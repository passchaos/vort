# Literal fallback pilot: rejected control row

本包保存2026-11-27的首个独立 Zstd literal-fallback pilot 原件。aggregate throughput GM 为 **1.0477891348148398x**，但 **ooffice 为0.9754890473549731x，低于预先固定的0.98x行门槛**。`target_gate_pass=false`，没有 performance acceptance；不得据此重采样、放宽门槛或签发formal。formal、controls、reference均未运行。

比较是当前候选 `beb79f99…` 对冻结 Git baseline `d5d9d8aa…`，全12 Silesia原64KiB输入，每行AB/BA两轮，共24pairs/48children。公开 `encodeFrameWithLevelAlloc(level3)`，greedy/search-budget24/repfalse/fast_compressed，无dictionary；对称warm1立即free，连续encode+lengthmix+free。完整SHA/decode只针对初始warm wire，timed output仅检查length/mix，不虚称timed full-wire SHA。

| Corpus | Paired throughput GM |
|---|---:|
| dickens | 1.047875174 |
| mozilla | 1.020022807 |
| mr | 1.042413567 |
| nci | 1.244418902 |
| ooffice | **0.975489047** |
| osdb | 1.076188749 |
| reymont | 1.064044728 |
| samba | 1.009662794 |
| sao | 1.036422368 |
| webster | 1.064408389 |
| x-ray | 1.004617062 |
| xml | 1.010340825 |

主机是 Intel Core i7-10700K，CPU2、single-thread、ReleaseFast、Zig0.16.0、x86_64-linux-gnu、skylake+pku+sgx。这是开发主机上匹配 lifecycle 的小型pilot，不是 dedicated-host、matched-quality competitor frontier或行业最佳证据。两轮没有CI，全部raw保留，不筛选波动行或用其他epoch比值相乘。

## 原件与身份

`epoch-data.tar.xz` 保留原epoch的5257份普通文件：所有48 child JSON/stdout/stderr/initial wires、pilot protocol/release/manifest/summary/actualterminal、完整两个frozen source registries及source bytes、actual ELF/object attempts、harness、inputs、原build/preflight/runtime/provenance和历史准备记录。只排除非source编译/runner caches；登记src bytecode保留。原symlink的目标bytes按原逻辑路径保存，target注明在manifest；captured程序在tar内mode0644，仅作数据。

source registry SHA为 baseline `1636c421…`、candidate `beb79f99…`。actual binary、harness、每input、完整warm wire、release和whole gate身份由 `evidence-manifest.json` 逐成员length/SHA绑定。`whole-original-*` 是原whole-library actualreceipt/stdout/stderr/before/after五份文件的原bytes，独立SHA与origin保留；whole gate当时actual0/419steps/6108tests+2skip属于功能硬门，不会将失败的性能pilot提升为接受。

原epoch、生产源码和父级report没有改写。`export-originals.py` 是本次有界原件复制工具；复制包不会构造、编码、解码或测量新样本。

## 离线验证与独立拒绝复核

`verify-evidence.py` 从原epoch逐字节复制，不import producer或调用codec；验证整个archive/source/ELF/member inventory和原点值。`point-recheck.py` 独立从全部48 raw ns重新算paired row GM和equal-row aggregate，核原argv、公开L3选项、source/input/ELF/CPU/thread/warm1与完整初始wire，并强制复核ooffice拒绝、CI=null、formal_authorized=false。

两次命令均从 `/tmp` 工作目录运行，actualexit0。验证程序只读取包内数据，不访问原临时epoch路径；原absolutepaths保留为provenance labels和精确查表键。

```sh
cd /tmp
python3 -B /path/to/package/verify-evidence.py --package /path/to/package
python3 -B /path/to/package/point-recheck.py --package /path/to/package
```

结果分别在 `verification-original.stdout.json` 和 `point-recheck.stdout.json`；对应stderr和 `verification-receipt.json` 保留actual exits与文件SHAs。`SHA256SUMS` 绑定本目录全部最终文件。没有运行C库、Vort codec、build、timing、RSS或bootstrap。
