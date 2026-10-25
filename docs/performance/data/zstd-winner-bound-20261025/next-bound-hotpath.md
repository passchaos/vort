建议下一有界增量：**仅对Certificate.inspect(compare=true,n=256)增加精确宽位vector归约，继续计算并验证完整g总量，不引入unchecked trusted-g接口或incremental observer。** Generic scalar实现保留为其他n及oracle。此方案未实现、未编译或计时，也未证明inspect已是当前实测热点。

父反馈的实际prune/shadow已精确吻合，XML保留29,499计划、MR16,401；14×5round新XML约1292.71ms/source500.75ms/MR971.94ms。这里把这些当父提供的上下文，不据此把剩余时间全部归给inspect。应先计actual_analyze_calls与该阶段成本；1.47m×256逻辑项是调查依据，不是CPU时间剖面。

**为什么当前数组仍应完整校验**

`single_cost_cache.prepareLiterals:144` 先调用CutHistogram.update，合并四流频率并统计unique；CutHistogram.init/update限制immutable block<=131072且0<=prefix<=tail<=N。由其range分割和增减可证明sum(frequencies)=regenerated<=N，合法内部Prepared的总量可信。

但是PreparedLiterals:39是普通公开struct，frequencies/regenerated/unique各字段可构造；Certificate.analyze也可直接接受任意完整u32数组。不能只给analyze传prepared.regenerated并跳过sum校验：伪造频率大数组会将原InvalidFrequencyTotal变成null或错误bound。CF可信前置也不能替代g几何校验。

本增量用宽位归约消除逐项checked-add/上限分支，仍验证真实sum，所以无需扩大可信接口边界；Prepared生成路径和直接错误测试走同一逻辑。

**固定256的算术证明**

当前inspect（weighted_bound.zig:106）按每项checked u64 sum、上限check、active、support、Dminus处理。取8个u32为一chunk，32chunks：

```
max(sum(g)) = 256*(2^32-1) = 1,099,511,627,520 < 2^64
max(each wide accumulation lane) = 32*(2^32-1) < 2^37
max(sum(max(f-g,0))) <= 256*(2^32-1) < 2^64
```

后两个最坏界甚至覆盖数值被异常改变的旧数组；正常init/publish后的f更紧，Dminus<=Rf<=131072。

因此n256任意已初始化u32数组的total/negative u64累积都不能溢出。当前数据均非负，某scalar前缀超过131072当且仅当完整sum超过131072；此n的scalar路径也永远不会先因u64加法溢出而报IntegerOverflow。可在vector循环后一次检查total>limit并返回**同一InvalidFrequencyTotal**，再按原顺序checked cast Dminus为u32。即使support变化也不得省掉total和negative校验；仍返回完整Analysis或同一error。

不是用u32累积total。例g所有项为2^24，sum=2^32；u32归约会wrap到0并错误接受。u64数值widen必须在相加之前，不能用bitCast把相邻u32拼成u64。

**建议implementation形态（伪代码，不是已编译Zig）**

```text
if comptime compare && n==256:
    totals[8]:u64 = 0
    negatives[8]:u64 = 0
    mismatch_mask:u8 = 0
    active:usize = 0
    for offset=0,8,...,248:
        g = load exactly [8]u32
        f = load exactly [8]u32
        totals += numeric_widen_u64(g)
        d = f - min(f,g)             // per-u32 exact max(f-g,0), no underflow
        negatives += numeric_widen_u64(d)
        mismatch_mask |= bitmask((f==0)!=(g==0))
        active += popcount(bitmask(g!=0))
    total = reduce_add_u64(totals)
    if total >131072: InvalidFrequencyTotal
    negative = checked_u32(reduce_add_u64(negatives))
    return total_u32,active,mismatch_mask==0,negative
else:
    original generic scalar inspector
```

必须使用f-min(f,g)或真正的unsigned saturating subtract。`select(f>g,f-g,0)`若先无条件计算f-g，在Debug可能underflow；不能依赖select遮住错误。加载从u32 array/slice转成vector，不新增alignCast或32/64byte alignment前置；只读实际256项，不过读。bitmask/OR和popcount结果与byte lane顺序无关，support、active精确。可先8lane作为固定方案，Zig在x86/其他目标可拆分/标量化；这不保证各目标更快，须native/x86实际验证。

保留analyze后半的checkedi64 Cf/DeltaR/penalty和Rg clamp，保init/publish generic scalar验证与事务；只优化频繁的compare=true inspection。无需改变Certificate布局、Cf可信前置或generic n行为。

**内存/错误与状态边界**

- 不新增retainedstate，Certificate仍own原frequency/Rf/Cf；combined cost/certificate state继续<8KiB。
- 两个8×u64累积器共128B local storage，编译可能寄存器化；loaded vectors/masks/后端spills另计，不拿它当实际frame或RSS。无heap/global。
- 结果字段和错误优先级保持：先total合法性，再negative cast，再same_support之后的i64公式。g empty/RLE/supportdiff仍null并完整返回Rg/active/Dminus。
- 对n256的所有完整、已初始化数组保持数字语义。延后总量check会改变内部读取顺序，但输入接口是完整const数组，无callback/volatile读取；不把未初始化尾部或不完整内存当有效输入。
- 不先用prepared.regenerated做early reject并假装已验证frequency vector；其字段一致性是别的可信边界，需要额外设计。

**与两个替代方案的比较**

| 方案 | 复杂度/额外扫描 | state/错误风险 | 目前建议 |
| --- | --- | --- | --- |
| 固定256宽位vector inspector | 仍一遍256，32chunks；去逐项checked总量/negative add，exact support/active归约 | 无retainedstate；任意u32总量仍校验，同error | 优先，容易独立证明和scalar oracle |
| private trusted-Prepared入口 | 可复用R/unique并只算support+Dminus；少部分归约 | 普通Prepared字段不能封闭proof；public checked API须保留，可信入口需严格生命周期/构造证明 | 暂缓，不能简单删校验 |
| incremental g/support/Dminus observer | 每range增减事件O(scanned bytes)，证书刷新O256；可少totalFrequencies/unique/inspect全扫 | 增加约1KiB g和scalar（预算可能仍<8KiB），紧耦合CutHistogram与证书generation；错误事务更复杂 | 后续若vector仍不足再做 |

Incremental observer可逐symbol维护g、active、Rg和Dminus=max(f_i-g_i,0)前后差。证书总是以当前g发布时可重置Dminus=0/support same，但若任意f刷新，必须全量rebuild；不能用旧observer配新Cf/f。Cache/Cert可移动，不能保留指向自身的长期内部指针。

四流range迁移会出现remove/add抵消：这些是stream重分配，不一定是真正total-frequency变化。必须所有事件处理完才读取summary；处理过程中Rg可暂时大于131072，不能在每个add误报InvalidFrequencyTotal。旧/new完整total各<=N，混合中间总量可到2N（262144）；u32有余量，最终才核对新geometry。原CutHistogram把cut/counter admission放在mutation之前，observer也不能引入中途fallible更新而留下两份state不同步。仅此协调复杂度就比vector一步高。

目前hist每query平均扫描量虽小，但observer会给每个event加g/D/support更新，且Prepared.frequencies若仍按值复制，每query仍有1KiB复制。不能仅按事件数宣称O1或加速倍数。

**独立验证与测量门禁**

1. 原scalar n256 inspector保测试reference，逐field比较Error!Analysis（不只bound）：random/empty/RLE、holes/支持替换同cardinality、legal131072、131073、单个u32.max、all-u32.max、all-2^24以及zero/high值混合、B1/3/11/255。
2. 非法mass与support变化同时出现时仍InvalidFrequencyTotal；必要时用异常旧数组验证negative cast优先级，正常证书publish/error不变。unaligned于SIMD但合法u32-aligned数组要覆盖。
3. nativeD/nativeRF/x86RF的全部tiny/realistic与shadow/prune每query结果一致；generic n2/3/4/257仍走旧path。旧14full wire hashes和candidate winners继续比对。
4. 待family/check结束后由父协调build再quiet，不在并行编译时排名。测actual_analyze_calls、inspector和prepare/seq/fullplanner分段，防优化了并非主要的阶段。保持相同compiler/CPU/corpus/5round，与既有1.29s XML整API不能直接相加作归因。

此建议只有精确vector inspection这一条implementation边界；任何trusted-current接口或observer是后续独立增量。本任务无source/compile/test/timing/Git变动。

**读取源码绑定**

| 文件 | SHA256 |
| --- | --- |
| `src/zstd/literals/weighted_bound.zig` | `52ed8c0e99c7ea827c904ac87957315f690a1774fba20ed05410c7f5f6474313` |
| `src/zstd/literals/single_cost_cache.zig` | `f0329e0e93e16996dfcf32451ed6b858ff61c095891e9d84e9518034ab43395b` |
| `src/zstd/literals/cut_histogram.zig` | `c5b3b1eb9d8718db51d00329efe0f1e68448bdd8d6c2451e22c1b9f4fde4c386` |

记录UTC：2026-10-25T06:26:58.425556+00:00。
