# Brotli distance-parameter coarse-shape gate (2026-11-17)

## 结论

q9 的 distance-parameter 选择会在 18k 命令上扫描全部 64 个 RFC 7932 参数
形状；仅这次规划扫描在 dickens 上就占 **7.4 ms（约 14%）**，即使两个搜索
候选最终都被跳过。现在先用 10 个代表性形状做粗筛：粗筛最优无法越过
512-bit 门限时，直接跳过精确的 64-shape 搜索；粗筛通过时仍由精确搜索
选择最终参数。

六文件 128 KiB planned q9 重复中位数几何平均 **1.047x**，全部 wire
SHA-256 与基线一致。

| case | base 三轮 (MiB/s) | new 三轮 (MiB/s) | median | speedup | bytes | wire same |
| --- | --- | --- | ---: | ---: | ---: | :---: |
| dickens | 2.180 / 2.180 / 2.140 | 2.410 / 2.400 / 2.420 | 2.180 -> 2.410 | 1.106x | 48,833 | yes |
| xml | 9.070 / 9.090 / 9.070 | 9.780 / 9.770 / 9.770 | 9.070 -> 9.770 | 1.077x | 9,123 | yes |
| mozilla | 1.930 / 1.930 / 1.940 | 1.910 / 1.920 / 1.920 | 1.930 -> 1.920 | 0.995x | 18,704 | yes |
| mr | 1.260 / 1.250 / 1.230 | 1.250 / 1.250 / 1.250 | 1.250 -> 1.250 | 1.000x | 30,317 | yes |
| sao | 0.820 / 0.820 / 0.810 | 0.820 / 0.820 / 0.820 | 0.820 -> 0.820 | 1.000x | 92,515 | yes |
| webster | 2.900 / 2.890 / 2.850 | 3.210 / 3.190 / 3.210 | 2.890 -> 3.210 | 1.111x | 40,534 | yes |

几何平均：**1.047x**；mozilla 的 0.995x 在噪声范围内，无低于 0.98x 的
对照。

与前面五个增量叠加后，相对 2026-11-17 初始 planned q9 基线累计约
**2.49x 几何平均**（dickens 4.82x、xml 3.73x、mozilla 1.70x、mr 1.62x、
sao 1.44x、webster 3.38x）。

## 形状证据

12 个 Silesia 128 KiB 文件的完整 64-shape 搜索结果：

| 类型 | 文件 | 估计节省 | 最优形状 (npostfix, ndirect_high) |
| --- | --- | ---: | --- |
| 保留 | mozilla | 3,350 bit | (3, 4) |
| 保留 | mr | 9,808 bit | (1, 1) |
| 保留 | sao | 25,326 bit | (3, 15) |
| 保留 | nci | 956 bit | (3, 15) |
| 保留 | osdb | 3,095 bit | (2, 8) |
| 保留 | x-ray | 25,702 bit | (1, 14) |
| 跳过 | dickens | 46 bit | (2, 0) |
| 跳过 | xml | 1 bit | (0, 1) |
| 跳过 | webster | 14 bit | (0, 7) |
| 跳过 | ooffice | 176 bit | (3, 1) |
| 跳过 | reymont | 101 bit | (0, 10) |
| 跳过 | samba | 47 bit | (0, 13) |

粗筛形状集（baseline 之外 9 个）：

```
(0,1) (1,1) (1,8) (1,14) (2,4) (2,8) (3,4) (3,8) (3,15)
```

覆盖了全部 6 个获胜形状。粗筛最优不可能超过完整 64-shape 最优，因此
不会产生“粗筛通过但精确搜索失败”的假阳性；风险只在“获胜形状不在粗筛
集合”时产生假阴性。12/12 文件的 wire 身份验证表明当前集合没有漏掉胜者。

## 改动

- `src/br/encoder/distance_parameter_search.zig`：新增 `selectCoarseAlloc`
  / `selectCoarse`，只评分 baseline 与上述 9 个形状。
- `src/br.zig` 的 `chooseDistanceParameterAlternativeAlloc`：在块 >= 64 KiB
  时先跑粗筛；粗筛最优未越过 512-bit 门限则直接返回 null，否则继续跑
  完整 `selectAlloc`。
- 同时把已存在但从未接线的 `sortDistanceFrequencies` 基数排序接入该函数
  （与比较排序同为升序，wire 不变）。

## 证据

- `base-r1..3.csv` / `new-r1..3.csv`：六文件三轮 `--iterations 5` 原始读数；
- `summary.csv`：逐文件中位数与 speedup；
- `wire-128k-{base,new}.json`：12 个 Silesia 128 KiB 前缀；
- `wire-1m-{base,new}.json`：dickens/xml/mozilla/nci/osdb/x-ray 的 1 MiB；
- `wire-4m-{base,new}.json`：dickens/xml/x-ray 的 4 MiB；
- `wire-synth-{base,new}.json`：四个合成 far-copy 输入；
- `wire-builtin-{base,new}.json`：bench 内置 9 个案例。

wire 身份结论：12/12、6/6、3/3、4/4、9/9 全部一致。

## 环境与命令

- CPU：Intel Core i7-10700K @ 3.80 GHz（`skylake+pku+sgx`）
- Zig 0.16.0，ReleaseFast，单线程，无 CPU affinity 固定
- 参考库：系统 libbrotli 1.0.9，lgwin 22，mode 0
- 命令：

```sh
zig build run-br-planned-encode-bench -- \
  --path <silesia-file> --limit 131072 \
  --planned-quality 9 --quality 9 --iterations 5 \
  --csv <out.csv>
```

## 验证

- `zig build test-br`：1619 pass / 1 skip（1620 total），31m，Debug native。
- 定向 `-Dbr-test-filter="distance parameter"`：41/41 pass。
- `zig fmt --check` 与 `git diff --check` 通过。
- 参考库吞吐仅用于 wire 尺寸对照；本包不主张 Vort 已达到 libbrotli q9
  的绝对速度。
