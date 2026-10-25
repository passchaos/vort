# Full-window slot specialization：只读方案

当前源码冻结 SHA256 为 `a149d36ce699001e985b77541bb3cafc46447161efee8b5690db95acb127b0e4`。本轮只读源码与已有 timing-pairs/result.json；未修改源码、编译或计时。

已有三个完整 allocate/encode/checksum/free 点比值中，repeat65539 为 0.965589、0.969965、0.968706，值得进行一个有界 specialization 对照。distant131072 的 1.010838、0.975177、0.940325 波动更大，不能据此宣称同样稳定的回归。旧新 source/executable 稳定且记录零编译器进程；这些是单 workload 的点估计，不是显著性或 CPU 因果证明。当前没有已读取的热点 ELF 可证明容量 mask 就是约3%差异的原因。

当前 insert 和 find 中分别用 `position & (previous.len-1)` 和 `first & (previous.len-1)`。可以用两种精确等价的 slot policy：

```text
slotFor(comptime full_window, position):
    true  → position & 65535
    false → position
```

证明：begin 要求 previous.len 为不超过65536的幂次，并覆盖 requiredPreviousLen(history.len+block.len)。若容量小于65536，则总 span 必小于等于实际容量。合法 insert 仅处理 position+3<=span；合法 find 的候选满足 first<position<=span。因此实际索引均小于容量，原 mask 与直接索引相同。若容量等于65536，则固定65535就是原 mask；复用满容量去处理小 span 也继续走该分支，不需收缩或改 ring。所有 hash、链前驱顺序、距离65536边界、长度65538上限及 match-driven insertion 次序保持。

建议本轮只修改 stream_match 模块：public find 在已有 available/max_chain guard 后一次判定 previous.len==window_len，调用 findFor(true/false)；private generic core 包含原完整 finder 循环，通过 slotFor 得到固定 mask 或直接索引。public insert 使用原范围 guard 后一次选择 insertFor(true/false)，原 hash 与链写入仍由同一 generic body 实现。begin 在历史 insertion loop 外一次选择对应 insertFor，避免每个历史位置再选。不要增加运行时参数、字段、匹配预算或用户选项，也不改 callers 的编码/计划逻辑。

相比单个 runtime ringSlot(self,position) helper，这个设计把 find 的选择明确移到链循环之外，避免每个 candidate 的 capacity load/sub 或 cmp/select；runtime helper 不能凭源码保证循环中被消除。insert 仍每个 public 调用选择一次，cmp/branch 代替旧 load/sub 是否更快需要机器码及计时验证，不预先承诺。私有 insertFor 可保持很小的 inline body，findFor 不强制整个循环 inline/noinline；编译器可能合并或内联，两份 specialization 的实际 code growth 也必须检查。

验证只需复用已有 full-window 独立 reference 和窄矩阵，额外强调：fresh small ring、grow 后 begin、满容量复用小 span、history+block 正好65536及超过65536、65535/65536/65537位置、实际 distance65536/length65538、不同max_chain/nice。OOM/remap/资源容量不变；source phase 一致后由父任务统一编译，核对 full finder loop 的固定 mask、小 ring 的直接索引及必要 bounds checks，再运行已有三点完整对照。若 insert dispatch 或代码布局使任何主要 case持续退化，撤回此次 specialization，保留资源优化和已存对照，不降低匹配质量来换比值。

改动不修订任何 unsafe 调用的语义，合法 domain 仍是完成 ensure/begin 后的当前 block-local positions。当前只是建议，等待父任务授权后才可实施。
