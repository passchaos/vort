# Brotli metadata 别名生命周期审核

本记录区分两个修复前的失败，并绑定当前修复的源码与已完成验证。工作目录为 `/home/passchaos/project-z/vort-brotli-context-cache`；审核期间仅写本 Markdown 和 `alias-source-epochs.json`，没有修改仓库代码、编译、运行测试或操作 Git。生成时间：2026-10-26T00:07:08.202405+08:00。

## 源码时间线与重建证据

| QA 阶段 | 字节数 | SHA-256 |
| --- | ---: | --- |
| before_static | 19,570 | `1dc34d78eb09bbc0734a8de6b3862d7b80080a379a2106a76acc9036851f1cd4` |
| transient_simultaneous_alias | 25,281 | `086eba319666aa550def96fc0a36f27e49c60dea2052a1dad18f0d3b64fbbaf2` |
| metadata_only | 25,152 | `dbd8aabb7f9ae74738c1f3c79309b262f77fd33e44943ee5352f764afa508a4a` |
| fixed_extended_qa | 30,959 | `89ae639f95eebb54630a96ae649d6bd4d79a5458c11f2f191fe9a181b52401a8` |

临时 static QA 写入命令于北京时间 **2026-10-25 23:48:51.726** 完成；metadata-only 校正命令于 **23:49:52.367** 完成。两时间对应 UTC 15:48:51.726 / 15:49:52.367，来自结构化命令完成记录的第 10209 / 10222 行。它们限定编辑阶段，不精确宣称编译器读文件的瞬间。

重建只在内存进行：从当前 `89ae…` 移除新增 `staticSourceAliases` 函数及其挂载，恢复 25,152 字节 `dbd8…`；再移除 `staticSurfaces` 及挂载，恢复 19,570 字节 `1dc34…`；将原命令内的临时 static 函数插回，恢复 25,281 字节 `086eba…`。四个完整哈希均匹配原记录。审核文档没有复制整个 rollout、命令正文或无关会话内容；JSON 仅保留来源路径与行号。

## 旧 ReleaseFast：临时同时 source 与 metadata 别名

保留原始失败日志 `metadata-releasefast.log` 和 `metadata-x86.log`，各为 29/30 passed。旧 native 二进制为 `.zig-cache/o/ec91534c4d5e2a63f2797d68b2a97629/vort-br-metadata-tests`；旧 x86 为 `.zig-cache/o/6e49d98b341fa322646be802dc8cfa50/vort-br-metadata-tests`。本次只读检查两者 DWARF，均观察到 `borrowed_chunks` 第 315 行、`old_state` 第 328 行、`next_chunks` 第 331 行，准确匹配重建的临时 `086eba…` QA。这两个二进制的完整生产源码摘要未独立恢复，不能将整生产快照冒称为某个后续冻结版本。

历史路由为临时 `staticSurfaces` 第 317 行 `encodeChunksScratchWithOptions(&borrowed_chunks, large_options)`，第 323 行比较解码明文。它同时把 source chunks 与完整 metadata 借自旧输出。该临时测试一度撤回；撤回没有修复 source 别名行为。当前共享快照修复后已恢复并扩展此回归。

独立按窗口位与 metadata 字段进行 LSB 打包，长度 65,537 的 MSKIPBYTES 为 3，len-minus-one 为 65,536。标准窗口 16 的前缀为 `6c 00 80 00`，metadata payload 从 offset 4 开始；Large Window 25 前缀为 `11 99 0d 00 10 00`，payload 从 offset 6 开始。旧 source borrow 仍指向 offset 4。新前缀与 metadata 发布到旧输出后，这一位置读到 `10 00` 加被后移的 plaintext。因此最终 61 字节恰好为 **`10 00 + plain[:-2]`**，逐字节匹配两份原 RF 失败日志。

原 RF 日志没有逐阶段栈，因此路由归属依据是重建源码、DWARF 变量/行号以及完整 61 字节匹配，不能伪称有运行时 stage trace。

## 旧 Debug：真实 metadata-only 的 undefined 填充

`metadata-final-debug.log` 对应 metadata-only QA `dbd8…` 与生产源码 `44e99f37159bd6a4b0d10f0d686746ec81eca3ba932eade540d02fb3735639d1`，结果为 29/30 passed。栈明确指向 QA `checkPrefix` 第 48 行、`staticSurfaces` 第 315 行。它报告 65,537 字节 metadata 不符，展示的前 256 字节全部为 `AA`，其余显示被日志截断。原失败二进制为 `.zig-cache/o/6a3aa22b6035f158bdc9824383595a58/vort-br-metadata-tests`。

根因在本地 Zig 0.16 标准库 `/home/passchaos/Temp/zig-x86_64-linux-0.16.0/lib/std/array_list.zig:1194`：`clearRetainingCapacity()` 第 1195 行先执行 `@memset(self.items, undefined)`，第 1196 行才把长度设为 0。修复前 wrapper 第 2117 行先清空旧输出，再进入 helper 复制 metadata 到独立 pending。借用的旧 metadata 已被 Debug undefined 填充覆盖，后续完整复制因此复制了错误字节。该解释无需假设旧输出提前 free。

先前“clear 仅改长度，所以 pending 复制前旧 bytes 完整”的安全论证错误，现明确撤回。`metadata-final-releasefast.log` 与 `metadata-final-x86.log` 在这一修复前 metadata-only 阶段各 30/30 passed；ReleaseFast 不保留 Debug 的 undefined 填充效果。**这两次通过不能证明修复前的别名生命周期安全，也不能覆盖真实 Debug 失败。**

## 当前修复与已完成验证

当前生产源码 SHA-256 为 `6c9c59c945ff39b0eb2493f5ce3572a456143ab57d0398c168999436f55a3bdc`；扩展 QA 为 `89ae639f95eebb54630a96ae649d6bd4d79a5458c11f2f191fe9a181b52401a8`；独立 wire oracle 为 `70d63b0088f8d82a8650be068913e6f7488ec4646f49ac4569da51a5061ee555`。本次从磁盘核对三者，均吻合父任务冻结信息。

修复先完整 `validateChunks` 准入，再对 `output.allocatedSlice()` 的全部容量范围使用既有 `stored_alias.protect`。metadata、source chunks 与描述符在 clear/reset 前保护，inner options 与 input 使用保护后的视图，快照持续至整次编码结束。快照拒绝发生在旧输出清空或 incremental reset 前。无别名输入无需快照分配；本次未新增 static total-heap-cap 支持。

原 `dbd8…` metadata-only 回归的字节保留证明见上述内存重建，不存在删除失败 fixture 或放宽预期。新增单函数还覆盖旧输出中的 source 与 descriptor 别名、精确旧 wire 容量下强制移动增长、完整独立参考 wire、offset 4→6 头字段、三次不同快照分配拒绝的旧输出/状态/live-bytes 保留，以及暖复用无别名调用不新增分配。

已读取的最终日志：

- `metadata-fixed-debug.log`：**130/130 passed**，metadata 30 + metadata-root 100。
- `metadata-fixed-releasefast.log`：**130/130 passed**，metadata 30 + metadata-root 100。

这两个结论属于当前共享快照实现和扩展 QA，不能倒推旧生产阶段安全。日志完整摘要、SHA、大小和原失败二进制 SHA 已写入相邻 JSON。审核只读取已有结果，没有重跑测试。

父任务发出本审核任务时，`metadata-fixed-x86.log`、`br-full.log`、`check.log`、`native-final-diff.log`、`x86-final-diff.log` 的后续门禁仍在运行；本记录不宣称它们已通过。后续由父任务记录这些门禁终态，本审核保留当前两个 native 130/130 的明确范围。
