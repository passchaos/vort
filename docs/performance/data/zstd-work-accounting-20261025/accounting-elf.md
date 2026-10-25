# 默认生产成本缓存 Work accounting 的 ELF 差分

审计时间：2026-10-25T15:56:42.556602+08:00，Asia/Shanghai。仅读取两个指定生产 ELF、源码和已有验证记录；没有编译、运行测试/benchmark、修改源码或 Git。取证文件只写 `/tmp/vort-zstd-work-accounting-20261025`。

## 结论

新默认 unindexed multi 路径实际使用 `CacheWithAccounting(SingleLiteralCostCodec,.prune,false)`，其 exact Work、winner Work 和 certificate_age 均为 void。旧 ELF 中这些字段的饱和更新及两个 Work histogram bucket 的 LZCNT 计算真实保留；新默认 emitter 的相应更新与 bucket 计算均不存在。

两边 `payloadForWinner` 都已内联进 `zstd.emitMultiDuplicateMatchCompressedBlockWithFirst`，不存在独立 payloadForWinner 符号；新 ELF 仍调用带 `.prune,false` 类型名的 sequenceBase，结合源码与真实调用点确认 specialization。此结论限定默认路径，不推断所有 library/API 实例或整个 ELF 都不含 Work。

Checked histogram 的 scanned_bytes/update_count admission与成功提交、证书验证/发布、tree缓存、stream products及candidate emit仍保留。它们属于codec语义状态，不能通过禁止普通inc/store来判断统计移除。此审计不作零cycle开销或性能收益声明。

## 来源与证据

| 对象 | 实读 SHA-256 |
|---|---|
| old production `.zig-cache/o/cb65c150ad435ec3299a71a1ad71caff/vort-zstd-encode-bench` | `5d14ea6817ac59176c0ee38b8f1331d627569e534f8a1cc7fcd08b46b5380b0b` |
| new production `.zig-cache/o/cb5827954aa0d116f6d48f2b2bf9daeb/vort-zstd-encode-bench` | `d32df6453d43fb7f2c8b64eacb55a271e1d662806eb5577fd3803d1e2bd8ebfa` |
| new `src/zstd.zig` | `cc29696a1fca71cf134210a12a197071fc2bad25801f528ad8b7140e29028a59` |
| new exact cache | `0a81c9834f9dd8006f2cab125fba230533b9eb8ff0f8720b39a70b6e29435f51` |
| new winner cache | `584446c9c72555c2c9ad71dd0f43c7fe2a5119b2475b5dc0f31d3bc6b0040f78` |

旧树为 `/home/passchaos/project-z/vort-zstd-anchor-cache`，新树为 `/home/passchaos/project-z/vort-zstd-work-accounting`。CutHistogram SHA两边均为 `6a9d7e4545f2ee075cfef1c1497b5609987820a9d6401848ca2268865711f9ad`；weighted_bound SHA两边均为 `e45b292daca0a33a5840f21543cf0ae93396db65072ab9aa4562def89ab4a890`。新已有encoder-build记录exit0、5/5 steps succeeded且关键source before/after稳定；本审计没有重跑该构建或parent family/check。

- [结构化 JSON](/tmp/vort-zstd-work-accounting-20261025/accounting-elf.json)
- [old exact emitter](/tmp/vort-zstd-work-accounting-20261025/exactasm/old-default-emit.asm)、[new exact emitter](/tmp/vort-zstd-work-accounting-20261025/exactasm/new-default-emit.asm)
- [old nm](/tmp/vort-zstd-work-accounting-20261025/exactasm/old-cost-symbols.nm)、[new nm](/tmp/vort-zstd-work-accounting-20261025/exactasm/new-cost-symbols.nm)、[new真实caller](/tmp/vort-zstd-work-accounting-20261025/exactasm/new-default-call-sites.asm)
- [old query与age更新](/tmp/vort-zstd-work-accounting-20261025/exactasm/old-work-queries-age.asm)、[old exact成本Work](/tmp/vort-zstd-work-accounting-20261025/exactasm/old-work-costs.asm)、[old histogram bucket](/tmp/vort-zstd-work-accounting-20261025/exactasm/old-work-histogram-buckets.asm)
- [new不含accounting的bound区域](/tmp/vort-zstd-work-accounting-20261025/exactasm/new-bound-without-accounting.asm)、[new checked histogram](/tmp/vort-zstd-work-accounting-20261025/exactasm/new-checked-histogram.asm)、[new证书发布](/tmp/vort-zstd-work-accounting-20261025/exactasm/new-certificate-publication.asm)
- [new普通stream products](/tmp/vort-zstd-work-accounting-20261025/exactasm/new-ordinary-stream-products.asm)、[new sequenceBase exact asm](/tmp/vort-zstd-work-accounting-20261025/exactasm/new-sequence-base.asm)

## 默认实际路由

[普通 wrapper](/home/passchaos/project-z/vort-zstd-work-accounting/src/zstd.zig:23298) 固定 cache_costs=true、profile_work=false、.prune、profile=null，转入 WithAnchors 的 reuse_anchors=false / anchors=null。这个默认路径继续使用原 scanner，未启用独立anchor实验。

[ActiveCostCache选择](/home/passchaos/project-z/vort-zstd-work-accounting/src/zstd.zig:23317) 现在直接以 profile_work 实例化 winner.CacheWithAccounting；其 [inner/Work/age定义](/home/passchaos/project-z/vort-zstd-work-accounting/src/zstd/literals/winner_cost_cache.zig:45) 与 [exact Work定义](/home/passchaos/project-z/vort-zstd-work-accounting/src/zstd/literals/single_cost_cache.zig:66) 使三个统计字段在false实例中无存储，相关更新受comptime track_work门控。Pruning和certificate状态不在门控中。

Cache admission仍要求 duplicate_index=null、4096<N≤131072，并先通过rleByte/小块过滤。两份机器码均保留null-index与长度判断；new见 `0x115aa21–0x115aa48`。Hashed finder继续调用payloadForWinner，由prepareLiterals、lower-bound/prune、exact pricing和certificate refresh组成；这部分被LLVM内联到默认emit。

| 符号 | old | new |
|---|---:|---:|
| emitMultiDuplicateMatchCompressedBlockWithFirst起址 | 0x115a9a0 | 0x115a9a0 |
| 同函数机器代码大小 | 0x2bff / 11263 B | 0x2817 / 10263 B |
| sequenceBase起址/大小 | 0x115df20 / 694 B | 0x115db40 / 694 B |
| sequenceBase类型名 | Cache(Codec,.prune) | CacheWithAccounting(Codec,.prune,false) |

代码大小减少1000 B仅是这个符号的静态代码差分，不是速度、总ELF、frame或RSS结论。

四个serial-beam实例都有真实调用：old `0x115a3fa`、`0x116a59b`、`0x116cb2a`、`0x1171131`；new `0x115a3fa`、`0x116a1bb`、`0x116c74a`、`0x1170d51`。因此这里不是仅查看未使用的诊断源码。New `0x115c3f4` 实际调用 `.prune,false` sequenceBase；独立named payloadForWinner/prepareLiterals均未保留，报告没有把未找到的名字当成函数不存在。

## 旧更新保留与新移除

Old默认cache的inner.Work基址为rsp+0x1d50，certificate_age为rsp+0x22c8，winner bound.Work为rsp+0x22d0。按源字段和实际更新路径映射：

| 旧字段/行为 | 旧ELF位置 |
|---|---|
| bound_work.queries load/inc/cmove(MAX)/store | 0x115ae76–0x115ae8c，rsp+0x22d0 |
| 有证书时certificate_age同类更新 | 0x115ae9e–0x115aead，rsp+0x22c8 |
| exact cost_queries同类更新 | 0x115c315–0x115c32b，rsp+0x1d50；rejected/error另有路径 |
| exact huffman_plans | 0x115c351–0x115c360，rsp+0x1d58 |
| exact tree_serializations | 0x115c703–0x115c711，rsp+0x1d60 |
| exact tree_cache_hits | 0x115d14f–0x115d15d，rsp+0x1d68 |
| exact stream_symbol_products | 0x115c890–0x115c89e及0x115c8ea–0x115c8f8，rsp+0x1d70 |
| negative_delta histogram bucket | LZCNT 0x115cf26；update rsp+0x2350+8×bucket |
| certificate_age histogram bucket | LZCNT 0x115cfd1；update rsp+0x23e0+8×bucket |

Old `0x115ceb0` 起还保留bound_checks、negative_delta_total、max_negative_delta、max_certificate_age的load/update/store；两个histogram bucket进行zero处理、log2/clamp、饱和entry increment及store。

同一exact-symbol范围的静态pattern核对得到old 21个“inc后饱和cmove”位置、2个LZCNT；new均为0。这个统计只用于定位并与源字段核对，不是dynamic执行次数，也不把所有cmov认定为统计。New .prune,false实例没有Work/age存储，default emitter的bound、exact pricing和refresh代码中对应accounting序列及两个bucket/log2计算均消失。

其他helper仍可为format/Huffman工作进行合法bit操作；本结论是Work bucket计算消除，不宣称整个codec没有log2或任何inc/store。New仍有条件move用于取min/max、普通索引增加、频率增减及状态写入。

## Checked histogram和证书状态仍保留

[CutHistogram admission](/home/passchaos/project-z/vort-zstd-work-accounting/src/zstd/literals/cut_histogram.zig:42) 在frequency/range mutation前用std.math.add验证scanned_bytes+work和update_count+1，成功后提交状态；模块未改动。

New实际scanned_bytes位于rsp+0x1a28：`0x115b2e8 add`、`0x115b2f0 setb`、`0x115b2f8 jae`成功gate，carry走失败路径。Update_count在rsp+0x1a30：`0x115b41e load`、`0x115b426 inc`、`0x115b43d je`溢出失败gate；前面的mov保持INC的zero flag。成功处理后 `0x115bfea` / `0x115bffa`分别提交这两个字段。

Old对应为scanned_bytes rsp+0xcf0、add `0x115b283` / jae `0x115b293`；update_count rsp+0xcf8、inc `0x115b3b2` / jne成功 `0x115b3c9`，最后 `0x115bf9a` / `0x115bfaa`提交。这些checked counters没有被void化，也没有换成饱和统计规则。

New certificate analysis向量循环 `0x115c19c–0x115c269`及随后checked scalar bound仍保留。有效replacement发布包含：

- `0x115cd3e`写active_symbols到rsp+0x2ba8。
- `0x115cd4b`写trusted_lower_bits到rsp+0x2bb0。
- `0x115cd68`以长度1024调用memcpy，将当前frequencies保存到证书rsp+0x2bb8。
- `0x115cd90`写total_frequency到rsp+0x2fb8；`0x115cd98`写optional valid标志到rsp+0x2fc0。

这些写入实现 [certificate replacement](/home/passchaos/project-z/vort-zstd-work-accounting/src/zstd/literals/winner_cost_cache.zig:103)，不属于移除的certificate_age或refresh计数。Tree key/serialized-length缓存仍保留；stream product循环 `0x115c985–0x115ca02`继续检查bits非零、imul并检查sum溢出，仅statistics increment删除。New `0x115d190`和old `0x115d55e`都调用emitBestSequenceCompressedBlockWithScratch，candidate emission仍在。

## 状态大小和诊断范围

仅读取父代理已有独立probe记录：[native](/tmp/vort-zstd-work-accounting-20261025/state-native/run.log)为tracked6032 B / untracked5568 B；[x86-linux-musl](/tmp/vort-zstd-work-accounting-20261025/state-x86-final/run.log)为tracked5980 B / untracked5516 B。两者减少464 B。这是特定cache类型的@sizeOf，不能换算成完整函数frame、进程总栈、heap、RSS或allocation峰值。本次没有重新编译或运行probe。

便利Cache(Codec,mode)仍按源码选择track_work=true；显式profile_work=true诊断wrapper继续选择tracked类型。对这两个指定encode-bench做nm过滤未找到独立named benchmarkNativeMultiDuplicateProfile、anchor-profile或tracked CacheWithAccounting符号；名字未出现可能来自未链接或内联，本审计不据此推断诊断代码是否整体链接。默认routealone已由源码、真实caller和false类型helper证实。

## 验证和下一建议

已完成指定ELF/source SHA匹配、exact nm/asm取证、默认调用链与实例选择、旧统计字段/桶和新移除差分、checked histogram与certificate状态保留核对，并读取已有sizeprobe/build provenance。没有执行测试或计时，代码存在证据不替代运行兼容性结论。

下一建议：父代理完成当前family/check后，将这份机器码证据与功能验证及隔离benchmark合并。默认untracked和诊断tracked应继续分别验证；性能与memory声明采用实际测量的对应指标。
