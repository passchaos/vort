# Brotli q11 full-corpus position (2026-11-18)

## 结论

当前源码（`edcdf4c5`）在 128 KiB Silesia 前缀、`--planned-quality 11
--quality 11` 下对 libbrotli 1.0.9 的完整位置。默认参考使用 lgwin 22；
匹配参数行额外使用 `--reference-lgwin 16 --reference-mode generic`，
此时 `parameters_match=true`。

默认参考（lgwin 22，12 文件，`--iterations 1`）：

| case | vort bytes | ref bytes | 体积比 | 速度（ref/vort） |
| --- | ---: | ---: | ---: | ---: |
| dickens | 43,953 | 42,949 | 1.023 | 0.315x |
| mozilla | 18,676 | 16,232 | 1.151 | 0.160x |
| mr | 30,036 | 27,038 | 1.111 | 0.207x |
| nci | 8,859 | 7,755 | 1.142 | 0.277x |
| ooffice | 64,634 | 61,188 | 1.056 | 0.431x |
| osdb | 46,778 | 44,749 | 1.045 | 0.257x |
| reymont | 33,363 | 32,202 | 1.036 | 0.293x |
| samba | 40,937 | 38,962 | 1.051 | 0.205x |
| sao | 92,145 | 88,108 | 1.046 | 0.219x |
| webster | 36,107 | 35,164 | 1.027 | 0.321x |
| x-ray | 77,220 | 73,006 | 1.058 | 0.516x |
| xml | 8,401 | 7,441 | 1.129 | 0.364x |
| **合计** | **501,109** | **474,794** | **1.0554** | — |

匹配参数（lgwin 16、generic，`parameters_match=true`）：

| case | vort bytes | ref bytes | 体积比 | 速度（ref/vort） |
| --- | ---: | ---: | ---: | ---: |
| dickens | 43,953 | 43,105 | 1.020 | 0.311x |
| mozilla | 18,676 | 16,279 | 1.147 | 0.163x |
| samba | 40,937 | 38,833 | 1.054 | 0.204x |
| xml | 8,401 | 7,435 | 1.130 | 0.367x |

## 解读

- 体积弱行集中在二进制/结构化输入：mozilla 1.147、nci 1.142、xml 1.130、
  mr 1.111；文本行在 1.020–1.051。窗口匹配后弱行基本不变，说明差距来自
  解析/熵规划而非窗口。
- 速度差距 3–6x：q11 当前每 128 KiB 约 0.89 s，而 libbrotli q11 约
  0.15–0.29 s。主要成本在多次 optimal parse、每个候选组的完整 split
  候选图（约 17% 编码时间）和 static-dictionary 候选重编码（约 12%）。
- 这不是“业界最佳”的完成证据；它是当前 q11 编码位置的可复现基线，
  用于选择下一轮优化目标。

## 下一步候选

1. static-dictionary 候选：q11 对每个 parse 都通过完整 split 图重编码，
   约 12% 编码时间；先测量其胜率，再决定门控或复用。
2. split 候选图：每个候选组物化约 15 条完整 wire；评估“计数写入 + 仅物化
   胜者”或按当前全局最优剪枝。
3. 弱行（mozilla/xml/nci/mr）：检查字面量上下文模式/块类型选择是否落后于
   libbrotli 的 HQ 模型，优先从二进制/结构化输入的比率差距入手。

## 环境与命令

- CPU：Intel Core i7-10700K @ 3.80 GHz（`skylake+pku+sgx`）
- Zig 0.16.0，ReleaseFast，单线程
- libbrotli 参考版本 1,000,009（1.0.9）
- 原始 CSV：`q11-*.csv`（默认参考）、`matched-q11-*.csv`（匹配参数）

```sh
zig build run-br-planned-encode-bench -- \
  --path <silesia-file> --limit 131072 \
  --planned-quality 11 --quality 11 --iterations 1 \
  [--reference-lgwin 16 --reference-mode generic] --csv <out.csv>
```
