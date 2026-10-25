# Winner-aware literal cost cache 只读审查

审查目录：`/home/passchaos/project-z/vort-zstd-cost-bound`。时间：2026-10-25 14:13:28（Asia/Shanghai）。只读取源码与既有证据，没有编译、运行测试/编码、计时、修改源码或 Git。唯一写入是本报告。父代理在并行完成产线接线和测试；行号对应本轮读取时的文件，最终以函数名和下方内容哈希定位。

## 结论

当前固定 `SingleLiteralCostCodec`、合法128KiB以内block和未索引multi finder调用范围内，未发现unsafe lower bound、stale prepared绑定、Cf提前发布、shadow刷新泄露或incumbent tie错误。真实shadow结果支持该算法在XML/MR两种64KiB切片上有很高的可剪枝覆盖率，并且保持旧wire与候选数；它不是新prune产线的运行证据。

新实现的两个通用错误处理限制需要明确：Prepared API没有快照版本校验；`verifyRejected`会忽略reference error。当前内部调用序列和finder的catch-continue语义避免产线结果差异，但不能把此wrapper当作保留任意Codec错误行为的通用API。seed后流/头部边界与prune完整wire差分应在本次接线的相关验证中覆盖。

## 已核对的契约

### Prepared 频率与 live stream histogram

`winner_cost_cache.zig:57`在query局部取得prepared；其后只调用witness.analyze及固定Codec的纯header/sequence成本函数，不会调用histogram.update。非剪枝路径在`:80`立即把同一prepared传给Base精确定价，然后在`:89`用该频率及返回weighted scalar构造完整replacement。因此当前wrapper不存在跨cut重用prepared。

Base的`prepareLiterals`（`single_cost_cache.zig:135`）先完成当前cut histogram更新，再取得完整frequency/unique/R/raw_cost。`streamsLen`（`:184`）仍从self.histogram的canonical一/四流读取counts，`:197`把未舍入stream_bits相加。该和在当前绑定下等于sum(prepared.f_i*plan.bits_i)，不包含end bit、padding、jump或tree bytes。

Prepared API本身是内部可信协议：`payloadCostPrepared`没有核对prefix/tail、generation或frequency与live histogram。若未来调用者在prepare与消费间update另一个cut，scalar会属于另一频率，可能仍通过Certificate的数值envelope而失去下界保证。当前唯一wrapper调用安全；若扩大API使用，需文档明确single-query lifetime，或增加generation/cut校验。borrowed block也必须保持immutable。

### 成功 weighted scalar 与 11-bit 最优前提

Base `literalCostPrepared`（`:147`）只有fresh plan、tree可序列化、streams可用、实际header成功且checked total成功后返回非null weighted_bits（`:163`）；raw/RLE、R<64、plan/tree/stream null、Unsupported header均不返回scalar。`calculatePayloadPrepared`（`:111`）先literal再RLE/predefined；payload成功后才返回scalar（`:127`）。wrapper取到actual成功后才publish，init失败保留旧证书（winner`:89`）。

raw最终赢得literal选择也可以发布Cf，因为Cf描述成功fresh Huffman计划的加权位最优，独立于representation最终选优。`SingleLiteralCostCodec`（`src/zstd.zig:31090`读取快照）声明maxbits11/min_tree2，并仍通过fresh zero plan→finalize→compact/package-merge或深度<=11的自然最优Huffman路径生成位长。该源码/数学前提已经在 `bound-contract-audit.md`详细证明；本轮没有把decl flag视为运行验证，也没有执行Huffman oracle。

### drift + header/tree/streams/raw minimum

`weighted_bound.zig:77`逐byte检查完全相同的非零support，允许频率增加和减少，并以i64计算：

```
B = max(Rg, Cf + (Rg-Rf) - 10*sum(max(old_i-current_i,0))).
```

Cf=Opt11(old)，每个current合法1..11码也在old的相同Kraft域；正delta至少贡献delta，负delta至少11*delta，故B<=current最优加权位数。same cardinality不够，changed support返回null正确。至少2正权重时，完整Kraft与Kraft<=1最优域等价；成功last-weight校验保证当前wire完整Kraft。

winner`:125`..`:132`使用

```
S = (R<=1023 ? 1 : 4)
streams_lower = floor((B+S+7)/8) + (S==4 ? 6 : 0)
huffman_lower = header(R,1) + minimum_tree_bytes + streams_lower
literal_lower = min(prepared.raw_cost, huffman_lower).
```

这正是sum(ceil((b_i+1)/8))>=ceil((sum(b_i)+S)/8)的聚合下界，并另外计入四流jump6。header(R,1)避开compressed_size0的CorruptFrame，且固定R时正compressed_size的实际header只会增大。fresh tree>=2在direct和FSE路径均成立：至少2active=>max_symbol>=1=>direct>=2；FSE首字节+至少1 byte ended bitstream。当前不包含treeless路径。

raw/RLE最小值使用Base实际unique与R：空input raw payload0，单符号RLE payload1；R<64或unique<2直接精确回退，不强行使用Huffman。

sequenceBase（winner`:137`）原RLE/predefined helper第四参数为0，提取原exact additive sequence cost；CorruptFrame仅表示该模式不可用，非Corrupt错误返回null触发原fullprice。成功的literal_lower+min(sequence_base)不含外层3字节block header，与incumbent payload_len口径相同。

### shadow/prune/incumbent 与年龄

canUpdate（winner`:30`）完全对应原finder比较：cost更小，或cost相同但candidate match更长。lower不能更新才would_reject，因此相等且更长保留exact pricing，相等且同/更短可skip。没有incumbent时根本不检查下界。

shadow始终fullprice；有下界则核对lower<=actual，对would-reject成功候选再核对original comparison不能更新incumbent（`:81`）。`:88`明确只在!would_reject时发布；would-reject即使shadow看到fresh Cf，也不重置certificate_age。prune在同一predicate下increment logical cost_queries/rejected并返回null，保留旧snapshot/age（`:73`）。两mode的histogram都会prepare当前cut，certificate状态轨迹相同；shadow tree_entry可能多更新，影响性能而不影响Cf/精确长度。

age在每query入口、已有证书时saturating+1；成功replacement才reset0（`:56`, `:94`）。support变化、RLE/null和错误保留旧证书，age继续增大。这符合按wrapper query定义的age；它不随每次非nullincumbent检查才递增。使用旧snapshot直接计算Dminus，没有未经证明的增量drift链。

### buckets 与数值

bucket（`:34`）value0→index0；其他value→min(count-1,1+floor(log2(value)))，所有数组下标合法。negative_delta_histogram[18]的最后bucket含>=65536；age_histogram[16]最后bucket含>=16384。128KiB最大Dminus131072会正确落入最后桶。

总频率<=131072，M11时Cf<=1441792、Dminus<=131072，i64 drift安全。合法stream最多45057 bytes、四流/jump最多180234、tree<=128，因此实际compressed_size<=180362且R<=131072，合法actual header在262143范围内；(B+S+7)与jump的未单独checked加法有由该域证明的充足余量。最后u64→usize cast受检，metadata/payload add受检，失败都回到fullprice。

bound_checks和negative/age histograms在support成功后、header/sequence进一步计算前增加。因此它们是support可分析次数，不保证每次都产生最终payload LB。max_certificate_age也是下界eligible检查中观察到的最大值，不是所有query中的age最大值。no_certificate/raw_or_small等计数只在存在incumbent时更新，first candidate无incumbent不属于这些分类。

## 错误处理限制与真实风险

1. **Prepared-generation是内部前提，未在API编码。** 当前query局部顺序安全；跨cut复用prepared会影响Cf真实性和后续prune安全。见Base`:86`, `:184`。
2. **prepare失败重试仅对cut/admission错误完全无额外histogram更新。** winner`:57`catch调用inner.payloadLen重试；Base`:136`先hist.update、`:143`才literalHeaderLen。注入失败literalHeaderLen时第一次prepare已改变ranges/计数，重试会再增加update_count；wrapper注释“rejected preparation mutates no ranges”对这类error不成立。当前固定Codec在R<=128KiB时literalHeaderLen必成功，故产线不会触发；任意mock/stateful Codec不能据此声称完全相同的work/error调用次数。
3. **prune reference错误未纳入诊断。** verifyRejected（winner`:154`）验证成功reference成本，但`:162`忽略所有reference errors，不增加mismatch也不传播。任意Codec若literal阶段在已有证书的后续query中报错，而sequence/header下界仍可算，prune会return null，shadow会返回原错误。当前finder原本对成本errors和null都continue，固定合法Codec也没有预计的literal arithmetic/range error；生产选优语义不变，但wrapper不能承诺一般error-exact行为。未来可扩大的error域应受独立回归约束。
4. **shadow计数不能替代新prune运行验证。** 当前产线接线和profile默认已改prune，主文件hash与shadow执行快照不同。尤其shadow tree cache更新较多，不能把would-reject比例直接换算成吞吐speedup。

## 现有证据的独立核对

读取 `shadow-result.json`、`shadow-work.json`；记录exit_code0、source_before==source_after且source_stable=true，x86_64/ReleaseFast/Zig0.16.0。winner/Base/weighted模块当前hash仍与该run一致，zstd主接线和工具hash已变化。

| Corpus 64KiB | queries | would_reject | refreshes | bound_checks | violation/false |
|---|---:|---:|---:|---:|---:|
| XML | 1473017 | 1443518 | 29499 | 1472254 | 0/0 |
| MR | 1039932 | 1023531 | 16401 | 1023977 | 0/0 |

两组queries=would_reject+refreshes；两组negative/age histogram sums都等于bound_checks。未分类query各128，与每个finder首次无incumbent候选一致。shadow rejected=0，reference_checks=0（production Codec无callback），但shadow明确对每个产生LB的成功actual计数核验。

与 `/tmp/vort-zstd-duplicate-profile-20261025/work.jsonl`独立比较，input_bytes/available/encoded_bytes、input与wire hashes、finder_calls/selected_matches/histogram_scanned_bytes/histogram_updates、cost_queries均相同。旧hash字段是ASCII hex再hex编码，正规化一次后与shadow64字符hash相等。XML wire41940 bytes、MR22857 bytes。未使用profiled_ns做prune性能结论。

既有shadow Debug/ReleaseFast日志各报告12 tests passed，但它们是旧shadow接线的小profile测试族，不是新增winner tests或新prune全wire验证。本轮未执行日志中的命令。

## 现有与必需测试

当前新 `winner_cost_cache_tests.zig`源码已覆盖：strict reject（prune未增加huffman_plans）、shadow保留fullprice、old witness和age不刷新、人工exact lower equality且longer保留、invalidcut/ML2不发布、support change回退、flat tree null/RLE/small不发布、shadow/prune finder winner参考对比。测试是有效入口，本轮只读没有宣称运行通过。

Base旧tests继续覆盖其exact成本及分流边界；wireAndAllocations比较multi(false)与multi(true)，因此产线改prune后相关现有测试会实际对比generic reference与prune wire/allocator行为。其最大block65537，不能替代128KiB新证书边界。

当前接线应验证以下项目（可在已有测试中增加覆盖或用现有合适入口满足，不要求重复实现）：

- seed后same-support drift在query中同时出现正/负delta、同总量换频率，并使两mode获得相同certificate与age轨迹；数学tiny exhaustive不能独自证明wrapper快照绑定。
- R63/64、1023/1024、16383/16384、131072，跨一/四流、header3/4/5与padding余数；至少一次真实prune reject，逐candidate callback对比与完整finder winner均无差异。
- same-cardinality但不同symbols、新增/删除support、missing symbol后又恢复、raw-final-winner但完整Huffman成功时Cf发布；null/error路径保留旧certificate。
- invalidcut、ML<3、illegaloffset或不可用sequence模式在incumbent存在时仍回退fullprice，并保持reference/error合同。若要宣称genericCodec error-exact，另需注入literal/tree/sequence非Corrupt错误并覆盖would-reject路径。
- 真prune的XML/MR raw block hashes/queries/selected matches与旧证据一致，128KiB complete multi wire、allocation与encode/decode/public caller smoke正确；单路径优化的性能结论再由父代理独立测量。
- 非索引与索引/小block admission边界未改变，single与indexed仍走原代码；逻辑cost_queries=wrapper queries且合法cut每query恰一次histogram update。

## 启用范围

当前`emitMultiDuplicateMatchCompressedBlockProfiledMode`（`src/zstd.zig:23279`读取快照）仅在cache_costs、duplicate_index==null、block.len>duplicate_exact_hash_input_max且<=标准block最大值时构造winner/shadow cache。indexed分支先行，small/admission不满足时走原finder。single helper和无cache的`findBestDuplicateMatchHashed`保持原exact路径。production默认.prune只通过multi调用链进入，null candidate立即continue且保留原winner比较。

现有encode/decode公开签名与这些limits未变。增加了公开诊断 helper `benchmarkNativeMultiDuplicateProfileMode`并使旧profile helper默认prune；这是一项诊断扩展，其mode/work口径应保持文档一致。`profile_work=false`不构造Profile且不执行profile defer；winner.bound_work自身仍有源码中的计数更新，是否优化消除不能仅凭该flag作claim。

## 内容哈希

- `src/zstd/literals/winner_cost_cache.zig`: `6ba152ff5934a97a6b1945b7d7492505d2760b79cb67630328c04f85ae936166`
- `src/zstd/literals/single_cost_cache.zig`: `f0329e0e93e16996dfcf32451ed6b858ff61c095891e9d84e9518034ab43395b`
- `src/zstd/literals/weighted_bound.zig`: `52ed8c0e99c7ea827c904ac87957315f690a1774fba20ed05410c7f5f6474313`
- `src/zstd/literals/winner_cost_cache_tests.zig`: `9cca55c33c5859d8663b722f27f51d385a5f91f5e1c57bc96a88cf8f2077aa29`
- `src/zstd.zig`: `490d3f2c560fecb0261ddafc79d04c1c3efd9000aa22bec7774917d5cd0459dc`
