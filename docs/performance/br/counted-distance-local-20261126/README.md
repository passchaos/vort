# Local counted adaptive distance：standalone pilot 拒绝 — 2026-11-26

此包封存 CF 基线与 standalone local exact-count rejection 候选的完整
pilot。**目标 speedup GM 为 1.0138217623027224，低于 1.03；所有行的
0.98 下限通过，standalone 仍被拒绝。** 这里只有每行一对 AB 和一对 BA，
**CI 为 `null`，full 未批准、未启动**。该结果不证明历史回退已恢复，也
不与下一 global-bound 源码 epoch 合并。

| 证据 | 已保存范围 |
| --- | --- |
| Pilot | 12 个 64 KiB 输入 × 2 对 = 24 pairs / 48 计时进程，全部实际 exit0 |
| 原独立验证 | 实际 exit0，48 个 process checks、192 个 raw sidecar SHA；独立 GM 与 producer 一致 |
| 完整初始 wire | 24 份 CF/candidate wire，逐字节等于 CF/C2 gold，原 pinned libbrotli 1.2.0 解码收据通过 |
| Native | 原 combined tool-result JSON：实际 exit0、29/29 tests、6 对真实等长不同 wire tie |
| 实际 WASI | 29/29 tests、6 对 tie，实际 exit0；编译 wasm、record object、运行输出与模块 SHA 均保存 |

`old_exact` 是保留的内部标签，实际指 clean CF
`cf442dee0144f4c0cc1823474f77c7e8b1685f2e`。`current` 指冻结候选
`cf-counted-adaptive:b7aa98bbc0ec967119d1371308120acce842e7e495e86e8ab92fa2ae0afa1ab8`。
它们保留原公共 allocating probe/harness，q8 / generic / explicit window16，
Zig 0.16.0、ReleaseFast、GNU x86-64、`skylake+pku+sgx`，i7-10700K，
单 codec 线程固定 CPU2。每进程一次 encode/free warmup 在计时外；
连续计时包含 allocating public encode、length mix 和 free。完整 SHA 与
外部解码只验证计时外初始 wire；计时输出只验证长度/mix。

Root 的 `HEAVY0` 和 `pilot-host-before.json` 与实际采样回执保存。
Host 是采样前 snapshot，不是连续零干扰证据。所有样本与实际退出保留，
未删离群值、重试成功样本或追加旧 phase。原 benchmark README/epoch
里的 preparation-only、尚未计时等文字原样保留，属于早期阶段；完成
状态以 `pilot/run-manifest.json`、`pilot-exit.json` 和独立验证回执为准。

源码只从冻结 bench `sources/current` 和原 snapshots 收集：CF partial
tar 保留 **2,992 个编译输入 / 2,200 个 src 文件**；候选闭包完整保留
**3,120 个文件 / 2,204 个 src 文件 / 125 个 pyc**。其中一个 pyc 属于
已注册 src 身份，所有生成字节码均按原字节保存，仅作为数据。没有
读取后续 live Root source；header/context/cache 源码与 CF 完全相同，
global-bound 新模块不在此闭包。

历史 native 编译的两处 `Api.Error` 歧义与新 test 的 `u2 + 1` 崩溃
原样保留在 `state.json`，原 chunk 索引为 `e9d8cb` 与 `9bda3c`。
before-count-widen test 和 before-reference module/unit source backups
同时保留。现有资料没有完整失败 tool-result 的独立字节，`failure-index.json`
明确标记为 index-only，没有伪造 stdout/stderr。最终 Native29/tie6 的
真实 combined 原结果单独保存；没有把其输出重新拆分为独立 streams。
Module unit5 的来源仍是 SOURCEFREEZE 中原 worker chunk 索引，未重跑。

包内三个归档：

- `sources.tar.gz`：原 CF partial tar、完整冻结候选闭包、pyc 与全文件
  身份清单。CF extracted tree 用原 tar 逐字节核对，不重复存储。
- `bench.tar.gz`：所有 raw/policy/runner/独立统计代码与回执、pilot 48 个
  JSON 和全部 sidecars、初始 wire/gold/input、refs、ELF/object/build、
  SOURCEFREEZE、HEAVY0、startup/freeze-arrival 回执；full 不存在的清单。
- `validation.tar.gz`：原 Native tool-result、实际 WASI/output/wasm/object、
  frozen src manifest/state、现有失败源码与原 chunk 索引。编译 cache 排除。

离线验证：

```sh
python3 -B docs/performance/br/counted-distance-local-20261126/verify.py
```

也可复制整个目录后运行 `python3 -B /copy/path/verify.py`。验证器只读
包内字节，在内存中读取 tar，独立重算 24 个 baseline/candidate 耗时
比值与每行 GM，核对 pilot 门槛、原独立收据、参数/时序/生命周期、
源码/pyc/ELF/object、完整初始 wire 和原 Native/WASI 收据。不执行
producer、codec、参考程序/SO、编译、测试或计时。

该 standalone pilot 的点估计不足以通过 ROI 筛选。正式 CI、完整
90-pair matrix、controls、resource 和 full-source adoption gates
没有由本包完成或批准。
