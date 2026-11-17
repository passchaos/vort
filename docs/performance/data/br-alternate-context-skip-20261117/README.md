# Brotli combined-split alternate-context skip (2026-11-17)

## 结论

`encodeEntropySplitWireCandidateInternalAllocRecorded` 在为 combined
command+distance 候选编码时，会针对 baseline 保留的每个落选 literal
context 再完整重编码一次 command plan。12 个 Silesia 128 KiB 前缀的
planned q9 中，这类 alternate context 候选 **0/1096** 次胜出；plain
literal 变体也没有出现。现在 combined 候选不再重编码这些落选 context；
standalone adaptive distance 候选保留 counted oracle 所需的同一组
alternates，legacy split 路径保持不变。

六文件 128 KiB planned q9 重复中位数几何平均 **1.164x**，全部 wire
SHA-256 与基线一致。

| case | base 三轮 (MiB/s) | new 三轮 (MiB/s) | median | speedup | bytes | wire same |
| --- | --- | --- | ---: | ---: | ---: | :---: |
| dickens | 0.880 / 0.880 / 0.880 | 1.110 / 1.120 / 1.130 | 0.880 -> 1.120 | 1.273x | 48,833 | yes |
| xml | 4.140 / 4.140 / 4.150 | 4.780 / 4.820 / 4.810 | 4.140 -> 4.810 | 1.162x | 9,123 | yes |
| mozilla | 1.660 / 1.660 / 1.660 | 1.870 / 1.890 / 1.880 | 1.660 -> 1.880 | 1.133x | 18,704 | yes |
| mr | 1.060 / 1.060 / 1.060 | 1.200 / 1.210 / 1.210 | 1.060 -> 1.210 | 1.142x | 30,317 | yes |
| sao | 0.680 / 0.690 / 0.690 | 0.810 / 0.810 / 0.810 | 0.690 -> 0.810 | 1.174x | 92,515 | yes |
| webster | 1.400 / 1.400 / 1.410 | 1.550 / 1.550 / 1.560 | 1.400 -> 1.550 | 1.107x | 40,534 | yes |

几何平均：**1.164x**；最弱行 1.107x，无低于 0.98x 的对照。

与前面两个增量（far-candidate gate、entropy-split 符号候选 skip）叠加后，
相对 2026-11-17 初始 planned q9 基线（dickens 0.490 / xml 2.610 /
mozilla 1.130 / mr 0.770 / sao 0.570 / webster 0.950）累计约 **1.70x
几何平均**（dickens 2.24x、xml 1.84x、mozilla 1.66x、mr 1.57x、sao 1.42x、
webster 1.63x）。

## 根因

临时 instrumentation（未提交）在 alternate 循环中记录 `selected` 与
`alternate` 的完整 wire 大小：

```
alternate: 0/1096 wins; plain: 0/0 wins
```

alternate 候选通常比 selected 大 200-300 字节（dickens 49,088 vs 48,838）。
它们来自 `PreferredCommandPlan.alternate_literal_context_candidates`，是
baseline 阶段已经输给主 context 的候选；combined split 只改变
command+distance 分块结构，不会让这些落选 context 翻盘。

这个 skip 不能扩大到 standalone adaptive distance 候选：该候选使用
counted oracle，测试 fixture 中 alternate context 可以大幅胜出
（49,396 -> 29,693）。最初的宽条件（`adaptive_command_split != null or
adaptive_distance_split != null`）正是被
`br counted adaptive distance context contracts` 测试拦下，因此最终
只对 combined 候选生效。

## 改动

`src/br.zig` 的 `encodeEntropySplitWireCandidateInternalAllocRecorded`：

```zig
const skip_alternate_contexts = adaptive_command_split != null and adaptive_distance_split != null;
if (!skip_alternate_contexts and literal_split == null and adaptive_literal_split == null) {
    // alternate literal contexts + plain-literal loop
}
```

只有 q9 的 combined command+distance 候选不再重编码落选 context；
standalone adaptive command/distance 与 legacy split 路径保持原行为。

## 证据

- `base-r1..3.csv` / `new-r1..3.csv`：六文件三轮 `--iterations 5` 原始读数；
- `summary.csv`：逐文件中位数与 speedup；
- `wire-128k-{base,new}.json`：12 个 Silesia 128 KiB 前缀；
- `wire-1m-{base,new}.json`：dickens/xml/mozilla/nci/osdb/x-ray 的 1 MiB；
- `wire-4m-{base,new}.json`：dickens/xml/x-ray 的 4 MiB；
- `wire-synth-{base,new}.json`：四个合成 far-copy 输入；
- `wire-builtin-{base,new}.json`：bench 内置 9 个案例。

wire 身份结论：12/12 个 128 KiB、6/6 个 1 MiB、3/3 个 4 MiB、4/4 个合成
输入、9/9 个内置案例的 `vort_bytes` 和 `vort_sha256` 全部与基线一致。

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

- `zig build test-br`：1619 pass / 1 skip（1620 total），31m，Debug native；
  其中 `br counted adaptive distance context contracts` 在收窄 skip 范围后通过。
- `zig fmt --check src/br.zig` 与 `git diff --check` 通过。
- 参考库吞吐仅用于 wire 尺寸对照；本包不主张 Vort 已达到 libbrotli q9
  的绝对速度。
