# Deflate64 one-shot 完整范围与有界两遍编码：只读架构评审

结论：父任务提出的两遍全 fixed 候选与全局 stored 仲裁可复用已发布 stream_match/stream_blocks，并保留现有 encodedBound 的保证。关键条件是两遍使用相同128KiB块切分、同一借用history、连续位状态、每块包含自己的EOB且只在最后块设置BFINAL并align一次。不要把新增量adaptive逐块混合stored策略直接搬到one-shot。

本轮只读探索主树父任务指定 `06d8909c`；没有编译、运行测试/基准、源码修改或 Git 操作，只创建此 `/tmp` 报告。wire选择变化已获父任务明确允许；安全/输出完整性和现有transactional API仍须保持。

## 当前参考与 ownership

- `src/deflate64/encoder.zig` SHA-256 `57c9cb19fdeb070442b0e4424cc47005950fdf0d61aa5113f82b517b98f01018`：one-shot still使用全输入lz77.GreedyPlan、u16 match及window65535/max_match258。
- `src/deflate64/stream_blocks.zig` SHA `1b888cee9cbd786bfd9b3bea66b98415200ee88a2f424de76d8bfe19c506558e`：已发布wide fixedPlan/writeFixed、完整length285与distance31、连续Writer。
- `src/deflate64/stream_match.zig` SHA `13879c9f5dcf45cecd1ae2d9cc7e7400db3748bae45f568dd49340706e4ae76b`：有界history+block局部坐标、65536距离、65538长度。
- `src/lz77.zig` SHA `24187d129ee76e433e3401cbd57556c3bdd7c61cbee585703c3534064b5855af`：仅作旧选项语义参考，不建议改普通Deflate Token/全局常量。

worker只需改one-shot encoder和有界共享helper的必要接口；public exports、docs、工具由父任务，QA由独立owner。已有stream行为、ZIP IncrementalEncoder/NoClone状态不在本轮修改范围。

## nice_length 与 max_chain 的兼容语义

旧 `encoder.zig:13,124–128` nice_length为u16 default128，未经最小值验证直接传入lz77。`lz77.zig:2925–2929,3001–3004`完整保留nice_len，只在更新一个长度>=min_match(默认3)的新best后判断 `len >= nice_len`。

因此：

| 旧选项 | 行为 | 新版建议 |
|---|---|---|
| nice_length=0、1、2 | 首个合法>=3 match即停止继续chain；匹配本身已完整扩展到max_len，不把match截成nice_length | 保留有效；可原值传stream_match或归一化3，二者停搜行为相同 |
| nice_length=3..65535 | 找到达到该长度的更佳match后停搜 | 原语义保留 |
| nice_length=65536..65538 | u16旧API无法表示 | 扩宽u32后支持，匹配范围仍完整65538 |
| nice_length>65538 | 新类型可表达，但超出有效match范围 | 建议拒绝InvalidBlockPlan；不默默clamp |
| max_chain=0 | old hash matcher明确返回无match，literal-only | 保留；不是InvalidBlockPlan |

不能直接调用stream Encoder.validateOptions，因为它拒绝nice<3；one-shot兼容性要求不同。文档中nice是search early-stop threshold，不是最大match长度。default128也能产生65538 match：找到首个run候选后先完整extend，再停搜。

扩大EncodeOptions.nice_length到u32仍可接受旧字面量和可隐式扩宽的u16值；可能改变struct尺寸/显式字段类型，属于API文档需要记录的宽度变化。没有理由借此改默认128。

## 两遍的同一块/历史迭代

块上限B=128*1024，history limitW=65536。offset指已处理input前缀；每次：

1. remaining=input.len-offset，take=min(B,remaining)。
2. end=offset+take。此加法有数学证明end<=input.len；避免写 `min(offset+B,input.len)`，后者offset+B在极大slice时可能overflow。
3. block=input[offset..end]；history=input[offset-min(W,offset)..offset]。
4. 只把history/block传matcher，offset不传入candidate/index arithmetic。

两遍对同一input采用完全相同迭代器/规则。没有全input clone、没有65536-byte history copy、没有u16 Token数组；history就是caller input中已处理前缀的最后65536字节。Matcher使用最多history+block<=196608的坐标，u32 position/candidate与65536ring可保持已审计不变量；整input.len可大于u32，而不造成u32 absolute cast。

空input特别执行一次空fixed块；普通循环结束时不要额外再发一个空final块。所有非空input只在end==input.len的最后块设置final。

matcher.ensure一次、两遍复用heads/previous。每次fixedPlan或writeFixed都begin清heads/reseed borrowed history，previous仅沿已插入reachable链访问；无需copy表/保留pass1 tokens。empty无需ensure；若max_chain0但仍调用现有非空fixedPlan/writeFixed，begin和insert仍要求tables，因此不能仅因max_chain0跳过ensure而触发assert。literal-only allocation优化是独立helper specialization，非本轮必要。

## pass1 成本与全流仲裁

先计算全局旧 `encodedBound(input.len)`，其定义仍是input+5*max(1,ceil(input/65535))，且乘法/加法checked。这个stored size是全局stored stream的真实size，不受128KiB fixed块划分影响。

对每个bounded fixedPlan，plan.bits已经含3位header、全部literal/length/distance extra、7位EOB。最大单块all-literal成本<=9*131072+10=1179658，usize32也可安全；block-local unchecked helper arithmetic只在这个硬上限内调用。

total_bits从0开始，**每块用std.math.add checked累加**。empty的唯一plan.bits=10。最终fixed_size=ceil(total_bits/8)，可用checked `add(total_bits,7)/8`；但更推荐无不必要+7 overflow的精确式：

`fixed_size = total_bits / 8 + @intFromBool(total_bits % 8 != 0)`。

该加法数学上有界；如仍使用math.add便于统一error风格，也没有安全损失。绝不能调用 `blocks.pendingBytes(.{}, total_bits, true)`处理任意全input累计bits，因为该helper的`total+7`没有checked，原安全前提是单有界事件。

若total_bits本身usize overflow，明确返回IntegerOverflow而非wrap、clamp或错误小size。注意这会在某些极大input上早于stored byte bound耗尽usize，因为bits比bytes宽；父任务若要覆盖这种理论输入，可改wide accumulator或byte+tail精确累计，但必须保持checked策略与错误语义，不在本次实现中假设“stored bound能表示则bit sum也一定能表示”。不要为了认证安全在输入扫描前计算未checked `input.len*9`。

只在fixed_size **严格小于** 全局stored_size时分配fixed_size并pass2输出；相等或更大直接调用旧global encodeStoredAlloc/Into。这样所有returned output都<=encodedBound，不重现逐128KiB mixed stored造成extra headers的旧bound陷阱。

**空input不是stored。** fixed=10bits→2bytes（标准empty fixed字节03 00），global stored=5bytes；strict比较应选fixed。empty不需要matcher或plan token allocation；只申请最终2byte输出。

## pass2 连续位流与 exact capacity

以同一matcher+chunks/history/options重放。一个 `blocks.Writer{state=.{},output=fixed_output}`跨所有chunks保留len/scratch/bit_index；每次writeFixed只让last chunk final=true。所有中间块都保留bit tail，不调用alignToByte，不把每个chunk重新建一个state=.{}的writer。最后一次align，再检查writer.len==fixed_size且bit_index==0。

也可每块新Writer借用output尾部，但必须明确传回/继承State并checked累计byte offsets；单writer方案更少边界机会。全candidate已exactsize且helper同源，pass2没有allocation/fallible format解析，可在preflight成功后无失败emit。

Pass1/Pass2两者不是旧lz77 reference policy的bit-exact保留；新match范围、hash/ring、密集insert及每128KiB EOB会改变合法wire，父任务已明确允许。两遍自身必须deterministic一致，并保持全部input bytes顺序和输出正确性。

## 错误优先级与内存所有权

现encodeAlloc先encodedBound，再plan allocations，再candidate allocation；新实现应继续在任何matcher/output allocation之前调用encodedBound，保持极大input的IntegerOverflow优先于OutOfMemory。新nice>65538建议在bound之后、matcher.ensure之前验证，保证确定配置错误不依赖allocator，但IntegerOverflow仍优先。0..2/max_chain0不产生新validation error。

matcher heads/previous使用显式caller allocator，defer matcher.deinit覆盖所有pass1 arithmetic/output allocation errors；ensure可部分成功，deinit必须释放所有已获得arrays。选stored后可保留matcher到return defer，不借它阻塞stored输出；结果slice单独归caller所有。fixed输出alloc后errdefer自由释放；final successfulreturn前不free它。

Matcher.history/block借caller input，输入须在整个同步encodeAlloc两遍期间有效且不被修改。deinit只释放matcher tables、不释放borrowed input。pass1结束到pass2开始不保存指向栈或新分配clone的history；每块重新取得input切片。globalstoredfallback直接读取同一仍有效input。

显式matcher存储131072+262144=393216byte，独立于input.len；无plain/history/token allocation。返回fixed<=storedbound，整体peak包含这393216byte加最终output与allocator元数据；不声称输出allocation也固定大小。

## Into、Append 与输入别名

当前 `encodeInto:69–72`先encodeAlloc到临时结果，全部成功再检查output.len，最后copy。保持该实现可维持任何allocation/error/OutputTooSmall之前output不变，以及input/output重叠时编码先完成、copy后发布的行为。无需为本轮强行directemit。

若未来direct Into，完整preflight与exactsize检查只能解决输出容量与allocation失败，**不能单独解决input/output alias**：emit第一个chunk可能覆盖第二遍还要借用的input或history。需明确拒绝/另走temporary overlap path，并在最后任何publish前完成所有fallible work。本轮保留temporary最小风险，仍不复制全input本身。

当前 `encodeAppend:54–57`先encodeAlloc(input)，之后ensure out容量并append最终bytes；必须保持次序。input可能是out.items的slice，若先ensure导致reallocation，再借用input做pass1/pass2，会read freed memory。temporary结果完成后out reallocation已不影响input。append失败不改变已有out.items prefix/len；不把全fixed output直接写进out的unused capacity并在编码中途发布len。

stored append原行为也保持，不用新逐fixedchunkfallback策略改写它。ZIP one-shot writer:165–167委派encodeAlloc并持有结果，能自然使用新one-shot；无需在本轮改ZIP增量state/NoClone。

## 窄验证建议

- option0/1/2/3/default128/65535/65536/65538与invalid65539；max_chain0 literal-only；default仍能发length65538。
- emptyexact03 00/2bytes，tiny/random全局storedtie/选择，所有output<=原encodedBound。
- input边界128KiB-1/恰好/＋1、多块最后空处理、跨块history65536distance；manual wire解析检查只有最后块BFINAL、每fixed块EOB、最后一次padding。
- pass1每块bits/累计size与pass2writer exactlen比较；roundtrip/独立UnZip method9完整差分；65538length与65536distance实际token。
- input/outputchunk概念不参与one-shot借用chunk切分；不同调用APIAlloc/Into/Append结果相同，wire可与旧版本不同。
- Into too-small、OOM、invalidoptions前output sentinel不变；Append以out.items全部/子slice作为input且故意触发reallocation，oldprefix不变/无alias；into input/output overlap保持temporary行为。
- allocator失败覆盖ensure heads/previous/fixedresult/globalstoredresult/Append ensure，allowned freed；极大encodedBound/checked bit sum/ceil helper边界，32位构建。无需构造会读取越界内存的fake巨大slice来测试 arithmetic，可为纯size helper单独测边界。

本轮最近取得系统时间：2026-10-25 12:20:03 UTC / 2026-10-25 20:20:03 Asia/Shanghai。
