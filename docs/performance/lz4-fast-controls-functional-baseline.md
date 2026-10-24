# LZ4 acceleration 控制功能基线（2026-10-24）

本轮为 native raw block、preset prefix、reusable encoder、native frame 与增量
frame 增加独立 acceleration 控制。默认值一保留既有逐位置 hash-chain/lazy
解析及默认 wire；非默认值在连续 miss 时扩大搜索步长。chain depth 仍控制
每个搜索位置的候选数，两者独立。完整 API 和统计定义见
[格式说明](../formats/lz4-fast-controls.md)。

这是功能与安全增量。参数生效、work counter 减少和功能测试耗时不证明比
liblz4 更快，也不证明 native fast 或 HC 在完整语料和平台上领先。

## 兼容与独立见证

公共加速度采用 signed i32，nonpositive 归一为一，超过 65537 截断。
一保留 Vort 原默认解析，其他值采用先推进旧 step 再更新 miss counter 的
策略：第一次 advance 为一，第二到第六十五次为 acceleration，第六十六次
才增长一。找到 match 后 reset，末尾仅统计实际合法搜索范围内的跳过位置。
独立 oracle 和精确 65/66 次边界验证这项顺序。

所有 skipped positions 仍可作为 literals，跳过后不逐字补齐 hash 表；matched
region 的 indexing、lazy choice、backward extension 与正常 offset 限制保留。
与 liblz4 单 hash fast parser 的差异明确记录，不用参数编号宣称算法或字节等价。
既有 level/HC 和固定 destination-size 行为没有改成另一套解析策略。

独立旧默认 wire 以 `fef87a827f5aeaa1c5a7b2035a7eb0c7648d9389` 归档为来源，
不是从当前实现产生新的 golden 后自比。raw/prefix/frame/reusable/incremental、
linked 和字典输入通过现有公共 API 做对照。Raw empty 的空 slice 旧契约单独
保留，上游 canonical empty `00` 的反向解码另行检查，不能记作上游接受零字节。

## 所有权与失败处理

独立强制移动分配器发现 raw append 的借用输入会在 output growth 后失效，
当时函数仍返回成功但解压内容改变。新增按真实 overlap 决定的 input/prefix
快照，在 output 扩容、frame header 写入及 reusable scratch 替换前捕获来源。
检查覆盖整个 output capacity，非 alias 不增加快照分配。

Frame append 失败恢复原 list length，raw append reserve 失败保留原 prefix，
Into 容量不足不写 caller output。Incremental allocation retry 保留 buffered
input、pending 与帧进度；nextFrame/reset 将同一控制传给真实 block parser。
候选失败和 stored fallback 仍计已发生 work，不伪造 emitted 统计或 CPU 上限。
所有 snapshot 和返回结果均使用调用者的原 allocator，并独立验证 OOM 释放。

Parser、hash/chain、miss schedule、配置/统计及 alias capture 已拆为小模块。
CLI 继续调用相同公共库路径，file 写入遵守 atomic replacement；profile 不改变
wire，归一化与错误验证由库实现。

## 验证来源

本轮窄验证与最终冻结来源分别记录。早期缺少 QA import 的 1/1 compile/run
不算命名测试验收；miss counter 调整前的错误 oracle、raw-empty 上游误分类
和 alias bug 的原始结果保留。最终计数须来自实际测试清单及运行结果。

完整 LZ4 家族使用新增 `test-lz4-full`，避免旧大写 `LZ4` filter 漏掉小写
native parser/frame 测试。参考活动调用匹配版本的 liblz4 raw/continue、
dictionary 与 LZ4F API，而不是猜测 C preferences 布局。

本轮正式证据目录为 `/tmp/vort-lz4-fast-final-20261024-mp6azj4l/`，永久归档为
[`data/lz4-fast-controls-20261024/`](data/lz4-fast-controls-20261024/)。

| 验证 | 已确认结果 | 实际范围 |
| --- | --- | --- |
| 专项 Debug / ReleaseFast / x86-linux-musl | 各 26/26 | 实际产物各 23 个具名测试、3 个匿名入口 |
| 完整 LZ4 家族 | 242/242 | 无大小写过滤，含旧 native 与 imported kernels |
| 版本化参考 | 37 rows、153 次实际调用 | 150 成功与 3 个预期错误，全部输出 guard 正确 |
| liblz4 1.9.3 / 1.9.4 | 72 项双向结果 | raw-empty 的 2 项规范空块反向结果单列，零字节参考拒绝如实保留 |
| CLI 最终小矩阵 | 60 往返、6 个解析/映射测试 | profile 字节比较 22、默认比较 9、输出保护 21、同路径 6 |
| 公共 Wasm | 3 个 smoke、5 个真实 profile 快照 | wasm32，imports=[]，完整实际 Node 执行 |
| 格式与消费 | 通过 | 19 个 changed/new Zig、两个 Python driver、Node 语法与完整 CLI help |
| 完整构建检查 | 152/152 | 退出码零；包括新增公共 probe、CLI 和 Wasm 编译 |
| rebase 后复验 | 26/26 | 新 seed 实际执行；codec 源码未改变 |

完整家族实际 ELF 为 238 个命名测试与 4 个匿名检查，本轮分组为独立 QA18
与 fast core5。其唯一非输入源码变化为 CLI gate；实际编译文件、运行 ELF
和依赖对象保持相同，原宽窗口差异与编译输入投影分别记录。

专项三个产物逐项核对同一个 23-name 集合和测试顺序；每组 1776 个源码/依赖
前后与字节归档一致，实际编译/运行 argv、缓存内容和 ELF 分别绑定。
构建检查的宽快照仅包含 CLI gate 的必要变化，不能称整个仓库窗口不变；
152 项实际编译成功，native 专项与最终 CLI 各自保持其实际输入不变。

参考活动的原 8 个独立旧 wire 与 2 个空输入补充没有重生成或覆盖。
37 个 profile-off 变体保持 wire 和 resolved 设置。System 1.9.3 使用匹配的
系统头文件与 runtime；本地 1.9.4 使用四个参考 C 文件构建，对应版本、内容和
动态 API 来源保存到参考 provenance，实际 C preferences 由头文件描述。

Wasm 的独立 512 字节无匹配样本、acceleration8 分别实际搜索 64 个位置、
跳过 437 个位置、最大 step8；maximum clamp 样本搜索 2、跳过 499、实际
最大 clipped step500。Prefix 实际播种 128 个历史位置与 90 个匹配位置。
这些是明确样本中的实际 work，不是吞吐或内存峰值比较。

CLI 首次 formal 失败来自对无 block parser 的空 frame 错误要求配置值出现在
last-parser profile 中。修正 gate 后，同一个可执行文件通过，core/CLI 源码
没有改写统计。原失败记录保存；最终零工作 frame 严格要求 counters 全零，
只对真正尝试过 parser 的 case 检查 resolved metadata。完整家族宽源码窗口
出现的唯一变化是这个非编译输入的 Python gate，真实编译来源另行绑定。

后续仍需当前源码的 quiet 真实语料 encode/decode、压缩率与 requested heap/RSS
比较，尤其不能把更少的 searched positions 直接当作 industry-best throughput。
