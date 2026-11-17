# Brotli optimal compact-index four-byte anchor (2026-11-17, rejected)

## 结论（已回退）

>64 KiB 输入的 optimal parser 走 non-eligible compact index 路径，该 index
一直用 3-byte hash；搜索循环再用 4-byte prefix 检查拒绝只匹配 3 字节的
候选。probe 显示这些拒绝占 chain nodes 的 63%。把 compact index 改为
`.four` 后单次 parse 从 44.6 ms 降到 19.3 ms，q11 端到端 1.0195x、-2
字节，但 **`lz77.test.ordinal optimal index preserves original plan and
ownership` 失败**：ordinal four-chain 被定义为原始 three-byte chain 的
过滤视图，改变 compact hash 就改变了参考 plan。该契约是显式的，因此
改动已回退；本包保留为负结果证据。

单次 optimal parse（128 KiB dickens，chain 512 / candidates 256 / nice
258）：

| 指标 | 3-byte index | 4-byte index |
| --- | ---: | ---: |
| total | 44.6 ms | **19.3 ms** |
| chain nodes | 8.06M | **3.05M** |
| prefix rejections | 5.13M | **114k** |
| matchLength calls | 270,022 | 270,294 |
| tokens | 29,609 | 29,606 |
| matched bytes | 118,393 | 118,394 |

parse 本身 **2.3x** 加速；prefix mismatch 直方图从
`[54907,0,0,5071787]` 变为 `[105860,8283,0,0]`，确认被移除的是 3-byte
匹配而非 hash 碰撞。

q11 端到端（三轮中位数，dickens 128 KiB）：

| 版本 | bytes | vort_ns (2 iters) | ns speedup |
| --- | ---: | ---: | ---: |
| baseline | 43,953 | 2,166,505,689 | — |
| compact four-byte | 43,951 | 2,125,012,061 | **1.0195x** |

q11 总时间只有约 2% 的改善，因为第一次 parse 只占 q11 的一部分；但单次
parse 的 2.3x 是 q10 大块 optimal 策略的直接成本杠杆。

## 为什么安全

- `.three` 仍是默认；只有 `minMatch(options) >= 4` 的 optimal parser 使用
  `.four`；
- 3-byte-only 候选无法通过 `matchLength >= minimum`，跳过它们不改变可接受
  匹配集合；
- chain 预算现在只被 4-byte 候选消耗，可能走得更深；实测 q11 尺寸反而
  减小 2 字节；
- `eligible`（<=64 KiB）路径本来就使用 four-chain，未受影响。

## 证据

- `base-r1..3.csv` / `new-r1..3.csv`：q11 dickens 三轮 `--iterations 2`；
- `summary.csv`：字节差、`vort_ns` 与 ns speedup；
- `run-br-optimal-search-probe` 输出（见上表）；
- `zig build test-br` 与 `zig build test`：见提交说明。

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
