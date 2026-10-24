# Brotli/Zstd长流计数功能基线（2026-10-24）

本轮从`dacd500a`继续功能优先目标，统一Brotli/Zstd的累计字节、pledge、
流/帧计数、metadata数量、诊断offset和历史绝对位置。`StreamCount`在32位
平台为u64，在64位平台保持usize；单次Progress、physical buffer、格式block
和distance上限保持本地类型。[完整契约](../formats/stream-counts.md)说明两种
Zstd decoder policy、Brotli coded-bit循环相位、32位XXH64以及CLI有界I/O。

这轮扩大实际功能和平台范围，不提供新的竞品吞吐、压缩率或RSS排名。
requested heap、工具进程RSS、累计输出和广告窗口是不同指标。

## 已完成的独立与正式专项

| 范围 | 结果 | 验证含义 |
| --- | --- | --- |
| 共享Counter与诊断 | native/x86各5/5 | checked加法、可选本地转换、物理narrowing、局部Progress类型 |
| XXH64 | native Debug/RF、x86 Debug/ReleaseSafe各5/5 | canonical向量、seed、31/32/33边界、独立C固定点长度oracle；64位保原std类型布局 |
| Brotli独立QA | nativeDebug/x86RF各37/37 | 18named＋19module entries，独立7份旧wire与合法重复prefix模型 |
| Zstd独立QA | native/x86Debug各32/32 | 17named＋15module entries，独立6份旧wire及15B checksum旧wire |
| 正式native Debug聚合 | 142/142 | Br77、Zstd55、Core5、XXH5；16/16构建步骤 |
| 正式native ReleaseFast聚合 | 142/142 | 与Debug同一实际ELF测试集合 |
| 正式x86-linux-musl ReleaseFast聚合 | 142/142 | 32位真实ELF执行，累计类型为u64 |
| Legacy diagnostics兼容 | 37类型x86编译＋1/1、4/4、4/4窄执行 | 只转换已有可选本地计数，不宣称这些codec内部长流能力已扩展 |
| CLI解析与小文件 | Br20/20、Zstd14/14；8参考往返与4旧wire比较 | stream-file使用32KiB读写、wide输入/编码输出cap、原子发布和同路径保护 |
| WebAssembly | 7/7步骤，4个实际公共操作 | 合法Brotli重复prefix模型、真实131090B Zstd大FCS帧的1B输出/预验证、wide pledge与XXH模型 |
| 最终全局/CLI | 160/160构建、34/34解析测试、完整help通过 | 当前全部源码和新增工具接线；CLI参考35/36往返及输出保护通过 |

142是四个测试产物的执行条目总数，含107named和35imports，也有共享测试
重复覆盖。18个Brotli和17个Zstd新QA均由实际ELF名称确认。12个测试ELF和
6个链接对象的缓存key、输入size与SipHash绑定原运行产物；后续修改的旧测试
从Git blob恢复并核对运行前SHA，不把旧产物冒称为后续全源码冻结结果。

独立QA先从只读`git archive dacd500a`获取wire与状态oracle。跨界模型会
验证完整状态关系，再推导重复合法prefix并实际处理尾部；它们没有物理输入
4GiB，不能替代真实大流门禁。XXH64的大长度模型有独立C XXH 0.8.2固定点
stripe和digest证据；真实长流checksum由另一门禁单独验证。

## 真实长流与家族回归

真实门禁用可复用的64KiB输入、输出和pattern缓冲区处理多GiB逻辑流；CLI
另外读取一个唯一稀疏文件并实际处理其全部字节。大型decoded数据和完整
输入不作为heap数组或Git artifact保存。执行结果及源码阶段在永久证据中
分别归档，完整成功/失败及后续修复记录以最终验收更新为准。

已完成的早期真实Zstd RLE组使用131094B checksum/FCS64帧，两policy实际
恢复4,294,967,297字节。Brotli大文件CLI实际处理4,294,967,313字节，生成
13,205,545B压缩输出，现代1.2.0和系统1.0.9完整流式解码、hash及17B尾部
核对通过。原工具8MiB编码输出cap被正确拒绝并保持旧目标；依据小样本增长
选择32MiB后完成必要重验，失败记录不计成功。

Zstd大文件默认single-segment输出的广告window随FCS达到约4GiB，参考流式
decoder按自身资源限制拒绝；该限制不计作参考通过。后续显式window17配置
使用同源数据单独验收：实际消费4,294,967,313字节，输出16,777,254字节，
请求堆峰值1,710 B、live=0；两版参考都用64KiB缓冲完整解码。两格式解码的
SHA-256同为`31193f7cfaeafc0300f827ba141d122e680b490584644208035a1547e2a37747`，
17B尾部一致。稀疏源只创建一次、实际分配4096B；成功读取全部逻辑字节。
Brotli实际两次尝试（一次低cap失败、一次成功），Zstd实际两次成功编码
（默认window参考拒绝、显式window参考通过），这些阶段没有隐藏或混算。

native库级矩阵的7项操作已经完成：两种Zstd策略完整RLE解码、两种策略
skippable拼接、Zstd增量编码，Brotli metadata三种consumer、跨4GiB之后
正常距离2048复制的两种consumer、stored subset三种consumer和stored
encoder。每条路径实际处理多GiB，保持64KiBcaller缓冲；释放后请求堆live=0。
编码器请求峰值约197KiB，解码器不超过1.31MiB。原RLE成功consumer没有因
后续skippable失败重跑；补录原缺失参考receipt单独注明。32位矩阵以自己的
实际producer/decoder运行证明该目标，外部参考结果只在字节一致时复用。
最终native和x86矩阵各7项操作全部通过、源码运行阶段前后一致。
最终汇总SHA-256为`e81a8e102c80fb7567e23f0d23b804105be23e9520fbfc157c5a6787646e3e71`，
[quick entry](data/stream-counts-20261024/large-streams.json)与原始阶段在证据包中保存。Zstd编码
输出131110B，Brotli stored编码累计输出4,295,163,909字节并同时由公共stored
decoder验证，完整巨wire仅流式hash与参考sink消费，不落成多GiB文件。

| 实际长流路径 | 输入字节 | 输出/metadata字节 |
| --- | ---: | ---: |
| Zstd checksum RLE两种policy | 131094 | 输出4294967297 |
| Zstd拼接skippable两种policy | 4294967313 | metadata4294967297，输出0 |
| Zstd增量编码 | 4294967313 | 编码输出131110 |
| Brotli metadata三种consumer | 4294968324 | metadata4294967297，输出0 |
| Brotli stored＋压缩copy两种consumer | 4294968332 | 输出4294969344，实际distance2048 |
| Brotli stored subset三种consumer | 4294968325 | 输出4294967297 |
| Brotli stored增量编码＋同步解码 | 4294967297 | 编码输出4295163909 |

独立128KiB SF3互操作也通过：native/x86公共编码产生同一98,369B wire，
5B头`0e00e00a60`包含再生长度131072与压缩长度98347、高32位值96。
两版libzstd各解码两个Vort产物（4次）；两版参考SF3帧由两个目标和两种
入口策略实际解码（8次）。该门禁用独立Python位字段解析，源码与实际ELF
编译输入完整绑定，报告不把prevalidated后转入共有executor称为另一算法。

最终完整家族均通过：Brotli native1328通过＋1平台跳过，Brotli x86为
1329/1329；Zstd当前native与x86各1003/1003。完整x86回归另发现旧32位
测试类型/layout假设，以及36位Huffman-literals头用usize聚合的实际portable
读写问题；原失败与必要修复分别记录。真实拼接skippable门禁也发现零输出
pledge下的续帧错误，修复保留正输出限额与明确stop语义。

最终资源测试保留wire等值、候选dominance、容量复用与OOM恢复目标。
独立`dacd500a` x86源码也复现原7项资源断言失败；原64位allocation magic
仅在相同已审计布局下保留，其他架构用独立Ledger、分阶段消除量和实际
ArrayList增长/type几何证明，未为测试数值改变生产算法。五符号55bit
参考读取改为多次窄读拼入u64，所有位宽/对齐检查保留。必要修复的36项
窄集合在native Debug/x86 ReleaseFast均通过，当前家族随后各自重验。

## 永久档案与后续目标

本轮已无冲突rebase到远端`a435e9b4`的PNG优化提交，Brotli/Zstd/Core/XXH
生产源码SHA保持不变。rebase后四路并行复验全部通过：全局Debug检查
160/160步骤，native/实际WebAssembly组23/23步骤且145/145测试，
x86组16/16步骤且145/145测试，CLI组14/14步骤、34/34解析测试及35/36
参考往返；完整CLI help再次实际运行通过。本轮94个Zig文件格式检查通过，
复验期间源码前后无变化。证据在[post-rebase结果](data/stream-counts-20261024/post-rebase.json)。

[证据索引](data/stream-counts-20261024/index.json)记录原始文件与确定性
tar.gz包的SHA-256。原始命令、日志、源码hash、实际编译输入索引和失败阶段
保留；完整源码ZIP、ELF/Wasm、大wire的身份与本地路径由报告保存，不在Git
重复加入整个源码checkout或多GiB输入。

两库更宽的累计API不增加单次物理数组、格式distance或working-memory上限。
Brotli完整输入bit reader的32位地址范围仍是独立边界；Zstd native HQ有限
state/length候选、完整字典训练成本和当前竞品ratio/speed/memory矩阵仍未
完成。下一有界功能工作是Zstd显式whole-block/complete-length/价格预算控制，
随后统一Brotli standalone stored资源API；长期业界最佳目标仍未完成。
