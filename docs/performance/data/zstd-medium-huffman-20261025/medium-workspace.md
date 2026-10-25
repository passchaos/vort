本增量选择了最容易证明旧wire不变的medium back-reference工作区收缩，而没有直接切换packed-count compact128算法。父统一编译/测试/计时；此子任务只完成源码、格式、静态边界与证明。

当前候选源码：`src/huffman.zig` SHA256 `2bfc756f0d0380eeab5f6bc9e268ef14294aa5816dbdb1e039390bdabb682aa3`。只此文件由本代理修改；新 `src/huffman/medium_alphabet_tests.zig` 由测试worker编写，SHA `116c36be76fca2ab20b47f95122f04508978a5bfb027da6cd68e713c715c0a4a`，本代理仅接一个named test。

为何不直接使用旧compact helper：`compactPackageMergeCodeLengthsKnownActive`调用packed multiplicity算法，其equal-weight comparator是反序counts向量；旧medium backref使用(weight,creation serial)。两者weighted cost等价不保证bit_counts一致。按现源码的独立Python小模拟，65active、freq[(i*149+41)%256]=1+(i*7)%9时，symbol25/37的old length6 vs packed7，symbol105的old6 vs packed5，weighted cost均1892。此为静态算法复现，不是Zig测试或计时；测试worker保留了相同tie反例以作实际核对。

实现边界：

- guard仅n==256、max_bits==11、65<=active_symbols.len<=127。
- 新medium wrapper为noinline，避免把medium固定大工作区放进共享known-active caller；没有修改dense>=128策略。
- 原backref engine扩展一个workspace_n与可选known-active来源。原callers仍workspace_n=n、原freqs.*扫描；目标分支workspace128、直接sortedactive list，不创建compact-frequency数组或末尾remap。
- nodes仍写原byte symbol，serial仍按active ordinal生成，output lengths仍[n=256]。比较、配对、merge、选根、linear multiplicity recovery算法均相同。

等价证明：对完整、升序、非零的trusted active list，旧freqs遍历过滤0后的叶子序列与新直接遍历的(weight,symbol,serial)逐项相同。Less仅比较weight/serial，所以第一层顺序相同。每次配对产生相同left/right、weight、serial；归纳可得所有层的current及selected roots相同。两种工作区只改变未使用容量，线性恢复到同一actualsymbol后，256项length向量相同，包括symbol255及holes。新分支没有用packed-count tie。

容量约束（不是实际compiler stack frame、RSS或requested heap）：

| 核心固定local数组 | workspace256 | workspace128 |
| --- | ---: | ---: |
| nodes[w*15]，Node16B | 61,440 B | 30,720 B |
| leaves[w] u16 | 512 B | 256 B |
| current[2w] u16 | 1,024 B | 512 B |
| next[w] u16 | 512 B | 256 B |
| multiplicities[w*15] u16 | 7,680 B | 3,840 B |
| 核心声明容量合计 | 71,168 B | 35,584 B |

[n=256]u4 output另256B保持。以上数组capacity合计，不含std sort内部栈、spills、调用者/sret，也不声称所有这些数组在最终机器码中都同时驻留。函数没有allocator，未增加requested heap。

A<=127、max_bits11：current层长度<=2A-1<=253，next pair count<=126，selected_count=2A-2<=252，容量分别256/128足够。最保守node数<=A+10(A-1)<=1387，小于128*15=1920。indices/serial仍u16安全；actualsymbol最大255，256项输出不变。实际used node prefix与merge工作量仍由A决定，所以缩容本身不保证速度；直接active traversal只免掉扫描256项及零项，提升需测。

父给出的完整输入统计：XML77unique/max_symbol121，source88/max125，均落medium；MR239/max255且极skew，不因此关闭dense或扩大guard。stream_products/4/queries只是每stream平均active，不能当完整alphabet统计。

验证方案：新named helper将medium与旧per-root BackrefTraversal和unchanged treeCodeLengths逐symbol比较；FullWidth packed只比较weighted cost/Kraft。包括65/66/77/88/96/127、holes255/equal/ties/skew/maxu32、7/8/11/15边界和真实XML/source频率。全family与同输入旧wire hashes仍由父安排。源码fmt/diffcheck通过；本子任务未编译、测试或计时，SOURCE_READY不等同最终验证完成。

记录UTC：2026-10-25T05:30:58.741922+00:00。

父级后续验证记录：nativeDebug、nativeReleaseFast、实际x86ReleaseFast各1/1 named测试通过，内部65组oracle；新encoder构建5/5通过。此记录来自父任务回传，本子任务没有重复编译/测试。完整family/check与finalquiet/14wire仍由父统一，尚不声称完成或速度提升。源码继续冻结。
