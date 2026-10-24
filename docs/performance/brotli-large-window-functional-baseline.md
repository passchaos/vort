# Brotli Large Window HQ 功能基线（2026-10-24）

本轮已把 Large Window 扩展接入真实 HQ 编码器、公共 API、流状态与共享堆预算。
显式 `large_window = true` 在窗口 10…30 都选择 14-bit 扩展头，窗口不超过 24
也保留该格式身份。解码器需要显式允许 Large Window。默认 `false` 保持普通格式。
本记录描述功能、兼容性与分配边界证据，不包含行业吞吐、速度、RSS 或性能排名结论。

记录时间为 2026-10-24 18:14:22（Asia/Shanghai，10:14:22 UTC）。本轮基础增量已保存于
`f2fb511e`、`9fb0ef2a`、`aa9f6c23`；wire/public 变更为 `786ae5e5`。

## 格式与状态约束

- HQ q10/q11 才能显式选择扩展；普通窗口 API 的默认策略保持稳定。
- `distance.Format` 贯穿 resolved options、Source、精确编码、parser plan、模型与 codec Context。
- 所有 64 个距离形状区分 wire 字母表与有效字母表：最高分别为 1128 与 544。
  简单 Huffman 树的符号宽度使用 wire 大小；复杂树只编码有效范围。
- 精确命令保留原始 704 命令选择、语义短距离选择器、距离前缀与附加位。
  普通距离按形状上限校验；缓存短距离别名按全局安全上限 `0x7fff_fffc` 校验。
- q11 完整候选与 q10 使用同一格式、窗口、距离形状和元数据；普通格式 legacy 候选
  不参与显式 Large Window 请求。跨块缓存、历史、树状态与发布事务保持原有语义。
- 总请求堆预算覆盖 I/O、历史、HQ、字典、matcher fork、别名和完整候选；
  工作区预算仍是单独约束。以下字节数是请求堆账本观测值。

## 正式小规模与互操作验证

| 验证 | 已确认结果 | 范围 |
| --- | --- | --- |
| 原生 Large Window 合同 | Debug、ReleaseFast、x86 各 44/44 | 每组 29 个命名测试与 15 个匿名导入检查，实际 ELF 名单及顺序一致 |
| 完整 Brotli 回归 | 1188/1188 | 完整家族测试，具体编译参数见原始记录 |
| 编译检查 | 原始 code gate 147/147，退出 0 | 包装器对脚本变化的判定见下文；永久消费入口另行复验 |
| 永久消费入口后的最终编译检查 | 149/149，退出 0 | [结果](data/brotli-large-window-20261024/final-build-check.json)，源码窗口无变化 |
| 公共 probe campaign | 131 个逻辑案例、586 次 probe 调用 | 466 次成功，120 次预期错误 |
| 扩展特性案例 | 114 个 | 42 窗口案例、64 距离形状、6 API 案例、raw 字典与空输入 |
| 旧版普通格式基线 | 9 个 | 与 `b20af85d` 的完整输出对照 |
| 参考互操作 | 227 个双向对照、227 个严格解码拒绝 | 系统参考的 raw 字典案例明确跳过 1 个 |

参考 campaign 使用 opt-in 参考解码器，检查真实扩展头、固定距离形状、公共解析/profile、
输入输出进度、解码字节、严格模式拒绝、插桩开关不改变输出以及预算边界。
系统 Brotli 1.0.9 支持 Large Window 开关；其 raw 字典能力限制单独记录。
这组结果不意味着 q10/q11 与参考实现的预设质量、压缩比或速度等价。

编译检查原始日志记录 code gate 成功。外层包装器曾因 CLI Python 脚本的一行变化返回 99；
该脚本不是编译输入。原始记录保留，并以补充证据绑定这项非编译输入变化。
实际编译输入和链接对象已逐项核验，测试名单已从实际 ELF 提取。原始包装器返回 99
及非输入脚本变化保留在 [补充证据](data/brotli-large-window-20261024/debug-source-supplement.json)
中；之后最终 149/149 编译检查在稳定源码窗口完成。

## CLI 与失败证据

修正后的 CLI gate 在同一编译二进制上完成 38 个案例：30 次扩展头检查、30 次严格解码拒绝、
12 次 Large Window profile 与 4 次普通 profile 检查、4 次精确预算成功、4 次预算差一字节拒绝、
22 次目标哨兵保持以及 4 次同路径输入输出检查。另有 10 个 parser 检查和 9 个驱动步骤检查。
这些计数包含同一案例上的多个断言，不能相加作为独立案例总数。

原 gate 要求每个微小样本的 BT 节点遍历数大于零，但小样本可合法使用辅助匹配路径。
修正改为检查实际 passes、states 和 price evaluations 均大于零，
并保留原失败、修正前后源码 SHA 与时间、编译输入清单、二进制 SHA 和同一二进制的重跑记录。
这是门禁断言的修正；原失败证据仍属于本轮记录。

## 大历史与真实公共产物

BT matcher 独立检查覆盖 17,825,849 字节历史与 192 字节远距离匹配；index 请求堆为 537,657,392 字节，
fork 请求堆为 1,075,314,784 字节。图预算差一字节在分配前拒绝，分配次数为 0；
跨段 stitch 检查长度为 127。这些检查用于证明可达历史与边界行为。

| 真实生产者产物 | 输入与产出 | 已确认观测 |
| --- | --- | --- |
| 公共 far-history，window30/q10 | 前缀 17,825,849 + 后缀 2048 = 输入 17,827,897 字节；输出 67,634 字节 | 最大普通距离 17,825,849；总请求堆峰值 2,341,312,656，HQ 工作区峰值 2,316,146,495 字节 |
| 公共 raw 字典额外位案例 | 输入 48 字节；字典 67,108,921 字节；输出 15 字节 | 最大物理距离 67,108,921；独立 reader 确认符号 64、25 个附加位、附加值 60 |

far-history 产物来自真实公共 HQ 编码链路，距离超过 `1 << 24`，不以合成命令代替生产者。
raw 字典额外位案例的原 Zig 报告表达式发生窄整数溢出，错误地记录 expected symbol 0；
生产 wire 没有变化。原报告保留，独立 Python 任意精度运算及逐位 reader 已确认实际符号 64。
两个大产物交由参考 worker 消费现有输出，只执行解码，不重复反向大规模 HQ 编码。
普通 far 产物通过 Brotli 1.2.0 和 1.0.9 的显式扩展解码；raw 产物通过现代参考的真实
字典附加解码，系统参考因缺少 RAW attach API 明确跳过。两个报告属于单向解码证据。

## Wasm 与永久消费检查

真实公共 Wasm 原型已通过 Node 26 执行：无运行时 imports，退出 0；4097 字节输入，
window30、postfix3/direct-high15、q10/q11 均输出 45 字节，公共上界为 4103 字节。
检查覆盖低 14-bit 扩展头、严格解码 `CorruptFrame`、允许扩展后的精确 round-trip、
summary、HQ effective format/quality/block8192/shape、总请求堆释放至 0。
q10/q11 请求堆峰值分别为 11,650,778 与 14,289,306 字节。原型为 ReleaseFast、
single-thread、无 libc 的实际编译链接与执行，源文件在观测窗口内 SHA 不变。

永久 `test-br-large-window-wasm` 已实际通过 7/7 构建步骤和 Node 执行，并复现上述结果。
大产物的单向参考解码与 raw 附加位 reader 证明也已完成。原始记录与源码版本分别绑定，
时间与请求堆观测不得用作行业性能结论。

专用 `test-br-large-window-extra` 已实际执行 1/1 测试，读取真实公共编码输出并核对
symbol64、extra25/value60。首次构建过滤器未匹配测试名，只完成编译，原日志保留；
修正后实际运行及结果独立记录。`build-br-large-window-far` 已编译与已验证 producer
逐字相同的源文件，不重复大编码；其数据和参考解码来自上述单次真实 campaign。

## 证据位置与复现入口

正式工作记录位于 `/tmp/vort-br-large-final-20261024-_su6uuhi/`。其中保存 Large Window
与完整 Brotli 原始日志、result JSON、源码前后清单、编译输入及 CLI 原失败/修正记录。
永久归档目标为 [`data/brotli-large-window-20261024/`](data/brotli-large-window-20261024/)；
归档包括 [参考结果](data/brotli-large-window-20261024/reference.json)、
[实际测试覆盖](data/brotli-large-window-20261024/coverage-summary.json)、
[CLI 与修正记录](data/brotli-large-window-20261024/cli.json)、
[远历史消费](data/brotli-large-window-20261024/far-reference.json)、
[RAW 额外位消费](data/brotli-large-window-20261024/extra-reference.json)及
[永久额外位测试](data/brotli-large-window-20261024/extra-permanent.json)。
复现应以归档清单和对应二进制/源码 SHA 为准。

仓库入口包括 `zig build test-br-large-window`、`zig build test-br`、`zig build check`、
`zig build test-br-large-window-cli` 与 `zig build run-br-large-window-diff`。
参考路径、旧版基线、目标平台、优化模式和已有大产物路径应使用记录中的实际参数；
消费已生成的大产物时仅复核解码，避免重复大规模编码。

本轮功能和证据闭环已完成。后续继续改善全局质量规划与完整候选流内存峰值，并使用
可复现的语料、CPU、编译模式、冷热运行、吞吐和峰值内存基准验证行业差距。
