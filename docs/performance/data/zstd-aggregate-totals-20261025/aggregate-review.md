# Owned aggregate totals 只读审查

- 工作树：`/home/passchaos/project-z/vort-zstd-aggregate-totals`
- 基线：`6b26275473146c4b6d602c99b91a9eaabe4b75f3`
- 时间：2026-10-25 16:17:58（Asia/Shanghai）
- 范围：已落盘Totals/CutHistogram/prepare路径、生命周期信任边界、零交叉及重分流数值、独立QAhelper与对象资源预测。没有编译、运行测试/编码/基准、计时或修改源码/Git。唯一写入为本报告；源码/测试仍由worker与父代理完成，实际运行/收益由父代理单独验证。

## 结论

合法受控init/update生命周期内，aggregate frequencies和active正确同步，完整update后等于原四流sum与非零符号数。重分流的瞬态计数按old+new最多2N<=262144证明u32安全，而不是错误地按当前R限定更新。没有发现cut/countererror时mutate-before-admission、Headerfailure回滚新cut、readyfalse重做update或绕过Certificatechecked逻辑。

Totals/Hist默认直接构造保持ready=false；常规init在emptyhistogram上受控ready=true。ready不是对任意外部rowarray的验证证书，公开字段被手工修改或forgedready属于生命周期前提破坏，不能用它声明任意输入已验证。parentprepare立即复制snapshot，没有保留跨update指针；readyfalse按同一次已完成update回退原fourrowmerge。成本/scorer策略不改。

当前静态审查支持正确性，但没有public收益结论。每个缓存对象约增加1KiB汇总state；native预计1040bytes，tracked6032→7072、untracked5568→6608，需实际sizeof与公共测量确认。较少prepare归约和更多byte-update工作之间存在取舍，不能先假定它是主热点或一定加速。

## 初始化、byte同步和数学不变量

`aggregate_totals.zig:16 Totals`持有[256]u32 frequency、usize active、bool ready；default `.{} `是全zero/unready。`:24 init()`仅在owneremptyinitializedstreams旁建立zero/active0/readytrue。`CutHistogram.init`（`:37`）保原128KiBcap拒绝后构造empty四rows，再调用Totals.init。

对受控ready状态建立归纳不变量：T[s]=sum_i(stream_frequencies[i][s])，active=非零T的个数。初始两者全zero。`CutHistogram.apply`（`:99`）每个byte先对原streamfrequency加/减1，紧接调用Totals同symbol add/remove。Totals.add（`:30`）记旧T==0再T+1并active+1；remove（`:37`）assertT>0、T−1，再在结果0时active−1。没有其他row变更路径，故每完整byte操作后不变量保持；完整update后T精确匹配当前cut literalfrequency。

row更新与summary之间短暂内部不一致无callback/可返回snapshot点，且init/update不允许并发读取mutablehistogram。snapshot契约明确只能ownercompleteupdate之后借用。若新代码以后引入中间callback或并发观察，应重新审核此atomicity前提。

重分流数值：update按stream依次removeolduncovered/addnewuncovered。已处理streams最多属于new覆盖，未处理streams最多属于old覆盖；当前stream也只保留old/newunion。总multiset量<=Rold+Rnew<=2N<=262144。每symbolT不超过此globalmass，u32加1绝不溢出；每oldremoval对应确有oldstream计数，而T>=该计数，所以remove不会下溢。active随zero crossings始终0..256，usize安全。finalT<=Rnew<=N；但不能在每个add强行检查T<=Rnew或N，否则合法repartition可能被错误拒绝。

## 状态/错误顺序与摘要寿命

`CutHistogram.update`（`:44`）保留所有旧cutvalidation、plan、work计算，scanned_bytes和update_count受检add（`:52`..`:53`）在任何row/Totalsmutation之前。invalidcut或这些counteroverflow返回旧Error并保持完整histogram（含新增Totals）原样。没有新增返回错误的Totals.add/remove分支；assert依赖合法受控不变量，不把malformedready数据转换成新的recoverableerror。

`ownedSnapshot`（`:83`）返回totals.snapshot；snapshot包含pointer-to-owned256freq及active值，不包含承诺validated的frequencyproof。寿命直到nextmutation/re-init，不能跨ownerblock变动、hash/costquery新cut或有意公开field修改；缓存重新初始化使旧view失效。

旧 `totalFrequencies`（`:66`）和`totalFrequenciesAndCount`（`:75`）始终读取四rows，完全不根据ready或aggregate去shortcut，继续用于publicexistingfield语义和oracle。人工state `. { .block=... }`默认Totalsunready；Totals.add/remove在unready时什么也不做（`:31`,`:38`），所以update永远不静默bootstrap/提升ready。该state仍用原fourrow合并，和基线语义相同。

`single_cost_cache.zig:157 prepareLiterals`只update一次；然后若snapshotready立即复制完整frequencies并取active，else调用oldtotalFrequenciesAndCount填同一局部array；不重复update/prepare。snapshot没有从prepare逃逸。随后读取regenerated、rawRLEminimum、header和checkedadd，Prepared是原ownedvalue。

Headerfailure仍发生在成功currentcut更新和完整摘要复制之后，保留**新cut的row/Totals/active**，由原failedPreparation单次query/referenceaccount返回error；不会rollback或再update。certificate发布只有fullpayload成功，not由ready属性提前触发。原Codecplan/header/sequence/null/error规则没改。

## 信任边界：ready不能证明任意rows

publicHist/Totals fields仍可以被Zig调用者构造或改写，但此优化的准入是受控ownerlifecycle，不是不可伪造的runtimeproof。特别是手工ready=true并提供不匹配row/summary、修改live rows或持有snapshot时改block，会破坏T=sumrows绑定；当前接口明确禁止，不运行全rows重校验。

不能用可造readybit说“arbitraryrow已验证”，也不能指望Certificate的数值envelope检测所有失配：例如伪造summary能通过频率总量/active几何，而Base streamweightedbits来自不同actualrow，Cf就未必对应拷贝summary的Opt。安全依赖内部init/update绑定，Certificate的原checkedarray/total/support/scalar前提仍保留而非被ready替代。

直接构造默认readyfalse会走fallback，不因此接受原来不合法的block/ranges/row值。若公共caller人为构造超过cap或不符合原range不变量的state，仍只具备原explicittrustedstate合同；不扩大domain或引入隐藏修复。准备路径新变量来自ownedcontrolledsnapshot，plainPrepared fields也没有成为绕过CF/realplan检查的授权。

## 源码范围和资源

目前diff只有CutHistogram新增Totals/init/snapshot/byte同步和Baseprepare选择summarycopy。未改root codec API、四流planner、budget、winnercache、weightedCertificate、Huffman树、cost策略、quality/level或formatter。初始化streamzero与cutcounter仍原值；结构布局会变，但新field不分配heap/retaininputcopy，metadata明示callerownedstate。

native布局预测Totals1024+usize8+bool1再align8padding=1040；加入所有包含CutHistogram的exact/winnercache对象，预计tracked7072/untracked6608，增加1040。32bitusize4下Totals可能1032，x86需实际probe。不要把此前Work减少464bytes结论改成此片降低内存；新汇总正好增加存储/每byte写操作。实际对象/stackframe/heap/RSS分别验证，不能由metadata无allocation就声明零资源开销。

## QA源码、已注册与建议补充

`aggregate_totals_tests.zig:12 contracts`独立expectedarray/active遍历，覆盖defaultunready add/remove保持未ready、全256symbols0→1→0、4096随机频次变化、reinit、单symbol瞬态262144再递减到0。snapshot pointeridentity也核对ownedarray，说明它是借用而非新allocation。

`histograms`（`:95`）从实际block[0..prefix]++tail直接countexpected，并与snapshot、oldtotal、oldAndCount及逐rowu64sum同时比对；不只比较两个可能共同错的summary方法。覆盖tiny24bytes全部合法cut、R0/1/63/64/1022/1023/1024/1025/16383/16384/65535/65536/65537/131072及回退重分流、64随机cuts、invalidcut/scannedoverflow/updatecounteroverflow状态不变、sameaddressblockreinit全0xff/RLEempty、manualdefaultreadyfalse update后仍null且oldmergeexact。

moduletest（aggregate_totals.zig:54）与CutHistogramrealcuttest（cut_histogram.zig:158）均已注册。父代理负责nativeDebug/ReleaseFast/x86和原winner/accounting/fullfamily的实际结果；本审计未执行，不提前写通过。

建议在新prepare层明确覆盖两项，而不只依赖histcore测试：

1. 把cache.histogram设置为合法manualdefaultreadyfalse，调用prepare后确认update_count只加1、snapshot仍null、Preparedfrequency/unique与旧fourrow及physicalcut相同。
2. HeaderFailureCodec经readyinit成功update后错误，检查ownedsummary仍等于新cut且active正确、query/referenceaccount一次、certificate未发布。旧headerfailuretest主要检查R/updatecount，不能代替直接aggregate绑定检查。

额外可验证counteroverflow时snapshotpointer内容也未变，以及fieldforgery不被宣称validated（无需为invalidcaller加未授权昂贵扫描）。真实snapshotcopy与oldmerge价格/wire/profilecounter差分和actualobjectsize应进入sourcefreeze验证。

## 性能证据界限

prepare避免四row256sum和nonzero归约，只需1024bytecopy；与此同时每个进入/离开stream的byte新增T[s]更新和zero-crossingactive维护，每个querystate增加约1KiB。 identicalcuts几乎不增加bytemaintenance，frequentlyrepartition则付新维护成本。这是源码工作取舍，不是实测热点比例或性能结论。

父代理已在独立baseline/public/samplegate流程准备对照；只有同source/exefile/完整levelpolicy、wire/profilecounter/资源稳定实测才可判断是否启用。不把少一次merge等价成wholeAPI相同倍数，或因为subject属于准备统计就默认接受生产性能优化。

## 本轮源码哈希

- `src/zstd/literals/aggregate_totals.zig`: `8915a6079f6aa19c6c721a42c4a785a31aaffe87b68360dc9e6c81b0d8aac4a2`
- `src/zstd/literals/aggregate_totals_tests.zig`: `c89f72954acc7db9d8c8b2332d811ce3e11cf37f14c3c4a5c28a64a7dd100582`
- `src/zstd/literals/cut_histogram.zig`: `7c9836675163db4b6982ddcc694eab0748e8a20992a6d17c2cb8047931d432c2`
- `src/zstd/literals/single_cost_cache.zig`: `09f9310ef8c41984cae503fa709354346584bdb4b95bd83e49eabfb4dff7e8d1`
