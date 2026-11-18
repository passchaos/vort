# Zstd level semantics aligned with zstd (2026-11-18)

## 结论

公开 Zstd level 语义按用户要求对齐行业 zstd 阶梯：

- 默认级别从 1 改为 **3**（与 zstd 默认一致）；
- level 1：legacy `fast_compressed` 单帧（最快）；
- level 2：controlled `fast` + acceleration 2；
- level 3：controlled `greedy`（保留 level 3 候选预算，关闭 rep beam）；
- levels 4–22：保留既有质量阶梯（本轮未改）。

1–3 级不再进入 adaptive split ladder，也不再使用每级候选预算之外的仲裁；
受控策略使用 `legacy_search_budget` 与 acceleration，且关闭 rep beam。显式
strategy / acceleration / HQ / encode controls 仍然优先。

level 3 选择 `greedy` 而不是 `double_fast`：`double_fast` 在 mr（+6.7%）与
nci（+1.4%）上比 level 2 更大，破坏“级别越高压缩率越好”的语义；`greedy`
在 12 个语料上严格优于 level 2 与 `double_fast`，代价是速度低于
`double_fast`（见下）。

## 位置（128 KiB，`--iterations 3 --rounds 3`，libzstd 1.4.8）

| case | L1 bytes | L1 MiB/s | L2 bytes | L2 MiB/s | L3 bytes | L3 MiB/s |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| dickens | 63,414 | 76.6 | 55,783 | 32.1 | 51,971 | 10.6 |
| mozilla | 25,151 | 160.4 | 21,341 | 95.2 | 20,112 | 34.8 |
| xml | 12,556 | 223.7 | 12,503 | 139.6 | 10,748 | 50.9 |
| samba | 55,670 | 100.0 | 52,255 | 46.2 | 48,697 | 17.9 |
| nci | 11,608 | 198.7 | 11,321 | 100.5 | 11,033 | 40.4 |

对 libzstd 同级别的大小比：L1 1.011–1.152，L2 0.970–1.032，L3 0.902–1.001。
速度比约 L1 3.6–4.7x、L2 6.7–9.6x、L3 12.0–20.5x 慢；旧 level 3 是
32–399x 慢（2.2–9.1 MiB/s，0.81–1.07x size）。L3 相对 `double_fast`
（29.8–129 MiB/s）约慢 2.3–2.8x，换来严格单调的压缩率阶梯。

## 全语料单调性核验（12 文件，`--iterations 2 --rounds 2`）

| case | L1 | L2 | L3 | ref L3 | L2≤L1 | L3≤L2 | L3/ref |
| --- | ---: | ---: | ---: | ---: | :---: | :---: | ---: |
| dickens | 63,414 | 55,783 | 51,971 | 51,934 | yes | yes | 1.0007 |
| mozilla | 25,151 | 21,341 | 20,112 | 21,338 | yes | yes | 0.9425 |
| mr | 37,918 | 34,382 | 32,663 | 33,978 | yes | yes | 0.9613 |
| nci | 11,608 | 11,321 | 11,033 | 11,264 | yes | yes | 0.9795 |
| ooffice | 77,758 | 74,579 | 68,503 | 72,249 | yes | yes | 0.9482 |
| osdb | 78,042 | 53,414 | 51,095 | 50,414 | yes | yes | 1.0135 |
| reymont | 47,564 | 43,217 | 39,168 | 40,509 | yes | yes | 0.9669 |
| samba | 55,670 | 52,255 | 48,697 | 50,611 | yes | yes | 0.9622 |
| sao | 115,365 | 101,650 | 99,490 | 105,695 | yes | yes | 0.9413 |
| webster | 51,345 | 47,465 | 43,073 | 44,728 | yes | yes | 0.9630 |
| xml | 12,556 | 12,503 | 10,748 | 11,921 | yes | yes | 0.9016 |
| x-ray | 107,219 | 102,637 | 93,086 | 103,219 | yes | yes | 0.9018 |

L2 在所有文件上都优于 L1，L3 在所有文件上都优于 L2（12/12 严格单调）。
L3 对 libzstd L3 在 10/12 上更小，dickens 大 0.07%（37 字节），osdb 大
1.35%（681 字节）。L3 速度 10.2–50.8 MiB/s。

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
- `zig build -j2 test check check-wasm --summary all`：见下节“全门结果”。

## 全门结果

- `zig build -j2 test check check-wasm --summary all`：389/389 steps 成功，
  5756/5758 tests 通过（2 skipped）；`test` 步骤 5663 pass / 2 skip。
- 首次运行中 `check-zstd-source-reverse` 的 node WASI 门出现过一次偶发非零
  退出；对同一 wasm 产物单独重跑 43/43 通过，最终构建 389/389 成功。

## 环境与命令

- CPU：Intel Core i7-10700K @ 3.80 GHz（`skylake+pku+sgx`）
- Zig 0.16.0，ReleaseFast，单线程
- libzstd 1.4.8（系统 `libzstd.so.1`）

```sh
zig build run-zstd-encode-bench -- \
  --path <silesia-file> --limit 131072 --level <1|2|3> \
  --iterations 2 --rounds 2 --csv <out.csv>
```

`<case>-L*.csv` 为 3/3 五文件位置表原始数据，`full-<case>-L*.csv` 为 2/2
12 文件单调性核验原始数据；所有 CSV 均含命令、二进制哈希、CPU、构建模式与
参考版本。
