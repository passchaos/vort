# Deflate64 增量 fixed/stored 最终核心只读审计

当前结论：在 Encoder 验证的有界参数和内部调用前提内，未发现匹配环、完整 length/distance wire、精确块成本、pending 容量、状态提交、sticky failed progress、生命周期或 flush 历史幂等性的阻断缺陷。发现一项非阻断 ratio 限制：greedy 接受所有长度>=3的匹配，并不做单 token 收益筛选；adaptive 的完整块成本仲裁仍正确。

本报告是源码审计，不是编译/测试通过证明或性能接受结论。本轮没有编译、运行测试、计时、修改源码或进行 Git 操作；只读核心/ZIP/QA，并写此 `/tmp` 报告。

## 精确来源与审计期间的类型限定修正

工作树：`/home/passchaos/project-z/vort-brotli-context-cache`。

| 文件 | 本轮最后审计 SHA-256 |
|---|---|
| `src/deflate64/stream_encoder.zig` | `597a2959ece1ce4335b1ef5e9846af4aac64e7fb74cbbd1cf1091d43293d834f` |
| `src/deflate64/stream_blocks.zig` | `1b888cee9cbd786bfd9b3bea66b98415200ee88a2f424de76d8bfe19c506558e` |
| `src/deflate64/stream_match.zig` | `13879c9f5dcf45cecd1ae2d9cc7e7400db3748bae45f568dd49340706e4ae76b` |
| `src/zip/incremental_writer.zig` | `918adb223db122b1557ba45e2bdeb00d79e36b426161936de4c3933e52a468a3` |
| `src/zip/incremental_writer/codecs.zig` | `51e04675c10e6ddbe0c66213970a3b9594b8865f6972557bd3fb6c24428143a5` |

最初指定 encoder SHA 是 `b5111e668233acc3a84a460e36ec407bd9818ce457131d7bf0bfa852154d8611`。审计过程中它变为597a：只把 fatal_error、Options.compression、函数返回类型改为 `stream_encoder.Error/Compression` 全限定名。将这几处限定名还原后，重算 SHA **精确等于 b511**，所以没有算法、状态机或执行 body 变化；报告已补读597a，而未把旧SHA直接当新源码认证。blocks/match/ZIP两源均维持指定冻结SHA。

QA 正由父任务修正/编译；本轮只读其覆盖意图，不认证QA冻结版本或测试成功。

## 有界坐标、索引与最大距离

`stream_encoder.zig:12,91–94` 限 block_len 为1..131072，`stream_match.zig:5–6` 明确 history/window=65536、max_match=65538。Matcher 每次 begin 使用 block-local 的 history+block 坐标；总长最多196608，合法 position<=196607，远小于u32哨兵maxInt。全局 stream counters 不进入候选差值，32位目标也不会因流累计长度影响匹配算术。

`stream_match.zig:40–49` 三字节 hash 在读取前检查 position+3<=history.len+block.len；乘法 `*%` 是显式 hash wrapping，右移17使 key 处于32768-entry heads范围。begin 清 heads 为invalid，并插入全部历史位置；历史末端 anchor可以读本块最初字节，因此没有永久遗漏跨history/block边界的末2个hash位置。

search 在当前位置插入前进行（`stream_blocks.zig:58–69,84–88`）。对当前P，任何仍可达候选 C>=P-65536 的 previous slot，在C插入后尚未被C+65536重写；最大距离恰好65536的槽要等P插入时才覆盖。候选链从较新位置指向较旧位置，C<P且距离<=65536才会读取 previous；过期候选在读取其可能已覆盖的slot前立即停止。只从已插入head访问链，所以 previous的未初始化尾部不被读取。

find 的 available/limit确保 position+length 在history+block范围内；candidate<position，所以 candidate+length也在范围内。逻辑byte访问允许candidate extension进入当前block，支持length>distance的重叠匹配。length以usize表示完整65538，distance以usize表示完整65536，没有窄化成u16零或缩窗至65535。

max_chain只限制访问量；0是QA明确验证的literal-only模式。nice_length验证3..65538。相同长度保持head遍历遇到的首个候选，规划和重放顺序完全一致。

## 精确 wire 和块成本

`stream_blocks.zig:129–146`：length258=284+5位/value31，259..65538=285+16位/value(length-3)，最大extra=65535；distance65536=31+14位/value16383。literal/EOB与distance固定codes复用现有Huffman表，没有动态格式近似。

fixedPlan的3位header+7位EOB与literal/match所有额外位都精确计入（52–72）。writeFixed在同样history/block/options上再次begin、find并插入同样的每个消耗位置（75–91），不会借用上一轮终态索引，也无保留token数组；所以计划bits/stats和实际emit一致。

storedBits正确计入当前q的首3位header对齐、32位LEN/NLEN、payload与后续每片40位头（99–102）。128KiB输入最多拆3片，每片<=65535；只有最后片可带BFINAL（104–117）。fixed中间块不align，partial只发10位empty fixed，sync/full的empty stored对齐；final在最后EOB后align一次。

`stream_encoder.zig:294–303` 非final比较完整连续bits，final比较含最后byte padding的pendingBytes；严格更小才选fixed，相等保留stored。它没有拿单独终止/对齐的流做多块仲裁，也没有沿用旧one-shot encodedBound作pending容量。最大forced-fixed位数可用9*131072+10界定；含旧q<=7的最终pending最多147459字节。stored/adaptive对应当前块的pending最多131088字节。

Writer.bits每次count<=16，旧bit_index<=7，u32 scratch可容纳最多23 live bits；所有实际value已被code/extra范围约束。逐完整byte输出/右移后只保留<8bits，align输出一byte并清state；plan/pendingBytes给出的精确容量涵盖全部写入。unchecked helper算术依赖Encoder有界block前提，不扩展为任意巨大slice的公共保证。

### 非阻断：单token收益限制

matcher/fixedPlan选择所有length>=3的匹配，没有literal-vs-match收益筛选。三个0..143字节literal为24bit；distance需要14extra时，length3的匹配为7+5+14=26bit。该合法token会增加2bit。adaptive仍使用包含这26bit的完整fixed成本与stored比较，所以不会破坏块仲裁或容量证明；forced-fixed可能比带收益筛选的greedy方案更大。

这属于后续ratio优化边界，不能声称当前greedy每个match都节省bits。若未来加入profit filter，规划和重放必须共用同一规则，并测真实literal codes的8/9位总和，不能只用固定24位估计。

## pending、分配与状态提交

Encoder先完整drain旧pending，再接受当前call的有界plain。旧pending未排完时立即need_output；output.len=0至多接受/生成一个有界事件，随后pending未排完即返回，不会循环生成第二个未排出的block。

writeDataBlock先计算成本与checked累计统计，ensure matcher、preparePending精确预留、ensure history容量（286–305）；随后Writer只在已经admitted的pending allocatedSlice内无失败生成。直到writer.len==required后才发布pending.items.len、bit state、统计，再保留history、reset matcher引用、清plain（307–325）。writeBoundary也先预留/checked统计，再一次提交（327–343）。pending部分drain不会重新规划或再次增加block/match统计。

规划临时改变matcher；preparePending/history分配若失败，bit state、已提交统计、history内容和plain内容还未commit该事件，pending live len仍零。分配容量/临时索引可能已变化，失败会sticky，不允许继续使用它来恢复半次编码；reset重新清语义状态。ensure若heads分配成功而previous分配失败，deinit分别释放已有allocation；reset保留部分allocation，下次ensure可补全。

显式最大owned allocation payload为heads131072+previous262144+plain131072+history65536+forced-fixed pending147459=737283字节；不随输入总量增长，不包含allocator bookkeeping/struct/stack。reset/较小options会保留旧capacity，但仍在各合法options的全局硬上界内。max_pending_output_len约束live完整输出bytes，不能把它误说为reset后所有retained capacity都会缩小。

## admission、sticky failure 与 overflow

当前源明确选择**整个offered slice预检**：总input+offered采用checked add，先检查pledge/max_input/options，再drain或consume（182–205）。超额offer即使本次本可只接受允许前缀也报错，且0progress；这与本轮QA吻合，是当前API语义。不能把早期架构建议的“按实际接收前缀quota”写成已实现行为。

plain allocation成功后才append/增加input计数；accepted take<=已经通过checked admission的offer，因此total_input+=take安全。pending drain每次先checked total_output+take，再copy并更新offset/progress（208–214）；overflow这一段不会发布新bytes。block/fixed/stored/match累计统计和boundary统计在emit前分别checked。last_step_progress两字段始终<=本次input/output slice长度。

首次step error保存fatal_error及此次已实际复制/排出的last_step_progress；以后step在重置progress或读取input/output前直接返回同一error（186–192）。failedProgress与snapshot因此保存首次失败call的真实承诺进度，而不是错误地归零或重复计入。所有flush请求与finish在fatal状态下不改语义状态，reset才清failure/progress/counters；reset保留allocator/options/pledge及owned capacities，resetExactSize明确替换pledge。

snapshot.last_error_name来自@errorName的静态字符串；没有caller input或临时writer引用。option midstream缩小block导致plain超过新block_len时会InvalidStreamState并sticky，不会下溢计算room。

## 引用与生命周期

所有caller输入都复制到Encoder自己的plain，不保留caller slice；pending属于Encoder，Writer只在同步emit期间借用它。Matcher.history/block临时引用自己的history/plain，正常事件末尾reset引用后才clear plain；deinit只释放matcher heads/previous，不释放借用history/block。

规划后history reserve发生在replay begin之前；replay重新传入当前history.items。首次history allocation时旧hist为空，后续正常hist已保留65536容量，不依赖可能失效的旧hist引用来emit。即使allocation error保留临时matcher refs，Encodersticky期间不再访问，reset/deinit安全清除；没有跨call借用caller内存的生命周期问题。

## flush历史与幂等性

每次新接受输入把flush_boundary置none。block结束nonfinal数据块而不align，保留history；partial发一个empty fixed并记录partial，重复partial不重发；sync发一个empty stored并记录sync，重复sync不重发。自动nonfinal数据block和普通flush均通过retainHistory保存最后65536字节。

full发与sync相同的byte boundary后清history/matcher一次（252–258）；boundary已为sync时，fullFlush直接清history，并在sync仍排出时把mode升级full，避免第二个marker（168–174）。marker pending排完后只结束mode，不再次发marker。已完成sync的full升级不需要新wire；重复full清空同样空history而不增加块/输出计数。fatal/finishing/done情况下请求均受guard。

finish等待已有flush/pending结束，校验pledge，再生成一次BFINAL事件。final_written防止重发，done只在其pending排完后发布。正好填满的最后plain保留到新input/flush/finish决定BFINAL，所以input/output chunking不会改变自然block边界。

## ZIP失败进度桥接与snapshot边界

`codecs.zig:263–268`仅Deflate64暴露failedProgress，Options/State/init/validate均接新IncrementalEncoder。ZIP普通/ZipCrypto/AES caller直出codec catch（writer:620,665,953–989）先检查failed input/output范围，对已写caller output加密正确prefix，再按同一progress增加CRC/entry input/compressed bytes/archive output；随后外层writer poisoned，不能再次计同一progress。

PKWARE强加密bridge catch（789–802）只把已写的codec_output prefix保留到bridge并计CRC/accepted input；这些尚未加密给caller的bytes不增加archive/compressed output。此前已经由encryptor发布的bytes仍由accountPkwareOutput计入。这个区分正确；不能把原codec failed output数直接加入加密archive output。

这里审的是新增failed-progress接线及其直接路径，不宣称完成所有既有ZIP全局计数/所有encryption错误的独立审计。

**现有ZIP/codec snapshot是诊断计数，不存在恢复clone接口。** 父任务已确认NoClone；本实现不需要新增deep clone，也不应把历史条件建议写成已存在/本轮已完成的snapshot持久化能力。

## QA边界与父任务收尾

只读QA显示独立bit cursor/固定symbol解析器检查wire、完整65538长度/code285与65536distance/code31、258/code284、三种compression、chunk/backpressure、history/flush、sticky failure/progress/reset、allocator failure与literal-only max_chain0。QA reset参数正在修正，编译由父任务统一；本报告没有运行或认证这些测试结果。

仍应由父任务完成并以相同SOURCE SHA保存：Debug/ReleaseFast/真实x86参考oracle、ZIP集成failed progress和加密路径、外部UnZip method9差分。额外有价值的窄验证是q=0..7的fixed/stored exact capacity/tie矩阵，以及sync marker部分drain中升级full的幂等fixture；不得仅用round trip替代这些状态/容量断言。

当前源码结论不构成性能声明。单token收益筛选与每块两次完整匹配的CPU成本留作后续独立ratio/吞吐工作。

本轮最近取得系统时间：2026-10-25 11:45:46 UTC / 2026-10-25 19:45:46 Asia/Shanghai。
