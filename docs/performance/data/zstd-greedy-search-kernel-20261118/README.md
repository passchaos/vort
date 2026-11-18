# Zstd greedy search kernel speedup (2026-11-18)

## 结论

在不改变任何 wire 字节的前提下，优化 controlled greedy/lazy/optimal 的匹配
搜索内核，使默认 level 3（controlled greedy）在 12 文件 128 KiB Silesia
前缀上取得 **1.152x 几何平均加速**（最小 1.046x，最大 1.217x）。完整文件
上 dickens 1.187x、xml 1.135x。所有 12 个前缀样本与两个完整文件的
`vort_bytes` 逐字节一致。

## 改动

基线：`c1d2de34`。全部改动位于 `src/zstd/match/controlled_search.zig`：

1. **SIMD 失配定位**：`matchAt` 用 `@bitCast(u32, left != right)` + `@ctz`
   替代 `std.simd.firstTrue`。后者在 Zig 0.16 会展开为 iota/blend/min
   归约（约 15 条 SIMD 指令）；前者在 x86-64 直接生成
   `vpcmpeqb/vpmovmskb/tzcnt`，且语义相同。
2. **短匹配前置字比较**：在进入 32 字节向量循环前，先以两个 `u64` 比较
   前 8/16 字节。哈希候选绝大多数在 3–16 字节内失配，因此避免了宽加载与
   循环簿记。
3. **候选价格缓存**：`findBest` 只在 incumbent 改变时计算一次
   `sequencePrice`，等长候选不再重复计算双方价格；tie-break 规则不变。
4. **无前缀快速路径**：`Cursor.init` 在 `prefixLen == 0`（单块/无字典、
   无历史）时跳过前缀哈希查找。

## Profile 证据

dickens 128 KiB，level 3，`perf record -F 999 -g`：

| symbol | before | after |
| --- | ---: | ---: |
| `controlled_search.matchAt` | 40.1% | 29.0% |
| `controlled_search.findBest` | 16.5% | 29.8% |
| `controlled_search.better` | 10.8% | 0（已内联/消除） |
| `controlled_search.planReuse` | 5.3% | 7.1% |

原始报告见 `perf-before.txt` / `perf-after.txt`（同目录）。

## 12 文件前缀结果（128 KiB，level 3）

交错 A/B，每侧 3 个进程 × `--iterations 3`，取中位数；`before` 为
`c1d2de34` 构建，`after` 为当前源码。原始 CSV 在 `prefix-ab/`。

| case | before ms | after ms | speedup | bytes |
| --- | ---: | ---: | ---: | ---: |
| dickens | 36.102 | 30.439 | 1.186x | 51,971 |
| mozilla | 10.918 | 9.745 | 1.120x | 20,112 |
| mr | 29.095 | 23.914 | 1.217x | 32,663 |
| nci | 9.451 | 8.827 | 1.071x | 11,033 |
| ooffice | 28.806 | 24.195 | 1.191x | 68,503 |
| osdb | 18.785 | 16.284 | 1.154x | 51,095 |
| reymont | 29.141 | 24.892 | 1.171x | 39,168 |
| samba | 21.506 | 18.747 | 1.147x | 48,697 |
| sao | 32.379 | 27.337 | 1.184x | 99,490 |
| webster | 26.000 | 22.590 | 1.151x | 43,073 |
| xml | 7.509 | 7.176 | 1.046x | 10,748 |
| x-ray | 34.226 | 28.424 | 1.204x | 93,086 |

几何平均 **1.152x**；所有行的 wire 字节完全相同。

## 完整文件结果

`--limit 33554432`，每侧 3 个进程 × `--iterations 1`，取中位数；原始 CSV 在
`full-file/`。

| case | input bytes | before ms | after ms | speedup | bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| dickens | 10,192,446 | 1232.0 | 1038.0 | 1.187x | 4,054,523 |
| xml | 5,345,280 | 200.2 | 176.3 | 1.135x | 675,079 |

## 非目标级别对照

L1（legacy fast）与 L9/L22（HQ）不经过该搜索内核；交错 A/B 显示均在噪声
范围内：L1 xml 5×10 次迭代 1.002x，L9 xml 0.998x，L22 xml 0.999x，均高于
0.98x 控制下限。原始 CSV 在 `controls/`。

## 搜索计数（dickens 128 KiB，level 3）

CLI `--strategy=greedy --level=3 --profile`：

- `positions=24165`，`candidate_checks=752755`（平均约 31.1 次/位置），
  `short_hash_probes=680278`，`rep_probes=72477`，`parser_matches=21018`，
  `parser_matched_bytes=127923`。
- 搜索预算 64 并未饱和；把预算减半预计只能削减少量探针，收益有限。

## 已排除：packed match 返回

把 `matchAt` 的 16 字节 `Match` 返回值改为 `u64`（length<<32|distance）以消除
隐藏 sret 指针，在 12 文件前缀上为 **0.988x 几何平均**（min 0.969x，
max 1.005x），是明确回归，已回退；回退后二进制与优化版逐字节一致。

## 已排除：4 字节哈希与混合链

把搜索哈希从 3 字节改为 4 字节（12 文件前缀，3 对交错 A/B）：

- **4 字节哈希**：速度 **1.199x** 几何平均，体积比几何平均 **0.9908**
  （nci 0.9409、dickens 0.9772 等更小；mozilla 1.0093、samba 1.0006、
  **x-ray 1.0678** 更大）。x-ray 的 +6.8% 二进制比率回退超出默认预算，
  未采纳。
- **4 字节 + 3 字节回退（2 探针）**：速度 0.979x，体积比 0.9950；
  回退探针在文本块上过频，净回归。
- **4 字节 + 3 字节回退（仅在无 4 字节匹配时 1 探针）**：速度 1.011x，
  体积比 0.9953（x-ray 1.0075）；低于 3% 门槛，未采纳。

三种变体均已回退，当前源码仍为 3 字节哈希；回退后二进制与优化版逐字节
一致。若未来要换取 1.2x 速度，需要用户明确接受 x-ray 级二进制比率回退，
并同步重冻 golden/gate。

## 验证

- `zig build test-zstd --summary all`：5/5 steps，1430/1430 tests 通过。
- `zig build run-zstd-encode-bench-gate`：ok（20 rows，libzstd 1.4.8）。
- 12 文件前缀与 2 个完整文件的 `vort_bytes` 与基线逐字节一致。
- `zig build -j2 test check check-wasm --summary all`：389/389 steps，
  5756/5758 tests 通过（2 skipped）；`test` 步骤 5663 pass / 2 skip。
- 首次全门中 `check-zstd-source-reverse` 的 node WASI 门出现过一次偶发非零
  退出；对同一 wasm 产物单独重跑 43/43 通过（`status:"ok"`，exit=0）。

## 环境与命令

- CPU：Intel Core i7-10700K @ 3.80 GHz（`skylake+pku+sgx`）
- Zig 0.16.0，ReleaseFast，单线程
- libzstd 1.4.8（系统 `libzstd.so.1`）
- 基线二进制 sha256：`fbf0727618c69e5c9c166d76ff38446e2b8c3f9ba7959b87dc291e0804d6b856`
- 优化二进制 sha256：`d5a0013b858fc3e8ec4564d5d219f6869b34526af509987dcd98c7841bc35f9c`

```sh
# 128 KiB 前缀
<bench> --path <silesia-file> --limit 131072 --level 3 \
  --iterations 3 --rounds 1 --csv <out.csv>
# 完整文件
<bench> --path <silesia-file> --limit 33554432 --level 3 \
  --iterations 1 --rounds 1 --csv <out.csv>
```
