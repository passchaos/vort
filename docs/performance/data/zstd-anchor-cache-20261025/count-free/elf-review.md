# Count-free anchor 实验 ELF 审计

审计时间：2026-10-25T15:41:14.725579+08:00，Asia/Shanghai。范围为 `/tmp` 独立实验及指定旧 profile=true ELF 的静态对照；未编译、计时、运行测试、修改源码或 Git，不作生产收益声明。

## 结论

两条 count-free 入口均为 cache_costs=true、profile_work=false、.prune、profile=null，区别是 enabled 路径准备并复用 anchor hashes/lengths。实际 enabled scanner 的 anchor build/query/hit/miss Work 更新已消除：命中分支直接使用 cached length，跳过 extender，也没有命中饱和计数。

但实验并非“所有 counter 都不存在”。两条入口调用同一个独立 `payloadForWinner` 函数，该函数仍包含 winner/exact 成本缓存的 Work 和 certificate-age 饱和更新。这里能确认的是特定 anchor 更新的消除和其他更新的保留，不能宣称 counter 零开销或从指令存在推导 cycle 差异。

Anchor allocation、完整 hash/length 初始化、正常释放均处于 enabled candidate 调用内。候选 emit 和完整输出比较实际保留，输出未被 DCE。整个比较仍是独立候选阶段实验。

## 来源与可复查产物

- [结构化审计](/tmp/vort-zstd-anchor-cache-20261025/count-free/elf-review.json)
- [enabled exact asm](/tmp/vort-zstd-anchor-cache-20261025/count-free/exactasm/enabled.asm)、[baseline exact asm](/tmp/vort-zstd-anchor-cache-20261025/count-free/exactasm/baseline.asm)、[符号表](/tmp/vort-zstd-anchor-cache-20261025/count-free/exactasm/symbols.nm)
- [enabled hit/miss](/tmp/vort-zstd-anchor-cache-20261025/count-free/exactasm/enabled-cache-hit-miss.asm)、[保留的成本计数写入](/tmp/vort-zstd-anchor-cache-20261025/count-free/exactasm/remaining-cost-work-writes.asm)、[完整共享成本函数](/tmp/vort-zstd-anchor-cache-20261025/count-free/exactasm/cost-payload-for-winner.asm)
- [profile=true query/hit/miss 对照](/tmp/vort-zstd-anchor-cache-20261025/count-free/exactasm/profile-true-anchor-query-hit-miss.asm)、[profile=true exact main](/tmp/vort-zstd-anchor-cache-20261025/count-free/exactasm/profile-true-main.asm)
- [分配与准备](/tmp/vort-zstd-anchor-cache-20261025/count-free/exactasm/enabled-allocate-and-build.asm)、[emit与释放](/tmp/vort-zstd-anchor-cache-20261025/count-free/exactasm/enabled-emit-and-free.asm)、[准备地址枚举](/tmp/vort-zstd-anchor-cache-20261025/count-free/exactasm/precompute-address-summary.json)
- [timed enabled](/tmp/vort-zstd-anchor-cache-20261025/count-free/exactasm/timed-enabled.asm)、[timed baseline](/tmp/vort-zstd-anchor-cache-20261025/count-free/exactasm/timed-baseline.asm)、[候选调用点](/tmp/vort-zstd-anchor-cache-20261025/count-free/exactasm/probe-candidate-call-sites.asm)、[共同 emitter](/tmp/vort-zstd-anchor-cache-20261025/count-free/exactasm/candidate-emitter.asm)

| 来源 | 实读 SHA-256 |
|---|---|
| count-free ELF `anchor-count-free` | `0f2747a25fb9b505ec4ddb9810f97ca90aec082df363609e7899c860ef8147bc` |
| 临时 `src/zstd.zig` | `94b657e61588848718baca559ddf85a0f0d9d2e989bf4b3edbcd5db8a4e5572c` |
| 原 workspace `src/zstd.zig` | `08ad02b510a0cc83bc667b56a00b339f3e55fdac1daaff142d3b6de8f044f8b5` |
| 两树 `paired_anchor_cache.zig` | `162a3afef29c137aba7d2fbcfb4cf702c01e38493cc079cbad850a818c935dc7` |
| probe | `f3825a1000aa2a116d1dacb3a7fce802be0ed5ddf1b43d3af0bc0c34b982a82c` |
| profile=true ELF `anchor-profile` | `c6382712b17036e8dfd92c9d2bf3936fd4baccddf9583e78ed41dada65fc2424` |

实读确认临时 zstd 源码恰为原 workspace 源码加 `wrapper.zig.txt`，core SHA 一致。已有 build-record 为 Zig 0.16.0、ReleaseFast、各模块 `-mcpu=native`，构建命令以 `probe.zig` 为根模块并引入 `src/zstd.zig`；build-result 记录结束时间 2026-10-25 07:36:00.896752 UTC、exit0、probe 未运行。本审计没有执行 ELF 或读取计时结果；父代理负责后续 compiler/check 结束后的运行。

## 两条真实路由

[临时 wrapper](/tmp/vort-zstd-anchor-cache-20261025/count-free/src/zstd.zig:45990) 只接受 `65535 < N <= 131072`；both compile-time enabled 实例实际保留：

| 实例 | ELF符号及地址 | 大小 | 实际路由 |
|---|---|---:|---|
| false | `benchmarkUnprofiledAnchorCandidate__anon_3085`，`0x10f4aa0` | 1562 B | ProfiledMode(true,false,.prune) → WithAnchors(reuse=false) |
| true | `benchmarkUnprofiledAnchorCandidate__anon_3091`，`0x10beed0` | 2404 B | alloc hashes/lengths → Cache.init → WithAnchors(true,false,.prune,true) |

[共同 candidate core](/tmp/vort-zstd-anchor-cache-20261025/count-free/src/zstd.zig:23314) 在 profile_work=false 时不执行显式 profile publication、finder_calls 或 selected_matches accounting；两条都选择同一 SingleLiteralWinnerCache、都以 null duplicate index运行。实际 scanner 已内联到两入口，未调用 profile=true API。`probe.timed__anon_3112` 在 `0x1060a98` 调用 false；`probe.timed__anon_3146` 在 `0x1060c78` 调用 true。两个 timed 函数同为469 B。

False 每 query 原输入八字节 anchor hash 乘 golden-ratio 常数、shift49；true 在 `0x10bf34b` 从 prepared u16 hash 读取。两者 scanner 保留同一 pending/predecessor、candidate guard和winner cost路径。False `0x10f4d4f`、true `0x10bf4a4` 都调用 `0x10f1840` 的同一个 .prune payloadForWinner。

## Anchor Work 与残留计数

[core](/tmp/vort-zstd-anchor-cache-20261025/count-free/src/zstd/match/paired_anchor_cache.zig:18) 的 Work 有 build_hashes、query_hashes、extension_calls、extension_hits、workspace_bytes。源码 init/hash/cachedLength 在更新前四者时均使用 `+|=`；临时 wrapper 不导出或查看 anchors.work，且 anchor 操作内联到本地 scanner。

Enabled `0x10bf3a2` load lengths[second]，`0x10bf3a6` 建立 UINT32_MAX sentinel，`0x10bf3ab` compare，`0x10bf3b2 jne 0x10bf406` 是 hit。命中后直接取得 cached length，`0x10bf40a` 检查 length≥8；没有 Work hit更新、没有 extender call。Miss 在 `0x10bf3d4` 调用 duplicateMatchLength，`0x10bf402` 将真实length写回，再到同一 `0x10bf406`。Miss没有 extension_calls更新。Prepared hash读取前没有 query_hashes更新；build loop只有 hash/length backing store与索引推进，没有 build_hashes更新或anchor Work publication。两个完整入口无 cmov 指令；循环索引、pending表和长度写回保留，不将这些功能性写入称为计数。这里的消除结论限定这份 ELF 的这些内联 anchor 操作。

共享成本缓存仍有下列静态写入，`profile_work=false` 没有使它们消失：

| 字段 | 实际位置 | 形式 |
|---|---|---|
| bound_work.queries | `0x10f1868–0x10f187d`，self+0x1600 | load/inc/cmove(UINT64_MAX)/store |
| certificate_age | `0x10f188d–0x10f189b`，self+0x15f8 | 有证书时饱和累加 |
| inner.work.cost_queries | `0x10f2cf2–0x10f2d07`，self+0x1080 | load/inc/cmove(UINT64_MAX)/store |
| inner.work.huffman_plans | `0x10f2d36–0x10f2d44`，self+0x1088 | eligible分支饱和累加 |
| inner.work.stream_symbol_products | `0x10f328f–0x10f329d`，self+0x10a0 | 有效symbol分支饱和累加 |

该函数是独立共享符号，大小9063 B，仍按指针更新成本缓存；anchor函数内联并局部优化，而成本函数保持独立，是实际factoring差异。汇编能记录这种DCE范围，不能仅凭它断言编译器具体优化原因或残留计数的cycle成本。仍有其他cost/bound更新，本表列举足以否定“全部计数为零开销”。

指定 profile=true 对照的 scanner 内联于 `multi_duplicate_profile.main`：`0x1064b8c–0x1064b93` 在prepared hash load前保留query_hashes的register inc/cmove；命中 `0x1064bef–0x1064bfd` 保留stack hit load/inc/cmove/store；miss `0x1064c0c–0x1064c1a` 保留extension_calls的同类写入后再call extender。Count-free在相应anchor分支消除了这些更新。两ELF整体入口、factoring和consumer不同，该对照仅用于说明静态计数保留，不用于生产或速度结论。

## 准备、计时边界与候选输出

Enabled allocation真实保留：`0x10bef5a` 通过 allocator vtable alloc申请2×M bytes、alignment log2=1；`0x10befb1` 申请4×M bytes、alignment log2=2，其中 M=N-7。Range/overlap admission仍在，之后 `0x10bf14b–0x10bf1f0` 四路展开bulk加scalar remainder，写每个u16 hash和UINT32_MAX length。

对probe固定 N=65536，M=65529：hash backing store 131058 B，length初始化store262116 B，used payload393174 B。每个anchor仍读8 B，指令load operand总524232 B；logical input span为65536 B，重叠读取不是一次完整64KiB读取。逐index枚举覆盖全部hash/length条目各一次、input `[0,65536)`，无overread。

`0x10bf803` / `0x10bf820` 在正常candidate emit返回后调用allocator free释放两storage，随后入口返回。Probe timer先clock、call入口、再clock；故两次allocation、Cache.init、candidate emission和anchor正常释放都在timer内。Input读入、wire/hash预检、full wire比较和out buffer deinit位于timer外。仅凭allocation参数不推导heap/RSS或进程总栈；本次未计时。

Enabled先allocation和Cache.init、后执行共同candidate的rleByte过滤；baseline先过滤再准备cost cache。二者都先经过外层长度检查。这是wrapper本身的实际边界，不假设所有输入都走完scanner。

候选output未DCE：false `0x10f506e` 和true `0x10bf7a4` 实际调用同一个 `zstd.emitBestSequenceCompressedBlock`（`0x10bf840`、15377 B），转发caller的out；共同emitter的allocation、append、ensureUnusedCapacity和memcpy调用保留。不是仅返回长度或可用性。正常emit只在candidate序列数足够时进入，提前false分支仍可能无wire。

Timed caller停止clock后仍读取实际out.items指针和长度，并以 `mem.eqlBytes` 比较整个wire：baseline `0x1060b16`，enabled `0x1060cf6`；available差异或bytes差异都会返回WireMismatch。Out buffer cleanup随后执行。这些消费者是实际ELF中的输出保留证据，本审计没有执行它们，不能把静态存在报告成已跑过的wire一致性验证。

## 交接

已核SHA、临时wrapper-only append、两profile=false specializations、anchor hit/miss与profile=true对照、残留cost计数、allocation/init/free边界、output emitter与完整bytes消费者。只写本目录报告和exactasm证据，没有任何源代码或Git操作。

下一建议：父代理等live check/compiler结束后再运行这份pinned实验；解读结果时明确anchor更新被消除、通用cost计数仍在，以及preparation/free包含在timer。任何生产判断仍需生产ELF、兼容性和独立benchmark证据。
