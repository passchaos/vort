# Zstd level semantics aligned with zstd (2026-11-18)

## 结论

公开 Zstd level 语义按用户要求对齐行业 zstd 阶梯：

- 默认级别从 1 改为 **3**（与 zstd 默认一致）；
- level 1：legacy `fast_compressed` 单帧（最快）；
- level 2：controlled `fast` + acceleration 2；
- level 3：controlled `double_fast`；
- levels 4–22：保留既有质量阶梯（本轮未改）。

1–3 级不再进入 adaptive split ladder，也不再使用每级候选预算；受控策略使用
`legacy_search_budget` 与 acceleration，且关闭 rep beam。显式 strategy /
acceleration / HQ / encode controls 仍然优先。

## 位置（128 KiB，`--iterations 3 --rounds 3`，libzstd 1.4.8）

| case | L1 bytes | L1 MiB/s | L2 bytes | L2 MiB/s | L3 bytes | L3 MiB/s |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| dickens | 63,414 | 76.6 | 55,783 | 32.1 | 54,086 | 29.8 |
| mozilla | 25,151 | 160.4 | 21,341 | 95.2 | 20,930 | 81.5 |
| xml | 12,556 | 223.7 | 12,503 | 139.6 | 11,784 | 129.2 |
| samba | 55,670 | 100.0 | 52,255 | 46.2 | 50,001 | 42.5 |
| nci | 11,608 | 198.7 | 11,321 | 100.5 | 11,479 | 99.5 |

对 libzstd 同级别的大小比：L1 1.011–1.152，L2 0.970–1.032，L3 0.981–1.041。
速度比约 2.6–6.9x 慢（此前旧 level 3 是 32–399x 慢，且 mozilla 更大）。

nci 上 L2 比 L3 小 158 字节（1.4%），是 `fast` 与 `double_fast` 在该语料上的
已知非单调点；其余语料 L3 均优于 L2。

## 为什么安全

- 受控策略路径已有 `ControlledFrameEncoder`、完整 wire 校验、独立解码器
  round-trip 和既有测试覆盖；本轮只改变公开级别的解析器选择。
- `applySpeedFirstLevelPolicy` 对显式 strategy/acceleration/HQ/controls 直接
  放行，不覆盖调用方选择。
- 1–3 级在 one-shot、append、into-slice、bound、reusable 各表面使用同一
  policy；`LevelFrameEncoder` 的复用路径同步修正为 1–3 级统一应用。
- golden wire 已按新语义重新冻结：controls helper 的 L1/L2/L3 三条、
  HQ legacy 84 条、large-history default、encode gate 的 L3 尺寸/时间断言、
  root 默认级别断言。

## 验证

- `zig build test-zstd`：1430/1430 pass。
- `zig build run-zstd-encode-bench-gate`：ok（20 rows）。
- `zig build test`：5663 pass，2 skip（5665 total）。
- `zig build check check-wasm`：389/389 steps，5756/5758 tests（2 skipped）。

## 环境与命令

- CPU：Intel Core i7-10700K @ 3.80 GHz（`skylake+pku+sgx`）
- Zig 0.16.0，ReleaseFast，单线程
- libzstd 1.4.8（系统 `libzstd.so.1`）

```sh
zig build run-zstd-encode-bench -- \
  --path <silesia-file> --limit 131072 --level <1|2|3> \
  --iterations 3 --rounds 3 --csv <out.csv>
```

## 全语料单调性核验（12 文件，`--iterations 2 --rounds 2`）

| case | L1 | L2 | L3 | ref L3 | L2≤L1 | L3≤L2 |
| --- | ---: | ---: | ---: | ---: | :---: | :---: |
| dickens | 63,414 | 55,783 | 54,086 | 51,934 | yes | yes |
| mozilla | 25,151 | 21,341 | 20,930 | 21,338 | yes | yes |
| mr | 37,918 | 34,382 | 36,669 | 33,978 | yes | **NO** |
| nci | 11,608 | 11,321 | 11,479 | 11,264 | yes | **NO** |
| ooffice | 77,758 | 74,579 | 70,671 | 72,249 | yes | yes |
| osdb | 78,042 | 53,414 | 51,127 | 50,414 | yes | yes |
| reymont | 47,564 | 43,217 | 41,523 | 40,509 | yes | yes |
| samba | 55,670 | 52,255 | 50,001 | 50,611 | yes | yes |
| sao | 115,365 | 101,650 | 100,317 | 105,695 | yes | yes |
| webster | 51,345 | 47,465 | 45,790 | 44,728 | yes | yes |
| xml | 12,556 | 12,503 | 11,784 | 11,921 | yes | yes |
| x-ray | 107,219 | 102,637 | 102,323 | 103,219 | yes | yes |

L2 在所有文件上都优于 L1；L3 在 10/12 上优于 L2，mr（+6.7%）与 nci（+1.4%）
是 `double_fast` 相对 `fast` 的已知非单调点。L3 对 libzstd L3 在 8/12 上
更小，dickens/mr/nci/webster 略大。

若要严格单调，可把 L3 换成 `greedy`（dickens 51,971 B），或让 L3 在
`fast` 与 `double_fast` 之间做一次完整 wire 仲裁（保证 L3 ≤ L2，代价约 2x）。
本轮保留 `double_fast` 以维持与 zstd 默认级别接近的速度点。
