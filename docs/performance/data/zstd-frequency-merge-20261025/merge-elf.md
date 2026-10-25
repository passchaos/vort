# Frequency merge ELF 审计

审计时间：2026-10-25 15:20:25 +0800（Asia/Shanghai）；2026-10-25 07:20:25 UTC（UTC）。仅读取指定 ELF、nm/objdump、源码和已有构建/样本 provenance；新文件只写 `/tmp`，未编译、运行 benchmark、修改源码或 Git。

## 结论

指定 micro ELF 中，`scalarReference` 的合并和 active 计数两遍真实保留；`mergeActive` 降为 AVX2 单遍合并并计数，完整输出写入保留。两条 query 每次都完整读取四行 4096 B、完整写入 256 个 u32（1024 B），没有越界；单遍路径从 merged 寄存器计数，无计数目的的输出重读。

指定 new public encoder 同样保留该向量合并计数循环，内联到生产 `zstd.emitMultiDuplicateMatchCompressedBlockWithFirst`。active 用于 raw/RLE 和 Huffman 门槛，频率输出被完整复制并供后续 planner 使用，均未 DCE。公共候选路径还包含 prepared-frequency 的复制、certificate 分析及 active-symbol 列表构建；“单遍”只指合并与 active 计数本身。没有提供旧 public ELF，不能把 micro scalar lowering 当成旧公共 encoder 的实际 lowering，也不据此推导速度排名。

## 产物与来源

- [JSON](/tmp/vort-zstd-frequency-merge-20261025/merge-elf.json)
- [scalar exact asm](/tmp/vort-zstd-frequency-merge-20261025/merge-elf-evidence/micro-scalar.asm)、[merged exact asm](/tmp/vort-zstd-frequency-merge-20261025/merge-elf-evidence/micro-merged.asm)、[nm](/tmp/vort-zstd-frequency-merge-20261025/merge-elf-evidence/micro-symbols.nm)、[timed query 调用点](/tmp/vort-zstd-frequency-merge-20261025/merge-elf-evidence/micro-query-call-sites.asm)
- [micro 地址逐操作枚举](/tmp/vort-zstd-frequency-merge-20261025/merge-elf-evidence/micro-address-enumeration.json)
- [public exact asm](/tmp/vort-zstd-frequency-merge-20261025/merge-elf-evidence/public-emit-multi-duplicate.asm)、[public merge 与消费者](/tmp/vort-zstd-frequency-merge-20261025/merge-elf-evidence/public-merge-and-consumers.asm)、[public 调用点](/tmp/vort-zstd-frequency-merge-20261025/merge-elf-evidence/public-emit-call-sites.asm)、[public 地址枚举](/tmp/vort-zstd-frequency-merge-20261025/merge-elf-evidence/public-address-enumeration.json)

| 对象 | SHA-256 |
|---|---|
| micro `/tmp/vort-zstd-frequency-merge-20261025/micro-bench` | `219978e0cef521e0fa683e718e838d2ebf7ef0bbaad807a919fb564ab2210947` |
| public `.zig-cache/o/01eb2d7a175dc1b159e6dfc0b899550d/vort-zstd-encode-bench` | `c07deeea37166a672abde8d32f897ddcb1dec006a826c46e546f8e9e76ca19d6` |
| `src/zstd/literals/frequency_merge.zig` | `6f5eb4b44e85485d5de3a1e51a2c454689826fa65668cd6910793bdd0fce096c` |
| `tools/zstd/frequency_merge_bench.zig` | `340a5651ac6868688aa65fb58a9a5aa01f660268d93c4ab7a98a3a7a17e0d75f` |
| `src/zstd/literals/cut_histogram.zig` | `6a9d7e4545f2ee075cfef1c1497b5609987820a9d6401848ca2268865711f9ad` |
| `src/zstd/literals/single_cost_cache.zig` | `1fde928e6f6133328dbdf09f9af4b30d8fdf60b162e1968f744327b6825d29e7` |

Micro 已有 `/tmp/vort-zstd-frequency-merge-20261025/micro-build/result.json` 记录 `zig 0.16.0 build-exe -O ReleaseFast`，源码 before/after 一致。构建命令未显式传 `-mcpu`；已有样本 provenance 记录 target `x86_64-linux-gnu`、CPU target `skylake+pku+sgx`、Intel Core i7-10700K，样本 ELF SHA 与本次实读匹配。本审计仅读取该 provenance，不采用其 timing 作排名。Public 使用父代理给定的 pinned 路径和 SHA，实读匹配；完整构建命令由父代理保管，当前源码 SHA 与其给定 final source 对应。

## 数值与逐 lane 顺序

[mergeActive 源码](/home/passchaos/project-z/vort-zstd-frequency-merge/src/zstd/literals/frequency_merge.zig:13) 的表达式是 `((row0 + row1) + row2) + row3`。micro scalar 和 vector 实际都先 load row1，再 add row0、row2、row3，即机器分组 `((row1 + row0) + row2) + row3`；第一对加数交换，后两步没有重新分组。Public 同样如此，但先预载两个 row1 的 8-lane 组，再开始第一组的 row0/row2/row3 加法。因此不宣称实际先 load row0。

实际 scalar `add` 和 vector `vpaddd` 均是 32-bit 普通 u32 加法，没有数值扩宽、饱和加法或运行时 histogram total 验证。对通过 `CutHistogram.init/update` 构造并维护的有效 histogram，每 symbol 四行总和不超过 regenerated length，后者不超过 131072；各频率非负，所有部分和同样不超过 131072，因此不溢出。边界来自 [CutHistogram](/home/passchaos/project-z/vort-zstd-frequency-merge/src/zstd/literals/cut_histogram.zig:8) 的最大块长、初始化和 cut admission；该结论不推广到外部任意修改的恶意 rows。

## Micro 真实 lowering 与访问范围

`query(true)` → `frequency_merge_bench.query__anon_2966`，地址 `0x10bc430`、大小 `0xf6`（246 B）；`query(false)` → `query__anon_2967`，地址 `0x10bc270`、大小 `0xad`（173 B）。源码 [noinline query](/home/passchaos/project-z/vort-zstd-frequency-merge/tools/zstd/frequency_merge_bench.zig:73) 的两个实例不互混。两函数均无 call、无 `sub rsp` 本地预留，只保存/恢复 rbp；这不说明 caller frame、进程总栈、heap 或 RSS。

| 每次 query | 四行输入 logical span | 输入 load operand 数×宽度 | 输出 store 数×宽度 | 计数所需输出 read 数×宽度 |
|---|---:|---:|---:|---:|
| scalarReference | 4096 B | 1024×4 B = 4096 B | 256×4 B = 1024 B | 256×4 B = 1024 B |
| mergeActive | 4096 B | 128×32 B = 4096 B | 32×32 B = 1024 B | 0 |

这些是汇编 memory operand 的访问字节总量，不是 cache/DRAM traffic、带宽或 cycle 测量。标量 memory-source `add` 和向量 memory-source `vpaddd` 都计入 load traffic。

Scalar 合并循环 `0x10bc440`–`0x10bc4bc` 的 rax 为 `0,4,…,252`，共64轮，每轮展开 j=0..3：输入地址 `row*1024 + 4*(rax+j)`、宽4；output `4*(rax+j)`、宽4。随后 `0x10bc4d0`–`0x10bc522` 的 rcx 为 `0,8,…,248`，共32轮，输出地址 `4*(rcx+j)`，j=0..7、宽4。`cmpl $1,frequency` 后 `sbb $-1,rax`：frequency=0 时 CF=1，增加0；任意 u32 frequency≥1 时 CF=0，增加1。返回精确 nonzero count。

Vector rax 之外的 induction 使用 rcx，初值补码 -8；循环体 `0x10bc290`–`0x10bc312` 每轮增加16，更新到248停止，执行值为 `-8,8,…,232`，共16轮。每轮两个组的地址为 `row*1024 + 4*rcx + d`，d=0x20/0x40、宽32；output 同式去掉 row 偏移。首轮每行 offset 0/32；末轮每行 offset 960/992。因此输入恰为 `[0,4096)`、output 恰为 `[0,1024)`，每字节在合并中恰访问一次，无 overread/overwrite。地址枚举逐操作验证集合、次数和边界，没有执行目标程序。

每组先 store merged，然后 `vpcmpeqd` 比较零、`vmovmskps` 取得8 lane的 equality mask、XOR 0xff 转成 nonzero mask、POPCNT 得0..8。rax 保存累计 active，rdx 在第一组 count 后合入上轮 active，第二组 count 最终加回 rax；所有累加在寄存器中，无 output reload。实际为 AVX2 YMM 256-bit、8个u32 lane；`vmovdqu` 及 memory-source `vpaddd` 不要求32-byte对齐，无 alignment check 或 tail。API普通 u32 alignment（4 B）足够。

## Micro 输出 DCE

[预检](/home/passchaos/project-z/vort-zstd-frequency-merge/tools/zstd/frequency_merge_bench.zig:35) 对3种输入形状×64输入比较 active 和完整256-word output；这是数值检查，不能单独证明 timed 路径的 store 保留。[measure](/home/passchaos/project-z/vort-zstd-frequency-merge/tools/zstd/frequency_merge_bench.zig:77) 每次 checksum 只读取一个 output 元素，并有 doNotOptimizeAway；本报告的完整存储结论来自两个 exact noinline query 的所有 output stores 及地址枚举。

实读调用点证明 timed loops 调用相同两符号：例如 scalar `0x10634f0`、merged `0x1063586`，随后各读取 caller output 单元素并累计 active。这些 query 函数的完整1024 B写入仍在，未因 checksum 采样而收缩或 DCE。

## Public 生产路由与生命周期

生产 [frame serial 路由](/home/passchaos/project-z/vort-zstd-frequency-merge/src/zstd.zig:19237) 调用 `emitMultiDuplicateMatchCompressedBlockWithFirst`；ELF 有四个真实静态调用点 `0x115a3fa`、`0x116a59b`、`0x116cb2a`、`0x1171131`，来自 serial-beam 实例。其 [源码 wrapper](/home/passchaos/project-z/vort-zstd-frequency-merge/src/zstd.zig:23268) 固定 cache_costs=true、profile_work=false、mode=.prune；cache admission 要求 duplicate_index=null 且 `4096 < block.len <= 131072`，并先排除纯 RLE/小块。汇编 `0x115aa1d`–`0x115aa46` 保留 null-index 与长度判断。

有 cache 的 hashed finder 经 [payloadForWinner](/home/passchaos/project-z/vort-zstd-frequency-merge/src/zstd/literals/winner_cost_cache.zig:54) 调用 [inner.prepareLiterals](/home/passchaos/project-z/vort-zstd-frequency-merge/src/zstd/literals/single_cost_cache.zig:144)，再经 [totalFrequenciesAndCount](/home/passchaos/project-z/vort-zstd-frequency-merge/src/zstd/literals/cut_histogram.zig:73) 到 mergeActive。单独 prepare/merge 符号已内联消失，证据在生产 emit 符号里，非 micro 示例代替公共代码。

Public emit 地址 `0x115a9a0`、大小 `0x2bff`（11263 B）。实际 merge loop `0x115bfd0`–`0x115c060` 的 rax=-8、+16、stop248，共16轮；每组32 B。行0基址 rsp+0xd00，各行间隔0x400，输入恰为 rsp+[0xd00,0x1d00)（4096 B）；output基址 rsp+0x3c0，完整32个store覆盖 rsp+[0x3c0,0x7c0)（1024 B）。128个输入memory operands，4096 B；32个输出stores，1024 B；merge/count 的计数输出reads为0。函数 rsp 实际以 `and rsp,-32` 对齐，但 emitted vmovdqu 与库API 4-byte alignment契约一致；不据此计算进程总栈。

`vpxor xmm4,xmm4,xmm4` 在 `0x115ae52` 建立零比较寄存器，向前 preparation 区间到 merge 无对 xmm4/ymm4 的重新定义或 call。每轮 rbx 保存 prior active，ecx 得group0 count并加prior rbx，edx持group1 mask，`popcnt edx,ebx` 后加ecx；最终rbx为总active，仍保留：

- `0x115c0c0 cmp rbx,1` / `cmove rbx,r13`：raw literal 长度选择1或regenerated。
- `0x115c124` / `0x115c333 cmp rbx,2`：bound与Huffman门槛；后者在无证书/无需bound时也执行。
- `0x115c0eb`：unique写入prepared rsp+0x2468。

完整output stores的后续使用也保留：`0x115c0e6` 调用 memcpy 长度1024，从merge scratch rsp+0x3c0复制至prepared rsp+0x2480；eligible Huffman分支 `0x115c380` 再以长度1024复制至plan rsp+0x3c8。`0x115c46f`–`0x115c50c` 遍历prepared全部256个频率构建ordered active-symbol list，`0x115c53d` 调用finalizeSmallHuffmanLiteralPlan。scratch rsp+0x3c0 随后复用为planner state，不代表此前频率store被删除。两处memcpy仅在此报告中记录其指针和长度契约，未把它们折算成额外具体load/store指令计数。

## 验证与下一建议

已核对两ELF和关键源码SHA、exact-symbol反汇编、真实query/emit调用点、数学范围、逐操作有效地址的完整覆盖及无越界、active和output消费者。没有新增编译、测试运行或计时；本报告不声称验证整个codec运行正确性，也不推断heap/RSS/进程总栈或性能排名。

下一建议：父代理把本审计与已固定public ELF的family/check结果和隔离benchmark证据合并；如需描述旧public lowering差异，另对旧public pinned ELF做同范围取证。当前increment继续由父代理负责提交、rebase和push。
