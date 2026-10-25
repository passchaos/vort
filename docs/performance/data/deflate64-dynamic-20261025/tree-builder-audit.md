# 动态 literal incomplete 报错的只读核查

结论：此次报错来自外部 Python 解析器的 HCLEN 顺序错误；生产 histogram/tree builder 不需要修改。核查没有修改源码或工具文件，没有运行 probe、编译、编码、计时或 Git。

读取 `/tmp/vort-deflate64-dynamic-20261025/native/manifest.json` 及已生成 raw 文件。工具当时的 code-length order 后半段为 `...,11,4,3,12,2,13,1,14,15`；RFC、生产 writer、Deflate64 decoder 和核心测试均使用 `...,11,4,12,3,13,2,14,1,15`。错误顺序会交换 code-length 符号的长度分配，而保持 code-length 长度集合本身的空间；随后 RLE 误解码产生错误 literal 长度，触发 incomplete。

只在 Python 内存中的函数副本替换这一个 order 常量，保持原 strict Huffman/RLE/header/payload/content 解析和所有断言。对 manifest 中全部40个 `.raw` artifact 核验文件 SHA256，读取独立 input 文件，并运行只读 strict inspect：**40/40通过**。

| 真实 artifact | dynamic literal active | literal max bits | 严格结果 |
| --- | ---: | ---: | --- |
| empty-dynamic-mixed.raw | 2 | 1 | 完整树、内容和位消费通过 |
| binary-dynamic-mixed.raw | 258 | 10 | 完整树、内容和位消费通过 |
| long_distance-one-shot.raw | 259 | 11 | 完整树、内容和位消费通过 |
| long_distance-dynamic-mixed.raw | 259 | 11 | 完整树、内容和位消费通过 |
| long_distance-adaptive-mixed.raw | 259 | 11 | 完整树、内容和位消费通过 |
| multi_block-dynamic-mixed.raw | 26 / 2 / 2 | 6 / 1 / 1 | 三个块均通过 |

其余34个raw文件也通过同一严格解析。此次只读结果验证已有 artifact 的实际树和输出，没有推论所有可能 histogram 均已穷举，也没有替代父任务的完整80-artifact ZIP/UnZip验证。

核查后四个 owned 源码 SHA256 保持：

```text
stream_blocks.zig b7ad207a82bf20c09fea458bff941ef3de55685842aae6275aab40bfbb8f47cb
dynamic.zig       bca8151e8c667eea3a35779b5e08685ee90348bfb3b5e81c92fef3ded8467800
dynamic_tests.zig 45990da7791c10e2f19ec7f6fd4b063a8fab28beb17a9a8143f6657fd71b1c41
codes.zig         c73d37205bb69c0f4c67b7a447d4e364935abdccdefd6c89616a0f9ba2f961b5
```

工具负责人已定位首个失败为空动态块，并获授权修复 HCLEN order 与增加独立 RFC golden 校验。生产树补全、真实频率和匹配预算保持原样。
