# Zstd level 3 current position (2026-11-18)

## 结论

当前源码（`e682da2b`）在 128 KiB Silesia 前缀、`--level 3` 下对系统
libzstd 1.4.8 的完整位置。默认级别是 1（已是 speed-first），level 3
是显式质量阶梯，保留既有的多候选 block-size 仲裁。

| case | vort bytes | ref bytes | 体积比 | Vort MiB/s | ref MiB/s | 速度比 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| dickens | 50,404 | 51,934 | 0.971 | 5.09 | 170.5 | 0.030x |
| mozilla | 22,914 | 21,338 | 1.074 | 6.41 | 504.1 | 0.013x |
| nci | 10,401 | 11,264 | 0.923 | 2.18 | 872.3 | 0.003x |
| samba | 47,596 | 50,611 | 0.940 | 6.94 | 223.4 | 0.031x |
| xml | 9,712 | 11,921 | 0.815 | 9.06 | 860.5 | 0.011x |
| **合计** | **141,027** | **147,068** | **0.9589** | — | — | — |

## 解读

- level 3 的比率总体好 4.1%，但代价是 32–399x 的吞吐差距；mozilla 上
  同时更大（+7.4%）且慢 78x，是该档位最差的行。
- 这不是新的回归：2026-10-25 的首轮基线（`d4297483`）记录过更慢的
  level-3 行（部分达数十秒），之后的混合搜索移除与串行化已改善吞吐。
  本表刷新了当前源码的位置。
- 默认级别是 1，且 levels 1–2 已由用户明确选择对齐 industry speed-first
  preset；level 3+ 保持质量阶梯是既有产品决定。若要把 level 3 也对齐为
  速度优先，需要用户重新确认比率/速度取舍。

## 环境与命令

- CPU：Intel Core i7-10700K @ 3.80 GHz（`skylake+pku+sgx`）
- Zig 0.16.0，ReleaseFast，单线程
- libzstd 1.4.8（系统 `libzstd.so.1`）
- 每行 `--iterations 3 --rounds 3`

```sh
zig build run-zstd-encode-bench -- \
  --path <silesia-file> --limit 131072 --level 3 \
  --iterations 3 --rounds 3 --csv <out.csv>
```
