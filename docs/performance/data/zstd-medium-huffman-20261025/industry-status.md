# Brotli / Zstd 当前行业地位只读核查

结论：**尚未达到业界最佳。功能覆盖已很广，当前最明确的产品差距是编码延迟，
其次是完整质量、内存和平台比较证据。** 精确 literal-cost 优化是已验证的进步，
不能把相对旧 Vort 的加速表述为超越竞品。

本次只读核查工作树 `/home/passchaos/project-z/vort-zstd-duplicate-profile`，HEAD
`c56c825591983a61c84994ff55b9e8bc8835a3c5`。读取三份目标文档及其三份逐项分析
JSON，仅复算数字；没有修改源码、Git，未运行编译、编码、测试或 benchmark。
“最新”指已经归档的 exact-literal-cost 一轮复测，不涵盖随后尚未测量的 profiling
或生产改动。

## 原编码首轮与最新 Zstd 必须分开

原始首轮来自 `d4297483`：i7-10700K、Linux x86-64、Zig0.16 ReleaseFast、CPU8，
十四份冻结64KiB前缀，每行一个 process 内五轮交替、iterations1。Brotli q8 和
Zstd level3 分别用自己的 encoder，比对相同输入；每 codec70个原始轮次。

| 统计 | 原 Brotli q8 首轮 | 原 Zstd level3 首轮 |
| --- | ---: | ---: |
| 更小输出 | 9/14 | 13/14 |
| 中位吞吐领先 | 0/14 | 0/14 |
| Vort/reference 压缩总字节 | 288091/296445 | 310437/328241 |
| 总字节减少，独立复算 | 2.818060686% | 5.424063417% |
| 各行中位吞吐比的几何平均 | 0.028209651978× | 0.000551816854× |

上述汇总与 `current-codec-encode-x86-20261025.md:14..18` 及原逐项JSON完全一致。
这里的几何平均是等权逐行统计，不是所有输入串联的总体吞吐；大小减少为压缩
字节总和的减少，不能替代各 corpus 的大小/速度权衡。两组均没有大小同值行。

Brotli 原首轮的吞吐比范围0.016036916…0.044969176×，Mozilla 为
96.226670ms 对1.543179ms。这是原首轮编码数据，不是最新HEAD重新测量的Br
排名。Brotli Vort窗口16，而参考lgwin22；相同q8编号不能声称参数/算法相同。
参考为本地 `558fc647` 的 libbrotli1.2.0-dev experimental Release 构建。

最新 Zstd exact-literal-cost 只改变未索引 multi paired-hash 候选的成本复用。
十四份 Vort/reference frame 的长度和SHA全部保持；原大小比较13/14、总字节
310437/328241因此仍成立，**新的性能测量单独统计**：

| 最新 Zstd 统计 | 独立复算 |
| --- | ---: |
| 本次相对原Vort中位时间降低的行 | 14/14 |
| 版本速度比几何平均 | 1.794587980× |
| 最新相对参考库中位吞吐领先 | 0/14 |
| 最新各行 candidate/reference 吞吐比几何平均 | 0.001000433609× |
| XML原first-screen→新 | 63448.242921→12017.306946ms，5.279738897× |
| XML同私有入口旧版→新 | 63972.941402→12017.306946ms，5.323400799× |
| MR原→新 | 54127.506423→19935.658265ms，2.715110066× |
| 仓库源码原→新 | 15729.365060→5180.813869ms，3.036079940× |

最新reference几何比是从最新analysis.json的十四个candidate_over_reference直接
复算，**没有用旧竞品比乘以版本速度比**。XML最新ratio约0.000007724526×；
最新reference时间由保存的ratio可还原约0.092828ms，与原首轮0.093473ms是不同
测量。MR最新约19.936秒，XML约12.017秒，因此内部加速仍未关闭竞品延迟差距。

`zstd-exact-literal-cost.md:30/44/49` 和 industry audit:62..69 的1.7946×、
5.2797×/5.3234×分别对应上述两种比较，数字正确。其余十三行没有额外同私有
入口旧版重复，因此1.7946×是这次版本对照，不是纯算法因果或稳定加速倍数。

## 功能差距与性能差距

两格式都已覆盖标准编码/解码、字典与恢复、增量I/O、资源限制及多种平台验证。
Brotli Large Window/q0…q11、全meta-block搜索、complete lengths、总堆预算，以及
Zstd signed levels、HQ策略、COVER/FastCover、seekable、长history、宽stream/bit
计数均有分开的功能证据。本次三文档没有提出另一项可复现的常用general decoder
合法wire拒绝；这不是穷尽兼容性证明，也不应为保持“功能优先”无限添加控制字段。

仍真实存在的质量/实现边界：

- Brotli q0/q1 matching 为fragment-local；通用非HQ retained history≤65535，
  另有独立ratio候选。complete lengths只穷尽已接纳匹配的长度，有限beam、matcher
  和熵模型仍可能漏掉更低成本计划。不能宣称与完整reference HQ/Zopfli等价。
- Zstd HQ维持8/16状态的有限搜索与自有prior；canonical hash/chain参数是query
  元数据。最大合法history配置不等于已测最大history匹配或广泛性能领先。
- physical allocation/完整one-shot边界仍与bounded streaming能力分开；功能门禁
  不能证明各CPU、所有合法数据或所有caller buffer模式均达最高性能。
- FastCover训练功能已实现，但标准字典finalization历史延迟与charged-output
  劣势尚待当前复测。不能把旧七样本的训练结果当本次普通frame编码数据。

这些主要是质量、效率或证据覆盖边界，不应错误称为缺少已实现的格式/API。
被明确排除的C ABI和native VORT方向未列为当前功能缺口。

## 历史解码证据不是当前编码领先

industry audit:53/55保留两条历史解码测量：Br2026-10-08为12/13行领先、
clustered q8仅0.8632×；Zstd2026-10-13 large JSON为0.9188×，小JSON为1.0139×。
这些固定参考/固定产物的局部decoder结果不能覆盖当前encoder，也不是本次HEAD的
完整decoder重测。这里未把解码历史胜项加入编码胜项，更没有重跑旧基线。

## 证据范围与核查结果

独立复算检查通过：各14行数量、70round文档口径、大小win/总字节/减少百分比、
原中位吞吐几何比、最新14个baseline_ms与原JSON的一一对应、14个wire_unchanged、
版本速度几何平均、XML同入口速度比。没有发现summary数字错误。

功能证据包括native/x86各1085项家族、成本/树cache三目标各19、CutHistogram
三目标各11，以及168build checks。它们证明该增量的等价/安全契约，不证明排名。
原ENOSPC未保存结果未计作通过；post-rebase完整1085执行单独归档。

XML旧/新独立请求堆事件序列均282项、peak均2,561,185B、返回live5078B/free后0，
说明该优化未新增请求堆。maxRSS18108/18100KiB只是两次进程描述，含code、input、
stack和launch；没有竞品heap/RSS对称比较，不能据8KiB差值宣称内存改善。

测量只有一个进程内五轮；没有独立重复process、1MiB/完整文件、全部档位、
incremental编码/解码、ARM64或冷缓存矩阵。保存的监控未观察到竞争Zig编译，
不能扩大为零系统噪声。参考文件/映射身份被记录，完整符号与传递依赖仍未验证。

下一步应继续保持wire质量，分离最新慢样本中的实际候选扫描/Huffman计划工作，
优化后再做同输入安静复测，并补独立重复、输入规模、streaming、ARM64与对称
内存数据。**当前最可信表述：功能广泛、部分输出更小，Zstd内部成本已有显著
进步；当前编码总体仍明显落后参考，尚不能称Brotli/Zstd业界最佳。**

核查时间：2026-10-25 13:13（Asia/Shanghai）。
