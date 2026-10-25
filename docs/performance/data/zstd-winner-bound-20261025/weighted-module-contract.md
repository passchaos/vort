weighted_bound.zig纯数学固定证书模块已实现并冻结。本代理仅新建该生产文件，没有修改cache/facade/tools/tests/Git，也没有编译、编码或计时。父接shadow逐候选验证后统一测试。

API：

```zig
const Cert = weighted_bound.Certificate(n, max_bits);
const certificate = try Cert.init(&old_frequencies, trusted_lower_bits);
try certificate.publish(&new_frequencies, next_trusted_lower_bits);
const analysis = try certificate.analyze(&current_frequencies);
const lower: ?u64 = try certificate.bitLowerBound(&current_frequencies);
```

n>=2、max_bits>=1为编译时条件，max_bits用u8。无证书由父持?Cert=null表达；每个有效Cert拥有[n]u32频率副本、total_frequency:u32、active_symbols:usize、trusted_lower_bits:u64，不保留输入指针，无heap/global/clock。

Analysis为same_support:bool/current_total:u32/current_active_symbols:usize/negative_delta:u32/bit_lower_bound:?u64。单次分析遍历全部n项，同时统计当前总量、非零个数、完整support比较和Dminus。

证书f初始化/发布要求support>=2且支持数<=2^B、sum<=131072。数值准入Rf<=Cf<=B*Rf；这只是本API选择的强证书数值包络，**不是最优性/可信lower证明**。弱于Rf的有效下界可由调用者先提高为Rf，因为所有非空多符号prefix-code至少1bit/symbol。不能把任意feasible plan的加权成本（上界）、frame bits、tree/header bytes*8当成Cf。

可信前置必须是Cf<=Opt(f)，Opt的域为同symbol support、同bit上限的prefix code。例f=(10,1,1)、B3，真实最优14；feasible长度(2,2,2)成本24，数字12<=24<=36合法，但24不是可信lower。模块没有算法来拒绝这个谎标scalar，父必须从可信规划/独立oracle得到Cf。测试worker正用tiny exhaustive Kraft optimum作Cf，不喂24伪造安全断言。

当前g只要求总量<=131072；support变化（含empty/RLE、即使cardinality相同但symbol不同）返回null，同时完整返回Rg/active/Dminus。相同support自动满足原证书的非零数量/feasibility，方才求bit下界。

公式及证明：

```text
Dminus = Σ max(f_i - g_i, 0)
b = max(Rg, Cf + (Rg - Rf) - (B - 1)*Dminus)
```

任意g可行长度l在相同support上也是f可行；f·l>=Opt(f)>=Cf。正delta至少乘1，负delta至少乘B，故g·l>=Cf+(Rg-Rf)-(B-1)Dminus；所有l>=1又给出Rg。因此b<=Opt(g)，不需要g==f或旧码长保持。模块不将这一步升级为完整payload/selector/pruning证明。

边界/错误：

- InvalidSupport：旧f非零符号不足2，或超过2^B。
- InvalidFrequencyTotal：任一输入vector总量超过131072；计数为u32，负数在类型上不可输入。旧empty因support非法被拒；当前empty返回无bound。
- InvalidCertificateCost：Cf不在Rf..B*Rf（包括maxU64）。
- IntegerOverflow：所有数学累积、乘加减、signed转换保持checked；在正常初始化后的固定bounds内不应出现。
- publish先构造已验证replacement，再一次替换self；任何错误旧频率与scalar不变，借用数组在成功后可改变而不影响已复制证书。
- analyze是const方法；support变化和错误不修改证书。

Rf/Rg/Dminus<=131072；B<=255，Cf<=33423360，中间signed数绝对值远小于i64/32bit边界；usize只存active count和循环索引，不混入wide scalar公式。支持数2^B在B>=usize位宽时不做溢出shift，此时任何可能active数已小于数学上限；native/x86行为一致。

独立测试worker已准备tinyExhaustive/resources/realistic(Codec)，覆盖B3/4、2..4active所有positive1..3频率对、独立Kraft optimum、holes/变化support/合法131072/highu32、publish事务，以及FullWidth weighted-optimum参考。父会从srczstd接线；本代理不写测试文件或自行运行矩阵。

SOURCE_READY SHA256：`52ed8c0e99c7ea827c904ac87957315f690a1774fba20ed05410c7f5f6474313`。
记录UTC：2026-10-25T06:02:26.667332+00:00。
