# Deflate reader dependency screens, 2026-11-12

Both candidates are rejected. They pass the complete 734-test ReleaseSafe
Deflate suite, but fail the declared whole-operation throughput controls.
Neither changes production codecs or the complete modern-reference ranking.

The frozen baseline is `8adfb3ba`, compare SHA
`2527c72112f19ac34d08d8f199f38e76dc4a9883ad25466f2f83ff193da21f14`.
Its production source bytes are identical to the reused 2,062-file registry.
Candidate timing source overlays include the new public generic tests and are
frozen separately; later source changes do not replace either overlay.

Each candidate runs twelve cold public `decodeRawDeflate` rows: reymont, nci
and xml; 64 KiB and 1 MiB; producer levels 6 and 9. Four interleaved process
pairs per row create 96 successful child events, with two warmup and two
measured Vort/reference pairs per child. Iterations are 500 at 64 KiB and 100
at 1 MiB. Ratios use raw Vort batch medians, `baseline_time/candidate_time`,
without reference normalization or best-sample selection.

| Selected cold scope | Length prefix | Refill OR56 |
| --- | ---: | ---: |
| All twelve selected rows | 1.009984x | 0.961166x |
| reymont 64 KiB L6 target | 1.048682x | 1.018335x |
| nci 64 KiB L6 control | 0.976816x | 0.923285x |
| nci 64 KiB L9 control | 0.938845x | 0.910306x |
| xml 64 KiB L6 control | 0.989262x | 0.839242x |
| xml 64 KiB L9 control | 0.981896x | 0.879126x |

The target is a 20% repair of the known reymont weakness, with every control
at least 0.98x. Both fall short and show clear control losses, so neither is
advanced to a full 72-row or dedicated-host acceptance matrix. The retained
full-schema manifests do not mean their complete task lists were executed.
All 192 child reports preserve full output, exact consumption, guards, input
immutability, source/probe/reference identities and host observations.

## Length-prefix candidate

The candidate stores total LL code/extra width, Huffman code width and extra
width in the same prepared length word. Literal pairs, EOB, secondary pointers
and distance entries retain their layouts. Linear, rolling, compact tail and
sink consumers are synchronized; whole match consumption remains atomic at
the original field/validation boundary. Prepared metadata stays within the
three reserved flag bits, and validated-table speculative width sums fit u6.

Machine-code review confirms that distance primary uses one shift from the
original reservoir, independently of length extraction. However, total shrx
and bzhi counts remain 11/4. The generic aligned symbol grows 3,637→3,723 bytes,
local stack reservation 296→312 bytes, and whole-symbol static instructions
898→916 including padding. New field operations and literal-path spills are
visible. This is not merely a reordering or a dynamic instruction reduction.

Reymont gains about 4–6% across the selected sizes/levels, but nci 64 KiB L9
loses about 6.1%. The selected-row geometric mean gains only about 1.0%.

## Refill-count candidate

The second candidate restores the original entry layout and changes only the
shared semantic refill's count update to `count |= 56`. With count below 56,
this equals `count + floor((63-count)/8)*8`. Existing count/input guards,
eight-byte load and byte-index increment remain unchanged.

Machine code has eight OR56 update sites, freeing count from the old
sub/and/add chain while retaining the byte-index sub/shr/add computation.
The generic aligned symbol grows 3,637→3,691 bytes, local stack reservation
296→312 bytes, and static instructions change 898→894 including padding.
Negative-rbp operand references increase 131→133, with new cursor/reservoir
stack accesses. Fewer whole-symbol static instructions do not establish fewer
dynamic spills or a full-operation gain.

The selected-row geometric mean is 0.961166x. The 64 KiB controls lose about
7.7–16.1%, while 1 MiB controls are mostly near parity. The six 64 KiB fixtures
all have complete LL trees, max width above nine, distance width below twelve,
and no RLE258 choice: they all select generic aligned. First-block inspection
does not establish the routes of every block in the 1 MiB fixtures.

## Evidence scope

These are i7-10700K development-host screens, CPU 15, Zig 0.16.0 ReleaseFast,
`x86_64-linux-gnu`, `skylake+pku+sgx`, one codec thread, libdeflate 1.26.
Compiler absence at each child boundary does not prove exclusive CPU use.
Static counts include cold paths/copy/tail/errors and padding, with no dynamic
frequency attribution. The [current profile](reymont-profile-20261112/README.md)
is diagnostic and contributes no samples to these throughput statistics.

[The archive](reader-screens-20261112/README.md) retains original raw reports,
frozen sources/binaries, exact build/regression logs and reproducible runners.
Independent statistics and main-authored derived codegen audits are labeled
as such; no pre-existing nm/objdump output file is claimed.

Further work should reduce the hot loop's live state without rebuilding the
rejected literal-run loop or weakening availability/error checks. Classify
the actual payload paths and token distributions before another code-layout
or register-lifetime experiment; a shorter local chain alone was insufficient.
