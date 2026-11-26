# Zstd controlled workspace 冷 public L3 资源拒绝

**REJECTED，原型未合入。** 只运行首行 `nci-64k` 的冷 public allocating L3 完整操作。Requested heap peak 从 **1468774 B** 升至 **1912513 B**，增加 **443739 B / 30.2115%**，超过事先固定的 **5%** 上限。立即按首失败停止规则结束筛选，没有放宽门槛。

| 已观察指标 | Baseline | Candidate |
| --- | ---: | ---: |
| Requested heap peak | 1468774 B | 1912513 B |
| 累计 allocated / freed | 1964957 B | 1964957 B |
| Allocation attempts / successes | 45 / 45 | 45 / 45 |
| Forced growth refusals | 8 | 8 |
| Caller free 后 live / active allocations | 0 / 0 | 0 / 0 |

两次编码进程均实际 exit0，完整 wire 逐字节相同，ownership errors0。首行的分配次数和累计分配相同，保留 workspace 延长了数组生命周期。`block_head` 的 32768 个 u32 增加 **131072 B** 与 entropy/wire 的重叠；首个无前缀 64KiB 块四数组合计保留 **524288 B**。这是源码支持的生命周期核算，完整操作峰值来自实际分配器观察，未独立测量各阶段峰值。

Baseline 从 git HEAD `92204434b194bd4e87cf6349cbd6bfaac64ea5da` 的完整 src 闭包冻结。Candidate 在 `SOURCE_READY` 后复制同一闭包，只覆盖约定的 5 个新/改文件。两代使用相同的原 public probe 和强制移动增长 requested allocator，plain 模式直接调用默认公共 level3 allocating API。无 memory profile/cap/strategy/control override，未引入 case 条件优化。两代均 Zig0.16.0、ReleaseFast、x86_64-linux-gnu、skylake+pku+sgx、CPU9。

原 6 项顺序、每个 input/dictionary identity、API、资源范围和首失败停止规则均完整保留在 [protocol.json](protocol.json)。剩余 `nci-1m`、`nci-full`、`mozilla-1m`、`random-1m` 和原 raw dictionary case **未运行**。本结果不推断 warmed workspace、multiblock 行、其他 5 行、吞吐或 RSS；没有配额/OOM sweep 或计时。

Copernicus 窄 gate 的原首轮失败和最终成功都保留：首轮 native **6/7、exit1**，含原 source、完整 stderr 和泄漏报告；最终修改后的 native **7/7、exit0**，actual wasm32-wasi ReleaseSafe 经 Node WASI `_start` **7/7、exit0**。最终两个 workspace 文件与资源 candidate 的对应文件 SHA256 相同。窄 gate 通过并不消除完整操作 requested heap 拒绝。

归档包含：

- `archives/baseline-source.tar.xz` 与 `candidate-source.tar.xz`：完整冻结 src，分别 2217 / 2219 个文件。
- `prototype-five-files.patch`：只由两份冻结源码生成的精确 5 文件 diff。
- `archives/resource-evidence.tar.xz`：原 epoch 的所有非 cache 证据，包括 helper、两代 ELF、编译与两次运行 argv/stdout/stderr/actual exit、完整 wire、6 个原 fixtures/字典、summary/screen、源码和 helper 前后 identities。
- `archives/copernicus-gate.tar.xz`：原 gate 的 SOURCE / SOURCE-final、成功和 6/7 失败全部 logs/command/actual exits、WASM 与 runner。
- 顶层 summary/screen/source verification/overlap 是原文件的逐字节副本，历史 `/tmp` 路径保留为 provenance，不是验证依赖。

[inventory.json](inventory.json) 记录所有 archive 与成员的 bytes/SHA256、顶层文件身份和原输入路径。[verify.py](verify.py) 仅使用 Python 标准库做数据校验：不运行 Zig、Node、codec、tests、build 或 timing；不依赖工作树、旧 `/tmp` 或网络。运行 `python3 verify.py --root /path/to/package` 可验证独立移植副本。封存状态和独立副本验证的实际 exit/日志见 `sealed.json` 与 `verification-copy.*`。

保留原始失败数据，不修改原 epoch、Root ledger、生产或既有文档。本包只记录拒绝的原型，未 commit/push。

Root 已将五文件原型保存为 stash `7e6d6b8bd3114162199dc0dfb5bc2be00d10dc5e`，并恢复生产到 `92204434b194bd4e87cf6349cbd6bfaac64ea5da`；收尾读验证 `git diff HEAD -- src` 为空。新 records test 在资源提前拒绝后取消，未生成文件，未运行 full codec gates。归档源码以冻结 epoch 为权威，stash/恢复信息见 `root-recovery.json`。
