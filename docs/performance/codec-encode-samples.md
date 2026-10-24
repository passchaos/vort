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
