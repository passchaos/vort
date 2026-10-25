# Work accounting 最终证据复核

- 源码：`/home/passchaos/project-z/vort-zstd-work-accounting`
- 基线/候选：`e4bfdd63` → `a8defd42e541421a475aab3c6488606ccfc75662`
- 复核时间：2026-10-25 16:05:06（Asia/Shanghai）
- 只读范围：既有raw sample/result/资源事件/ELF摘要与对应源码身份；独立重算数字和文件hash。未编译、跑测试/编码/基准、计时、修改源码或Git；仅写本报告。

## 接受结论与边界

接受此次纯统计专门化为小幅性能改进和明确464byte缓存对象缩减。默认未索引multi使用无Work实例，诊断保留全量计数；功能/错误/证书和资源合同证据通过。公开14行首轮geomean speedup为1.010826x，三个focus输入复测的processmedian之median为1.012298x/1.028748x/1.022357x。

这些是限定数据下的小幅观察值，**不是统计显著性、全平台/全等级/稳定行业排名结论**。首轮MR确实变慢，保留其0.969849x，不用复测覆盖或隐藏。与本地Zstd1.6.0对照，候选吞吐GM仅0.00393447、0/14胜出，因此仍未达到业界最佳。464bytes是cache object大小差，实际requestedheap本次不变，不宣称RSS或总stack减少。

## 独立重算14行公开比较

读取baseline14/samples.json与candidate14/samples.json，对14个相同frozen64KiB SHA逐项匹配；每个版本在一个process中每input5轮交替vort/reference。独立从raw vort_ns和reference_ns排序取median，再计算old/new与reference/new，全部与analysis.json一致。old/new settings与完整wires对象逐项相等，14/14输出不变。

重算：

- version speedup GM=`exp(mean(log(old_median/new_median)))=1.010826416794477`。
- candidate throughput/reference GM=`0.003934472416971656`，throughput wins0/14。
- 14行中9个new较快，5个较慢；不能描述为每行获益。
- candidate totalbytes310437、reference328241；13/14输出更小，这是ratio切面，不能抵消吞吐未领先事实。

保留重点首轮median：

| 输入 | old ms | new ms | old/new |
|---|---:|---:|---:|
| MR | 501.419941 | 517.008229 | **0.9698490524** |
| XML | 588.344770 | 579.799678 | 1.0147380075 |
| source | 225.816693 | 223.356663 | 1.0110139092 |

MR首轮new耗时约高3.109%，其余四个负向输入为dickens、mozilla、samba、sao。没有为这个小单轮version差异赋统计显著性，也没有因复测结果反向而改掉原rawsample。

## 重复focus：3个交替process pairs

读取repeated-focus/result.json与0/1/2-old/new六个rawsampleJSON。实际process顺序为old/new、new/old、old/new；每process3inputs×5round，均level3、iterations1、limit65536。每process独立从5个rawvortns取median，再对3个processmedians取median；该层次没有误当作15rawround简单median。

| 输入 | old process medians ms | new process medians ms | oldmedian/newmedian | 三个pair ratios |
|---|---|---|---:|---|
| MR | 502.297366, 510.464272, 503.651625 | 495.879577, 497.533126, 498.828634 | 1.0122976716 | 1.012942, 1.025991, 1.009669 |
| XML | 596.637347, 594.879670, 597.053517 | 578.378053, 579.964362, 580.630321 | 1.0287482923 | 1.031570, 1.025718, 1.028285 |
| source | 228.248040, 227.652421, 228.367816 | 222.307114, 223.256705, 223.486092 | 1.0223569321 | 1.026724, 1.019689, 1.021844 |

每input三个pair ratio均>1。所有rawfocus版本/轮次的settings与wires相同，输入SHA相同，每input输出wirehash一致。该复测缓解首轮MR方向不稳的顾虑，但仅针对MR/XML/source三个输入和3pairs；不扩展为重复14行、稳定跨平台、alllevels或显著性保证。

## 执行、源码与reference身份

baseline/candidate实际执行文件重新读hash与result/provenance匹配：

- old encoder SHA256 `5d14ea6817ac59176c0ee38b8f1331d627569e534f8a1cc7fcd08b46b5380b0b`。
- new encoder SHA256 `d32df6453d43fb7f2c8b64eacb55a271e1d662806eb5577fd3803d1e2bd8ebfa`。

14行两result均exit0、source_stable/reference_stable/executable_stable=true、compiler_observations_with_process0；各sample gate exit0。focus六run均exit0、0compiler、实际样本provenanceexe与runhash相等，sourcebefore/after stable。关注的是已freeze相同源码执行，不能仅凭GitHEAD或未使用helper证明代码身份。

运行条件为ReleaseFast/Zig0.16.0、x86_64/skylake+pku+sgx、Intel i7-10700K、单个benchmarkthread、affinityCPU8；公开API保持level3完整level_policy/auto，未通过改变level/quality/searchbudget换取统计。reference请求本地Zstd1.6.0动态库，file SHA256 `c76f4c4457df67a5e0c7bb6bb4f58b9857cf4f2cdd7925bfb9345daac4e6b83e`。samples loaded_identity=null/dependencies_verified=false，故验证的是请求文件及其freeze身份，不夸大动态依赖身份核验。

## Tracked诊断统计和对象大小

profile-result/profile-work的XML/MR读取后与旧anchor实验noanchors rawrow直接比对：inputbytes/available/encodedbytes/wirehash相同，**所有work fields deep-equal**，cache_state_bytes仍6032。这验证trackeddiagnostic接口行为保持，profile时间排除在publicspeedclaim外。默认production untracked无Work不能用其字段读数与tracked比值说明真实codework消失；这由源码/ELF与功能oracle共同验证。

已有实际sizeof：native6032/5568，x865980/5516，均减少464bytes，对应Work56+Work400+age8。ELF独立审计旧默认exactemitter21个sat统计update、2个bucketLZCNT→new0/0；checkedHistogram、Certificate math/publication和streamproducts/emitter保留。这是特定native符号静态站点与cache对象，不是dynamicinstructioncount或全frame/RSS指标。

## 资源事件与错误：实际heap没有减少

读取memory/final-validation及old/new-allocation-events.json，独立deepcompare事件JSON一致。范围是publiclevel3 XML64KiB一次encode和tinyforcedfirstallocationOOM；不涉及C/referenceencoder、没有RSS/wall采集或14corpus资源复测。

两版本：

- 282个request/free事件相同；115次成功allocation、51次成功remap、resize0。
- requestedheap peak均2561185bytes，output5078bytes与SHA相同，返回时仅output5078live，callerfree后live0。
- increased/released最终均4462540bytes；tinyforcedfailure均OutOfMemory/live0/allocattempt1。

ledger以page_allocator为backing，计callerallocator请求及返回output至callerfree；排除input、fixedstack/tracker、code、bookkeeping与OSpagerounding。resourceprobe tracker本身sizeof16528，不在该ledger。候选build中HEAD从基线推进到a8defd42但所有源码hash不变，完整manifest绑定编译与执行；不能把commitonlytransition误当作构建源变化或新编译执行。

资源结果支持输出/分配/error合同保持，**不支持heappeak下降**；464byteobject缩减是另外的compiledsizeof证据。

## 完整验证与剩余限制

读取完整check/result.json：exit0、source_stable=true，`172/172 steps succeeded`。先前accounting三targetfilter各11/11，完整nativeRF test-zstd1102/1102；外部callbackQA覆盖完整成功/error、refobserver、副作用、prepheadererror与Histcheckedoverflow等行为。审计代理未重新运行命令。

最终验收满足这次范围：统计关掉不改变codec/policy，trackedprofile保留、对象size小464bytes、限定公开测量有小幅收益，heap/wire/error合同保持。后续提高性能bar应继续研究剩余matcher/entropy/stream等真实热点，但本证据不能直接给热点因果排名；跨平台/更宽corpus验证或更高industrybar仍属于后续工作。

## 复核产物hash

- `analysis.json`: `95b241e26ee3f9bbf36fa6d195294955cb08e7d61b320f99f3d4ca89f5fa5381`
- `baseline14/samples.json`: `115947b502917575b9da072a337c6c4433259d04e92df261f6327db7c49f3fce`
- `candidate14/samples.json`: `af424cca47e9eca7362ed7049bb829140774920ec5d8f99d3e50c512621b3f7a`
- `repeated-focus/result.json`: `0b7d11e7aae23c193057e10670df175d144fbd396c8116500627272e6cafd7b8`
- `profile-result.json`: `f0b38a5211cee489450ceb5b2b481f45bb1b1b91540fe9042d96e182835295ea`
- `profile-work.json`: `eb6db55b4d325427ceaf3829e2b554650bfaa9358ef34a00207c21fa81a68bd9`
- `memory/final-validation.json`: `7e7aa5f35ca35d51ae94b197cbbdbd4e5edb1210051edbb4ba1ef0d5abee74e2`
- `memory/old-allocation-events.json`: `bb4e3e13b919217e8df17510cba2a7f4b20c6629b7806f6839d884d39953e0f3`
- `memory/new-allocation-events.json`: `bb4e3e13b919217e8df17510cba2a7f4b20c6629b7806f6839d884d39953e0f3`
- `complete-check/result.json`: `3eea1411bac27b67557b5cd83075fd5043de030b5c045f83dedd9b935df2a4ab`
