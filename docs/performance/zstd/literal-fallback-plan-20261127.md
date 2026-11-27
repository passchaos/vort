# Exact Zstd fallback planning, 2026-11-27

Status: rejected performance pilot. Focused Native/actual WASI contracts and
whole-library gates pass, but one fixed pilot row misses the 0.98 throughput
floor. The frozen main baseline is `d5d9d8aa`. The prototype is not adopted;
the shared Deflate stream-resource increment is validated separately.

The final repeated ReleaseSafe `test/check/check-wasm` gate returned actual
exit0,419/419 successful steps and6108/6110 passed tests (two skipped), with
unchanged source. Its full receipt/logs are retained under
`/tmp/vort-encoder-contract-integration.44n9_fus/whole-library-after-clone-types`.
The initial full gate's old Deflate clone-type assertion failed and is preserved
separately; only that test expectation was corrected. Recorded complete2267-file
source SHA is `beb79f99ed3809717dee3d3a3438247f835c45f012bfbb3aeab6cab6e6b0955f`.
New source-bound probe builds and untimed complete-wire preflight subsequently
passed. The old benchmark epoch remains invalidated. Only the fresh pilot
has been timed; formal, controls and reference campaigns remain unrun.

The [portable functional evidence package](../codec-contracts-20261127/README.md)
preserves the original failed and passed whole-library gates, the clone-type
correction and the complete final 2,267-file source overlay. Offline verification
passes after relocation, rejects corrupted/missing gate data, and passed a
separate Root replay from `/tmp`. It launches no codec or build and does not
verify the pending throughput or resource matrices.

The controlled public L3 encoder previously materialized a sequence candidate
and a complete Huffman/raw fallback before choosing either. The new fallback
module prepares fixed-size metadata without an allocator, compares exact block
lengths with the existing sequence candidate, and emits the fallback only when
it wins. Sequence candidates retain their current materialization path. This
slice does not constitute whole-codec winner-only emission.

The plan stores the freshly finalized Huffman model, tree kind, selected FSE
table/normalized counts, header geometry and each stream's exact byte size.
Emission uses those choices rather than rebuilding trees or recomputing sizes.
It includes each reverse-stream end marker and independent byte rounding,
the four-stream jump table, the zero sequence count and the block header.

All original eligibility and strict ties remain: repeated patterns retain
their old rejection, Huffman must beat raw payload length, sequence wins equal
fallback block length, direct wins equal FSE tree length, and FSE log5 wins
equal log6. Raw keeps previous entropy state; successful Huffman commits the
fresh full model even when its tree is reused; sequence preserves its original
table/repeated-offset commit. Out length, state and emitted counters retain
their existing failure rollback. Remaining allocations use the scoped allocator.

The grouped emitter has a bounded accumulator: at most 7 residual bits plus
four 11-bit symbols on 64-bit targets or two on 32-bit targets. Original tree,
FSE, header and checked-stream routines remain differential oracles. Their
unchanged bodies were independently reviewed; the new plan is compared against
complete legacy blocks and frames, not only against its own length formula.

Focused Native and actual WASI each pass32/32, with actual build/run exit0.
Coverage includes sequence/Huffman/raw winners, complete next state, raw and
standard dictionaries, multiple blocks, fresh frequencies with treeless reuse,
direct/FSE and log6 trees, 1023/1024 and non-divisible stream geometry, all
header lengths, 11-bit/group/bit remainders, quotas, remaining backing failures,
prefix/state/emitted rollback and recovery. A public Huffman fixture measures
peak requested heap17,345 B Native and9,497 B WASI; these are fixture results,
not a complete-corpus memory comparison. The WASI16 MiB stack is harness scope.

Original failed compilation attempts and the final source/command/exit records
are retained in `/tmp/vort-zstd-literal-fallback.jiyajo7r`.
Production module SHA256 is
`f87ae0ff35d8cb2a626645cb10479075a27a34b670025d927b351a97949acc2f`.
The integrated execution gates are:

```sh
zig build -j2 test-zstd-huffman-fallback -Doptimize=ReleaseSafe
zig build -j2 test-zstd-huffman-fallback-wasm -Doptimize=ReleaseSafe
```

Performance evidence must use ordinary public L3 owning encode/mix/free, with
all candidate settings and output bytes unchanged. The effective policy is
greedy/search-budget24/rep-beamfalse after the speed-first resolver, not the
older benchmark's pre-policy `resolved_primary` metadata. Natural winner
controls require untimed instrumented/plain wire equality and must not force a
strategy or reduce search work to manufacture a fallback. Current-main A/B
and pinned libzstd1.6.0 comparisons remain distinct measured scopes.

## Actual pilot result

The fresh pilot completed all 12 fixed Silesia 64 KiB rows x 2 paired rounds,
24 pairs / 48 children, with actual exit0. It uses public allocating L3
encode/mix/free, unchanged greedy/budget24/rep-beamfalse/fast-compressed policy,
ReleaseFast, `skylake+pku+sgx`, Intel Core i7-10700K, CPU2 affinity and one
codec thread. Both builds and initial complete wires are bound to the frozen
source manifests; every baseline/candidate initial wire is byte-identical and
passes the external single-frame decoder proof.

Throughput GM is **1.04778913x**, but ooffice is **0.97548905x**, below the
predeclared 0.98 row floor. Its two original paired values are 1.02262324x
and 0.93052733x. Nci is 1.24441890x, from 1.06213001x and 1.45799327x.
All values remain in the result; no outlier filtering, row replacement or
retry is permitted. This two-round pilot has no CI. It fails the fixed gate,
so a formal release is not authorized and no throughput or memory acceptance
is claimed from the 4.78% aggregate gain.

The [portable pilot evidence](literal-fallback-pilot-20261127/README.md)
retains the original samples and independent data-only point replay. The next
source must repair the weak row under unchanged settings and pass a fresh
predeclared campaign before adoption.
