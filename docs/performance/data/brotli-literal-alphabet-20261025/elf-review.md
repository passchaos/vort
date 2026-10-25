# Brotli context alphabet sorting ELF 审计

审计时间：2026-10-25T19:15:28.034509+08:00，Asia/Shanghai。仅读父代理指定public ELF及两份冻结源码；未编译、计时、运行测试、修改源码或Git。本报告限定ordinary tree-score排序路由、lowering和局部scratch，不作全输入exact-output证明。

## 结论

Ordinary tree scorer的`buildTreeAlphabet` wrapper确实使用新literal_alphabet模块。Support<64时保留inline reference insertion；support≥64时调用独立large helper，过滤nonzero后仅live≥64且未已排序时使用radix。Large support/live不足、already-ordered和uniform-byte skip都有实际分支。

Radix keys保留完整u32 frequency，执行四个frequency-byte LSD passes，uniform字节可跳过；symbol低字节不再额外排序。实际digit extraction、counts、prefix和scatter均为scalar或scalar unroll，vector stores只用于scratch清零，不能称SIMD排序。

Frequency读取仅按support或已过滤live symbols索引进行，不无条件遍历整个256-frequency表。支持集严格ascending/unique是caller契约，ReleaseFast并没有把debug assertion变成任意恶意support的验证。Under contract输出live symbols唯一，frequency-descending且ties按symbol升序。

大型scratch隔离在noinline helper中，small support不传递该workspace。Large helper实际sub5656 B并多了一份compiler count copy；声明5120 B并非实际frame。任何helper栈数字都不是完整call-chain peak、RSS或性能证据。

## 来源与有限证据

Pinned public path为context-cache树`.zig-cache/o/1928ccf0f65566cb15f468f5a8857ce6/vort-br-planned-encode-bench`，实读SHA `60204e9a3b332da25ebd9c738d481a5f307adf731ac74846c7b38747e3d2b839`，与 [identity](/tmp/vort-br-context-alphabet-20261025/public-executable.json)一致。冻结模块literal_alphabet SHA为`66ecc843530b925666f93f6c2983a056668d95a8f7f978ce680940b111e475c7`；literal_context_split SHA为`37d886fd412ac3ae7444ca4d73549f6aa80d49f6f5a28db36ffdb717eca8edcf`。

这确认指定ELF与本次源码取证，完整check/family及全源码before/after绑定仍由父代理报告。本审计没有读取或采用benchmark timing作性能判断。

- [JSON](/tmp/vort-br-context-alphabet-20261025/elf-review.json)、[nm](/tmp/vort-br-context-alphabet-20261025/focusedasm/symbols.nm)
- [普通small/large路由](/tmp/vort-br-context-alphabet-20261025/focusedasm/ordinary-small-and-large-route.asm)
- [large过滤、key和live阈值](/tmp/vort-br-context-alphabet-20261025/focusedasm/large-live-filter-key-and-threshold.asm)
- [四frequency-byte skip gates](/tmp/vort-br-context-alphabet-20261025/focusedasm/four-frequency-byte-skip-gates.asm)、[shift常量](/tmp/vort-br-context-alphabet-20261025/focusedasm/radix-shifts.rodata)
- [scalar count/prefix/stable scatter](/tmp/vort-br-context-alphabet-20261025/focusedasm/radix-scalar-count-prefix-stable-scatter.asm)

## Ordinary路由与支持集读取

[production wrapper](/home/passchaos/project-z/vort-brotli-context-cache/src/br/encoder/literal_context_split.zig:1003)把frequency与parent active support传给literal_alphabet.build。Ordinary scorer `treeBitCostProfiled__anon_46144`（`0x120e0e0`）实际`0x120e102 cmp support_len,63`、`0x120e106 ja`：≥64走large helper `0x120e1b6→0x12131e0`；其余执行inline原reference插入排序。该scorer实例无Timer/profile调用，名字Profiled不代表开启profiling。

Small实际`0x120e152`读support byte、`0x120e157`按该symbol读u32 frequency；previous frequency comparison`0x120e189`也只使用此前已从support写入的alphabet symbols。没有传入keys/temp/counts/positions指针。Large ABI为rdi=frequencies、rsi=supportptr、rdx=supportlen、rcx=alphabetptr、r8=tree-symbolsptr，error返回ax；没有allocator或clock参数。

Large初始非零filter见`0x1213262/0x1213268`等support-byte/u32-frequency indexed loads；zero频率被跳过，tree_symbols按原ascending support追加。`already_ordered`记录nonzero频率是否一直nonincreasing；`0x12132f0`之后可直接复制tree_symbols至alphabet，避开key/sort。

未已排序时`0x1213312 cmp live,64`、`0x1213317 jae`才进入radix；live<64仍插入排序。这个live-small fallback位于已进入large helper之后，物理large frame已经预留，不能称它与support<64一样没有large-frame开销。

Key阶段`0x1213430`从filtered tree_symbols取symbol、`0x1213436`索引读取完整u32 frequency。所有input-frequency reads都来自supported symbols或其filtered子集；radix后处理的是local keys，未读raw input block。这里的“完整频率”指u32所有bits，非每次读满256频率。

## 完整频率key与稳定排序

[源码key](/home/passchaos/project-z/vort-brotli-context-cache/src/br/encoder/literal_alphabet.zig:56)是 `(u64(~frequency)<<8)|symbol`。实际u32 load后`NOT r10d`清楚保留32-bit补码结果，随后64-bit `SHL8`，再OR symbol低字节；没有截断高frequency字节、total proxy或只用部分frequency。

排序从low frequency byte到high byte（key shift8、16、24、32）。Target rodata `0x1002a00`恰为 `08 10 18 20`；没有shift0的symbol pass。Complement ascending对应original frequency descending。

Tree symbols初始为ascending unique support的非零子集。每pass按source顺序进行stable计数分发，所以相同完整frequency的keys保留初始symbol顺序。Low symbol byte仍在整个key中，最终提取该byte，不参与frequency-digit重排。

Actual pass结构：scalar SHRX取得digit、truncate成byte、`incw`增加u16 counts；prefix以u16 positions保存0…256区间起点；scatter `0x1213860`起顺序读source key，以positions[digit]存fullkey到destination，再增加该position。四路unroll的每个key仍按原source先后执行。Stable scatter配合unique support保证live prefix包含每个支持的nonzero symbol一次；没有额外duplicate过滤或未经契约验证的uniqueness保证。

Uniform skip来自variation=`OR(key XOR key0)`，actual gates为：

| shift | uniform实际跳转 |
|---|---|
| 8 | `0x1213673 je 0x121394f` |
| 16 | `0x1213962 je 0x1213c41` |
| 24 | `0x1213c54 je 0x1213f2e` |
| 32 | `0x1213f41 je 0x12142fd` |

被跳过的pass不初始化/执行其count/prefix/scatter；buffer选择和parity继续保留。Keys/temp只在执行pass时交替，odd parity在`0x1214235` memcpy `8*live` bytes回keys。最后`0x1214250`等读低symbol byte并写u16 alphabet entry，`0x12142e6`保存live长度。Tree_symbols保留filtered ascending support；输出仅写live prefixes，inactive tails保持旧内容。

Vector指令确实用于固定counts清零和局部复制辅助；digit extraction/count/scatter用的是scalar integer指令，报告没有SIMD throughput或排名结论。

## 局部scratch及分配边界

[radix声明](/home/passchaos/project-z/vort-brotli-context-cache/src/br/encoder/literal_alphabet.zig:68)的keys2048 B+temporary2048 B+counts512 B+positions512 B合计5120 B。Actual large helper prologue为sub0x1618（5656 B），另保存48 B寄存器（含rbp），stable rsp=`rbp-0x1640`。

| 实际workspace | 地址与字节数 |
|---|---|
| keys | rbp-0xe40，2048 B |
| temporary | rbp-0x1640，2048 B |
| counts | rbp-0x240，512 B |
| positions | rbp-0x440，512 B |
| compiler count copy | rbp-0x640，512 B |

Compiler在prefix循环前另以512 B memcpy保留count副本，四个对应call sites为`0x121379f`、`0x1213a9f`、`0x1213d8f`、`0x121407f`；第五memcpy是odd-parity keys回拷。Large函数所有calls仅这些memcpy，没有heap allocation或clock。Temp最低base恰为stable rsp，没有本范围中更低的red-zone访问；它不是前一轮leaf-builder的red-zone布局。

Small ordinary scorer的sub仍为0x6b8（1720 B）；其inline reference不包含这份5120+compiler-copy workspace。Large helper的整个frame在entry就预留，already_ordered/live<64时可能不使用radixarrays但预留仍在。这些local instruction/layout数字不是@sizeOf、完整caller+descendant峰值、process stack、heap或RSS，未作净内存/速度结论。

## 验证与交接

已核pinned ELF和两冻结源码、ordinarywrapper→large/no-large阈值、supported indexed full-u32读取、key宽度、四pass/skip、scalar稳定scatter和局部scratch。只保存8份有限证据，没有扩大到全ELF源码或重复大规模反汇编；未执行all-output oracle、benchmark或family/check。

下一建议：父代理合并当前family/check、support/threshold/uniform/tie oracle和wire验证，再用隔离benchmark评价实际收益。源契约不覆盖的malformed support、所有frequency组合exact顺序和整个过程资源峰值仍需对应独立证据。
