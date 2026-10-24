# 编码基准的单格式构建范围

Brotli 和 Zstd 两个编码基准现在通过私有构建模块直接调用已有公开 codec
声明。用户的 `vort` package、`vort.br/zstd` 命名空间和其他 CLI 保持原入口。
这项改动不发布可组合的新 package 模块，也不复制或改变压缩算法。

每个私有模块仅附加自身需要的对象：Brotli 的 record-optimal、Zstd 的
Huffman X2。原来的整库入口为两个基准都导入全部格式和两个对象。

## 实际依赖验证

| 编码基准 | 原项目输入数 | 当前项目输入数 | 当前全部缓存记录 |
| --- | ---: | ---: | ---: |
| Brotli | 1178，加16个crypto文件 | 237，无crypto | 1053 |
| Zstd | 1176，加16个crypto文件 | 166，无crypto | 982 |

原数量来自实际基准产物的缓存清单，当前数量也由尺寸、SipHash、派生产物
目录与源码归档逐项确认。当前两者都不含 `src/root.zig`、Deflate 或外部
crypto，也不链接相反 codec 的对象。Zstd 仍纳入一个共享 Huffman 工具的
`br/fast_bit_reader.zig` 路径；不能把路径纳入解释成运行 Brotli 编码器。

依赖数量不等于已实例化的函数数或运行的测试数。单次构建耗时仅记录，
没有相同安静条件下的冷构建对照，所以此增量不报告编译加速倍数。

隔离工作树中临时改变未使用 gzip helper 的内容 SHA，分别构建两个基准，
实际编译均命中缓存（11ms/10ms）；随后原文件逐字节恢复。这个实验只
验证此未使用文件的改动不再使这两个编译缓存失效，不外推所有构建情形。

## 行为验证

四个变更文件只改变构建导入与公开声明路由。静态反向映射后，benchmark
文件与原基线一致；CLI、CSV/JSON格式、级别策略、候选、warmup和计时方式
没有其他变更。Zstd 的 `encodeFrameWithLevelAlloc` 保留完整 level policy。

Brotli 的两个路由参数测试在 native Debug 与 x86 ReleaseFast 各2/2通过；
同十四份64KiB冻结输入的q8结果，输入、settings、Vort/reference wire长度
与SHA全部等于旧基线，strict gate通过14行/70轮。验证运行固定在CPU6，
并行构建期间的耗时只用于功能检查。

Zstd 在新模块图下的三个辅助测试，native Debug/x86 ReleaseFast各3/3通过。
50B输入的完整level policy和native-selection两条路径成功导出CSV/JSON并
通过strict gate；默认策略的wire与settings等于原整库基准。没有为模块
路由重复耗时约十六分钟的十四项编码比较；生产codec源文件完全未改。

[证据索引](data/scoped-codec-bench-20261025/index.json)保存完整命令、日志、
源码与实际缓存输入绑定、wire对照、产物和临时改动恢复记录。这里的门禁
证明模块路由和依赖范围，压缩性能继续由独立安静测量提供证据。

交付前已`git pull --rebase origin main`整合当前编码基线文档。随后实际
构建并运行完整原生CLI的`--help`成功，四个改动源码SHA前后相同。
[最终检查](data/scoped-codec-bench-20261025/final-check.json)另保存该阶段，
没有用旧基准的构建结果代替当前整合后的CLI行为。
