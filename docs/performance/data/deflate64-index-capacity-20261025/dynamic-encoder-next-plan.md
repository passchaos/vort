# Deflate64 dynamic encoder 下一步：有界 Zig-native 路线与索引容量概念复核

建议下一功能增量是：复用当前wide greedy matcher与连续bits writer，用每块一次histogram扫描和一次输出重放生成dynamic Deflate64，初版保持现有parse decisions，只在stored/fixed/dynamic三种wire representation间精确选择。不直接搬普通Deflate的DynamicCodingPlan、u16Token或30-distance Stats；小幅提取通用code-length RLE与canonical-tree primitives，把Deflate64的格式语义留在独立模块。

这是父任务指定main `35229f7c` 的只读研究，不是实现、编译或性能结果。未修改源码、运行测试/编译/计时或进行Git操作；只写此/tmp报告。parent另有stream_match容量worker与QA，本报告不接管其文件。

## 关键文件与现有可复用边界

| 文件/位置 | 已有内容 | 建议用途/必要适配 |
|---|---|---|
| `src/deflate64/stream_match.zig:17–71` | bounded block-local history+input matcher、wide Match、65536 window/65538 length | 同parse histogram/emit，容量变化只影响previous storage，保留hash/candidate规则 |
| `src/deflate64/stream_blocks.zig:52–91,129–146` | fixedPlan/writeFixed、完整Deflate64 classifier | 提取共享classifier与token walk，dynamic频率/extra/wire不可自创不同映射 |
| `src/deflate64/stream_blocks.zig:16–38,94–126` | count<=16 Writer、exactstoredcost/continuousbitstate | dynamic按字段写，reusecapacity与finalpadding，避免56-bit整token融合 |
| `src/deflate64/decoder.zig:114–176,213–227` | dynamic header286literal/32distance、RLE16/17/18、285=3+16bit | 本格式边界参考，独立parser oracle起点 |
| `src/deflate.zig:1724–2173` | privateDynamicCodingPlan、hist→boundedtree→RLE→encoders→header/payload | 学习步骤，不能整对象/近似cost搬入Deflate64 |
| `src/deflate.zig:2424–2520` | HLIT/HDIST/HCLEN trim、树freq completion | 提取简洁generic helpers，距字母表需32，syntheticfreq与真实cost分开 |
| `src/deflate/dynamic/code_length_rle.zig:1–89` | 不拼接输入的跨HLIT/HDIST RLE、有界opplan和histogram | 参数化max_ops316→318或新的PlanFor(capacity)，规则保持不变 |
| `src/huffman.zig:46–157,1243–1270` | CanonicalEncoder.init、treeCodeLengths(n,maxbits)、bounded package-merge | 直接reuse n=286/32 max15，n=19 max7；初版用完整frequencyreference入口 |
| `src/deflate64/stream_encoder.zig:281–344` | admission/reservation/atomic commit、flush/fatal/progress | 增dynamic选项/计数时保留这些状态不变量 |
| `src/deflate64/one_shot.zig:13–49` | privateu128 wholecost与strictglobalstoredfallback | dynamicone-shot保持globalstoredbound、宽comparethenwinnercast |

读取来源SHA：stream_blocks `1b888cee9cbd786bfd9b3bea66b98415200ee88a2f424de76d8bfe19c506558e`；stream_match `13879c9f5dcf45cecd1ae2d9cc7e7400db3748bae45f568dd49340706e4ae76b`；decoder `8748745abf4a0037b2557e5f70cebe218ad716c8ef12d1a3168dbe524a02fc9c`；deflate.zig `128d45a63fbd468c58a7810d70c9de8b81af77bb78489a2da5d3c59c1af3a96f`；RLE `0d3fd9af16216a70a01ff9ee91ad2d3f546da5bf116f6fa2f4456dbd49f35c1a`；huffman `2bfc756f0d0380eeab5f6bc9e268ef14294aa5816dbdb1e039390bdabb682aa3`。

## Deflate64语义与不能机械复用的地方

- literal/length histogram为[286]u32，distance为[32]u32，包含符号30/31；HLIT=257..286，HDIST=1..32，HCLEN=4..19。保留两个5bitcounts；32distance不需要增加headerwidth。
- length3..258保留普通形状但258=284+5extra/value31；length259..65538=285+**16extra**/value(length-3)。285动态codewidth最多15，加16长度bits；distance31对应49153..65536，额外14bits。
- `deflate/incremental/.../dynamic_stats.zig:35,78–93`参数仍lz77.Token.Match(u16)，length258=285无extra，distance数组30；不能只扩数组就认为classifier正确。
- 普通DynamicCodingPlan固定成本特意减去280..284频率（deflate:1927–1933），保持普通lz77历史近似model；新exact Deflate64不复制该减法，使用现stream_blocks真实symbolwidth与extra。
- 普通DynamicCodingPlan的`code_len_freqs`经completion后参与headercostweighted（1984–1993）；新exact实现必须使用真实RLEopfreq/ops，而不是synthetic树频率，避免给从未发出的补全符号计费。
- 普通`writeDynamicMatchFused`最大15+5+15+13=48bit；Deflate64最大15+16+15+14=60bit，超现BitWriter56bit接口上限。初版沿stream Writer分字段写（每次<=16）；不用整tokenfusion，后续u64reservoir优化再独立证明。
- `huffman.parseDynamicHeader`仍拒HDIST>30，不可拿普通parser认证包含31/32distance的Deflate64输出。用Deflate64decoder/独立formatparser。

## 最小模块划分与每块两遍路线

建议新 `src/deflate64/dynamic.zig` 负责fixed大小histogram→trees→headerplan/cost，`dynamic_blocks.zig`或stream_blocks小扩展负责writeheader与widepayload。当前stream_blocks已承担fixed/stored，提取 `codes.zig` 的public-internal CodeExtra{symbol,bits,value}可避免dynamic重复length/distance数学。match walk可用comptimeconsumer/sink共同复用，保留find/insert所有细节；若为速度临时写两个loops，必须做exact decisions差分。

### 第一次遍历：真实histogram与exactcost

matcher.begin(history,block)，按当前greedy循环find、take、insert。只保留：

- lit_freq[286]、dist_freq[32]（u32最大次数<=128KiB，足够）；每块真实EOB256固定加一次。
- length_extra_bits、distance_extra_bits、actualfixedbits、match统计；每次使用同codesclassifier。
- 不保留整个tokenlist；array/统计为固定workspace。active symbollist初版可不做，完整318频率scan远小于parse，先保证referencecorrectness。

### 树规划

拷贝actualfreq为treefreq，在treefreq中处理零/单symbol补全。使用 `treeCodeLengths(286,...15)`、`treeCodeLengths(32,...15)`；code-length RLE获得19-symbol真实freq，tree副本必要时补全，再 `treeCodeLengths(19,...7)`。构造CanonicalEncoder为falliblepreflight的一部分，在publishpending前完成。

一个有界DynamicPlan拥有lengths[286]/[32]/[19]、canonicalencoder三套、最多318个RLEops、counts/headercost/payloadcost。它不能借用栈上临时histogram或Huffman树缓冲，返回时所有arrays按值拥有。不存在inputallocator-retainedtoken数组，treebuilder的workspace固定由alphabet决定。

### 退化字母表

EOB必须非零且真实payloadcost只计一次。lit只有EOB时可补symbol0，tree完整；empty adaptive自然fixed10bit更小。dist无actualmatch时需要一个可被当前incrementaldecoder接受的非空tree：其validDynamicAlphabet拒全零active0。可合成distance0 one-bit singleton（HDIST1）；若初版希望避免跨reference incomplete-singleton争议，可补0/1两个symbols做完整tree，HDIST2。singleactualdistance同样可保single1bit或补另一个symbol；必须明确选一种deterministic政策并差分UnZip。所有这些synthetics仅影响header/treeshape，不增加realpayloadhistogram或distanceextra。

code-length alphabet建议补到至少2symbol以生成完整树，真实RLEop计费排除补全symbol。不因合成tree改变实际parse、删candidate或clampfrequency。

### RLE的318容量

HLIT286+HDIST32最多318个长度，现RLEmax_ops=316存在格式硬差距。重复ops只替代多长度，maxops<=sourcecount；但不能依赖“实际tree应能压缩两项”避开318。参数化PlanFor(max_ops)/buildFor或合理扩大shared固定cap318，保证普通Deflate输出规则不变。跨HLIT/HDIST唯一相邻run仍合并；16只在previous存在时发，17/18重置prev=0，extra2/3/7bit不变。

### 第二次遍历：按已计划tree直接输出

先admitexactpendingbytes与historycapacity，再emitheader、RLE、重新begin/replay同matchwalk，用dynamiccanonicalcodes输出literal/length/distance与extras，发EOB。writer为现continuousstate；没有dynamic中途allocation/fallibletreebuild。final最后align，提交pendinglen/state/counts/history一次。若实际emitbits与plannedbits不同，应在QA/Debug exact assertion发现，不能在ReleaseFast靠超量allocation隐藏错算。

固定parse的dynamic只改变entropy表示，不算真正的entropy-aware optimalparse。初版无需迭代trees/reparse或成本驱动candidate选择；那会改变histogram并增加遍历，需另外设计。

## exact stored/fixed/dynamic成本与选择

dynamicbits=

`3 + 5 + 5 + 4 + 3*HCLEN + Σ(realRLEfreq[s]*CLlen[s]) + RLEextra + Σ(actualLitFreq[s]*LitLen[s]) + Σ(actualDistFreq[s]*DistLen[s]) + LengthExtra + DistanceExtra`。

真实litfreq已含EOB；不再加第二次。stored使用已有currentq对齐公式，fixed使用同一parse的真实8/9bitcodes/length/distanceextra。nonfinal比较exactcontinuousbits；final比较ceil((q+bits)/8)，padding只算一次。建议确定tie优先stored→fixed→dynamic（新dynamic必须strictbetter）以保既有fixed/storedties；forceddynamic则明确允许比其他更大但仍有安全pendingcap。

treefreq完整无approximation，huffmanmaxdepth固定15/7。within128KiBblock，evenforceddynamic的字面code最多15bits，每matchlength3最多15+0+15+14=44bits<=15*3；length4..258最多50<=15*4；length>=259最多60<=15*length。payloadbits<=15*blocklen+15(EOB)。header最多17+57+(318*7+318*7)=4526bits保守界，因此全事件容量是固定有界且32bit可表示；实际reserve用exactbits。不能仅使用fixed9bits/byte上界为forceddynamicbuffer分配。

## Streaming API、flush与dictionary取舍

增量现Compression{adaptive,fixed,stored}可以追加dynamic与新的best，或在adaptive中加入dynamic候选；后者会改变合法wire，需记录行为变化并保持fixed/stored强制模式。若要最小review增量，可新Compression.best保留现adaptive fixed/storedwire，发布后再统一命名。不要让CLI/ZIP选择逻辑绕过library。

所有existingstate契约继续：有界plain/history/pending、offered整个slice预检、stickyfirsterror/failedProgress、resetretaincapacity/pledge、finalonce、input/outputcounterchecked。增加dynamic_block_count与treeplan不应改变这些。hist/treeplanerror必须发生publish前；若firstpass改变matcher后失败，fatal直到reset可避免恢复半状态。

blockFlush结束当前nonfinal块不align，partial仍10bitemptyfixed，sync/full仍emptystoredbyteboundary；dynamic不是flushmarker。full同boundary后清history/index一次，sync→full升级不重发marker；新dynamic不能把currentq或history清掉作为“重建树”。跨blockdynamic/fixed/stored共享64KiBhistory，树每block独立重建。

dictionary首先是已有rollinghistory，不隐含新presetdictionaryAPI。当前Deflate64IncrementalEncoder明确preset不支持，decoder也没有matching preset初始化公开契约。若新增rawpreset，应独立API在初始化时copy/borrow最后65536 bytes并配decoder，明确reset/fullflushdictionaryavailable规则；ZIPmethod9无标准dictionaryID携带，ZIPowner不应默许preset。先交付dynamicentropy功能更小且可验证。

## one-shot全局bound与遍历次数

原encodedBound仍globalstoredlayout，不可因dynamicone-shot逐128KiBstoredfallback产生更多头。可以比较三条完整候选：globalfixed、每块fixed/dynamic取min的compressed-only候选、globalstored；或者固定相同parse每块只取fixed/dynamicmin，则它包含纯fixed作为下界选择。全流u128累计、quotient/remainderceil、先宽compareglobalstored，只有strictwin后usizecast/alloc；无中间align或perblockstored。inputborrowedchunks/history保持。

**遍历次数要诚实。** Streaming每块hist→tree→emit是2次matcher遍历。One-shot若先全流exactpreflight再alloc，而且不保留O(blockcount)plans，输出阶段每块必须重新hist/tree再emit，因此总体是3次matcher遍历：全流preflight1、输出时tree重建1、payloadreplay1。保持总2次需保存每块header/treeplan（O(blockcount)memory）或完整tokens；不符合最严格fixedworkspace目标。初版推荐boundedmemory/3passes，测CPU后再优化；不能把两个外层loops宣传为两次实际parse。

Into/Append仍可保encodeAlloctemporary，维持input/outputoverlap、out.itemsalias安全和原子发布。若directInto必须处理alias会覆盖待重建history，不能靠preflightsize独自证明安全。

## quick review：previous索引按actual span缩小

概念：S=history.len+block.len，P=pow2ceil(min(S,65536))；无hashable输入时可0或最小1，实际begin/find/insert前须满足实现分支前提。hash仍32768且hash函数/取桶/候选预算/insert顺序不改。

- S<65536时P>=S，合法插入坐标0..S-1间无slotcollisions，等价于旧fullring；S>=65536时P=65536，严格等同旧ring与search-before-insert最大distance。
- 如果用S-2（hashablepositions）进一步缩小，则须重新证明每个合法插入的最大坐标<P；推荐S方案更直观。pow2计算范围<=65536，溢出可完全有界。
- beginassert从previous.len==65536改成power-of-two/足够当前span，所有slot表达式必须从65535改为P-1或等价mod；finddistance仍<=65536，不把storagecapacity当formatwindow。
- 重配previous只在begin之前，heads随后reset，所以不需迁移oldchains；若resize/alloc失败，不能先发布新mask/active_len，旧allocation仍要可deinit/reset。heads先成功而previous失败的partialownership必须照常释放。
- ownedalloclength与activeP分开，不能切短owned[]后用短lenfree/realloc；capacitygrowretained后若继续用oldlargerP作为mask仍safe但memory不会缩小。若需要切小activeP，用独立active_len且free完整ownedallocation；新begin清heads保证oldslot不用迁移。
- reset/deinit不得freeborrowedhistory/block；ensuregrowth之前不能持有指向旧previous的slice供后续find；同输入的plan/replay若一遍用小P另一遍复用大capacity也应candidate相同，但QA必须冻结真实allocation/active-mask轨迹。
- 将heads也缩小（例如4096）会改变hashcollisions/candidatebudget，不能与“完全相同候选”混在本优化中。
- 先small后large再small的session会retainlargeprevious；报告memorywins应区分freshinstance/peak/livecapacity，不能把小inputactiveP当allocatedmemory。

必要差分：P边界0/1/2/3、powers-of-two±1、32768±1、65535/65536/65537；history0/partial/full配tinyblock；distance正好window与过期链；sameinput两遍allmatchchoices/statistics/fullwire对旧65536prevreference。加入ensuregrowfailure/reset/deinit、反复smalllarge以及allocator精确free长度验证。只改变prevstorage，fullfixedwire应逐字节相同。

## portable minimal实施顺序与oracle条件

1. 提取widecodes/sharedwalk与RLE318capacity，保证旧fixed/stored及普通DeflateRLE规则完全不变。
2. 新dynamichistogram/treeplan做纯fixed-size模块，覆盖real/syntheticfreq区别、empty/single/no-distance、full32distance，独立长度数组/canonicalcodes验证。
3. 写dynamicheader/payload，forceddynamic先验证wire，不急改变adaptive默认；exactheader+payloadbits对independentsymbolwriter/scalarparser。
4. stream集成三representation精确选择，q=0..7全部initialstate、final/nonfinal、stored切片、flushpartial/sync/full升级、stickyprogress/OOM/reset、128KiB多blockhistories。
5. one-shotglobal候选扩展，保持u128cost/globalstoredbound/transactionalalias并记录真实3parse策略，附CLI/ZIPmethod9独立差分。

oracle至少三层：

- 纯tree/cost reference不复用classifier和RLEcost公式，验证所有length3..65538与distance1..65536边界class；285必须16extra、31必须14extra，动态width来自新tree。
- 独立Deflate64dynamicbitparser检查HLIT<=286/HDIST<=32/HCLEN<=19、RLE16/17/18跨alphabet界、oversubscribed/zero/singleton policy、EOB、actual65538/65536token与exactpadding/inputconsumption；同时自家one-shot与IncrementalDecoderroundtrip。
- 已本机确认Info-ZIPUnZip6.00带USE_DEFLATE64，可raw封method9ZIP用unzip-t/输出差分；ordinaryzlib解码不支持Deflate64额外距离/285语义，不能作兼容oracle。无需本轮巨大外部搜索/安装。

架构结论不包含性能保证；dynamicheader开销、treebuilderworkspace/CPU、3parseone-shot是后续可复现benchmark对象。不要为了ratio优化减少candidate或近似频率，先交付完整portableZigreference与明确boundedAPI。

最近取得系统时间：2026-10-25 13:04:49 UTC / 2026-10-25 21:04:49 Asia/Shanghai。
