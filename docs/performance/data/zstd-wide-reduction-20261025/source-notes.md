固定256宽位归约源码已完成并冻结。只编辑weighted_bound.zig和新frequency_reduction.zig；其他测试、cache、facade、build/tools与Git由各owner处理，本代理未编译或计时。

API：frequency_reduction.inspect256(current:*const[256]u32,previous:*const[256]u32,max_total:u32)!Inspection{total:u32,active:usize,same_support:bool,negative_delta:u32}。Error仅InvalidFrequencyTotal/IntegerOverflow。

Certificate.analyze默认只有n256/comparetrue走此kernel。init/publish和其他n仍使用原inspectScalar；新增analyzeReference(g)!Analysis用于测试与same-process kernel benchmark，通过相同finishAnalysis执行原checkedi64 Cf、DeltaR、penalty、Rg clamp。没有Certificate字段/布局变更，root不新增导出。

数学与错误等价：

- 8lane u32读取，数值widen到u64后加；32chunks，任意完整u32数组总和<=256*(2^32-1)=2^40-256，每lane<=32*(2^32-1)<2^37，全部u64运算无溢出。
- negative用prior-min(prior,now)，减法不underflow；再widen到u64累积。任意旧/新u32数组负向总量同样<=2^40-256。
- support由zero-mask XOR后OR，active用nonzero-mask popcount；位置顺序/endianness不改变其真假或数量。
- total最终与真实max_total比较，InvalidFrequencyTotal先于negative u32cast；非负输入scalar前缀超限iff最终sum超限。n256 scalar不会有u64累加溢出，因此这些错误优先级相同。
- total合法后再checked cast Dminus，保异常previous使负mass=Max32允许、Max32+1 IntegerOverflow，即使support changed也不吞掉它。
- 不信任Prepared.regenerated替代实际sum，不用u32累计total，all2^24样本总和2^32不会wrap到0。

读取current[offset..][0..8].*与previous同方式，offset0..248，正好256项，无overread，不增加SIMD alignment假设/alignCast；数组原u32对齐即可。要求原接口正常的完整初始化输入；没有新I/O或volatile读取。

两个8x64 localaccumulators名义共128B，loadedvectors/masks和后端spill另计，不能拿它当actual stack/RSS；无新retainedstate/heap/global/用户knob。Zig可在目标拆分或标量化vector，不据此保证x86/其他平台速度。

测试worker已提供weighted_reduction_tests.zig，hook为weighted module named `zstd weighted reduction complete scalar oracle contracts` → contracts(@This())。其独立u128scalar+formula oracle逐field/error对照默认与analyzeReference/rawkernel，覆盖正常/empty/RLE/支持改变/hugeu32/all2^24/limit±1/negativecast/error优先/B1,3,11,255/generic2,3,4,257/u32合法而SIMD未对齐。父统一三目标tests与newencode/kernelbuild，之后再quiet。不声称这些矩阵已经完成。

| 冻结源码 | SHA256 |
| --- | --- |
| `src/zstd/literals/weighted_bound.zig` | `e45b292daca0a33a5840f21543cf0ae93396db65072ab9aa4562def89ab4a890` |
| `src/zstd/literals/frequency_reduction.zig` | `34ee2d73fb003ae301e9642a9cd61ef366aaccefa856baff2cae56166347eb2b` |

记录UTC：2026-10-25T06:36:03.357968+00:00。
