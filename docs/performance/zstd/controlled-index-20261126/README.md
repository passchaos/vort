# Zstd controlled-index 完整操作验收，2026-11-26

**结论：拒绝本候选，`merge_allowed=false`，生产代码未合入。** 公共 L3
的完整语料吞吐提高 17.73%，但两个其他等级控制行低于预设 0.98x 下限。
全部慢样本、失败门槛和较早的两种候选均保留，不重跑至通过。

## 比较范围和构建

基线是 `2d798695c86bfab430c98da04d26b72b6f44a89c`；候选由该源码冻结。
双方使用相同公共 allocating level API、Zig 0.16.0、ReleaseFast、
`x86_64-linux-gnu` 和 `skylake+pku+sgx`。主机是 Intel Core i7-10700K
@ 3.80GHz，每个 benchmark 进程固定 CPU 2。

原始报告的 `benchmark_threads=1`、`codec_thread_policy=internal-auto`
保持原样。公共 L3 已核实不执行历史候选线程或五种 parser sweep；其他
等级保留公共默认策略。控制定义的线程计划字段不能代替运行时线程观测。
这是重型编译、测试和资源任务停止后的开发机采样窗口。

主矩阵使用十二份原始完整 Silesia 文件，共 **211938580 bytes**，不重复、
填充或归一化。每行六轮，三次 AB、三次 BA，72 pairs / 144 children。
每个 child 一次 timed encode；计时包含输出分配、length mix 和 free。
初始完整输出的哈希与交叉解码在计时外；timed 输出验证长度/mix。
双方采用同一生命周期，未使用持久编码 workspace。

实际公共 L3 为 controlled greedy、search budget 24、rep-beam disabled。
候选采用连续三字节 hash、带历史时的 block-local match、u32 prefix
position 和减少索引清零；保留 scalar Source oracle、global stride、
extra-edge 次序及重复项、探测预算和完整输出。较早 hash/local 与
incumbent-bound 两个 pilot 属于不同采样 epoch，不能相减推断组件贡献。

## 完整验收结果

以下吞吐倍数均为 candidate / baseline，越大越快：

| 项目 | 实测 | 门槛 | 结果 |
| --- | ---: | ---: | --- |
| 十二行几何平均 | 1.177268x | >=1.03x | 通过 |
| 成对 95% CI | 1.167228–1.188514x | 排除持平 | 通过 |
| 完整 NCI | 1.275295x | >=1.20x | 通过 |
| 最弱完整行 x-ray | 1.084735x | 每行 >=0.98x | 通过 |
| NCI 64 KiB / L8 | 0.975321x | >=0.98x | **失败** |
| Mozilla 64 KiB / L2 | 0.979686x | >=0.98x | **失败** |

统计固定十二行，按 AB/BA 分层重采样整个 round block 20000 次，seed
`20261126`；保留原始顺序、每个时间值、wire hash、argv 与退出回执。
独立 reducer 的 evidence integrity 通过，退出 1 表示预期 gate failure。

控制矩阵使用 nci/mozilla/ooffice 的真实 64 KiB 前缀，公共 L3 和
L1/L2/L8/L19 共十五行，90 pairs / 180 children / 10872 timed encodes。
L1/L2/L3 每 child 100 次编码，L8/L19 一次；每 child 一个 timed batch。
低等级批次数在任何控制样本产生前从 10 提高至 100，旧定义和说明一起保留；
输入、公共选项、六轮顺序和 0.98x 门槛未改。

NCI L8 的 paired 95% CI 是 0.936610–0.999424x，第六 pair 为 0.873548x；
Mozilla L2 的区间是 0.945163–1.002156x，第五 pair 为 0.894042x。
Mozilla 区间包含持平，尚不能归因于源码某处；两个点估计仍违反门槛。
这些慢样本全部保留，没有通过删除样本或追加采样改变判决。

## 正确性和资源证据

冻结候选原生 Zstd 1491 tests、encoder controls 62、scalar/planner native
与实际 WASI 各 23、untouched-baseline large-prefix records 对照 1 项通过。
完整日志保留 Zig runner 的 warning 和最终成功 build summary；原生套件
未单独保存的会话退出回执不补填。初始完整 wire SHA/size 均匹配；资源 adapter 的
成功输出另与基线 wire 逐字节相等。

公开 L3 requested-heap adapter 的十四个输入、170 processes 和两个
allocator self-tests 通过：28 unlimited、28 exact-peak、28 peak-minus-one、
56 backing OOM injection、28 plain runs 及两个 quota-zero priority checks。
所有运行 caller free 后 live=0、allocated=freed、ownership errors=0。
OOM 使用 backing ordinals 0/1 受控注入，范围不包括全部 allocation ordinals。

七个多块输入 peak 各减少 **524288 bytes**；完整 NCI peak 保持
**10762377 bytes**，累计申请字节 **492794119 → 359100679**，减少 27.13%。
十四行 allocation attempts 不变。这些是 requested heap，不是 RSS；
资源改善不能覆盖吞吐控制失败。完整 benchmark ELF `.text` 增长 0.0592%，
该数字不等于单独 codec text 或 stack 测量。

## 参考差距和下一步

同窗口的次要 default-preset 观察中，完整 L3 基线/候选吞吐为 libzstd
1.6.0 的 **0.077467x / 0.090284x**，Vort 输出大小为参考的 **1.066077x**。
Vort 和参考的 window policy 不同，此项不参与 candidate/baseline 门槛。
基线是 main，候选未合入；本结果没有证明 matched-quality frontier 或
业界最佳。参考库文件、实际版本、每行 window 和原始样本均在归档内。

下一轮应隔离失败等级的完整操作路径，并研究可复用索引 workspace，减少
每块分配与初始化；保留压缩质量、预算、原始输入和控制门槛。

## 归档与离线核验

`sources.tar.gz` 保存三个候选和原始 parser oracle；`campaign.tar.gz`
保存输入、build/ELF/reference 身份、三个 pilot、formal、controls、统计
和退出回执；`resources.tar.gz` 保存全部 828 个资源 artifacts；
`validation.tar.gz` 保存真实编译/运行日志、命令、native/WASI gates。
清单与各模块只从包内重放，不启动 codec、编译器、SO 或 benchmark。

在该目录执行：

```sh
PYTHONDONTWRITEBYTECODE=1 python3 verify.py
```

`verify.py` 退出 0 表示归档与统计重放校验成功；候选仍是 `rejected`。
归档完成后的独立复制核验回执另行保留，不能把校验成功改写成合入许可。
