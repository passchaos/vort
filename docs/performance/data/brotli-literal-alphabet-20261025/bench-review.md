# literal alphabet工具静态审查

审查时间：2026-10-25 19:17:52（Asia/Shanghai）。工作树`/home/passchaos/project-z/vort-brotli-context-cache`，分支`work/br-context-alphabet-20261025`。只读新增工具、构建入口、support契约及父已完成的PDQ/radix微测、public14/profile70与验证，独立重算结果。未compile、运行encoder/benchmark、计时、修改源码/tools/Git；本轮新增授权仅写`docs/performance/industry-gap-audit.md`，另写本指定/tmp报告。原PDQ已在public前拒绝；radix源码及正式微测独立绑定通过，公共firstscreen有界结果已复核，三pair尚待完成。

## PDQ方案决定与证据范围

**原PDQ方案已被拒绝，在公共encoder测量前撤回。** 下面的静态工具可接受结论只是接口/测量合同，不等于算法性能通过，也不将后续radix替代源码归入该旧证据。

父`pdq-microbench/samples.json`与`gate-result.json`为8族×32slots、50,000迭代、同一进程五轮交替的完整support collection/rank+checksum比较。独立重算各median和reference/candidate点比，均与报告一致：

| 族 | reference/candidate点比 |
| --- | ---: |
| small16 | 0.870423x |
| threshold64 | 0.401656x |
| medium96 | 0.476636x |
| boundary128 | 0.527122x |
| dense_mixed | 0.789268x |
| dense_ties | 1.327698x |
| ascending_weights | 5.963619x |
| sparse_dense_support | 0.479555x |

升序重排和全ties的有利点不抵消随机中/密集族、small control及sparse support的明显不利点。没有统计显著性或公共encoder回归主张；这些数据足以支持父不继续当前候选的有界决定，但不是全部质量/平台性能排名。

`pdq-microbench/result.json`exit0、source/exe稳定、compiler process observations为0。旧核心SHA为`81ba69e0e99ed667c37eab9445584cd17ed12b62ecb7a794b6b9dcd0a176d59e`，旧exe SHA为`3d736a875893fec565b4e9b8d37ba9346f4b3350f2b453aeb4c81848250be739`；数据保留原PDQ身份，不抹去或按新radix改写。新micro如采用同8族pool应逐族核input_sha256相同，再另绑定新source/exe，不能只沿用case名称。

后续radix按四个完整frequency byte（key shifts8/16/24/32）做稳定LSD pass，跳过所有项相同的digit，利用原symbol升序维护equal-frequency tie；全32bit频率不截断。当前该版本已SOURCE_READY，静态算法和正式微测复核如下；旧PDQ数据仍归旧epoch。

## Radix SOURCE_READY与正式micro复核

### 原始结果、相同输入与身份

独立重读`microbench/samples.json`和`gate-result.json`，逐族对五round raw值重算两个median及reference/candidate点比，8族全部一致；验证order为R/C、C/R、R/C、C/R、R/C。两份PDQ/radix样本schema、50,000迭代及pool32一致，按case逐族SHA256完全相同。不是仅依赖case名或“生成公式没改”的推断。

| 族 | reference ns/call | radix ns/call | 点比 |
| --- | ---: | ---: | ---: |
| small16 | 74.96982 | 80.39200 | 0.932553x |
| threshold64 | 836.20326 | 370.12434 | 2.259250x |
| medium96 | 1629.06748 | 481.62264 | 3.382456x |
| boundary128 | 2619.31462 | 604.63044 | 4.332092x |
| dense_mixed | 8120.02562 | 1068.30834 | 7.600826x |
| dense_ties | 465.37036 | 363.47958 | 1.280321x |
| ascending_weights | 14782.99516 | 1427.14530 | 10.358437x |
| sparse_dense_support | 1406.96274 | 525.60680 | 2.676835x |

每call值是完整迭代成本（kernel+双输出checksum+pool选取），而非裸sort成本。small16继续有较慢点；不能说8族全胜，也不能把局部高比直接当公共encoder收益、显著性或无内存成本。

正式meta exit0、source/exe稳定、compiler process observations0。当前核心SHA`66ecc843530b925666f93f6c2983a056668d95a8f7f978ce680940b111e475c7`、测试helper SHA`730195dc3e5549d33eb6e34defd987141781cef2311b6e782a9de674a2b9a0f0`、工具SHA`9f948ecb7e92d835749c8ab59f2f63daf479633f2f87baade190e8dae7acdbfc`、build SHA`54186919eb186f75db953e2513671491ae9f74484f1fa86dca3c6bc21d5d7f73`均与micro source_after逐项相同，before=after。正式exe SHA`bd4e4e42efe314c44c113a39edf26b63d929da982fd72baf72cfac918ae95a86`与样本provenance一致。来源中CPU8/ReleaseFast/单线程与rawcommand保留；0 compiler观察不等于所有系统噪声为0。

### 稳定radix正确性与数组/计数边界

- `literal_alphabet.zig:25..35`仅读取有效support，过滤零频率后按symbol升序写tree_symbols；因此`:57..61`生成keys的原顺序已按symbol升序。Key为`u64(~frequency)<<8 | symbol`，最高40bit，完整32bit无clamp/加和溢出。
- `:77`按key的8/16/24/32四个byte低位到高位执行LSD stable counting pass，不对低symbol byte单独排序。若四frequency bytes相等，每个pass都稳定维护原symbol升序；若不同，高频的u32补码较小，最终freq降序。输入symbol唯一，equal-frequency tie确定。
- `:70..78`variation为所有key相对首key异或的OR，某byte无variation等价该digit对全部keys统一。重排不改变集合，所以统一判定可在原key集合计算一次；跳过该pass是稳定identity操作。低symbol byte variation未参与四个mask，不会误启frequency pass。
- `:81..90`counts清0后只计live<=256项，每bucket<=256、总next<=256，u16足够。positions为exclusive prefix，scatter前每个要写的位置是0..live-1；最后bucket计完时positions可升至256，仍能表示且不会被再次索引。
- `:79..80/:94..99`source和destination在keys/temporary之间分离，按source顺序稳定scatter，每个destination有效槽恰写一次；temporary在读之前已完整写入。in_keys仅实际pass执行后翻转，跳过uniformdigit不翻转；`:101`奇数次pass才copyback，0/2/4次保持keys内结果。无读undefined尾部。
- static scratch声明为keys2048B、temporary2048B、counts512B和positions512B，总5120B；实际优化后caller frame/stack峰值需ELF或runtime单独核查。noinline大support隔离不等于这些内存消失，不从速度点比推断降内存。
- API constfreq/constsupport、固定输出256容量和len可表示256继续满足；reference仍原fused insertion。已排序shortcut和support/live阈值分支不改变合法输出。内部support契约为unique升序，工具全部符合，未将Debug assert称成对任意恶意support的运行期验证。

### 父已完成的QA及未完成范围

只读核`radix-debug/radix-releasefast/radix-x86/result.json`，三个平台各1个named contract test exit0/source稳定；每named test内部包含完整矩阵，不是仅1个输入。helper`:129..159`覆盖单个frequency byte变化、uniform上/下digit与tie，以及2/3/4变化byte、跳过uniform middle digit、最终buffer奇偶、动态threshold-1/threshold/threshold+1。原独立selection oracle不共享packed keys，另外覆盖全u32、稀疏/undefined support外和输出guard/tail。

`context-debug/context-x86`各76/76，source稳定。全family和check等后续结果已由父完成并独立核对如下；公共效果以独立firstscreen数据为准，不把micro直接换算公共收益。本审计未新增compile/time/Git。

## 最终firstscreen、完整非计时详情与已完成验证

- 独立重读baseline14/public14原始五round，按input SHA配对，14行settings与完整两库wire长度/hash一致，重算old/new median点比几何值**1.060755910287x**、reference/new **0.034437158996x**，与analysis一致。11/14版本点正向，reference 0胜；Dickens0.999098330、Reymont0.998364309、NCI0.981048186不隐藏。仅冻结64KiB q8/generic，三对进程重复仍待父完成，不宣称显著性、每行稳定改善或全质量/平台领先。
- 独立读取当前profile14与前一dense-Huffman的profile14按输入/round/detail配对，**70次调用、140条实际详情**。逐个origin/variant/command_count和所有非`_ns`字段全部相同，没有允许改动的计数字段；cache/uncached/scope/mode、treecalls、activebuckets、proposal shapes、Huffman/prefix work包括在内。wire与selection所有语义字段比较通过。不是全Profile深相等，Profile细time应不同；没有把shape相等说成所有内部context_map本体的读取oracle。
- `tree_alphabet_ns`各plan独立median重算：Mozilla lazy/optimal 4.984463/5.291635→1.360870/1.691083ms；SAO11.365281/11.284848→1.718895/1.759234ms；source0.584796/0.629856→0.295514/0.331832ms。这些细time嵌套在parent context，median分别计算不应相加，instrumentation overhead不代表ordinary吞吐。变化为精确alphabet排序方法，未少搜实际树或偷减候选/熵计算。
- 只读核三平台radix各1个named内部完整matrix、context Debug/x86各76，fullBrotli **1424 pass/1skip/0fail**、check **175/175**、legacyprofile **10/10**、CLIhelp **7/7**，exit0且source_before=after。未重跑验证。
- 当前kernel、kernel_tests、literal_context_split、literal_alphabet_bench、build共五项hash逐个匹配以上所有QA/check/CLI/micro/public/profile的source_after。这是选定实际源码的绑定，不伪称全Git内容和所有外部工具从未变化。public/micro/profile0 observed compiler processes等记录保留，不能证明全部系统噪声为0。

行业文档本轮已新增`brotli-literal-alphabet-x86.md`链接、PDQ rejected、新radix微测与firstscreen局部值，保留弱样本和5KiB静态scratch非RSS/stackpeak。三pair尚未完成不写未验证数字；后续父通知完成后补对照。

## 当前结论与实质核对项

`tools/br/literal_alphabet_bench.zig`的两路计时和输出消费范围一致：先构造8族×32pool，计时外逐项比两种输出的有效数组和len；计时内noinline运行完整support收集/排序，同时消费rank和sparse两输出。哈希只读初始化的freq字节及有效support，无结构padding。没发现当前输入或默认mix算术溢出问题。

1. **API const签名已核**：tool`:102/:105`encode接收`*const Input`，实际频率为`*const [256]u32`、support为`[]const u8`；当前radix `literal_alphabet.zig:13/:106`的build/reference接受相同只读类型。工具Rank为[256]u16+usize，Symbols为[256]u8+u16，两个len均可表示256，满足anytype输出布局；没有mutable指针ABI冲突。
2. **双输出长度保留项已解决**：父最新tool`:65..68`先核old_rank.len==old_symbols.len、new同等式，再核old/new各len与完整live数组。计时`:107`双slice消费具有显式预检契约，不再保留缺equality问题。
3. **module imports核对通过**：`build.zig:3268`的root为`src/br/encoder/literal_alphabet.zig`，当前核心只import std(:5)和同目录测试(:130)，没有../../跨根引用，不需要旧dense工具那种src wrapper。本审计未compile，构建/运行结果按父已有证据单独记录。

## 8族输入与精确比较

- `:21/:36`四个固定support小/中族和四个256support族，各32slot；support初始化为全0..255升序，传前support_len，因此有效support唯一且严格升序，与生产父histogram support一致。
- `:38..44`small16/threshold64/medium96/boundary128为16/64/96/128个正freq，dense_mixed/dense_ties/ascending_weights支持256且全live。sparse_dense_support支持256，但实际live85或86，32项中85有21项、86有11项；可明确它测support扫描256但只排序85/86的路径。
- `:48..53`随机频率1..65536、ties17、ascending1+index..256+index（最大287）。`:55..56`support外所有频率设u32max，旧/新实现应只读取caller support；不能把外部高值拉入rank或树symbol。
- dense_ties32slot的全部freq/support实际相同；随机state虽然每slot推进，不用于ties权重。报告可以称32pool slots，不能称32distinct histograms。ascending32slot只是频率全部加常数，rank相同但输入字节不同。其他族使用固定seed跨case推进，不等同于每族单独重置seed。
- `:57..58`hash拼接全初始化`[256]u32`原始字节加有效support，重复32次；不hashInput/Rank/Symbols结构或undefinedpadding。原生freq字节依目标端序，target provenance与冻结source需同时记录。固定每族support_len和固定freq1024B使当前拼接边界明确；如果未来混合support_len，需把长度纳hash避免模糊重建。
- `:63..68`比较reference/candidate两len、同次双len等式和各自有效rank u16数组、sparse u8数组，不读undefinedtail。tail为scratch、len外不属输出语义，所以不应比较整256undefined空间。它覆盖实际排序/ties/稀疏symbol结果，而非仅checksum。
- 当前预检仅比较两个实现，没有独立扫描oracle/assert expectedlive或supportoutside排除；若reference保持旧helper这可做差分证明，但本工具本身不能证明两路共同bug不存在。已有独立literal_alphabet_tests可提供kernel correctness，勿仅因benchmark新增过度重复测试。
- 输入仅有效非空support，没有empty/error/malformed support性能族；这是有界微测面，不是完整API错误验证。

## noinline测量、双输出消费与时间范围

- `:101..107`noinline encode每次构造undefined输出scratch，调用参考/候选同样形状的build，消费rank.len、symbols.len和两个有效输出数组。排序/收集及输出消费在同一个完整入口内；不把它说成独立排序kernel的纯时间。
- `:109..119`两路measure每次重置同pool选择seed，before/after包围完整iterations循环。`:114..115`pool选择序列和次数完全一致，accumulate同noinline checksum；计时不含生成、exact检查、provenance、JSON或排序median。
- `:78..79`reference/candidate各128暖身，reference先；`:83..89`五轮R/C、C/R、R/C、C/R、R/C，原始order保存。五轮为一个进程内重复，3次reference先/2次candidate先，没有独立进程分布保证。
- `:91..94`分别对5值排序输出median及全部raw rounds；未输出min，但raw可重建。median ratio不是逐round ratio中位数或几何平均，父分析须明确统计方式。
- `:105..106`两个输出全有效元素均消费，但两个slice必须同len。checksum是加权聚合，可碰撞，不替代`:65..67`逐项exact检查；`:118`doNotOptimizeAway和输出round.mix使结果可观察。静态代码不等同于最终机器码无hoist/CSE证据，父如需可绑定ELF独立核查。
- 两路都包含相同pool选择/checksum，微测比会受共同消费开销稀释；不应将其等同公共proposal search/encoder吞吐收益。

## 算术、scopes与provenance

- LCG乘加与累计均显式wrapping，合法输出symbol<=255、rank/symbols.len<=256。单个encode最宽mix上界2,181,038,464，默认50,000次累计上界109,051,923,200,000 < u64max；无需因默认合成输入另引overflow测试。实际输入weights不参与checksum加和，也无频率求和导致u32max ignored值溢出。
- `:17..18`拒零iterations和额外参数，parseInt接收usize；超大iterations可以wrapping mix，这是诊断hash而非codec统计，不能假称无上限运行数学唯一性。`:117..119`awake i96 elapsed转u64沿正常非负范围，未提供timing_complete/溢出状态；当前有限微测不需要改变codecerrorpolicy。
- 无Profile tree/cache/work字段，也无nestedtiming；两路唯一作用域为完整kernel+消费。不能把它的时长直接叠加q8context/outer已有细stage。
- `build.zig:3260..3278`benchmark和kernel模块均ReleaseFast，provenance共享模块也ReleaseFast；build check`:7182`纳入工具。run entry允许传iterations，未强制CPU pin。
- `benchmark_provenance.zig:7..21/:62..78`记录Zig/target/CPU/affinity/单线程policy、实际exe hash和argv；工具`:75`记录sort_threshold（候选约定64）。source/实际构建输入稳定与quiet无编译观察需要父执行元数据，provenance本身不证明。

## 快照与下一步

- tools/br/literal_alphabet_bench.zig：`9f948ecb7e92d835749c8ab59f2f63daf479633f2f87baade190e8dae7acdbfc`
- build.zig：`54186919eb186f75db953e2513671491ae9f74484f1fa86dca3c6bc21d5d7f73`
- src/br/encoder/literal_alphabet.zig（当前radix SOURCE_READY）：`66ecc843530b925666f93f6c2983a056668d95a8f7f978ce680940b111e475c7`

当前核心dispatch范围：`literal_alphabet.zig:14`support<64直接参考insertion；大support`:37..42`检测live频率已降序（ties视为已序）后直接复制；`:44..53`若live<64仍采用insertion；其余`:56..65`生成完整40bit key后调用稳定frequency-byte radix。被拒绝的旧PDQ在同一位置调用sortUnstable，不能混称当前算法。所有freq读取只访问支持/筛出的symbol，未扫描support外填max值。

因此dense_ties族测alreadyordered shortcut，不是密集排序；small16测原reference路，threshold64和medium/dense随机测排序，sparse256的85/86live测大support过滤后排序。ascending_weights使原insertion承受最重移位顺序。当前8族不覆盖“support>=64但live<64”的性能分支及恰63/65边界；这些属覆盖说明，不要求再扩本轮bench，kernel correctness由独立tests负责。

测试helper`literal_alphabet_tests.zig:3`仅importstd，无module-root外引用；其独立selection oracle不共享packedkey排序，补工具的new/ref差分证明。当前tool/radix审查没有实质阻塞项，micro源码绑定已核；下一步父完成running的family/check并独立验证公共ordinary效果，本审计不compile/timing。
