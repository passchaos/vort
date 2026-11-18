# Brotli q11 ratio frontier (2026-11-19)

## 结论

Brotli q11 与 libbrotli 1.0.9 的比例差距分布如下（128 KiB Silesia 前缀，
`--planned-quality 11 --quality 11`，3 对交错 A/B 的 after 行）：

| case | Vort bytes | libbrotli bytes | ratio |
| --- | ---: | ---: | ---: |
| dickens | 43,953 | 42,949 | 1.0234 |
| mozilla | 18,676 | 16,232 | 1.1506 |
| mr | 30,036 | 27,038 | 1.1109 |
| nci | 8,859 | 7,755 | 1.1424 |
| ooffice | 64,634 | 61,188 | 1.0563 |
| osdb | 46,778 | 44,749 | 1.0453 |
| reymont | 33,363 | 32,202 | 1.0361 |
| samba | 40,937 | 38,962 | 1.0507 |
| sao | 92,145 | 88,108 | 1.0458 |
| webster | 36,107 | 35,164 | 1.0268 |
| xml | 8,401 | 7,441 | 1.1290 |
| x-ray | 77,220 | 73,006 | 1.0577 |

差距在 mozilla（+15.1%）、nci（+14.2%）、xml（+12.9%）、mr（+11.1%）最大，
说明这不是单一的静态字典问题，而是 q11 preset 的解析/定价模型整体落后于
libbrotli 的 q11。

## 当前 q11 preset 路径

`encodePlannedStreamQualityWithOptionsAllocRecorded`：

1. `lz77.lazyGreedyPlanAlloc` + `command_plan.buildAlloc` 生成主 lazy wire。
2. 继承完整 q10 winner（保证 size 单调）。
3. optimal 候选：`lz77.optimalPlanAlloc`，通过 `QualityDictionaryProbe` 提供
   每个位置的静态字典最长匹配，`dictionary_cost` 是固定 22-bit proxy。
4. `command_state_max_input_len = 8 KiB` 时额外跑 command-state DP。
5. 静态字典 literal-run mix、大窗口/上下文/分割候选，最后取最短 wire。

关键限制：

- `lz77.optimalPlanAlloc` 是**无状态反向 DP**：只有 `costs[]`/`steps[]`，
  没有 insert-length 状态；字典边的代价是固定常数，不能按实际 command
  symbol、distance code、extra bits 定价。
- lazy 主路径不集成静态字典；literal-run mix 只覆盖短 literal gap。
- command-state DP 有状态和精确定价，但只用于 ≤8 KiB 输入。

## 已排除的证据

| 实验 | 结果 |
| --- | --- |
| 降低 command/distance split 阈值 | q11 wire 逐字节不变 |
| 静态字典 flat cost 12/22/24/28 bit | 12：xml 8,515 / dickens 46,674；24：8,400 / 44,109；28：8,389 / 44,408；默认 22：8,401 / 43,953；无常数同时改善两者 |
| 按 copy 长度的字典折扣 slope 1/2 | slope 1：xml 8,401 / dickens 43,950；slope 2：8,400 / 43,955；边际且互相抵消 |
| LZ77 计划 + 字典计划位置合并 | 静态 copy 原子不可拆分，部分重叠触发 `InvalidBlockPlan`，回退 |
| lazy 计划 literal-run 字典 mix | xml/dickens/x-ray 逐字节不变 |
| token 级字典重写（允许替换/拆分 LZ77 token） | xml/dickens/x-ray 逐字节不变；字典候选不优于 lazy token |
| command-state DP 扩到 64 KiB | 64 KiB 输入上 xml 3,972、dickens 22,352，与默认逐字节相同 |
| HQ codec（btultra2 级）作为 q11 候选 | depth 512 与默认 depth 64 在 128 KiB xml 上都超过 5 分钟，远慢于 q11 的亚秒级；不能作为默认级别候选 |

## 设计提案：状态化 q11 optimal DP

最小切片（仅 q10/q11、≤128 KiB 输入）：

- **前向 DP**，状态 `(position, insert_bucket)`，桶边界 0、1、2、3、4-7、
  8-15、16-31、32-63、64+；首版不引入 recent-distance 维，保持与现有
  `optimalPlanAlloc` 的距离代价口径一致。
- 转移：
  - literal：`(i,b) -> (i+1, min(b+1,last))`，代价 `literalCost(input[i])`；
  - LZ77：`(i,b) -> (i+len, 0)`，候选来自现有 hash chain，代价
    `commandCost(b, len) + fixedDistanceCost(distance)`；
  - 静态字典：`(i,b) -> (i+output_len, 0)`，候选来自
    `hq_dictionary.Provider.appendCandidates` 的 static frontier，代价
    `commandCost(b, copy_len) + staticDistanceCost(address)`。
- `commandCost` 使用 Brotli command LUT 的 insert/copy extra bits 与固定符号
  成本；`staticDistanceCost` 使用 `prices` 的距离码价格，不再使用 22-bit
  flat proxy。首版可用 q8 固定表，后续再接 `Model.encodingPrice`。
- 重建：每个状态保存 predecessor；输出命令时使用真实 `insert_len`（桶内精确
  值需要同时保存 literal 起点，或按桶边界回放）。
- 复杂度：`n * buckets * (chain + dictionary)`；128 KiB × 8 × ~64 ≈ 65M 次
  候选评估，先在 xml/dickens 测量耗时，超过 q11 当前预算则减桶或减 chain。
- 保留 lazy/q10/现有 optimal 候选作为控制，最终仍取最短完整 wire，保证不回归。
- 先用 xml/dickens 验证比例收益，再扩到 12 文件；更新 q11 golden 与 gate。

首个原型已落地为 `src/br/encoder/stateful_plan.zig`：前向
`(position, insert_bucket)` DP、literal/LZ77/dictionary 转移、前驱重建与
5 个单元测试；尚未接入生产 q11 路径。

首次集成尝试只把 lazy 计划 token 起点作为 LZ77 候选，xml/dickens/x-ray 的
最终 wire 逐字节不变（8,401/43,953/77,220）。下一步必须为 DP 提供**每个
位置的真实 hash-chain 候选**，否则 DP 只能复现 lazy 计划的选择。

## 全位置候选实测（2026-11-19）

本轮把候选来源换成真实的稠密 hash chain：

- `lz77.collectHashMatchesAlloc`：逐位置先查询、后插入，不跳过 match 内部
  字节，返回每个位置的最长候选（`u16` length/distance），并有 2 个单测。
- `br/encoder/stateful_optimal.zig`：把候选与 `entropy_feedback.Model` 接到
  DP。literal 用 `literal_context` 价格；LZ77 用
  `command_encoding.forLengths(insert_bucket, copy_len, false)` 的 command
  symbol 价格 + insert/copy extra bits + `model.distance[distance]`。
- 实测接线只打开 q11、≥64 KiB 且 ≤128 KiB 输入，`max_chain = 64`（稠密插入
  下比 greedy 的 512 更密），每个模型（`model2`）跑一次 DP，产出命令计划后
  走完整 wire 编码并参与最短 wire 仲裁。

12 文件 128 KiB 前缀，`--planned-quality 11 --quality 11`，单次测量：

| case | baseline | DP | delta | DP 用时 |
| --- | ---: | ---: | ---: | ---: |
| dickens | 43,953 | 43,953 | 0 | 524 ms |
| mozilla | 18,676 | 18,676 | 0 | 605 ms |
| mr | 30,036 | 29,639 | -397 (-1.32%) | 820 ms |
| nci | 8,859 | 8,859 | 0 | 577 ms |
| ooffice | 64,634 | 64,634 | 0 | 604 ms |
| osdb | 46,778 | 46,778 | 0 | 723 ms |
| reymont | 33,363 | 33,363 | 0 | 514 ms |
| samba | 40,937 | 40,937 | 0 | 771 ms |
| sao | 92,145 | 92,145 | 0 | 917 ms |
| webster | 36,107 | 36,107 | 0 | 493 ms |
| xml | 8,401 | 8,401 | 0 | 393 ms |
| x-ray | 77,220 | 76,963 | -257 (-0.33%) | 713 ms |

baseline 对照（同机、同命令、无 DP）：xml 352.9 ms、dickens 451.9 ms、
x-ray 604.5 ms；DP 分别增加 11.3%、16.0%、17.9%。12 行几何平均比例改善
约 0.14%，低于 3% 合并门槛，且 q11 编码时间上升两位数百分比，因此**不接入
生产默认路径**；DP、桥接模块与收集器作为已测试原型保留。

变体：同一 distance 上追加长度阶梯（4/8/16/32/64/128/max）反而变差：
mr 29,699（-337）、x-ray 回到 77,220、dickens/xml 不变。说明当前
`Model.command` 的近似价格会放大额外选择带来的误差，不是缺少长度选择。

结论：`(position, insert_bucket)` 状态在二进制行（mr/x-ray）能带来
0.3%~1.3% 的收益，但文本行 10/12 逐字节不变。下一步不是加深 chain 或加
长度阶梯，而是：

1. 候选质量：为每个位置产出 Pareto 前沿（多个 distance/长度，而不是单一
   最长候选），对齐 `optimalPlanAlloc` 的 candidate 循环；
2. 精确价格：`Model` 需要区分 last-distance/implicit 命令符号与 repcode
   状态，否则命令价格仍是近似；
3. 成本预筛：先用模型代价过滤 DP 计划，避免为必然落选的候选构建完整 wire。

## 验证计划

1. 单元：状态桶、字典边定价、原子 copy 边界、回滚。
2. 端到端：xml/dickens 的 q11 wire 必须可被 libbrotli 解码且 round-trip。
3. 12 文件 A/B：目标 q11 几何平均比例改善 ≥3%，无控制行低于 0.98x。
4. 门控：`test-br*`、`run-br-planned-encode-bench-gate`、全门
   `zig build -j2 test check check-wasm`。
