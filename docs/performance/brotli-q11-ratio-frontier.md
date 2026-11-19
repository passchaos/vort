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
0.3%~1.3% 的收益，但文本行 10/12 尺寸不变。下一步不是加深 chain 或加
长度阶梯，而是：

1. 候选质量：为每个位置产出 Pareto 前沿（多个 distance/长度，而不是单一
   最长候选），对齐 `optimalPlanAlloc` 的 candidate 循环；
2. 精确价格：`Model` 需要区分 last-distance/implicit 命令符号与 repcode
   状态，否则命令价格仍是近似；
3. 成本预筛：先用模型代价过滤 DP 计划，避免为必然落选的候选构建完整 wire。

### Pareto 前沿变体（同日追加）

`lz77.collectHashFrontierAlloc` 按“长度递增、距离不减”记录每个位置的
前沿（近处短 copy + 最长 copy），`stride == 1` 与单候选收集器逐项相等；
DP 每状态最多展开 4 个候选。12 文件 128 KiB 前缀结果：

| case | baseline | 前沿 DP | delta |
| --- | ---: | ---: | ---: |
| dickens | 43,953 | 43,953 | 0 |
| mozilla | 18,676 | 18,676 | 0 |
| mr | 30,036 | 29,559 | -477 (-1.59%) |
| nci | 8,859 | 8,859 | 0 |
| ooffice | 64,634 | 64,634 | 0 |
| osdb | 46,778 | 46,778 | 0 |
| reymont | 33,363 | 33,363 | 0 |
| samba | 40,937 | 40,937 | 0 |
| sao | 92,145 | 92,145 | 0 |
| webster | 36,107 | 36,107 | 0 |
| xml | 8,401 | 8,401 | 0 |
| x-ray | 77,220 | 76,971 | -249 (-0.32%) |

相对单候选 DP：mr 再减 80 字节，x-ray 增加 8 字节；其余行尺寸不变。
耗时 xml 399.4 ms、dickens 533.8 ms、x-ray 721.3 ms（相对 baseline
+13.2%/+18.1%/+19.3%）。12 行几何平均改善约 0.16%，仍远低于 3% 门槛，
因此前沿版同样**不接入生产默认路径**，作为原型与等价测试保留。

前沿宽度没有解锁文本行，说明限制不在候选数量，而在“模型价格 ≠ 实际
wire 大小”。后续若继续 q11，需要让 DP 的代价模型与最终熵编码迭代收敛
（例如用 DP 自己的命令计划重建模型再跑一轮），或改用更强候选结构
（二叉树上界搜索），而不是继续加宽前沿或加深 chain。

### 匹配窗口探针与 64 KiB 最优窗口实测（同日追加）

`tools/br/window_probe.zig`（`run-br-window-probe`）对每个位置分别用
32 KiB 与 65,520 字节窗口跑同一 hash chain（chain=512、min_match=4），
统计更远窗口新增的最长匹配覆盖：

| case | 32 KiB 覆盖 | 65,520 覆盖 | 新增 | ≥8B 位置 |
| --- | ---: | ---: | ---: | ---: |
| dickens | 715,094 | 771,767 | +56,673 | 980 |
| mozilla | 14,674,644 | 15,319,653 | +645,009 | 5,801 |
| mr | 5,458,666 | 5,497,610 | +38,944 | 84 |
| nci | 6,244,967 | 6,357,539 | +112,572 | 2,863 |
| ooffice | 1,330,336 | 1,354,273 | +23,937 | 494 |
| osdb | 1,076,075 | 1,146,965 | +70,890 | 1,852 |
| reymont | 1,210,031 | 1,287,018 | +76,987 | 2,331 |
| samba | 1,814,491 | 1,826,002 | +11,511 | 244 |
| sao | 197,426 | 216,401 | +18,975 | 31 |
| webster | 1,257,994 | 1,329,437 | +71,443 | 2,088 |
| xml | 5,763,675 | 5,964,237 | +200,562 | 3,291 |
| x-ray | 77,243 | 108,550 | +31,307 | 4 |

12 个文件都存在更远匹配，mozilla（+645,009）、xml（+200,562）、nci
（+112,572）最明显，而这三行正是 q11 差距最大的行。

随后把 `lz77` 的固定距离代价表从 32 KiB 扩到 65,535，并临时放开
quality-scheduled optimal 窗口到 wire 窗口（q11 默认 16 bit = 65,520）。
q11 结果：dickens 43,258（-695）、osdb 45,905（-873）、webster 35,501
（-606）、reymont 32,833（-530）、ooffice 64,409（-225）、nci 8,758
（-101）、mr 29,945（-91）、samba 40,908（-29）、xml 8,377（-24），
mozilla/sao 不变，x-ray 77,358（+138）；12 行几何平均约 0.73%。
代价：xml 440.1 ms（+24.7%）、dickens 516.0 ms（+14.2%）、x-ray
610.6 ms（+1.0%）。低于 3% 合并门槛且 x-ray 出现唯一回归，因此不启用
默认路径：`br.zig` 的 optimal 窗口恢复 32 KiB（输出回到 baseline），
`lz77` 保留 65,535 的窗口能力与修正后的 64 KiB 固定距离表。

该表同时修复了一个潜在越界：q11 lazy 解析器早已用 65,520 的搜索窗口，
但 `fixedDistanceCost` 只覆盖 32 KiB，>32 KiB 的接受判定会越界读表；
现在 1...65,535 全部有确定代价。

下一步若继续该方向，需要同时抬高 wire window bits（q11 默认 16 位，
libbrotli 参考为 22 位）并让 token 距离支持 >65,535（u32 或 Brotli 专用
远距离通道），否则 64 KiB 是本架构的硬上限。

### literal context 消融与 wire 结构对照（同日追加）

bench 新增 `--no-literal-context-modeling`（`run-br-planned-encode-bench`），
q11 128 KiB 结果：

| case | context on | context off | 差值 |
| --- | ---: | ---: | ---: |
| dickens | 43,953 | 45,358 | +1,405 (+3.20%) |
| mozilla | 18,676 | 18,878 | +202 (+1.08%) |
| mr | 30,036 | 30,462 | +426 (+1.42%) |
| nci | 8,859 | 9,027 | +168 (+1.90%) |
| xml | 8,401 | 8,768 | +367 (+4.37%) |
| x-ray | 77,220 | 85,209 | +7,989 (+10.35%) |

literal context 在 x-ray/xml 上贡献很大，但在差距最大的 mozilla/nci/mr
上只有 1~2%，因此不是这三行的主要缺口。

`run-br-quality-compare-probe` 的 wire 结构对照（vort vs libbrotli q11）：

| case | vort implicit/copies | ref implicit/copies | vort cmd/dist types | ref cmd/dist types |
| --- | ---: | ---: | ---: | ---: |
| mozilla | 862/5,805 (14.9%) | 2,631/5,480 (48.0%) | 1/1 | 13/5 |
| nci | 451/2,731 (16.5%) | 1,272/2,809 (45.3%) | 1/1 | 1/1 |
| mr | 110/11,336 (1.0%) | 1,395/9,502 (14.7%) | 1/1 | 4/4 |
| dickens | 5/11,399 (0.04%) | 95/11,744 (0.8%) | 1/1 | 2/3 |
| x-ray | 0/6,335 (0%) | 521/13,142 (4.0%) | 1/1 | 2/4 |
| xml | 218/2,229 (9.8%) | 627/2,350 (26.7%) | 1/1 | 1/2 |

两个结构性差距：

1. **last-distance/repcode 解析**：libbrotli 的 Zopfli 最优解析为每个 DP
   节点携带 4 项 distance cache，并维护 8 个不同 cache 的起始位置队列；
   vort 的最优 DP 无 cache 状态，implicit distance 占比低一个数量级。
   这是 mozilla/nci/mr/xml 差距的共同主因。
2. **command/distance block types**：libbrotli 在 mozilla/mr/x-ray 上分出
   多个命令/距离块类型，vort 即使开启 adaptive split 仍只有 1 个类型；
   分块候选存在但完整 wire 竞争落败，说明搜索或成本模型偏弱。

结论：q11 的下一步应优先实现 repcode-aware 最优解析（在 DP 状态中携带
distance cache，或按 libbrotli 的 8 起点队列近似），其次再调
command/distance block split；literal context 与匹配窗口都不是主杠杆。

### repcode-aware beam 解析器实测（同日追加）

`src/br/encoder/rep_optimal.zig` 实现前向 beam DP：每个状态携带 Brotli
4 项 distance cache 与精确 insert 长度，候选来自 hash 前沿（4 宽）与 4 个
cache 距离，按 implicit/short/regular 距离真实定价；beam 宽 8，含 round-trip
与“重复距离”单测。q11 128 KiB 实测（beam=8、frontier=4）：

| case | baseline | rep beam | delta | 用时 |
| --- | ---: | ---: | ---: | ---: |
| dickens | 43,953 | 43,953 | 0 | 581 ms |
| mozilla | 18,676 | 18,676 | 0 | 662 ms |
| mr | 30,036 | 29,565 | -471 (-1.57%) | 938 ms |
| nci | 8,859 | 8,859 | 0 | 678 ms |
| xml | 8,401 | 8,401 | 0 | 480 ms |
| x-ray | 77,220 | 77,092 | -128 (-0.17%) | 734 ms |

变体：把 implicit 命令符号改为按 explicit 符号定价（避免 unseen penalty）
后，mr 29,822、x-ray 77,095，文本行仍不变；beam 加宽到 16、前沿加到 8
后文本行依旧不变（dickens/mozilla/nci/xml），用时进一步上升（672/864/789/
598 ms）。

结论：cache 状态确实能在二进制行（mr/x-ray）带来 0.2~1.6% 收益，但
文本行完全不动，且 q11 编码时间上升 28~50%。低于 3% 合并门槛，因此
不接入生产默认路径；解析器与单测作为原型保留。文本行的差距更可能来自
候选质量/熵模型收敛，而不是“是否有 cache 状态”本身——这与前沿 DP 的
结论一致。

### command/distance block split 诊断（同日追加）

对 `encodeEntropySplitCandidateAllocRecorded` 加临时诊断后发现：
adaptive command/distance plan 在每一行都存在（多数 `type_count=8/8`，
x-ray 命令类型 5），但**combined adaptive command+distance 候选从未被
物化**：`if/else` 链先命中 adaptive literal 分支（或同时存在两个 adaptive
plan 时只编码 command-only），combined 候选没有调用点。

临时补上 combined 候选后，q11 的完整 wire 对比：

| case | baseline | combined split 候选 |
| --- | ---: | ---: |
| mozilla（胜出 parse） | 18,676 | 18,903 (+227) |
| mr（胜出 parse） | 30,036 | 30,146~30,339 |
| x-ray | 85,848 | 86,157 (+309) |
| dickens | 44,061 | 44,337 (+276) |
| xml | 8,588 | 8,682 (+94) |
| nci | 8,989 | 9,300 (+311) |

q9 A/B：加不加该候选，xml/dickens/mozilla/mr 尺寸完全相同
（9,123 / 48,833 / 18,704 / 30,317），耗时 +3~8%。因此回退了该改动，
避免“无尺寸收益的固定时间成本”。

原因：`block_split_plan.Plan.estimated_bits` 只覆盖 command/distance
符号载荷（mozilla 30,889+21,696 bit ≈ 6.6 KB），而完整 wire 是 18.9 KB；
splitter 的提案无法感知树描述/类型图/字面量成本，完整 wire 仲裁正确地
拒绝了这些提案。下一步应改进 splitter 的搜索与成本模型（把类型/树开销
计入提案、增加迭代/类型数），而不是补候选接线。

## 验证计划

1. 单元：状态桶、字典边定价、原子 copy 边界、回滚。
2. 端到端：xml/dickens 的 q11 wire 必须可被 libbrotli 解码且 round-trip。
3. 12 文件 A/B：目标 q11 几何平均比例改善 ≥3%，无控制行低于 0.98x。
4. 门控：`test-br*`、`run-br-planned-encode-bench-gate`、全门
   `zig build -j2 test check check-wasm`。
