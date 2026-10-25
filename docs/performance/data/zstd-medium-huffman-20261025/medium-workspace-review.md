# Medium KnownActive Huffman workspace: independent static review

只读审查 `/home/passchaos/project-z/vort-zstd-duplicate-profile` 中的
`src/huffman.zig` 及 `src/huffman/medium_alphabet_tests.zig`。
读取时源码SHA分别为：

- huffman.zig：`2bfc756f0d0380eeab5f6bc9e268ef14294aa5816dbdb1e039390bdabb682aa3`
- medium_alphabet_tests.zig：`116c36be76fca2ab20b47f95122f04508978a5bfb027da6cd68e713c715c0a4a`

结论：**未发现新的容量越界、symbol截断、creation-serial tie变化或旧caller
工作区语义问题。** 本次没有编译或运行测试；测试设计的读取不等于执行结果。

## 分派范围

`treeCodeLengthsKnownActive:1288..1319` 保留0/1以及≤32/≤64的既有路径。
medium条件同时要求n==256、max_bits==11、active count65…127 (:1313)。
medium wrapper是noinline (:1326)，传入
`backrefPackageMergeCodeLengthsWithWorkspace(n,128,...,true,false,active_symbols)`。

128及以上仍走原dense wrapper (:1315)，自然树失败仍回原dense backref fallback
(:1354..1355)。max_bits不等于11、n不等于256也不进入新medium路径。新kernel
不应被描述成替换所有Huffman alphabets或所有位数策略。

KnownActive的trusted list必须按symbol严格递增、覆盖全部nonzero frequencies。
Debug/ReleaseSafe检查长度、symbol范围、非零及顺序 (:1294..1300)。ReleaseFast
仍遵守已有trusted输入契约；没有在新kernel中扩大该契约。校验没有重新扫描整个
alphabet来证明完整性，所以不要将此trusted接口表述为恶意list的通用验证API。

## 工作区容量证明

令active=A≤127。初始frontier C1=A，每一层配对后
`C_next=A+floor(C/2)`，所以所有C≤2A−1≤253，每层pair≤A−1≤126。
max_bits11执行十层package创建，node数保守上界
`A+10(A−1)≤1387`。

| 数组 | 新容量 | 最大需求 / 安全理由 | 旧n256容量 |
| --- | ---: | --- | ---: |
| nodes | 128*15=1920 Node | node数≤1387；子节点来自此前已创建frontier | 3840 Node |
| leaves | 128 u16 | A≤127 | 256 u16 |
| current | 256 u16 | C≤253 | 512 u16 |
| next | 128 u16 | pair≤126 | 256 u16 |
| multiplicities | 1920 u16 | 只初始化/读取0..node_len | 3840 u16 |
| returned lengths | 256 u4 | 原始symbol索引，不随workspace压缩 | 256 u4 |

`workspace_n*max_code_bits≤maxInt(u16)` 在1578有comptime断言。medium所有node
index/serial远小于65535 invalid值。Node.symbol仍u16，实际n256的原始byte编号
0…255完整保留；新kernel没有压缩到128symbol或做最终remapping。

Node.weight仍u64 (:1582)，leaf来自u32 frequency。最多10级成对叠加，在最保守
2^10重复贡献下也仅约2^42，远低于u64上限；near-max u32 frequency测试不会因
新工作区引入u32累加。multiplicity仍u16；一个internal occurrence向其每个叶子
贡献长度，合法最终长度≤max_bits，现有≤max_bits断言保持 (:1670..1683)。

## leaf、tie、merge与恢复保持旧语义

旧入口`backrefPackageMergeCodeLengthsWithRecovery:1557..1565`现在转发
workspace_n=n并传void值 `{}`。WithWorkspace的comptime void分支
(:1608..1615)逐项扫描原freqs、跳过zero，原symbol和连续node_len serial不变。
其他旧caller因此仍有原n容量，不受medium128容量限制。

medium的trusted-list分支 (:1616..1623)依同样递增symbol顺序建立叶子，给相同
frequency相同creationserial。Less仍比较weight后serial (:1591..1598)，medium
bucket_leaves=false，使用相同std.mem.sort。package按同current配对顺序创建，
serial仍node_len，merge仍同`mergeNodeIndexLists:1786..1802`，只改变数组预留
宽度；没有改变比较、tie、package创建顺序或selected_count=2A−2。

linear_recovery=true继续原逆creation-order multiplicity传播，引用子节点的
index严格早于parent。只对nodes使用前缀清零multiplicities，不读取undefined
尾部。output256长度数组先清零，active叶子的node.symbol写回原symbol；absent
字节仍零。旧Traversal reference仍走linear_recovery=false的原栈遍历。

## 测试 oracle 的角色正确

新helper独立保存77-symbol XML与88-symbol source频率；没有导入parent模块，
通过Codec参数调用reference和candidate。它的compare:188..231检查：

- 对active>64：BackrefTraversal逐symbol **exact lengths**。
- scanned treeCodeLengths同样逐symbol **exact lengths**。
- packed FullWidth：只比较独立weighted cost与完整Kraft，不要求不同tie政策的
  逐symbol长度相同。
- absent symbols、max_bits限制及repeat determinism。

65个tied symbols的具体fixture (:258..263)先断言FullWidth和旧serial长度
不相同，然后确认candidate仍等于旧serial。该fixture明确保留此前FullWidth
建议纠正，避免把同成本的另一个code树当作byte-exact reference。

helper覆盖65/66/77/88/96/127，equal/ties/skew/near_max/random和多个seed；
自然skew超过11后检查有限11bit；另测64/65/127与max_bits7/8/11/15。
>=128不是这个新kernel范围，已有dense known-active测试
huffman.zig:2923..2938遍历65…256并与scanned exact比较；没有因这片删除其覆盖。

## 固定数组与真实资源指标分开

nodes和multiplicities容量减半、leaf/frontier/pair数组同样减半，是静态可确定的
kernel workspace变化。两块大数组分别是1920*sizeof(Node)和1920*sizeof(u16)，
返回256symbol长度与caller输入不变。

这不是已测全栈峰值、stack-size multiplier或RSS减少。编译器可能重用不同数组
生命周期、改变padding/spill和wrapper frame；调用链还含plan/cache/FSE等状态。
noinline避免将大工作区直接内联到common caller，但不能由此推断机器码大小或
调用栈峰值。函数没有allocator，也没有新增heap请求；requested-heap统计不会
体现这些栈容量变化。RSS还包含code、input、launch、页驻留等，需独立测量。

父任务可继续既有专项和实际quiet复测；本报告没有对速度改善、总栈或RSS作
测量断言。审查时间：2026-10-25 13:31（Asia/Shanghai）。
