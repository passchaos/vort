# 编码基准原始样本与身份记录

Brotli 与 Zstd 编码工具的 CSV 继续报告各实现多轮中的最小耗时。
`--samples-json FILE` 另存每一轮实际耗时，供复算中位数、检查交替顺序，
以及核对输入和参考文件身份。这项工具增量本身不提供新的性能排名。

样本报告使用 `schema=vort.codec_encode_samples`、`version=1`。每行记录
实际输入长度和 SHA-256、迭代次数、编码设置、预先生成的两份 wire 的长度
与哈希、原始轮次和最小值／中位数。偶数轮中位数为两个中间值平均后向下
取整。报告生成、文件哈希和摘要计算均在编码计时区间外。

参考库记录只证明显式提供的文件与当前文件哈希一致。动态加载器可能解析
其他依赖，报告用 `loaded_identity=null` 与 `dependencies_verified=false`
保留这一边界。未显式提供路径时，文件路径和哈希为未知；运行时版本号
不能代替完整的库身份。Brotli 三个显式库参数必须同时提供，使用同一套
encoder、decoder 与 common 文件。

以下命令中的路径均需由调用者替换。先完成构建，再直接执行生成的基准
程序；计时期间应避免竞争构建。首轮可取相同的 64 KiB 输入，分别比较
Brotli q8 与 Zstd level 3。相同级别编号是产品策略比较，不证明两库内部
搜索算法和有效窗口相同；设置与实际 wire 信息必须保留。

Brotli 的 `vort_window_bits=null` 表示公开默认窗口，另用
`vort_default_window_bits` 记录其默认值。command-state 值 255 是保留质量
策略的 sentinel，不能解释为 255 KiB 的实际搜索范围；q10/q11 当前默认
上限为 8 KiB。`vort_hq_enabled` 描述显式 HQ 选项是否启用，不替代质量
策略内部规划的说明。Zstd 的 `resolved_primary` 仅描述公开级别解析器的
主配置，自动策略还会仲裁其他候选；报告保留这一范围及实际帧头。

```sh
vort-br-planned-encode-bench --path INPUT --limit 65536 --iterations 1 \
  --planned-quality 8 --quality 8 --planned-mode generic \
  --libbrotli-encoder ENCODER --libbrotli-decoder DECODER --libbrotli-common COMMON \
  --csv RESULT.csv --samples-json RESULT.json

vort-zstd-encode-bench --path INPUT --limit 65536 --iterations 1 --rounds 5 \
  --level 3 --libzstd LIBRARY --csv RESULT.csv --samples-json RESULT.json
```

独立校验器接受冻结输入 manifest 的 `input_sets` 数组；每个条目至少包含
`frozen_path`、`input_bytes` 与 `input_sha256`。它重新读取文件验证身份，
核对全部轮次、wire 长度与迭代校验和、最小值与中位数、CSV 和可执行文件。

```sh
python3 tools/codec_bench/sample_gate.py --samples-json RESULT.json \
  --manifest MANIFEST.json --csv RESULT.csv --executable EXECUTABLE \
  --require-explicit-references
```

校验器不设吞吐胜负门槛，不会把通过验证解释为性能领先。压缩率／吞吐
比较还需保留源码版本、CPU、编译模式、完整命令和安静测量记录。此报告
未测 requested heap、RSS 或硬件冷缓存；这些指标需要独立的资源与生命周期
测量，混合运行双方的进程 RSS 不能分别归因给某个实现。

## 功能验证（2026-10-25）

| 范围 | 已执行结果 |
| --- | --- |
| Brotli 辅助与参数测试 | native Debug、实际 x86 ReleaseFast 各 10/10 |
| Zstd 辅助测试 | native Debug、实际 x86 ReleaseFast 各 3/3 |
| 完整原生工具 | 两个 ReleaseFast benchmark 实际编译成功；Zstd help 列全 11 种策略 |
| 计时前 CLI 拒绝 | Brotli 缺库组件及三种输出冲突、Zstd 六种参数／路径错误均符合预期；输出 sentinel 保持 |
| 独立校验器 | 六项测试覆盖缺轮次、错误顺序、摘要、有效设置、身份变化和 CSV 错配；普通及 Python `-O` 模式通过 |
| 实际 JSON／CSV | 同一 50B 完整 synthetic JSON 输入，Brotli q0 五轮、Zstd level3 四轮，均通过输入／wire／每轮 mix／摘要／CSV／可执行文件／显式参考文件身份核对 |

上述小输入运行用于验证报告格式及跨库输出正确性。运行期间可能有竞争
构建，因此不把其耗时列为当前性能证据。Brotli 保留参考解码器读取 Vort
编码结果的原验证，Zstd 保留两种解码器检查双方 wire 的原验证。

[证据索引](data/codec-encode-samples-20261025/index.json)保存命令、完整日志、
源码前后 SHA、产物和实际小输入报告。Brotli 最初一个测试常量的 wrapping
乘法需要显式 `usize` 类型，首次失败和修正后验证均保留。两份成功工具的
计时算法未因该测试常量修正而变化。
[输入 manifest](data/codec-encode-samples-20261025/manifest.json)冻结 40 份准备
输入的实际长度和 SHA；这些输入尚未完成正式竞品计时矩阵。

[实际编译输入绑定](data/codec-encode-samples-20261025/compiled-binding.json)将
Brotli 的 2,011 条、Zstd 的 2,009 条缓存输入记录，以及两份共用链接对象
的 549/551 条记录，逐项核对大小、SipHash 和派生产物目录。所有输入无
缺失或不匹配，两个 ELF 的 SHA 与实跑 JSON 相同。1,200 份实际项目及
crypto 源码已归档，精确对应 `30611d7e`；标准库内容核对后未重复打包。
这是缓存所用源码和实际产物的绑定，不推断原始运行期间存在完整目录的
连续快照，也不验证动态加载器的依赖闭包。

整合 gzip 修复与工具提交后，`git pull --rebase origin main`确认无需冲突
处理。[最终整合记录](data/codec-encode-samples-20261025/final-integration.json)
保留该源码epoch的新工具构建、两种codec的显式参考库tiny JSON/CSV门禁、
Brotli默认库加载门禁和native/x86各11/11 gzip回归。42个改动Zig文件格式
检查通过。旧`30611d7e`产物与源码绑定保留为原阶段证据，新整合记录另列，
不把旧artifact冒称为合并后可执行文件，也不把tiny耗时作为性能排名。
