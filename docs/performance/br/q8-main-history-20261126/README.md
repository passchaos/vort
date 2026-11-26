# q8 main 历史采样与阶段诊断 — 2026-11-26

此包分别封存公共 allocating q8 历史 A/B 和当前 main 的阶段诊断。
两种 scope 分开验证；归档通过不代表性能已恢复或获得行业验收。

| 证据 | 完整范围 | 结果方向 |
| --- | --- | --- |
| 历史源码 A/B | 12 个 64 KiB 输入，6 对主轮；Dickens/Mozilla/NCI 各额外 6 对，共 90 对 / 180 次计时调用 | 当前 / 历史耗时 GM **3.203170864687844**，95% CI **[3.1842254436026094, 3.2222290067428885]**；当前更慢 |
| 编码大小 | 保存的完整初始 wire，24 份 | 当前 / 历史大小 GM **0.9565808633658663** |
| 阶段诊断 | 12 输入 × 3 轮，共 36 trace；所有事件完整 | 1,029 次物理 wire，993 次 lost，1,746 次 evaluation；计时只用于诊断 |
| context 细节 | 18 次完整，18 次只保留最多 8 条前缀 | 保留细节中 observed reuse 共 **87**；被截断轮的完整 reuse 数保持 `null` |

采样比较 `0a673757ea6a1e88b90794ad44dce1a8a824f371` 与已提交 main
`8ccd54a59da850da724cc4d6ca79a727c659889e`，不包含工作树修改。
公共选项均为 q8 / generic / explicit window16，Zig 0.16.0、ReleaseFast、
GNU x86-64、`skylake+pku+sgx`，Intel Core i7-10700K，单线程固定 CPU2。
每个进程一次 encode/free warmup；连续计时覆盖 allocating public encode、
length mix 与 free。完整 SHA/外部解码只验证计时外的初始 wire；计时输出
只核对长度/mix。全部样本保留，没有离群值删除或成功样本重试。

Root 在采样前收齐重任务停止状态并写入 `ROOT-HEAVY0.json`。
实际采样为 **2026-11-26 10:24:15.408945–10:24:50.368971 UTC**，约
**34.96 秒**；按 Root 本轮调度记录，该窗口没有其他构建、归档或 profile
重任务同时运行。记录的 92 次 runner snapshot 没有匹配 collector。
这些 snapshot 和进程过滤记录不是连续零干扰证据，也不是专用性能主机
验收。原始 settings/summary 中继承的 pending/nonquiet 文字原样保留；
Archimedes 的独立 host 注释另存，没有重写原始 scope。

诊断使用同一 main 编译源码，36 次 ordinary/profile 均由 producer 比较
完整字节并通过 Vort round-trip。诊断工具不导出新的 profile wire；它们
通过 row SHA/大小绑定到保存的 c2 gold。libbrotli **1.2.0** 的独立解码
记录覆盖 12 份保存的 gold。包内另核对这些 gold 与新 main 采样的初始
wire 逐字节相等；没有把它称为对每次 profile 输出的新外部解码。

原 profile gate 的实际 exit1、失败输出、临时 adapter/diff 和 6 项测试
全部保留。Root 冻结的新 gate、diff、项目入口 **3/3 steps、24+11 tests**
以及真实 36-trace gate exit0 同时封存。新 gate 对完整 proposal hit
要求明确的 scorer 计数字段和零工作计数；包内复核使用该冻结源码，
通过内存输入适配器验证原事件，不调用 CLI 或原始路径。

归档内容：

- `timing.tar.gz`：全部 runs/raw-pairs/manifest/summary、24 份完整初始 wire、
  libs、ELF、probe/object/build、失败回执、Root release、独立统计/host 收据。
- `diagnostic.tar.gz`：完整 `profile.json`、stage raw/CSV/summary、gold/input/libs、
  ELF/object/build、原失败 gate、tmp6tests、Root 冻结 gate 与 24+11 测试回执。
- `sources.tar.gz`：完整 current **2,200** 和 old **1,690** 个 src 文件，
  main 的 build/tools/probe 所需代码、build.zig/zon 和 vail 依赖。诊断与
  timing 的同源 main src 只存一次，映射见包内 `source-closure-audit.json`。

原始源码 tar 的 SHA/大小已核对，保留成员与原 Git tar 逐字节一致。
原 1.60 GB main tar 中已有 docs 大归档、examples/corpus/CI/项目文字
等 7,910 个非编译闭包成员不重复打包，逐项记录排除路径/大小；Zig/Git/
Python caches 排除。完整编译输入与所有原 raw/evidence 保留；不声称
复现原 tar 容器元数据或整仓库测试。归档程序均以 0644 数据模式保存。

离线验证：

```sh
python3 -B docs/performance/br/q8-main-history-20261126/verify.py
```

也可复制整个目录，在任意位置执行 `python3 -B /copy/path/verify.py`。
验证器只读取当前包，在内存中读取 tar；核对输入/source/ELF/object/wire、
参数/生命周期/时序/终态及已保存的失败证据。它调用逐字复制的
Archimedes `reduce_statistics(pairs, sizes)`，重算全部配对行及 20,000 次
确定性 AB/BA 分层 bootstrap；矩阵只使用共享的六个主轮，不让弱行追加
轮数增加其权重。不会执行 producer、codec、参考程序/SO、编译或计时。

该历史采样表明当前 main 在这组输入和生命周期下更慢；没有测量 RSS，
物理 wire 字节总量也不是 heap 或内存流量。优化归因和性能恢复仍需新的
独立源码 A/B 与明确控制行门槛。
