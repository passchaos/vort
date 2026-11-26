# Shared literal model 证据包 — 2026-11-26

此包封存已经完成的性能矩阵、focused 功能/资源验证和所有原失败。
**Root full-library gate 最终 actual exit0：414/414 steps succeeded，
6068/6070 tests passed（2 skipped）**，完成于2026-11-26T16:25:19.713244Z。
冻结源码、功能与声明的性能硬门通过，`mergeAllowed=true`。精确 Zstd
source-reverse rerun84/84独立保存；整体通过依据 whole gate 的真实终态。

| 已完成矩阵 | 完整原始范围 | 独立结果 |
| --- | --- | --- |
| Full primary | 90 pairs / 180 processes / 180 timed calls | speedup GM **1.0320069538939025**，95% CI **[1.0286014769465641, 1.0354237056386224]**；12行点估计floor通过 |
| q4 / q11 / ratio controls | 18 pairs / 36 processes / 1,224 timed calls | 三项点估计floor通过；q11显式command-state cap8 KiB |
| 4 KiB q8 controls | 72 pairs / 144 processes / 14,400 timed calls | 12行点估计floor通过；NCI **0.9853882704418276**，95% CI **[0.9785405194196362, 0.9963229246292287]** |

**小输入 NCI 的 CI 下端低于0.98**，不能称其置信下端通过floor。原声明
门槛是每行点估计，不能用总体均值掩盖该范围。Full使用共享的六个主轮
round blocks和20,000次确定性bootstrap；三条弱行的额外六轮不增加矩阵
权重。controls/small均使用每进程全部调用的算术平均、六对AB/BA和原
order-stratified20,000 draws，全部原样保留。

Pilot的24 pairs / 48 calls独立保存，不混入full。Mozilla两对原speedup
**1.2669249970692857 / 1.0026711751245123** 的差异完整保留，没有滤样或
成功样本重试。Full sampling由Root的FULL_APPROVED允许，属于采样许可，
不是采用许可。所有actual stdout/stderr/exit与原独立复核代码/收据保存。

CF基线为 `cf442dee0144f4c0cc1823474f77c7e8b1685f2e`；候选源码2218的
权威manifest SHA为
`a3cc7ac8e424db04added9be220465f3428adc563b57f4b1de474a3ca6577153`。
只读取6km4y0gx/SOURCE与p9冻结编译闭包，不采live Root。GNU ReleaseFast /
`skylake+pku+sgx`、i7-10700K、CPU2/single；公共allocating encode、length
mix与free连续计时，每进程一次warm encode/free在计时外。完整wire/decode
只验证计时外initial wire；计时输出按length/mix核对，不是假定全部timed
wire都有完整SHA。54份fresh preflight wire、原输入、pinned libbrotli1.2.0
decoder、6个ELF、own objects、harness/protocol与编译回执全部保存。

一条combined precheck误从build-preflight artifact查protocol键而KeyError，
**之后已授权的public采样仍启动**。原错误、先后事实和原note保存，不把它
改成成功precheck。正确protocol/source/ELF/script哈希在public终态后、small
计时前和原独立审计中通过；没有改protocol、参数、source或重跑controls。

Focused验证保存以下真实范围：

- Owner final Native/WASI15，smoke Native25。
- 修正后的writer Native/WASI25：162 wire/model oracles，126 fresh-frame
  decodes，36 seeded-history oracles。实际combined stderr中的
  `uncached_first_difference=0 cached_first_difference=0 decoded_equal=true`
  原样保留，没有虚构额外诊断文件。
- Public4gold/Scope的named case在原Native/WASI **37 pass / 1 fail**
  campaign中OK。**原37/38整体失败未改称通过**；当时writer history oracle
  解码初始化错误的源前后、真实output和失败contracts.wasm保存。
- Native/WASI resource35：Mozilla625/658 allocation-ordinal OOM及同数量
  重试均完成，peak不增加；**allocation次数与累计bytes增加**。Mozilla/Xray
  正model hits24/28保存，exact-D、D−1拒绝、retry和live0/freed一致性均保留。

最初fmt:semicolon与两处Native comptime失败、pilot verifier第一次reader
失败以及history oracle初始化修正均保存原源/输出/wasm/退出，不重造结果。
Owner旧14/final15的真实gate日志独立保留；当时source是live symlink，未
跟随它。旧14的owner/tests从冻结15源码仅撤HQ新增块反向恢复，model原样
复制，三项SHA匹配原910c/4f47/ac15，明确标为 **reverse-recovered**。
旧14当时完整src树快照没有留存，不能称其完整历史树已捕获。

包内 `sources.tar.gz` 保存CF/candidate冻结闭包与Root SOURCE映射；
`performance.tar.gz` 保存全部pilot/full/controls/small/raw/54preflight及
receipt；`validation.tar.gz` 保存finished功能/资源验证、失败与恢复源码。
编译cache和旧worker live source link排除，已完成精确Zstd rerun4files及
SHA绑定wasm保存。Root37380已终态，其完整command/stdout/stderr/exit及
final-gate capsule保存。原`failed command` NodeZstd/vort-tests提示原样
保留，属于诊断行，不能由它推断实际subprocess非0；最终actual0与414/414
allstep success更正此前该解读。95261 rerun仍不替代整体终态。

最终portable数据验证：

```sh
python3 -B docs/performance/br/shared-literal-model-20261126/verify.py
```

验证器只读取当前包，在内存中读tar；独立重算各矩阵、所有样本均值/CI，
检查参数/source/wire/实际exit与失败范围，不import producer或执行
codec/foreign/compiler/timing。它输出 `verified_completed_scope` 与依据
冻结声明硬门计算的 `mergeAllowed=true`。旧pending status和
`completed-scope-verification.json`保留为当时的历史checkpoint；最终
状态以final-gate capsule、gate-status及最终复核收据为准。本包不声称
行业best，也不声称历史3x回退已经修复。
