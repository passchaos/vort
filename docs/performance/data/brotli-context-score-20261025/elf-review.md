# Brotli context cache 普通入口及 ReleaseFast ELF 审计

审计时间：2026-10-25T17:30:38.824038+08:00，Asia/Shanghai。源码为 `/home/passchaos/project-z/vort-brotli-context-cache`，ELF为父代理指定public identity。仅读nm/objdump、源码与已有build/baseline记录；未编译、运行测试/benchmark、修改源码或Git。

## 结论

普通入口确实走 `chooseProposalsCore(false,true)`。实际机器码在chooser中创建一份128-entry memo，四个mode调用顺序复用相同地址，baseline、suffix和cluster均使用它；不是四份同时存在的memo。ScoredMapCache继续按mode局部保存，属于不同key/domain。

普通context评分helper没有ProfileTimer、profile或origin参数，实际无Timer/quality-recorder clock调用或origin查询/发布。普通hits/misses的incq仍保留，不能称所有统计写入均DCE。Origin metadata也没有被证明移除：cache对象的整体memset覆盖其区域，只是ordinary查询/发布逻辑不使用它。

已记录实际internal ABI及各函数的explicit `sub rsp`，但memo初始化范围、Cache@sizeOf和完整调用链stack是不同指标。旧版储存重心在mode callee，新版memo在chooser中长活，因此不能仅看到mode frame缩小就宣称总栈下降。本审计不作heap/RSS、过程总栈、速度或ISA吞吐结论。

## ELF与源码绑定

Public ELF路径：`/home/passchaos/project-z/vort-brotli-context-cache/.zig-cache/o/78f0aed58c7f51384364cb890565eb73/vort-br-planned-encode-bench`，实读SHA：`734570819d2d2c996c492b4bdc1f7f0271bcd6b77db0ec96d1ebe5044af4f0be`，与 [identity](/tmp/vort-brotli-context-cache-20261025/public-executable.json)一致。

已有tool-build/result.json记录source_stable=true；run.log证明两个ReleaseFast native compile步骤成功。组合命令exit1来自public smoke收到diagnostic-only `--rounds/--json`参数而返回UnknownArgument，报告不将它当编译失败，也不声称smoke成功。单独smoke由父代理处理。

| 核心源码 | 本次与build记录一致的SHA |
|---|---|
| src/br.zig | `9405cddaa1c6742a7008b98a22f69fb868db70ae6e64b90c534b265e4a7b528d` |
| literal_context_split.zig | `5e0f139d1a30601e5824bdaade4c23fad1af4de0632fdfe6ed31e79f68a8c458` |
| literal_context_profile.zig | `b6292a1e6427e65a7aeed3433821384cbf57c7400cb89e3ee1a9195b68f770d3` |
| literal_tree_score_cache.zig | `f2b16b331850d6bebcce486a75327648aafd8513b47cdffc7313ad42fa6497b6` |
| quality_profile.zig | `3c9c6b32c3a015d8e3438c464e1bb46b3a52a5bce5a98ca85d1d6fe0e3bf2e8b` |

- [JSON](/tmp/vort-brotli-context-cache-20261025/elf-review.json)
- [ordinary route调用点](/tmp/vort-brotli-context-cache-20261025/elf-evidence/ordinary-route-call-sites.asm)、[nm](/tmp/vort-brotli-context-cache-20261025/elf-evidence/public-symbols.nm)
- [chooser exact asm](/tmp/vort-brotli-context-cache-20261025/elf-evidence/chooseProposals.asm)、[四mode同memo参数](/tmp/vort-brotli-context-cache-20261025/elf-evidence/shared-memo-base-and-four-mode-calls.asm)
- [mode exact asm](/tmp/vort-brotli-context-cache-20261025/elf-evidence/chooseModeFromHistograms__anon_46230.asm)、[同memo消费者](/tmp/vort-brotli-context-cache-20261025/elf-evidence/mode-shared-memo-consumers.asm)
- [tree scorer exact asm](/tmp/vort-brotli-context-cache-20261025/elf-evidence/treeBitCostCached__anon_46145.asm)、[layout/hit/miss/publish](/tmp/vort-brotli-context-cache-20261025/elf-evidence/tree-memo-layout-hit-miss-publication.asm)
- [普通Recorded调用扫描](/tmp/vort-brotli-context-cache-20261025/elf-evidence/ordinary-recorded-call-scan.json)

## 源码和机器码普通路由

[preferred普通分支](/home/passchaos/project-z/vort-brotli-context-cache/src/br.zig:10229)的trace_enabled=false调用chooseProposals；ordinary入口固定Core(false,true)。Public API机器调用 `0x1283bd2`进入falsequality root（`0x1289a50`），quality到lazy `0x128a1f0`，preferred在 `0x1210551`实际调用ordinarychooser `0x120ee00`。没有通过profiled proposal API。

[Core](/home/passchaos/project-z/vort-brotli-context-cache/src/br/encoder/literal_context_split.zig:188)只创建一次Analysis及一次tree_cache。baseline传&tree_cache；四mode遍历继续同ptr。[mode](/home/passchaos/project-z/vort-brotli-context-cache/src/br/encoder/literal_context_split.zig:489)在shared_cache=true时local_tree_cache为void，ScoredMapCache仍mode-local；suffix和cluster传入共享memo。

这份memo只活在一次proposals search的Analysis lifetime中，不跨input保存。Encoder可能进行多次顺序candidate search；单modeAPI也有自己的memo生命周期，不能把每search一份改写为整个encoder永远只有一个缓存。

## 实际ABI与一份memo证据

这是该ReleaseFast ELF的优化后internal ABI，不是稳定外部ABI声明。Ordinary chooseProposals的rdi为caller result/error-union Proposals存储，rsi/rdx为allocator context/vtable，rcx/r8为input pointer/length，r9为commands pointer，callee `[rbp+0x10]`为commands length。Preferred caller传结果storage并在返回后消费proposal/error字段。

`treeBitCostCached__anon_46145`（`0x120c670`）实际只有rdi=result/error-union u64 storage、rsi=frequency pointer、rdx=parent active-support pointer、rcx=cache pointer。Allocator、profile scope/mode和profiler没有进入该helper ABI；source tree scorer的实际下游采用固定工作区，这个specialization消除了未使用参数。

Mode helper `0x120d1b0`使用rdi=result、esi=mode、rdx=mode histograms、rcx=total、r8=literal count、r9=baseline bits；callee `[rbp+0x10]`为active support，`[rbp+0x18]`为cache。ProfileTimer参数不存在。

Chooser `0x120f40e`建立 `rbp-0x20e98` 的memo地址；它对应prologue后的stable rsp+8。`0x120f41f`一次memset初始化0x209b0（133552 B），范围为relative-rbp `[-0x20e98,-0x4e8)`。Baseline `0x120f43b`以rcx传该地址。

| mode | 实际call | cache参数 |
|---|---|---|
| 0 | 0x120f4ce | push r15，此前r15=rbp-0x20e98 |
| 1 | 0x120f672 | lea rbp-0x20e98后push |
| 2 | 0x120f8b5 | lea同一地址后push |
| 3 | 0x120fab5 | lea同一地址后push |

四mode硬件调用展开且顺序执行，返回后恢复16 B outgoing参数。Mode从`[rbp+0x18]`读同指针；suffix的两次tree调用在`0x120d456/0x120d487`，cluster在`0x120e961`，继续相同cache。Mode帧没有shared分支的local_tree_cache副本；未对四mode复制memo内容。

Memo entry机器stride是0x410（1040 B）：hash offset0、bit_cost offset8、histogram offset16（1024 B）；机器layout与源码字段排列可不同。Occupied words位于cache+0x20800，hits/misses位于+0x20810/+0x20818。Lookup先hash，然后比较完整1024 B key（不相等可early-exit）；success后put保存hash、完整histogram、bit_cost再置occupied bit。

`0x120d194`的hits incq和`0x120ca91`的misses incq都实际保留。Cold/conflict classification、cache.origin/getOrigin/setOrigin操作在ordinaryhelper中不存在。Cache整体memset仍包含未使用origin metadata区域，因此这里只证明无origin查询/发布，不能声称其存储或初始化写入完全消失。

## 真实栈预留与边界

| 函数 | 实际sub rsp | 保存寄存器push | 额外说明 |
|---|---:|---:|---|
| quality root | 0xbe8 = 3048 B | 48 B | 不含子函数 |
| preferred | 0x10c0 = 4288 B | 48 B | sub之前and rsp,-32，alignment padding另计 |
| chooseProposals | 0x20e78 = 134776 B | 48 B | 每mode调用另push16 B参数 |
| mode helper | 0x2d5a8 = 185768 B | 48 B | suffix/cluster工作区同帧 |
| treeBitCostCached | 0x6d8 = 1752 B | 48 B | scorer继续有下游调用 |

表中数字是明确指令预留，不能单列一个sub当完整stack。它们不包含call return-address8 B、未列outgoing临时参数、caller/descendant frame、alignment padding或整个进程stack。Memo133552 B初始化range也不是chooser134776 B预留值；本审计没有编译@sizeOf probe，因此不提供单独“Cache类型sizeof已测”声明。

Analysis与memo分开：`0x120ee54`通过caller allocator申请0x40408（263176 B）、alignment8，`0x120ee6c`清零Analysis。它包含四份mode histogram，这是四mode数据，不是四memo。申请参数不表示已测heap峰值/RSS。

已有baseline14所用旧public ELF为q8-profile树的d54ab...，SHA `a6f1f0bb5d4d403605b9989e6006f64b3f44d86fedb87d9215140b9cf216b725`，已实读匹配。旧chooser sub0x3d8（984 B），旧mode sub0x4ddd8（318936 B）；新chooser变大、新mode变小，表示memo存储由modecallee迁到跨modechooser lifetime。不能只选择mode的缩小值声称整个active call-chain stack下降；本审计未测完整峰值。

## 普通无ProfileTimer的实际范围

Core(false,true)与tree评分的profiler类型均为void；source clocks/recordTreeCache、origin和setOrigin由profiled门控。ELF chooser、mode和tree scorer均无ProfileTimer/quality-profile调用、无Io-vtable clockcall。另核public9个Recorded candidate/helper，其实际quality recorder与Clock.now calls也为0。

这不意味着普通完全没有metadata写入：hits/misses、occupied bitmap、frequency key和price存储仍是实际操作。Allocator、ordinarycodecstats、预算API或benchmark outer timer也不因Disabled recorder消失。不能从全ELF存在Io.Threaded.now推断此contextcache路径在做profiling，也不能反过来宣称所有libc clock不存在。

## 验证和下一建议

已核pinned ELF/source SHA、普通调用链、internal ABI、四mode稳定memo地址、完整entrykey/put、hits/misses与Timer/origin操作范围、明确stackreservation及旧存储位置差分。没有重新编译或测试运行；本报告不替代父代理semantic proposals/wire/error/ownership验证。

下一建议：父代理完成单独public smoke及功能/兼容性验证后，合并本报告。若未来需正式Cache@sizeOf或完整stack峰值，采用独立probe并保持指标分离；性能或RSS需要对应的实际测量。
