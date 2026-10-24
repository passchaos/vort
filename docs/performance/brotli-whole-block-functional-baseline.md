# Brotli whole-block HQ 功能基线（2026-10-24）

本轮增加显式 `HqOptions.parse_mode = .whole_block`，使 HQ parser 在完整 meta-block
输入上运行动态规划，去除 bounded 模式的 4096 位置切分边界。`bounded` 仍为默认。
whole 模式必须真正执行请求的解析；工作区或总堆配额失败返回
`WorkingMemoryLimitExceeded`，不能用 bounded 成功结果静默掩盖失败。

记录时间为 2026-10-24 18:53:42（Asia/Shanghai，10:53:42 UTC）。
本文件描述实际 wire、兼容性、状态与请求堆证据，不提供行业吞吐、RSS 或性能排名结论。

## 算法与实际输出保护

- ParseMode 贯穿 HqOptions、Resolved 与实际 parser，保留格式、距离参数、质量和其他设置。
- whole 使用完整输入长度的节点图；前驱位置改为 `u32`。x64 Node 仍为 120 字节，
  与原结构大小一致。输入上限仍受 meta-block 和公共资源约束。
- native 保留进入模型、Source、距离缓存、previous bytes 与 matcher 检查点。
  每轮分别解析 bounded 与 whole，序列化实际候选后比较 wire 位数，使用所选实际模型训练下一轮。
- 另保留原完整 bounded refinement 序列的实际输出。仅比较每轮局部候选不能保住旧序列，
  因为 whole 胜出后的模型会改变后续解析。
- 完整帧 API 另保留原完整 bounded HQ stream；whole 一次性 q11 还与对应 whole q10
  的完整帧结果比较。实际输出选择只发布获胜候选的模型、缓存和 emitted 统计。
- profile 记录全部真实尝试：`bounded_passes`、`whole_block_passes`、
  `max_parse_positions`。即使最终选择 bounded 或 stored，whole 工作记录仍保留；
  失败时 emitted 与公共状态回滚，effective 仍表示调用者请求的 whole 模式。

同一模型下的独立实际 trace/wire witness 记录 whole 代理成本 **32792**、bounded **32793**。
它证明这项输入可以越过原边界获得更低代理成本；wire 仍须实际序列化比较。
whole 保留有限 beam 与长度采样，不穷举所有缓存路径或长度，不声明全局最优，
也不将不同 refinement 模型的代理成本直接作为相同比较依据。

## Command storage 与内存记账

命令存储由按输入长度预分配改为动态 Builder。初始化不分配；首次增长以 16 条命令为起点，
随后使用 checked 容量增长，优先 resize/remap，需要移动时由同一分配器保留旧块并分配新块。
追加失败必须返回错误并保留原数据。收尾返回精确 owned slice，调用者仍用原分配器释放。

`requiredWorkingMemory` 现在描述固定工作区下界，包括初始命令容量，不能等同于最终峰值。
后续命令增长和精确收尾期间的旧块、新块同时存活峰值，都由真实 HQ/总请求堆账本计算。
测试分别验证下界、实际分配与配额失败，不通过扩大额度掩盖两者的区别。

Command 为 **96 字节**；3 条记录的最终精确存储为 **288 字节**。
这不是整个编码操作的峰值，峰值还包含节点、模型、字典、matcher fork、候选和 I/O/history。
相同远历史输入与 wire 的旧总请求堆峰值为 **2,341,312,656 字节**；
Builder 接入后的新总峰值为 **1,134,463,136 字节**，减少 **51.55%**。
HQ 工作区从 **2,316,146,495** 降到 **1,084,029,611 字节**，减少 **53.20%**。
同一输入、参数及输出的 SHA-256 完全相同，真实 17,825,849 字节远距引用保持不变。
这是该 fixture 的请求堆峰值改善，不代表 RSS、吞吐或竞品内存排名。

## 当前正式验证

| 验证 | 已确认结果 | 计数范围 |
| --- | --- | --- |
| whole ReleaseFast | 54/54 | 37 个命名测试、17 个匿名导入检查 |
| whole 32 位 x86 | 54/54 | 同一正式测试范围 |
| whole Debug | 54/54 | 实际名单与 ReleaseFast、32 位完全一致 |
| 新 whole 公共 Wasm | 7/7，Node 26 实际执行 | standard/large，whole 最大实际跨度 4098 |
| 正式参考 campaign | 20 个报告 rows；6 个旧版基线 rows | final report 状态 ok、前后 source 清单一致 |
| Builder 后 codec 配额窄复验 | Debug 19/19 | 2 个目标测试、17 个匿名检查 |
| 新完整 Brotli 家族 | 1229/1229 | 另含 Builder integration 的两个命名测试 |
| 新 CLI | 29 次往返；12 个解析测试 | 4 项默认字节比较、8 项 whole/profile/大小/跨度检查、21 项输出保护、2 项同路径、精确/低一字节预算各 1 项 |
| 完整构建检查 | 149/149 | [结果](data/brotli-whole-block-20261024/build-check.json)，源码窗口无变化 |

37 个命名测试来自公共 QA **18**、command-storage **8**、parser whole **5**、
options **3**、codec **3**。完整家族中的另两个 Builder integration 测试不属于主 54 项，
不能重复计入该总数。正式 coverage 从实际 ELF 的 TestFn 数组提取，并核验编译与运行缓存摘要。

参考报告 `reference/whole-block-report.json` 的 rows 包含 one-shot、chunks、incremental，
q10/q11、standard/large，以及 binary、raw 字典、空输入和 4100 字节尾部案例。
旧版基线为 `90f21bad` 的六个对应输出。预算检查使用报告中的实际调用与错误结果，
本文件不把调用次数、rows 和预算断言相加为未经提取的新总数。
stage 记录与最终报告处于不同阶段，以 final report 为本轮结果依据。

Builder 接入后只复验受影响的两项 codec 公共配额测试：当前实测 bounded 工作区峰值
不能让 whole 请求静默成功；whole q11 的当前实测总峰值额度成功并保持相同 wire，
低一字节时硬失败。两项都保持 effective whole、emitted 事务，清理后 live 为零。
相关源码观测窗口前后 SHA 一致；该窄检查不是完整编译输入清单证明。

Wasm 门禁实际编译并在 Node 执行 whole 公共路径，验证完整跨度大于 4096、输出和格式语义。
验证持续时间以及请求堆数字仅描述本次功能检查，不用于比较竞争实现速度。

## 证据绑定与复现

正式工作目录为 `/tmp/vort-br-whole-final-20261024-c47wcqh0/`，永久归档目标为
[`data/brotli-whole-block-20261024/`](data/brotli-whole-block-20261024/)。
原始日志、测试名称 coverage、source 前后清单、参考报告、编译缓存绑定和产物 hash
分别保存。[参考结果](data/brotli-whole-block-20261024/reference.json)、
[参考来源绑定](data/brotli-whole-block-20261024/reference-binding.json)、
[CLI 来源](data/brotli-whole-block-20261024/cli.json)、
[CLI 结果](data/brotli-whole-block-20261024/cli-gate.json)及
[实际测试覆盖](data/brotli-whole-block-20261024/coverage-summary.json)已永久归档。
同输入和输出的请求堆峰值对比见
[内存改善报告](data/brotli-whole-block-20261024/far-memory-comparison.json)。
其实际 producer 和全部 1900 个编译输入通过
[缓存摘要与内容绑定](data/brotli-whole-block-20261024/far-memory-binding.json)
核对，链接对象的递归来源也已验证。

正式子命令没有开启 verbose。QA 使用构建缓存 SipHash 与实际缓存目录的核验方法，
结合实际依赖/编译输入及对应产物绑定源码；不能因 argv 未含 verbose 就声称已经获得
完整命令展开。源码阶段变化需保留各阶段记录，不能把 stage 与 final 混作同一次不变窗口。
报告日期、CPU 与目标信息用于说明验证环境和兼容范围，不作为性能结论。

代码增量包括 Options `8877`、Builder `4f81`、whole parser `1ee9`、
实际候选保护 `b651`、integration `2f2`、CLI `2d4` 提交；
最终完整提交 ID 以归档清单和 Git 记录为准。
相关入口为 `zig build test-br` 和本轮 whole/CLI/Wasm 专用目标，实际优化模式、
目标平台、参考库路径及命令行以正式清单为准。

后续性能比较另行记录语料、CPU、编译模式、冷热运行、吞吐和
峰值内存，不将本轮验证耗时当作竞品速度排名。

## 已记录复现命令

```sh
zig build -fno-incremental test-br-whole-block -Doptimize=Debug --summary all
zig build -fno-incremental test-br-whole-block -Doptimize=ReleaseFast --summary all
zig build -fno-incremental test-br-whole-block -Dtarget=x86-linux-musl -Doptimize=ReleaseFast --summary all
zig build -fno-incremental test-br -Doptimize=ReleaseFast --summary all
zig build -fno-incremental test-br-whole-block-cli -Doptimize=Debug --summary all
zig build test-br-public-wasm -Doptimize=ReleaseFast --summary all
zig build check -Doptimize=Debug -j4 --summary all
```

参考 gate 的四个版本化 helper 参数及独立旧版基线文件记录在
`reference-summary.json` 和实际命令清单。内存对比使用
`zig build -fno-incremental test-br-large-window-far -Doptimize=ReleaseFast -- 17825849 <output_dir>`，
其结果的输入与输出哈希严格等于上一版本的同一 fixture。
