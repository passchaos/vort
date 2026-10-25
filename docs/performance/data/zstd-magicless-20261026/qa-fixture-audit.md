# Magicless QA fixture 校正记录

生成时间：2026-10-26T02:03:07.699234+08:00。本记录只说明独立 QA 的两处校正，没有修改生产编码器/解码器，也不将旧编译可能读取混合版本作为已证根因。

`magicless-debug-second.log` 的 17/18 core tests 通过、128/129 aggregate 通过；失败首先发生在独立 QA scanner 的 kind 3 检查，还没有把该自造大 raw frame 交给生产 decoder。`magicless-debug-diag.log` 随后证明首八字节实际为 `a4 03 00 02 00 00 00 00`，应为 `a4 03 00 02 00 00 00 10`。构造器已附加 131,072 字节 raw payload，但错误地把首块 Block_Size 写成零。

实际原因是 `const length = @min(payload.len - offset, 128 * 1024)` 的推导类型被常量上界收窄为 `u18`。旧 `length << 3` 仍在 u18 内执行：131,072 左移三位需要 21 位，结果截断为零。这与父任务独立检查中的显式 runtime `usize` 不同；并非通用 u24 写入或标准库错误。

`magicless-debug-fixed.log` 第 4/5 行保留运行证据：`min_type=u18 length=131072 old_shift=0 widened_header=0x100000 bytes=0,0,10`。修复先声明 `length: usize`，再把字节数扩为 `u24` 后移位并编码 last bit；仍使用 std.mem.writeInt，并未手填预期 header。根 QA 保留独立 golden：总长度 131,090、FHD/FCS `a4 03 00 02 00`、首 raw header `00 00 10`、下一 header 位于 offset 131,080 且为 `19 00 00`，以及两个完整 payload 段比较。临时诊断打印已移除。

修复后 raw fixture 通过并进入后续字典测试。`magicless-debug-fixed.log` 第 6 行的下一个失败是 QA 对 one-shot 错字典 ID 预期不符：预期 DictionaryMismatch，实际 NeedDictionary。栈指向生产 `validateNativeDictionary` 第 9,942 行的既有合同：提供的 ID 无法满足 frame 时返回 NeedDictionary。QA 已据此修正 one-shot WithOptions 的预期；增量 `provideDictionary(wrong)` 仍保持 DictionaryMismatch，不修改生产逻辑迎合测试。

本轮只做上述 QA 源码修改与格式检查，未编译、执行测试、操作 Git或重启父任务仍运行的 RF/x86 handles 26644/50739。这里的通过范围仅是此前日志中 raw fixture 的进展；最终 aggregate 验证由父任务另记。

最终冻结 QA 源码：

- `src/zstd_magicless_tests.zig`：`3562014e9f3768ff9328a49ab11b4434ae374c82cfe7076ab7b609a714720c3b`
- `src/tests/zstd_magicless_helpers.zig`：`11c3501ff8fa707203b0c305b35f986794a877cce4ac45ffc87588fd22db203a`
- `src/tests/zstd_magicless_streams.zig`：`60ca069517fcebde64a7706c7392016b0c20e6e8d06cbaf2a9fcfba6fcc72d50`
- `src/tests/zstd_magicless_dictionaries.zig`：`294054ed5c5c226491ce0862d9eb58f67e7c7caf1d3db3665d92b2adda5460c1`
- `src/tests/zstd_magicless_memory.zig`：`f2ae638df400dda11df245a2f29fa8d6a1f311c45b5bffc42aa1c2042412dbd5`
