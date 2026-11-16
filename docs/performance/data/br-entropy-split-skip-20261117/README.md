# Brotli entropy-split candidate skip (2026-11-17)

## 结论

planned q9 的 entropy-split 候选组每次调用都会完整物化 legacy split、adaptive
command、adaptive distance 和 combined 四个 wire。逐候选追踪显示 legacy
split 与 standalone adaptive command 从未在 12 个 Silesia 前缀的任一次调用
中胜出；combined 与 adaptive distance 覆盖了全部胜者。现在：

- 当 adaptive command 和 adaptive distance 同时存在时，跳过 legacy split
  wire；
- 当 adaptive distance 存在时，跳过 standalone adaptive command wire
  （combined 已覆盖 command+distance 两个维度）。

六文件 128 KiB planned q9 重复中位数几何平均 **1.259x**，全部 wire
SHA-256 与基线一致。

| case | base 三轮 (MiB/s) | new 三轮 (MiB/s) | median | speedup | bytes | wire same |
| --- | --- | --- | ---: | ---: | ---: | :---: |
| dickens | 0.540 / 0.550 / 0.550 | 0.880 / 0.880 / 0.880 | 0.550 -> 0.880 | 1.600x | 48,833 | yes |
| xml | 3.410 / 3.450 / 3.430 | 4.140 / 4.140 / 4.150 | 3.430 -> 4.140 | 1.207x | 9,123 | yes |
| mozilla | 1.410 / 1.420 / 1.410 | 1.660 / 1.660 / 1.660 | 1.410 -> 1.660 | 1.177x | 18,704 | yes |
| mr | 0.870 / 0.880 / 0.870 | 1.060 / 1.060 / 1.060 | 0.870 -> 1.060 | 1.218x | 30,317 | yes |
| sao | 0.560 / 0.570 / 0.570 | 0.680 / 0.690 / 0.690 | 0.570 -> 0.690 | 1.211x | 92,515 | yes |
| webster | 1.180 / 1.180 / 1.170 | 1.400 / 1.400 / 1.410 | 1.180 -> 1.400 | 1.186x | 40,534 | yes |

几何平均：**1.259x**；最弱行 1.177x，无低于 0.98x 的对照。

与上一增量（far-candidate gate）叠加后，相对 2026-11-17 初始 planned q9
基线（dickens 0.490 / xml 2.610 / mozilla 1.130 / mr 0.770 / sao 0.570 /
webster 0.950）的累计加速为 **1.47x 几何平均**（dickens 1.76x、xml 1.59x、
mozilla 1.47x、mr 1.38x、sao 1.21x、webster 1.47x）。

## 候选追踪

在 `entropy_wire_selection.consider` 上临时加标签（未提交），对每个
planned q9 编码记录每个候选的 wire 大小与是否替换当前选择：

| 输入 | entropy-split 调用数 | 每次调用的胜者 |
| --- | ---: | --- |
| dickens / mr / samba | 4 | combined（全部 4 次） |
| mozilla / x-ray | 1 | combined |
| nci / ooffice / osdb / reymont / webster / xml | 1 | adaptive distance |
| sao | 4 | adaptive distance（全部 4 次） |

`legacy_wire`、`adaptive_command`、`adaptive_literal` 以及 samba 上的
`two_literal_candidate` / `four_literal_candidate` 均未在任何调用中胜出。
单独跳 legacy split 在 dickens 上为 1.255x、mr 1.046x，其余文件约 1.0x；
单独跳 adaptive command 在所有文件上为 1.16-1.22x。

## 改动

`src/br.zig` 的 `encodeEntropySplitCandidateAllocRecorded`：

- `has_adaptive_combined` 为真时不再调用
  `encodeEntropySplitWireCandidateAllocRecorded` 物化 legacy split wire；
- `symbol_splits.adaptive_distance` 存在时不再物化 later standalone adaptive
  command wire；没有 adaptive distance 时仍保留该候选。若 counted adaptive
  literal plan 不可用，初始候选槽仍会回退到 adaptive command wire，保证
  ratio 安全。

adaptive literal（counting writer）、adaptive distance 与 combined 候选
不受影响。

## 证据

- `base-r1..3.csv` / `new-r1..3.csv`：六文件三轮 `--iterations 5` 原始读数；
- `summary.csv`：逐文件中位数与 speedup；
- `wire-128k-{base,new}.json`：12 个 Silesia 128 KiB 前缀；
- `wire-1m-{base,new}.json`：dickens/xml/mozilla/nci/osdb/x-ray 的 1 MiB；
- `wire-4m-{base,new}.json`：dickens/xml/x-ray 的 4 MiB；
- `wire-synth-{base,new}.json`：四个合成 far-copy 输入（400 KiB、1 MiB、
  664 KiB 混合、2 MiB）。

wire 身份结论：12/12 个 128 KiB、6/6 个 1 MiB、3/3 个 4 MiB、4/4 个合成
输入的 `vort_bytes` 和 `vort_sha256` 全部与基线一致。

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
- bench 内置 9 个案例（json/source/log/dictionary/mixed/uppercase/
  incompressible/records_q8/source32k）wire SHA-256 全部一致。
- `zig fmt --check src/br.zig` 与 `git diff --check` 通过。
- 参考库吞吐仅用于 wire 尺寸对照；本包不主张 Vort 已达到 libbrotli q9
  的绝对速度。
