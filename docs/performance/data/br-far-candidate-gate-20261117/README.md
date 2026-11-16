# Brotli default-window far-candidate gate (2026-11-17)

## 结论

planned q9（`--planned-quality 9 --quality 9`，generic，128 KiB Silesia
前缀）在默认 16-bit ratio 流上不再为“近似不可赢”的 far candidate 物化完整
wire：当 near plan 已经匹配大部分字节（literal share < 50%）时，跳过
all-literal far 提案，只保留 near-plan far 提案。六文件重复中位数几何平均
**1.167x**，逐文件 1.000-1.309x，全部 wire SHA-256 与基线一致。

| case | base 三轮 (MiB/s) | new 三轮 (MiB/s) | median | speedup | bytes | wire same |
| --- | --- | --- | ---: | ---: | ---: | :---: |
| dickens | 0.490 / 0.500 / 0.500 | 0.550 / 0.540 / 0.550 | 0.500 -> 0.550 | 1.100x | 48,833 | yes |
| xml | 2.610 / 2.630 / 2.620 | 3.430 / 3.410 / 3.450 | 2.620 -> 3.430 | 1.309x | 9,123 | yes |
| mozilla | 1.130 / 1.130 / 1.140 | 1.410 / 1.400 / 1.420 | 1.130 -> 1.410 | 1.248x | 18,704 | yes |
| mr | 0.770 / 0.770 / 0.770 | 0.870 / 0.860 / 0.870 | 0.770 -> 0.870 | 1.130x | 30,317 | yes |
| sao | 0.570 / 0.570 / 0.570 | 0.570 / 0.560 / 0.570 | 0.570 -> 0.570 | 1.000x | 92,515 | yes |
| webster | 0.950 / 0.950 / 0.950 | 1.180 / 1.170 / 1.180 | 0.950 -> 1.180 | 1.242x | 40,534 | yes |

几何平均：**1.167x**；最弱对照行 1.000x，没有低于 0.98x 的对照。

## 根因

对 `considerDefaultWindowFarCandidate` 的临时 instrumentation（未提交）显示，
128 KiB 输入上 near plan 的 literal 只剩 3,050-7,909 字节（sao 为 66,198），
far matcher 在 near-plan 提案的 literal run 中没有找到可用的 far copy，于是
`augmentAllocWithOptions` 返回 `null`；真正被完整编码的是 all-literal 提案：

- 它丢弃 near plan 的全部近距匹配；
- 为容纳 far distance，wire window 从 16 bit 扩到 17 bit；
- 17-bit distance code 的代价远大于 far copy 的收益。

| case | literal bytes | near plan 17-bit 重编码 | best | 差 |
| --- | ---: | ---: | ---: | ---: |
| dickens | 7,675 | 59,442 | 48,834 | +10,608 |
| xml | 3,050 | 48,574 | 9,167 | +39,407 |
| mozilla | 7,546 | 43,920 | 18,919 | +25,001 |
| mr | 7,276 | 36,503 | 30,820 | +5,683 |
| webster | 7,909 | 61,726 | 40,541 | +21,185 |

也就是说，near plan 的 17-bit 窗口扩展本身已经把候选推到必败位置；far
copy 只能回收其中很小一部分。sao 的 literal share 为 50.5%，仍走原路径，
因此保持中性。

## 改动

`src/br.zig` 的 default-window far 选择器把 all-literal 提案限制在
`large_literal_share`（literal bytes >= input.len / 2）的块；near-plan
提案不受影响，explicit 17-bit+ 窗口路径也不受影响。这样保留了 far
candidate 对真正 literal-heavy / 大 far-copy 输入的收益，同时避免在
near plan 已覆盖大部分输入时物化必败候选。

## 证据

- `base-r1..3.csv` / `new-r1..3.csv`：六文件三轮 `--iterations 5` 原始读数；
- `summary.csv`：逐文件中位数与 speedup；
- `wire-128k-{base,new}.json`：12 个 Silesia 128 KiB 前缀的 wire bytes 与
  SHA-256；
- `wire-1m-{base,new}.json`：dickens/xml/mozilla/nci/osdb/x-ray 的 1 MiB
  前缀 wire 身份；
- `wire-synth-{base,new}.json`：四个合成 far-copy 输入（400 KiB、1 MiB、
  664 KiB 混合、2 MiB）的 wire 身份。

wire 身份结论：12/12 个 128 KiB、6/6 个 1 MiB、4/4 个合成输入全部
`vort_bytes` 和 `vort_sha256` 与基线一致。

## 环境与命令

- CPU：Intel Core i7-10700K @ 3.80 GHz（`skylake+pku+sgx`）
- Zig 0.16.0，ReleaseFast，单线程，无 CPU affinity 固定
- 参考库：系统 libbrotli 1.0.9（`1000009`），lgwin 22，mode 0
- 命令：

```sh
zig build run-br-planned-encode-bench -- \
  --path <silesia-file> --limit 131072 \
  --planned-quality 9 --quality 9 --iterations 5 \
  --csv <out.csv>
```

wire 身份比较使用 `--samples-json <out.json>` 的 `wires.vort_sha256`。

## 验证

- `zig build test-br`：1619 pass / 1 skip（1620 total），31m，Debug native。
- `zig fmt --check src/br.zig` 与 `git diff --check` 通过。
- 参考库吞吐仅用于 wire 尺寸对照；本包不主张 Vort 已达到 libbrotli q9
  的绝对速度（dickens 仍为 0.55 vs 9.47 MiB/s）。
