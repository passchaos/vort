# Zstd 重复候选的精确 literal 成本复用

本轮修复公开 level3 编码在64KiB XML等样本上的昂贵 multi_duplicate 候选。
保留原hash配对、遍历、完整匹配长度、dominance、payload/tie、级别和split策略。
缓存只复用同一不可变block上的literal统计和完全相同Huffman树键的序列化长度；不丢弃候选或降低质量。

## 实现与语义

新CutHistogram绑定一个block，统计原scorer使用的 `block[0..prefix_len] ++ block[tail_start..]`。
四路统计只扫描前后区间的差集，固定状态4208B(native)/4192B(x86)，无新增堆分配。
其中prefix仍保留旧scorer的byte-zero语义，即使finder start_min非零；没有借优化改变旧定价选择。

Huffman/FSE plan、header、RLE/predefined序列表均委托既有实现。流bit数由精确频率乘相应code长度，
保留1023/1024分界、四流分段、终止位、padding和u16 stream长度检查。最后一次tree length的键为
`{ max_symbol, max_bit_count, bit_counts[256] }`，按完整字段比较；成功null可缓存，错误不缓存。
范围仅为未索引的multi paired-hash候选；旧single、exact-hash、indexed路径和65535索引上限保持。

## 验证

- CutHistogram：native Debug/ReleaseFast、实际x86 ReleaseFast各11/11，包含10个独立oracle测试。
- 成本与树cache：三目标各19/19；成功/错误成本、每个losing candidate、winner、wire与请求分配等价。
- 完整Zstd家族：native/x86 ReleaseFast各1085/1085，合2170通过，无失败/跳过/协议泄漏。旧1053名字全部保留。
- 两个家族各174实际编译输入核对内容与artifact；19要求named tests恰一次执行。
- 最终168/168 build check通过，源码前后SHA一致。原ENOSPC造成的未保存结果另保留，不计作通过。

## 单轮安静复测

相同十四份64KiB冻结前缀、level3、iterations1、每行五轮；CPU8，i7-10700K，Zig0.16.0 RF。
全部十四行Vort/reference wire字节数和SHA完全等于旧记录，压缩总大小没有变化。
本轮十四行中位数均更低，速度比几何平均为1.7946倍；小幅行变化未作显著性结论。

| 输入 | 原中位ms | 新中位ms | 本轮速度比 |
| --- | ---: | ---: | ---: |
| silesia-dickens | 4186.588221 | 1197.358272 | 3.4965 |
| silesia-mozilla | 74.856186 | 52.114823 | 1.4364 |
| silesia-mr | 54127.506423 | 19935.658265 | 2.7151 |
| silesia-nci | 36.147937 | 35.686665 | 1.0129 |
| silesia-ooffice | 17.230429 | 16.412825 | 1.0498 |
| silesia-osdb | 11.928607 | 11.452930 | 1.0415 |
| silesia-reymont | 7163.660421 | 2462.885840 | 2.9086 |
| silesia-samba | 18.675020 | 17.451499 | 1.0701 |
| silesia-sao | 16.913834 | 14.978141 | 1.1292 |
| silesia-webster | 12960.503396 | 3843.220444 | 3.3723 |
| silesia-xml | 63448.242921 | 12017.306946 | 5.2797 |
| silesia-x-ray | 9.639968 | 9.352467 | 1.0307 |
| brotli-source | 15729.365060 | 5180.813869 | 3.0361 |
| validation-schema-json | 35.620177 | 29.318906 | 1.2149 |

原十四行来自整库基准；为区分构建路由影响，另对XML用同私有构建入口做五轮旧版对照。旧63972.941402ms，新12017.306946ms，本轮5.3234倍。
其他十三行没有额外同构建入口旧版重复，所以几何平均是本轮版本对照，不能解释成纯算法因果或稳定倍数。
原始全部轮次与compiler监控保存，未观察到竞争编译；该次结果不是跨平台、所有档位或行业领先。

## 资源与边界

独立Vort-only XML旧/新各一次，282个请求/释放事件序列相同，请求堆峰值都2561185B，
alloc115/remap51，返回输出live5078B，caller free后0。累计增长与释放都4462540B。
固定输入、tracker元数据和栈不含在requested heap中；新cache有固定栈状态，未引入堆。
单次进程maxRSS18108/18100KiB仅作描述，共享构建环境且包含launch/code/input/stack，
不作为内存排名，没有比较libzstd请求堆。故意OOM的两版本仍OutOfMemory且live0。

新XML仍需约12秒、MR约20秒，远慢于参考库。此增量完成精确复用片段，长期最好目标未完成；
后续需分离实际扫描/Huffman计划工作，继续保质量优化，并补重复测量与更广输入/平台。

[证据索引](data/zstd-literal-cost-20261025/index.json)保存原始轮次、家族协议、源码/编译输入、
oracle、内存事件和存储失败/恢复记录；[逐项结果](data/zstd-literal-cost-20261025/analysis.json)可复算。
