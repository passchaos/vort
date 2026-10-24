# Zstd HQ搜索控制功能基线（2026-10-25）

本轮从`97c4ad99`增加三个公开控制：`hq.parse_mode`、`hq.match_lengths`和
`hq.max_price_evaluations`。最优HQ策略可以在当前最大128 KiB格式块内搜索
完整位置，枚举已接纳匹配及合法offset选择的全部长度，并在实际sequence-edge
定价前执行每计划配额。[契约](../formats/zstd-hq-search-controls.md)说明有限
beam、matcher frontier、bounded continuation、价格预算和wire保证的范围。

完整输入接口比较请求配置与对应bounded/sampled配置的两个实际完整frame；
增量接口比较同incoming state的两个完整block。两个配置保留相同depth、nice、
dictionary、memory和显式价格额度。请求失败硬返回，只有两个候选成功后才
选较短wire，平局保留基线。默认和cap-only不增加基线搜索，seekable显式
search-controls调用为失败安全而暂存整流和entries。

这是搜索能力、参数效果与输出事务增量，不提供当前行业最佳ratio/throughput
结论。更多被定价的长度仍可能被有限beam丢弃，不能宣称全局最优。

## 独立与正式验证

| 范围 | 结果 | 含义 |
| --- | --- | --- |
| 控制解析与profile | native/x86各8/8 | 不适用策略前置拒绝；区分已访问位置、累计价格与单计划最大值 |
| Parser内部 | 七新搜索native/x86各18/18；storage17/17 | 真实128 KiB宽前驱、全部长度/offset、cross-horizon定价、配额/OOM |
| 默认Plan归档 | 9组与97c4ad99完全一致 | records、offset、repeat、cost、passes和旧工作/堆计数保持 |
| Codec/事务 | native/x86各36/36；增量各17/17 | 两帧/两块guard、请求硬失败、seekable旧entries/output、空输入重试 |
| 独立QA | native/x86各39/39 | 23named＋16imports，11份旧wire、成本recurrence、资源与别名 |
| 正式专项 | nativeDebug/RF/x86RF各64/64 | 当时过滤集合；两项增量专用名字由后续扩大过滤和完整家族另覆盖 |
| 完整Zstd家族 | native/x86 RF各1053/1053 | 实际逐项测试协议与各167个编译输入绑定 |
| 公共参考campaign | native/x86各41主行＋8旧wire | libzstd1.6.0与1.4.8独立验证，完整帧和增量保证分别记录 |
| CLI | 每架构127往返、76旧wire、18profile比较 | 12组每计划B/B−1/0、57项输出保护，六个现有入口与MAX_U64 |
| WebAssembly | 7/7步骤、四实际公共操作 | 完整跨度128 KiB、exact cap、拒绝、增量重试和策略前置错误 |
| 全局检查与格式 | Debug162/162、完整CLI help通过 | 31个改动Zig文件fmt检查，编译期间源码前后相同 |

独立QA成本模型确认内部长度50/75的33/35 bit路径，4098字节夹具whole为
32775 bit、bounded为32784 bit；128 KiB真实输入验证末端前驱131068与u32
回溯。这些是实际计划及字节重放证据，不能外推为普通公开entropy模型会
产生相同压缩收益。11份旧wire与默认Plan来自独立只读源码归档，未修改旧
期待。早期独立ML位表转录错误和工具证据脚本错误保留，没有修改生产算法
迁就这些错误。

## 公共参数和资源效果

参考矩阵覆盖三种最优策略、三种扩展模式、one-shot/reusable/incremental/
seekable四类入口，以及RAW/完整字典、真实131072位置span和两个普通长度
夹具。每条完整输入wire与相同其他选项的bounded/sampled完整输出比较；
增量只验证其实际块guard，不声称独立旧完整frame支配。
每架构实际223次Probe事件，包括8旧回归、41对应基线、41请求、41无profile
比较、82反向解码和10辅助调用，6次预期错误保留输出。32条完整输入wire
均不大于对应基线，9条增量场景仅证明块级保护。普通公共输入实测没有严格
缩小的wire，两个69/75夹具均为160B；不将模型收益或更多工作量冒充实际
压缩率提升。[参考汇总](data/zstd-hq-search-20261025/reference.json)的SHA-256为
`7508759d69aab96796ddc5e02df60255ab18271d4b0e7cc781a499c3b5f8731c`。

参考价格边界记录单计划上限103963，exact通过时`max_plan_price_evaluations`
同为103963，累计`price_evaluations`为404145；差一与零配额分别产生拒绝。
复用profile的累计和reset通过实际多次调用核对。不同计划的累计次数超过
一个配额属于预期语义，不将该额度误当整次操作总CPU上限。

真实Wasm的512B whole/complete frame为56B，与对应基线相同；exact配额
1565945通过，B−1/0拒绝并保持caller输出和emitted统计。128 KiB full-span
往返的总请求堆峰值53477926B，低于128MiB额度。10KiB增量场景在8192B
flush和2048B finish处分别零配额拒绝，提高额度后空输入重试生成正确67B
wire，释放后live=0。配置、实际工作、requested heap与Wasm linear memory
分别记录，均不作为竞品性能数字。

## 证据与后续目标

交付前`git pull --rebase origin main`确认基线仍为`97c4ad99`，无需冲突处理。
相关三路复验全部通过：全局Debug162/162步骤，native/实际Wasm12/12步骤
且66/66测试，x86专项5/5步骤且66/66测试；完整CLI help再次实际运行通过。
扩大过滤后的66项包含原64项未命中的两项增量HQ搜索测试。复验期间源码
前后完全相同。[post-rebase结果](data/zstd-hq-search-20261025/post-rebase.json)
保留命令、运行日志和源码投影；正式64项与最后66项是两个明确阶段。

[证据索引](data/zstd-hq-search-20261025/index.json)保留命令、日志、实际测试
协议、源码与编译输入哈希、产物和参考版本；各阶段源码投影分别绑定。旧
native正式probe与后来新增Wasm接线的32位阶段保持独立，未重跑成功campaign。
完整源码ZIP、ELF/Wasm及wire保留本地路径与哈希，不在Git重复加入整个
checkout或编译缓存。

下一功能优先项是Brotli standalone stored资源控制的一致性。更广的匹配
候选、全局entropy规划、字典训练成本和当前多平台竞品ratio/speed/memory
矩阵仍未完成，长期业界最佳目标继续保持未完成。
