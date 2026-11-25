# Original instrumented native code audit

Read-only `nm`, `objdump -dl` and DWARF inspection of the frozen ReleaseFast
complete public benchmark binaries:

- baseline SHA-256 `f15d100c21958bb91b7babb077df46cfee1772f596a7630267b10777841b7585`;
- variant SHA-256 `273f6dbb4591d9d976483750b0fcabbec4919d0fdf8a06e4541b694221cc7c69`.

| Path | Symbol bytes before/after | Entry stack reservation before/after |
| --- | ---: | ---: |
| narrow `planAllocWithStartingDistances`, Cache(32) | 10,377 / 11,326 | 0x2628 / 0x2868 (+576 B) |
| beam 4 `planAllocInternal__anon_424948` / `__anon_424985`, Cache(64) | 8,278 / 8,965 | 0x26e8 / 0x2b98 (+1,200 B) |
| beam 8 inline in `selectWideCommandStateCandidate`, Cache(128) | 9,449 / 10,219 | 0x2b68 / 0x33a8 (+2,112 B) |
| `selectQualityCommandStateCandidate` | 2,379 / 2,379 | 0x24b8 / 0x24b8 |

DWARF inline types identify the cache capacities and beams. No independent
profiled-plan symbol is emitted, so its stack reservation cannot be inferred.
These values exclude register pushes, temporary call arguments and nested
callees; the full encoding stack peak has not been measured.

`.text` changes from 2,047,017 to 2,048,617 bytes (+1,600), and the custom
`.vort_br_command_state` section from 14,644 to 15,414 (+770). The `size`
utility's aggregate text category, which also includes other read-only sections,
changes from 3,496,896 to 3,499,266; those scopes must not be interchanged.

Cache statistics survive in hot generated code although the ordinary parser
never reads `recent_evidence.stats`:

| Path | queries | same-position hit | same/span hit | tail extension |
| --- | --- | --- | --- | --- |
| narrow | 0x12a30a8 `inc %rbx` | 0x12a3138 `incq -0x608(%rbp)` | 0x12a33ea indexed `incq` | 0x12a3409 `incq -0x230(%rbp)` |
| beam 4 | 0x12a56d1 | 0x12a574d | 0x12a59e2 | 0x12a59fe |
| inline beam 8 | 0x1340e11 `inc %r15` | 0x1340e94 | 0x13410e0 | 0x1341102 |

The source mapping is `recent_match_evidence.zig` lines 38/56/62/68 in the
archived original prototype. Scalar-probe and eviction increments also remain.
This proves an instrumentation cost exists; it does not quantify its fraction
of complete encoder time or prove that removing it will produce a win.

## Counter-free follow-up

Runtime executable SHA-256:
`487e830d407b0fe4408fe1a80192337b852578dd6ec93a20ac10018c01dd329d`.
DWARF identifies `CacheWithStats(32/64/128,false)` in the same three paths.
The original evidence-counter writes are absent; the remaining evidence `inc`
is the tail byte-loop index. Original logical parser accounting remains.

| Path | Original / runtime symbol bytes | Runtime own stack reservation |
| --- | ---: | ---: |
| narrow `planAllocWithStartingDistances` | 11,326 / 10,917 | 0x2828 = 10,280 B |
| beam 4 `planAllocInternal__anon_424984` | 8,965 / 8,483 | 0x2b58 = 11,096 B |
| inline beam 8 in wide caller | 10,219 / 9,854 | 0x3368 = 13,160 B |
| narrow caller | 2,379 / 2,379 | 0x24b8 = 9,400 B |

Each own frame reserves 64 bytes less than the instrumented variant. Relative
to baseline, the increases are 512/1,136/2,048 bytes. Whole-operation stack
peak remains unmeasured.

Runtime `.text` is 2,047,785 bytes (original -832, baseline +768), and
`.vort_br_command_state` is 15,049 (original -365, baseline +405).
The aggregate text category is 3,498,069 bytes.

The native function entry addresses are 0x12a1500 (narrow), 0x12a3fb0
(beam 4) and 0x133f07b (wide caller). Their `sub %rsp` instructions are at
0x12a150d/0x12a3fbd/0x133f088. Preserved logical transitions include narrow
0x12a2939/0x12a3187, beam-4 0x12a51d9/0x12a56c4, and wide
0x134083e/0x1340c79. This audit verifies the intended instrumentation removal,
not complete-operation speed or total stack parity.
