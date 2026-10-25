# Q8 普通与诊断 candidate 路径 ELF 审计

审计时间：2026-10-25T16:54:32.409005+08:00，Asia/Shanghai。仅读取指定ELF、nm/objdump、frozen源码和已有构建metadata；没有编译、执行测试或benchmark、修改源码或Git。证据仅写 `/tmp/vort-brotli-q8-profile-20261025`。

## 结论

普通public Q8经 `encodePlannedStreamQualityWithOptionsAlloc` 实际调用 `Recorded(false,.{})` 实例；其Disabled/EmptyScope不保留profile/io字段。实际9个普通Recorded candidate/helper符号没有quality Active.begin/Scope.finish/prefer调用，也没有Clock.now调用。对应候选路径的新quality事件、配置记录、时钟和recorder状态已消除；普通allocator、codec状态、候选wire仍保留。

诊断API经 `Recorded(true)` 的独立实例执行同一candidate body。其lazy/optimal、preferred context、split planning、wire与selection层级真实调用Active/Scope；时钟、parent/child时间、固定event array、wire config和selection记录真实保留。该诊断ELF也带有普通false实例，不能把两条路径按相似符号名混合。

固定的是Profile中的512个Event和32个Frame；Active.begin/finish/prefer不分配event节点。工具自身在passes外一次分配148696 B的Profile对象，codec/budget也有各自分配，因此不声称诊断整体无heap allocation。没有据汇编推导速度、ISA、heap/RSS或进程总栈。

## 来源与复查证据

| 来源 | 实读 SHA-256 |
|---|---|
| public `d54ab236499589e8c9225c90450b9b10/vort-br-planned-encode-bench` | `a6f1f0bb5d4d403605b9989e6006f64b3f44d86fedb87d9215140b9cf216b725` |
| diagnostic `f67ed575467f368cf1ce021440d4e813/vort-br-quality-stage-profile` | `d11b00006fd2229e0150d0f17fdbdaf705d1a951f30722fb16d3e182253a2c4e` |
| `src/br.zig` | `0be45f1153d120230bcadcdcc9958df54d32d06d92537f90fe3057ba9d722082` |
| `src/br/encoder/quality_profile.zig` | `aa3e79ec0c3d304fe84bd15e6f88591762e02e1e70e3bfbf4512444902078451` |
| QA contracts | `4684b0d75d0a01395597cf35379384179c7c7e15f687f07bc5441b04a967f8ca` |

ELF SHA均与父代理给定的public/profile-executable.json一致。工具源码首次读取SHA为 `a3f6e80df09cf980b8b44e44d021d4d2208032e57c77c03db6eb62338e9b9d33`；最终复核时父代理更新了工具，当前SHA为 `a94eaf4d9ebddcf5d692a8f5c9d002c1980b79f2b847522be84a9b5c02793b9f`。三个冻结核心/QA文件仍匹配；本文工具行为同时以指定ELF实际指令为证，不声称工具树始终未改。已有public-bench-build与tool-build-fixed记录exit0、5/5 steps succeeded，关键source before/after稳定；这些records包含此前smoke执行，本审计没有再次执行或用其timing作结论。旧public参考SHA为 `541df153c9ba535d998ab3e53d6c4401da834b438a2f84b312cea1909aeced5b`，仅记录identity和caller，不声称机器代码等价或性能差异。

- [结构化 JSON](/tmp/vort-brotli-q8-profile-20261025/profile-elf.json)
- [public nm](/tmp/vort-brotli-q8-profile-20261025/focusedasm/public-symbols.nm)、[diagnostic nm](/tmp/vort-brotli-q8-profile-20261025/focusedasm/diagnostic-symbols.nm)
- [public quality caller](/tmp/vort-brotli-q8-profile-20261025/focusedasm/public-quality-entry-call-sites.asm)、[diagnostic quality callers](/tmp/vort-brotli-q8-profile-20261025/focusedasm/diagnostic-quality-entry-call-sites.asm)、[普通9函数call审计](/tmp/vort-brotli-q8-profile-20261025/focusedasm/public-recorded-call-audit.json)
- [public quality exact asm](/tmp/vort-brotli-q8-profile-20261025/focusedasm/public-encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589.asm)、[diagnostic true exact asm](/tmp/vort-brotli-q8-profile-20261025/focusedasm/diagnostic-encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584.asm)
- [Active.begin](/tmp/vort-brotli-q8-profile-20261025/focusedasm/diagnostic-quality_profile.Active.begin.asm)、[Scope.finish](/tmp/vort-brotli-q8-profile-20261025/focusedasm/diagnostic-quality_profile.Scope.finish.asm)、[Active.prefer](/tmp/vort-brotli-q8-profile-20261025/focusedasm/diagnostic-quality_profile.Active.prefer.asm)
- [wire配置写入](/tmp/vort-brotli-q8-profile-20261025/focusedasm/diagnostic-wire-config.asm)、[诊断Lease路由](/tmp/vort-brotli-q8-profile-20261025/focusedasm/diagnostic-profile-api-lease-route.asm)、[工具Profile分配](/tmp/vort-brotli-q8-profile-20261025/focusedasm/diagnostic-main-profile-allocation-extract.asm)

## 普通false与诊断true的路由

[public API](/home/passchaos/project-z/vort-brotli-q8-profile/src/br.zig:4575) 在本次q8/generic、默认window16、没有shared dictionary/额外request的场景走完整quality candidate。其 [普通wrapper](/home/passchaos/project-z/vort-brotli-q8-profile/src/br.zig:5127) 固定trace_enabled=false、空recorder。Public实际caller `0x1283a72`调用normal root `0x12898f0`。

[diagnostic API](/home/passchaos/project-z/vort-brotli-q8-profile/src/br.zig:5065) 固定q8/generic、输入≤65536，创建Active(io,caller Profile)，begin outer，建立Lease并调用Recorded(true)。API被内联到`quality_stage_profile.profilePass`，实际 `0x11473bc`调用true root `0x11b3de0`。工具normalPass的`0x1146f68`调用普通public API，后者`0x12999ab`调用同一ELF内false root `0x129a820`。

| helper | public false实例 | diagnostic true实例 |
|---|---|---|
| quality root | anon253589，0x12898f0 | anon28584，0x11b3de0 |
| lazy candidate | anon43465，0x11ea3d0 | anon29228，0x1268fe0 |
| optimal candidate | anon253613，0x128b170 | anon29486，0x123a8a0 |
| preferred context | anon43479，0x120fcd0 | anon231663，0x1273b10 |
| split planning | anon43527，0x11eb020 | anon231669，0x126a190 |
| split wire | anon43678，0x11f05f0 | anon231681，0x1272b80 |
| wire encode | anon35307，0x1174a00 | anon29509，0x122eb30 |

源码将trace_enabled/trace一路传给同名Recorded bodies及其helpers；区别为编译期recorder类型，不是另一套Q8候选算法。Generic Recorded root还含其他quality分支；caller与API设置建立这里的q8场景，不宣称每个机器分支都在Q8执行。

## 普通recorder的消除范围

[Recorder(false)](/home/passchaos/project-z/vort-brotli-q8-profile/src/br/encoder/quality_profile.zig:166) 返回空Disabled；begin返回EmptyScope，finish/wire/failure/config/returned/forgetWire均不保留事件，prefer仅比较candidate.len<incumbent.len。没有profile pointer、io字段或新增mutable recorder global。

实际public9个Recorded helper覆盖quality、lazy、optimal、preferred、split、split-wire、distance search、wire及stored selection；所有call instructions中quality_profile引用为0、Clock.now/Io-vtable now call为0。其indirect calls仍是allocator alloc/free等合法操作；没有把普通memory offset中出现的0x2c0误计为时钟call。Disabled config无Config.from事件写入，普通wire helper `0x1174adb`继续调用共享encodeCommandPlanWithOptionsWrite、`0x1174af7`返回真实owned wire。

原codec的可选统计timer独立于quality recorder。Lazy候选在 [preferred调用](/home/passchaos/project-z/vort-brotli-q8-profile/src/br.zig:9183) 传original io=null；writer中原timer受if(io)门控。诊断true也没有把recorder的io改作旧stats io。Public ELF仍含benchmark outer clocks、Io.Threaded.now、其他profile API或可配置budget，不能因此推断普通Q8 candidate执行quality时钟，亦不能宣称整个ELF/libc不含clock。

## 诊断层级、时间和config实际保留

Active.begin为 `0x1277590`、609 B；append内联在该函数。实际event_total更新profile+0x23028，event_count更新profile+0x23020，以0x118（280 B）stride写caller events。容量检查为min(512,event_limit)，截断标志保留。函数从depth与top frame读取parent id，按16 B stride写固定Frame数组，depth容量32。

`0x12777d6`经Io vtable+0x2c0调用awake clock，selector1；它是begin唯一call，没有allocator/node allocation调用。Scope.finish为`0x1277170`、1044 B，唯一call是`0x127719e`的同类clock；实际pop depth、读取child_ns、计算exclusive，并在 `0x1277227/0x127722c`写inclusive/exclusive。Parent child time的checked累加和timing_complete/overflow标志也保留。

真实候选stage调用包括root other `0x11b3e9d`，lazy_parse `0x11b4382`，lazy_commands `0x11b45e2`，preferred_context `0x1273c11`，split_planning `0x126a287`（stage6），wire `0x122eb8f`（stage7），optimal scope `0x123a93e`。True helpers还调用finish处理正常和错误退出，不能用这些静态site数量作为dynamic次数。

Active.prefer（`0x123dfe0`，846 B）保持strict byte-length选择并内联append selection event，关联candidate/incumbent wire id；整个方法无call指令。Same-body selection/source关系来自 [Active.prefer](/home/passchaos/project-z/vort-brotli-q8-profile/src/br/encoder/quality_profile.zig:243)，其追踪不会替换长度判定。

True wire在begin后执行 [Scope.config→Config.from](/home/passchaos/project-z/vort-brotli-q8-profile/src/br/encoder/quality_profile.zig:290)。`0x122f0f8–0x122f19a`保留config字段stores，`0x122f176/0x122f17b`写完整64-byte context_map；包括window/large_window、recent distances、npostfix/ndirect、context mode/tree/cutoff/map、split flags/type counts及same-last-distance policy。随后`0x122f2ba`调用同一个普通writer，`0x122f2dd`取得owned wire；wire/error和finish处理继续保留。

## Profile存储、预算Lease和输出消费

[Profile](/home/passchaos/project-z/vort-brotli-q8-profile/src/br/encoder/quality_profile.zig:113)有内嵌512 Event、32 Frame及固定wire身份数组。Recorder方法写caller Profile，没有逐event分配。工具 [main](/home/passchaos/project-z/vort-brotli-q8-profile/tools/br/quality_stage_profile.zig:45)却显式create一次Profile：ELF `0x114ac9e` allocator调用参数148696 B/alignment8，位于normal/profile passes之外；已有smoke metadata的profile_state_bytes同样为148696。该数字是对象requested size/@sizeOf，不是RSS或整个diagnostic内存。

诊断API `0x1147313`调用Lease.init，`0x1147555`deinit。Lease [源码门控](/home/passchaos/project-z/vort-brotli-q8-profile/src/br/encoder/total_budget.zig:45)保留：继承已tracked allocator；否则limit/profile都null时直接返回原allocator；显式cap或memory_profile才创建计数State并记录budget。ELF Lease.init条件路径的`0x1277095`仍有80 B、alignment8的state allocation。ProfilePass保持budget error translation、release-to-caller及cleanup，不以fallback掩盖request failure。工具每轮Profile默认request为空，不代表带request的诊断API没有budget开销。

工具对两个pass的输出均有完整bytes消费者：normal `0x1146fbd`调用mem.eqlBytes，在outer stop-clock `0x1146f92`之后；profile `0x1147853`调用mem.eqlBytes，在stop-clock `0x1147823`之后。候选输出和诊断配置实际写入没有被unused result删除。本审计只确认这些消费者静态存在，没有把它们报告为本轮运行的wire equality或兼容性验证。

## 验证与下一建议

已匹配ELF与source SHA、核exact-symbol/caller、辨认同ELF false/true实例、核普通recorder消除与诊断event/clock/config保存、固定node存储与独立tool/Lease allocation，并验证输出消费者。没有速度、ISA或heap/RSS结论，也没有替代父代理的完整family/check。

下一建议：父代理完成live family/check后，将该静态证据与normal/profile wire和request-budget contracts结果合并；任何profile开销评估应由quiet条件下的独立benchmark支持，并区分事件记录、工具Profile对象及显式budget请求。
