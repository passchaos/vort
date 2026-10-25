# Deflate64 full-window index ELF 差分审计

审计时间：2026-10-25T21:34:55.986476+08:00，Asia/Shanghai。只读两份final common probe、源码和已有build记录；未编译、运行benchmark、修改源码/冻结工具或Git。输出只写/tmp。本审计用于选择小范围优化试验，不证明父代理报告的约3%负向计时由某条指令造成。

两个SHA匹配：old `a92ef667374a061b0809a53bd0e5fc174df9be31373c85c8e406cb39491edaf2`，new `6333face63d9ecbcc93211b6e65808df83e21917a76af4d38013a3207de6c8a2`。实际构建记录为 [probe-builds.json](/tmp/vort-deflate64-index-capacity-20261025/probe-builds.json)，两个ReleaseFast构建exit0，源码before/after stable；共同tool SHA是`50e0ef9c3334a7677f07d37866d69af17ad0303e494bee2166ff3ec3ad32f573`。New matcher source为a149d36c…，stream_blocks/encoder源码两边相同，one_shot仅capacity准备路由不同。没有重跑已有计时。

## 机器码结论

Full65536 ring时旧常量mask和新dynamic mask语义相同，但new实际没有把previous.len或完整mask提升到查找/插入循环外。

Matcher.find链继续位置旧`0x1091aee`用movzwl r15w得到first&65535；新`0x1091a7e`加载self+0x18的previous.len，`0x1091a81`减一，`0x1091a83`AND first，再`0x1091a8a`读previous link。该序列位于candidate backedge内，每次继续链都会再次执行；没有新增helpercall或allocation。Distance≤65536及length≤65538边界两边保留。

但findmask只在需要继续链时执行。Defaultnice128的Q×65539 fixture很可能首个长match就提前返回，跳过这个tail；因此不能把findtail静态增加当作该case约3%原因。这里只定位潜在差分，未测任何branchcounter。

## 更直接的insert差分

Insert已内联于fixedPlan和writeFixed；matched-byte重建循环和history preload保留dynamic容量读取：

| 位置 | old | new |
|---|---|---|
| fixedPlan matched insert | 0x1091de9 movzwl si,esi | 0x1091d89 load len，add，ANDposition |
| writeFixed matched insert | 0x10917c6 movzwl dx,edx | 0x1091746 load len，add，ANDposition |
| fixedPlan history preload | bounded position直接索引 | 0x1091b4d load len，add，ANDposition |

New汇编形式是previous.len加hoisted0xffffffff再AND current localposition，而非每次单独DEC。Position范围小于2^32，因此与len-1 mask等价；fixedPlan `0x1091af7`只提升了这个常量operand，未提升previous.len load/add后的mask。每个validinsert依旧load metadata。Full-ringconst specialization可针对这些序列，而不是仅改findtail。

## Allocation边界与small path

Old one-shot matcher fullindex的ensure在encodeAlloc内展开，alloc调用`0x105fb44/0x105fb87`。New `0x105fbd6`调用独立ensureForSize（`0x1091eb0`）：clamp span到65536、LZCNT/SHLX power-of-two容量计算、已有capacity判断及条件alloc/remap仍在。它位于每planning chunk准备边界，不是匹配内层循环。

Repeat65539首chunk的required ring由静态几何得65536，与旧capacity相同；fresh matcher.previous.len=0不会走remap。Standaloneboundary和capacity数学可能值得优化，但没有cycle证据说明它造成计时差异。小span仍需要dynamiccapacity；没有新增rawinput clone或匹配内层heap分配。

## 完整输出消费真实保留

两份encodePass均为365 B；地址归一化后的100条instruction相同。Old `0x1063a5d`、new `0x1063a3d`实际调用各自encodeAlloc；caller保留bulk和remainder全wirebyteweightedwrappingchecksum，随后free并返回mix。该结论来自实际ELF，而不是仅凭源码noinline。

EncodeAlloc也保留plan/emit：oldfixedPlan `0x105fc30`、writeFixed `0x105fe80`；newfixedPlan `0x105fc1f`、writeFixed `0x105fe50`。WriteFixed实际wirebyte stores与bit/outputstate更新仍在，没有变成仅size返回。计时scope是encode+完整outputchecksum+free，不能描述为纯codec throughput。两边消费相同不意味着它的耗时或编译布局对统计完全无影响。

## 建议与限制

可试在full65536 ring时于loop外选择const-mask路径，保留smaller-power-of-two dynamic分支；find和所有inlineinsert必须使用一致geometry。再核最大distance65536、跨chunkhistory、wireexact一致、allocator/资源contracts，最后用新pinnedELF和隔离计时评估。没有建议恢复所有小输入fullindex来换取局部简化。

没有测速度、branchcounts、heap/RSS或stackpeak。Symbol大小、指令差分、helperboundary均不能单独证明父报告~3%是稳定或由mask造成。当前发现足以指导boundedvariant，不足以作统计因果声明。

[JSON](/tmp/vort-deflate64-index-capacity-20261025/full-window-review.json)和focused证据：

- [旧constant findmask](/tmp/vort-deflate64-index-capacity-20261025/full-window-evidence/old-find-constant-mask.asm)、[新dynamic findmask](/tmp/vort-deflate64-index-capacity-20261025/full-window-evidence/new-find-dynamic-mask.asm)
- [旧plan insert](/tmp/vort-deflate64-index-capacity-20261025/full-window-evidence/old-plan-insert.asm)、[新plan insert](/tmp/vort-deflate64-index-capacity-20261025/full-window-evidence/new-plan-insert.asm)
- [旧emit insert](/tmp/vort-deflate64-index-capacity-20261025/full-window-evidence/old-emit-insert.asm)、[新emit insert](/tmp/vort-deflate64-index-capacity-20261025/full-window-evidence/new-emit-insert.asm)
- [消费instruction比较](/tmp/vort-deflate64-index-capacity-20261025/full-window-evidence/encodePass-instruction-comparison.json)

下一步由父代理/实现worker选择exactvariant并联合验证；本审计不修改任何库或工具。
