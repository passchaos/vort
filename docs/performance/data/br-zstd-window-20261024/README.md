# Brotli/Zstd窗口与资源契约证据（2026-10-24）

这是功能验证档案。各阶段结果保留自己的源码、实际编译输入和产物身份；
较早通过的产物不会被冒称为随后源码的执行结果。原失败记录和必要修复阶段
保留，预期错误与参考库能力限制不计作成功往返。

`index.json`列出每个原始文本文件的相对路径、大小和SHA-256，以及对应
确定性tar.gz包的SHA-256。包内保留原始JSON、命令、日志、源码哈希和
实际编译输入索引；顶层JSON提供主要阶段的快速入口。原始日志中的绝对
路径来自执行机器。大型原始输入、wire、源码ZIP与ELF/Wasm未重复加入Git，
其身份与本地路径由原报告保存；生成和执行工具作为仓库源码提交。

| 证据组 | 范围 |
| --- | --- |
| brotli-native | Debug、ReleaseFast和真实32位x86专项，独立旧默认wire |
| brotli-family | 初次旧HQ-only测试失败及必要修正后的完整1274项家族 |
| brotli-reference-final | 76组、原10份baseline、普通/实验/系统参考能力与实际输入绑定 |
| brotli-cli | 早期35参考往返的CLI阶段，与其当时的编译输入 |
| zstd-native / zstd-portability | 55项专项、原32位编译/运行失败及必要宽度修复 |
| zstd-family | 原952/954失败及Source检查/合法窗口候选修复后的954/954 |
| zstd-reference-preliminary | 工具准备和早期功能阶段 |
| zstd-reference-final | 真实D=64MiB+8五操作、独立wire读数、两版参考解码及当前小型重绑定 |
| zstd-cli及后续修正组 | single-segment头、系统参考窗口上限与最终CLI验收分阶段记录 |
| window-wasm | 原对齐失败及portable wrapper修复后的真实公共API执行 |
| integration | 全局构建/CLI help、源码快照和rebase后相关复验 |

全局156/156通过来自标准Debug检查；原额外全库ReleaseFast构建结束时的
SIGTERM和取消上下文保留，不能算作通过。两库完整ReleaseFast行为家族和
跨平台专项使用各自的实际产物与记录。早期宽快照中的CLI gate修复及生成
Python bytecode变化不属于Zig编译输入，标准Debug收尾源码快照无变化。

广告窗口、配置历史上限、实际保留字节和requested heap是不同指标。
这里的请求堆排除借用输入、caller output、allocator bookkeeping及不可观察
OS开销；功能执行耗时不是吞吐benchmark，本文档不提供行业最佳结论。
