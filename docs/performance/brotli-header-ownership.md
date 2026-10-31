# Decoder short matches and Brotli header ownership

This increment follows the user priority for Deflate, Zstd and Brotli decompression.
Encoder experiments remain frozen. The objective of industry-leading functionality
and performance remains active.

## Adopted changes

Zstd uses exactly one existing 16-byte move for dense-path matches of length
3 through 16, after the original source distance, initialized prefix, literal
and destination headroom proofs. Longer matches keep the previous dispatcher.
The diagnostic counters observe 16,921,483 eligible short matches in 58 of 72
reference frames. The old dispatch widths total 1,027,439,568 bytes versus
270,743,728 bytes with one move; these are architectural copy-width counts,
not measured memory bandwidth. Independent scalar oracles cover 5,376 isolated
combinations and 7,168 chained matches, including alignment and guards.

Brotli incremental parsing writes the already-owned inactive header through
Into hooks, returning only consumed bits. It preserves the old return-value
hook for generic Codec users, including validation before publishing a
returned header. Per-bit truncation and retry tests cover final/non-final
headers, standard window24, large window30, 256 command trees and decoded
lengths above 32 bits. Invalid generic hooks preserve the prior inactive
header, zero progress and the fatal CorruptFrame result.

Under explicit 8,388,608-byte soft and hard stack limits, a heap-owned public
Brotli decoder processing compressed hello failed in the baseline and succeeds
after Into parsing. Debug stepImpl frame reservation falls from 5,193,256
to 9,128 bytes; parser reservations also fall sharply. These are individual
function frame reservations and are not added together or claimed as peak stack.
Oversized test fixtures in four modules were also split into noinline helpers
without changing errors, output, progress, finish, diagnostic or resource
assertions. Original failures are retained as evidence.

## Rejected alternative

A separate typed noalias Reader prototype retains 76 ordinary and 28 fallback
static memory operands and has no stable throughput benefit in its independent
432-process screen. It is not adopted. Its negative evidence is retained.

## Final-source measurement

The complete final-source Zstd ReleaseFast suite passes 1,251/1,251 tests.
An earlier native/Wasm compilation gate passes 212/212 steps. Focused actual
WASI Debug and ReleaseFast execute 14 meaningful named tests across the four
suites (112 import/test entry terminals), keeping the 8 MiB stack. They include
the copy16 scalar/chain oracle, Mozilla 64 KiB contents and guards, Brotli
caller-owned/owned one-byte output, exact owned-history budget and the original
per-bit header oracle. This is focused WASI execution, not a claim that all
WASI tests ran.

The final-source complete Brotli ReleaseFast gate exits zero under explicit
8 MiB soft/hard stack limits: 1,499 passed, one 32-bit-specific skip, zero
failed. The complete Brotli Debug gate also exits zero under the same explicit
8 MiB limits: 1,499 passed, one platform skip, zero failed. The post-freeze
native/Wasm compilation gate passes 212/212 steps and the CLI help smoke check
exits zero with the final source binding.

The final ordinary timing epochs complete with actual exit zero: 1,296
caller-buffer processes (216 frames, three implementations, two alternating
sweeps) and 288 owned Brotli streaming processes (72 frames, two implementations,
two alternating sweeps). Both run sequentially on logical CPU2, with no other
compiler, probe, test or archive tasks active. Every child has explicit 8 MiB
soft/hard stack limits. Input loading, buffers, startup warmup, full output
checks, SHA, guards and freeing are outside timing. Streaming includes actual
reset, every step and finish, with 4,096-byte input/output slices and retained
owned history from the unmeasured warmup.

The per-case medians are reduced as geometric means across all twelve actual
Silesia sources. Lower time ratios are faster. The baseline already contains
the previously adopted Deflate short-copy/index correction and Zstd grouped
transition change; this epoch directly measures the additional copy16/header
increment instead of multiplying earlier ratios. Independent audit reparses
all 1,584 raw stdout records, verifies progress/content/guards, process intervals,
libraries, all 1,631 source hashes in both roots and five binary hashes, then
recomputes every median and geometric mean. The audit exits zero and agrees
with the reports.

| Codec / producer | 64 KiB final / baseline | 1 MiB | Full file | Full final / reference |
| --- | ---: | ---: | ---: | ---: |
| Deflate 6 | 0.997314 | 0.998425 | 1.001213 | 1.706393 |
| Deflate 9 | 1.000073 | 1.001938 | 0.995493 | 1.724357 |
| Zstd 3 | 0.923736 | 0.918139 | 0.918212 | 1.531615 |
| Zstd 19 | 0.894473 | 0.908783 | 0.926361 | 1.557396 |
| Brotli 6 | 0.998874 | 0.999177 | 1.013726 | 1.517301 |
| Brotli 11 | 1.000662 | 0.992876 | 0.992838 | 1.545121 |

Zstd complete-file time falls 7.4–8.2%. Deflate and Brotli one-shot ratios
remain near the current baseline; Brotli q6 full-file time is 1.37% higher in
this epoch, so no one-shot Brotli performance benefit is claimed. Ordinary
Brotli one-shot does not use the modified progressive header hook.

| Brotli producer / owned streaming | 64 KiB final / baseline | 1 MiB | Full file |
| --- | ---: | ---: | ---: |
| 6 | 0.919334 | 0.934912 | 0.958167 |
| 11 | 0.914753 | 0.946458 | 0.960058 |

Owned streaming time falls 8.1–8.5% at 64 KiB, 5.4–6.5% at 1 MiB and
4.0–4.2% for actual full files. Both sweeps independently show faster full-file
geometric means for Zstd (levels3: 0.919800/0.916429; level19:
0.928513/0.923986) and Brotli streaming (q6: 0.960776/0.955598;
q11: 0.965544/0.954702). These two-sweep point estimates do not show
that every input is faster.

The largest Zstd case ratio is XML 64 KiB level3 at 1.026884; both sweeps
are slower (1.014647 and 1.039054). The largest Brotli one-shot ratio is
SAO full q6 at 1.080009, with divergent sweeps 1.138273/0.999847.
The largest streaming ratio is Webster 1 MiB q11 at 1.057435, also mixed
across sweeps 1.140486/0.975007. Brotli one-shot q6 full-file group ratios
are 1.021037/1.004337, so this API gets no performance-win claim.

 The streaming result measures internal baseline/final
improvement; a matching reference streaming lifecycle was not measured.
The one-shot reference gaps remain about 1.71–1.72x libdeflate, 1.53–1.56x
libzstd and 1.52–1.55x libbrotli time on actual full files. This workload, CPU
and API scope does not establish industry-best decoder performance.

The environment is Intel i7-10700K, Zig0.16.0 ReleaseFast,
x86_64-linux-gnu target with skylake+pku+sgx, one thread pinned to CPU2
and the existing powersave governor. Reference direct APIs are libdeflate1.26,
libzstd1.6.0 and libbrotli1.2.0 on identical externally compressed frames.
This measures warmed decoder invocations; cold start and a full memory/CPU
ranking remain outside the evidence.

## References and next work

Local reference review includes libdeflate 1.26 lib/decompress_template.h
fast literals and table-preload/refill scheduling; Brotli
c/dec/decode.c ProcessCommandsInternal,
its safe/ordinary split and bounded literal spans; Zstd
lib/decompress/zstd_decompress_block.c sequence execution, copy widths and
long-distance sequence lookahead/prefetch. Vort must translate these mechanisms
into explicit Zig state and preserve exact malformed-input and progress behavior.
Next priorities are Brotli context/table dependencies and proven literal spans,
Zstd sequence scheduling/FSE lifecycle, and Deflate semantic loop decoding.
Concrete remaining API and state gaps are Brotli entropy-header retry from
the prefix instead of a persistent Huffman substate, Zstd standard dictionary
entropy reconstruction on every frame instead of a DDict-style prepared decode
handle, and Deflate's lack of an optional block-boundary pause/checkpoint API.
Standard dictionaries and streaming already work; these are finer-grained
reuse and control gaps. Next implementation should start with resumable Brotli
code-length parsing and a per-bit oracle plus cumulative work counters.

Dictionary/reusable streaming comparison, peak memory, wider CPUs and portable
paths still require broader measurements before an industry-best claim.

## Reproducible evidence

The [evidence package](data/brotli-header-ownership-20261101/README.md)
preserves the earlier independent screens and a separate final-source epoch.
Final raw stdout, two-sweep reproducibility analysis, complete source/binary
bindings, actual terminal records, failed pre-fix gates, isolated fixture
controls and WASI artifacts are retained. It references the shared 216-frame
corpus archive without duplicating the 448 MB input/reference package.

The working tree contains unrelated Bzip2 changes. In accordance with the
repository workflow, this increment is left uncommitted; no pull, rebase or
push is performed over those changes.
