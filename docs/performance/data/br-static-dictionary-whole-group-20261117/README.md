# Brotli static-dictionary whole-word grouping (2026-11-17)

## 结论

q10/q11 的 optimal parse 在预计算阶段对每个输入位置调用静态字典
`Index.findLongest`。RFC 7932 的 121 个变换里有 103 个是
`keeps_whole_word`（kind 0/10/11，只改变大小写与后缀），旧实现让每个后缀
变体都重新比较一遍完整 base word：同一候选词在一次 bucket 访问中会被
`std.mem.eql`/大小写比较最多 103 次。

现在编译期把变换表按 `(prefix_len, case_kind)` 拆成 whole / omit 两组：
whole 组先对候选词做一次大小写归一化 base-word 比较，不匹配就跳过整组；
匹配后每个变换只检查前缀、后缀与长度。omit 组保留原来的逐变换路径。

128 KiB q11 三轮中位数：

| case | baseline ns | whole-group ns | 速度 | wire |
| --- | ---: | ---: | ---: | ---: |
| dickens | 1,308,173,945 | 1,214,380,116 | **1.0772x** | 43,953 B 不变 |
| xml | 849,558,991 | 837,003,499 | 1.0150x | 8,401 B 不变 |
| samba | 1,720,445,410 | 1,669,194,113 | 1.0307x | 40,937 B 不变 |

三语料几何平均 **1.0406x**；wire 字节数与 checksum 全部一致。

对照（dickens，2 次运行）：q9 103.3M -> 103.7M ns（慢 0.36%，噪声内），
q10 193.3M -> 193.6M ns（慢 0.15%，噪声内）。q9/q10 的 optimal 字典查询
次数少于 q11，收益集中在 q11。

## 为什么安全

- whole 组的比较对象与 `transformedWordMatches` 内完全一致：
  kind 0 用 `std.mem.eql`，kind 10 用 `firstUppercaseMatches`，
  kind 11 用 `allUppercaseMatches`；`transformBaseMatches` 直接复用这三个
  函数，不引入第二套语义。
- whole 变换的 `skip = 0`、`kept = word.len`，所以 base 比较与后缀无关，
  提前一次比较不会改变任何候选的接受/拒绝结果。
- 最佳匹配选择是 `(output_len 最大, address 最小)` 的全序，遍历顺序
  （whole 组先、omit 组后）不影响最终结果。
- whole 变换的 `output_len = prefix_len + word.len + suffix_len >= 4`，
  无需再过滤零长度；后缀边界检查保证 `output_len <= input.len`。
- q9/q10/q11 的完整 wire sha256 与改动前逐字节相同：
  - q9: 48,833 B `a7f47e3d33bdadb2...`
  - q10: 48,747 B `dae9a5618d89e420...`
  - q11: 43,953 B `93777456f2c7d0bc...`
- `run-br-complete-dictionary-bench`（indexed vs reference 差分）通过。

## 测试

- 新增 `static dictionary transform groups partition every RFC transform`：
  121 个变换恰好各出现在正确的 `(prefix_len, case, whole/omit)` 组一次。
- 新增 `static dictionary whole-word base comparison agrees with transformed
  matching`：103 个 whole 变换 × 采样 base word，`transformBaseMatches`
  与 `transformWord` 的实际字节一致，且 `transformedWordMatches` 返回同一
  长度。
- 扩展 `indexed static dictionary matcher agrees with exhaustive reference`：
  新增 `" the dictionary"`、`"s dictionary"`、`"dictionar"`（prefix 5、
  prefix 2、omit-last 路径）。
- `zig build test-br -Dbr-test-filter="static dictionary"`：139/139 pass。
- `zig build test`：5661 pass，2 skip（5663 total）。
- `zig build test-br`：1621 pass，1 skip（1622 total）。
- `zig build check check-wasm`：385/385 steps，86/86 tests。
- 首次聚合运行暴露了一个既有 32 位可移植性 bug（`src/br.zig` 的
  `sortDistanceFrequencies` 用 `u6` 位移计数，wasm32/x86 上 usize 为 u32），
  已单独修复为 `std.math.Log2Int(usize)`；修复后 check/check-wasm 全绿。

## 证据

- `base-dickens-r{1,2,3}.csv` / `new-dickens-r{1,2,3}.csv`：q11 dickens
  三轮 `--iterations 2`；
- `base-xml-r{1,2}.csv` / `new-xml-r{1,2}.csv`、`base-samba-r{1,2}.csv` /
  `new-samba-r{1,2}.csv`：跨语料两轮；
- `summary.csv`：字节、中位数、speedup 与 wire checksum。

## 环境与命令

- CPU：Intel Core i7-10700K @ 3.80 GHz（`skylake+pku+sgx`）
- Zig 0.16.0，ReleaseFast，单线程，未固定 CPU affinity
- libbrotli 参考版本 1,000,009（1.0.9）
- 命令：

```sh
zig build run-br-planned-encode-bench -- \
  --path <silesia-file> --limit 131072 \
  --planned-quality 11 --quality 11 --iterations 2 \
  --csv <out.csv>
```
