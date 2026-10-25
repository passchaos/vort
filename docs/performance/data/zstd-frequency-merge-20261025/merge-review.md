# Frequency merge/count 准备路径只读审查

- 工作树：`/home/passchaos/project-z/vort-zstd-frequency-merge`
- 基线：`df05f9fe92811461905cfe48fa3ebfd8b010c666`
- 审查时间：2026-10-25 15:14:04（Asia/Shanghai）
- 范围：已落盘frequency_merge小模块、CutHistogram接线、Base prepare变化、独立QAhelper以及microbenchmark静态口径。未编译、执行QA/编码/基准、计时或修改源码/Git。唯一写入是本报告；父代理负责source-ready后的构建和实测。行号/hash是本轮读取的源码快照。

## 结论

当前合法CutHistogram输入域内，合并frequency和active计数的向量实现与原totalFrequencies加标量非零计数精确等价。未发现u32中间overflow、漏lane/尾部、支持计数错误、越界读写、非向量对齐要求或prepare状态/error顺序变化。输出仍是全部256项，zero频率也覆盖caller旧数据。

该模块不校验任意外部u32 row sums，也没有扩大Prepared或Cf的信任范围。其安全依据是合法histogram每symbol四row和<=regenerated<=block.len<=131072；它不是前一任意256u32 inspector的u64数值验证器。只读源码显示取消了prepare中重复非零扫描，但真实热点因果和吞吐收益必须由micro/public实测确认。

## 数学及内存范围

`src/zstd/literals/frequency_merge.zig:5`定义8lane u32 vector；`:16`offset0..248，按8递增，共32chunks。每chunk在`:17`..`:20`读取四row同位置的8项，覆盖全部1024input counters，读范围没有越过row255。

`:21`明确表达 `((first+second)+third)+fourth`，与旧 `CutHistogram.totalFrequencies`（`cut_histogram.zig:64`）每symbol左结合一致。合法CutHistogram把保留literal串划分为一/四个不重复canonical streams，故每symbol四row和不超过再生字节数R。current cut满足prefix<=tail<=block.len，由init/update确保block<=131072，所以R<=131072。各输入非负，则每个left partial sum不超过final sum，因此每次普通u32加法都不会overflow。

这里使用普通u32 `+`，不是饱和、wrap或signed bit reinterpretation；不会因合法域小而改变算术mode。module comments（`:8`..`:12`）明确限定valid sums、不验证外部malformed histogram。不能以Prepared.unique/regenerated或旧Cf替代对实际四row的计算；新模块没有读取这些fields。

`:22`每chunk写对应8项，总共恰好写满out[0..256]。sum0也写0。`:23`逐lane判非零，`:24`把8bool bitcast u8再popcount；每chunk0..8，usize合计0..256，与遍历全部256combined frequencies的old unique count一致。

输入/输出都只需要正常u32 alignment，加载通过[8]u32切片值转vector，没有32byte alignCast。currentproduction out为prepare局部独立数组；module除out外不写内存、不retain指针、不分配、无global state。input与out disjoint时全部rows保持原样；out别名进histogram的调用并非当前prepare流程，不能因self const签名就宣称这种人为alias也不改histogram。完整[4][256]和[256]有效初始化/readwrite span仍是函数参数合同，不支持部分rows或未初始化input。

## CutHistogram与prepare的状态和错误

新增 `CutHistogram.totalFrequenciesAndCount`（`cut_histogram.zig:73`）只委托 `mergeActive(&self.stream_frequencies,out)`；旧totalFrequencies保留原expression供reference使用。没有修改ranges、stream_count、frequency增减、scanned_bytes或update_count。

`single_cost_cache.zig:144 prepareLiterals`diff仅把旧3行 `totalFrequencies; unique=0; scan nonzero`替换为 `const unique=totalFrequenciesAndCount`。仍先histogram.update完成cut校验、counter admission和state transition；然后合并当前histogram，再读取R、决定raw/RLE payload、调用literalHeaderLen、checked add并发布Prepared。

因此：invalid cut/counter admission仍在任何frequency读写前返回旧Error，successfulupdate后的header error仍在同一位置返回；准备一query一次histogram update、failedPreparation accounting/ref原规则不变。新module没有Error返回或新的cap检查，不把普通helper error改成其他顺序。Prepared完整frequency/unique/raw/R由同一currentcut计算，后续live stream histogram绑定无变化。

源diff没有修改src/root.zig或src/zstd.zig（本轮读取快照）；root codec公开签名、winner fallback、Cf校验、single/indexed/limits/emitter路径不变。内部新增返回activecount的histogram method不改变old totalFrequencies语义。

## QAhelper的独立性与覆盖

`frequency_merge_tests.zig:5 oracle`采用u64逐symbol遍历四rows求和，assert每symbolsum<=131072，再写u32并独立count非零。它不调用vector/scalarReference来算expected，能抓到输出遗漏、误合row、支持计数和宽度错误；当前validsum域内u64 oracle与u32kernel应完全相同。

`compare`（`:17`）检查new与scalarReference的active与全部frequency等于oracle，用caller poison保证zero slots被覆盖，输入snapshot保持，out首尾guard不变。

读取覆盖：

- emptyrows、不同symbol0/1/127/128/254/255上4×32768=131072、仅第四row131072；验证所有四row贡献和最大单symbollegal sum。
- row support互不重叠、全alphabet重叠、稀疏mixed支持。
- 实际生成bytes分配到四连续streamquarters，再独立直接count bytes；0/1/63/64/1023/1024/65535/65536/65537/131072。
- input/out相对32byte边界偏4bytes，normalu32alignment；input/out ownership guards及input snapshot。
- `histograms`（`:100`）真实CutHistogram init/update，在R0/1/63/64/1023/1024/1025/16383/16384/65535/65536/65537/131072并往回收缩；每R测试prefix0/中点/全prefix，expected直接从block[0..prefix]和block[tail..]count，不借用histogram内部planner。
- 每realcut同时比对oldtotalFrequencies与new全部output、activecount、histogram state未变，首尾guard不变；131072全0xff RLE最大count。

module`:42`挂入contracts；cut_histogram`:140`挂入realhistogram测试。synthetic rows仅验证数值sum契约，不假装它们每种都符合canonical一/四流物理partition。实际CutHist test独立满足真实partition验证。

没有发现本次validdomain实现所必需的安全case缺口。父代理应确认native Debug/ReleaseFast/x86测试和既有winner/prepareheadererror回归运行通过，以及真实profile/publicwire/counters稳定。本审计不执行这些测试。malformed arbitraryu32溢出行为不属于新模块domain；不应为本private validhist kernel增加未经要求的cap/trusted-field验证。

## microbenchmark与收益范围

静态读取 `tools/zstd/frequency_merge_bench.zig`：3shape为77active四流、256active四流、77active单流；每shape64个完整[4][256]输入，inputgen值1..63，validsum且globaltotal<cap。single_stream其余三个row初始化0，两侧也会读取全部四rows，和production原total helper一致。

`:37`在计时外对每array比较scalarReference与mergeActive全部256输出和active，不只比较checksum。`:73`每次query noinline；runtime LCG选择64array，测量包括选择/call、4KiBinput访问、1KiBout写入、active与一个输出样本mix/loop。doNotOptimizeAway对output与mix在时钟结束前保留消费。warm1000、5round交替scalar/mergedfirst、rawns/mix/order及median/min记录。

最终参照侧是 **原始两遍scalarReference**：`frequency_merge.zig:33`..`:36`先按原expression写满所有256总频率，然后`:38`第二个loop遍历完整output统计非零符号，与production基线prepare的totalFrequencies加unique扫描一致。它与新一次vector merge/count的micro对比覆盖这两个局部准备步骤；不能据此独立拆分“vector算术”与“消除第二遍扫描”各自收益，也不能声明新增API整体相同比例或确定之前最大热点。先前本报告把旧reference快照误称为final micro参照，已纠正；实际micro绑定新两遍module hash，见末节。

每shape输入池约256KiB，warmmicro包含cache/output/call/选择成本；编译vector源不证明所有target生成同宽ISA或更快。父代理需在source/executable稳定且无编译干扰窗口记录micro原始轮次、再测public完整compression14、outputwire与candidate/profile计数；最终micro已有局部实测结果（末节），本报告仍没有wholeAPI收益或热点因果结论。可重复收益不成立时，可以拒绝production启用并保存证据。

## 内容哈希

- `src/zstd/literals/frequency_merge.zig`: `6f5eb4b44e85485d5de3a1e51a2c454689826fa65668cd6910793bdd0fce096c`
- `src/zstd/literals/frequency_merge_tests.zig`: `41f7d3140d4426e90cb946c0df9ae10fecc0af714eed88b2f9a738213f00a628`
- `src/zstd/literals/cut_histogram.zig`: `6a9d7e4545f2ee075cfef1c1497b5609987820a9d6401848ca2268865711f9ad`
- `src/zstd/literals/single_cost_cache.zig`: `1fde928e6f6133328dbdf09f9af4b30d8fdf60b162e1968f744327b6825d29e7`
- `tools/zstd/frequency_merge_bench.zig`: `340a5651ac6868688aa65fb58a9a5aa01f660268d93c4ab7a98a3a7a17e0d75f`


## 最终两遍reference与micro证据 epoch（2026-10-25 15:16:10 Asia/Shanghai）

初次静态审查读到的scalarReference在写入频率的同一symbolloop中count，随后父代理在micro之前要求参考侧还原原始两遍。最终当前 `frequency_merge.zig:29`注释明确“Original two-pass scalar path”，实现是第一loop写all totals、第二loopcountout。mergeActive本体、leftassociation、读写/alias/validsum契约没有变化。初次报告把旧参考状态用于最终性能描述是错误的；本节依据实际source/executable身份更正，旧snapshot不能绑定到这次micro。

最终module SHA256=`6f5eb4b44e85485d5de3a1e51a2c454689826fa65668cd6910793bdd0fce096c`。`micro-result.json`source_before/after均为此hash及工具hash`340a5651ac6868688aa65fb58a9a5aa01f660268d93c4ab7a98a3a7a17e0d75f`，source_stable=true，exit0；current源码hash匹配。executable SHA256=`219978e0cef521e0fa683e718e838d2ebf7ef0bbaad807a919fb564ab2210947`，result与samples provenance一致。07:13:49 UTC计时记录观察17次compiler状态，with_process0。

`micro-samples.json`schema=`vort.zstd.frequency-merge-bench.v1`，iterations250000、3shape各5个交替round；rawscalar/mergedns、先后和mix记录完整。摘要median重新由5rawround排序核对一致。ReleaseFast/Zig0.16.0/x86_64/skylake+pku+sgx、Intel i7-10700K、单线程CPU8。

| shape | 原始两遍scalar median ns/query | 一遍vector median ns/query | scalar/vector |
|---|---:|---:|---:|
| medium_four_streams | 193.830152 | 50.784368 | 3.816729 |
| dense_four_streams | 196.157880 | 44.911300 | 4.367673 |
| single_stream | 197.165164 | 51.919872 | 3.797489 |

此局部测量比较完整原两遍merge+count与新一遍向量merge+count，含选择/call/读写/mix/loop。它支持这个局部准备函数在该条件下更快，不能单凭倍数宣称wholeAPI压缩吞吐提升、分析热点因果或将收益拆成向量与scan消除各自份额。

读取 `merge-debug/result.json`、`merge-releasefast/result.json`、`merge-x86/result.json`：native Debug、native ReleaseFast、x86-linux-musl ReleaseFast，均exit0、source_stable=true、passed_test_counts[13]，并均绑定上述最终两遍reference module hash。13包含CutHistogram和imported模块contracts。审计只读这些产物，没有重跑。父代理complete-family/check尚在工作流中，公共性能验证仍独立进行；这里没有wholeAPI获胜结论。
