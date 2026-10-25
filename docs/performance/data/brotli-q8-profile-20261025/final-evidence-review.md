# Brotli q8 instrumentation 最终证据复核

- 源码：`/home/passchaos/project-z/vort-brotli-q8-profile`
- 当前功能提交：`212f1431 feat(brotli): profile the native q8 candidate pipeline`、`8279c31a tools(brotli): record and validate q8 candidate-stage reports`
- 复核时间：2026-10-25 17:04:29（Asia/Shanghai）
- 范围：既有rawprofile/publicsamples、gate/results、freeze源码hash、alias测试产物和真实赢家事件；独立重算perround equations/median/fraction/GM。未编译、执行test/encoder/benchmark、计时或修改源码/Git；唯一写入为本报告。

## 接受结论与限制

接受为真实固定q8/generic/defaultwindow16 pipeline的诊断与验证面，**不是压缩算法/性能优化**。70轮profile全部完整、exactwire保持，事件层级和exclusive分解通过独立重算；普通编码旧新14行wire和settings全部相同，契约/完整family/check通过。

公开ordinary旧新GM点比1.010577不作为优化收益、显著性或更快CPUcode证据。instrumented profile用于定位具名阶段和尝试配置，不能与libbrotli吞吐直接排名；各阶段median不可相加，fraction必须每round计算后取median。relative-reference吞吐GM0.0282557、0/14获胜，仍不支持行业领先结论。

## Source与执行身份

冻结核心hash与本审计当前读值、linkedQA、profile14、公用new14及finalcheck source_after相同：

- brroot `0be45f1153d120230bcadcdcc9958df54d32d06d92537f90fe3057ba9d722082`。
- qualityprofile `aa3e79ec0c3d304fe84bd15e6f88591762e02e1e70e3bfbf4512444902078451`。
- QA `4684b0d75d0a01395597cf35379384179c7c7e15f687f07bc5441b04a967f8ca`。

普通oldencoderSHA=`541df153c9ba535d998ab3e53d6c4401da834b438a2f84b312cea1909aeced5b`，newencoder=`a6f1f0bb5d4d403605b9989e6006f64b3f44d86fedb87d9215140b9cf216b725`，profiletool=`eb7309f7f37f0e73b4ca2f44be6509a1dc1bc35d44413c78f3c05c7a52945be7`。重新读取这三个exehash均与result/provenance匹配。

profile14 08:57:30..08:57:41 UTC，14input×5round共70，在一process中normal/profile交替；source_stable=true、exit0、102compiler观察/withprocess0。newpublic14 08:58:34..08:58:48 UTC、oldbaseline14 08:34:51..08:35:06 UTC，各版本一process、14input×5个vort/reference交替round，exit0/source_stable、withprocess0；newreferences_stable=true。早期tool-build Mozilla单轮smoke存在并行编译，已在profile-review单独限定，不能把它作为这次完整受控窗口数据或与它比较性能。

当前工具输出alias修复源码SHA=`a94eaf4d9ebddcf5d692a8f5c9d002c1980b79f2b847522be84a9b5c02793b9f`。工具源码调用encode_samples.requireDistinctOutputs在读取/编码/写JSON前拒绝同路径、规范化/symlink/hardlink别名。profile14的source snapshot只收集src *.zig，未单独保存tools/br的hash；因此“source_stable”不自动等于工具所有transitivefiles freeze，工具执行身份以实读exehash和alias执行产物绑定。随后补充br-tool-source-bindings.json显式固定tools/br源码与两个exe身份，本审计逐文件核对该sources全部hash与当前相同；它是额外after绑定，不是当时计时执行前的完整manifest，不能改写原result为完整toolsbefore/after核验。

## 全部70run exclusive独立核算

读取profile14/samples.json，14个输入均65536bytes、每个5round，全部wire_equal/roundtrip_verified。保存3470events，每run event_count=events_total<=512、nottruncated、timing_complete和wirecoverage_complete为true。按id建立直接children，独立对**每个event，含所有leaf**核对：

```
event.exclusive_ns = event.inclusive_ns - sum(direct_child.inclusive_ns)
summary[stage] = sum(event.exclusive_ns for nonouter events at that stage)
sum(summary) + unaccounted_ns = outer_elapsed_ns
```

70run全部精确成立，与独立gate-result validated_runs70一致。instantprefer selection默认0duration、没有clock/Frame，strictaccepted与gain相符；timedfinalselection是另一个accepted=null scope，不混淆。子范围只从直接parent减一次，不把孙范围再次减或把所有inclusive加起来。

每run returned_wire_event_id指向成功Recordedwire且bytes等于返回wire；wire_attempts等于Recordedwireevent数量。全14输入尝试次数范围8..20，不能把“18个wire”泛化到所有输入。全部是typedcandidate配置观察，不代表everyinternalkernel独立计时；smallinput<=4096未Recorded字典coverage限制依旧在接口文档，本批65536不触发。

stage medians与analysis.json全部重新由raw5round排序核对。preferred_context_fraction取 `median(pref_exclusive_this_round / outer_this_round)`，**不是medianpref/medianouter**。单阶段fraction高不能证明它的子routine是最慢内核，更不能证明CPUtime精度。

## Mozilla/source描述性阶段及真实赢家

| 输入 | outer median ms | preferred-context exclusive median ms | perround preferred fraction median | wire exclusive median ms | optimal-parse median ms |
|---|---:|---:|---:|---:|---:|
| Mozilla | 100.994323 | 69.791928 | 0.6916768305 | 18.290616 | 7.685198 |
| source | 37.488358 | 7.257834 | 0.1929986637 | 13.714862 | 11.044058 |

这些独立stage medians只描述各个分布，不相加推导outer或剩余时间；分解恒等只按raw每round检验。

Mozilla五轮赢家一致：event26、originlazy、wire14216bytes，ancestor包含distance_parameters；每round10lazy+8optimal共18wire。最小optimalwire16269bytes，所以optimal不是该输入最终赢家。返回wire来自lazy距离参数搜索替代，不因为preferred阶段总耗时高就将赢家误标contextcandidate。

source五轮赢家一致：event37、originoptimal、wire11687bytes、config.context_trees10，ancestor包含preferred_context；每round也是10lazy+8optimal共18wire。它确为该输入的optimal/context候选，但不能把这一个结论推广为所有q8input总是optimal胜出。

origin标识是原parser来源，不是另一条不同qualitypolicy。contextmode/treecount、distance参数、splitbits从实际传入typedoptions记录，不需要重新parsewire；标签是候选配置，不代表所有writer内部优化必然触发。另一个readonlycontext任务负责继续拆解preferredcontext，当前profile不能给未拆分子步骤的因果耗时结论。

## Ordinary public旧新对照与reference范围

读取baseline14/public14 samples，按inputSHA匹配14row，独立从每row5个rawvortns/reference_ns求median。old/new整个settings与wires对象相同；profile工具返回wirebytes/hash也与ordinaryold/new对应一致，输入实读sha验证。

重算ordinaryversionGM=`1.0105773490772076`，12个old/newratio>1、2个<1；这只是infrastructure前后oneprocessversion点差，没有做codec性能优化或assignedsignificance。new/reference GM=`0.028255696697149443`，吞吐胜0/14。

运行条件ReleaseFast/Zig0.16.0/x86_64/skylake+pku+sgx，i7-10700K，单线程、affinityCPU8，14个固定64KiB文件前缀。Vort接口one_shot_quality_preset/quality8/generic/defaultwindow16，referencequality8/mode0/lgwin22；此对照并非window等参数完全对称配置，不能扩大为全平台稳定排名。

references为本地libbrotli1.2.0 enc/dec/common，filehash：encoder20155a6e...、decoder0f88c6ef...、common18f909e3...，old/new记录相同，newafterreferences_stable。样本loaded_identity=null/dependencies_verified=false，所验证是请求文件及其固定身份，不宣称实际动态依赖全部验证。公开samplegate两侧各exit0、14rows/70round输入与explicitrequestedreferences检查通过。

## 契约、工具alias与完成验证

最终linkednativeDebug、nativeReleaseFast、x86ReleaseFast各25/25/source_stable，通过完整wire/error、fixedeventlimit截断、positive同cap/profile exactpeak/peak−1、失败allocatorcleanup和返回wireownership合同。new入口显式Errorunioncasts只是类型修正，不改错误类型或把资源拒绝变storedfallback；ordinaryRecorder(false)空type无clock和全局profilestate。

完整Brotlifamily：1420/1421 tests passed，1skipped，exit0/source_stable。最终final-check：173/173 steps succeeded，exit0/source_stable，sourcehash仍同冻结核心。不能把1skip改写成1421全部运行通过。

工具outputalias执行记录已从 `/tmp/vort-brotli-q8-profile-20261025/tool-file-smoke.json`只读取得（与父docs归档一致）：五case包括same/spelling/symlink/hardlink均拒绝且inputpreserved，separate_output通过并inputpreserved；exeSHA与上述最终profiletool相同。Pythonquality_profile_gate_smoke实际result.json为exit0/source_stable，run.log记录“Ran 6 tests...OK”；本审计已读取该执行证据，没有重跑。actualprofile14 gate70runs也已独立读取和方程核算。

工具source aliaspreflight保原文件读写合同，gate只独立核input/exe、eventtopology/math；producerwireequal/roundtripassert是输出正确性证据的一部分，不能把gate读到bool等价成它自行编码解码。

## 最终建议范围

本milestone完成真实q8计时plumbing和可靠限定证据，不改变算法/level/quality，不取舍输出ratio、安全或预算。在完整profile与ordinarywire验证基础上，下一步可优先细分Mozilla等input的preferred-context阶段；需要直接观察真实内部调用，不凭高stagefraction或候选赢家倒推因果。未来优化仍应独立验证收益，不能把本次ordinaryGM1.01058误写为这个diagnostic功能的性能承诺。

## 复核产物hash

- `analysis.json`: `53af1d9ba806facebae5e7ce7382340934c61a9e8b8ab2457cb21ca6b31ae4c1`
- `profile14/samples.json`: `63c44448359f0245e7c9ee167cfc335d53fb7c8cabfd59b770624c937c6bdb38`
- `profile14/result.json`: `fac6d74744aa89a36816126d7d06d2257cace20a0231f76840a315005a01ed42`
- `profile14/gate-result.json`: `e87bb6150be38bdef9b349f2d7ebde90f1c73babaca9570f8056b5c88f1a07a4`
- `baseline14/samples.json`: `e4330b294400b2adc0a8e65cb89feb520e9200a81bc75e77a03f8a377965852d`
- `baseline14/result.json`: `2f41863ae30139c4022c83f20363a1bc7bf5277fdba3e346c97abfed2d93f157`
- `public14/samples.json`: `7135164f377bbb1b9aaac7507ac1ed0068e6fe6e5a4cdcf7371b1d565275b742`
- `public14/result.json`: `a886147bd9ce609a7cbadc1eeb4b8b192df78712e91b9ece5b0d6d844a7f2791`
- `public14/gate-result.json`: `5594597ed7c54c1d2f29f7ddc028c71bc3b0c11926f7a48d73af093402cce012`
- `complete-family/result.json`: `15660b6882c3ccbdba15c18908e660ca2334e2d200926916c81ab885c2c707c2`
- `final-check/result.json`: `125cee39ce70b125eb87eb408647b3b92eff4537c532e02b09086fbb0f49f7eb`


补充身份范围：2026-10-25 17:04:29 Asia/Shanghai，五casealias与六Pythongate实际结果已读，Brtools补充manifest逐文件hash相符。未来复验可在执行前记录src+alltools完整manifest并在后比较；它不会追溯消除本次旧snapshot遗漏tools/br的范围短板，不需要据此重跑既有timing。本报告不提供伪造的计时前source身份。

- `br-tool-source-bindings.json`: `594b24523fbc93650817ddfcea3d44d80c532a4c908c81d1fae5f68a7c7273f2`
- `tool-file-smoke.json`: `905fe1cd985fee14b199310b913cacdfb5aeaf69e46c164586a08a6f630a826f`
- `python-gates/result.json`: `6fa7fe9182d1748eb3ba7d56ba9b0cc446f189cb0cc0317ad9787a24d3bc5a54`
