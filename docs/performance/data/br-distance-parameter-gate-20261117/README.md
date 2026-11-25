# Brotli distance-parameter estimated-gain gate (2026-11-17)

## 结论

planned q9 的 distance-parameter 搜索会为每个候选参数集完整重编码一次
command plan。搜索的选择器已经算出估计节省位数；当估计节省低于 64 字节
（512 bit）且块不小于 64 KiB 时，这个候选在 12 个 Silesia 文件上从未
改善最终 wire，因此现在直接跳过它的完整物化。估计节省较大的输入
（mozilla / mr / sao）仍保留搜索。

六文件 128 KiB planned q9 重复中位数几何平均 **1.128x**，全部 wire
SHA-256 与基线一致。

| case | base 三轮 (MiB/s) | new 三轮 (MiB/s) | median | speedup | bytes | wire same |
| --- | --- | --- | ---: | ---: | ---: | :---: |
| dickens | 1.110 / 1.120 / 1.130 | 1.470 / 1.490 / 1.480 | 1.120 -> 1.480 | 1.321x | 48,833 | yes |
| xml | 4.780 / 4.820 / 4.810 | 6.060 / 6.130 / 6.070 | 4.810 -> 6.070 | 1.262x | 9,123 | yes |
| mozilla | 1.870 / 1.890 / 1.880 | 1.870 / 1.890 / 1.870 | 1.880 -> 1.870 | 0.995x | 18,704 | yes |
| mr | 1.200 / 1.210 / 1.210 | 1.200 / 1.210 / 1.210 | 1.210 -> 1.210 | 1.000x | 30,317 | yes |
| sao | 0.810 / 0.810 / 0.810 | 0.810 / 0.810 / 0.810 | 0.810 -> 0.810 | 1.000x | 92,515 | yes |
| webster | 1.550 / 1.550 / 1.560 | 1.930 / 1.930 / 1.940 | 1.550 -> 1.930 | 1.245x | 40,534 | yes |

几何平均：**1.128x**；mozilla 的 0.995x 在噪声范围内，无低于 0.98x 的
对照。

与前面三个增量（far-candidate gate、entropy-split 符号候选 skip、
combined alternate-context skip）叠加后，相对 2026-11-17 初始 planned q9
基线累计约 **1.93x 几何平均**（dickens 2.96x、xml 2.32x、mozilla 1.66x、
mr 1.57x、sao 1.42x、webster 2.03x）。

## 估计节省与实测 wire

临时 instrumentation（未提交）打印
`chooseDistanceParameterAlternativeAlloc` 的估计节省位数：

| case | commands | base bits | estimated saving | actual wire delta | gate |
| --- | ---: | ---: | ---: | ---: | --- |
| dickens | 18,047 | 271,289 | 46 | 0 | skip |
| xml | 2,625 | 35,173 | 1 | 0 | skip |
| webster | 14,198 | 206,322 | 14 | 0 | skip |
| mozilla | 5,832 | 56,344 | 3,350 | -150 | keep |
| mr | 11,652 | 170,400 | 9,808 | -501 | keep |
| sao | 12,701 | 180,781 | 25,326 | -3,095 | keep |

估计节省与实测胜负高度一致；最小的获胜估计是 3,350 bit（mozilla），
最大的失败估计是 46 bit（dickens）。512-bit 阈值给出明确间隔。

## 小输入保护

最初使用绝对 512-bit 阈值时，bench 内置 `source`（83 字节）wire 从
83 变 84 字节：小输入上 1 字节仍然重要。最终条件要求
`total_output_len >= 64 * 1024`，小输入保留搜索；内置 9 个案例 wire
全部恢复一致。

## 改动

`src/br.zig` 的 `chooseDistanceParameterAlternativeAlloc`：

- 在已有的 command 遍历中累计 `total_output_len`；
- 在原有参数等价/估计更差检查之后：

```zig
if (total_output_len >= 64 * 1024 and
    selection.baseline.totalBits() - preferred.totalBits() < 512) return null;
```

返回 `null` 后调用方只保留基线候选，不再为估计收益低于 64 字节的参数集
完整重编码 command plan。

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
- `zig fmt --check src/br.zig` 与 `git diff --check` 通过。
- 参考库吞吐仅用于 wire 尺寸对照；本包不主张 Vort 已达到 libbrotli q9
  的绝对速度。
