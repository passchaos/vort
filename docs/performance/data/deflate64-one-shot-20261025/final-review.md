# Deflate64 one-shot 候选最终只读审计

## 当前最终 wide SOURCE_READY：先前容量问题已修复

当前结论：最终两份wide源码已经修复旧15a/b2ca的fixed候选先窄化问题。本次只重审容量/分配数据流与源码范围，没有重复旧大范围审计；未发现新的阻断问题。其余先前审计的借用history、两遍同input、原子发布、alias与生命周期证明继续适用，因为执行路径和共享stream文件没有改变。以下旧候选内容保留为历史，旧“需修/限制”描述不代表当前源码。

当前隔离工作树 `/home/passchaos/project-z/vort-brotli-context-cache`：

| 文件 | 当前已审计 SHA-256 |
|---|---|
| `src/deflate64/encoder.zig` | `9e996ca92cd21f45864eff4c19f5fbea5746231b5c14db3d4519d7dae2da6cf1` |
| `src/deflate64/one_shot.zig` | `919d7c9d333b68a5409a451a886ebac2d92babd7efc28630fd475d9c84e36738` |
| `src/deflate64/one_shot_tests.zig` | `bf6544863a263e7a2c021e8c6d96de503542add05021d5b8350e485eb4d359c4` |

### 宽比较和最终容量

`one_shot.zig:13–16` 的Plan.bit_len/encoded_len均为u128；每boundedblock成本在line30以std.math.add(u128)checked累计。line37的encoded_len用quotient/remainder，不依赖共享io/bit_count，也不使用bits+7。私有wide成本更改没有改动实际每blockscorer、matchfinder或wirehelpers。

`candidateSize:46–49` 在u128域内计算精确ceil bytes，先与@as(u128,stored_size)比较。encoded_len>=stored_size时返回null，包括usize32/64容量以外的较大候选；encoder:44随即调用原globalstoredfallback。只有严格获胜才@intCast(encoded_len)。由于0<=encoded_len<stored_size<=usizeMax，这次cast必然可表示，不会重新触发原来的“败候选先窄化”错误。stored_size=0时也只返回null，不会错误接受零候选。

quotient/remainder对任意u128输入均安全：bits/8最大为2^125-1，加一个余数标志最多为2^125，远小于u128max。`candidateGeometry`新QA包含u128max、32位大败候选、usize边缘strict tie/ceil cases，不构造或读取fake大输入。

fixed_size已通过严格获胜证明并由exactplan确定；outputalloc仅使用该usize值。emit仍跨全部相同chunks保留连续state、最后align一次，并assertwritten==fixed_size。尾部padding不超过ceilplan，没有新allocation/fallibleemit步骤。空input仍10bits→2bytes<stored5；0/1/2nice及max_chain0仍保留。

### 32/64位全部输入几何的u128界

任意literal<=9bits；任意匹配bits<=9*consumed：length3最大26<=27，length4..258最大code/extra/distance为8+5+5+14=32<=36<=9*length；length>=259使用最多43bits，远低于9*length。因此对n>0，固定候选totalbits<=9*n+10*ceil(n/131072)，empty为10bits。

| usize宽度 | n最大 | chunk数 | fixed bits上界 |
|---|---:|---:|---:|
| 32 | 4294967295 | 32768 | 38655033335 |
| 64 | 18446744073709551615 | 140737488355328 | 166022104038269517815 |

两者均<2^68，u128累计不可能因合法usize32/64inputgeometry溢出。Stats.match_count<=floor(n/3)，checkedusize累计也不会因此溢出。原encodedBound先检查globalstoredbyte容量；对所有它可表示的合法input、有效options，候选成本几何不再引入额外先窄化/bitwidth限制。实际allocation可失败，输入必须真实有效且两遍期间稳定；这不是巨大物理输入编码或性能完成证明。

### 源码稳定与错误顺序

重新逐body检查：encodedBound、encodeAppend、encodeInto、encodeStoredAlloc、encodeStoredAppend、encodeStoredInto六函数均与主树旧body相同；stream_encoder、stream_blocks、stream_match、io/bit_count四源逐字节与主树相同。此前sharedSHA和生命周期/alias证明未因costwidth更改失效。

nice>65538仍在encodedBound/allocation前返回InvalidBlockPlan，无allocation；validnice的encodedBound检查仍早于matcher/outputallocation。只在candidate获胜后cast/allocfixed，败候选无需小size近似或overflowfallback异常。Into仍先独立encodeAlloc再检查/发布，Append仍先encodeAlloc完成后ensureoutcapacity，输入别名安全次序保持。

### 当前验证范围

本轮只读QA新body及哈希；父任务正在统一编译最终native/x86。历史15a/b2ca的99/99结果不能改标成最终9e99/919d通过。新source稳定编译/独立差分完成结论由父任务附带对应SHA记录。

仅更新/tmp报告；没有编译、计时、运行测试、修改源码或Git。最新取得系统时间：2026-10-25 12:42:36 UTC / 2026-10-25 20:42:36 Asia/Shanghai。

## 历史：15a/b2ca容量边界（已在当前源码修复）

结论：指定两份候选在有界借用chunks/history、完整length/distance、两遍deterministic规划/输出、全局stored bound、分配所有权及Into/Append原子发布上未发现安全阻断。另确认一个需要明确契约的整数边界：fixed候选的最终bytes先窄化到usize，之后才与stored比较；32位上可能存在stored仍可表示而fixed不可表示的输入，当前会提前IntegerOverflow并放弃storedfallback。见下文“容量边界”。不能把此版本宣传为所有stored-bound可表示输入都能自适应fallback。

本报告只读源码与父任务已有QA产物，不执行编译、测试、计时、源码/Git操作；只写此/tmp报告。wire可因范围/匹配/分块变化而改变已获授权，未承诺旧压缩wire恒定或所有平台ratio最优。

## 冻结来源与引用稳定性

工作树 `/home/passchaos/project-z/vort-brotli-context-cache`，参考主树为父任务指定已发布 `06d8909c`。

| 文件 | 已审计 SHA-256 |
|---|---|
| `src/deflate64/encoder.zig` | `15a48ab6ae0a5241aab75ccb4dfe0eea979d98fd5f876dc6a29470ed1ce27be2` |
| `src/deflate64/one_shot.zig` | `b2ca96fc79867fe1b9a0eeab9ed43af24b407332786833917d67a6c4e2abff1e` |
| `src/deflate64/one_shot_tests.zig` | `8c9e9a56d46bd5d6ff5560350c1215e7c90f891441ec2d9b8867710239cd2b8d` |
| `src/deflate64/stream_blocks.zig` | `1b888cee9cbd786bfd9b3bea66b98415200ee88a2f424de76d8bfe19c506558e` |
| `src/deflate64/stream_match.zig` | `13879c9f5dcf45cecd1ae2d9cc7e7400db3748bae45f568dd49340706e4ae76b` |
| `src/deflate64/stream_encoder.zig` | `597a2959ece1ce4335b1ef5e9846af4aac64e7fb74cbbd1cf1091d43293d834f` |
| `src/io/bit_count.zig` | `bf4dcac62fa3258687146bfb9f733d2a6e20624a65a7789e08f736948484b1f2` |

两候选/QA最后复核保持上述SHA。stream三文件及io/bit_count逐字节与主树相同，没有把共享stream安全证明移植到修改过的实现。分别提取并比较了六个旧公开函数body：encodedBound、encodeAppend、encodeInto、encodeStoredAlloc、encodeStoredAppend、encodeStoredInto全部逐字节相同；没有借one-shot扩展改写已有stored输出或public wrapper执行顺序。

## 有界计划与两遍同一输入

`one_shot.zig:26–36,50–56` 两遍用相同while规则：take=min(131072,input.len-offset)，end=offset+take，history_start=offset-min(offset,65536)。每次end<=input.len，offset单调到input.len；没有危险的offset+chunk_len先加后min，也没有把全局offset塞进u32 matcher。

block借input[offset..end]，history借已处理前缀最后65536字节；block<=131072，history<=65536，局部可寻址总长<=196608。大于u32的全input offset只用于usize slice，不影响matcher局部坐标/哨兵或window ring。没有全input clone、plain/history copy、u16Token列表或per-block候选输出。

每个fixedPlan都begin清heads/reseedhistory，emit每个writeFixed也begin。两遍传同一input、options和切分，完整匹配扩展与每个消耗位置插入完全一致；pass1结果size与pass2writer字节数对应。first match ties按照相同head遍历顺序，range完整覆盖length65538/distance65536。empty只循环一次、10bit固定块；input为exact chunk倍数也没有额外emptyfinal。

共享matcher搜索前插入规则、65536ring与跨history末2字节anchor仍是已发布原实现。max_chain0是literal-only，但非empty helper仍会begin/insert，所以当前ensure不是可删的无用allocation；empty不ensure。

## 连续bits、stored bound 与输出容量

`one_shot.plan:31` 使用已有 `bit_count.BitCount` checked加法累加每块bits；每块已含3位header+7位EOB+全部symbol/extra。single块helper算术在128KiB硬上界内，32位也安全。Stats.match_count按usize checked累计，max字段只是bounded max。

BitCount在usize<64目标为u64，在64位目标保留usize（`io/bit_count.zig:5`）。因此32位上全流bits可越过2^32而不截断。`ceilBytes:38–40` 使用bits/8+非零余数，不作wholebits+7；最后toLocal checked窄化为usize。这已经取代早期架构报告中“usize+7”假设，当前候选没有该overflow代码。

encoder先成功plan，只有plan.encoded_len严格小于global stored_size才alloc exactfixed并emit；相等或更大调用未改globalencodeStoredAlloc。成功return必然<=原encodedBound，fallback未采用每128KiB独立stored分片，所以不会引入多余stored头的旧bound陷阱。

emit使用单Writer跨所有块保留state与len，仅最后一块final=true，最终align一次。输出容量已精确admitted，emit没有allocation/fallible操作；written==plan.encoded_len assertion用于核对同源plan/replay不变量。最后padding字节包含在ceil size，不会为每个chunkalign。

empty bit_len=10、ceilBytes=2、storedbound=5，选择fixed；output为03 00，可不申请matcherworkspace。较小wire不意味着每token总为ratio最优：sharedgreedy仍接受所有length>=3，不做profit筛选，但wholefixed成本包含真实bits。

### 容量边界：fixed先窄化可能遮住可用storedfallback

`one_shot.zig:38` 在返回Plan之前调用ceilBytes→toLocal。32位上fixed候选bytes若>usizeMax，则IntegerOverflow在encoder:44比较之前返回。globalstoredsize此前可能通过encodedBound检查。

仅用整数几何模型举例，不运行或分配该输入：n=4,000,000,000个高字节、max_chain0；k=30,518个128KiB fixed块；storedsize=4,000,305,185<=4,294,967,295；fixedsize=ceil((9*n+10*k)/8)=4,500,038,148>usizeMax。当前fixedPlan的u64sum能表示这些bits，但ceilBytes窄化失败，无法选择更小可表示stored。

这没有产生小buffer、wrap或错误wire，是一种显式IntegerOverflow返回；不过若目标要求“凡encodedBound能表示且allocator能提供output就可fallback”，则需调整：Plan保留宽encodedbytes，先与@as(BitCount,storedsize)比较，只有赢的fixed才checkedcast；或者传storedlimit，candidate超过limit时直接标记lost而不窄化。不要把overflow当nearzero fixedsize。64位上BitCount仍usize，极大candidatebits自身可能在bytebound之前overflow，亦须诚实记录而不是声称任意byteaddressable输入都可编码。

该边界已通知父任务；此报告锁定上述15a/b2ca版本，不认证未来修正。没有实际创建巨大fake slice或声称QA已覆盖这个物理输入。

## 生命周期、alias与原子公开

encoder内部Matcher由调用者allocator拥有、deferdeinit覆盖plan/ceil/outputalloc/fallbackerrors；ensure可先获得heads后previous失败，deinit各自释放。matcher只借caller input，deinit不释放history/block。plan成功和emit结束都reset引用；plan错误时defer释放其arrays即可，不会访问过期borrowed数据。

fixedoutput allocator.alloc发生在plan完整成功且fixed获胜之后；其独立allocation不会与仍live的input别名。emit没有error-return/fallibleallocation，故outputalloc后无需额外errdefer处理不存在的recoverableemiterror；正常所有权移交给caller。allocator须遵守不把liveinputstorage重叠分配给新output的基本契约。

全public调用仍同步且input不可在两遍之间外部修改；helperemit明确要求input/output不重叠。Into/Append不会把calleroutput直接传此helper：

- Into仍encodeAlloc到独立temporary，成功后检查outputsize再copy。too-small/配置/OOM期间output不变；input/outputoverlap也在temporary完全读取后发布。
- Append仍先encodeAlloc完毕，再ensureoutcapacity，再append。input可为out.items全部/子slice；即使ensure使原out搬迁，input已完成两遍读取。appendfailure不发布partialitems，temporarydeferfree。
- Stored wrappers执行body保持，未扩展其直接Intoalias契约。

matcher显式workspace393216字节固定，wholefixed/stored最终result由inputsize决定。没有input clone、tokenplan或固定候选分块buffers，但不能把整个publicIntopeak说成仅workspace：还包含temporary完整encodedresult和calleroutput。

## 选项与错误优先级

nice_length由u16扩为u32，default仍128；只拒>65538，0/1/2旧有效首合法matchstop语义保留，max_chain0保留literal-only。nice_length不是lengthcap，实际匹配可完整extend65538。

当前encoder:39先拒invalidnice，再encoder:40计算encodedBound，再matcherallocation。故InvalidBlockPlan优先于stored bound arithmetic/OOM；对于全部旧u16value，这个新invalid域不存在，所以没有改变旧有效选项的错误优先级。早期架构提出“bound先于新增invalid”是建议，已被当前实现明确的nicefirst顺序替代；不能在文档中反过来描述。

validoptions的encodedBoundIntegerOverflow仍早于所有allocations/输入读取；matcherOOM早于实际fixed/storedoutputallocation；Into仍先完整encode再OutputTooSmall，不承诺smalloutput早于OOM。QA已明确invalidoptions在refusingallocator下不allocation，并检查publicoutput不变。

## 已有QA证据与限制

只读复核 `/tmp/vort-deflate64-one-shot-20261025/codec-debug/result.json` 和 `codec-x86/result.json`：两者source_before/after匹配两候选、QA、bit_count及sharedhelperSHA，source_stable=true、exit_code0，分别99/99通过。命令为src/deflate64.zig Debug native，以及ReleaseFast `-target x86-linux-gnu`；这些是producer已有结果，不是本轮执行。

QA有独立bit-reader/token字段检查、自家decoderroundtrip、forcedfixedstream与wholeglobalstored选择比较、actual65538length/65536distance、multi128KiB、nice0/max_chain0、outputsentinel/overlap/Appendalias与allocatorfailure。nice<3的wholefixedstream比较跳过（streamAPI自身拒<3），但one-shotroundtrip/inputunchanged仍检查。

99tests和x86通过证明相应fixture行为，不等于所有integergeometry或平台/ratio最优，也没有验证4GB模型的物理编码。外部reference ZIP/UnZip差分、publicdocs/tools及更广验证由父任务独立完成；本报告不重复运行。

下一步：父任务明确上述fixedbyte窄化与storedfallback契约；如果修正源码，冻结新SHA并只重审该capacity数据流，再结合producer相应verification。其余当前核心契约没有发现需改源码的阻断问题。

最近取得系统时间：2026-10-25 12:30:37 UTC / 2026-10-25 20:30:37 Asia/Shanghai。
