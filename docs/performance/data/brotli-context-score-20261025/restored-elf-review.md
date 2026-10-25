# Restored public context cache 路由审计

审计时间：2026-10-25T18:06:05.896981+08:00，Asia/Shanghai。只读父代理指定的restored public ELF及当前源码，未编译、计时、运行测试、修改源码或Git。本报告限定恢复后的关键路由，不重复前一份全部ELF分析。

已核ELF SHA `16ffb6c50977990036c204777423459eeaa7fe515d4f9410360c833f86e0a79d`，路径为context-cache树`.zig-cache/o/ee59b567d9fa359fa365d21c6dd4ba7f/vort-br-planned-encode-bench`。当前core `literal_context_split`为`72cb7349697453c172686b8acba87484f99a4b4a9da775d93fc77383d21fa79b`，context profile为`fc19a207d99db5ed5118ce5153968b8cf7c246d4dc8af43ac46c3075d8d7ae83`，memo为`a14ea8a7d6e5cf047e0c3d46c1dbf17f4df7ec64b143ef1e751c4f8b666138b7`。完整restored-check源码绑定及family/check结束状态仍由父代理记录；这里没有“全面passed”结论。

恢复后的ordinary `chooseProposals`固定Core(false)，baseline直接调用原scorer；suffix左右两树也直接评分。128-entry tree memo仅位于每mode的cluster阶段，ScoredMapCache同样mode-local。四mode顺序调用各自mode函数，未跨mode传入或共享外层memo，也没有四份同时存在的memo。

实际关键指令如下：

- preferred `0x12105a1`调用ordinarychooser `0x120ee50`。
- baseline `0x120f472`调用`treeBitCostProfiled__anon_46128`（`0x120c670`）；该名字带Profiled，但实际false实例无Timer ABI或clock。
- suffix `0x120cf0e`和`0x120cf42`同样直接调用scorer，只传result、frequencies和parent active-support，未传memo。
- chooser对mode0…3的实际call为`0x120f502`、`0x120f6a1`、`0x120f8f0`、`0x120faf2`；不再有cross-mode memo参数。
- mode局部memo基址为callee `rbp-0x4ddf8`；suffix处理后`0x120d1cd`以长度`0x20830`（133168 B）memset初始化它。
- cluster lookup `0x120e505`取128-slot，stride0x410，检查hash和完整histogram；miss在`0x120e890`直接评分，成功后发布hash、1024 B histogram、cost与occupied bit。

源码证据在 [baseline/core](/home/passchaos/project-z/vort-brotli-context-cache/src/br/encoder/literal_context_split.zig:188)、[suffix及mode-local memo](/home/passchaos/project-z/vort-brotli-context-cache/src/br/encoder/literal_context_split.zig:443)和 [cluster cached scorer](/home/passchaos/project-z/vort-brotli-context-cache/src/br/encoder/literal_context_split.zig:866)。Cache源码已移除origins数组和origin/setOrigin方法；普通路径不存在origin查询或发布。Ordinary chooser、mode、directscorer与preferred exact asm均没有literal/quality profile调用或Io clockcall；不据此宣称整个ELF或libc没有时钟。

父代理已有native布局probe记录Cache@sizeOf为133168 B，其a14 cache-source SHA与本次一致；本审计只读取 [布局记录](/tmp/vort-brotli-context-cache-20261025/restored-cache-layout.json)，未重新编译/运行probe。这个数字是cache类型大小，不是完整stack、heap或RSS。实际局部sub rsp分别为chooser1208 B、mode318936 B、directscorer1720 B，也只记录这些明确指令，未作为完整调用链峰值。Mode的整个frame在函数entry就预留，memo逻辑后suffix生命周期和物理stackreservation需分开理解。

[结构化报告](/tmp/vort-brotli-context-cache-20261025/restored-elf-review.json)及少量取证：

- [baseline与四mode路由](/tmp/vort-brotli-context-cache-20261025/restored-elf-evidence/baseline-direct-and-four-mode-route.asm)
- [suffix直接评分与局部memo初始化](/tmp/vort-brotli-context-cache-20261025/restored-elf-evidence/suffix-direct-and-mode-memo-init.asm)
- [cluster key/miss/publication](/tmp/vort-brotli-context-cache-20261025/restored-elf-evidence/cluster-memo-key-and-miss.asm)
- [ordinary caller](/tmp/vort-brotli-context-cache-20261025/restored-elf-evidence/preferred-ordinary-chooser-call.asm)

先前elf-review.md描述SHA734570…的跨mode共享版本；这份恢复版本为SHA16ff…，不能把两者路由结论混用。当前已验证指定identity、关键源码、direct baseline/suffix、mode-local cluster memo及普通无origin/Timer操作，未作性能或完整验证完成声明。

下一建议：父代理记录restored-check最终全源码绑定，完成family/check与独立smoke，再将这份有限路由审计与功能/资源证据合并。
