# ZIP Deflate64 adapter/doc bounded review

只读复核及文档更新工作树：`/home/passchaos/project-z/vort-brotli-context-cache`，分支`work/deflate64-stream-20261025`。本任务仅编辑`docs/formats/zip.md`、`docs/performance/industry-gap-audit.md`；此前两个ZIP adapter源码已冻结，本轮不编译、运行测试/encoder/基准、计时或操作Git。

## 生产与文档范围

- 新公开Deflate64 IncrementalEncoder默认adaptive fixed/stored、128KiB planning block，history65536、match最大65538/distance65536；oldZIP默认65535stored改变已明确记录。显式4096块仍有效，`.stored`禁用match，`max_input_len`和`max_pending_output_len`界限不误称完整heap/RSS。
- 已实现ZIP接线使用新Options/State，validateOptions与expected-size物理usize收窄在beginEntry分配/publication之前；deinit既有路由释放，snapshot没有deepclone。
- failedProgress接普通、ZipCrypto、WinZipAES已产出callerbytes加密与CRC/input/archive计账；PKWARE仅计实际acceptedinput，bridge未cipherbytes不当作archive/output。ZIP仍错误后poison，未将failedprogress语义说成可继续未完成归档。
- 单次Deflate64 encoder仍maxmatch258/distance65535，没有把新stream上界伪扩到oldoneshot。动态Deflate64 Huffman编码、presetdictionary、更广ratio/speed/memory及平台矩阵仍未完成。
- 历史45entry stored-only ZIP差分campaign明确为earlier，不把新match构造测试归到旧报告。ZIP其余cipher/certificate/encryptedcentraldirectory缺口保留。

## 已完成证据

只读核父结果JSON：codec Debug/ReleaseFast/x86 each183/183 source stable，包括实际4MiB/1024blocks与warm32 ownership/capacity；ZIPDebug/x86各41/41（7/7steps），PKWARE成功及3cipher失败进度矩阵。

native independent-diff与independent-x86-diff各7/7 exit0/source stable；两个差分JSON各28artifacts/42members/58commands，合56/84。记录Info-ZIP UnZip6.00 exe身份，独立rawtoken+ZIP9metadata/CRC/descriptor+实际unzip全plaintext核。实际length65538/distance65536；两chunkpattern wire相同、known/unknown method9 entries。

两个external结果source_after都匹配冻结ZIP生产SHA：

- incremental_writer.zig `918adb223db122b1557ba45e2bdeb00d79e36b426161936de4c3933e52a468a3`
- incremental_writer/codecs.zig `51e04675c10e6ddbe0c66213970a3b9594b8865f6972557bd3fb6c24428143a5`

native external使用此前QAhelper snapshot但同生产core，x86使用finalhelper；不宣称全src在这两个epoch相同。首次完整ZIP suite单旧storedfixture假设失败，父只改该fixture `.compression=.stored`、生产无改；首次check176/176属于该testfix前版本，不提前绑定为最终src验证。

## 最终完成与文档冻结

完整ZIP suite修复后terminal：zip-complete-fixed7/7steps、1988/1988tests，source稳定。仅旧storedfixture显式选择stored，生产scope无改。修复后final-check176/176已terminal source稳定，文档明确该check属于fixture修复后的snapshot，而非旧首次176check。两文档完成冻结，不再编辑；无新峰值/RSS/吞吐领先声明。
