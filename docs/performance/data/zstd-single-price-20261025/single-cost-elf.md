指定micro ELF的scalar=true确实使用内联的三类canonical分类和直接公式，未调用通用FSE planner；general=false保留分类helper及可用状态mask循环。公共最终ELF在bound路径调用一个sequenceBase wrapper，scalar计算内联在wrapper里，wrapper本身仍是emitter的真实call。

micro `/tmp/vort-zstd-single-price-20261025/micro-bench`，SHA-256 `9a58d14cf744028ca06e7fd5b339699d6ccf95cf0d1c48811b481a46e097adef`。它属于build记录中的旧root SHA `7f654071421b6aba0f1f1441832b2d85842ff462478519f3990a74006a12c6ec`，早于parent test-hook及unused facade alias更新。当前root为 `72cbede8fd4f4770e1cbaab26f7f375e43c3d335729ab4bee8fe6413692116ca`。scalar module SHA `d2a33d7d9cd08002db5504890bc7527324f2d4d40ce044cbf5692f45d35cbf48`与micro建造时一致，benchmark源码SHA也仍一致；本报告明确保留micro旧epoch，不将整份ELF标成当前root。公共最终ELF `/home/passchaos/project-z/vort-zstd-single-price/.zig-cache/o/42267594774fd3ad0fdebe27688508e1/vort-zstd-encode-bench`，SHA-256 `ce84bd9b61e727098f11ab793013cdb76c4655a99d806d091bfb0b4e4308e825`，其root建造SHA与当前一致。

| 函数 | 代码大小 | 实际调用/存储 |
|---|---:|---|
| scalar=true query `__anon_2965` @0x10bd060 |704 B|无call；CFG无循环；push rbp8 B，无sub rsp，另用40 B red zone|
| general=false query `__anon_2964` @0x10bd320 |976 B|6个直接classifier call＋3个predefined planner call；自身sub0x6c8+6push=1,784 B|
| micro predefined planner @0x10bda00 |687 B|sub0x18+6push=72 B；识别canonical masks后仍遍历set bits，最后tzcnt|
| public bound sequenceBase @0x115df90 |694 B|无下游call；scalar计算内联，wrapper自身push8 B|

scalar按LL、OF、ML各分类一次并校验canonical范围，加载3组额外bit宽度；E<=16+31+16=63。RLE为`6+floor(E/8)`，predefined为`2+floor((E+25)/8)`；E+25<=88，实际局部u32舍入/加法不会wrap。RLE长度先计算，再检查3组可用mask；predefined仅在严格更小时选中，E%8==7的tie保留RLE。源码`baseLen`在availability检查前执行RLE-first checked `section_len+RLE`；但micro固定section_len=0，LLVM已消除该动态加法检查，因此不能以此ELF证明动态section溢出路径。

micro scalar与general planner使用同一实际mask地址：LL0x1015140、OF0x1015260、ML0x1015360。公共对应三组mask和bit宽数组已从ELF读取并逐值比对，完全相同。初始state宽度6/5/6与transition宽度分开，OF mask至少要求2additional bits；实际零mask索引为 `{'literal_masks': [], 'offset_masks': [0, 1, 29, 30, 31], 'match_masks': []}`。scalar availability是3个nonzero test；general成功全可用路径共9次classification：初始RLE3次、RLE同码再验3次、3个predefined调用各1次。错误路径可以提前结束。

不能把源码`next_choice[512][64]u8=undefined`记为每次32KiB清零。micro的values.len=1，转换/重建循环及该矩阵已被优化掉；实际planner只有72 B自身frame。其null分支恢复frame后tailjmp memset0x218（536 B）输出对象。这与matrix清零无关。公共通用planner确实保留sub0x8248+6push=33,400 B静态frame，但未观察到unconditional32KiB矩阵清零；read_fields同样为undefined，micro单序列字段成本已折叠。以上是局部frame/存储事实，不是heap/RSS或进程总栈收益。

公共最终emitter在0x115d129调用sequenceBase0x115df90。wrapper包含相同三分类、bit公式和maskchecks，不再调用通用planner；所以Calculator是wrapper内部inline，不能称wrapper整体inline到emitter。完整exact pricing仍在0x115ca66/0x115cade调用旧rle/predefined helper，并保留`singleBestSequencePayloadLen` reference路径。新scalar价格只用于廉价bound阶段，不替代完整exact wire pricing。

所有取证是对已存在文件执行nm/objdump/读取，没有编译、运行benchmark、修改源码或Git。未根据汇编推断性能ranking。完整精确asm和公共call摘录保存在 `/tmp/vort-zstd-single-price-20261025/single-cost-elf-evidence`，机器报告 `/tmp/vort-zstd-single-price-20261025/single-cost-elf.json`。
