# Dense Huffman benchmark与计数静态审查

审查时间：2026-10-25 18:45:11（Asia/Shanghai）。工作树 `/home/passchaos/project-z/vort-brotli-context-cache`，分支 `work/br-tree-cost-20261025`。只读源码、构建配置、标准库和父已完成的功能/正式micro/public/profile/paired证据；以不计时的独立标量算术重建fallback自然树最大深度并重算结果。未编译、执行benchmark/codec、计时、修改源码/工具/Git。当前新增授权文档为`docs/performance/industry-gap-audit.md`，另仅写本指定报告。核心reference/alias及派发已落盘，最终QA与父正式测量已完成，完整证据复核见末节。

## 结论

工具比较合同可接受：四族各32项，预先比较reference、ordinary、profiled三份完整256长度数组；noinline完整Alphabet长度入口的频率拷贝/scatter，以及全部256结果消费都在两路相同timer内。它测量完整长度构造局部成本，不等同于完整prefix字节序列化或公共Brotli编码吞吐。

父已解决首轮提出的两项工具问题：module root改为src内薄wrapper，untimed preflight加入真实失败/fallback派发检查与频率pool哈希。reference method、Profile alias及256派发现已落盘；父功能smoke实际构建/运行3/3成功。mixed频率族也可能有自然深树，最新工具只强制ties为0、depth_fallback为32，mixed和medium记录实测fallback，避免按族名称假定无fallback。JSON保存五轮原始值与独立median，未显式输出min，min可从raw rounds重建。

## 输入、预检与计时范围

- `tools/br/dense_huffman_bench.zig:8/:20/:32`，每族32项，四族共128项，运行期gpa存储。固定seed/LCG生成，alphabet构造在计时外。`:47`乘149为奇数，活跃项排列到不同原byte symbols，检查scatter而非只查compact rank。
- `:34`前三族active=`129+(index*17)%128`，32个不同值，实际范围129..256；不是129..256每个大小。最新medium_control用`65+(index*13)%64`，实际32项65..122，作为未改中等路径control，不声称覆盖每个65..128大小。
- `:41..45`dense_ties频率1..8，dense_mixed为1..4096，depth_fallback为34项Fibonacci加剩余1，control为1..1024。独立标量自然Huffman重建32个fallback权重得到最大深度20..21，全部>15；最大频率5,702,887，最大总和14,930,573，小于u32。此算术不是codec执行或性能测量。
- `:51..57`reference和ordinary逐项比较完整256 u4数组，再与profiled结果逐项比较，并核Profile.calls==1、package_merge_calls==failures。`:58..61`只强制depth_fallback族累计32次package、dense_ties为0；mixed/medium允许实际失败并记录，不把“全部其他族0”当合同。父已完成的功能smoke实际observed：ties0、mixed1/32、fallback32/32、medium0；全128组exact/preflight通过。该smoke使用iterations=1，只证明工具/派发功能，不是正式micro性能证据。
- `:50/:60/:85`逐项哈希初始化后的`[256]u32 frequencies`原始字节，32输入连接构成每族input_sha256；不哈希Input/Alphabet结构或未初始化padding。哈希按目标端序，不能跨不同端序直接当相同字节pool；provenance.target_arch及冻结源码绑定重建。算法生成及哈希不在timer内。
- `:93..94`noinline encode分别调用reference和ordinary codeLengths，包含返回长度初始化、compact频率拷贝、长度算法、必要fallback及scatter；不含alphabet收集/排序、复杂prefix RLE/header/payload写出或完整codec。

## 两路同scope、DCE与统计

- `:96..105`每次measure先重置相同pool选择seed；before/after包围整个迭代循环。两路相同iterations、相同pool选择序列；timer包含pool选择、noinline长度入口、全256项mix，不含生成、预检、JSON输出或排序。
- `:101..103`每iteration使用运行期池索引，全部256项用`(bits+1)*(index+1)`消费；`:106`doNotOptimizeAway，`:78`两路mix相等并在JSON保存。mix可碰撞，不能替代preflight逐项oracle；静态源码不等同于优化后机器码无hoist/CSE证明。若父需要机器码证据，应绑定最终ELF独立核查。
- `:70..71`reference和candidate各128迭代暖身，reference先。`:75..81`正式五轮按R/C、C/R、R/C、C/R、R/C交替，JSON显式记录order；这是一个进程内五轮，不是五个独立进程。3次reference先、2次candidate先的有限设计不支持显著性或稳定排名声明。
- `:83..86`五个raw rounds均保存，并独立排序输出reference/candidate median。最小值可从raw rounds重建，目前无显式min字段；如果需要JSON同时提供min，排序数组[0]即可，否则报告只称median。独立median比不等于逐轮比的median/geomean。
- 两路都承担相同mix/循环成本，可能稀释算法差异；这仍是明确定义的完整length调用成本。局部点比不能直接宣称公共encoder收益、统计显著或行业领先。
- `:105..107`awake Duration的i96转换u64，沿用正常非负计时假设；没有独立timing_complete/溢出状态。默认20,000迭代为有限微测范围，不是任意无限运行保证。

## 参考API与构建

- `dense_huffman_bench.zig:94`调用的`Alphabet.codeLengthsReference(frequencies: *const [256]u32) ![256]u4`现位于`command_plan.zig:128..129`，选择Core(false,false)，ordinary为Core(false,true)；`:193..208`dense_fast为false时沿原fillTreeLengths(...,256,...)，true尝试256 builder，失败仍调用相同旧path。<=128旧路和简单树/空集行为共享，保持rank/tie/scatter。Profile alias位于该文件`:5`。不再保留旧“缺参考method”的审计项。
- `src/br_prefix_bench.zig:3..6`导出PrefixAlphabetFor、alphabetFromFrequencies和CodeLengthsBuildProfile；`build.zig:3249`模块root现位于src，command_plan的../../huffman等相对imports处于同src边界内。父实际构建/运行3/3成功，没有outside-module-path错误，首轮root-path风险已解决。wrapper没有导入src/root.zig或完整库根；本审计仍未穷举实际编译输入。
- `build.zig:3241..3259`工具和command_plan module均ReleaseFast，提供run-br-dense-huffman-bench；`:7162`纳check。共享benchmark_provenance module在`:268..272`也固定ReleaseFast。
- `tools/benchmark_provenance.zig:7..21/:62..78`输出Zig/target/CPU/affinity/单线程policy、实际exe SHA及argv；工具另输出schema/iterations/pool32/exact标记/各族inputhash和fallback_inputs。工具不自行强制pin CPU，父需采用实际command/affinity与quiet窗口验证。
- pool哈希、exe哈希和provenance本身不证明源码期间一直稳定、无并发编译或外部依赖完整性；父另存SOURCE_READY源码/实际构建输入/quiet窗口证据。

## literal profile计数适配

`tools/br/literal_context_profile_gate.py:160..161`已改为small_huffman_calls=sum(active_buckets[1:])，package_merge_calls=small_huffman_failures；`src/br/encoder/literal_context_split.zig:1170..1173`也把bucket5（129..256）纳入small calls。全calls/bucket总数、uncached+cachemiss评分及既有prefix/Huffman细时间守恒保留。

等式前提：Alphabet.codeLengthsProfiled对所有5..256非简单树恰尝试一次small builder；失败恰执行一次package merge；builder单记calls/failures，caller单记package。现256派发、同旧path fallback与Profile alias已落盘；功能smoke核calls1/package=failures及实际mixed深树。最终native Debug/ReleaseFast/x86 dense各21/21与旧literal profile gate/smoke运行已由父完成，本审计只读核对结果；不保留此前“第二处断言pending”的过期结论。

## 父已完成的功能smoke证据

`/tmp/vort-br-tree-cost-20261025/micro-build-fixed/result.json`记录父命令`zig build run-br-dense-huffman-bench -j2 --summary all -- 1`退出0；`run.log`为3/3成功、iterations=1、all_exact_lengths_equal=true，四族fallback_inputs依次0/1/32/0。工具、wrapper、build及command_plan对应source_before/source_after哈希一致。该tiny raw timing不作性能证据；后续正式20,000迭代micro与该功能smoke区分，见下节。

## 快照与后续

本报告最新工具快照（2026-10-25 18:31:32）：

- tools/br/dense_huffman_bench.zig：`bf6109833c756ee1cbf3503d45084e3122a09e028327cf424cc6bef54d27824c`
- src/br_prefix_bench.zig：`5a875342d4554c1778982716d0a92b92e50c839d633320c2378d9ecd763aee67`
- build.zig：`f60fcbf6f7ffe00f9dc7669757cf1ee7351343675c5c14ab2f73b7e6833af937`
- tools/br/literal_context_profile_gate.py（初查未再次变更）：`666c0a6d3e1994344f834acf05ef8b9e6f154ba9f333bbb4773d05866170524b`

核心当前版本：command_plan `173cf7e6bc7e784fab80201f5cb696b0f870f4843de35e5999179439e6d9d9f9`；small_huffman `b23a30082ccce63b785051b61831ab4a297e09c152db6825bd76eed787c99bf7`；literal_context_split `bc8bc8bd60cfe72ba884167cb59ed67e83c217e9046452c7e4db47050abbd4ab`。与最终QA/micro/public/profile/paired对应快照选择核对通过。

## 最终证据独立复核

### 正式micro与公共ordinary结果

- 父`microbench/samples.json`为20,000迭代、每族32pool、五轮相同进程交替，`gate-result.json`valid。独立重算四族median及reference/candidate点比：dense_ties **16.340477x**，dense_mixed **8.518460x**，depth_fallback **0.959412x**，medium_control **0.983286x**。失败fallback/控制路径的较慢点必须保留，不把所有族说成提升。正式meta source/exe稳定，compiler observations with process=0，不能用此声称全部系统噪声为0。
- 独立重读baseline14/public14原始五轮，核14个输入身份、settings和完整wires（两库长度/hash）一致，重算ordinary version几何比 **1.230502836087**、reference几何比 **0.032977087479**，与analysis相同。版本14/14首轮点提升，reference吞吐0胜。Mozilla100.170462→59.872755ms，SAO158.803697→92.542811ms。这是当前冻结64KiB q8/generic设置，不推广所有quality/平台/解压或RSS。
- 父`paired14/result.json`六进程exit0，顺序old/new、new/old、old/new，每进程14输入×5轮。对42个per-input/process-pair点比独立重算几何比 **1.214583121679**。Mozilla三点1.748352/1.678830/1.669785，SAO1.671689/1.710574/1.693266，source1.028755/1.025772/1.026259。Webster0.982081/0.991895/1.028495，故不能称每行每重复均胜。已记录source/输入/reference frozen及742次compiler observations中0次进程；不作统计显著性、置信区间或广泛稳定排名主张。

### 完整工作计数与profile时间

- `analyze.py:12..20`原比较列表已覆盖提案shape、suffix/cluster/search、treecalls/uncached/activebucket等，并逐详情检查small=sum(buckets1..5)、package=failures；它未穷尽所有细count字段，因此本审计另直接遍历old-restored/new的70run×2detail共**140条实际详情**。
- 独立比较每detail origin/variant/command_count及全部非time字段（仅允许small_huffman_calls、small_huffman_failures、package_merge_calls改变），无不一致。这也涵盖scope/mode cache矩阵、uncached矩阵、cold/conflict、simple/complex与prefix token计数等原analysis未逐一列出的字段。全140条验证calls=cachemiss+uncached、bucket和=allcalls、smallcall=sumactivebucket[1:]、failure<=calls、package=failure。该结果说明保留了实际提案形状/评分请求与搜索工作，变化是长度构造派发，不能把新统计方式当减少tree请求。
- `quality_profile_gate.py:114..140`继续核uncached与cache区别、成功event/detail覆盖、baseline无mode、suffix2*scores、default无baseline/suffix cache、逐mode/scope守恒；`:141..`按direct-child inclusive从parent扣除。新dense派发计数由analysis/旧focused literal gate独立核；不把Q8 gate本身说成穷尽所有Huffman计数。
- Mozilla的lazy/optimal tree_lengths独立median20.440211/22.243927→2.192731/2.416199ms，旧796/830个dense package构造变为0，纯tree/scorer次数保持。source对照无bucket5密集树，length median0.505578/0.549230→0.529187/0.575979ms，保留较慢细阶段。所有细time为嵌套的独立median，不能相加或替代ordinary measured收益。profiler clock/shape/count开销不归作普通编码速度。
- Profile事件的wire/config/selection语义比较通过，不以全Profile深相等作证明；该profile只输出proposal shape，没有context_map本体。wire/selection语义和既有codec QA提供输出验证，本分析未将shape相等说成全部内部candidate map数组逐项oracle。

### 已完成验证与最终绑定

只读核父报告：native Debug、native ReleaseFast、实际x86 dense各**21/21** exit0；Brotli完整family **1423 passed、1 skipped、0 failed**；check **174/174**；legacy focused profile gate及smoke **cases21/positives4、10/10 steps**。它们对应source_before/source_after稳定，未经本审计重跑。

当前八个选定源码（tool、wrapper、build、command_plan、small_huffman、dense_tests、literal_split、legacygate）与上述三个dense QA、family、check、micro、public14、profile14的after快照逐个一致；paired14采用两工作树嵌套snapshot，candidate map的八项也一致且both-worktree before=after。文档不属于这些执行的src/tools/build snapshot，不将后续文档写入说成测量源漂移，也不声称旧所有Git内容未变。

`docs/performance/industry-gap-audit.md:218..245`已新增bounded dense增量及链接`brotli-dense-huffman-x86.md`，含首轮/三pair、Mozilla/SAO、Webster较慢点、四micro族、source较慢细阶段及全部已完成验证。现有行业最佳目标仍开放，reference的14/14吞吐优势明确保留。下一步由父整理新doc、最终handoff和后续更广测试；本审计没有新增compile/timing/Git操作。
