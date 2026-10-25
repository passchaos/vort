# Brotli dense tree-cost ReleaseFast ELF 审计

审计时间：2026-10-25T18:41:10.750120+08:00，Asia/Shanghai。本次仅查看父代理指定public ELF和冻结kernel源码，保存少量exact/focused汇编；没有编译、运行测试/benchmark、修改源码或Git。本报告为有限路由和lowering证据，不是全输入exact-array证明。

## 结论

普通tree cost实际调用`PrefixAlphabetFor(256).codeLengths`。Active count在129…256时进入新增dense路径：按sorted symbols gather频率到局部scratch，调用256-symbol两队列builder，成功后scatter长度到原symbol位置。Builder的leaves/parents实际使用u16；64/128 specialization继续使用byte indices。

机器两队列比较u64 weight，weight相等时选择leaf；serial/rank关系由leaf排在parent之前及稳定equal-group顺序实现，没有额外“rankcmp”指令。深度超过15时，builder在存储该深度和输出长度之前返回false；caller随即调用原fillTreeLengths256/package-merge路径。没有将过深的natural tree截断后作为成功输出。

256-builder是无call的leaf函数，ABI只有频率slice及输出指针。它复制active频率到栈上u64 weights并构建local indices/parents/depths，没有heap allocator或raw block拷贝；这不代表整个encoder不分配。明确记录了局部stackreservation与leaf red-zone，未据此计算RSS或完整调用链stack。

## ELF与来源

Pinned public路径为context-cache树`.zig-cache/o/7cab685de62cdb93856431f8e3ddb813/vort-br-planned-encode-bench`，实读SHA `9f971543decb34eb391dda765341c28f28da0a8953d73bb8f455ac533942a3f5`，与 [identity](/tmp/vort-br-tree-cost-20261025/public-executable.json)一致。

冻结源码匹配：small_huffman `b23a30082ccce63b785051b61831ab4a297e09c152db6825bd76eed787c99bf7`；command_plan `173cf7e6bc7e784fab80201f5cb696b0f870f4843de35e5999179439e6d9d9f9`。父代理complete-check结束后的全源码绑定和family/check结果仍单独记录，报告不宣称全面passed。

- [JSON](/tmp/vort-br-tree-cost-20261025/elf-review.json)
- [符号记录](/tmp/vort-br-tree-cost-20261025/focusedasm/symbols.nm)
- [threshold/gather/scatter/fallback](/tmp/vort-br-tree-cost-20261025/focusedasm/dense-threshold-gather-scatter-fallback.asm)
- [two-queue/rank/depth](/tmp/vort-br-tree-cost-20261025/focusedasm/dense-two-queue-rank-and-depth.asm)
- [weight与u16 index初始化](/tmp/vort-br-tree-cost-20261025/focusedasm/dense-stack-weight-and-index-init.asm)
- [128-byte-index路径](/tmp/vort-br-tree-cost-20261025/focusedasm/old-128-byte-index-path.asm)
- [dense fallback](/tmp/vort-br-tree-cost-20261025/focusedasm/dense-fallback-to-package.asm)

## 普通Prefix dense route及gather/scatter

普通context scorer为`treeBitCostProfiled__anon_46141`（`0x120e0b0`）；`0x120e17d`实际调用`PrefixAlphabetFor(256).codeLengths`（`0x1175220`）。命名Profiled不表示这个实例开启profile；普通源码 [codeLengths](/home/passchaos/project-z/vort-brotli-context-cache/src/br/encoder/command_plan.zig:122)固定profiled=false、dense_fast=true。

实际`0x11753e3 cmp active,129`/`jae`与`0x1175521 cmp active,257`建立新129…256分支，较小长度走64/128原分支。Large invalid active count仍走generic fallback，而合法PrefixAlphabet(256)支持≤256。

`0x1175a70`开始bulk eight-way scalar gather：读取u16 symbol编号，以它读取original u32 frequency，写compact_frequency stack；remainder在`0x1175b30`。这是scalar unroll，不是SIMD vpgather。Compact frequency基址为Prefix frame `rbp-0x6b0`，compact u4 lengths基址`rbp-0x2b0`。

`0x1175b5f`实际调用256 builder `0x11ba7c0`。Success在`0x1175ce0`bulk及`0x1175ddd`tail读compact length，mask0xf，再按original symbol编号scatter至完整lengths数组；inactive lengths保持原zero初始化。Gathers读取frequency表而非raw input block；这些代码不涉及额外heap input副本。

## 两队列、rank和索引宽度

[buildInternal](/home/passchaos/project-z/vort-brotli-context-cache/src/br/encoder/small_huffman.zig:64)的node index亦是stable serial：leaf indices先于generated parents，parent在两child之后追加。PrefixAlphabet由descending frequency、ascending symbol tie order建立compact rank；kernel从最轻group到最重group填leaf queue，equal-weight group内部保持ascending rank。

机器group扫描`0x11ba91c…0x11baa78`保留frequency equality边界和按rank填写leaves。`0x11baad8`/`0x11bab1c`以movzwl读取16-bit leaf index；`0x11baaf2`比较leaf/parent u64 weights，`0x11baafa jbe`在相等时选leaf。第二pop也保留同类比较。Parent queue从active count开始，按append次序消费，所以weight tie的rank/serial由queue/node顺序实现，未看到也不宣称有单独serial comparator。

256实际数据类型和例证：

| 对象 | 编译后操作 |
|---|---|
| weights u64 | `0x11ba824`写8 B weight；merge读取两个weight相加 |
| leaf indices u16 | `0x11ba82c`写word；`0x11baad8`/`0x11bab1c`读取word |
| parent indices u16 | `0x11baab6`/`0x11baabe`写word；`0x11bab60`读取word |
| depths u5 | byte-addressed local，存入前mask/guard |
| output lengths u4 | byte-addressed输出，mask0xf |

Capacity256最多511个node，最大index510，u16可表达。旧64使用u8 Index/i8 Parent（最多127 nodes），128使用u8 Index/u8 Parent（最多255 nodes）；128实际`0x11bb296`读取byte leaf index，`0x11bb276/0x11bb27d`写byte parents，`0x11bb320`读取byte parent。小路径调用仍为64 `0x11754ff→0x11bb460`、128 `0x117569f→0x11baf80`。已有final-kernel-static-check记录≤128源码路由不变，本次没有重新运行该reference验证。

## Depth guard与package-merge回退

[深度遍历](/home/passchaos/project-z/vort-brotli-context-cache/src/br/encoder/small_huffman.zig:112)逆序排除root，保证parent depth已可读取。先前保存的depth≤15，下一次addition最多16。

Compiler将u5的`depth+1`与`>15`判定降为`0x11bab70 shl3`、`0x11bab73 add8`、`0x11bab76 sar3`及`0x11bab79 js`。在这个0…15 parent-depth域，next16编码为负值，跳到`0x11baba0`返回false；正常depth store是其后的`0x11bab7e`。Final leaf output直到所有depth完成后才从`0x11babb0`/tail复制。因此guard位于新depth store和length输出之前。

Caller `0x1175b64 test al` / `0x1175b66 je 0x1175b81`接收false；`0x1175b8e`调用`fillTreeLengths__anon_35943`（`0x11bac80`）。该helper在`0x11bacdc/0x11badd6`调用`huffman.treeCodeLengths__anon_40857`；[原fillTreeLengths](/home/passchaos/project-z/vort-brotli-context-cache/src/br/encoder/command_plan.zig:316)继续gather到256频率scratch，调用treeCodeLengths(max_bits15)后scatter。

Generic [treeCodeLengths](/home/passchaos/project-z/vort-brotli-context-cache/src/huffman.zig:1243)保留package-merge/compact或backref package-merge政策。本审计证明false路由仍到该bounded实现，不等于证明natural-tree或fallback对每种tie distribution具有相同exact length array。该部分正确性由父代理完整oracle/contract/differential验证负责。

## 内部ABI与有限stack证据

256 builder（`build__anon_35945`，`0x11ba7c0`，1205 B机器代码）的ABI为rdi=compact u32 frequencies、rsi=active length、rdx=caller compact output；bool在al返回。整个函数无call指令，无allocator或raw input pointer参数。内部确实将u32频率扩成u64 weights写栈，这个localcopy不能描述为“无任何拷贝”。

| 函数 | 明确sub rsp |
|---|---:|
| ordinary tree cost | 0x6b8 = 1720 B |
| PrefixAlphabet256.codeLengths | 0x688 = 1672 B |
| builder64 | 0x4c8 = 1224 B |
| builder128 | 0xa00 = 2560 B |
| builder256 | 0x1780 = 6016 B |

256主路径另push保存6个寄存器共48 B；其stable rsp相对于rbp是`rbp-0x17a8`。Parent array写base为`rbp-0x1826`，即rsp下方126 B，在该无call leaf函数red-zone中。因此即使这个kernel，sub6016也不能当所有访问栈字节；表格更不包含caller/descendants、return addresses、outgoing参数或完整调用链峰值。没有类型sizeof或heap/RSS测量。

## 验证与交接

已核pinned SHA与冻结small/command源码、普通treecost→Prefix256→builder256调用、129…256分支、scalar gather/scatter、u16两队列/implicit rank、depth-before-store失败与package-merge回退，并记录有限stack及red-zone。没有全ELFclone分析、重复反汇编或target执行；共保留14份小范围证据。

下一建议：父代理完成当前family/check及最终全源码binding后合并此报告；所有输入的exact length、prefix-code合法性和性能收益采用对应oracle/测试/隔离benchmark证据。
