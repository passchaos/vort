# Zstd single-sequence payload lower-bound contract audit

- 审计目录：`/home/passchaos/project-z/vort-zstd-cost-bound`
- 基线：`27dcca4562c3098b2cd6c71760d421366ea1627c`
- 完成时间：2026-10-25 13:57（Asia/Shanghai；系统 UTC 05:57）
- 范围：只读源码与数学/调用契约审计；未编译、编码、跑测试、计时或修改 Git/源码。唯一写入是本报告。并行工作中的新增下界实现及测试不在本次实现审查范围内。

## 结论

合法的 single-sequence 候选可以把 literal-section 下界与原有 RLE/predefined sequence 的零 literal 成本相加。下界必须涵盖 raw/RLE/Huffman 的最小值、四流跳转表与每流结束位，并保持原有错误顺序和 incumbent tie 规则。`SingleLiteralCostCodec.planFromFrequencies` 的成功结果走最优 11-bit 加权 Huffman 构造；这个最优性只涉及加权位数，不涉及 tree/header/分流舍入后的总字节数。

发现一个明确的 API 陷阱：`huffmanLiteralsHeaderLen(R, 0)` 不可用于最小头部估计，因为它直接返回 `CorruptFrame`。应使用 `huffmanLiteralsHeaderLen(R, 1)`，或独立证明并实现按 R 分段的最小头部函数。

## 可直接复核的安全构造

设合法 cut 的实际再生字节数为 R，实际频率为 f；u 是实际非零符号数。基线 literal 成本见 `src/zstd/literals/single_cost_cache.zig:89`（并行编辑前位置）及 `src/zstd.zig:25012`：

- `L_raw = literalsHeaderLen(R) + (u == 1 ? 1 : R)`。u=0 的空输入不能按 RLE 的 1 字节载荷计；u=1 直接采用 RLE；u<2 或 R<64 时，基线不尝试 Huffman。
- 对确实可能进入 Huffman 的候选，取已证明不大于实际加权位数的 B。S=1（R<=1023）或 4（R>=1024），J=0 或 6。令 `L_stream = J + ceil((B + S)/8)`。
- 当前 fresh-tree 路径至少 2 字节，因此 `L_huff = huffmanLiteralsHeaderLen(R, 1) + 2 + L_stream` 合法。使用 tree=0 也安全，只会削弱下界。
- `L_literals = min(L_raw, L_huff)`；若已证明 Huffman 分支不被基线尝试，可直接采用 L_raw。未证明 Huffman 不可用时，不能只使用 raw 成本。
- 对成功的原有 helper，`E_rle = rlePayloadLen(prefix, offset, match, 0)`，`E_pre = predefinedPayloadLen(prefix, offset, match, 0)`。`L_payload = L_literals + min(available E_rle, available E_pre)`。这里 payload 不包括外层 3 字节 compressed-block header。

流公式的证明：实际第 i 流的位数为 b_i，每流长度是 `ceil((b_i+1)/8)`；所以其和至少 `ceil((sum(b_i)+S)/8)`，而 `sum(b_i)>=B`。四流的 6 字节 jump table 另加。源码：`src/zstd/literals/single_cost_cache.zig:132`（基线）；`src/zstd.zig:25142`、`:25194`。即使 B=0，聚合公式仍安全，但弱于逐流至少一字节的事实。通用代码中的 B+S、rounding 和最后加法应采用受检算术；本 codec 的 block 上限为 128 KiB（`src/zstd/literals/cut_histogram.zig:7`），实际 11-bit 位数及这些加法在 32-bit usize 上也不接近溢出。

### 头部与树的最小值证据

`src/zstd.zig:25069` 明确检查 compressed_size==0；正尺寸下头部为 3/4/5 字节，阈值分别为 R/C<=1023、16383、262143。固定合法 R 时，正 compressed_size 增大不会缩短头部，故 C=1 得到安全最小值。

fresh-tree>=2 不依赖经验数据：

1. 成功 finalize 要求 plan.len>=2，并由非零频率的 distinct byte symbols 设置 max_symbol（`src/zstd.zig:25135`、`:31069`）。因此 max_symbol>=1。
2. direct 长度为 `1 + ((max_symbol+1)/2)`（`:28522`），至少 2。
3. FSE tree 长度为 `1 + compressed_len`（`:28621`）。内部压缩符号流的 bit_count 从 1 个结束位开始（`:28886`），成功序列化长度至少 1；normalized header 的 usize 长度非负（`:28871`、`:29151`）。因此成功 FSE tree 至少 2。
4. tree selector 只取 direct/FSE 可用长度的最小值；null 代表该候选树没有可用序列化，并不提供更小的树路径。当前 cache 不考虑 treeless/旧树重用；若以后增加此路径，fresh-tree>=2 不能直接复用。

## 最优加权成本前提

`planFromFrequencies` 构造 fresh 零初始化计划，按 byte symbol 升序收集全部非零频率，随后 finalize（`src/zstd.zig:31069`）。`fillSmallHuffmanWeights`（`:28399`）把 max_symbol<64 的输入交给 `treeCodeLengths(64,...,11)`，其余交给 `treeCodeLengthsKnownActive(256,...,11)`。代码没有使用较早的启发式 `weightedCodeLengths`。

已读路径与数学依据：

| 路径 | 源码 | 对最优成本前提的含义 |
|---|---|---|
| scanned 64-symbol / known-active compact | `src/huffman.zig:1243`, `:1308`, `:1481` | 删除零频率符号后映射到 packed package-merge，不改变 active 频率或目标函数。 |
| known-active 65..127 | `src/huffman.zig:1326`, `:1568` | 128 workspace 的 serial backref package-merge；依次相邻成包、合并原叶列表、选 2*active-2、恢复 multiplicity。 |
| known-active >=128，natural accepted | `src/huffman.zig:1339`, `:1367`, `:1425`, `:1444` | 两个最小权重结点合并的普通 Huffman 最优树；仅当每个 active 深度都在 1..11 才采用。无约束最优树已满足限制，故也是 11-bit 约束最优。spread>16 的拒绝只选择 fallback，不改变结果目标。 |
| dense natural rejected | `src/huffman.zig:1354`, `:1551` | 返回 bounded backref package-merge；bucket leaf order仍按(weight,serial)排序。 |
| packed bounded kernel | `src/huffman.zig:1824`, `:1871` | 同样的 package-merge 选取与 multiplicity 恢复；nibble 计数上限11不会发生跨 nibble carry。 |

package-merge 在 active<=2^11（这里最大256）、正 active 权重、最大深度11时最小化 `F(f)=min sum(f[s]*length[s])`。实现与该标准构造相符。排序符号、生成 canonical code 和 last-weight validation 发生在长度生成后，不改变 bit_counts；失败返回 null，而不是一个更优或更贵的 Huffman 位成本。

这是源码与算法定理层面的依据，不是本轮运行验证或对所有实现细节的形式化证明。现有测试提供参考对比与 Kraft 证据，例如 `src/huffman.zig:2795`、`:2916`、`:2974`；本次没有执行这些测试。FullWidth packed 与 serial backref 在相同加权成本时可给出不同 per-symbol 长度；最优成本验证应比较 weighted cost、active 位长范围与 Kraft，不应要求 FullWidth exact lengths 相同。对于原有 byte-exact 替代路径，应继续对比原 scanned/backref traversal 的 exact lengths。

### B 的合法来源及陷阱

- 对实际 f，成功 plan 的 `sum(f[s]*bit_counts[s])` 就是 F(f)，也等于总 stream symbol bits；它可作为聚合 stream 成本的 B。
- 对逐符号保证计数 g<=f，且 g 有至少两个非零符号，F(g)<=实际 Huffman 位数。证明：把实际码限制到 g 的符号集合仍为深度<=11的有效 prefix code；压缩 unary 节点可得到不增加任何 retained 长度的完整树，因此 F(g)<=sum(g*l_actual)<=sum(f*l_actual)。这个证明允许 g 的 support 小于 f 的 support。
- 单个缓存计划对新频率的 dot 通常满足 `F(new)<=dot(new,l_cached)`，所以通常是上界，不能仅凭旧 plan 最优就称它为新频率下界。
- `planFromFrequencies(g)==null` 不能证明实际 f 的 Huffman 分支不可用；保证计数只有0/1个符号时，应采用已证明的更弱 B 或继续精确计价。也不能因为保证计数只有1符号就把实际候选视为 RLE。
- 目标函数的最优性不能推导 serialized tree、单流舍入、四流舍入或 header 的最优性。对这些项需要独立最小值，或使用原精确 estimator。

## 序列项、fallback 与错误契约

`src/zstd.zig:28218`、`:28236` 的 RLE helper 从第四参数 literals_section_len 起加 sequence count、mode+3 codes、extra-bit stream。`src/zstd.zig:28082`、`:28096` 的 predefined helper从同一参数起加 count、mode 和规划后的字段位数。第四参数是纯加法基数；0 没有特殊拒绝规则。singleBestSequencePayloadLen 只调用这两类成本，mixed table 成本只有 sequences>1 才纳入（`:28171`、`:25427`）。因此成功模式的 `L+E` 分解精确。

原 cache 先算 literal section，再按 RLE、predefined 顺序尝试序列项，忽略各模式的 CorruptFrame，其他错误立即返回（基线 `src/zstd/literals/single_cost_cache.zig:69`）；两模式都不可用才返回 CorruptFrame。literal plan/tree/stream null 或 Huffman header UnsupportedZstdFeature 退回 raw/RLE；其他 literal 错误仍传播（基线 `:99`）。

下界接口必须保留这些规则：

- Cut 验证为 prefix<=tail<=block.len，先于 histogram 状态修改（`src/zstd/literals/cut_histogram.zig:40`）；init 拒绝大于128KiB的 block。
- 不能把未证明合法输入的错误转成一个可剪枝数值。若 sequence helper 非 CorruptFrame 失败，保留原错误/精确回退；若两模式都 CorruptFrame，则按原错误或不可用候选处理。
- 不改变 literal-then-sequence 错误先后顺序，也不能让新的最小头部调用制造基线本无的 CorruptFrame。
- indexed finder 的 prefix_len虽是 index-start_min，cache 的实际 literal view仍是 `block[0..prefix_len] ++ block[tail_start..]`。下界必须使用同一 view，不能擅自改成从 start_min 开始的 prefix（`src/zstd.zig:30427`、cache模块文档）。

## incumbent 与等成本剪枝

原 hashed finder 比较式是 payload更小，或 payload相等且 match len更长（`src/zstd.zig:30433`）；同成本同长度保留先来的 candidate。安全剪枝条件为已有 incumbent，且：

- LB > incumbent.payload_len；或
- LB == incumbent.payload_len 且 candidate.len <= incumbent.len。

LB相等但candidate匹配更长时必须继续精确计价。无 incumbent 时不剪枝。不要改变原候选枚举、hash采样、已有 duplicateMatchCannotBeat 规则或 error catch-continue 行为。

## 后续验证建议

实施者应覆盖 R=0/1/63/64/1023/1024/16383/16384/128KiB、u=0/1/2/64/65/127/128/256、sparse/high-byte/tied/skewed histogram；核对每个合法候选 LB<=原精确 payload，并对全 finder winner 与 emitted wire 做差分。应专门加入 LB相等且更长匹配的案例，以及invalid cut、invalid sequence和literal错误顺序案例。最优成本前提的 oracle验证用 weighted cost与Kraft；exact-length/wire保持验证继续使用原 serial/reference路径。


## 补充审计：same-support drift 证书与 shadow refresh 门禁

补充时间：2026-10-25 13:59:44（Asia/Shanghai）。本节针对当前实际实现的 drift 公式。前节 g<=f 的 restriction 是另一种充分下界构造，不是这里的频率限制；本节明确允许 current 频率增加和减少。读取了当前 `weighted_bound.zig` 和 Base.Cache 分层接线源码；shadow wrapper 尚未出现在读取的文件中，所以 shadow 部分是对父代理提供设计的契约审核，未声称完成其逐行实现验证。

### drift 公式完整证明

设 M=11、old 频率 f、current 频率 g；它们的非零支持集合 S **逐符号完全相同**，|S|>=2，且 |S|<=2^M。令 Rf=sum(f)、Rg=sum(g)、Cf=Opt_M(f)，并定义 Dminus=sum(max(f_i-g_i,0))。允许任意 g_i>f_i。

对固定 S 定义可行码长集合：每个 active 符号的整数长度在1..M，Kraft和<=1。该集合只依赖 S/M，与频率大小无关，所以任何 current 最优码长 l 也是 old 的合法码长。于是 Cf<=sum(f_i*l_i)。逐项令 delta_i=g_i-f_i：

- delta_i>=0 时，delta_i*l_i>=delta_i，因为l_i>=1。
- delta_i<0 时，delta_i*l_i>=M*delta_i，因为l_i<=M，乘负数后不等号翻转。

因此：

```
Opt_M(g) = sum(g_i*l_i)
         = sum(f_i*l_i) + sum(delta_i*l_i)
        >= Cf + sum(delta_i) - (M-1)*Dminus
         = Cf + (Rg-Rf) - (M-1)*Dminus.

B(g) = max(Rg, Cf + (Rg-Rf) - 10*Dminus) <= Opt_11(g).
```

Rg clamp来自每个active符号至少1 bit；这仍是 Huffman **位**下界，不能替代 raw/RLE 的 representation minimum。Cf也可以是已证明Cf<=Opt(f)的更弱标量，证明仍成立；任意可行但非最优树的加权成本不具备此信任条件。

实现签名/数值检查与该证明一致：

- `src/zstd/literals/weighted_bound.zig:30` 的 `Certificate(n,max_bits)` 固定同一码域；实际实例为 n256/M11。
- `:49` 的 init 接受 `[n]u32`频率快照和 u64 trusted scalar，检查至少2 active、active<=2^M、频率总量<=131072，并复制完整快照。只检查数值 envelope，不能自行证明 scalar 是下界；模块注释 `:26` 明确留下 caller 前提。
- `:77` analyze 输入current完整频率；`:122`逐符号比较 `(old!=0)==(current!=0)`，不是只比较cardinality。`:123`仅累加 prior>current 的负质量，完全没有禁止 current>prior。
- `:91`..`:99`采用i64计算prior、signed总量差、负质量penalty及clamp，避免u32 underflow或错误saturating差。M11、总量131072时 Cf<=1441792，Dminus<=131072，penalty<=1310720，i64有巨大余量；一般本模块u8 M的受检envelope也远小于i64上限。
- `:69` publish先构造replacement，成功后整体替换，错误不会把scalar绑定到半更新频率。

### 完整 Kraft 可行性与 Zstd last weight

Huffman wire要求完整的canonical tree；数学测试枚举允许Kraft<=1。这两个最优域在当前前提下等价：正active权重、至少两个叶子时，任意incomplete prefix tree可删除unary内部节点，得到每个内部节点都有两个孩子的full binary tree。被保留的符号长度只会减小，仍>=1且<=M；full tree的Kraft和=1。因此允许Kraft<=1不会获得比完整树域更低的最优成本，完整域也显然包含在<=1域中。M11、active<=256确保两域可行。

成功production plan还给出完整Kraft的直接源码校验：`src/zstd.zig:28399`用11-bit最优builder产生active长度；`:28425`以后不改变bit_counts。`validateSmallHuffmanLastWeight`（`:28492`）以H=max_bit_count、w_i=H+1-l_i，显式weight贡献是2^(H-l_i)。它要求省略的max_symbol对应remaining是2的幂，且重建weight等于该符号的真实weight，故成功时所有active贡献之和等于2^H，即sum(2^(-l_i))=1。它只过滤非法计划，不把计划重新分配成非最优成本。

完整域与相同support是关键条件，不能放宽为任意删符号。反例：M11、f=(1000,1000,1)，Cf=3002；g=(1000,1000,0)，Rg=2000、Dminus=1。强行使用drift会得到max(2000,3002-1-10)=2991，但g的真实Huffman最优成本是2000。当前模块在这种support变化时返回null，正确避免此问题。

### weighted_bits 发布绑定

当前Base.Cache的分层接线符合先literal再sequence的原有顺序：

- `src/zstd/literals/single_cost_cache.zig:135` prepareLiterals取得当前histogram频率、unique、R与raw_cost。
- `:147` literalCostPrepared只有plan/tree/streams/header全部成功时返回非null weighted_bits；raw最终更短时仍可返回此scalar。Cf是Huffman位最优，不要求Huffman赢得literal representation选择。
- `:184` streamsLen将各流未舍入的stream_bits求和（`:197`），没有包括结束位、padding或jump bytes；在快照绑定成立时，它正好是sum(f_i*plan.bits_i)=Opt_11(f)。
- `:111` calculatePayloadPrepared在literal成功后尝试RLE/predefined；`:127`只有至少一个sequence payload成功才把weighted_bits随PayloadCost返回。payload错误不能发布新证书。

一个必须保持的内部调用前提：PreparedLiterals频率快照必须对应Base当前histogram的cut。streamsLen从self.histogram读实际stream_frequencies，而不是从prepared重建。wrapper应在同一个query中执行prepare→bound→fullprice→publish，中途不能再更新cut、复用别的prepared或改变borrowed block内容。否则Cf可能来自另一cut，尽管scalar和frequency各自都看似合法。当前父代理描述的顺序满足此绑定；prepared公开方法本身没有编码此约束。

Baseunlimited无需建立或维护certificate。scalar只是一项返回信息；诊断wrapper在成功result与非null scalar上负责发布，保留基线cache精确定价能力。

### shadow would-reject 不刷新与 age 模型

对父代理提供的shadow设计，推荐且安全的状态转移如下：

1. 每候选先按相同顺序更新cut/histogram，并使用**旧certificate**分析current频率得到B，再用raw/RLE/Huffman最小值、header/stream/sequence下界构造LB。
2. 依据真实incumbent与原tie规则计算would_reject；不能用fullprice后新鲜Cf重新计算本候选的would_reject。
3. shadow所有候选继续原fullprice，并保留原error/reference检查。对成功结果核对LB<=actual；would_reject成功候选还要核对原比较式不能替换incumbent（尤其payload相等但match更长时不得reject）。失败fullprice按原catch/error语义处理，不能作为Cf出版来源。
4. would_reject=true时，即使shadow刚算出有效Cf，也不publish，不reset certificate age；旧频率与旧Cf一并保留。只有would_reject=false且fullprice成功且weighted_bits非null时才原子publish。更新incumbent与publish是两个条件，正常精确定价的losing candidate也可提供合法Cf。
5. age应一致定义为query ordinal减上次publish ordinal；未发布的错误、raw/null、support变化及would-reject候选都不能偷偷reset。若实现使用不同admission计数，shadow和future prune必须使用同一规则。certificate分析始终直接对保留snapshot计算Dminus，不把每步delta累计成一条未经证明的链。

这个门禁保持未来真实skip路径中的certificate历史：would-reject候选被skip时本来就不会产生新Cf；shadow虽然为了验证强制定价，但不能将这个额外见到的Cf泄露到后续bound状态，否则会过度乐观地刷新age和reject覆盖率。histogram仍在每query更新，这与真实prune为获得当前频率也必须prepare一致。support变化或raw/null时保留旧证书本身安全；以后support恢复可以重新应用旧snapshot公式。

shadow与真prune的tree_entry可以不同，因为shadow额外全价会更新tree cache。当前treeLen由完整TreeKey纯粹决定精确长度，差异只影响cache命中和性能，不影响精确wire大小、Cf或下界安全；shadow elapsed/tree-cache计数不能直接当作prune性能实测。这里的模拟对象是certificate/age/选优状态，真prune的收益仍需后续专门验证。

本补充未编译或执行数学测试。已读取测试源码，tiny oracle使用独立Kraft长度枚举并包含正delta、负delta与同总量变化（`src/zstd/literals/weighted_bound_tests.zig:51`），这提供设计层面的有效验证入口；实际结果由执行者确认。
