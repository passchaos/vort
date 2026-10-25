# Aggregate totals 默认方案拒绝决定复核

- 最终生产工作树：`/home/passchaos/project-z/vort-zstd-aggregate-totals`
- 生产恢复HEAD：`6b26275473146c4b6d602c99b91a9eaabe4b75f3`
- 审计时间：2026-10-25 16:25:08（Asia/Shanghai）
- 操作范围：读取既有raw样本、测试/sizeof结果、归档候选源码与恢复后的Gitblob身份；独立重算median/geomean、deepcompare设置/wire/work。没有编译、执行test/encoder/benchmark、计时或修改Git/源码；仅写此报告。

## 最终决定

**拒绝这次“默认维护256总频率并在prepare读取summary”的具体实现，保留原生产代码。** 候选正确性验证通过，但阶段改善只有约1%且有反向pair，公开14行old/candidate吞吐比GM0.988277（小于1），同时native/x86对象增加1040/1032bytes。没有足够收益依据把默认维护代码加入主线。

该决定不是“aggregate totals永远不可优化”的证明，也不是数值正确性失败；限制到本实现、这台机器、此corpus/level/测量方法。小点差不赋统计显著性，不能把stage结果盖过公开负向结果或推断热点因果。候选代码/QA仅作为可复现的tmp文本归档，不再是活跃codec源码。

## 生产恢复与候选epoch分离

只读确认git rev-parse HEAD为6b262754完整值、git status --short无输出。当前root/cut/cache文件字节SHA与 `git show 6b262754:<path>`完全一致：

- src/zstd.zig：`cc29696a1fca71cf134210a12a197071fc2bad25801f528ad8b7140e29028a59`。
- cut_histogram.zig：`6a9d7e4545f2ee075cfef1c1497b5609987820a9d6401848ca2268865711f9ad`。
- single_cost_cache.zig：`0a81c9834f9dd8006f2cab125fba230533b9eb8ff0f8720b39a70b6e29435f51`。

活动src不含aggregate_totals/aggregate_cost helper，当前cut/cache没有ownedSnapshot/totals新调用。恢复后的runtime使用原先已验证的基线功能，不能把候选QA13pass称为恢复代码包含aggregate；候选未采用，不要求为了“完成”而新增完整candidatefamily/check。基线既有完整通过结果属于之前生产handoff；本审计没有重跑。

6个候选文件保存在rejected-source/<slash-to-doubleunderscore>.txt，重新读每个文件hash，全部等于analysis.json candidate_source_hashes；候选源码不是Gitcommit，只用完整sha绑定：

| 文件 | 候选SHA256 |
|---|---|
| aggregate_totals.zig | 8915a6079f6aa19c6c721a42c4a785a31aaffe87b68360dc9e6c81b0d8aac4a2 |
| cut_histogram.zig | 7c9836675163db4b6982ddcc694eab0748e8a20992a6d17c2cb8047931d432c2 |
| single_cost_cache.zig | 09f9310ef8c41984cae503fa709354346584bdb4b95bd83e49eabfb4dff7e8d1 |
| aggregate_totals_tests.zig | c89f72954acc7db9d8c8b2332d811ce3e11cf37f14c3c4a5c28a64a7dd100582 |
| aggregate_cost_tests.zig | 13c8aee1f5c8ea3f1c482af8f61e173aeb1421094ed94e35eadc1cf79ac96ef4 |
| src/zstd.zig | 68c263e1b467bd5c440705754e67fed40249937e7891adff7dcfc1b1f016e760 |

QA三target、state两个probe、stage和candidate14的source_after全部匹配上述6个sha，source_stable=true，保证候选test和runtime证据属于相同候选epoch；它们与现在已恢复的productionfingerprint分开。

## 候选正确性与对象大小

读取aggregate-debug/releasefast/x86 result：nativeDebug、nativeRF、x86-linux-muslRF均exit0、source_stable、13/13。候选追加两个prepare-level测试已注册，不再沿用早期“未覆盖”状态：

- aggregate_cost_tests中的on/off以及legacy.histogram.totals=.{}，各真实cut的Prepared全部physicaloracle相等、legacyreadyfalse走fourrowfallback；没有通过forgedreadybit证明任意row。
- HeaderFailureCodec两个不同合法views每次只update一次，错误后snapshotfrequency/active与新cut和四rows精确一致，query/referenceaccount一次，不rollback或重试。
- Prepared为拷贝，后续update不改变旧value；invalidcut拒绝前hist/totalsstate保持。原核心QA还涵盖zero crossings、repartition瞬态262144及counteroverflow拒绝。

这支持候选正确性；拒绝原因是速度/资源取舍，不是漏了这些tests。候选test日志可保留，但不需要为已拒绝方案继续fullcandidatefamily/check或默认启用。

实际cache@sizeOf结果：

| target | 基线tracked/untracked | 候选tracked/untracked | 增加 |
|---|---:|---:|---:|
| native x86_64 | 6032 / 5568 | 7072 / 6608 | 1040 B |
| x86-linux-musl | 5980 / 5516 | 7012 / 6548 | 1032 B |

两个stateprobe均exit0/source_stable且绑定候选6hash；native和x86的metadataalignment差异解释+1040/+1032。objectsizeof不等于heap/RSS/全函数stack；此方案默认增加固定state与每byte维护，未证明有性能补偿，恢复后避免此增量。

## 公开14输入：独立raw5round重算

读取baseline14/candidate14 samples，根据输入SHA匹配14条row，分别从5个rawvort_ns求median再old/candidate。每条resultold/candidate_ns与analysis.json一致，所有settings和完整wires对象相同；14/14framesidentity不变，没有靠换level/quality/header赢速度。

重算geomean=`exp(mean(log(old_median/candidate_median)))=0.9882771746188965`。14条中4个ratio>1、10个<1。公开时延点差的正/负均保留，不赋显著性。

| 重点输入 | old median ms | candidate median ms | old/candidate |
|---|---:|---:|---:|
| MR | 494.025445 | 494.484507 | 0.9990716352 |
| XML | 571.959936 | 581.149093 | 0.9841879526 |
| source | 221.186165 | 233.970902 | 0.9453575770 |

这是一process/version、每input5round的公开codec对照，不是3processpair publicstudy。corpus为14个固定64KiB文件前缀、level3自动完整policy、iterations1；仅这个scope的平均结果无帮助。

baseline/candidate两个encoder重新读exe SHA与result相符：

- baseline `d32df6453d43fb7f2c8b64eacb55a271e1d662806eb5577fd3803d1e2bd8ebfa`。
- candidate `61a4e00771d506f691bb844c097479f01388c2cdf2e4544238d3295caaaa9ee7`。

两个result均exit0、source/ref/exe stable、0 compiler-process观察；sample gate各exit0。reference请求本地Zstd1.6.0，fileSHA c76f4c44...；loadeddependencyidentity仍未验证，不扩大竞争库身份保证。执行为ReleaseFast/Zig0.16.0/x86_64/skylake、i7-10700K、单benchmarkthread/CPU8。

## Tracked阶段3processpairs：取舍与counter等价

stage/result与0/1/2-old/new六个rawJSON独立重算。每process三个inputs各一次完整stageevaluation，process顺序old/new、new/old、old/new。它不是每个process5round；三次rawtime求median，不与public5roundmedian混同。

| 输入 | old median ms | candidate median ms | old/new | 三个pair ratios |
|---|---:|---:|---:|---|
| XML | 622.276311 | 616.686610 | 1.0090640869 | 0.961936, 1.015415, 1.012486 |
| MR | 517.028471 | 514.046868 | 1.0058002552 | 1.010401, 0.996044, 1.009600 |
| source | 233.796910 | 231.224513 | 1.0111251051 | 1.046713, 0.998866, 1.011125 |

每input都出现至少一个负向pair，整体约1%的小点差方向不稳。它测trackedcandidate-stage、包含初始化/aggregate更新/全部pricing/emission与统计，不能称counter-freepublicAPI加速。stage_positive不推翻公开GM<1，也不能证明归约是主要热点。

全部18个rawstage rows独立对比：inputbytes/SHA、modeprune、anchorsfalse、available、encodedbytes、wireSHA相同；**排除cache_state_bytes后所有existingWork字段deep-equal**，包括finder_calls/selected_matches、costqueries/huffman/tree/streams、histogram扫描/updates、全部costbound计数/直方图、anchorzerofields。仅trackedobject6032→7072不同，未以删计数或变枚举换时间。测试仍不说明aggregate维护本身没有额外内存写操作，这些并非旧Work计数字段。

两profileexe SHA与rawprovenance/run一致，6run exit0/0compiler，stage source_after匹配候选6file/source_stable。baselineprofile55b24dfe...、candidateprofile65d0c6b1...属于阶段工具身份，不等于公开encoderexe。

## 决定的后续作用

保留候选source/test/rawevidence用于以后设计对照，当前主线保持HEAD6b262754的checked/quality/price实现，避免将没有实测收益补偿的默认state添加进去。未来可以采用其他aggregate策略、减少每byte维护、按输入选择或更紧布局，但每项需重新证明lifecycle/Prepared/Cf绑定、错误顺序与真实速度/资源；本次拒绝不预断它们不可行。

## 复核产物hash

- `analysis.json`: `6885bd80661d6de81d8137ffc9decd57c17c9cd78bb4ca0fbcf51cd43d8c0278`
- `baseline14/samples.json`: `abb65bad9ce1d805019ef6ecd66a7c4c72e805bd3cd9c79e32c94402685c17ef`
- `candidate14/samples.json`: `66d33a7b78f30644a47bd2f226fdbe38e350ad4ad861d5a7a412bd53e859f2d4`
- `stage/result.json`: `a63d686821a7f2f64594592a30677745a0299051f91b2340aaa8a894845f8a5e`
- `aggregate-debug/result.json`: `5498c4c50e88c90afe3a716599aee934a5ddae452ad9303bfebf5bc32608c04c`
- `aggregate-releasefast/result.json`: `ce2c763a123aae2068c9ac4ecf793ab3d600034921e2d16d10b101486e2dca21`
- `aggregate-x86/result.json`: `5fad15a73ce69b446a103958def815405f44cab5457927d0b46bbf44e8d2e66a`
- `state-native/result.json`: `b7191bcb553f3efe74ed8ef21e7f3c9dd1e4307a78b24bf8a76538c783a2bcce`
- `state-x86/result.json`: `8ffca46fec190bf96971839d44c1feaa23d386a4f048571c3a2ae2ea18a72d35`
