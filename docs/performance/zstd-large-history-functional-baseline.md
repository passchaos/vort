# Zstd 大历史与编码总堆预算功能基线（2026-10-24）

本轮从 `fa35a843` 的64 MiB固定历史上限扩展到共享的checked坐标上限
**4,294,836,222字节**，并为公开one-shot、reusable、incremental、dictionary、
level和seekable编码入口增加 `max_total_working_memory` 与
`EncodeMemoryProfile`。共享分配器位于通用I/O模块，Zstd使用薄适配层。
[API与资源契约](../formats/zstd-large-history-memory.md)说明实际匹配策略、
所有权转移和排除项。

这是功能、安全和资源控制增量。配置最大值、格式窗口41、内部work counter
以及功能验证耗时都不能证明行业最佳压缩率、吞吐或RSS。

## 实际超过64 MiB的匹配

唯一生成的输入长度为67,110,920字节，重复anchor的距离
`D = 67,108,872 = 64 MiB + 8`；显式窗口27为128 MiB。
独立wire读取确认最终序列 `LL=0 / ML=2048 / OF extra bits=26 / extra=11`。
前缀的511个Huffman纯字面量块和2个raw块均按真实块形状校验。
libzstd 1.6.0（本地 `01b7154f`）及系统1.4.8独立解码完整流到原始输入。

| 公共操作 | 实际最大引用距离 | 请求堆峰值 | 最终live |
| --- | ---: | ---: | ---: |
| incremental fast | 67,108,872 | 97,323,001 B | 0 |
| 同输入exact总预算fast | 67,108,872 | 97,323,001 B | 0 |
| history D−1 fast | 0 | 97,323,001 B | 0 |
| incremental double_fast | 67,108,872 | 97,323,001 B | 0 |
| 大RAW字典＋2048B输入 | 67,108,872 | 11,015 B | 0 |

fast、double_fast和exact的完整wire相同。D−1对照实际从绝对位置1保留历史，
没有发出禁止引用。字典路线借用D字节字典并生成19B wire，两版参考真正
load字典后解出2048B。输入只生成一次，成功fast初始编码只执行一次；
后续复用已保存结果。工具EOF包含边界与前缀形状假设的失败证据原样保留。

正式参考报告另有7份独立旧wire及14组小门禁、42次调用：31成功、
6次预期 `WorkingMemoryLimitExceeded`、5次预期 `InvalidBlockPlan`。
正式汇总SHA-256为
`108eb03f7224a4eb4713d899d743775a1e10a02f4f07aac1a46117dd81fcf306`。
1941个实际编译输入与2个递归对象绑定到当时公共probe。此后必要Source
检查顺序修复只调整错误输入的分类；当前产物小型重绑定单独记录。
当前probe重编后14组与7份旧wire仍通过；当前decoder实际解码保存的
fast/double/exact三个67,110,920字节流和2048字节字典流，均与原输入一致。
当前重绑定汇总SHA-256为
`35f04c5e8d64d3c83426628d8be758b60888436175733678d8aca1178ca8d90e`。
该阶段未重新执行大输入编码或生成输入，不将旧Far冒称为全新源码不变运行。

## 独立契约与平台验证

独立QA17项覆盖窗口/有效历史、fast/lazy/HQ、字典、真实请求峰值、exact/B−1/0、
OOM释放、旧wire、别名、输出/状态回滚、retained容量和nextFrame。
共享预算另有真实并发admission与sticky拒绝分类测试；总预算helpers、
增量生命周期和frame publication分别验证。

Debug、ReleaseFast专项均 **55/55通过**（42 named、13 module entries）。
初次32位编译的5处宽度错误与随后真实位流运行修复分阶段保留；最终
x86-linux-musl ReleaseFast专项 **55/55通过**。reverse writer使用明确u64状态，
跨31/32位和完整字宽边界的独立位流oracle保留。

真实WebAssembly公共API完成4次往返。Zstd小输入在32位Wasm中保留
2,199,023,255,552字节广告窗口，effective history为128 MiB，实际请求堆峰值
1496 B、live=0；raw/RLE路线实际history=0、峰值1574 B、live=0。
原native对齐wrapper保持64/256对齐，portable wrapper省略目标不支持的
函数对齐。此报告不把小输入的合法大窗口配置当成大距离匹配证据。

初次完整Zstd家族952/954通过，两个失败分别为checked长度溢出错误的优先级
和旧测试手造prefix大于窗口的非法Source。修复先由纯长度证明prefix+block
可表示，再验证geometry，最后形成suffix；窗口候选测试改为合法Source并
继续实际验证window外候选拒绝、相同候选在较大窗口被接受及预算约束。
两项具名回归在Debug、ReleaseFast和32位x86各10/10执行通过（含导入项）。
唯一必要完整家族ReleaseFast复验为 **954/954通过**、5/5构建步骤成功，
实际源码输入前后无变化。原952/954失败产物、错误名字和编译绑定保留。
CLI/全局检查结果在[共同验收记录](br-zstd-window-verification-20261024.md)中记录。

[永久证据目录](data/br-zstd-window-20261024/)保留阶段结果、命令、日志、
源码哈希、输入索引及失败证据。统计requested heap排除借用input/dictionary、
caller output、固定当前线程stack、allocator bookkeeping和不可观察OS开销。

## 仍需完成

32位累计编码字节、pledge和绝对history坐标仍为usize，应作为下一独立功能片。
局部u32匹配坐标的合法最大值不代表支持任意2 TiB引用或无限长度流。
HQ有限8/16状态、native priors、4096位置horizon和长度采样仍是算法边界；
全竞品ratio/encode/decode/requested-heap/RSS矩阵和字典finalization性能仍未达标。
