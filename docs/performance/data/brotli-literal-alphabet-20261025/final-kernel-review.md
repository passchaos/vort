# literal alphabet 最终源码契约审计：radix SOURCE_READY，保留 PDQ 历史

当前结论：对指定 radix SOURCE_READY，在原内部生产契约内，未发现 exact rank/tie、support/undefined 读取、256 容量、临时缓冲区初始化、错误输出或隐藏分配的阻断缺陷。该结论只覆盖源码契约，不决定候选或阈值 64/128 的性能接受；父任务正在另行执行 ReleaseFast、正式 micro 与公共验证。

## 当前 radix 快照与审计范围

- 隔离源码路径：`/home/passchaos/project-z/vort-brotli-context-cache/src/br/encoder/literal_alphabet.zig`，SHA-256 `66ecc843530b925666f93f6c2983a056668d95a8f7f978ce680940b111e475c7`。
- split SHA-256 `37d886fd412ac3ae7444ca4d73549f6aa80d49f6f5a28db36ffdb717eca8edcf`，与旧候选 wrapper/QA 集成版本相同。
- QA `src/br/encoder/literal_alphabet_tests.zig` SHA-256 `730195dc3e5549d33eb6e34defd987141781cef2311b6e782a9de674a2b9a0f0`。
- 基准源码仍是主树 `/home/passchaos/project-z/vort` 已发布 HEAD `d689a411c03208d242e8775e34e7c4c006b07e80`。只把主树用作旧源码 reference，新代码审计均在上述隔离树。
- 前提：support 为严格 byte 符号升序且唯一；输出拥有至少 256 个符号槽，长度类型可表示 256，生产调用传入独立的 `PrefixAlphabetFor(256)`（usize len）和 `ActiveSymbols`（u16 len）。该 `anytype` helper 没有承诺处理较小数组或非法 support。
- 本轮没有编译、测试运行、计时、源码编辑或 Git 写操作；仅阅读来源、复核哈希/既有 QA 结果、执行文本比较，并更新本 `/tmp` 报告。

## 当前 exact rank 与稳定 radix 证明

`literal_alphabet.zig:61` 构造 `(@as(u64, ~frequencies[symbol]) << 8) | symbol`。完整 u32 频率先按 u32 求补，再扩宽到 u64 后左移，完整 40 位键没有 clamp、近似或频率截断。低 byte 保留唯一的 symbol；符号不同则 key 不同。key 升序的数学顺序严格等价于频率降序、同频符号升序：相邻频率差异在高位至少贡献 256，任何符号差异至多 255。

key 构造遍历 filtered tree_symbols，因此最初的 key 数组按 symbol 升序。`radixSortKeys:77` 从低到高处理 shift=8、16、24、32 的四个频率 byte。每轮先计数，再计算独立桶的起始位置，最后按 source 原顺序 scatter，桶内顺序保持不变。稳定 LSD 的归纳不变量是：每轮结果按已处理频率字节排序，字节组合相同的元素保持此前顺序；四轮后完整补频率升序，即完整频率降序；所有相等频率仍保持最初 symbol 升序。初始顺序明确，所以不需要额外 low symbol byte pass。

`radixSortKeys:70–78` 的 variation 是所有初始 key 与首 key 的 XOR 的 OR。一个 byte mask 与 variation 为零，当且仅当该 byte 在全部 key 中恒定。其稳定 counting pass 必然是 identity，跳过不改变上述不变量。variation 在全部 pass 前完成，后续 permutation 不改变 digit 是否恒定；low symbol byte 的 variation 没有参与四个 mask。没有省略任何变化的频率 byte。

radix helper 是 private，并依赖调用点建立的 symbol 初始升序；不把它宣传为任意输入顺序下可忽略 low byte 的通用 numeric-key sorter。同一 support 与相同的 supported frequencies 得到完全相同的 alphabet/tree_symbols；unsupported frequencies 不影响结果。频率缓存 key、候选评分与 wire 决策代码没有改写。

## support/undefined 与错误输出

`buildLargeSupport:25–34` 只读 support 内的 `frequencies[symbol]`；已初始化的 live tree_symbols 是后续插入与 key 构造的唯一符号来源。small support 的 reference 仍只沿 support 读取。radix 完全在初始化的 keys prefix 上执行，不回读频率。support 外的频率槽可以 undefined；没有 dense scan 或完整频率数组拷贝。

原 fused insertion、already-ordered copy、large-support/small-live insertion、radix 四条路径都只写两个 len 和输出 `[0..live]`。tree_symbols 始终是过滤零频率后的符号升序，alphabet 才是频率排名。already-ordered 比较只在非零频率更新 previous_frequency，从 u32max 起始，零洞与最大频率首项均正确。

空 support/全部 supported frequency 为零时返回唯一 `error.InvalidBlockPlan`，两 len 均为零，符号数组没有写入，尾部保持旧值。合法唯一 byte support 的 live<=256，两个输出长度类型足够；所有正常路径完整写 live prefix，不触及 inactive tails。原容量错误分支在合法 256 槽输出下不可达；非法 support 的 debug assertion 前提和较小输出数组的不支持范围没有变化。

## u16 count/offset 的 256 边界

`radixSortKeys:74–97` 中 counts、positions、next 均为 u16，范围可覆盖 0..256。每轮所有 counts 先清零；全部 256 个 positions 都由 prefix sum 初始化，没有读取 undefined count/position。count 总和为 keys.len<=256，各 count<=256，next 中途与终值均<=256，不会因 full support 溢出。

对 digit 桶，start 等于之前各桶 count 之和，end=start+该桶 count；这些半开区间构成 `[0..live)` 的不重叠分割。source 每出现该 digit，先用 positions[digit] 写入，再增一，所以最后一个非空桶元素最多写下标 live-1<=255，之后 cursor 才可成为 256。空桶或已完成桶的 position=256 是合法计数值，scatter 不会从没有当前元素的桶把它用作写下标。所有 destination prefix 下标恰好写一次。

## temporary 有效范围与奇偶最终缓冲区

初始 `in_keys=true`，第一轮实际执行的 pass 只从完整初始化的 keys prefix 读，往独立 temporary prefix 写。上面的桶区间证明确保 temporary `[0..live]` 在翻转状态前被完整初始化；下一轮才可能读取它。keys 与 temporary 是不同数组，source/destination 不别名。两者只切片到 keys.len，temporary 的未初始化尾部从不读取。

仅实际执行的 pass 翻转 in_keys；跳过恒定 digit 不翻转。

| 实际 pass 数 | 最终完整结果 | 收尾读取 |
|---|---|---|
| 0 | keys 原顺序 | 不读 temporary、不复制 |
| 1 或 3 | temporary live prefix | `@memcpy(keys, temporary[0..live])`，只读已初始化 prefix |
| 2 或 4 | keys live prefix | 不复制、不读 temporary 尾部 |

最后只从 keys `[0..live]` 提取 low byte 写入 alphabet；u64 key 的其他位不影响 symbol extraction。

## 当前内存和旧核心未变

radix 模块没有 allocator、可变全局/cache、输入指针保留、I/O 或计时。keys `[256]u64` 与 temporary `[256]u64` 共 4096 字节；counts/positions 各 `[256]u16` 共 1024 字节，源码显式数组合计 5120 字节，加少量标量和调用信息。所有 storage 固定有界，不申请 heap，也没有 PDQ/通用 sort 调用。未检查生成机器码，故此数字不是精确 stack-frame 声明。

`noinline buildLargeSupport` 使 support<64 路径不调用带 key workspace 的大 support 函数。radix 构造与排序逻辑只在未 already-ordered 且 live>=64 时执行；不推断大 support 的提前返回分支没有为数组预留 stack frame。

重新对当前源码执行文本审计：split 去掉新增 import/wrapper、将旧 reference 名称还原并去掉新增七行 QA 比较后，与主树旧 split 逐字节相同。新模块 reference body 在 support slice 适配后也与旧插入 body 相同。主树已有 1217 个 src Zig 文件仅 split 有差异，其余 1216 个逐字节相同。因此所有旧纯函数、频率统计、候选生成/预算、map/cache、code-length、weighted sparse 和 prefix/RLE 行为代码均未改写。

## 当前 QA 来源与结论边界

只读复核父任务已有 `radix-debug/result.json` 与 `radix-x86/result.json`：两者 source_before/source_after 都匹配以上三个 radix/split/QA SHA，source_stable=true，exit_code=0，各报告 1 个 module contract test。Debug 为 native；x86 命令为 `ReleaseFast -target x86-linux-gnu`。本轮未运行这些命令。

QA oracle 逐符号选择最大完整频率/最小 byte，不复用 key 或 radix。比较完整 live alphabet 与 tree_symbols、两 len、reference prefix、输出尾部/guard 和输入不变；undefined fixture 的 oracle 条件短路，且不复制完整频率数组。新增 `frequencyByteCases:129` 覆盖分别只有四种频率 byte 之一变化、重复 byte/tie、两/三/四个变化 byte、恒定中间 byte，以及 threshold-1/threshold/threshold+1；其直接数值 oracle 覆盖跳过 byte 和最终奇偶 buffer 的对应输出。其余 full-u32/random、u32max tie、full count256、零输入、稀疏支持测试保留。

未宣称穷举所有 0..256 count、host ReleaseFast、完整 code-length/候选/wire 差分或公共性能结果；这些由父任务另行完成。非阻断 QA 文案问题仍在 `literal_alphabet_tests.zig:187`：`128-symbol` 频率本身降序，该 fixture 验证 already-ordered，原插入也无长移动，注释“long movement”不准确。

当前审计最后取得系统时间：2026-10-25 11:04:56 UTC / 2026-10-25 19:04:56 Asia/Shanghai。下一步由父任务核对同 SHA 的 ReleaseFast、正式 micro 和公共 full-wire 证据，再决定是否接受 radix 与 threshold64；本报告不提前作性能决策。

## 历史：已拒绝 PDQ 候选

父任务根据正式 source-stable micro 中多数案例明显变慢拒绝 PDQ。以下保留旧 `81ba69e0` 快照的源码审计；其中“等待 radix”的描述是旧轮次状态，已由上面的当前 radix 结论替代。不能用旧结论认证新源码或宣称部署接受。

### 旧 PDQ 审计对象与边界

- 隔离源码：`/home/passchaos/project-z/vort-brotli-context-cache/src/br/encoder/literal_alphabet.zig`，SHA-256 `81ba69e0e99ed667c37eab9445584cd17ed12b62ecb7a794b6b9dcd0a176d59e`。
- 对应 split：`src/br/encoder/literal_context_split.zig`，SHA-256 `37d886fd412ac3ae7444ca4d73549f6aa80d49f6f5a28db36ffdb717eca8edcf`。
- 原版参考：主树 `/home/passchaos/project-z/vort`，已发布 HEAD `d689a411c03208d242e8775e34e7c4c006b07e80`；原 split SHA-256 `bc8bc8bd60cfe72ba884167cb59ed67e83c217e9046452c7e4db47050abbd4ab`。
- 仅阅读源码、标准库、既有结果并复算文本/哈希；没有编译、测试运行、计时、源码编辑或 Git 写操作。此报告只写入 `/tmp`。
- 审计前提与原内部函数一致：support 是严格符号升序且唯一的 byte 集合；输出拥有至少 256 个符号槽，长度类型能表示 256；生产调用传入独立的 `PrefixAlphabetFor(256)` 与 `ActiveSymbols`。不把 `anytype` 扩展解读为支持较小输出数组或非法 support 的公开验证 API。

## 旧 PDQ 快照的静态结论

在上述生产前提内，未发现频率排名、平局、稀疏有效范围、错误输出或隐藏分配缺陷。这不改变 PDQ 已被正式 micro 拒绝的结果，也不决定阈值 64/128。

### 排名、same key 与平局

`literal_alphabet.zig:61` 的键为 `(@as(u64, ~frequency) << 8) | symbol`。`~frequency` 保留完整 u32，随后先扩宽为 u64，再左移 8 位，因而能覆盖完整 40 位键；没有 clamp、近似或截断频率。高 32 位的差异至少贡献 256，低 byte 的符号差异至多 255，所以 key 升序严格等价于频率降序、同频符号升序。

support 唯一使每个 live symbol 的低 byte 不同，因此不同符号不可能具有相同 key。`sortUnstable` 的稳定性不会影响结果。键提取只截取低 byte，即原符号；频率数值本身不被改写。同一 support 与同一组 supported frequencies 总是得到相同结果；support 外的频率任意改变都不应影响输出。

### 四条路径

| 条件 | 旧候选执行路径 | 精确顺序依据 |
|---|---|---|
| support.len < 64 | 原 fused insertion | 仅严格更高频率前移，保留同频的初始符号升序 |
| support.len >= 64，live 非空且频率已降序 | 复制 filtered ascending support | 零频率跳过；同频已由 support 顺序解决 |
| support.len >= 64，未降序且 live < 64 | 对 filtered live set 插入 | 与原插入比较条件完全相同 |
| support.len >= 64，未降序且 live >= 64 | 完整 40 位 key 的 PDQ | 唯一精确 key 的总序 |

`previous_frequency` 从 u32max 开始，只在非零频率上更新，所以零频率洞不会破坏 already-ordered 判断，u32max 首项也被正确接受。`tree_symbols` 始终保持 filtered support 的符号升序，与排名后的 alphabet 分开保存。

### 稀疏 undefined 范围与输出 shape

初次收集只读取 `frequencies[symbol]`，其中 symbol 来自 support；后续插入和 key 构造只从已经初始化的 live tree_symbols/alphabet prefix 获取 symbol。没有 dense scan、完整频率数组复制或通过 comparator 回读数组。keys 只写 `[0..live]`，PDQ 与提取均只访问该 prefix；其未初始化尾部不参与排序。

所有正常路径只写输出 `[0..live]` 和两个 len，尾部保持原值。插入最多写原 alphabet.len 的新槽，合法 support 下 live<=256，最后一个写入下标为 255。生产 `alphabet.len` 为 usize、`tree_symbols.len` 为 u16，均可表示 256；最终 `@intCast(live)` 在范围内。

空 support 或 supported frequencies 全为零时，原版/新路径均返回唯一的 `error.InvalidBlockPlan`，两 len 已置零，没有写任何符号槽，尾部保持原值。原 reference 的容量错误分支在合法 256 槽/唯一 byte support 前提下不可达；新大 support 路径依赖同样的生产前提，并未承诺较小输出数组的错误恢复。非法顺序/重复 support 仍属于原有 debug assertion 前提，没有新增错误集合或生产校验承诺。

### 内存与保留状态

模块没有 allocator、全局可变状态、cache 或输入/输出指针保留。排序 workspace 是固定 `[256]u64`（2048 字节）。Zig 0.16 本地 `std.mem.sortUnstable`（`lib/std/mem.zig:627`）调用原地 PDQ；`std/sort/pdq.zig:43` 使用固定 Range stack，并可能回退到原地 insertion/heapsort，均不申请 heap。PDQ 源码还含固定排序 stack，故不能把 2048 字节声称为整个调用的精确 stack frame。

`noinline buildLargeSupport` 在源码层隔开 support<64 的 reference 路径。key 构造/排序代码只在上述最后一条路径执行，但未检查机器码，不能断言大 support 的 copy/insertion 分支没有为 key buffer 预留 stack frame。

## 旧核心未变化的文本审计

从 split 去掉新增 literal_alphabet import，去掉 forwarding wrapper，将 `buildTreeAlphabetReference` 名称还原，并去掉新增七行 QA 比较后，完整文件与主树原 split 逐字节相同。

因此旧候选没有改写其他旧纯函数、候选生成、map/score/cache key、预算、频率统计、code-length 构造、weighted sparse 计分或 RLE 前缀成本。新模块 `reference` 的执行 body 在把旧 `active_symbols.symbols[0..active_symbols.len]` 适配为同一 support slice 后与旧函数 body 相同。

另逐文件比较了主树已有 1217 个 `src/**/*.zig`：仅 split 有差异，其余 1216 个全部逐字节相同；隔离树新增源码只有 literal_alphabet 与 literal_alphabet_tests。command_plan、small_huffman、literal_tree_score_cache、complex_prefix 四个相关模块也分别确认完全一致。构建/微基准文件属于父任务工作，此处不做部署验证。

## 既有 QA 证据及限制

仅阅读 `/tmp/vort-br-context-alphabet-20261025/alphabet-debug/result.json` 和 `alphabet-x86/result.json`：两者 source_before/source_after 对应上述已审计 SHA，source_stable=true，exit_code=0，各报告 1 个 module contract test。Debug 为 native，x86 为 `ReleaseFast -target x86-linux-gnu`。这些是父任务已有结果，不是本次运行的验证。

`literal_alphabet_tests.zig` 的 oracle 逐符号选择最大完整频率/最小 byte，与 packed key 实现独立。测试比较完整 live alphabet、ascending tree_symbols、两个长度、reference prefix、输出尾部 guard、输入不变性；包括阈值附近的代表性 live/support counts、零输入、高频、u32max 平局、support 洞及 support 外 undefined。oracle 通过短路条件避免读取 unsupported entries，undefined fixture 不复制完整数组。

这些测试选择了代表性的 counts，没有穷举 0..256 所有 count；这里不宣称完整 count 穷举、host ReleaseFast、集成 full-wire/所有候选或性能验证。QA 注释 `literal_alphabet_tests.zig:154` 所说的“long movement”与 `128-symbol` 降序频率 fixture 不符：该 fixture 本身已频率降序，实际验证 already-ordered 路径，原插入也不会发生长移动；只是注释问题，独立 oracle 结论不依赖它。

## 等待新的 radix 审计

收到新的 SOURCE_READY 后再审，不把本报告旧 SHA 的结论迁移到新源码。重点重新检查：完整频率的每个变化字节稳定通过、初始 symbol-ascending 顺序与同频 tie、只读 support/live 范围、u16/usize offset 的 256 边界与最后写下标、空输入与 untouched tails、固定 workspace 和既有核心未变。阈值和候选接受由父任务正式 source-stable micro/public 结果决定。

本轮最后取得系统时间：2026-10-25 11:01:26 UTC / 2026-10-25 19:01:26 Asia/Shanghai。
