# Brotli distance-search whole-candidate skip (2026-11-17)

## 结论

distance-parameter 搜索在估计收益低于门限时不仅应跳过 alternative 参数集，
还应跳过 `force_recent_distances` 的 baseline 编码。逐候选追踪显示：在
估计收益低于 512 bit 的 12 个 Silesia 128 KiB 文件上，整个 split-aware
搜索候选要么输给已有 best，要么与 best 持平，从未严格获胜。现在 q9 在
块 >= 64 KiB 且 `chooseDistanceParameterAlternativeAlloc` 返回 null 时
同时跳过 parameter-only 候选与 split-aware 候选；parameter 选择只计算
一次，并与两个候选族共享。小于 64 KiB 的输入保留原路径，因为 frozen
legacy wire 测试中存在 forced-recent baseline 唯一获胜的样本。

六文件 128 KiB planned q9 重复中位数几何平均 **1.236x**，全部 wire
SHA-256 与基线一致。

| case | base 三轮 (MiB/s) | new 三轮 (MiB/s) | median | speedup | bytes | wire same |
| --- | --- | --- | ---: | ---: | ---: | :---: |
| dickens | 1.470 / 1.490 / 1.480 | 2.180 / 2.180 / 2.140 | 1.480 -> 2.180 | 1.473x | 48,833 | yes |
| xml | 6.060 / 6.130 / 6.070 | 9.070 / 9.090 / 9.070 | 6.070 -> 9.070 | 1.494x | 9,123 | yes |
| mozilla | 1.870 / 1.890 / 1.870 | 1.930 / 1.930 / 1.940 | 1.870 -> 1.930 | 1.032x | 18,704 | yes |
| mr | 1.200 / 1.210 / 1.210 | 1.260 / 1.250 / 1.230 | 1.210 -> 1.250 | 1.033x | 30,317 | yes |
| sao | 0.810 / 0.810 / 0.810 | 0.820 / 0.820 / 0.810 | 0.810 -> 0.820 | 1.012x | 92,515 | yes |
| webster | 1.930 / 1.930 / 1.940 | 2.900 / 2.890 / 2.850 | 1.930 -> 2.890 | 1.497x | 40,534 | yes |

几何平均：**1.236x**；最弱行 1.012x，无低于 0.98x 的对照。

与前面四个增量叠加后，相对 2026-11-17 初始 planned q9 基线累计约
**2.39x 几何平均**（dickens 4.36x、xml 3.46x、mozilla 1.71x、mr 1.62x、
sao 1.44x、webster 3.04x）。

## 追踪证据

临时 instrumentation（未提交）在 distance-search 调用点打印
`best_before` 与搜索候选大小：

| case | best before | search candidate | 结论 |
| --- | ---: | ---: | --- |
| dickens | 48,833 | 48,834 | 输 |
| xml | 9,123 | 9,167 | 输 |
| webster | 40,534 | 40,541 | 输 |
| ooffice | 64,646 | 64,699 | 输 |
| reymont | 35,287 | 35,287 | 持平 |
| samba | 45,769 | 45,769 | 持平 |
| mozilla | 18,854 | 18,704 | 赢 |
| mr | 30,818 | 30,317 | 赢 |
| sao | 93,411 | 92,515 | 赢 |
| nci | 9,645 | 9,577 | 赢 |
| osdb | 47,262 | 46,956 | 赢 |
| x-ray | 84,558 | 82,135 | 赢 |

搜索候选严格获胜的 6 个文件全部有 alternative 参数集；估计收益低于门限的
6 个文件从未严格获胜（2 个持平）。因此 `null` 时跳过整个候选是安全的。

## 改动

`src/br.zig`：

- 新增 `encodeCommandPlanWithDistanceParametersAllocRecorded`，复用已选好的
  alternative 参数，比较默认参数 baseline 与该参数集的完整 wire；
- `encodeDistanceParameterSearchWithSplitsAllocRecorded` 增加
  `precomputed_alternative: ?encoder_distance.Parameters`；没有 alternative
  时仍返回 baseline（保持小输入与 q8 的原行为）；
- q9 调用点在 `input.len >= 64 KiB` 时只计算一次
  `chooseDistanceParameterAlternativeAlloc`：
  - `null` → 同时跳过 parameter-only 与 split-aware 候选（不调用后者）；
  - 非 `null` → parameter-only 与 split-aware 候选共享同一参数选择。
- 小于 64 KiB 的输入保留原路径：parameter-only 候选与 split-aware 候选
  仍各自运行，frozen legacy wires 不变。
- q8 的 prepared-pair 路径保持原行为（仍由 wrapper 自行选择参数）。

两次测试拦截了过度裁剪：

1. 最初对全部输入跳过整个候选，`Brotli large window default false and
   instrumentation preserve the frozen complete legacy wires` 失败（57 字节
   wire 内容变化）；加上 64 KiB 条件后恢复。
2. 把 split-aware 函数的无 alternative 结果从 baseline 改成 `null`，导致
   `br serialized dictionary trainer learns UTF-8 shift transforms` 的
   `baseline_frame_bytes` 从 3512 变 3513；恢复 baseline 返回后通过。
   只有 q9 大块调用点可以在 null 时跳过整个调用。

第一次尝试在调用点重复计算参数，导致 alternative 文件多一次频率收集，
mozilla/mr 出现 0.95-0.97x；改为共享参数后恢复为 1.01-1.03x。

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
- frozen legacy wire（32/32）、distance-parameter（41/41）与 UTF-8 shift
trainer 定向测试均通过。
- 定向 `-Dbr-test-filter="distance parameter"`：41/41 pass。
- `zig fmt --check src/br.zig` 与 `git diff --check` 通过。
- 参考库吞吐仅用于 wire 尺寸对照；本包不主张 Vort 已达到 libbrotli q9
  的绝对速度。
