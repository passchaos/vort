# Brotli stored资源功能基线（2026-10-25）

本轮从`37031849`为`StoredStreamOptions`增加总请求堆预算和内存profile，
覆盖单次、chunks、Append、Into、复用与增量stored入口。[契约](../formats/brotli-stored-memory.md)
说明零堆输出、实际capacity计费、alias快照、输出转交和profile生命周期。
这是资源功能与事务增量，不提供新的竞品压缩率、吞吐或RSS排名。

## 功能与所有权

干净独立caller-buffer路径在cap=0时仍无需分配，profile可用且fresh peak/live
均为0。全新复用器的无别名Into和caller spare Append也保留该行为；已有
scratch或authority则按完整capacity和实际control计费。快照只保护实际写入
区域交叠，未覆盖的初始化尾部借用不引入分配；真正交叠仍在写入前获准。

Alloc结果在转交给原backing前计费；caller已有Append allocation不被新owner
收编，新replacement在发布前计费，同tracked caller的输出仍留在外层账本。
复用call-scoped profile在返回前脱离，后续调用及deinit不写过期profile。
它的最后live值可以包含retained scratch，不伪造清零。增量profile跟随配置
生命周期，使用相同options的reset继续保留它。

增量prefix/block/metadata/final失败会恢复pending长度与mutable尾字节，
保留已接受输入、已发送输出和实际容量；提高额度后的空输入重试产生原wire。
嵌套lease不重设父policy、不重计capacity或清掉配额拒绝。操作协调者开启
新分类区间，成功分配、resize/remap/adoption/reservation不抹掉区间内拒绝。
关闭但尚有live allocation的authority不能被重新retain复活，延迟释放仍安全。
该Brotli账本是单owner串行协调，未新增线程并发保证。

## 已完成验证

| 范围 | 结果 | 证据边界 |
| --- | --- | --- |
| 独立QA | 23具名测试，native/x86各48/48 | 含8个owner检查和anonymous；旧20wire与64KiB边界来自独立370归档 |
| scratch范围必要修复 | native/x86各19/19 | 初始化尾部exactcap无快照、真正重叠quota拒绝与oldwire/cap保持 |
| authority权限/分类 | native/x86Debug各19/19 | 12旧named、5新named、2imports；control堆布局不变 |
| 既有总内存回归 | native/x86ReleaseSafe各62/62 | 既有levels、精确峰值、差一、复用与generic路径 |
| 增量stored资源 | native/x86Debug各27/27 | 10真实stored named，prefix/flush/metadata/final失败重试、续流和shared ownership |
| 共用planned/static/generic | native/x86各45/45 | 新checkpoint和预算权限未破坏共用编码器 |
| 正式专项 | nativeDebug/nativeRF/x86RF各65/65 | current scratch修复后完整过滤，5/5构建步骤；非输入Wasm变化单列 |
| 参考矩阵 | 两架构各28主行、100实际Probe调用 | 28独立旧wire加1旧retry辅助、两版Brotli参考 |
| CLI | 两架构各40往返、24旧wire、12profile比较 | 12组exact/B−1/0、25输出保护、3同路径；binding字段错误在0call前保留 |
| WebAssembly | 7/7步骤、四实际操作 | 零堆Into、owned exactcap、1024capacity复用与incremental retry |
| 全局检查／格式 | Debug164/164、完整CLI help通过 | 28个改动Zig文件fmt检查，源码前后稳定 |
| 完整Brotli家族 | native1378通过、1跳过；x861379/1379 | 实际逐项测试协议、ELF和各226个编译输入绑定 |

独立QA初版中的旧错误名称、别名未真正交写区和未触发增长夹具已按原
归档/实际地址修正；数值资源目标和输出保护未放宽。QA还捕获fresh reusable
Into错误创建control的生产缺口，生产修复后通过。随后scratch范围修复是
另一生产epoch，正式65项在该最新源码上重验；先前63项与48项不混成同一冻结阶段。

参考工具区分三种live值：standalone complete-owned转交后0；reusable call
返回时保留scratch或control的last snapshot；incremental配置profile在deinit真实归0。所有codec
最终独立allocator live均归0，不将过期call profile重写成0。宽source中的
Wasm夹具和CLI工具更新不属于Probe实际编译输入，按各自阶段记录。
每架构100次调用中，返回14次配额错误、5次无效配置和2次OOM，内部重试
另有一OOM和一配额拒绝。两平台28份wire全部相同；native/x86 Alloc精确
预算194/154B、chunks218/178B、scratch194/154B、incremental353/349B。
6条零堆路径实际分配次数为0。保留scratch logical114B、真实capacity为
516/476B，各自独立清理后live=0。
[参考汇总](data/brotli-stored-memory-20261025/reference.json)的SHA-256为
`61f580f27ecea74a7c9842bc54afc39eab5c1c77190eaf9e38130bc7534bed9a`。

真实Wasm四条Into wire分别154/157/156/159B，cap0/profile0正确解码。Owned
峰值196B，精确生成156B wire，B−1/0拒绝；Reusable1024B capacity加40B
control计费1064B，真实alias峰值1216B。Incremental128Bpayload+276Bmetadata
生成417B wire，retained651B、峰值815B，空输入重试与nextStream通过。
这些数值仅用于实际资源契约，不推断其他平台内存或行业领先。

## 证据与剩余目标

[永久证据索引](data/brotli-stored-memory-20261025/index.json)保存原始结果、
命令、测试名单、日志、源码hash、实际编译输入及产物身份，必要修复和失败
阶段分别保留。完整源码ZIP、ELF/Wasm和二进制wire记录本地路径与hash，
不重复加入整个checkout或编译缓存。完整家族与全局检查均已完成；交付前
rebase后的相关结果在最后验收记录中另列。

常用格式API范围持续扩展，但物理one-shot输入边界、全平台兼容/模糊测试
覆盖、HQ有限候选与全局entropy质量、字典训练成本，以及当前跨库完整
ratio/encode/decode/requested-heap/RSS矩阵仍是待完成工作。长期业界最佳
目标继续保持未完成。
