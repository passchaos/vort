# Brotli 通用 Large Window 功能基线（2026-10-24）

本轮将显式 Large Window 编码从 HQ q10/q11 扩展到 q0...q11、legacy 三档与
stored 的单次、chunks、reusable、incremental 和 metadata 入口。
`large_window = false` 保持旧窗口合法性、默认政策和 wire。
完整格式与匹配边界见 [格式说明](../formats/brotli-general-large-window.md)。

这是功能和输出安全增量，不提供行业最佳压缩率、吞吐或 RSS 结论。
q0/q1 仍使用 fragment-local 匹配；一般非 HQ 保留不超过 65535 字节的历史。
ratio 的既有 input/history 可达远距候选保留，引用距离可能大于 retained-history
长度，但不等同于搜索完整 1 GiB 窗口。未指定窗口的 legacy ratio 仍保留自动
17 位候选，并在实际 wire 中保留 Large Window 身份。

## 已完成的独立验证

| 范围 | 结果 | 证据含义 |
| --- | --- | --- |
| 正式 Debug | 37 通过、1 跳过，38 总项 | 唯一跳过项是只对 32 位地址空间运行的数值边界 |
| 正式 ReleaseFast | 37 通过、1 跳过，38 总项 | 与 Debug 同一实际测试集合 |
| 正式 x86-linux-musl ReleaseFast | 38/38 | 数值边界在真实 32 位执行中补齐 |
| 实际 ELF TestFn | 21 named、17 imports | 其中独立 QA15、核心6，不能把导入项当新增行为测试 |
| 独立旧默认 wire | 41 rows | 来源 `fa35a843` 的独立源码归档；质量/模式/legacy/stored 对照 |
| 原总内存回归 | 46/46 | legacy/q/HQ 配额、alias/moving/OOM 与 live 清理 |
| 标准距离参数回归 | 26/26 | standard 格式的既有评分保持 |
| 旧 q0/q1 窄回归 | 21/21 | 原 fast fragment 编码路径保持 |

正式原始目录为 `/tmp/vort-br-zstd-window-final-20261024-qnq4udcc/brotli-native/`。
实际编译 argv、TestFn、二进制与编译缓存内容分别核对。三组实际编译输入
没有变化；宽仓库快照中的 Zstd 在途修改不是这些 Brotli codec 测试的输入，
原始差异和实际编译投影分别记录。

CLI 阶段的小矩阵已通过 35 项参考往返、27 项扩展身份、10 项非 HQ、
10 项 profile 字节一致、33 项 metadata、两项默认格式、精确/低一预算各两项、
18 项输出保护和 4 项同路径操作；parser 测试 18 项通过。其实际编译输入包含
当时的 Zstd 文件，阶段记录没有冒充最终整个仓库冻结。最终产物绑定与复验
另行记录，不能把不相同的编译阶段拼成一个不变窗口。

## 输出与别名修复

独立 QA 捕获 Large Window q4 chunks 的 prepared alphabet 未初始化：重复
距离优化原来只初始化 standard79，而 large544 仍读取结果。chooser 已按真实
format capacity 泛化，候选拒绝和接受都初始化对应输出，保留该优化。

General reusable 在清空输出之前保存借用的 chunks 外层描述符、source bytes、
共享字典描述符和 metadata。别名路径使用临时 codec，避免 retained matcher
缓存指向临时字典视图。Stored reusable 同样在 clear、reserve 和写头之前保存
借用数据。独立移动/毒化分配器与 caller-output/OOM 回归已验证。

## Serialized 参考能力

普通 pinned Brotli 1.2.0 构建关闭 `BROTLI_EXPERIMENTAL`，实际 attach 在读取
payload 前拒绝 SERIALIZED 类型；helper 没有预挡。系统 1.0.9 不提供该 API。
这两个边界与有效 descriptor 的解析失败分开记录。

同一 pinned1.2 源码在独立临时目录启用实验 parser 后，原 70 字节字典真实
attach 成功。一个非 HQ q11/window25 单例实际产生两次 shared dictionary copy，
Vort wire 被实验参考解码，参考编码又被 Vort 解码。字典和头部未被移除；
原字典字节与准备阶段一致。普通全场景和这项实验验证的来源分别记录。

## 完整家族和版本化参考验证

最终 Brotli ReleaseFast 家族为 **1273 通过、1 跳过、0 失败，共 1274 项**。
唯一跳过的既有32位数值测试已由 x86 专项实际执行补齐。初次家族中旧
HQ-only negative test 对三项现已合法配置错误期待 `InvalidBlockPlan`；修正后
改验真实 OOM、扩展身份、严格拒绝和 opt-in 解码，非法窗口测试仍保留。
原失败证据与最终通过记录分阶段归档。

正式参考活动共 **76 组**（普通75组＋实验serialized单例），唯一运行退出码0。
391 次实际调用中316成功，75次预期错误均保持输出；150个双向参考结果通过。
普通1.2.0、系统1.0.9及实验1.2.0的能力边界独立记录，三个已知参考能力跳过
没有冒充通过。10份原回归baseline不重生成；独立QA另有41份旧wire。
planned总请求堆峰值689113字节，exact、B−1和零预算检查通过。

[永久证据目录](data/br-zstd-window-20261024/)保留原始结果、命令、日志、
源码哈希和实际编译输入索引。原正式汇总SHA-256为
`7f4b412a977b9c9ecce57f2da72c3981460bfd5d33cf6b48211de9f008915a47`。
其1795个源码文件前后相同，1942条实际编译输入与最终RF probe完整绑定。
最终CLI和全局构建收尾结果在[共同验收记录](br-zstd-window-verification-20261024.md)
中另列，不与较早阶段混为同一产物。
