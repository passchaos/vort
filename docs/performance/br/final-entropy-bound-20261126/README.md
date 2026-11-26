# Global final entropy bound：ROI 拒绝 — 2026-11-26

此包封存独立 global final entropy bound epoch。完整 pilot 为 **24 pairs /
48 calls**，原独立验证 actual exit0；speedup GM **1.0156422687081639**
低于 1.03，最小行 NCI **0.993756037054902**，全部行通过 0.98 下限。
**ROI 被拒绝，CI 为 null，full 未批准、未启动，候选不能据此采纳。**
本结果没有 full/global 行业性能结论，不与先前 local rejection 拼接。

基线为 clean CF `cf442dee0144f4c0cc1823474f77c7e8b1685f2e`；候选为
`cf-global-entropy-bound:4cd88fda7a97f8e9b9bbc81fc93ef18711965f31b80dd1136334b1374286c78f`。
权威源码是 global 根的 `final-source.json` / `SOURCEFREEZE`，注册 src
**2,211 个文件**。完整编译闭包保存 CF **2,992** 与候选 **3,127** 个
文件，候选 **125 个 pyc** 均按原字节保留。所有输入来自冻结 benchmark
和 snapshot；没有采集后来 live Root source。

公共 API 为 q8 / generic / explicit window16，Zig 0.16.0、ReleaseFast、
GNU x86-64、`skylake+pku+sgx`，i7-10700K、单 codec 线程固定 CPU2。
每进程一次 encode/free warmup 在计时外；连续计时覆盖 allocating
public encode、length mix 和 free。24 份完整初始 wire 与 CF/C2 gold
逐字节相等，原 pinned libbrotli **1.2.0** 解码收据通过；计时输出只核对
长度/mix，没有在计时内做完整 SHA。全部样本保留，无离群值删除或成功
样本重试。Host snapshot 不构成连续零干扰证明。

冻结源码保留 RFC static eligibility 修正：标准 LZ 与现有 RFC static
references 属于固定最终熵阶段，HQ/compound、shared/serialized、large、
metadata 等不支持路径保留 boundnull。最初 native activation 失败
（session17382 / chunk `8a090a`）的真实 combined JSON 已恢复：34/35
tests pass，五个 synthetic wire 保持原字节，但均 entry1 / rejection0。
该失败、原控制与 activation 断言保留，后续 gold 扩展没有伪造覆盖。

最终验证证据均完整保存：

| 运行 | 原实际终态 | Mozilla OOM / active retry | Gold owned-release 范围 |
| --- | --- | ---: | --- |
| Native ReleaseSafe | chunk `d82912`，exit0，36/36 tests | 550 / 550 | Mozilla/Xray owned0；owned retry0 |
| 实际 WASI 32-bit | exit0，36/36 tests，compiled wasm SHA 一致 | 583 / 583 | Mozilla/Xray owned0；owned retry0 |

原输出覆盖 unlimited probe、exact-D 成功、D−1 配额拒绝、无限配额重试和
Mozilla allocation-ordinal OOM sweep，记录 live0、正 bound entry/rejection。
这些是保存的资源契约验证，不是与 CF 的资源性能 A/B。**没有 nonzero
owned normal discard / owned-release retry 覆盖**，不能从 gold activation
或正 global rejection 推导其覆盖。

Native 与最初失败的 JSON 通过指定原 session 的 exact rg 和 bounded
slice 恢复：原 JSON 字段与 combined output 保留，不拆成假定的独立
stdout/stderr。`session-recovery-provenance.json` 记录行31829/31636及来源。
Global WASI 原路径虽然位于先前 validation 目录，其文件字节与 global
根复制件完全一致，映射在 `validation-epoch-map.json`。旧 local
final-source2204、Native29、WASI29 均没有用作 global2211 验证。

Root `live-before-stash-verification.json` 记录冻结2211资产一致。
`stash-verification.json` 记录 stash
`5e431ffff10d57fc576c97f49d1fbb5ea330cf58` 保存2210资产；一个 gitignored
src pyc另存 `ignored-source-assets/`，其原字节 SHA 与冻结 manifest 相同。
首次将该 ignored pyc 视为缺失的核验原因原样保存，修正后记录与2211
manifest完全匹配、生产2200恢复HEAD；这是原回执核对，没有重采 live source
或重执行 Git stash。

包内三个归档：

- `sources.tar.gz`：完整冻结 CF/candidate 编译闭包、生成 pyc、全文件
  SHA/大小清单及归档工具。没有复制巨大 docs 归档或编译 cache。
- `bench.tar.gz`：全部 pilot raw/192 sidecars、独立 runner/统计代码与
  actual exit0 回执、SOURCEFREEZE/HEAVY0、policy、input/gold/24 wire、
  decoder receipts/libs、ELF/own object/build，以及不存在 full 的清单。
- `validation.tar.gz`：global权威 manifest/marker、真实 Native/初期失败
  combined结果、实际 WASI output/receipt/wasm/object、精准epoch映射、
  session恢复出处和stash/ignored asset原回执。

离线验证：

```sh
python3 -B docs/performance/br/final-entropy-bound-20261126/verify.py
```

可复制整个目录后执行 `python3 -B /copy/path/verify.py`。验证器只读取
包内字节，在内存中读 tar；独立重算 pilot 配对比值/行GM/门槛，核对
raw、完整 wire、源码/pyc、source-before/after、ELF/object、实际验证与
资源字段、owned0范围及原始失败。不 import/eval producer，不执行
codec、参考程序/SO、编译、测试或计时。两个包内 reader 适配失败及
修正另存 `verification-attempt1/2.json`，原数据未改。

该 primary pilot 未过 ROI。正式 CI、完整90-pair matrix、q4/q11/ratio
controls 及 full-source adoption 未由本包完成或批准。
