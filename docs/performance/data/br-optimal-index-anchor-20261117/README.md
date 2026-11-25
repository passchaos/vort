# Brotli optimal-index four-byte anchor (2026-11-17)

## 结论

Brotli optimal parser 的 compact index 一直使用 4-byte hash，但
entropy-modeled parse 走的 non-compact index 仍用 3-byte hash。optimal
parser 的最小匹配是 4 字节（q10/q11 的 `min_match = 4`），3-byte bucket
里只匹配 3 字节的候选不可能产生被接受的匹配，却会消耗 chain 预算。
现在 non-compact index 在 `minMatch(options) >= 4` 时改用 `.four` anchor。

q11 在 128 KiB dickens 前缀上的三轮中位数：

| 版本 | bytes | 三轮 (MiB/s) | median |
| --- | ---: | --- | ---: |
| baseline | 43,956 | 0.110 / 0.100 / 0.110 | 0.110 |
| four-byte anchor | 43,953 | 0.120 / 0.120 / 0.120 | 0.120 |

**+9.1% 速度，-3 字节**。q9 与 q10 lazy wire 不变；q10 的 compact optimal
路径本来就使用 4-byte hash。

## 为什么安全

- `HashIndex.build` 仍保留 `.three` 默认，3-byte 匹配的调用方行为不变；
- 新入口 `buildWithAnchor` 只被 optimal parser 在 `minMatch >= 4` 时使用；
- 3-byte-only 候选无法通过 `matchLength >= minimum`，因此跳过它们不改变
  可接受匹配集合；
- chain 预算现在只被 4-byte 候选消耗，可能走得更深；实测 q11 尺寸反而
  减小 3 字节，没有比率回退。

## 证据

- `base-r1..3.csv` / `new-r1..3.csv`：q11 dickens 三轮 `--iterations 2`；
- `summary.csv`：中位数、speedup 与字节差；
- `zig build test`：5666/5668 pass（2 skipped）；
- `zig build test-br`：1619/1620 pass（1 skipped）；
- `run-br-optimal-search-probe` 的 compact-path 计数在改动前后完全一致
  （该路径原本就是 4-byte hash），说明收益来自 modeled/non-compact parse。

## 环境与命令

- CPU：Intel Core i7-10700K @ 3.80 GHz（`skylake+pku+sgx`）
- Zig 0.16.0，ReleaseFast，单线程，无 CPU affinity 固定
- 命令：

```sh
zig build run-br-planned-encode-bench -- \
  --path <silesia-file> --limit 131072 \
  --planned-quality 11 --quality 11 --iterations 2 \
  --csv <out.csv>
```
