# Brotli 完整复制长度与搜索额度功能基线（2026-10-24）

本轮为 q10/q11 HQ 增加可选 `copy_lengths = .complete`，对每个普通或 RAW
compound 匹配候选枚举 2 到该候选最大值的全部复制长度。默认仍为 `.sampled`。
长度策略与 `.bounded` / `.whole_block` 位置策略独立，standard / Large Window
及现有公共所有权模型均通过原 HQ 配置传递。完整契约见
[格式说明](../formats/brotli-complete-copy-lengths.md)。

本基线描述功能、实际 wire、请求堆和失败事务，不提供最新竞品吞吐、RSS 或
全局最优压缩结论。有限 beam、matcher 候选与实际熵模型仍限制搜索空间。

## 搜索工作与实际输出

新增 `max_price_evaluations: ?u64`，默认 `null`。它约束每一次实际 parser plan
准入的精确 copy-command 编码 choice 数量，覆盖该 plan 的全部 bounded horizons。
合法编码元数据与价格计算分开，先检查额度，再读取 symbol price。
implicit/explicit distance-zero 和各个短距别名分别计数；已计算但被 beam 丢弃的
边仍计数。静态字典 transform 保持原 raw copy length / output length 原子性。

这不是整个操作、CPU 时间或 matcher 工作上限。literal、tree、I/O、terminal
insert-only 以及辅助 continuation/extension 计价不在该计数内。零额度合法，
无复制候选的 plan 可成功；首次复制价格之前返回 `SearchLimitExceeded`。
零额度不保证零分配，HQ 工作区及总请求堆配额仍独立控制分配。

每个 refinement、sampled/position guard 和 q10 对照都拥有独立 plan 额度；
profile 累计工作可以超过该值。请求 complete 的解析必须成功，不能因为已经
拥有 sampled 成功 wire 就静默跳过搜索失败。

native codec 保留相同进入模型、history/cache 和 parse mode 下完整独立的
sampled refinement 轨迹，随后执行 complete 并按实际 serialized bit 数选择。
完整帧 one-shot、chunks 和 reusable 入口还保留对应 sampled 完整流；q11 保留
对应 q10 完整帧。所有候选共享原分配器与总请求堆配额。
incremental 使用相同 block codec 的进入检查点保护；这不保证与另行运行的
sampled incremental 整流大小顺序，因为之前的不同选择可能改变后续模型和 history。

## 独立质量和资源证据

- 独立模型中的复制长度 **50、69（q10）、83（q11）** 分别达到
  **18、18、19 model bits**；sampled 更贵。独立命令成本枚举、完整 trace/replay
  和实际 Huffman wire reader 验证选择符与输出。
- RAW compound 长度 50 的见证达到 **13 model bits**；静态 transform 的
  raw 4 / output 5 保持原子命令。16 个短距别名保留各自语义、精确 wire 和 cache。
- 独立最小模型确实产生三个可计价编码：implicit0、explicit0、regular4。
  每 plan 额度 3 成功，2 和 0 失败；同一 caller profile 累加到 6 后，单 plan
  额度仍为 3。无复制候选、零额度成功，证明额度不按旧累计 profile 误算。
- 动态命令堆、HQ workspace 与总请求堆的实测精确额度及低一额度独立验证。
  搜索错误与 `WorkingMemoryLimitExceeded` / OOM 保持区分，清理后 live 回零。
- one-shot caller output / emitted 回滚，incremental buffered input / snapshot
  的重复错误保持不变；reset/retry 同 wire。tiny allocation graph 遍历分配失败点。
- **23** 份 40 字节新默认输出从独立 `34dbe96a` 归档生成；旧 golden 未修改。
  正式参考 campaign 另保留 **6** 份此前冻结的 sampled 对照。

这些 bit 数是明确模型中的合法路径成本，不等同于实际语料的压缩率改善。
公共 wire 始终由实际序列化比较，不能直接比较不同 refinement 模型的 proxy cost。

## 正式验证与来源

正式证据目录为 `/tmp/vort-br-complete-final-20261024-qy09p5f8/`；永久归档为
[`data/brotli-complete-copy-lengths-20261024/`](data/brotli-complete-copy-lengths-20261024/)。
测试名称从实际 ELF TestFn 数组提取。最终专用门禁均为 **41/41**：
**24** 个命名测试（独立 QA 15、parser 3、codec 3、options 3）与
**17** 个匿名导入检查。Debug、ReleaseFast 和 x86-linux-musl ReleaseFast
的实际名称集合及顺序一致；1584 个源码/依赖前后一致，编译缓存、递归对象和
实际运行 ELF 输入分别绑定。见 [汇总](data/brotli-complete-copy-lengths-20261024/coverage-summary.json)。

| 验证 | 已确认结果 | 范围 |
| --- | --- | --- |
| 专用 Debug / ReleaseFast / 32 位 | 各 41/41 | 最终冻结源码，24 个命名测试 |
| 最终完整 Brotli 家族 | 1253/1253 | 最终 parser 3 个命名测试，宽源码窗口一致 |
| 公共参考 campaign | 28 rows，6 个 sampled 基线 | 144 probe 调用；54 项双向参考检查、2 项系统 RAW API 缺失跳过 |
| 每 plan 实测额度 | exact 69162 成功 | 累计 2476840；69161/1/0 正确返回搜索错误，live 回零 |
| CLI 完整小矩阵 | 60 往返、14 解析测试 | 两次各自源码阶段通过；最终测试修剪后的产物另做窄运行 |
| 最终 CLI 产物 | 4 组合、12 往返 | exact 各 4，零/低一各 4，8 项输出保护；1910 实际编译输入匹配 |
| 公共 Wasm | 7/7 构建步骤 | 6 个 export 检查、4 个 smoke 调用；新增 2 个 complete 往返与 4 个搜索拒绝 |
| 格式与消费检查 | 通过 | 25 个 changed/new Zig，两个 Python driver，完整 CLI help |
| 完整构建检查 | 149/149 | 实际命令退出 0；窗口中的内部测试/Node gate 变化另行记录 |

参考 campaign 的 28 个 wire 均不大于对应 sampled，14 组 q11 不大于 q10，
26 个非空 case 实际执行 complete pass，profile 关闭后输出一致。
原参考可执行文件与最终测试文件收敛后的直接编译产物 SHA-256 相同，支持复用
实际运行结果；旧缓存 manifest 与当前直接编译记录分层保存，不声称直接编译
生成了新的同类 `.h` manifest。

`check` 编译整库、CLI、tools 与 Wasm 的既有消费目标，实际退出码为零。
它的宽源码窗口包含内部测试和 Node gate 的两处变化；
[原始结果](data/brotli-complete-copy-lengths-20261024/build-check.json)明确记录
`source_before_after_equal = false`，不能将 149 项说成整个仓库完全冻结的证明。
最终专用三组、公共 Wasm 和最终 CLI 窄验收分别绑定其实际源码/产物。

CLI 小矩阵覆盖两种 quality、format、parse mode 和两个小输入；profile 关闭与
开启字节一致，exact / B-1 / 0 的错误不破坏原输出或同路径输入。
新选项为 `--hq-copy-lengths=sampled|complete` 和
`--hq-max-price-evaluations=NUM`，complete + profile 另写 `br_length_profile`。

Wasm 通过真实公共 q10 standard/bounded 48 字节与 q11 large/whole 64 字节路径，
验证实际 complete passes、sampled wire 保护、exact plan 额度同 wire、零/低一额度、
emitted/live 和往返。Debug 构建可能保留标准 WASI 导入，Node gate 为明确的
preview1 函数使用真实 Node WASI host；正式 ReleaseFast 产物没有 imports。

不同阶段的源码窗口需分别记录。最初门禁启动后，内部 parser 测试新增两个质量
见证，Node gate 修复标准 WASI host；原阶段报告保留真实差异。最终测试必须覆盖
新增具名测试，参考/CLI 的实际编译输入和对应可执行文件另行绑定。不能把早期
stage 与最终源码混作一次完全不变的窗口。首次完整家族门禁确实执行了随后
删除的未成立 q11 成本构造，结果 1253 通过、该构造 1 失败；失败日志保留，
不计作完整家族成功。独立 q11 长度 83 的质量见证仍由最终公共 QA 覆盖。
最后使用最终冻结源码重新运行完整家族，实际退出码为零，**1253/1253** 通过，
源码窗口前后与专项门禁一致。rebase 无冲突、源码未变；随后使用新测试种子
实际复验 ReleaseFast 专项，**41/41** 再次通过。不同阶段的计数没有相加。

本轮保存为独立实现、CLI/可移植验收、功能基线与最终验证记录提交。
目前系统时间与最终 Git revision 以交付消息和仓库日志为准。

## 复现

```sh
zig build -fno-incremental test-br-complete-lengths -Doptimize=Debug --summary all
zig build -fno-incremental test-br-complete-lengths -Doptimize=ReleaseFast --summary all
zig build -fno-incremental test-br-complete-lengths -Dtarget=x86-linux-musl -Doptimize=ReleaseFast --summary all
zig build -fno-incremental test-br -Doptimize=ReleaseFast --summary all
zig build test-br-complete-lengths-cli -Doptimize=Debug --summary all
zig build test-br-public-wasm -Doptimize=ReleaseFast --summary all
zig build check -Doptimize=Debug -j4 --summary all
zig build run -- --help
```

四个 versioned reference helper 的实际路径、版本、ABI 与命令见参考来源报告。
本轮只用小输入确认长度功能，不重复上一轮大 Far / RAW 内存 fixture，也不将
并行编译和功能检查耗时用作竞争实现性能对比。后续工作优先补更完整的质量规划，
降低全流候选同时存活的峰值，再进行当前源码的真实语料及平台竞品比较。
