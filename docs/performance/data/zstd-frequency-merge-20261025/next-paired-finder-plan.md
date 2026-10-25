# 保留 suffix 配对轨迹的块级 anchor 缓存提案

本轮只读检查源码，并写入本报告；没有修改源码、编译、编码、计时或执行 Git。读取工作目录为 `/home/passchaos/project-z/vort-zstd-frequency-merge`，初次记录时间为 2026-10-25 15:17:02 Asia/Shanghai（07:17:02 UTC）。当前频率合并验证和交付仍由父任务推进，本报告不重复它们。

唯一建议的下一增量：为当前未索引 multi-duplicate 路径增加一个可选、由 caller 拥有且仅在同一个 immutable block 内存活的 anchor cache，预存每个位置的 15-bit hash，并按 second position 懒缓存该 hash 的紧邻 occurrence pair 的精确 match length。保留原逐位置 scanner、每个 suffix 的 pending 重置，以及所有比较和计价逻辑。首个增量不改为跳跃式 dense occurrence 枚举。

这样能够消除 suffix 查询中的重复 hash 计算，并避免同一相邻 occurrence pair 的重复 match extension；它仍扫描原来的位置，仍产生原来的计价查询。因此，它不能被描述为减少既有诊断中的约 147 万 cost queries，也没有未经测量的速度承诺。

## 读取到的实际行为

[emitMultiDuplicateMatchCompressedBlockProfiledMode](/home/passchaos/project-z/vort-zstd-frequency-merge/src/zstd.zig:23280) 只有在 `duplicate_index == null`、`block.len > 4096` 且不超过 Zstd block 上限时才建立 winner-aware literal cost cache。multi 的序列上限是 128。每次选择一个 match 后，以 `literal_start = match.second_start + match.len` 再调用 finder 搜索新 suffix；已有 index 时走 indexed finder，否则走 cached hashed finder 或原 standalone finder。

[findBestDuplicateMatchHashedImpl](/home/passchaos/project-z/vort-zstd-frequency-merge/src/zstd.zig:30424) 每次查询重新创建 `paired_predecessors:[32768]u32` 和全 false 的 `pending:[32768]bool`，从 `start_min` 按位置递增访问全部可读八字节 anchor。每个位置的处理顺序是：

1. 若已有 best 且 `block.len - position < best.len`，在 hash 之前 break。
2. 计算原 `duplicateHash8`。该 hash 是八字节 little-endian 值经原 wrapping multiply 后取得的 15-bit 值，见 [duplicateHash8](/home/passchaos/project-z/vort-zstd-frequency-merge/src/zstd.zig:31042)。
3. 若该桶没有 pending，记录当前位置为 first，置 pending 为 true，然后 continue。
4. 否则取已记录的 first，并立即将 pending 置 false。检查 first 范围；若已有 best 且剩余字节数 `<= best.len`，continue。
5. 调用原 `duplicateMatchLength`；即使 hash 相同，八字节本身也可能不同，长度小于八时继续。该函数验证原八字节，并保留现有 vector/word/byte extension，见 [duplicateMatchLength](/home/passchaos/project-z/vort-zstd-frequency-merge/src/zstd.zig:31051)。
6. 保留 [duplicateMatchCannotBeat](/home/passchaos/project-z/vort-zstd-frequency-merge/src/zstd.zig:31026) 的长度与 offset 支配判断，再调用原 cost cache。所有计价错误继续跳过候选。只在 payload 更小，或 payload 相等且 match 更长时更新 best。

pending 的 false 切换发生在长度、支配和计价拒绝之前。任何优化都不能把碰撞、短 match、支配候选或失败计价的 occurrence 从桶序列中删除，否则后面的配对会改变。尤其不能按完整八字节值重新分桶：原规则按截断 hash 配对，包括 hash collisions。

## 为什么不能直接扩大旧 indexed 路径

旧 [DuplicateMatchIndex](/home/passchaos/project-z/vort-zstd-frequency-merge/src/zstd.zig:29712) 存储固定的全局 alternating pairs，其 positions、predecessors、match lengths、计数以及 byte-frequency 元数据使用 u16，允许输入长度为 65,535。它的 builder 从块首位开始采样配对，而 [indexed suffix query](/home/passchaos/project-z/vort-zstd-frequency-merge/src/zstd.zig:29887) 二分找到后面的 candidate row，并过滤 `first < start_min`。

固定全局配对加前缀过滤不具有一般的 suffix parity 等价性。令某一个桶的 occurrence 顺序为 `q0 < q1 < q2 < q3`，全局配对是 `(q0,q1)`、`(q2,q3)`。若新 suffix 的第一次 occurrence 是 q1，原 hashed 重置 pending 后配对 `(q1,q2)`；过滤全局 row 只会丢弃 first=q0 的 row，并保留 `(q2,q3)`，候选轨迹已经不同。

这是一项候选轨迹的代数反例，不是本轮执行得到的测试失败或 wire 差异。本报告不扩大范围修改旧 indexed 路径；新的可选路径应以原未索引 hashed scanner 为精确 oracle。也不能直接增大旧常量：u16 position/count/sentinel 和 byte-frequency 累加的边界需要各自处理，而非一个容量开关。

## 所选增量与配对证明

设某个 hash 桶的所有有效 anchor 为 `q0 < q1 < … < qk`。对任何合法 `start_min=s`，该桶留在 suffix 内的 occurrence 必是一个后缀 `qj,qj+1,…`。pending 初始为 false，因此原配对依次是：

```text
(qj,qj+1), (qj+2,qj+3), …
```

这里每一个实际 pair 的 first 都是其 second 在全局该桶序列中的紧邻前驱。换言之，当位置 `p=qt` 在任意 suffix 中成为 second 时，它的 first 必为 `qt-1`；改变 suffix 的 parity 只改变 p 是否成为 second，不会为同一个 second 产生另一个 first。

所以 `length_by_second[p]` 有唯一含义：原截断 hash 桶内紧邻前驱与 p 的原 `duplicateMatchLength`。该值只依赖 immutable block 和这两个位置，与 suffix、winner、literals、certificate、compression level 无关。它可以安全跨 suffix 缓存，包括 hash collision 导致的 0…7 长度；缓存不能被用于选择多个历史 predecessor 的 exact/four-candidate/mixed-chain finder，因为那些路径不满足这个键唯一性。

首次实现只在原 scanner 的两个位置增加机制：

```text
hash = optional_index.hashes[position]       // 原 duplicateHash8 的精确预存值
...
len = optional_index.lengths[position]
if len == unknown:
    len = 原 duplicateMatchLength(block, 原 pending first, position)
    optional_index.lengths[position] = len
```

保留原 `paired_predecessors:u32` 和 pending 数组，且每次查询仍从全 false 开始。保留每一次位置迭代；所有 range 检查、`<` break、`<=` continue、长度阈值、支配判断、cost callback、error catch 和 winner 更新都留在原位置。缓存长度只有到达原 extension 调用点时才读取或填充，不提前算整块 match lengths，也不越过长 match break。

这不需要额外的持久 predecessor/rank 链：查询已有的原 u32 first 记录负责精确重放 suffix parity；second-position 唯一性负责 length-cache 的正确性。hash 可以使用 u16 存储，因为值仅为 15 bits；位置索引、缓存长度和 sentinel 使用 u32/usize，因而不引入 65,535 的位置或频率限制。

## 内存、生命周期和回退

范围只选现有 `duplicate_index == null` 且原 cost cache 已准入的 multi 路径，输入最多 131,072 字节。不新增 encoder 用户旋钮，不改变哪个 level 或 stage 运行 multi，不替换已存在的 small exact/旧 indexed 路径。

对长度 N 的块，有效八字节 anchor 数 `M=max(0,N-7)`。新增持久 payload 为：

| 内容 | 元素类型 | 字节数 | 128KiB block 上限 |
| --- | --- | --- | --- |
| `hashes` | u16 | `2*M` | 262,130 |
| `lengths` | u32 | `4*M` | 524,260 |
| 合计 | | `6*M` | 786,390 |

使用一个普通 u32 对齐 slab 时，两个区域之间至多补两字节，上限为 786,392 字节；768KiB 的固定 payload workspace 足够。Index 的设计只需 block、hash slice 和 mutable length slice 等少量元数据，另预留至多 64 字节 view/header 预算即可。这里是计划的 payload/layout 上限，不是本轮量得的 RSS 或编译后 sizeof。

查询沿用原 128KiB 的 u32 predecessor 数组和 32KiB bool pending 数组，没有新增按查询分配；新增 index payload 加原 finder scratch 的计划工作集约 928KiB，另加现有 cost-cache 状态。多 worker 同时持有 index 时按实例倍增预算，不能把这个 workspace 隐藏为一个大型自动栈局部值。

优先让 caller 提供 typed u16/u32 storage 或已存在的 caller-owned slab，实现内不分配。若生产调用没有合适 workspace，可由现有 stage scratch 的显式 allocator 取得一个有硬上限的 backing allocation，并跨 suffix 复用；不能为了强制零 heap 而删除可行实现，也不能在每次 suffix 查询新建 allocation。所有 ownership、deinit 和容量由 caller 管理，Index 本身只借用输入和 storage。

建议 module 只包含准备、预存 hash 和 length-cache 访问，不拥有 candidate policy。初始化先检查 block 的适用范围和两个 storage 的容量，完成所有 admission 后才发布有效 Index。hash 全部使用现有 hash callback 建立；length entries 初始化为 `u32.max`。有效 match length 最多为 `N-second <= 131,071`，所以 unknown sentinel 不冲突，不截断或 clamp 频率/长度。

Index 仅在一次 immutable block 编码期间有效。caller 提供的 hash/length storage 必须彼此不重叠，也不能覆盖 borrowed block。不得仅因 buffer 指针和长度相同，就跨下一次可变 buffer 内容复用；caller 在新 block admission 时必须 rebuild/invalidate。输入在整个借用期间不能被修改。首个增量中各 worker 独占自己的 mutable length cache；不加入共享 mutable global 或锁。

准备可选 index 失败、容量不足、allocator OOM、输入超出适用域或 caller 没有 workspace 时，内联回退到原 hashed scanner，以同一个既有 cost cache 从同一个 start_min 继续原调用。可选资源失败不成为新的 codec 输出错误，也不缩短候选扫描。不允许开始部分候选计价后再从头 fallback，否则会重复 certificate 更新；所有 preparation/fallback 判断必须在第一次候选扫描之前完成。已有 cost-cache init 的错误处理和输出 allocation 错误继续沿用原顺序。

## winner、错误和 wire 的证明链

对固定 block 和 s，通过位置递增归纳：

1. 新旧每个查询的 pending 和 first 初始相同。
2. 两者访问同一个 position，并在 hash 前见到相同 best，所以 break 决定相同。预存 hash 等于原 hash，故 pending 切换及 first 相同。
3. 所有剩余长度检查相同。cache miss 调用同一原 extension；cache hit 根据前述紧邻前驱唯一性得到同一长度。因此短 match 及支配判断相同。
4. 对每个到达计价点的候选，新旧传入同一个 prefix、offset、match length、tail start 和 incumbent，且 callback 次序相同。成功值、错误后 continue、prune/null 决定以及 cost-cache/certificate 状态更新均相同。
5. 更新 best 的严格小于与等成本更长规则保持，所以循环终止时 nullable winner 和 payload_len 完全相同。

multi driver 的第一个 s 相同，每次选出的 match 相同，故下一次 s、最多 128 个 decisions、literal arrays、first_match、最终 emitter 参数也相同。既有确定性 emitter 不变，因此 emitted bytes 相同。该证明依赖相同输入、配置和 callback，不以“round-trip 成功”替代候选/成本/wire 等价。

可选 index 的 hash/length 缓存不调用 literals preparation，也不吞并或重排计价错误。不能缓存完整 candidate cost：它依赖 start_min、literals 和 incumbent/certificate，只有 pure match length 具有这里证明的稳定性。

## 下一增量的验证与接受条件

1. 用原未索引 hashed scanner 做独立 trace oracle。先对抽象 hash occurrence 序列覆盖每一种 suffix 起点和桶内 parity，包括从第二次 occurrence 开始；验证逐 position pending/first、候选 pair 和 skip 原因一致。专门保留全局固定配对过滤的反例，防止实施时把这个提案悄悄替换成旧 indexed row 过滤。
2. 在真实 block 上对照完整 nullable winner、first/second/length/payload，并记录每次 cost callback 的全部参数、incumbent、error/null、prune 和 certificate 更新。测试 hash collisions、碰撞后仍必须消耗 pair、短 match、equal-length closer offsets、成本相等但更长、成本错误、长 match 的 `<` break 与 `<=` continue。
3. 覆盖 4097、65534、65535、65536、65537、131071、131072 字节；覆盖 first/second 和 match length 超过 u16 的情况、空/短/尾部 start、全重复 finder 直接查询、近乎全重复但允许进入 multi 的 block、随机和结构化输入。以 `0 <= start_min <= N` 的原有效调用域为准，不附带修改无定义的任意超大 start_min 算术语义。
4. 对 miss 与 hit 路径逐条比较原 extension，保证一个 second cache entry 不被不同 predecessor 污染。测试 caller storage guards、输入不变、重复 buffer 地址的新 block invalidate、内存不足和 OOM fallback；fallback 的 cost-query/certificate trace 必须与原路径一致。
5. 保持既有候选和质量配置。执行原 multi winner oracle 和既有十四个公开样本 wire hash 回归，要求 bytes 完全一致。所有平台上的 u32 sentinel、usize 转换和 normal alignment 行为一致，不扩大旧 u16 index 的适用范围。
6. 父任务协调 frozen source 后分别量 prepare+queries 总成本和 warmed queries；冷运行包含预存 hash、length sentinel 初始化与 allocation/reuse 成本。实际记录 anchors scanned、build hashes、query hashes、extension misses/hits、cost queries 和 workspace bytes，再检查发布构建机器码。只有 full/public 证据支持时才接受优化；如果 build 成本或约 768KiB 增量使公共 workload 无收益，应保留 optional fallback 或撤回这个增量，不能通过关闭 multi、减少候选或改变质量来制造收益。

本建议的界限明确：先降低同一原候选轨迹的重复工作。它没有证明安全减少那些候选的精确计价次数，也没有证明全局固定 occurrence 配对可以替代任意 suffix 的重新配对。
