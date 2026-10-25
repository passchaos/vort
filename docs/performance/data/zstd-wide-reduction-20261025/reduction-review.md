# Zstd frequency wide-reduction 只读审查

- 工作树：`/home/passchaos/project-z/vort-zstd-wide-reduction`
- 基线：`452445f4ed4e66be61999a0b76f6bf017d5d5022`
- 审查时间：2026-10-25 14:34:53（Asia/Shanghai）
- 范围：只读向量归约、weighted dispatch/标量契约、独立QAhelper和kernel benchmark源码。没有编译、执行QA/编码/基准、计时或修改源码/Git；仅写本报告。父代理负责构建、实际测试和whole API benchmark。

## 结论

当前落盘实现的256-symbol归约在任意完整初始化的u32输入数组上安全、精确，包含malformed高总量/异常previous频率。未发现总量或负差wrap、支持域mask错误、active计数错误、u32下溢、错误优先级变化或正常Cf/i64公式变化。Prepared字段没有参与可信输入；模块独立从完整current/previous数组计算几何。

仅compare&&n256使用vector kernel，init/publish及其他n保持原标量检查；新diagnostic analyzeReference与production analyze共用原finish scalar formula。root API与编码功能范围不变。QA helper提供独立u128/i128对比，测试入口覆盖本次关键安全约束；运行结果仍待父代理验证，不以静态审查替代编译/测试。

## 任意u32输入的数学与循环证明

`src/zstd/literals/frequency_reduction.zig:14`定义8个u32频率lane和8个u64累加lane；`:27`从offset0到248按8递增，共32chunks，没有tail漏项或越界。

任意current[i]、previous[i]均在0..2^32−1：

- 各totals lane恰好累加32个u32，最大 `32*(2^32−1)=2^37−32`，严格小于2^37。
- 全256项总量最大 `256*(2^32−1)=2^40−256`；8lane的u64 add reduction同样安全。
- 每项negative=`prior-min(prior,current)`在0..prior，最大2^32−1，因此每negative lane与总negative也分别<=2^37−32、2^40−256。无需借用合法128KiB域才能证明中间安全。

关键顺序是`:30`先数值拓宽now为Wide，然后`:31`累加；负差`:35`先在u32 lane计算安全表达式再拓宽`:36`。它没有在u32中累加，也没有signed位重解释。`prior-min(prior,now)`与max(prior-now,0)完全相等，且min始终<=prior，所以对current>previous或maxInt值也不会下溢；避免了先计算一个可能下溢的select分支。

`:45`的reduce结果仍是u64。完整总量超过cap时，非负current的scalar prefix必在某处超过cap；反过来prefix超过cap则完整和也超过。因此把cap检查移到循环后不改变InvalidFrequencyTotal结果。普通malformed输入最多2^40−256，不可能提前产生标量u64 add overflow；处理全量previous也不会产生vector u64 overflow。

## 支持域、active、alignment 与错误优先级

- `:39`、`:40`逐lane比较now/prior是否非零。`:41`把八个bool mismatch位转成u8，并OR进跨chunk accumulator。最终mask0当且仅当所有256对应符号非零状态一致；并不只检查active cardinality。跨chunk复用8位位置不会抵消某个mismatch。
- `:42`每chunk的current support popcount在0..8，累加usize最多256，对32/64bit平台均安全。
- `:28`、`:29`通过正常u32对齐数组切片载入[8]u32再coerce到vector，未承诺或assert32byte aligned；正常u32 alignment足够。输入必须全部256项初始化，这是函数已有完整数组读取契约，不以malformed数值为由扩大到无效内存。
- `:48`首先检查total>max_total；仅通过后`:49`reduce负差、`:54`受检cast u32。max_total参数为u32，故`:51`total的intCast已受范围证明。

结果的exact error priority与基线compare inspect一致：

| current / previous 数值 | 结果 |
|---|---|
| current总量>max_total；previous任意，包括Dminus>u32 | `InvalidFrequencyTotal` |
| current总量合法；Dminus>maxInt(u32)，包括support mismatch | `IntegerOverflow` |
| current合法、Dminus<=u32、support不同 | 成功Inspection same_support=false，之后Analysis.bound=null |
| current合法、Dminus合法、support相同 | 成功Inspection；继续原i64 Cf drift公式及错误 |

特别是previous全max/current全0会在合法总量之后返回IntegerOverflow，不能被support mismatch吞掉；previous全max/current每项1<<24，则总量2^32先返回InvalidFrequencyTotal。Dminus==maxInt(u32)可成功，下一单位返回IntegerOverflow。

## weighted层合同与状态

`src/zstd/literals/weighted_bound.zig:113`仅在comptime compare&&n256派发inspect256并传固定max_total_frequency131072；false compare的init和任意其他n仍走`:119`原checked scalar扫描。Inspection alias字段/类型与旧私有struct相同。

`analyze`（`:73`）和新`analyzeReference`（`:80`）分别用vector/scalar inspect，再共用`finishAnalysis`（`:85`）。finishAnalysis原逻辑没有调整：先完成mass admission/负差cast，再support mismatch返回null，再Cf cast i64、signed R差、(M−1)*Dminus penalty、受检add/sub、max(Rg,adjusted)和u64cast。

Normal certificate init仍要求至少2active、maxdepth支持容量、合法总量以及 `sum(f)<=trusted_lower_bits<=M*sum(f)` 的数值envelope。标量<=Opt(f)仍是caller前提，归约不凭Prepared.regenerated/unique/以前缓存scalar来跳过检查。publish继续先构造replacement，再整体替换；init/publish error不改旧frequency/scalar绑定。源码diff只抽出原finish公式，未改码长maxbit、M11前提、winner选优规则或root公开codec接口。

## QA helper的独立性与覆盖

`src/zstd/literals/weighted_reduction_tests.zig:6`用u128 scalar循环计算全量total/negative，然后以同域cap与D-u32检查构造oracle。它不调用vector归约、也不依赖原标量inspection的早退循环，能抓到u32/widening错误。`:25`的Analysis oracle以i128计算公式，独立检测原i64中间范围；M是u8、D是u32，penalty乘法自身必在i64范围内。`:39`同时对比oracle、analyzeReference、analyze的**所有字段及exact error**，不只比较bit lower bound。

已读取测试覆盖：

- `:58 wideVectors`：128组LCG频率，support相同/删除，cap正好131072及+1；256*(1<<24)=2^32和全max避免u32归约wrap；同cardinality但不同symbols；empty/RLE与非法支持输入。
- `:113 corruptedPriorities`：previous全max、Dminus的maxInt/超过边界、current非法总量先行、support mismatch时无Cf cast、非法Cf和i64 add overflow。覆盖暴露的certificate field异常而不假设旧频率总量可信。
- `:154 genericFallbacks`：n2/3/4/257和M1/3/11/255，生产generic fallback、snapshot不变、publish invalidsupport/total/cost错误；n256/M1/3/255也用vector compare但原scalar公式保持。
- `:199 misalignedVectors`：current/previous相对于32byte边界偏4/8bytes，实际u32 alignment；正常及2^32 malformed总量。
- `:216 widePublication`：n256 init/publish非法current总量、empty support、invalid scalar、保持旧snapshot，以及最大合法总量发布。

`weighted_bound.zig:145`把contracts挂入模块测试。原tiny exhaustive/weighted成本oracle仍验证Cf数学前提。本轮静态审查没看到本次归约需要新增的必需安全案例缺口；实现者还需确认native Debug/ReleaseFast、32bit x86及root相关测试实际通过。向量源形式不等于已经在每个target生成指定ISA指令，也不自动意味着更快。

## kernel benchmark测量范围

读取 `tools/zstd/weighted_bound_bench.zig`和build.zig接线。它是**完整certificate analyze路径的同process microbenchmark**，不等于exclusive inspector time或压缩API吞吐：

- `:23`生成3shape×64个完整array，generation/初始检查在每次计时pass外；input池每shape64KiB，加certificate约1KiB，随后warm1000 queries。
- medium_support旧support77、dense_support256；inputs除增加freq外也可能删除符号，包含成功same-support与changed-support Analysis路径。
- invalid_totals shape的64array均有总量超过131072（maxInt、全1<<24、首项131072加其他非零项），测的是exact InvalidFrequencyTotal早退路径；scalar可prefix早退，vector仍读取全256。这类结果不可概括为一般合法input speed。
- Cert.init scalar=total（`:31`）是**合法trusted lower bound**：每active码至少1bit，所以total<=Opt。它未建立或宣称Cf是Opt，足够用于两条相同finish公式的性能比较；没有不合法地把任意可行码成本当下界。
- `:47`对所有192个arrays先query scalar/vector，成功比较全部五个Analysis字段，失败比较exact error；这些before checks防止benchmark只测两个不同合同的函数。
- `:90`query每个scalar/vector编译实例noinline；`:100`runtime LCG选择64预生成input，减少常量hoist风险，避免每轮只用固定knownarray。
- `measure`的timed部分包含LCG/update/index selection、input访问、noinline调用、全部analyze检查/原i64 finish、error handling、mix、loop；JSON/output与initial equality在外。
- 5round交替scalar/vector先后，共10 passes；每pass同seed、同iterations、同LCG选择顺序。mix是modular checksum并doNotOptimizeAway，两侧mix相等提供结果消费校验，但checksum可能碰撞，不替代before exact check或独立QA。
- 摘要记录median/min，两侧rawns/order/mix也保存；这是warmed kernel evidence。公开codec比较需父代理单独跑baseline/final14、同wire/queries/源身份及CPU/build/reference记录。

build.zig约5897行添加ReleaseFast bench executable/run step，check依赖它；没有改root API。若工具报告kernel ratio，应描述为“相同输入选择/完整analysis工作负载的scalar vs vector耗时比”，不能宣传wholeAPI相同比例收益、孤立归约ns或稳定跨平台排名。

## 后续交付边界

本报告的静态结论可以供source-ready编译验证使用。父代理负责记录实际QA/target结果、kernel原始round、source稳定性及完整codec benchmark；本审计不重复这些操作。若后续源改动（特别是widening、mask、postloop错误顺序）发生，需要重新核对对应部分。

内容哈希（本次读取版本）：
- `src/zstd/literals/frequency_reduction.zig`: `34ee2d73fb003ae301e9642a9cd61ef366aaccefa856baff2cae56166347eb2b`
- `src/zstd/literals/weighted_bound.zig`: `e45b292daca0a33a5840f21543cf0ae93396db65072ab9aa4562def89ab4a890`
- `src/zstd/literals/weighted_reduction_tests.zig`: `0c7fb8c19c78f707363d46370de39bb9e2d68d1dede4da3fbd694a9ff15f6363`
- `tools/zstd/weighted_bound_bench.zig`: `283e6eb7a2964904573a481443ad8494cf1f7937e562d8e7df25529688a69b6e`
- `build.zig`: `c5bb3b1b261838240ac4fa5c01f3a840caf70614c8c16b3e1a640eaa92818f8a`
