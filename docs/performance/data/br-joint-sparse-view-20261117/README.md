# Brotli joint-context sparse-view reuse (2026-11-17)

## 结论

q10/q11 的 ratio pipeline 对每个候选组运行 `literal_joint_context_split.chooseAlloc`：
它按 15 种树数量 × 2 个种子 × 最多 3 轮迭代对每个 `(block_type, context)`
直方图做树分配。旧实现每轮、每个候选都在 `chooseGrouped` 内重新扫描 256 个
计数构建 sparse 视图（`symbols[256] + frequencies[256]`，约 1.3 KiB 写入），
单个 planner 调用内重复约 3.5 万次。

现在在收集阶段之后按上下文构建一次 `SparseView`，所有树数量/种子/迭代复用；
频率直接从直方图读取。分配结果逐位不变，wire 完全一致。

128 KiB q11/q10 三轮中位数（ReleaseFast，单线程）：

| case | baseline ns | sparse-view ns | 速度 | wire |
| --- | ---: | ---: | ---: | ---: |
| dickens q11 | 1,206,015,198 | 1,017,334,905 | **1.185x** | 43,953 B 不变 |
| samba q11 | 1,663,390,490 | 1,382,950,491 | **1.203x** | 40,937 B 不变 |
| dickens q10 | 192,597,989 | 154,915,464 | **1.243x** | 48,747 B 不变 |
| dickens q9 | 103,390,411 | 103,713,252 | 1.003x（噪声） | 48,833 B 不变 |

q10/q11 三行几何平均 **1.210x**。

## 为什么安全

- `sparseView` 只是把 `counts[symbol] != 0` 的符号按升序收集一次；
  `chooseGroupedView` 用 `context.counts[symbol]` 取频率，与旧
  `Sparse.frequencies` 完全一致。
- 累加顺序、4 路向量化与标量尾部都保持原实现，逐位结果相同。
- 新增测试 `sparse view assignment matches the histogram scan` 对
  2/3/4/7/8 棵树比较两条路径的 `Choice`。
- 6 个 Silesia 语料 × q10/q11 共 12 个用例的完整 wire sha256 与改动前相同
  （dickens/xml/samba/mozilla/nci/webster，128 KiB 前缀）。
- 内存：每个 planner 调用新增 `context_count × @sizeOf(SparseView)` 的
  scratch（8 类型 × 64 上下文时约 132 KiB），已计入
  `scratch_budget_bytes` 预算检查。

## 测试

- `zig build test-br -Dbr-test-filter="joint"`：45/45 pass。
- `zig build test`：5662 pass，2 skip（5664 total）。
- `zig build test-br`：1622 pass，1 skip（1623 total）。
- `zig build check check-wasm`：392/392 steps，7377/7380 tests（3 skipped）。

## 证据

- 计时来自 `run-br-planned-encode-bench` 的 `vort_ns`（2 iterations），
  每个配置 3 次运行取中位数；
- wire 身份来自 `--samples-json` 的 `vort_sha256`。

## 环境与命令

- CPU：Intel Core i7-10700K @ 3.80 GHz（`skylake+pku+sgx`）
- Zig 0.16.0，ReleaseFast，单线程
- libbrotli 参考版本 1,000,009（1.0.9）

```sh
zig build run-br-planned-encode-bench -- \
  --path <silesia-file> --limit 131072 \
  --planned-quality 11 --quality 11 --iterations 2
```
