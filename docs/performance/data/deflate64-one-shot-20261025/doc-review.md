# Deflate64 one-shot文档源码复核

审查时间：2026-10-25 20:26:31（Asia/Shanghai）；工作树`/home/passchaos/project-z/vort-brotli-context-cache`，分支`work/deflate64-one-shot-20261025`。本轮仅编辑`docs/formats/deflate64.md`与`docs/performance/industry-gap-audit.md`，不编辑encoder/helper/incremental/ZIP/tests，不编译、执行编码/测试/benchmark、计时或Git操作。

## SOURCE_READY绑定

- encoder.zig SHA`15a48ab6ae0a5241aab75ccb4dfe0eea979d98fd5f876dc6a29470ed1ce27be2`
- one_shot.zig SHA`b2ca96fc79867fe1b9a0eeab9ed43af24b407332786833917d67a6c4e2abff1e`

两项当前sha匹配worker通知。`encoder.zig:39`先拒nice>65538，再bound/alloc；niceu32 default128，0..2由matcher eligiblelength>=3后的length>=nice立即停止进一步候选扫描，仍使用该match的实际完整长度。maxchain0无match，但fixedliteral可能优于stored，不将其写成forcedstored。

`one_shot.zig:26..38`每128KiB借用callerinput和最多前65536history，fixedbit总采用BitCount checkedadd、ceilBytes最终padding一次；无wholeinput copy、Tokenarray或逐块outputcandidate。matcher heads32768×u32与previous65536×u32固定393216B workspace，计划/emit复用；该数不包含返回output、allocator开销或栈峰/RSS。

`encoder.zig:43..47`仅wholefixedencodedlen严格小于原globalstoredsize才alloc精确fixedout并emit，否则原encodeStoredAlloc；不把perchunkstored拼接纳选择，因此原encodedBound不扩张。Into/Append仍先encodeAlloc后写/ensure，calleralias、失败atomic和stored-onlywire策略保留；adaptivebytes可变化，不宣称old/new bitidentity。

文档将原currentoneshot258/65535gap移除，保incremental策略/默认/limits不变；dynamicD64encoder/presetdict与更广质量/平台/ratio/speed/memory仍未完成。旧stream183/ZIP1988/check176为前一里程碑，不归新one-shot验证。新独立baseline链接与最终验证计数待父通知，不提前报通过。
