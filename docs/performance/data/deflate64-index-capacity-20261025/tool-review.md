# Deflate64 index probe静态审查

审查时间：2026-10-25 21:28:22（Asia/Shanghai）。工作树`/home/passchaos/project-z/vort-brotli-context-cache`，分支`work/deflate64-index-capacity-20261025`。只读最终probe/gate/build、冻结matcher及父正式资源结果；未编译、运行probe/codec/tests、计时、修改源码/tools或操作Git。本轮新授权仅写docs/performance/industry-gap-audit.md，另写本指定TMP报告。

## 结论

最终工具适合比较**codec请求的同时存活字节**，包含one-shot返回output，明确排除input生成、wire collector、decoder、JSON、provenance和tracker本身。alloc/resize/remap/free的成功后更新、实际pointer/length匹配、afterfree/deinit清零及增长计数守恒在源码上相符。rawRemap仅观察API持有的逻辑bytes，已明确排除backing allocator私有瞬时physical allocation；不能用该peak作为RSS或完整进程heap peak。

最初optional timing仅消费wire.len/首字节的保留项已解决。最终noinline encodePass消费全部wire字节并free，timer无tracker，JSON明确包括checksum/free。因此它是同定义的公共encodeAlloc调用成本加输出消费，不是裸codec时间或public throughput领先门禁。本报告不以静态noinline事实充作最终ELF反DCE证明。

## live/peak与操作计账

- `tools/deflate64_index_probe.zig:98..123`alloc只在backing成功后记录pointer/bytes、增加successful_allocations/live/current，peak更新到当前live。失败attempt和maximum_single_request仍记录；请求失败本身不增加live。这里current/peak的“successful requests”与attempt计数是不同字段，不能把allocation_attempts当successful次数。
- `:77..89`后续操作需pointer和slice bytes精确匹配；resize成功`:125..134`以new-old更新current/growth或released，slot length同步。resize失败不修改逻辑尺寸。
- `:136..145`remap成功后更新同一slot的pointer/length及new-old，不新增liveallocation或free。移动remap返回新pointer不会导致后续free漏匹配。原API持有allocation数量不变。
- `:147..159`free先交backing，再清slot并减live/current，clean检查current/live/slots为零且growth==released。最终gate的`:55..74`也核成功次数上界、growth-released=current、cleanup free==successfulallocations及alloc event数/bytes。resize/remap的隐含移动不额外计free，这是Allocator合同的逻辑层。
- `:50..53`tracker用128个固定live slots和256条alloc-attempt记录，bookkeeping不分配trackedheap。若live slots耗尽，会释放刚由backing分配的块并返回null；这会人为产生OOM而不是无限观测。records满有truncated flag，成功测量结束会拒绝该报告。对本轮boundedcodec足够，不将其推广为通用任意并发heap observer。
- `:84..88`统计采用usize普通加减而非无限宽安全计数；本轮7个有限输入、4MiB/1024块及最多1000可选iterations，单次tracker生命周期的bytes/counter受实际codec分配界限约束，未见当前范围溢出。timingmix和每byte乘加显式wrapping，属于可碰撞结果消费，不当无碰撞hash。

## 新ring成长与peak区别

- `src/deflate64/stream_match.zig:12..13`previous长度为min(localspan,65536)向上power-of-two，至少1；`:34`heads始终32768×u32=131072B，并未一起缩小。只有previous根据需要成长，已分配容量不缩小。
- 初版`:36..45`成长先alloc新previous、后free旧previous，tracker真正看到old+new共存。最终a149版`:40..55`先尝试allocator.remap，成功后没有后续fallible操作，旧allocation已被backer消耗，不另free；失败仍alloc-beforefree安全fallback。显式fallback的新旧共存照样计peak，不能因checkpoint只展示new而删掉瞬时请求。
- `one_shot.zig`根据128KiB借用chunk加至多64KiB history span预备ring；大输入最终仍用full65536 ring，小input可少分配。这不等于所有输入或完整stream peak下降。
- probe`:448..465`在step返回后记录heads/previous变化及memory checkpoint，因此checkpoint的current是post-step保留量，checkpoint.memory.peak包含之前alloc事件最大值。`memory_before_deinit`是完成stream后仍拥有的codec容量，`peak_requested_bytes`可能更大，二者不能互换。
- `first_output_input_offset`是首次观察到output的step返回后累计accepted input，不是step内部实际写出第一字节时的精确瞬间。可以作为call-boundary responsiveness观察，不能说成精确内部output事件计数。

## 输入、输出与scope

- `:257..277`7个one-shot输入在plainallocator生成；资源pass`:279..325`仅encodeAlloc与返回wire使用tracker。完整SHA、encodedBound、解码与plaintext equality用plain allocator执行，返回wire单独free后clean。`memory_at_return.current`包括caller-ownedwire；其peak还含encode临时index workspace，不把current当整个call最大量。
- `:376..424`stream用一个4096B stack block复用至4MiB，input SHA逐块累计；编码器init延迟分配、资源流不计时。collector保留完整wire，decoder分配完整4MiB plaintext，均排除trackedcodec metric。故“codec bounded”不代表这个验证进程没有全量collector/decoder内存。
- `:431..475`drive每次接收257B calleroutput，核进度边界、完整accepted input和done/finish，真实输出累积用plaincollector，checkpoint fixed16项（超额报错）。双方比较的是same input/schema/options，整个compressed wire SHA可作完整bytes身份，不只比较size。
- `:328..345/:477..`仅对前min(3,actualallocattempts)个one-shot rawalloc和3个stream rawalloc做诱导失败clean检查，均使用新的Tracker实例，不纳successful resource报告。它们是选定清理检查，不穷尽所有resize/remap或后续ring-growth失败路径；完整core QA另负责，勿把此字段命名误读为all-allocation-fail coverage。

## gate与来源边界

- `tools/deflate64_index_gate.py:26..51`独立复现7个input及4MiB重复块SHA；`:91..125`核schema/commonchain128nice128、输出bound、roundtrip标记、trackedwire包含、cleanup、streamfullringgeometry。`:147..157`old/new完整wirehash/size与input/settings保持，并输出两边provenance。
- gate核内存标量守恒和alloc events，但事件列表只有alloc，不包含resize/remap/free的完整顺序。因此gate不能独立重放计算peak，也不认证Allocator内部物理瞬时量；peak可信度来自上述Tracker源码及最终实际报告。JSON有明确remap_metric_limit。
- optionaltiming `:348..373`只有显式`--iterations`（1..1000）才运行，五轮每次同输入plain encodeAlloc+fullwrappingchecksum+free；warmup、input、SHA、decode、metadata均在timer外。输出raw/min/median按5值正确计算，stream资源pass无clock。noinline输出byte消费消除了源码中只观察首字节的问题；checksum成本仍含在测量内，不能称encode-only。
- gate`:77..84`校验timing五轮/min/median，`:166`明确不确认isolation或赋speedclaim；它没有强制old/newiterations相同、process交替、CPUaffinity/target/source窗口一致。父需要给速度点比时须另检查这些条件，不能仅以资源gate ok宣称性能。
- `build.zig:2779..2797`probe与codec module固定ReleaseFast，codec root为src/deflate64.zig，覆盖src目录中的codec-relative imports；不导入完整src/root/crypto。provenance为共同module，记录target/CPU/affinity/Zig/argv/actualexe hash。finalsrc/actualcompileinputs/exe及quiet窗口仍需父另绑定，本审计不代作执行证明。

## 冻结快照

- tools/deflate64_index_probe.zig：`50e0ef9c3334a7677f07d37866d69af17ad0303e494bee2166ff3ec3ad32f573`
- tools/deflate64_index_gate.py：`b4bfb5a99ab820a76178cd45c5f5cfa702a6b4b1d3b0810c8758d840358621b1`
- src/deflate64/stream_match.zig（最终remap版）：`a149d36ce699001e985b77541bb3cafc46447161efee8b5690db95acb127b0e4`
- build.zig：`f33f080240758439e8383f1f416dbeab5a6da931ee26c9f19a0a5d876fe62e36`

当前没有阻止本轮资源测量的实质工具问题；剩余边界是requested-live metric而非物理memory、fixedobserver容量、选定失败checks和可选timer包含checksum。父最终执行/compare需要绑定此新增完整消费版本，不能将早先首byte timing执行归作该source。未新增测试/benchmark或扩大publicbehavior。

## 最终remap资源实测独立复核

父`resources/result.json`两工作树嵌套source_before=after，old/new两个probe exit0、gateexit0，两个samples SHA与实际文件重算一致、exe SHA与样本provenance一致。当前matcher a149、one_shot a08bdd2beb610ad19dc9dce3a23797f8e1e6ea4753028f2f382655ca5c749332、stream_encoder8f9e7d4df4707e0bf365ba8f630f639ed4edf11f6995be308353005691af2b85、probe50e0ef9c和gateb4bfb5a9均逐项匹配new工作树source_after。资源run全部one-shot timing=null，是无计时的requested allocation证据，不要求或虚构quiet吞吐结论。

独立重读两个报告的七个one-shot case，核name/bytes/inputSHA、fullwireSHA/bytes/encodedbound全部相同；重算alloc successfulbyte sum与报告一致、returncurrent=returnedwirebytes、afterfreecurrent/live0、growth=released。comparison所摘old/newpeak与原memory字段相同：

| Case | Old peak requested bytes | New peak requested bytes |
| --- | ---: | ---: |
| empty | 2 | 2 |
| tiny16 | 393234 | 131154 |
| pattern12079 | 393262 | 196654 |
| random4097 | 397318 | 167942 |
| random16387 | 409608 | 278536 |
| repeat65539 | 393222 | 393222 |
| distant131072 | 462314 | 462314 |

heads request131072B未变，小inputprevious分别64/65536/32768/131072B；大input仍262144B。不要把本pattern46B wire与此前不同生成text的pattern53B混同，两probe本轮inputhash已匹配。

stream完整4MiB input/wire身份相同，首有output的step返回时accepted8192bytes。oldpeak/currentbeforedeinit462909，新最终peak/current也462909；新4remapattempts/2success、7allocations，其他两次grow安全fallback。poststep成长checkpoint（accepted input/previous entries/current/peak）依次8192/4096/217149/217149，12288/8192/233533/249917，16384/16384/266301/299069，24576/32768/331837/331837，40960/65536/462909/462909。中间fallback peak大于current是真实API共存，请保留。最终deinitlive0，容量成长后稳定；没有声称流式峰值低于old。

`growth-peak-decision.json`的初new593981相较old462909为allocate-first方案历史观察，推动了remap修正；不能归作最终new实测。rawRemap backer内部temporary、slab/page/allocatorpadding仍不可观察，不将最终equalrequestedpeak视为physical/RSS无任何变化。

只读核最终codec Debug/ReleaseFast/x86各100/100 source稳定；三target matcher各1个named reference contract，其内部比较fullwindowreference、growth/rebuild/failure等，不能称只测一个输入。后续本轮ZIP44、native/x86external合96artifacts128members、完整ZIP1993/1993、check177/177与CLI7/7全部terminal。行业文档final已冻结并链接deflate64-index-capacity-x86.md，不新增格式或宣称全面压缩吞吐领先。

最终保留matcher源码a149、资源/计时主报告恢复该版本身份；固定slot44dba试验只在fixed-slot-experiment保留，已撤回不归最终。primaryresources再次核a149及原old/new exe a92ef667/6333face，七行peak和4MiB462909结果保持。primarytiming的三pair每case几何点比独立核为empty0.980039、tiny1.054839、pattern0.991585、random4097 1.086759、random16387 0.990310、repeat0.968085、distance0.975022；这与baseline所列每case ratio的中位数是不同统计，不能互换。计时包含全输出checksum/free，aggregate1.005803，无统计显著或全输入提升结论。

行业文档最终SHA`8235bc5494921a07b88d902a9cedfe7f86847352b4661e5def0072b00fa8762b`，限定diff检查通过，之后不再文档写入。未compile/timing/Git操作。
