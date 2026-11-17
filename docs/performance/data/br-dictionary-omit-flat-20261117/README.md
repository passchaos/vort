# Brotli static-dictionary omit-path flat tables (2026-11-17)

## 结论

RFC 7932 的 18 个 omit/skip 变换全部满足 `prefix_len == 0`、`case_kind ==
none`。旧实现每个候选词对每个 omit 变换调用 `transformedWordMatches`：
重复加载 spec/metadata、检查空前缀、做一次大小写分支，并为 9 个
omit-last 变换分别比较 base 字节。

现在编译期把 omit 变换拆成 omit-last / omit-first 两张扁平表；在
prefix-zero 探针里：

- omit-last：一次公共前缀扫描 `common` 取代 9 次独立 base 比较，
  逐变换只做 `output_len` 边界、`common >= kept`、后缀和 best 更新；
- omit-first：按各自 skip 做一次直接字节比较；
- 后缀比较改用 `suffixBytesMatch`，不再构造 metadata。

128 KiB q11 三轮中位数（baseline 为 sparse-view 提交 `d53ea5bf`）：

| case | baseline ns | flat omit ns | 速度 | wire |
| --- | ---: | ---: | ---: | ---: |
| dickens | 1,010,341,333 | 890,502,371 | **1.1346x** | 43,953 B 不变 |
| webster | 891,494,225 | 833,311,880 | 1.0698x | 36,107 B 不变 |
| samba | 1,382,950,491 | 1,324,886,101 | 1.0438x | 40,937 B 不变 |
| xml | 718,030,154 | 698,897,135 | 1.0274x | 8,401 B 不变 |

四语料几何平均 **1.0686x**；q9/q10 不变（q10 不走该字典预计算路径）。

## 为什么安全

- omit-last 的 base 比较是 `word[0..kept]` 对 `input[0..kept]`；
  `common` 是同一对字节的最长公共前缀，因此“匹配”严格等价于
  `common >= kept`。`output_len <= input.len` 先检查，保证
  `kept <= min(word.len, input.len)`，扫描范围覆盖 `kept`。
- omit-first 的 `skip = min(metadata.omit_first, word.len)`、
  `kept = word.len - skip`，与旧 `transformedWordMatches` 完全一致；
  `kept == 0` 时为空比较。
- 所有 omit 变换的 `output_len < 4` 过滤保留；best 选择仍是
  `(output_len 最大, address 最小)` 全序，遍历顺序不影响结果。
- 旧的 `transformedWordMatches` 仍是 `CompleteIndex` 与测试的通用 oracle，
  新路径与其语义逐条对应。
- 6 个 Silesia 语料 × q10/q11 共 12 个用例的 wire sha256 与改动前相同。
- `run-br-complete-dictionary-bench`（indexed vs reference 差分）通过。

## 测试

- 扩展 `static dictionary transform groups partition every RFC transform`：
  whole 组 + omit-last/omit-first 扁平表覆盖全部 121 个变换，且表字段与
  `transformMetadata` 一致。
- `zig build test-br -Dbr-test-filter="static dictionary"`：139/139 pass。
- `zig build test`：5662 pass，2 skip（5664 total）。
- `zig build test-br`：1622 pass，1 skip（1623 total）。
- `zig build check check-wasm`：392/392 steps，7377/7380 tests（3 skipped）。

## 证据

- 计时来自 `run-br-planned-encode-bench` 的 `vort_ns`（2 iterations），
  每个配置 3 次（xml/webster 2 次）运行取中位数；
- wire 身份来自 `--samples-json` 的 `vort_sha256`。

## 环境与命令

- CPU：Intel Core i7-10700K @ 3.80 GHz（`skylake+pku+sgx`）
- Zig 0.16.0，ReleaseFast，单线程

```sh
zig build run-br-planned-encode-bench -- \
  --path <silesia-file> --limit 131072 \
  --planned-quality 11 --quality 11 --iterations 2
```
