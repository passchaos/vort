# Gzip 分配提示与错误回退

Gzip trailer 的 ISIZE 是明文长度对 `2^32` 取模的值。在 raw Deflate 与
trailer 验证之前，输入末尾四字节只能作为分配提示，不能证明完整输出长度。

普通 `decodeGzipAlloc` 及其 options/limited 变体仍优先使用可能正确的
footer 提示。现在先以饱和的 `raw_bytes × 8 × 258` 判断提示是否可能：
每个输出 token 至多产生 258 字节，并至少消耗一位；stored 字节消耗
八位。计算包括可能的 trailer，因此只会使上界更宽。超过上界的提示
不用于预分配，调用原 raw 解码路径，再由实际流与 footer 校验给出错误。

提示通过这一检查仍不代表流合法。校验和、ISIZE、截断和 trailing-data
检查继续由实际解码结果决定；真实 allocator 失败仍返回 `OutOfMemory`。
调用者指定的输出上限保持有效，物理分配和地址空间范围没有增加。

如果提示缓冲不足，解码器在回退之前释放该缓冲。成功返回 `null` 不会
触发 Zig 的 `errdefer`，因此释放必须显式执行；其他错误继续由 `errdefer`
清理，成功输出交给调用者释放。

[功能基线](../performance/wide-bit-addressing-functional-baseline.md)记录了
发现该问题的完整 32 位回归和修复。缺 footer 的 34B dynamic raw 数据曾
被解释成 4,209,256,066B 的提示；修复后返回 `TruncatedFrame` 且没有
发出分配请求。独立 C/Python 语料还验证了错误大提示、偏小提示、真实 OOM
和合法 1MiB 高膨胀内容，native/x86 的请求与释放记录一致。

此策略用于过滤不可能的提示及正确释放回退缓冲，不是完整流的预验证，也
不是 RSS 限额。显式 expected-size 接口和调用者提供输出的接口保留各自
契约，不自动采用该提示策略。
