# Literal/winner work-accounting 工厂只读审查

- 工作树：`/home/passchaos/project-z/vort-zstd-work-accounting`
- 基线：`e4bfdd638980d62fb4dc878158994d1471d8f29d`
- 时间：2026-10-25 15:51:44（Asia/Shanghai）
- 范围：已落盘两Cache factory、root ActiveCostCache接线、diagnostic/profile类型、纯统计field用途、外部callbackQA和受检policy合同。没有编译、执行测试/编码/基准、计时或修改源码/Git；唯一写入为此报告。父代理负责source-stable运行、actualsizeof、ELF及公共性能证据。

## 结论

未发现track_work comptime门禁误删成本返回、certificate init/replace、treecache publication、reference observer side effects或Histogram.checked admission。false factory仅将统计Work与diagnostic age字段设为void，并消除统计写入、max/bucket/log2、统计比较；所有codec math/policy/state/error顺序保留。true factory保留原Work布局和计数语义，原Cache wrapper直接映射true factory，现有tests/Profile调用类型兼容。

当前parent ActiveCostCache由mode/profile_work实例化，同一个comptime profile_work guard包住profilecopy/read，因此normalmulti false不会读取void字段，diagnostic true保留全量统计。QA已在src/zstd.zig约31314行注册，不能把纯统计字段删除误说成整体policy/counter删除。实际sizeof已由读取父代理probe结果确认：native tracked6032/untracked5568，x86 tracked5980/untracked5516。三目标QA与完整family也已通过（末节）；本审计未编译或运行，公开吞吐仍未测得。

## 字段用途：统计与策略区分

Base.Work（`single_cost_cache.zig:6`）七个u64记录cost query、plan/tree调用、treehit、symbolproducts、referencecheck/mismatch。在算法内没有通过这些字段决定codecplan、error、缓存或返回值；reference mismatch是反馈，不是当前errorpolicy。

Winner.Work（`winner_cost_cache.zig:9`）16scalaru64和18+16bucketu64记录bound/refusal/refresh/error/mismatch观察。certificate_age仅用于max与agehist，不参与Cf可信性、证书可用/过期、publish或prune选择。因此age field可在false配置完全省略，不是把真正certificate历史删掉。

保留的不纯统计行为：

- CutHistogram.scanned_bytes/update_count（`cut_histogram.zig:50`..`:51`）受检溢出可返回IntegerOverflow，且拒绝在ranges/frequencies mutation前。这是原admission/error合同，两模式均保留。
- weighted.Certificate.frequency snapshot/trusted scalar、bitwidth/total checks及i64 drift都是策略数学；没有diff或comptime gate。
- tree_entry/key/nullablelen确定exact价格缓存，是功能state；保留。
- Base streams dot checked multiply/add、endbit rounding、u16stream null、Header及sequence errors全部保留。
- reference callback有外部observer副作用，不能以Work关闭而删除调用；两路径均保留。

## Base工厂逐项门禁核对

`single_cost_cache.zig:59 Cache(Codec)`直接返回CacheWithAccounting(Codec,true)；新factory`:66`的work为 `if(track_work) Work else void`，其余histogram/block/tree_entry类型未改。

查询、failedPreparation、prepared查询三个costquery increments分别在`:85`、`:92`、`:103`由comptime保护；原calculate/checkReference/return在外。错误仍先准备literal，再序列helper，raw/RLE/Huffman selection、null/error fallback不变。

`:109 checkReference`的@hasDecl在track gate外，`:114`无论true/false都调用Codec.referenceCost。true保留旧equal-error/value比较和mismatch计数；false显式消费成功/error结果，不保留反馈。不引入callbackerror传播，也不漏callback side effect。

plan、treehit、treeserialization、streamsymbolproducts的统计增加仅各自一行comptime gate（`:172`,`:192`,`:196`,`:212`）。实际planFromFrequencies、treeLen、成功/null tree_entry发布、streamslen dot/checkederror仍原控制路径。void模式不存在未门控self.work.field读写。

## Winner工厂逐项门禁核对

`winner_cost_cache.zig:38 Cache(Codec,mode)`直接返回truefactory；`:45 CacheWithAccounting`把inner同步实例化exact.CacheWithAccounting(Codec,track_work)，Work/agefalsevoid，certificate保持实际类型。

- query/age增加、equalityretained、wouldreject/rejected计数有comptime gate；实际lower计算、would_reject predicate、modeprune、verifyRejected调用及returnnull不在统计gate中（`:71`..`:90`）。
- actual payloadCostPrepared（`:93`）始终执行于原非prune路径；随后boundviolations/false统计比较整个gate删除，未覆盖actual计算/return。
- 非wouldreject成功weightedbits才Certificate.init（`:104`），init error仍returnactual.len；成功replacement（`:108`）在gate外。仅diagnosticage reset与refresh count被门控。shadow仍不从wouldreject query刷新真实证书。
- payloadLowerBound的raw/small/nocertificate/analysiserror/supportmismatch统计写门控，但各自returnnull/真实分析保留。bucket/negative/max/age代码整个`:135`..`:142`comptimeblock false被排除，既无数组storage又无log2/bucket计算。payload math跟随原公式。
- verifyRejected（`:175`）@hasDeclreference与实际调用`:178`在track gate外；true比较lower/cost/incumbent并反馈，false只消费回调result。callback返回error仍按原finder语义不可更新，不生成虚假成功cost；关闭统计不删除回调。

每个comptime gate只包统计或仅为统计计算的局部表达式。没有gate包Certificate.init、treeLen或payloadreturn；true/falseselftype中的void字段仅在truecompilebranch引用。

## Root/profile类型与footprint

`src/zstd.zig:23317`ActiveCostCache=`winner.CacheWithAccounting(SingleLiteralCostCodec,mode,profile_work)`，沿用原cacheadmission：cache_costs、unindexed、block超过exactmatcher threshold且<=标准block最大值。normalmulti传profile_work=false，diagnostic传true。`:23323`的profiledefer同参数编译条件，inner.work/bound_work仅true实例被读取；finder/profilecounter分支仍同guard。

公开diagnostic Profile本身仍有原literal.Work/winner.Work结构，Cache wrapper仍true，所以其JSON计数/尺寸口径保持。原truefactory参数与旧struct fieldorder/类型一致，预期native6032继续；两个bool配置对codec状态不同layout是内部缓存实现细节，不修改encode/decode/publiclimits。新增benchmarkLiteralCostStateBytes只提供诊断sizeof入口。

静态大小推导：Base.Work7×8=56bytes；Winner.Work(16+18+16)×8=400bytes；age8bytes，共464。若原native6032共同fieldpadding不变，false=6032−464=5568。u64 aligned字段被void去除，true布局与原相同，但精确Zig layout/target差异应由父代理actualsizeof与target构建确认。初审时这是静态预测；末节已读取实际probe确认，但仍只表示该缓存类型sizeof。

## 外部observer QA与当前注册

`work_accounting_tests.zig:18 ObservedCodec`在每个callback记录kind、args、成功/error、frequency或bits到test-owned externalLog；这些globalobserver只用于测试，productioncache不retain。falsework fields永不读。相同输入执行on/off后deepcompare完整external logs、结果/错误、histogram、tree_entry、certificate，以独立观察证明回调/功能状态未被门控。

已读contracts覆盖：

- exact costs/prepared结果、不同cuts/R<64/invalidcuts/ML2、treekey状态及reference callbacks；falsework type为void。
- shadow/prune都有certificate seed、wouldreject、support变化、loose更新、invalidcut/ML2与equal-costlongermatch retention；compare真证书、actualcache state和callbacks而不读取falseage。
- nulltree、rawRLE、小输入不生成证书；HeaderFailureCodec在prepare后error，两mode回调logs同且Histogramupdate一次，保firstliteralerror/ref合同。
- true Cache wrapper与explicittruefactory类型相同/状态相同；统计饱和max保持不影响结果和原saturation行为。
- finder多suffixtrue/false与原referenceFinder winner一致，externalcallbacklogs相同，包括reference；防止false被@hasDecl错误门控或跳过pruneoracle。
- histogram.scanned_bytes=max后的prepareoverflow，两配置同IntegerOverflow且range/frequency state不变，明确checkedpolicy计数没删。

`src/zstd.zig:31314`已挂入“zstd work accounting preserves exact costs callbacks and checked admission”调用contracts。当前脚本state_probe使用真实Codec sizeof入口；实际输出及三target/source-stable运行、ELF机器码仍由父代理确认。最终QA/probe执行结果已读取并记于末节；本审计没有执行这些命令，也不声明公开性能提升。

后续应核对：nativeDebug/RF/x86实际void路径编译和callbacktests，trackedprofile与旧wire/counters/6032一致，untrackednormalwire相同/实际5568；source+exe稳定公开benchmark不受编译干扰。只有源码comptime branch可证明false不生成统计代码语义，具体ISA/codegen、吞吐增益与热点因果要靠ELF和实测；不把未经验证的指令计数或partialkernel倍数作为APIclaim。

## 本轮源码哈希

- `src/zstd/literals/single_cost_cache.zig`: `0a81c9834f9dd8006f2cab125fba230533b9eb8ff0f8720b39a70b6e29435f51`
- `src/zstd/literals/winner_cost_cache.zig`: `584446c9c72555c2c9ad71dd0f43c7fe2a5119b2475b5dc0f31d3bc6b0040f78`
- `src/zstd/literals/work_accounting_tests.zig`: `74fa21f76d28662bfd0afcf21f8fd713d0f4162d649d53ec8800f9a253ccb204`
- `src/zstd.zig`: `cc29696a1fca71cf134210a12a197071fc2bad25801f528ad8b7140e29028a59`


## 冻结版本、实际QA与sizeof/ELF事实（2026-10-25 16:00:01 Asia/Shanghai）

最终功能提交 `a8defd42 perf(zstd): specialize production pricing without diagnostic Work` 基于e4bfdd63。当前两个cache、QA和src/zstd.zig的hash全部与本报告初次审查hash相同；因此静态gate检查、error/reference callback合同与冻结测试对应同一源码。原Cache wrappers仍true，生产unindexedmulti使用profile_work=false实例，诊断profiletrue保留全量统计；不修改policy、levels、quality或默认anchor关闭条件。

### 最终运行验证与回调范围

读取现有accounting-debug/releasefast/x86 result：native Debug、native ReleaseFast、x86-linux-musl ReleaseFast的“zstd work accounting”filter均exit0、source_stable=true、11/11。读取complete-family/result.json：native ReleaseFast `zig build test-zstd -j2` exit0、source_stable=true、5/5 steps、1102/1102 tests通过。11包含imported helper tests，不是11个唯一on/offcase。

QA并非只验证successcost：外部observer日志记录reference与codec回调的args/value/error，包括invalidcut、ML2、nulltree/RLE/small输入、prepareheaderfailure、shadow/prune拒绝和equalcostlonger保留；on/off每一步comparison检查完整error/optionalpayload和外部logs一致，功能histogram/tree/certificate state一致。falseconfig虽不保留reference_mismatch feedback，Codec.referenceCost仍被调用并消费success/error，observer side effects相同。原Histogram.checkedscanned/updateoverflow测试同IntegerOverflow且mutation拒绝前state保持；这些行为不会随Workfalse被省略。

### 实际对象大小与边界

读取state-native/result.json/run.log、state-x86-final/result.json/run.log及state-analysis.json；相同最终源码，exit0、source_stable：

| target | tracked缓存sizeof bytes | untracked缓存sizeof bytes | 差值 |
|---|---:|---:|---:|
| native x86_64 | 6032 | 5568 | 464 |
| x86-linux-musl | 5980 | 5516 | 464 |

差值对应Base.Work56+Winner.Work400+age8，验证了静态预测。state-x86-final明确root与module都为x86 target；state-analysis排除了早期mixedtarget probe，不能使用早期错误身份。

这些是特定cache object的@sizeOf；不等于全函数stackframe、RSS、heap峰值、totalworkingmemory或alloc event减少。诊断trackednative仍6032，对外profile.cache_state_bytes保持原tracked口径；正常untracked无Work storage。实际memory/allocator行为由父代理独立资源审计处理，不凭sizeof代替。

### 已读取的独立生产ELF差分

读取accounting-elf.md/json，scope限定两个指定native生产ELF的默认unindexedmulti exact emitter符号。old/new执行文件hash分别5d14ea68.../d32df645...，新记录sourcehash与当前冻结源码相同。独立审计以源码、nm、真实caller及asm确认默认`.prune,false`而不依据未找到的独立payloadForWinner符号猜测。

该报告统计旧默认emitter21个饱和Work更新站点、两个Workbucket LZCNT；新对应0/0，符号代码大小11263→10263bytes。它同时核对新机器码保留checked Histogramadd/overflowgate/successcommit、Certificate frequency/scalar/validflag发布、streamcheckedproducts/treecache及emitter调用。

这些是独立ELF报告的**静态站点/codegen**事实，本审计没有重新构建或执行/计时，也未重新扫描整个ELF。不能变成dynamic执行次数、zero-cycle开销、整个library无inc/log2或全target相同机器码；诊断true实例仍统计，其他Huffman/format操作仍可使用bit指令。实际资源审计的memory结果不在这份sizeof/ELF结论内。

### 未完成性能范围

本报告最终更新时没有新current14 public timing结果；父代理仍跟踪check，随后独立分析公开性能。baseline14只是旧对照，不能算本变更after。故本审计不宣称吞吐提升、wire/counters已在新的全部公开corpus差分、行业获胜、零开销或更低heap峰值。下一步将已有功能/ELF证据与实际profile/publicwire和隔离benchmark结果按各自source/exe身份结合。
