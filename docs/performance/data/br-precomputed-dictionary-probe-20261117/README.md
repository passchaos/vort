# Brotli precomputed static-dictionary probe (2026-11-17)

## 结论

q11 的 optimal parse 在**每个位置**调用静态字典的 `findLongest`；q11 对
同一输入运行四次 parse（first、modeled、modeled2、bonus），同一批字典
查询被重复四次。per-parse trace 显示四个 `optimal_parse` 事件分别为
182.2 / 165.8 / 166.8 / 166.1 ms，而无字典 provider 的隔离 probe 只有
25–42 ms，字典查询是 q11 的主要成本。

现在在 q10/q11 候选入口把每个位置的字典匹配预计算一次
（`[]?lz77.DictionaryMatch`），四次 parse 通过
`PrecomputedDictionaryProbe` 复用同一结果。

128 KiB dickens q11 三轮中位数：

| 版本 | bytes | vort_ns（2 iters） | 速度 |
| --- | ---: | ---: | ---: |
| baseline | 43,953 | 2,166,505,689 | 0.12 MiB/s |
| precomputed probe | 43,953 | 1,303,374,958 | 0.19 MiB/s |

**1.662x 加速，wire 完全一致（-0 字节）**。

## 为什么安全

- 字典匹配只取决于输入位置与静态字典，不依赖 parse 的 cost model；
- 预计算调用的是原来的 `QualityDictionaryProbe.find`，返回值逐位相同；
- 四次 parse 读取同一数组，DP 的字典分支、`dictionary_cost` 与最终 wire
  均不变；
- 内存代价：`input.len * @sizeOf(?DictionaryMatch)`，128 KiB 约 1.5 MB，
  每次 q10/q11 候选分配一次；小输入按比例缩小。

## 证据

- `base-r1..3.csv` / `new-r1..3.csv`：q11 dickens 三轮 `--iterations 2`；
- `summary.csv`：字节差、`vort_ns` 中位数与 1.6622x speedup；
- per-parse trace（临时 profile hook）：四个 `optimal_parse` 事件
  182.2 / 165.8 / 166.8 / 166.1 ms；
- `run-br-optimal-search-probe`（无字典）fixed/modeled parse 25–42 ms；
- `zig build test-br`：1619/1620 pass（1 skipped）。
- `zig build test`：5666/5668 pass（2 skipped）。

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
