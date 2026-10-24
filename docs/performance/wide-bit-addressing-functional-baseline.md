# 宽位地址功能基线（2026-10-25）

本轮从`3e59413a`修复32位完整输入在512 MiB处的位计数边界。共享reader、
Brotli快速reader、完整解析/profile与stored/planned编码bound先将字节数
扩为BitCount再乘八；32位使用u64，64位保留usize。byte indices、局部
reservoir、单块位数和物理allocation保持本地类型。
[契约](../formats/wide-bit-addressing.md)说明地址范围、逻辑尾部和消费者接口。

这是位寻址、安全和平台功能增量，不提供新的竞品吞吐/ratio/RSS排名。
编码bound的大数字验证不等于实际生成或处理同尺寸输出。

## 读取与边界

Scalar和Brotli fast padded peek屏蔽logical bit_len之外的非零synthetic
高位。独立逐位oracle发现并验证该问题，读取截断和游标保持语义不变。
共享buffered/chunk/span reader对非对齐57…63位字段采用专用分段路径，
解决whole-byte填充不足而assert的问题；较小字段维持原reservoir路径。

整流位地址、header位置与profile位总量使用宽类型。局部header长度与
candidate位差在检查后转为usize。Stored bound采用精确first/full/tail乘加，
不再为极大长度执行逐块循环。Deflate fused state保留宽consumed位地址，
其首块局部metadata检查后收窄；ZOO结束padding检查在宽位域计算。

## 已完成验证

| 范围 | 结果与边界 |
| --- | --- |
| BitCount helper | native/x86各2/2，无虚假大slice或实际读 |
| 共享reader | native/x86Debug各32/32，1…63位、partial尾部、失败原子性与布局 |
| 独立QA | 23named，native/x86Debug各47/47；旧wire、游标、布局和bound来源独立3e归档 |
| 三组正式专项 | nativeDebug/nativeRF/x86RF各96/96（64+32产物）；build变化与实际编译投影分列 |
| 真实映射 | 每架构6公共API＋1direct fast＋4参考解码全部通过 |
| WebAssembly | 7/7步骤，三实际操作；数字geometry和小reader，未映射512 MiB |
| CLI/额外兼容 | 30Brotli参考往返/20旧wire；CSO6、DAX4往返；Snappy/LZMS窄测试及完整x86 CLI语义编译通过 |
| 全局检查／局部适配 | Debug168/168、完整native help通过；WIA native/x86各16/16、ZIP Zstd两架构各79/79 |
| 完整Brotli家族 | native 1418通过＋1跳过，x86 1419/1419；native原产物为旧测试计数构造epoch，checked narrowing单项两目标各21/21 |
| 完整Deflate家族 | 最终native/x86 ReleaseFast各528/528，原522项全部保留，新增六项gzip资源回归 |
| 完整ZOO家族 | native/x86 ReleaseFast各45/45 |

独立5份旧wire、5种reader的八步值/游标与原生布局来自只读归档，未修改
golden。数字geometry覆盖2^29±1和u32max字节，分别得到4294967288、
4294967296、4294967304、34359738360位。Wasm用真实16B输入验证phase2
读取63位和后续1位，支持peek/advance重放；scalar partial13 dirtybits
正确补零。真实128B stored调用生成142B wire，cap0/profile0正确往返。

## 真实大输入证据

两个实际稀疏文件长度536871044和536871053B，各实际磁盘占用135168B。
它们包含WBITS16及33个metadata块，共536870913B metadata。第二个文件
在高偏移后接旧版本生成并经两版参考核对的压缩尾块，输出64个R，SHA-256为
`8c175d2d5eb51bea41375384166593c310e7351ded44fd69a552fdb5387a8548`。

公共Alloc/Into/size/summary/profile在真实映射上执行，header start位地址
4294968364。独立fast探针从4294968344实际加载到4294968412位，八字段
`[1,30,3,0,32896,3392840,1,2]`和每次cursor/sync与独立oracle一致。普通
RLE解码未记录fast调用，因此不把它冒称为fast路径证明。独立探针的七个
缓存源码副本与实际生产源码逐字节相同，未新增shipping API。

最终最大RSS为native11952KiB、x8616656KiB，地址空间门限768MiB、RSS
门限128MiB。Native首次工具wait4字段错误丢失receipt，后仅单项补录；系统
参考首次正确解码但metadata映射页累计导致526848KiB RSS，工具释放已消费
页后仅重验这一调用。原报告、artifact和重验理由分别保留；32位全7＋4调用
均首次执行，未重跑整组矩阵。

[映射汇总](data/wide-bit-addressing-20261025/reference.json)SHA-256为
`4980797bfae2f9d1759b1048b642ff6798cc963ea56ba1f946156f75e66fe9e7`。
每架构3928条实际编译输入完成SipHash和归档SHA核对。源文件记录稀疏
区间及header/tail hash，没有伪报未扫描的整文件SHA。

## 必要兼容修复与证据范围

完整32位CLI检查暴露既有的usize移位与大分配限额常量问题。Snappy按当前
字节计算移位，LZMS在验证power后使用目标移位类型；九个CLI模块保持
逻辑16/32/5GiB上限，完整buffer默认限额取原值与maxIntusize的交集。
WIA物理索引和ZIP可选长度显式检查转换。外部`vail/archive_crypto`的7z
KDF循环改用u64 while，独立依赖提交`5d3f8a1`已同步；native/x86各8项
测试和独立Python/旧密钥向量一致，用户原未跟踪内容保留。

WIA相关范围、partition/raw/损坏输入测试通过后，额外导入的1206项codec
运行被结束，取消记录保留，不计作完整WIA全套通过。完整Br、Deflate和
ZOO回归独立执行并各自记录，不混用部分或其他产物结果。

最初完整Deflate x86编译在原进程运行后被SIGKILL结束，未生成产物，测试
执行数为零；原compiler返回-9，wrapper记录247。内核日志不可读取，因此
未把终止原因冒称为已证OOM。随后发现一个运行时32KiB数组的`first ++ first`
测试构造在native产物生成1308908B函数；用两次memcpy构造同一64KiB输入后，
函数为native21067B、x8619841B，seed、块大小和全部断言未改。这是测试
构造与编译代码量变化，不是codec吞吐测量；十三分组方案未执行。

修复构造后的完整x86实际执行522项，521通过、1失败。失败是缺footer的
34B动态raw gzip流：最后四字节被当作4209256066B的ISIZE，分配失败先于
真实TruncatedFrame。该helper在`3e59413a`和`0f437af6`完全相同，是本轮
验收发现的既有错误。现在ISIZE仅作提示；每个Deflate输出token至多258B且
至少消耗一位，因此用饱和的`raw_bytes * 8 * 258`过滤不可能的提示，再由
原bounded raw decoder判断实际流。OutputTooSmall回退前显式释放临时输出，
真实allocator失败继续返回OutOfMemory。未修改旧错误期待或golden。

六项新回归加原截断测试与导入项在nativeDebug/nativeRF/x86RF各11/11通过。
[独立gzip证据](data/wide-bit-addressing-20261025/gzip-independent.json)使用
Python/C libz 1.2.11生成和验证十一份语料；每目标22行Alloc/Limited调用及
4named/8execution全部通过。错误UINT32MAX提示返回SizeMismatch，最大请求
4346B；偏小提示的两次分配完全释放，live=0且allocated=freed；缺尾部和
非最终dynamic正确Truncated，合法1052B gzip产生1MiB输出，真实OOM仍透传。
最终完整native/x86各528项全部通过，源码/实际TestFn/产物证据分阶段保留。

[证据索引](data/wide-bit-addressing-20261025/index.json)保留每阶段命令、
日志、源码/编译输入/产物身份和失败修复记录。当前功能范围不放宽物理
address space、allocation上限或历史距离。全平台兼容、HQ全局quality、
字典训练成本和当前跨库性能矩阵仍未完成，长期业界最佳目标保持未完成。

交付前`git pull --rebase origin main`确认基线仍为`3e59413a`；相关四路复验
通过：全局Debug168/168，native/实际Wasm15/15步骤且96/96测试，x86专项
8/8步骤且96/96测试，CLI门禁9/9步骤且23/23解析及38参考往返。完整native
CLI help再次实际运行。34个改动Zig文件格式检查通过；复验期间源码前后无
变化。[post-rebase记录](data/wide-bit-addressing-20261025/post-rebase.json)
保留该阶段命令、日志与源码投影。上述全家族修复与复验在后续源码epoch
独立执行，原SIGKILL和521/1的结果保留，未用专项通过结果替代它们。
