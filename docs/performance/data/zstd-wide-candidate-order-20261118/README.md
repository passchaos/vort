# Zstd wide-candidate emission order (2026-11-18)

## 结论

在 `.strict` wide-match 速度策略下，把 double-fast 候选的完整 wire 发射推迟到
与 rep-beam token 逐项相等证明之后。落败候选不再先物化再丢弃，L9 取得
**1.033x**、L22 取得 **1.036x** 几何平均加速（12 文件 128 KiB 前缀），
所有比较行 wire 字节完全一致。L1 对照在噪声内（dickens 0.995x、xml 0.999x）。

## 改动

基线：`053e57e4`。`src/zstd.zig` 的
`emitDecisiveWideMatchCompressedBlockInternal`：

- 原顺序：plan double-fast → 发射完整 wire → 尺寸门 → strict 下 plan rep-beam
  → token 比较；不相等时回滚并丢弃已发射 wire。
- 新顺序：plan double-fast → plan rep-beam → token 比较；仅在相等后发射一次
  wire 并做尺寸门。`.fastest`/`.fast` 策略仍保留原有“先发射再判断速度策略”
  的顺序。
- `precomputed_rep_beam_stats`、`state_applied` 与回滚语义不变；输出 wire
  逐字节一致。

## L9 结果（128 KiB 前缀，level 9）

交错 A/B，每侧 3 个进程 × `--iterations 2`，取中位数；原始 CSV 在 `l9/`。

| case | before ms | after ms | speedup | bytes |
| --- | ---: | ---: | ---: | ---: |
| dickens | 87.39 | 84.87 | 1.030x | 50,404 |
| mozilla | 41.13 | 39.52 | 1.041x | 22,914 |
| mr | 78.29 | 74.36 | 1.053x | 32,676 |
| nci | 124.19 | 124.38 | 0.998x | 10,401 |
| ooffice | 81.84 | 78.40 | 1.044x | 68,549 |
| osdb | 93.70 | 90.99 | 1.030x | 50,003 |
| reymont | 56.38 | 53.16 | 1.061x | 37,093 |
| samba | 78.21 | 76.70 | 1.020x | 47,596 |
| sao | 83.90 | 82.29 | 1.020x | 97,832 |
| webster | 51.91 | 49.37 | 1.051x | 41,734 |
| xml | 28.44 | 27.78 | 1.024x | 9,712 |
| x-ray | 68.88 | 67.16 | 1.025x | 100,874 |

几何平均 **1.0329x**；min 0.9984x，max 1.0607x。

## L22 结果（128 KiB 前缀，level 22）

原始 CSV 在 `l22/`。

| case | before ms | after ms | speedup |
| --- | ---: | ---: | ---: |
| dickens | 87.16 | 85.12 | 1.024x |
| mozilla | 41.39 | 39.63 | 1.044x |
| mr | 78.67 | 73.76 | 1.067x |
| nci | 124.30 | 124.08 | 1.002x |
| ooffice | 80.68 | 78.06 | 1.034x |
| osdb | 91.91 | 92.08 | 0.998x |
| reymont | 56.51 | 52.23 | 1.082x |
| samba | 78.17 | 76.25 | 1.025x |
| sao | 84.38 | 81.76 | 1.032x |
| webster | 52.25 | 49.31 | 1.060x |
| xml | 28.51 | 27.86 | 1.023x |
| x-ray | 69.36 | 66.81 | 1.038x |

几何平均 **1.0355x**；min 0.9982x，max 1.0818x。

## L1 对照

`.fastest` 路径未改动；dickens 5×10 次迭代 0.9945x，xml 0.9987x，均在噪声内
且高于 0.98x 控制下限。原始 CSV 在 `l1/`。

## 已排除：hash 链 prefetch

在 `lz77.findBestHashMatchWithLayoutAndHashLimits` 中提前读取下一个链节点并
`@prefetch` 下一个候选的输入字节：L9 的 12 文件端到端 **0.988x** 几何平均
（min 0.963x，max 1.010x），是明确回归；已回退，回退后二进制与优化版逐字节
一致。链节点已基本驻留 L2/L3，提前读取与预取指令反而增加开销。

## 验证

- `zig build test-zstd --summary all`：5/5 steps，1430/1430 tests 通过。
- `zig build run-zstd-encode-bench-gate`：ok（20 rows，libzstd 1.4.8）。
- 12 文件 L9/L22 与 L1 对照的 `vort_bytes` 与基线逐字节一致。
- `zig build -j2 test check check-wasm --summary all`：389/389 steps，
  5756/5758 tests 通过（2 skipped）；`test` 步骤 5663 pass / 2 skip。
- 首次全门中 `check-zstd-source-reverse` 的 node WASI 门出现过一次偶发非零
  退出；对同一 wasm 产物单独重跑通过（`status:"ok"`，exit=0）。

## 环境与命令

- CPU：Intel Core i7-10700K @ 3.80 GHz（`skylake+pku+sgx`）
- Zig 0.16.0，ReleaseFast，单线程
- libzstd 1.4.8（系统 `libzstd.so.1`）

```sh
<bench> --path <silesia-file> --limit 131072 --level <9|22> \
  --iterations 2 --rounds 1 --csv <out.csv>
```
