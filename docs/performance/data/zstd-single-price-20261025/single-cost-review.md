# Single-sequence base pricing 只读审查

- 工作树：`/home/passchaos/project-z/vort-zstd-single-price`
- 基线：`5928518f0c6dc4cea028dba3c6692a7128b74275`
- 时间：2026-10-25 14:55:24（Asia/Shanghai）
- 范围：源码、原helper/OF table/mask契约、新single_cost与QAhelper、winner可选hook及kernel benchmark静态口径。没有编译、运行测试/编码/基准、计时或修改源码/Git；仅写此报告。源码仍由父代理/worker并行完成，hash对应本轮读取快照。

## 结论

最终冻结版本（a6f328f7/e663ac2f）固定Rules接线下，single-sequence base公式与原RLE/predefined helper完全匹配：RLE=`5+ceil((E+1)/8)`；predefined=`2+ceil((E+18)/8)`，且只有LL/OF/ML三个min-filtered masks均非零时可用。OF接线正确使用 `predefined_offset_state_masks`（min additional bits2），不是min0 code mask。该匹配来自canonical(base,width)与decoded FSE state描述逐项一致，而不是假设offset code与额外位数天然相同。

winner仅在下界sequenceBase中使用可选hook，原fullprice/emitter/helper主体仍原样；另有一项通用offsetCode加3 overflow安全guard，属于额外安全修复，报告不能说generalhelpers完全不变。QAhelper提供独立table扫描和bit-packing长度oracle；14:55:30最终回读已确认在zstd模块约31220行注册contracts。性能收益由父代理实际kernel和public benchmark决定，静态审查不预测收益。

## 原single序列成本的精确推导

设canonical LL/OF/ML code分别cL/cO/cM，E=ll_bits[cL]+of_bits[cO]+ml_bits[cM]。

RLE helper `src/zstd.zig:28238`先按LL、OF、ML顺序调用sequenceCodeForValue；`:28256`单序列只需确认同一码，位数1个结束位+E。长度为sequence count1 byte+mode1 byte+三个RLE code3 bytes+bitstream ceil((E+1)/8)，所以base5+ceil((E+1)/8)。单序列没有RLE额外表开销。

Predefined helper（`:28102`）按LL、OF(min2)、ML规划；`predefinedSequenceReadFields`（`:31767`原读取位置）固定initial fields6+5+6=17 bits，并添加三个symbol.additional_bits。单序列 `i+1<len`恒false，不写transition state_bits，因此decoder表中的变化state_bits不会改变single成本。加结束位1后base=sequence count1+mode1+ceil((17+E+1)/8)=2+ceil((E+18)/8)。

对E=8q+r、0<=r<=7：RLE=6+q；predefined在r<=6时5+q，r7时6+q。最终 `single_cost.zig:52`保留RLEfirst checked section add；三个mask可用时`:63`显式计算checked predefined cost，`:64`只在严格更小时选择它。相等保留RLE，和原strict less比较一致。这里只返回成本，没有选树/FSE state或输出wire。

当前Contract把initial6/5/6、OF minbits2、extra maxima16/31/16固定；E<=63，bits+25、6+bits/8安全，32/64bit usize一致。section_len+base受检（`:97`）；原helper所有中间增量非负且不大于最后总和，所以是否overflow相同。尤其section=maxIntusize−5、E2时predefined可单独恰好fit，但RLE溢出；base必须返回IntegerOverflow，不能用更便宜predefined消掉原RLEfirst错误。新实现及QA明确保留此规则。

## OF min2 与wire编码值的具体匹配

`of_base`（`src/zstd.zig:457`）前项是0,1,1,5,13,29,...；`of_bits`前项0,1,2,3,4,5,...。`offsetCode`（约`:32089`最终读取快照）对value0返回code0；value>0采用floor(log2(value+3))并验证base/span。这是当前encoder传递的offset value坐标，helper没有额外改写value为其他repcode编号。

`buildPredefinedStateMasks`（`:31428`原读取位置）只在symbol.base==of_base[code]、symbol.additional_bits==of_bits[code]时加入state，并先过滤additional_bits<2。legacy `planPredefinedSequenceValues(offsets,&offset_symbols,2)`通过pointer/min2专门分支查询同一个offset_state_masks。len1时所有encodable state直接viable，返回最低state；不受next_state transition限制。

具体关键值：

| offset value | canonical code / extra | min2 decoded FSE state | predefined可用 |
|---|---|---|---|
| 0 | code0 / 0 | 无（state0 extra0被过滤） | 否，RLE仍可用 |
| 1..4 | code2 / 2，base1 | state14，base1/additional2 | 是 |
| 5..12 | code3 / 3，base5 | state5，base5/additional3 | 是 |
| 13..28 | code4 / 4，base13 | state19，base13/additional4 | 是 |
| 2^29−4 | code28 / 28 | state27，base2^28−3/additional28 | 是 |
| 从2^29−3到2^32−4（canonical合法） | codes29..31 | 无对应FSE state | 否，RLE仍可用 |

decoded offset state23也是base1，但additional_bits1；它在min2路径被过滤，且code1不会被value1..4的canonical classifier选择。若错误用min0 `predefined_offset_code_state_masks`，offset0会被当作可用；再以E0价格比较会得predefined5而原min2 helper只能RLE6，破坏exact-size合同。新Rules `offset_masks=&predefined_offset_state_masks`（`src/zstd.zig:31137`）避免此错误。

只读解析源码array描述进一步核对：LL36codes、ML53codes每个都有匹配FSE state；OF32codes的min2空masks正好[0,1,29,30,31]，所有remaining state(base,width)均匹配canonical描述。LL/ML canonical ranges互不重叠；OF code1/code2重复base1的重叠在min2过滤后消失，codes>=2各区间也互不重叠。因此legacy decoded-state span scan与new mask availability/current code额外位数匹配。这是源码结构验证，没有调用生产编译/test/encoder。

## Calculator与winner接线合同

`src/zstd/sequence/single_cost.zig:22`无分配、状态或retained pointers，classify只执行一次LL→OF→ML，并核对返回code在bits数组内。实际Rules用现有literalLengthCode、offsetCode、matchLengthCode；这些分类器只返回CorruptFrame/成功。predefined单mode的classification failure映射CorruptFrame，对应原planner mask不可用；baseLen分类失败后整体不可用，实际两模式也不会成功。

validateContract/validateTable（`:105`）约束initial width、OF min2、table shape、码长上限和mask所表示state编号范围；它不自行证明每个mask的state descriptor正确，这是Rules caller契约。当前Rules直接用原comptime masks，前节已核对。不要把这个私有Calculator泛化成任意classifiers/masks的自动证明器，也不承诺stateful classifier多次调用副作用的旧调用次数。

`winner_cost_cache.zig:137`只在Codec存在singleSequenceBaseLen时调用并catchnull；错误则下界不可用，后续原exact price仍执行。没有hook的Test/其他Codec仍采用原两个sequence helper。new Codec.singleSequenceBaseLen只传section0给Calculator.baseLen（`src/zstd.zig:31101`）。原Base full exact cost用Codec.rlePayloadLen/predefinedPayloadLen，他们仍委托原general helper，emitter/序列选择没有替换。new下界sequence base与旧exact base相同，因此不改变已有Cf/Prepared/header/tree/stream/incumbent合同。

当前winner QA VerifiedCostCodec已alias新hook（`winner_cost_cache_tests.zig:15`），原reject/longer equality/support/error/age测试会走新序列定价路径。fallback Codec缺hook时仍原价模式。

## 通用offset overflow安全修复的范围事实

当前diff增加 `offsetCode`的 `value>maxInt(usize)−3 => CorruptFrame` guard，防止value+3发生usize overflow。它不影响任何合法canonical offset，因为最大合法value为2^32−4；32bit也恰好使value+3<=maxInt。对maxusize−2/−1/max这类超域值，旧Debug可能trap或ReleaseFast出现溢出结果，新guard给CorruptFrame，与scan-table reference相同。

这是通用classifier的一项行为安全修复，超出“generalhelpers绝不变”的字面范围；父代理已获提示，应在最终说明/commit中明确。新的 `zstd offset code rejects arithmetic overflow before adding bias` test针对0/1/2/3/4、u32/usize最大附近值与旧无加bias扫描reference对比。formula优化不能掩盖这个额外修复。

## QAhelper独立性、覆盖和当前注册状态

`src/zstd/sequence/single_cost_tests.zig:20 scanCode`独立扫描canonical base/span，采用base最大/等base后code的旧selection规则；`:30 scanState`独立扫描decoded FSE states与min2，不使用newmasks。`:38`与`:52`的oracle用ByteWriter逐位写initialstate/extra/end bit来算实际bitstream bytes，再按原次序加count/mode/code，避免仅重写公式镜像。最大的single bit数<=81，16byte内部buffer足够。这里验证长度而不声称逐bit reverse wire相同。

`:87 check`同时对比三种新成本与原RLE/predefined/base helper及三个独立oracle，含exact error。已读覆盖：

- 每canonical code的base/span end及±1（含OF重叠base、states空hole）、offset0/1/2/3、LL/ML131070..131075、u32/usize最大附近、64bit>2^32超域。
- E模8全部余数，r7 tie与其他少1；section0/1/4096/溢出边界，保RLEfirst overflow。
- 每个LL/OF/ML mask分别故意挖hole，验证predefined unavailable/RLE fallback；synthetic policy不错误地声称等于原非hole成本。
- 512组合法/超域随机值和section近overflow。

生产QA helper在14:55:30最终回读已确认 `src/zstd.zig:31220`注册 `single_cost_tests.contracts(SingleSequenceCostTestCodec)`。最终生产scalar filter已在native Debug/ReleaseFast与x86 ReleaseFast各11/11通过，winner Debug/x86 ReleaseFast各11/11通过；这些是读取现有result/log后的事实，本审计没有执行。详细运行epoch见末节。

## 性能证据范围

`tools/zstd/single_cost_bench.zig`静态设计是同process old general helper vs new scalar Calculator；四shape（small、64KiB值、large OF codes24..31、invalid lengths），64triplets/shape，初始对全部exact cost/errors相等，warm1000、5round交替、runtimeLCG/noinline query和mix防hoist。timedpass包含选择、调用、cost/error、mix/loop，不是独占分类器时间；invalidshape包含LL/ML超域和offsetmax，不代表一般合法input速度。

该诊断提供base定价局部证据，不能直接外推为public compression throughput倍数。父代理应在源码稳定、无编译干扰时测kernel，再验证新/旧public14完整wire、candidate queries/选优和成本正确；无可重复收益时允许拒绝优化并保存结论。最终micro实测支持局部定价收益，公开API收益尚未测得；见末节，不能将micro倍数作为wholeAPI结论。

## 内容哈希

- `src/zstd/sequence/single_cost.zig`: `d2a33d7d9cd08002db5504890bc7527324f2d4d40ce044cbf5692f45d35cbf48`
- `src/zstd/sequence/single_cost_tests.zig`: `1440875cababda795366ae2e762f746dad4d9d12594c8dfc1b4dce5a1b8d8133`
- `src/zstd/literals/winner_cost_cache.zig`: `f8319362c42e785234dbc961004da5e9258c9caeb5410586414d68a1ead1ddc5`
- `src/zstd/literals/winner_cost_cache_tests.zig`: `504e7b0522aefa41f3e755444436a94563b2a86119655621b1bdb30e94bfa3e3`
- `src/zstd.zig`: `72cbede8fd4f4770e1cbaab26f7f375e43c3d335729ab4bee8fe6413692116ca`
- `tools/zstd/single_cost_bench.zig`: `b4b22b73b5c98c3772cac8efa68fd3548814a4a10191d88a99c1c984cccd79e1`


## 冻结源码、最终测试与micro证据（2026-10-25 15:03:35 Asia/Shanghai）

只读末次核对当前代码HEAD `e663ac2f`，前一功能提交 `a6f328f7`：

- `a6f328f7 perf(zstd): price single sequence bounds without state planning`
- `e663ac2f bench(zstd): compare general and scalar single sequence prices`

### 最终源码和计数范围

最终single_cost helper SHA256=`d2a33d7d9cd08002db5504890bc7527324f2d4d40ce044cbf5692f45d35cbf48`；production QA helper=`8c7544d7e70364b1e801198703f050711c9c8c23315f26e17c08b04fd7d85eb0`。最终helper改用明确的LL→OF→ML分类局部变量，baseLen仍先checked RLE section add，再在三个mask均非零时checked predefined section add，最后strictcompare；没有shortcut重排原错误时序。rlePayloadLen/predefinedPayloadLen各自模式及base的成本/可用性/IntegerOverflow合同不变。

与5928518f基线的Base `single_cost_cache.zig`diff为空；winner cache的diff仅sequenceBase中的2行可选Codec hook。准备cut、逻辑query计数、certificate age/refresh、bound_checks/rejected与reference逻辑没有变动。对真实相同合法query/newsequencebase==oldsequencebase，则lower/incumbent决策和这些逻辑计数保持；这是源码与公式推论，当前尚无最终public/profile逐候选counter实测，不能把推论改写成已测counter一致。

当前Rules.offset_masks仍为min2 `predefined_offset_state_masks`，full exact price/emitter仍委托原general sequence helper。额外generic offset bias overflow guard及其named table-scan oracle明确保留为单独安全修复，docs/performance/zstd-single-sequence-cost.md也如实描述。编码公开签名/limits不变；新增benchmarkSingleSequenceBaseLen只是诊断入口。

### 已完成测试（读取已有证据，没有重跑）

| result目录 | command重点 | 结果 |
|---|---|---|
| scalar-debug-final | zstd scalar single filter，native Debug | exit0，source_stable，11/11 |
| scalar-releasefast-final | 同filter，native ReleaseFast | exit0，source_stable，11/11 |
| scalar-x86-final | 同filter，x86-linux-musl ReleaseFast | exit0，source_stable，11/11 |
| winner-debug | winner cost filter，native Debug | exit0，source_stable，11/11 |
| winner-x86 | winner cost filter，x86-linux-musl ReleaseFast | exit0，source_stable，11/11 |
| complete-family | zig build test-zstd ReleaseFast native -j2 | exit0，source_stable，5/5 steps，1096/1096 |

这些result的source_after均绑定上述最终helper/QA hash。11是filter连同imported helper tests的数量，不是11个独立single-cost子case。QA内部还包含全部code边界、独立state scan/min2、8个E余数、overflow和512random。旧失败编译日志和早期较小module test不是最终结论；报告使用-final结果。

### micro schema与源码epoch

`micro-samples.json`schema=`vort.zstd.single-sequence-cost-bench.v1`，iterations250000，四shape各5轮，general_first顺序true/false/true/false/true，JSON记录完整raw general_ns/scalar_ns/mix。每行median字段重新从raw5round排序核对一致，同一shape各轮mix一致。

`micro-result.json`记录2026-10-25 06:54:28 UTC、exit0、source_stable=true、8次compiler观察均无compiler process。executable SHA256=`9a58d14cf744028ca06e7fd5b339699d6ccf95cf0d1c48811b481a46e097adef`，与samples/provenance/analysis一致。ReleaseFast、Zig0.16.0、x86_64/skylake+pku+sgx、Intel i7-10700K、单线程CPU8。

精确epoch限制：micro record主 `src/zstd.zig` SHA256为`7f654071421b6aba0f1f1441832b2d85842ff462478519f3990a74006a12c6ec`，最终当前主文件为`72cbede8fd4f4770e1cbaab26f7f375e43c3d335729ab4bee8fe6413692116ca`；micro source record包括helper与tool且它们与最终hash相同，但未列QA/winner文件。source_stable是记录文件在那次micro执行前后稳定，不是全部最终树已以micro身份测量。这个micro可支持同一helper/tool的局部实现测量；完整最终代码安全由-final tests/family提供，wholeAPI仍需专门测试。

| shape | general median ns/query | scalar median ns/query | general/scalar |
|---|---:|---:|---:|
| small_values | 50.616364 | 14.718624 | 3.438933 |
| block64k_values | 41.903000 | 7.757704 | 5.401469 |
| large_offsets | 82.922312 | 10.565972 | 7.848053 |
| invalid_lengths | 131.600472 | 6.718284 | 19.588406 |

这是同process general helper vs scalar formula的warmed局部工作负载收益，包含call/loop/input selection/error/mix；invalid_lengths是错误定价路径，不能代表一般合法codec input。没有public current14结果，check尚在父代理工作流中，故本报告不宣称公共压缩吞吐加速、wire全部不变或行业领先。原baseline14仅是后续对照准备，不能算完成before/after。

最终代码哈希：
- `src/zstd/sequence/single_cost.zig`: `d2a33d7d9cd08002db5504890bc7527324f2d4d40ce044cbf5692f45d35cbf48`
- `src/zstd/sequence/single_cost_tests.zig`: `8c7544d7e70364b1e801198703f050711c9c8c23315f26e17c08b04fd7d85eb0`
- `src/zstd/literals/winner_cost_cache.zig`: `f8319362c42e785234dbc961004da5e9258c9caeb5410586414d68a1ead1ddc5`
- `src/zstd/literals/winner_cost_cache_tests.zig`: `504e7b0522aefa41f3e755444436a94563b2a86119655621b1bdb30e94bfa3e3`
- `src/zstd.zig`: `72cbede8fd4f4770e1cbaab26f7f375e43c3d335729ab4bee8fe6413692116ca`
- `tools/zstd/single_cost_bench.zig`: `b4b22b73b5c98c3772cac8efa68fd3548814a4a10191d88a99c1c984cccd79e1`
