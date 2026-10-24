# Brotli/Zstd窗口与资源增量验收（2026-10-24）

本轮补齐Brotli非HQ Large Window格式选择与Zstd超过64 MiB的实际历史匹配，
保留独立旧默认wire，并给Zstd全编码入口加入共享requested-heap预算。
功能与资源范围见[Brotli基线](brotli-general-large-window-functional-baseline.md)
和[Zstd基线](zstd-large-history-functional-baseline.md)。
整体功能和性能领先目标仍未完成；这轮未执行新的竞品吞吐/ratio/RSS排名。

## 最终验证范围

| 范围 | 结果与边界 |
| --- | --- |
| Brotli native专项 | Debug/RF各37通过、1跳过；真实32位x86为38/38 |
| Brotli完整家族 | 1273通过、1跳过，共1274；32位专有边界另有实际x86覆盖 |
| Brotli版本化参考 | 76组、391实际调用、150双向结果；75预期错误保持输出，3项参考能力跳过分列 |
| Zstd native专项 | Debug/RF/x86各55/55；最初32位编译/运行失败与修复阶段保留 |
| Zstd必要Source回归 | Debug/RF/x86各10/10，包含两个具名测试及导入项 |
| Zstd完整家族 | 954/954（939 named、15 anonymous），与原失败阶段测试名字及顺序完全相同 |
| 实际Zstd远历史 | 五操作全部通过；真实D=67,108,872，独立wire读取及libzstd1.6.0/1.4.8验证 |
| Zstd当前小型重绑定 | 14组、7旧wire；当前decoder实际恢复4份保存产物，原Far编码未重复 |
| Brotli CLI | 早期35参考往返；最终当前Root窄重绑定3参考用例（q0/file、q1/stream、stored）及18 parser通过 |
| Zstd最终CLI | 36参考往返、15profile wire比较、3窗口描述符、exact/B−1各3、33输出保护、6同路径；12 parser通过 |
| 巨大窗口参考限制 | 3个API的41/noFCS头与profile独立通过，系统libzstd1.4.8明确拒绝窗口过大，3次拒绝单列 |
| 实际WebAssembly | 7/7构建步骤，4个公共往返；原对齐失败与portable修复阶段保留 |
| 全局检查与完整CLI | Debug `zig build check` 156/156步骤通过；完整CLI `zig build run -- --help`实际运行通过，源码前后相同 |

ZstdCLI原门禁误把已知44B内容的合法single-segment头当作缺少描述符；必要
修复先显式关闭内容大小，随后记录系统参考库对约2TiB广告窗口的拒绝。
最终普通36次参考往返保留41位已知内容配置；既有25位配置关闭内容大小以
实际验证窗口描述符。41位无内容大小场景独立核对header、profile和特定参考
拒绝，不能计作参考解码通过。两次原失败与工具源SHA均保留，生产源码未改。

## 源码、产物与永久证据

[永久证据索引](data/br-zstd-window-20261024/index.json)包含原文件和tar.gz包
SHA-256；[档案说明](data/br-zstd-window-20261024/README.md)标明各阶段范围。
正式Brotli probe为1942条实际编译输入，Brotli完整家族为203个仓库输入。
正式Zstd Far/current probe为1941个输入及2个递归对象；完整Zstd家族为954个
唯一输入。命令、编译清单与实际产物分别绑定，阶段源码变化与不属于该编译
的文件变化分别记录。

原Far与当前Source必要错误分类修复后的重新编译是两个阶段。当前decoder
实际读取原fast、double-fast、exact和字典wire，结果逐字节一致；没有将原
大编码冒称为全新源码冻结运行。默认wire来源独立`fa35a843`归档，没有重写
golden来适配新输出。

## 收尾与后续

全局Debug检查和完整CLI help已通过。先前额外选择的全库ReleaseFast检查在
全库测试模块优化上耗时很长；标准Debug检查通过后结束该额外构建，原日志、
SIGTERM和取消理由保留，不计作ReleaseFast全局通过。ReleaseFast行为验证由
两库完整家族、native/x86专项及实际WebAssembly提供。
远端`69e1218e`新增的有界PNG增量编码已无冲突rebase，Brotli/Zstd核心文件
SHA保持不变。rebase后三路并行复验全部通过：全局Debug检查156/156、
native/实际WebAssembly组20/20步骤（106通过、1跳过，共107项）、
x86组10/10步骤且93/93测试通过。当前WebAssembly产物实际完成4次公共往返，
SHA-256为`c7aab3d0a371dea77b6a4e5216ac0440d02a5dedf1d4bbef4d4d1233d30938b6`。
完整CLI help再次实际运行通过，本任务59个Zig文件格式检查通过；三组复验
期间源码前后无变化。完整结果在integration包的`post-rebase/`中，顶层
[integration.json](data/br-zstd-window-20261024/integration.json)指向该通过阶段。
下一独立功能片优先统一32位平台的累计字节、pledge和诊断offset到u64；
local buffer长度和实际距离仍按平台资源边界检查。随后扩展Zstd HQ显式
whole-block/complete-length及价格预算控制，并统一Brotli stored资源API。
当前竞品性能矩阵和已知最弱场景仍需单独测量、优化和复验。
