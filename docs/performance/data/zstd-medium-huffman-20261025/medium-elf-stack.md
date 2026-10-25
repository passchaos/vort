指定旧/新 ELF 的 medium 分支局部静态栈分配从 **75,112 B 降到 39,240 B**（包含 `finalizeSmallHuffmanLiteralPlan`、KnownActive、Medium 和链内返回地址），减少 **35,872 B，约47.76%**。新 KnownActive 自身只保留1,768 B；该 ELF 没有保留旧的大 workspace 后再叠加 Medium 的问题。

本报告只依据已存在 ELF 的 `nm`/`objdump` 与指定源码，没有编译、运行基准、修改源码或操作 Git。全部取证文件在 `/tmp/vort-zstd-duplicate-profile-20261025/medium-elf-stack-evidence`，机器可读结果为 `/tmp/vort-zstd-duplicate-profile-20261025/medium-elf-stack.json`。

| 项目 | 旧 ELF | 新 ELF |
|---|---:|---:|
| `finalizeSmallHuffmanLiteralPlan` | `sub rsp,0x5c8`=1,480 +6 push=48 → **1,528 B** | 同为 **1,528 B** |
| `treeCodeLengthsKnownActive__anon_38967` | `sub rsp,0x11f38`=73,528 +6 push=48 → **73,576 B** | `sub rsp,0x6c8`=1,736 +4 push=32 → **1,768 B** |
| `treeCodeLengthsMediumKnownActive__anon_38997` | 无独立函数，medium path 内联在 KnownActive | `sub rsp,0x8c28`=35,880 +6 push=48 → **35,928 B** |
| KnownActive 起点的 medium 局部链 | **73,576 B** | 1,768 +8 call-return +35,928 = **37,704 B** |
| finalizer 起点的 medium 局部链 | 1,528 +8 +73,576 = **75,112 B** | 1,528 +8 +1,768 +8 +35,928 = **39,240 B** |

计数以各函数入口的 RSP 为基准；入口已有返回地址不计入自身 frame，每个链内 `call` 另计8 B。审计函数各有一次 `sub rsp` 与匹配的 `add rsp`，push/pop数量匹配；没有 page-probe循环、`__chkstk`/probe调用、动态栈对齐或其他 RSP 分配调整。不能把 Medium 自身35,928 B直接与旧 KnownActive73,576 B比较；上表明确累加了新 caller frame 和返回地址。

两份 finalizer 都在 `0x111af85` 调用地址 `0x111c260` 的 KnownActive。旧 KnownActive 代码大小为 `0x127c`（4,732 B），`active<128` 跳到 `0x111c9bc` 的内联全宽 back-reference 分支。新 KnownActive 大小 `0xa99`（2,713 B），先以 `0x40`、`0x7f` 检查 active数量；65…127落到 `0x111c8b0` 的真实 `call`，目标为 `0x1141640` 的 Medium（代码大小 `0x83c`=2,108 B）。128及以上仍走独立 dense分支。该实例对应n=256/max_bits=11；不将此结果推广至其他实例或参数。

Medium 的排序子调用也已作小范围核对：旧 `sort.block.block__anon_39113` 与新 `__anon_39129` 都为 `sub rsp,0x628`=1,576 +6 push=48 →1,624 B。计到该直接子函数序言，旧局部链为76,744 B，新为40,872 B，差值仍是35,872 B。这是另一个局部前缀计算，未声称覆盖排序器或 runtime helper 的更深调用高水位。

源码声明容量为nodes/leaves/current/next/multiplicities五组数组的总和：workspace256为61,440+512+1,024+512+7,680=71,168 B；workspace128为30,720+256+512+256+3,840=35,584 B。输出仍是256项数组。该声明容量减少35,584 B，与 ELF 局部链减少35,872 B是不同计量；后者还包含编译器临时量、寄存器保存及调用开销。

旧 ELF：`/home/passchaos/project-z/vort/.zig-cache/o/ed94ec1c4a213c549af1a1d632f56d71/vort-zstd-encode-bench`，SHA-256 `cae7982a8dd399aa1b78b7b96877601ce60809b33269d408e26d6fcedc5a487b`。

新 ELF：`/home/passchaos/project-z/vort-zstd-duplicate-profile/.zig-cache/o/e896d85b31c33819f34a4488826cd334/vort-zstd-encode-bench`，SHA-256 `fc6723c9409244bc88ea1ae9fefa95cde76fcfd33559c439e5461bc6a585718d`。

新 huffman源码SHA-256：`2bfc756f0d0380eeab5f6bc9e268ef14294aa5816dbdb1e039390bdabb682aa3`。

结论限于这两份 ELF 的 medium 65…127符号分支静态栈指针下降量。它不提供 heap、RSS、进程总栈、完整递归调用高水位或性能收益的证据。此 ELF 已满足局部栈缩减，不需要为避免保留大 caller frame 再添加一次 outlining；若检查其他 runtime max_bits实例，应重新取证。
