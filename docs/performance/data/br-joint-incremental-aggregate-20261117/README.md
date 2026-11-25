# Brotli joint-context incremental tree aggregation (2026-11-17)

## 结论

`literal_joint_context_split` 的聚类迭代每轮都对全部上下文重新聚合树：
387–480 个非空上下文 × 256 个计数，加上每个树的首次贡献整块 1 KiB 复制和
空树清零。实际上每轮只有一部分上下文改变所属树（首轮约 50%，后续
20–30% / 10–25%）。

现在分配循环记录 `(context, from, to)` 移动，只对变化的上下文做
“从旧树减去、向新树加上”的增量更新；`literal_count > u32` 的极端路径
保留原来的受检全量合并。计数是互不相交上下文的精确和，因此增量结果与
全量重聚逐位一致。

128 KiB q11/q10 中位数（baseline 为 omit-flat 提交 `ac683422`）：

| case | baseline ns | incremental ns | 速度 | wire |
| --- | ---: | ---: | ---: | ---: |
| samba q10 | 223,365,356 | 215,563,754 | **1.0362x** | 45,325 B 不变 |
| samba q11 | 1,339,859,837 | 1,296,697,891 | **1.0333x** | 40,937 B 不变 |
| dickens q10 | 154,885,518 | 152,618,002 | 1.0149x | 48,747 B 不变 |
| webster q11 | 833,311,880 | 826,557,337 | 1.0082x | 36,107 B 不变 |
| xml q11 | 698,897,135 | 693,797,174 | 1.0074x | 8,401 B 不变 |
| dickens q11 | 896,341,451 | 894,147,475 | 1.0025x | 43,953 B 不变 |

六行几何平均 **1.0169x**。低于默认 3% 合并门槛，但这是一个精确的
重复工作消除：所有行非回归、samba 弱行 3.3–3.6%、无 wire/比率变化。

## 为什么安全

- 上下文是互不相交的划分，`literal_count <= u32` 路径中每个树的计数就是
  其上下文的精确和；对移动的上下文做减/加与全量重聚在整数加法上等价。
- 空树不变式：减到 `total == 0` 时所有计数恰为 0，与全量路径的
  `Histogram.init()` 一致；之后收到上下文时从零相加也一致。
- 移动记录只在 `previous != best_tree` 时生成；同一轮内多个移动的加减
  可交换，最终计数与顺序无关。
- 若某轮没有变化，直接退出，不再做一次语义上空转的全量重聚。
- `literal_count > maxInt(u32)` 保留原来的 `addHistogram` 受检路径。
- 新增测试 `joint kernels incremental moves match full re-aggregation`：
  随机 16 上下文 × 4 树，比较增量结果与全量 `aggregateTrees` 的完整
  `Histogram` 深度相等。
- 6 个 Silesia 语料 × q10/q11 共 12 个用例的 wire sha256 与改动前相同。

## 测试

- `zig build test-br -Dbr-test-filter="joint"`：46/46 pass。
- `zig build test`：5663 pass，2 skip（5665 total）。
- `zig build test-br`：1623 pass，1 skip（1624 total）。
- `zig build check check-wasm`：392/392 steps，7379/7382 tests（3 skipped）。

## 证据

- 计时来自 `run-br-planned-encode-bench` 的 `vort_ns`（2 iterations），
  每个配置 2–3 次运行取中位数；
- wire 身份来自 `--samples-json` 的 `vort_sha256`。

## 环境与命令

- CPU：Intel Core i7-10700K @ 3.80 GHz（`skylake+pku+sgx`）
- Zig 0.16.0，ReleaseFast，单线程

```sh
zig build run-br-planned-encode-bench -- \
  --path <silesia-file> --limit 131072 \
  --planned-quality 11 --quality 11 --iterations 2
```
