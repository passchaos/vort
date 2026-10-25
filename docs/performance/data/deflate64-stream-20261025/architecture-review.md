# Deflate64 fixed/stored 增量编码架构只读评审

结论：建议新增独立 adaptive 增量编码器，保留现有 `IncrementalStoredEncoder` 行为；复用固定 Huffman wire 原语并提取 Deflate64 的宽 length/distance helpers。流核心保留最多 65536 字节滚动历史、一个有界输入块和一个 pending 输出块；fixed 与 stored 必须在当前连续 bit offset 上精确仲裁。现有 one-shot 和两种共享 matcher 都不能直接覆盖完整 Deflate64 上界。

本文针对父任务指定主树 `0cf32f1f` 的只读探索，不是新实现审核或性能结论。未编辑源码、执行编译/测试/基准或进行 Git 操作，只写此 `/tmp` 报告。

## 当前实现与确切 gap

| 位置 | 现状 | 实现含义 |
|---|---|---|
| `src/deflate64/incremental_encoder.zig:7–59` | Codec.State 只有 bit_index=0，writeBlock 只发 stored，最大 LEN=65535；Encoder 为共享 stored.Encoder | 目前没有匹配、滚动历史或压缩块，不能把类型原地改行为而继续命名 StoredEncoder |
| `src/deflate/incremental/encoder/stored.zig:9–198` | caller-owned state、plain/pending、finish/flush、expected size、计数；单块缓冲，先 drain pending | 可参考 progress/背压接口；无需为 Deflate64 功能扩展全部普通 Deflate stored 类型 |
| `src/deflate64/encoder.zig:32–44` | 一次性规划全部输入，再发一个 BFINAL fixed 流；仅当其最终字节数小于 stored size 时保留 | 是 whole-stream 仲裁，不是连续多块仲裁 |
| `encoder.zig:119–129` | lz77.hashGreedyPlanAlloc，window_len=65535、max_match=258 | 超过普通 Deflate 窗口的匹配已存在，但最大距离 65536、最大长度 65538 均未编码 |
| `encoder.zig:132–151` | 固定 BFINAL=1，最后 toOwnedSlice 自动对齐 | 不可按块调用并拼接：会提前结束流并增加不应存在的字节对齐 |
| `encoder.zig:160–191` | lengthCode/distanceCode 参数为 u16，length 仅接受 3..258 | 长度 258 正确发 284+5 位 value31；该 planner 从不发 code285，距离65536也不可表达 |
| `src/deflate64/decoder.zig:213–227` | 285 解码为 3+16bit；distance alphabet=32 | 解码支持 length65538、distance65536，编码仍有差距 |
| `src/zip/incremental_writer/codecs.zig:21,56,89–100,280–284` | options/state/init 均指向 IncrementalStoredEncoder；只验证 block_len<=65535 与 input quota | ZIP method9 的增量写入当前始终 stored，需切换新类型并更新预检 |

探索时源码 SHA-256：

- encoder `57c9cb19fdeb070442b0e4424cc47005950fdf0d61aa5113f82b517b98f01018`
- incremental_encoder `7417caa6cf19aa11ceac88e55f2cf3736959f81efa2ceb88322a468f88ccab4d`
- ZIP codecs `152b5bb07a1d8fb1d74f3a050dcf832fd03e621fe3d193fccbbfd10b0f15aa34`
- lz77 `24187d129ee76e433e3401cbd57556c3bdd7c61cbee585703c3534064b5855af`
- shared stored `dcb6633d112c8c5ed05cb7be091ef8a8eaac4682c88017932f38ab0005fdf918`

## Wire helper 的窄共享边界

建议用 `src/deflate64/codes.zig` 或同等小模块集中完整编码范围、符号及额外位数、fixed bit cost，供旧 one-shot 和新 block writer 共用；不要让 ZIP 实现 codec wire。

- Match.length 与 Match.distance 用 u32 或 usize，分别覆盖 3..65538 和 1..65536；不改 ordinary Deflate 的现有 u16 Token ABI/全局 max_match 常量。
- length 3..258 保留经济的 257..284 编码；258 为284/extra_bits5/extra_value31。length259..65538 发285/extra_bits16/extra_value=length-3；65538 的 extra_value=65535 恰好仍可用 u16。
- code285 在 fixed literal alphabet 中是 **8 位 Huffman code + 16 位长度额外位**，不是18位额外长度。decoder `285=3+readBits(u16,16)` 是确切参考。
- distance32769 为30/extra_bits14/value0；49153 为31/value0；65535 为31/value16382；65536 为31/value16383。参数/中间计算须宽于 u16，额外值本身仍 fits u16。
- fixed literal code 长度：0..143 为8，144..255 为9；EOB256 为7；length257..279 为7，280..285 为8；distance 固定5位。最大 length/distance token 的 bit cost=8+16+5+14=43，可直接精确计分。
- block writer 接受 final 与已有 scratch/bit_index；非 final fixed 不 align，finish 只在最后块/EOB 后补最终 padding。stored 先在当前 bit offset 写3位头，再对齐，写 LEN/NLEN 与 plain bytes。

`src/bitstream.zig:850–925` 已有可共享 BitWriter 原语：writeBitsAssumeCapacity 可在精确预留后无分配写，scratch/bit_index 允许跨块连续位流；不要调用 toOwnedSlice 完成每个中间 fixed block。

## 有界块规划与 exact arbitration

一个实际输入块取 0..B 字节，B 是 options 中有硬上限的目标。若要能在块开始位置编码完整65538 match，至少需65538个当前可用输入字节；严格仅65536字节 plain 而没有额外 lookahead 会把最大可规划 length 截为65536。建议 B 上限65538，或明确65536 target +2 lookahead、允许最后 token 消耗该 lookahead；两者都必须公开真实 retained-input 上限。历史本身固定最多65536字节。

parse 一次，保留 bounded wide tokens（最坏每字节一个 literal，token count<=B），精确累计 fixed cost，再只发选中的表示。初版不必并行构建两份完整候选流或复杂候选缓存。stored 选中也保留同样输入的 history/index 进度，后续 fixed 可以匹配 stored block 中的数据。

设旧 reservoir bit_index=q，0<=q<=7：

1. fixed bits F=3+所有 token exact bit cost+7(EOB)。非 final 保留新 reservoir；final 加 `(8-((q+F)%8))%8` padding。
2. stored 将输入拆成每片<=65535；非空块片数 k=ceil(n/65535)，空块 k=1。第一片增加 `3+pad(q+3)+32+8*n_first` bits，后续每片增加 `40+8*n_piece`；pad(x)=(8-(x%8))%8。只有最后一片可承接 final。
3. 在相同当前 q/final 下比较精确 bits，采用固定 tie policy（例如严格小于才选 fixed、相等选 stored）。不要用两个单独终止流的 alloc 字节长度作 block 成本。

所有 cost/容量加法用 checked usize 或足够宽的计数，再验证转换。预留选中候选的完整 pending-byte 容量后，用 AssumeCapacity 生成；pending 只包含完整可发布字节，残余 bits 属于持续 state，flush/final 才会补边界。

**旧 encodedBound 不能自动继承。** 当前 one-shot bound 为 `n+5*ceil(n/65535)`。若每个65538输入块独立回退 stored，则 n=2*65538 时新布局为四片、20字节头，旧 bound 却为三片、15字节头。需要新 options-aware bound，或统一 one-shot 与新流的实际分块布局；旧 encodeAlloc/encodeInto 在完成这个转换前继续使用旧 bound/旧 whole-stream 实现。不能为方便把新流的输出容量声明为旧 bound。

## matcher 与64KiB历史

现有共享实现都只能作为提取参考：

- `src/lz77.zig:173–327` StreamingHashGreedy：window<=65535；head/prev 为有界持久表；next 以 dictionary/input/absolute stream_start 访问历史，支持 journal；但是 Result.Token 用u16，maxMatch clamps258，不能直接返回完整 Deflate64 token。
- `src/deflate/incremental/encoder/match_finder/rolling_hash.zig:80–111` Matcher：window<=32768，u16 Token，普通 Deflate dynamic_stats/profitability；prev 表也是32768。不能只改 options.window_len 复用。

建议窄提取/参数化 hash-chain 索引、跨 history/current block 字节访问、wide candidate result，而将 token/cost/format-specific stats 留给 codec。可建 `src/lz77/wide_streaming_matcher.zig` 或 bounded generic matcher；优先保留旧 Deflate matcher 行为，避免全局改宽产生无关回归。若首版另建 Deflate64 matcher，应复用这些低层不变量并保持独立 ownership。

- head/prev 只记录 absolute positions，前驱 ring period>=65536；search **先于当前位置插入**，使恰好distance65536仍可见，然后旧同槽位置才过期。
- bounds 为1<=distance<=min(65536,available_history+already_planned_input)，match<=min(65538,remaining_available_input)。length可大于distance，必须支持重叠复制；current block已持有 plain bytes，可通过逻辑 byte accessor 逐段比较。
- 每次提交块，把 history 更新为历史+块的最后65536字节；stored/fixed 都执行一次。history 跨 output drain 保持，不能因为 pending 分多次写而重复规划/提交。
- 哈希至少3字节时要补 seed 跨块边界的历史末2字节 anchors；不能因为上一块末尾缺lookahead而永远漏掉这些候选。
- dictionary 在这里首先指内部滚动 history，不隐含 ZIP 支持外部 preset dictionary。新raw preset API需要decoder相应支持后再公开。
- absolute/input/output positions 的加法和 index casts 检查 overflow，尤其32位目标；不要把distance65536编码为u16零，也不要静默缩窗为65535。

## progress、quota、fatal 与 reset

新增 `IncrementalEncoder`/`IncrementalAdaptiveEncoder` 保持 allocator 与 state 由调用者拥有。options 至少 block_len、max_input_len、max_chain、nice_length；nice_length 类型能表示65538，max_chain>0，block controls 在初始化或 validateOptions 阶段验证。原 IncrementalStoredEncoder 继续原行为以保留已有 exact stored wire 测试。

- step 先 drain pending；只接受有界 plain 空间内的数据。input_read 仅计实际复制接受的 caller bytes，output_written 仅计实际发布字节，未消费 input 必须可原样重送。零 output 不可触发无限规划或接收第二个 pending block。
- 非 final block 边界取决于累计输入与固定目标，而非一次 step 的 input/output chunk 大小；正好填满目标时可以保留块直到看到更多输入或 finish，避免 chunk-sensitive BFINAL/多余终止块。
- max_input_len/expected_size 应针对实际接受量计数，提前验证一次 offered chunk 的全部长度会阻止合法 partial acceptance。现 shared stored `step:117–118` 使用 total+offered length，且 expected mismatch 检查在 append之后（143–144）；这是旧语义，应明确新codec决策并用测试锁定，不无意复制到新adaptive核心。
- 预检 quota/expected remaining 和 checked counters，最多接受允许前缀；达到上限且 caller继续提供数据才报相应limit/size error。finish 校验已接受总长度等于 pledge。
- plan/emit 若在 state 已改变后失败，不能允许用户继续 step 使用半写bitstream或失配matcher。初版可统一保留 first fatal Error，随后所有step返回同一error，直到reset；或者完整事务 rollback。建议预留固定上限 storage，减少中途 allocator failure，再使用明确fatal latch处理剩余错误。
- reset 保留 allocator/options/pledge和可复用容量，清 plain/pending offsets、bits、history长度、matcher状态/absolute位置、输入输出计数、finish/done/fatal。deinit释放所有自己拥有的buffers，不能释放borrowed callerinput。
- blockFlush 只结束nonfinal块；partial为10位empty fixed marker；sync为empty stored对齐；full在同样边界后清history/index一次。不能继续保留旧stored“bit_index永远零”的假设或忘记full的历史reset。

建议诊断 Snapshot 增加 history_len/retained-input/pending bytes/pending bits/fatal 状态；它是计数观察面，不等同于可恢复状态镜像。

## ZIP 接线与 snapshot/deep clone

ZIP owner应只修改类型/生命周期/预检和测试：`codecs.zig` 的Deflate64Options、State.deflate64、init两分支切为新adaptive类型；validate调用新validateOptions及retained-input硬上限，再沿用validateExpectedSize；deinit/finish/step保持codec API委派；`inputLimit`仍使用max_input_len。method9、CRC、ZIP64、descriptor和加密路径不应由codec拥有。

当前 `src/zip/incremental_writer.zig:287–367` Writer.snapshot() 只有phase/counters，没有深拷贝或恢复能力；在本次主树的src/zip及全src clone定义搜索中未定位ZIP state clone实现。父任务若另有snapshot模块/隔离树，需要它的路径再审，不把counter Snapshot当完整checkpoint。

任何已有/新 deep clone 都须同时复制 plain/history/pending live bytes、pending_offset、bit scratch/index、wide plan tokens、matcher head/prev/epoch/init/absolute progress、flush阶段、finish/final/done/fatal、options/pledge与计数。只复制原stored的plain/pending或 `state.*=source.state` 会让新match tables别名、双重free或丢失连续bits。clone用明确allocator并完整errdefer；原/clone任一deinit不影响另一个。若matcher含undefined table tails/epoch无效槽，只复制已初始化内容或先初始化目标，不对undefined数组做全量值拷贝。

ZIP snapshot恢复必须保留codec pending bytes和连续bit reservoir，随后继续相同输入产生相同剩余wire；diagnostic Snapshot无需复制buffer。最低测试是在fixed块的非零bit offset、stored→fixed跨块、pending部分drain和history含65536字节时clone/恢复，分别继续并deinit；加allocator失败测试证明无alias/leak。

## 外部参考：先查本地，现可用解码oracle

先查询了`~/Work`顶级相关目录及整个目录的Deflate64/7zip/inflate64/infback9文件名：没有发现zlib、zlib-ng、zlib-rs、7zip/p7zip或libarchive相关本地checkout；存在`/home/passchaos/Work/zstd`，不提供Deflate64 wire oracle。

- 已安装`/usr/bin/unzip`，`unzip -v`为Info-ZIP6.00，编译选项明确包含`USE_DEFLATE64 (PKZIP 4.x Deflate64 supported)`与ZIP64。可将新raw流封装method9 ZIP，使用`unzip -t`及`unzip -p`做外部完整CRC/输出差分。
- `7z`、`7zz`、`7za`、`bsdtar`均未在PATH。此次不安装、不联网、不创建外部ZIP样本。
- `/usr/bin/zip`为Info-ZIP3.0；`zip -Z help`列出仅store/deflate/bzip2（该探测以Invalid command arguments退出），不能作为method9编码生成器。系统minizip头也只声明store/ordinary Deflate及可选bzip2，不认证Deflate64能力。
- 内部decoder已有手工code285/16bit fixture及65536distance fixture，可作为wire边界测试基础，但外部unzip验证仍必要，不能以自家round trip代替兼容性。

## 有界验证建议与实施顺序

1. 先落实codes helper完整length/distance边界，测试257/258/259/65535/65536/65537/65538长度与32768/32769/49152/49153/65535/65536距离，包含非法0/65539/65537distance。检查helper与fixed cost一致。
2. 新块wire测试：q=0..7全部bit offsets；空/tiny/random/repetitive；fixed/stored交替；n=65535/65536/65538的stored分片；final只在最后piece；full-range285和distance65536的实际token/输出。
3. 新stream测试：输入split1/小块/大offer，输出0/1/小buffer；sameoptions各split完整wire一致；跨block dictionary match、overlap/run、完整65538长度；bounded memory峰值随输入总量不增长；quota/pledge/error latch/reset/flush；allocator failure与32位构建。
4. ZIP owner测试known/unknown/empty size、method9 compressed output确为fixed或stored选择、跨block65536distance、ZIP64/descriptor、现有加密路径；有snapshot模块则加入独立深clone继续。通过外部unzip测试/输出差分。
5. 最后更新public docs/roadmap与输出bound说明。one-shot是否改为新stream core是独立可review增量，先处理分块策略与bound差异再统一。

建议文件ownership：codec worker负责codes/block/incremental模块及codec测试；共享matcher worker只负责其有界新模块/参考差分；ZIP owner负责codecs类型/预检、ZIP及snapshot接线。本文只建议边界，没有创建或指派新agent。

最近取得系统时间：2026-10-25 11:34:51 UTC / 2026-10-25 19:34:51 Asia/Shanghai。
