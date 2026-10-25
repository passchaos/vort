# Zstd magicless：五项易漏路径与独立 fixture

本轮针对 `/home/passchaos/project-z/vort` 的基线 `89fae5d6` 做只读代码/本地 reference 检查；没有修改源码、编译、编码、计时、Git 或安装依赖。实施 worker/父任务负责 format-aware API 和验证。本报告中的行为是建议验收条件，尚未执行新增测试。

本地 `~/Work/zstd/lib/zstd.h` 版本为1.6.0，`ZSTD_format_e` 定义 standard=0、magicless=1，明确要求 decoder 显式选格式，不能自动识别。`ZSTD_getFrameHeader_advanced` 与 `ZSTD_DCtx_setParameter(...,ZSTD_d_format,1)`/`ZSTD_CCtx_setParameter(...,ZSTD_c_format,1)` 是适合的参考接口；仅 standard 的 getFrameContentSize/frameHeaderSize 等旧便利函数不能直接认证 bare magicless。枚举参数是实验API宏，必须按本地 zstd.h 声明使用，不把 enum1 与参数ID混淆。

## 1. Header偏移与raw/known-size fast recognizers

`inspectNativeFrameHeader`/`findNativeFrameEnd` 使用 magic检查和 offset4；通用 parseRawOrRleFrameHeaderWithOptions 本身接收 offset并解析descriptor，适合作统一 format prefix。`src/zstd/frame/raw.zig` 的 tiny path 固定 descriptor[4]、payload9；scan固定descriptor[4]/content字段[5]；known_size.zig也固定magic/[4]/offset5。reusable NativeFrameDecoder.decodeIntoSlice同样先调用raw fastpath。

所有这些入口必须传format或在magicless明确回退通用parser。不要仅从待验证输入切去4字节，或在magicless前补伪magic再把offset当实际输入；这会破坏限额和错误偏移。standard默认原 fastpath应保持。inspectFirstBlock/BlockAt/sequence-mode replay等依赖payload_offset的辅助API也要同格式，不能parse正确但inspect仍固定4。

独立bare fixture：

```text
empty:       20 00 01 00 00                         （5 bytes, last raw0）
raw abc:     20 03 19 00 00 61 62 63                （8 bytes）
RLE 256 Z:   60 00 00 03 08 00 5a                   （7 bytes, FCS2编码0+256）
unknown abc: 00 00 19 00 00 61 62 63                （无FCS，window1024）
two blocks:  20 05 20 00 00 61 62 63 64 09 00 00 65（raw4+raw1）
```

standard counterpart只在前面添加`28 b5 2f fd`。对raw tiny和>=256两种输出大小、alloc/Into/reusable/chunks/size APIs均比较相同输出和实际bare偏移。两字节FCS的+256、无FCS、8字节FCS字段截断要各覆盖；format不能改变descriptor保留位/unused bit4规则。

## 2. Incremental首字节准入与字典resume

appendFrameInput先收4 bytes，beginBlockStreamIfSupported/checkFrameDictionaryIfHeaderAvailable硬magic gate，completeFrameAvailable以及direct-output路径仍使用standard inspector。仅改通用decode会让magicless在这几条路径停滞或接受额外payload。magicless descriptor解析从第一个字节开始；标准magic4 bytes+descriptor仍保持。

两种input_policy均要求header完整后先解析dictionary策略，再接受payload。bare字典fixture：

```text
21 07 03 19 00 00 61 62 63
```

single-segment/1-byte dictID7/FCS3，header仅前三bytes；即使实际payload是raw，缺dict7也应在此请求。每字节喂入或一次offer完整9bytes，NeedDictionary首次的accepted input与error offset应为3，output0、未接受payload。重复step/finish仍NeedDictionary且不消耗input/output；wrong id8失败后仍可provide7，再从原payload起点恢复。std counterpart header为7。dictionary ID宽度1/2/4、encoded id0、standard trained entropy字典、dictset与当前frame override过期应沿用原语义。

cap测试可用bare empty5bytes和header/payload分割，确保max_compressed_buffer_len不再暗中需要额外magic4。block_stream仍只缓冲当前block，prevalidated仍完整预验证，不把两种策略的输出时机/late error语义混同。`finish`后的可恢复TruncatedFrame/OutputTooSmall/短pledge、fatal sticky与last_step_progress也要重复原contracts。

## 3. 拼接、stop-first/trailing与skippable格式隔离

decodedSize、alloc/Into/chunk/reusable扫描循环、stream summary/error diagnostics、completeFrameAvailable和自动next-member都以magic决定data/skippable。magicless须按explicit格式直接解析下一descriptor；靠frame block last位和checksum长度找边界，绝不能搜payload字节的magic。

把两份bare raw abc拼成16bytes，stop_after_first_frame=true：输出只abc，data_frame_count1，可能已经接受的后8bytes必须由trailingInput保留，其余未接受bytes由progress留给caller。`nextStream`保持format、累计input/output、限额和已接受suffix，恢复后输出第二个abc；default concatenation输出abcabc。expected_output_len=3的stop-first应完成，nextStream后的数据仍受整个logicalstream pledge/limit约束。prevalidated可能接受suffix，block_stream可能只接受首帧；不要强制两策略相同input_read，但两者必须守恒。

单帧known-size recognizer不能把双帧当首帧并丢suffix；checksum含4 bytes应在stop boundary内。带magic字节的raw payload也不能触发帧或skippable拆分，可用内容`28 b5 2f fd 50 2a 4d 18`和FCS8/rawheader`41 00 00`。

skippable显式fixture（ID8）：`58 2a 4d 18 03 00 00 00 61 62 63`。standard识别为metadata、output0/capture3；explicit magicless不会识别skippable，应按descriptor0x58的reserved bit报错，capture counters/事件不增加。不auto嗅标准magic，不为magicless默许standard/skippable混合。其他skippable首字节可能碰巧是合法descriptor，因此通用contract是“不当作skippable处理”，不是每个变体必须InvalidMagic。

## 4. Checksum、错误字节位置与跨frame状态清理

magicless只是删magic4 bytes；checksum仍是内容XXH64的低32位，不包括descriptor、headers或原magic。raw abc checksummed fixture：`24 03 19 00 00 61 62 63`后附独立XXH64("abc",seed0)低32位little-endian `99 09 77 ad`。其standard counterpart前加magic，checksum完全相同。

覆盖每个checksum字节截断、flip一个checksumbit、output分成0/1byte，以及no-size raw和compressed sequence payload。对late failure比较实际input/output/last_step_progress与error offsets；不要按“所有位置减4”粗略处理concatenated stream，第二帧累计位置相对standard少8 bytes。公开diagnostics.phase仍应是对应header/block/checksum，不能把bare descriptor错误报告成魔术失败而吞真正offset。

单帧各block共享sequence/Huffman repeat state和字典历史；下一帧/reset/nextStream清理这些状态与standard相同。magicless不能让frame_end错过checksum，导致4-byte checksum被当下一descriptor，或让零长度frame跳过data_frame_count与dictionary borrow释放。

## 5. Encode header、所有bound/初始化路径与format复用

有FCS `emitFrameHeader`、无pledge IncrementalEncoderCodec.writeHeader和 controlled/HQ/dictionary编码入口都独立写magic；nativeFrameHeaderLen起始4+1，public FrameOptions→NativeFrameOptions转换与dictionary options helper都要传播format。未知输入大小的header也必须删4，不只one-shot已知大小。stored/raw/literal/compressed selection和压缩块规划不由format改变。

验收相同输入/options/字典下：magicless wire等于standard wire[4..]，raw conservative bound和header bound少4，block数量/bytes/checksum/dictID/FCS/window一致。在FCS1/2/4/8、单segment/explicit window/noFCS、blocksize0/1/128KiB边界、include checksum和unknown pledge路径分别比对。Into exact/below、Append caller prefix/alias、header allocation失败的transactional重试都要重复；magicless不得因错误地保留magic配额而拒绝可成功容量，也不能因过早减4出现underflow。

`Options.format`默认standard且通过resetWithOptions/decoder dictionary constructors保留；nextStream沿用同一显式format，不增加自动格式切换。libzstd reference也要在每个独立DCtx/CCtx或重置参数后设置format1；只session reset可保参数，reset_session_and_parameters会回standard，不能把配置失效误报codec不兼容。原standard固定wire hashes/公开行为应全部保持。

## Reference与验证限度

所读本地zstd1.6.0解码实现只在format==standard识别skippable；magicless starting header prefix=1，descriptor就在0，frame size/concat按这个format解析。测试应优先使用设置了format1的DCtx或getFrameHeader_advanced，不调用默认standard convenience helper来断言magicless header。

以上五组覆盖逻辑关键路径和可手工构造的小fixture，不包含新增实现或运行结果，也不提供热点速度声明。raw/known-size优化是否泛化应以行为明确和最终codegen/bench再评估；最初可以安全回退，不需为此改变解码安全或候选策略。
