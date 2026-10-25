# Paired anchor hash/lazy length cache 只读审查

- 工作树：`/home/passchaos/project-z/vort-zstd-anchor-cache`
- 基线：`9cc8c47735a197bbc18956a4dc8e8464033c84cb`
- 初次审查完成时间：2026-10-25 15:33:47（Asia/Shanghai）；最终更新见末节
- 范围：已落盘borrowed cache、suffix scanner接线与真实finder QA、caller storage准入、总预算/WorkingAllocator未来可选分配约束、现有diagnostic实测身份。没有编译、执行测试/编码/基准、计时或修改源码/Git；唯一写入是此报告。父代理负责实际验证和生产启用判断。

## 结论

当前核心“按second缓存长度”的证明成立，前提是保持原suffix scanner每hash的pending parity、顺序和guard位置。落盘scanner只替换hash读取与exact extension两个表达式，未改变pair consumption或cost/winner比较。core init容量/范围/nonoverlap错误均发生在任何Hasher调用或mutable fill前，正常alignment与u32 length资源边界安全。

当前默认production通过reuse_anchors=false包装，无新增anchor heap分配，只有显式diagnostic启用。cache核心借用caller slices；当前diagnostic API自己用caller allocator申请两个数组并传播失败，而不是optional失败后fallback。未来生产可选allocation必须在首costquery前完成preflight，并解决shared total-budget sticky拒绝标志污染；不能直接吞allocation失败再认为错误/event计数完全不变。

现有3input×5轮每setting诊断输出及旧work一致，局部耗时改善约1.4%..1.9%，不是公开压缩API实测或全平台收益。源码和QA仍在并行修改，运行snapshot与最终回读hash必须按下方epoch区分。

## 同一second的全局相邻前驱证明

固定hash bucket h，在完整immutable block中所有有效8byte anchor位置排序为q0<q1<...。从start_min开始的suffix扫描删除的仅是该序列的前缀，因此遇到的bucket序列为qk,q(k+1),...，没有中间anchor跳过。

原scanner每suffix初始化pending=false，遇到bucket的第一项存predecessor并pending=true，下一项取得该predecessor并先pending=false，再做candidate/collision/length guards。因此它配对(qk,q(k+1)), (q(k+2),q(k+3)),...。任意被配对为second的qi，其first必为全局相邻前驱q(i−1)。suffix reset可以改变哪些qi为second，但不会改变某qi一旦为second时的first。因此 `(first,second)` 是second的唯一函数，可以把deterministic exact duplicateMatchLength缓存为lengths[second]。

这不允许预先按wholeblock parity过滤pair：从q1开始suffix必须配(q1,q2)，不能沿用wholeblock的(q2,q3)。也不能把hash碰撞的0..7短匹配忽略pending消费，或把不合格candidate在读取hash前单独跳过。当前 `src/zstd.zig:30462`包装内保留了：每suffix新pendingfalse、逐position hash、取得predecessor后pendingfalse、所有原guard/len<8/CannotBeat/costcatch/strictwinner次序。break提前结束整段扫描，不跳过已经观察到的中间anchor。最末端maxlen guard在pending被消费之后，因此也不破坏相邻证明。

core `paired_anchor_cache.zig:28`..`:38`明确规定相邻canonical15bit hash pair、immutableblock/hash、同一个Extender、不能跨worker共享mutable lengths、reinit使旧view失效。`:94`只assert范围/order/equalhash，不重新扫描adjacency；相邻前提由唯一当前scanner保证。它不是任意predecessor或indexed matcher的通用cache。

## 核心数值、读写与存储准入

8byte anchor有效位置数M=max(0,N−7)，N<=131072，M<=131065。hash u16只保存当前canonical15bit key0..32767；exact length<=N−second<=131071，远小于u32 max sentinel。未知值maxIntu32不会与合法长度混淆，0..7碰撞长度也是可缓存成功值。

`Cache.init`（`:55`）先blockcap、hash/lengthcapacity，再对**完整supplied slices**做checked byte length和pointer+bytes Region运算（`:60`..`:64`），检查三组halfopen range两两不重叠，包括多余capacity区域。emptyregions不重叠，usedcount0不写或调用Hasher。workspace 6*M受检，然后才构造view、逐positionHasher写u16与unknownlength（`:73`）。因此函数返回的四种errors都beforemutablefill/Hasher。invalidHasher超15bit、invalidExtender/adjacency是caller contract violation，不是可恢复error；固定productionHasher是原duplicateHash8。

正常u16/u32 alignment即可，无SIMD alignment要求。hash读取只在position<M，extension确保first<second<M，所以两侧8byteanchor读取合法；Extender最大边界N−second同时保证first+length也在input。cache只写hashes[0..M]和lengths[0..M]，sparecapacity保持。长度第一次miss后存，hit不调用Extender；work饱和计数不会wrap。

两独立数组的payload请求为2M+4M=6M，最大786390 bytes；work.workspace_bytes排除unusedcapacity/cachemetadata。未来单块布局若base align4、先hashes2M再lengths4M，u32边界需0或2bytepadding：storage_bytes=6M+pad<=786392，最大M131065为odd需2pad。应申请完整合并capacity并按原始buffer释放，不能用payload6M替代allocationcapacity预算。core本身无allocator，不会在state中隐式申请此空间。

## 当前接线及失败时机

默认 `emitMultiDuplicateMatchCompressedBlockProfiledMode`委托WithAnchors(...reusefalse,null)，默认`findBestDuplicateMatchHashedImpl`也委托reusefalse；single/indexed/general quality/level/limits维持原路径。true只有explicit `benchmarkNativeMultiDuplicateAnchorProfile`通过unindexedmulti诊断进入。成本cache依然按原blockadmission，pricing/scorer使用原exact或已证明winner下界，不改变candidatequality。

当前diagnostic（`src/zstd.zig:19522`读取位置）先合法64..128KiBblockadmission、resetprofile，接着try allocator.alloc(u16,M)和alloc(u32,M)，各成功后注册deferfree，再Cache.init，最后进入multi/scanner。第二alloc失败释放第一，init失败释放两块；发生在任何costquery和emitter输出前。OOM直接返回，未实现optionalallocation失败fallback。当前cacheinit参数来自allocator disjoints，因此mapInvalidBlockPlan为diagnostic范围内合理的异常处理。

借用ownership准确含义：cache核心borrowscallerarrays；这个publicdiagnostic helper是callerallocatorowned两个临时数组，工具timer包含allocation、hashbuild/lengthinit、全部suffixqueries和emission，free也是调用返回时defer路径。未经单独API设计不能声称caller提供预切storage的诊断签名已存在。明确诊断启用时allRLE也可能先build再早returnfalse，只影响诊断成本，不影响质量。

## 预算与未来optionalallocation的真实限制

`zstd/encode/total_budget.zig`alias共享requested_heap_budget；普通默认Lease在无cap/profile时保持callerallocator（requested_heap_budget.zig:32），有cap/profile时State ledger计requestedheap，而非RSS/stack。

已读路径：

- `io/working_allocator.zig:18`allow cap拒绝后hit_limit和last_failure_was_limit=true，拒绝不改live/peak；successadmission在`:33`清last_failure，实际backingalloc成功才changedlive，第二块失败时free第一live归零。hit_limit仍sticky。该简单workspacepolicy常用于HQ，不能为optionalanchor添加新的必需qualitypolicy或以fallback改level。
- shared `requested_heap_budget/state.zig:47`拒绝会sticky hit_limit/last_failure=true；`:90`alloc、resize、remap成功/physicalOOM不会自动清这些operationflags，设计刻意让并发sibling拒绝保持。
- `requested_heap_budget.zig:65`beginOperation仅coordinator可清；borrowedlease调用不会清。现有tests明确要求child成功后拒绝flag仍保持（tests:47..:71）。内层optionalcache不能重置owneroperationflags来掩盖自己的尝试。
- `total_budget/entry.zig:64`根据last_failure_was_limit把OOM映limit；`src/zstd.zig:7726 mapScopedAllocationError`还按stickyhit_limit映射。若未来optionalcache实际allocator请求因cap拒绝，吞OOMfallback，随后必须baseline分配physicalOOM，可能把原OOM误报WorkingMemoryLimitExceeded。即使live/peak正确，errorclassification与hitlimit事件已变化。
- shared externalreservation（`:12`）也通过allowedLocked，失败仍污染stickyflag；它虽能在成功reserve后physicalOOMdeinit回滚reserved/ref、不提高peak，不能当作无副作用失败preflight。

因此当前borrowedcore/显式diagnostic没有productionoptional失败问题；未来启用一次可选分配需要独立审核：在firstcostquery前决定reuse/fallback，预算不够时避免通过会置stickyflags的allocator拒绝路径，或者提供有明确operation/sibling合同的optionaladmission API。简单snapshot剩余容量检查在并发sharedledger中可能竞态，不能当作原子reserve；不能绕过带预算allocator用另一heap，也不能调用borrowedbeginOperation改变outerflags。

若请求成功再进入cache，缓存live应与其他state/outputallocation同时计peak；freeall才返回baseline。资源不足fallback必须使用原candidate枚举/评分/quality而非降低搜索budget。allocationevent可能多一次failed或success请求，即使输出wire不变；公开event/budget合同须真实定义并测试，不能宣称与无cache完全相同的allocator调用数。

## QA源码与待确认运行

core `paired_anchor_cache_tests.zig`提供独立byteassembled canonicalhash、directextension、suffixpendingtrace；覆盖每suffixstart/allcollision、globalpairvsresetpair、0..7shortcollision、最大131071/65536/65535长度、sentinelhit、reinit、N0/7/8/32/4097/65535/65536/65537/131072/invalid131073、两种capacity不足、三种storageoverlap/unusedcapacityoverlap、input/hash/lengthguards与normalunalignment。

真实 `paired_anchor_finder_tests.zig`现已落盘并在主约31177行注册。Trace对每costquery记录prefix/offset/match/tail/incumbent/cost/error、certificateage/refresh、queries/huf/wouldreject/rejected；shadow/prune两mode对4097/65537多suffixcompare uncached/cached完整winner、events、work、certificate。它构造真实hashcollision<8、注入确定costerrors以及allrepeated输入；最后从wholeblockhashposition逐项重建previous，核对每publishedlength。注入error发生在costcallback，不能证明futureallocation失败fallback。

现有cache-debug/releasefast/x86 result各exit0/source_stable/1pass（读取证据）。最终读取finder-debug/releasefast/x86 result已确认当前snapshot各13/13通过，含真实suffix trace与诊断allocationfailure测试（详见末节）。必要后续：完整family/check完成、128KiB全multiwire与更宽corpus收益对照；未来optionalheap仍需cap精确/onebelow、成功free、physicalOOMafteroptionaldenial/共享sibling分类测试。

## 现有diagnostic实验及epoch

读取 `experiment-result.json`、samples与analysis：同process3input×5轮每setting，共30rows，modeprune，按noanchors/anchors交替；source_stable、exit0、compilerobservations128/withprocess0，executable SHA256=`c6382712b17036e8dfd92c9d2bf3936fd4baccddf9583e78ed41dada65fc2424`。

独立比较全部rawrows，每inputbefore/after各5，wirehash唯一，剔除newanchorwork/storagefields后existingwork全部exact；XML/MR/source成本query与选择、histogram、certificatebound计数无变化。64KiBpayloadworkspace为M65529×6=393174；cachedqueryhash7704668/6948504/3849234，extensionmiss49943/38397/38293、hits3456817/2770486/1542003。

| 输入 | uncached median ms | cached median ms | diagnostic stage ratio |
|---|---:|---:|---:|
| XML | 625.713293 | 617.165429 | 1.013850 |
| MR | 516.963602 | 507.400217 | 1.018848 |
| source | 233.627708 | 229.906683 | 1.016185 |

这些计时含2alloc/build/init/所有suffixqueries/emission及instrumentation，不是wholepublicAPI比较。重复hash/extension工作减少非常多，但elapsed只有约1%..2%改善；不能据此归因主热点、承诺生产widecorpus收益或忽略近0.75MiB新增workspace。父代理应在收益/预算证明后再考虑productionpreflight。

运行epoch：experiment corehash=`162a3afef29c137aba7d2fbcfb4cf702c01e38493cc079cbad850a818c935dc7`与当前core一致，主zstd实验hash617856a0...与当前最终回读08ad02b5...不同，coreQA也追加变动，工具未列experiment source snapshot。source_stable仅证明记录文件在该run前后稳定；此报告不把诊断snapshot写成全部finalsource公共验证。

## 本轮内容哈希

- `src/zstd/match/paired_anchor_cache.zig`: `162a3afef29c137aba7d2fbcfb4cf702c01e38493cc079cbad850a818c935dc7`
- `src/zstd/match/paired_anchor_cache_tests.zig`: `3db96ff0c96df9c9671f8f444acecf49b320d2fded2f5f366454fd5803cabd7b`
- `src/zstd/match/paired_anchor_finder_tests.zig`: `6342463ec73827647284a436a80a292c337d414397dd7818a128019fabef2af3`
- `src/zstd.zig`: `08ad02b510a0cc83bc667b56a00b339f3e55fdac1daaff142d3b6de8f044f8b5`
- `src/zstd/match/multi_duplicate_profile.zig`: `0f6c798ab6d1dea7682b7117706bd01cab430d605337ec23df60c90062fc542b`
- `tools/zstd/multi_duplicate_profile.zig`: `c754060daf47afd37eda03a73c24cf89daaecab5ac529b9c205a86bc4f2eba89`


## 最终接受决定与allocation回归（2026-10-25 15:34:19 Asia/Shanghai）

**接受为显式研究诊断和正确性验证面；保持默认production reuse_anchors=false。** 当前新增cache正确性有相邻pair证明和完整suffix/costtrace对比，然而含allocation/init的3input×5round阶段收益仅约1.4%..1.9%，每64KiBblock额外393174bytes（约6倍输入长度）。这些证据不足以把研究diagnostic宣传成生产性能获胜，或默认引入heap/newsetting。此次不提供production optionalbudgetpreflight修复或默认启用承诺。

最终源码中 `benchmarkNativeMultiDuplicateAnchorProfile`（src/zstd.zig:19522）仍清楚是显式diagnostic：它通过callerallocator依次tryalloc hash/lengths，失败直接返回OutOfMemory，**没有fallback**。已分配部分由deferfree释放；失败发生在firstfinder/costquery前，不动caller输出。不能把该函数写成“optionalallocation失败会继续baseline”，也不能声称未来default sharedbudget分类已修复。

新增 `zstd paired anchor diagnostic allocation failures preserve caller output`（src/zstd.zig:31180）对fail_index0和1验证：返回OutOfMemory、caller prefix原样、profile.finder_calls由7reset0、allocated_bytes==freed_bytes。allRLE成功诊断虽build65529hash后returnfalse，仍无finderquery/output；这是明确诊断工作，不改变productionquality。该回归解决当前显式diagnostic泄漏/输出时机验证，未触发sharedtotalcap，不替代未来optionalbudget测试。

最终两项anchor主测试均注册（suffixwinner/pricingtrace与allocationfailures）。读取现有result：

- finder-debug：native Debug，paired anchor filter13/13，exit0、source_stable。
- finder-releasefast：native ReleaseFast，同filter13/13，exit0、source_stable。
- finder-x86：x86-linux-musl ReleaseFast，同filter13/13，exit0、source_stable。

三个result的主源码hash均`08ad02b510a0cc83bc667b56a00b339f3e55fdac1daaff142d3b6de8f044f8b5`，corehash均`162a3afef29c137aba7d2fbcfb4cf702c01e38493cc079cbad850a818c935dc7`，与本轮当前回读相同。13包括imported测试，不是13个独立allocationcase。本审计只读取执行证据，没有重新编译/test/time。

实验执行的core与最终一致，主源码/QA注册epoch不同：experiment主617856a0...先于最终08ad02b5...，额外registeredtests不改变被实验调用的cache算法。该差异已保留身份区分；不改写experiment source_stable为完整最终树publicbenchmark。完整family/check尚由父代理跟踪，本报告没有提前写通过或公开wholeAPI收益。
