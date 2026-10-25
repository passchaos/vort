这份 `skylake+pku+sgx` ReleaseFast micro ELF 的 vector query 确实在加法前数值扩宽到64位：`vpmovzxdq`读取4个u32扩成4个u64，随后`vpaddq`累加；水平归约也使用qword加法。未发现u32累加归约。

ELF SHA-256：`a3424c92856f905642cd5e6bcbf27c061302048c77e5fe1dad2c40bec035a54b`。源码weighted/frequency SHA分别为 `e45b292daca0a33a5840f21543cf0ae93396db65072ab9aa4562def89ab4a890` / `34ee2d73fb003ae301e9642a9cd61ef366aaccefa856baff2cae56166347eb2b`。所有命令只有读取、`nm`、`objdump`和写入/tmp报告，没有编译或运行基准。机器结果：`/tmp/vort-zstd-wide-reduction-20261025/reduction-elf.json`，原命名函数完整汇编与公共路径小摘录在 `/tmp/vort-zstd-wide-reduction-20261025/reduction-elf-evidence`。

`query(scalar=true)`是 `weighted_bound_bench.query__anon_2994`，地址0x10bc600，代码421 B；`scalar=false`是`__anon_2995`，地址0x10bc380，代码629 B。源码明确true调用analyzeReference、false调用analyze；main中0x1060fd3/0x1060fe1按同顺序调用这两个实际符号。

vector路径的关键指令：

- total：0x10bc3a0 `vpmovzxdq m128,%ymm5` →0x10bc3a7 `vpaddq`；其余total m128读取同样先扩宽。0x10bc488…0x10bc49f的水平归约仍是`vpaddq`，最终`vmovq`取u64结果。
- negative：源码`prior-min(prior,now)`降低为0x10bc3ce `vpmaxud`、0x10bc3d3 `vpsubd max-now`。max>=now，因此u32差值不会下溢；随后低/高四lane分别`vpmovzxdq`到u64后`vpaddq`。存在u32减法，不存在u32加法累加。
- 每u64 lane最多累加32个u32，单lane最大137,438,953,440；总归约最大1,099,511,627,520，严格小于2^40。该固定几何下total及negative均不可能u64溢出。

实际ISA为AVX2的256-bitYMM操作，水平归约另使用128-bitXMM；包含`vpmovzxdq`/`vpaddq`/`vpmaxud`YMM，未使用AVX-512。输入加载为`vmovdqu m256`和`vpmovzxdq m128`，没有新增32字节对齐检查或aligned-input-load要求，保持普通u32的4字节对齐契约。

| 读取计量 | current | previous |
|---|---:|---:|
| 每次完整vector query的唯一频率地址覆盖 |1024 B|1024 B|
| 指令实际读取字节总量 |2048 B|1024 B|

硬件循环初始rcx=-8，每次+16，执行16次；最后一次rcx=232，更新到248后停止。每次覆盖16个频率（64 B），是源码8lane循环的两次展开。全部频率地址范围都在[0,1024)，末字节为1023，没有越界。current因总量扩宽加载与delta/support加载重复，指令load traffic合计3072 B；这不等于越过数组末尾。`vpmovzxdq m128`只读16 B，输出32 B。完整每次load的16轮地址范围已在JSON逐条校验。previous在Certificate中的真实数组起点为self+16；另读self+8/+0x410是已声明的证书metadata，单独区分。

scalar路径0x10bc638 `mov`到r12d时自动zero-extend，0x10bc645使用64位`add r12,rax`，0x10bc648立即比较cap0x20000。无效前缀可在加载剩余数组之前退出；valid完整循环为256次，读取current和previous各1024 B。vector直到0x10bc47e循环完成和64位水平归约后，才在0x10bc4a9检查同cap。negative的u32转换检查在cap之后。非负输入的前缀超过cap当且仅当最终总量超过cap，因此此check位置变化保留错误优先级，但处理无效前缀时扫描工作不同。此事实不推出性能排名。

两个query都是leaf，无call、无`sub rsp`。scalar保存6个寄存器，显式RSP下降48 B，最深rbp相对访存使入口以下覆盖达到96 B，其中48 B在当前RSP下red zone；vector在扫描完后才push rbp，显式下降8 B，最深访存覆盖入口以下48 B，其中40 B在red zone。入口已有返回地址不计入这些数值。这只说明两个局部静态函数的寄存器保存/访存布局，不是进程栈高水位或heap/RSS。

唯一公共encoder ELF：`/home/passchaos/project-z/vort-zstd-wide-reduction/.zig-cache/o/7f7353d4aaa264722bc376e6614e034e/vort-zstd-encode-bench`，SHA-256 `ceb10d219665a5e1e13b121cc1d5be7789dd61edf818761844fb98c6ce162511`。`inspect256`没有独立符号，但在`zstd.emitMultiDuplicateMatchCompressedBlockWithFirst`（0x115a9a0，11,375 B）内发现实际内联归约：0x115c1dc起使用相同m128数值扩宽、qword累计；0x115c2a9循环回跳，0x115c2cb才检查cap。源码路径由SingleLiteralWinnerCache.payloadLowerBound调用witness.analyze；内联区没有对inspect的call，未使用的active计数已被优化掉。其current/previous频率在rsp+0x2480/rsp+0x1eb8，固定1024 B范围与micro同型。只证明这一实际调用点，不将其推广至其他发行CPU或所有调用者。
