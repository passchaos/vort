建议下一增量只做一件事：**在同一频率支持集上，用上次Huffman最优加权bit成本形成可证明的当前成本下界；下界已证明不能更新当前finder winner时，跳过完整Huffman planning。** 不猜码长保持、不降级别、不关闭multi、不改变候选上限。本建议未实现，未编译或计时。

它与被否决的exact频率缓存不同：即使当前向量与旧向量不同，也能取得一个安全下界。它也不把旧plan对新数据的dot-product当作下界——那只是可行plan的上界，不能直接用于拒绝候选。

**范围与当前事实**

父诊断给出XML约1.47m评分/128finders，tree长度cache约99.9%，exact频率hit仅65。现有medium workspace收缩保持同engine，却不消除planning调用次数。本报告仅据当前源码及父数据设计一项保旧winner的剪枝，不声称它的拒绝率或速度收益。

范围限定现有unindexed multi、single-sequence legacy cost、block<=131072，max Huffman bits固定11；仅已形成incumbent的query可剪枝。原hash pairing、完整match length、suffix break和duplicateMatchCannotBeat全部先照旧执行。

**数学证书：下界不依赖新码长是否相同**

设f为上次完整规划的256项频率，R_f=sum(f)，l_f是现builder在相同max_bits=11约束下给出的最优长度向量：

```
C_f = sum(f_i * l_f_i)
```

证书储存f、R_f、C_f（约1KiB+几个scalar），不必保存整plan。只对当前g与f有完全相同非零支持集且至少两个符号时启用；support改变、无成功证书、小literal、RLE或超出声明bounds时沿原路径。

令delta_i=g_i-f_i，R_g=sum(g)，D_minus=sum(max(f_i-g_i,0))。任意当前合法长度向量l均有1<=l_i<=11，且在相同支持集上也是旧f的一种可行编码。因此：

```
sum(f_i*l_i) >= C_f
sum(delta_i*l_i) >= sum(delta_i>=0 ? delta_i : 11*delta_i)
OptBits(g) >= C_f + (R_g-R_f) - 10*D_minus
b = max(R_g, C_f + (R_g-R_f) - 10*D_minus)
```

b是安全整数bit下界。max(R_g,...)来自每个active符号至少1bit。使用i64处理中间有符号值，最终checked转换；R<=131072、C_f<=11*131072，D_minus<=R_f，native/x86均远低于整数上限。

这个证明依赖C_f是旧频率在同一可行域的**最优值或可信下界**，不能拿任意非最优可行plan的上界代替。当前Codec.planFromFrequencies委托11bit Huffman builder，package-merge或已验证合法自然树返回最优加权成本；medium workspace保同engine。新测试必须把每个发布证书的C_f与FullWidth weighted optimum、tiny exhaustive oracle核对，长度ties不影响该最优scalar。若以后builder改为tree-header-aware启发式、改变bit cap或不能证明最优，必须禁用或换独立可信lower certificate。

例：f=(50,25,25)，旧最优(1,2,2)，C_f=150；g=(51,24,25)，D_minus=1、总量不变，11bit域给b=140，真实最优149。无需g==f，也无需断言l_g==l_f。证书保守但正确。

**将bit下界转成旧literal成本下界**

先照旧执行CutHistogram.update、totalFrequencies、unique计数（`single_cost_cache.zig:89`），保其错误admission和legacy视图。只有unique>=2、R>=64时才用证书；RLE已经被真实当前频率排除，不使用“看起来不像RLE”的代理。

原legacy literals仍为：

```
p = second_start - start_min
t = second_start + match_len
view = block[0..p] ++ block[t..]
R = p + N - t = N - start_min - match_len
```

不是block[start_min..second_start]。同支持集不要求相同cuts或四流分布。

S=1当R<=1023，否则S=4。实际所有流的bit总和为当前Huffman加权成本C_g>=b，每流至少一个终止bit：

```
streams_lb = ceil((b+S)/8)
if S==4: streams_lb += 6
```

可以再取max于按每流regenerated长度得到的一bit下界，但第一版不必增加复杂度。ceil(sum/8)<=sum(ceil/8)，所以无需知道当前四流各自码长也不会高估。四流六字节jump准确加入；若真实u16/size限制使Huffman unavailable，仍保留这个放松分支只会使下界更低，不能造false rejection。

有效fresh tree的serialized length至少2：direct最高symbol>=1时1+ceil(max_symbol/2)>=2；FSE description是1+payload，而其bitstream包含end marker，payload>=1。Huffman header按R的minimum为3/4/5（<=1023、<=16383、其他；真实compressed-size可令它更长）。因此：

```
huf_lb = header_min_by_R + 2 + streams_lb
raw_exact = old_literalHeaderLen(R) + R
literal_lb = min(raw_exact, huf_lb)
```

即使Huffman tree最终无可用序列化形式，relaxed huf_lb仍不会提高min。unique==0/1、小于64等旧快速路径不需要新证书。建议树minimum=2作为独立oracle测点；若codec契约无法保它，第一版保守设0也仍正确，但会更弱。

**序列部分：复用原函数，不另造FSE算法**

旧single cost中的RLE/predefined表family共用同一literal section，两个helper仅在结果上加literals_section_len（`src/zstd.zig:28082`、`:28096`、`:28236`）。因此先用相同p、offset、match_len，只把**第四个参数literal section bytes设0**：

```
seq0 = min_available(
    Codec.rlePayloadLen(p, offset, match_len, 0),
    Codec.predefinedPayloadLen(p, offset, match_len, 0))
LB = seq0 + literal_lb
```

不是把prefix_len/literal_len设0。保原CorruptFrame不可用/其他error逻辑；未剪枝时复用seq0，加原精确literalSectionLen得到原完整数值，避免把两个helper算两次。新受限入口只用于合法matched参数；原unlimited payloadLen和malformed/error入口保持原顺序，不能因重排操作改变公共错误。

建议私有接口形态为`tryPayloadLenBelow(..., incumbent_cost, incumbent_match_len)`，返回成功精确cost或“已证明无更新可能”的状态。第一步仍update histogram/validate，再判断证书。不要把缺证书或lower bound不能拒绝当成成功null/raw fallback。

**拒绝条件与旧winner证明**

原finder只在cost更小或相同cost而match更长时更新（`src/zstd.zig:findBestDuplicateMatchHashedImpl`末尾）。新条件只能是：

```
LB > incumbent_cost
or (LB == incumbent_cost and candidate.len <= incumbent.len)
```

如果LB==incumbent但candidate更长，必须完整定价。actual_cost>=LB保证被拒绝候选不可能更新best；best及其length不变，所以之后原suffix bounds、old domination和最终winner也不变。pending/hash phase必须已按原规则翻转，不能提前跳过它。逐query winner不变，128步选出的pair列表不变，最终multi/whole frame wire保持原输入与状态。

**不要拿此single下界与外层5KiB winner直接关闭multi。** 最终multi可由128个matches进一步削掉literal；single-view lower bound不是整个multi family的可实现lower bound。本增量只比较当前finder incumbent，避免为整个selector做未证明的捷径。

**证书更新与开销**

只在一次完整定价成功、Huffman plan有效时发布f/C_f；错误或无plan不发布。第一版可以只使用successful non-null tree与successful streams所得weighted总bits，复用已算的四流bit总和，少一次dot-product。跳过的候选不更新证书；证书可能变旧，但只影响sharpness，不影响数学下界。null/RLE无证书时保原路径。

f需要约1KiB固定存储，R/C/valid少量scalar；当前cost state仍可要求<8KiB，不新heap/global/userknob。支持集和D_minus可融合进已有256项合并/unique循环。没有log2、浮点熵、巨大lookup表或新Huffman构造。证书copy只发生完整成功规划后，若剪枝低则这也是额外开销，必须测。

父给出的histogram scanned平均约33B/query仅提示相邻cuts变化较小，不能直接推出证书distance或拒绝率；一旦连续剪枝，certificate可能不是上一query，差异会累计。频率完全一致命中率很低不否定近邻下界，但也不证明它有效。

**独立proof/oracle门禁，先潜在拒绝计数再启用**

1. Tiny alphabet exhaustive长度/Kraft枚举：固定B如3/4，正频率f/g覆盖权重增减、ties与总量变化，逐例验证b<=Opt(g)；同时测不支持mask改变时必fallback。真实B=11测试与oldFullWidth weighted optimum核对证书C_f和b，不能只测成本相同的几组树。
2. 每个candidate在诊断模式先仍计算old exact cost。记录would_reject并断言其不满足旧update条件；覆盖LB==B/更长tie、raw/Huffman切换、RLE、小literal、1023/1024、header4095/4096/16383/16384、65535/65536/65537/128KiB和highbyte、tree-null/error。此阶段不改变wire。
3. 拒绝率有价值后才开启early return，逐candidate shadow oracle、每query oldwinner/选中pair、完整multi wire、14旧frame hashes、native/x86与allocator请求/精确cap一起验证。source和profile未齐之前不做quiet排名。
4. 计数：certificate_available/support_mismatch、bound_checks、would_reject/rejected、actual_huffman_plans、certificate_refreshes、D_minus和certificate_age分布、LB距离incumbent、真实oldcost-LB slack、等成本更长保留数。每query汇总，不147万次日志/clock；shadow/reference开销与production timing分开。
5. 若同支持集下界大多过弱或copy/check成本吞掉收益，如实否决，不降低候选/level阈值。没有当前拒绝率证据，本报告不承诺数量级提升。

这是一个可独立证明和oracle验证的bounded候选；“用旧码长给新频率精确报价”没有同等级proof，当前不推荐实施。

**本次读取的源码绑定**

| 文件 | SHA256 |
| --- | --- |
| `src/zstd.zig` | `ef5497a1db44d130f8eae02ab5c8337055126866b26a765f44eb7de3eabb4984` |
| `src/zstd/literals/single_cost_cache.zig` | `648128d3ced0dbb4cf10d897e662635d6d7d201bf13f457f6b78a2e303245e76` |
| `src/zstd/literals/cut_histogram.zig` | `c5b3b1eb9d8718db51d00329efe0f1e68448bdd8d6c2451e22c1b9f4fde4c386` |
| `src/huffman.zig` | `2bfc756f0d0380eeab5f6bc9e268ef14294aa5816dbdb1e039390bdabb682aa3` |

记录UTC：2026-10-25T05:45:22.653780+00:00。源码冻结，本次仅写报告。
