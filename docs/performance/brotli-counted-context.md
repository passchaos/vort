# Exact counted Brotli context alternatives

Preferred ordinary q8 context groups retain the primary full wire and evaluate
subsequent literal-context candidates with exact counts. The real header
serializer writes to a separate checked counting writer; weighted Huffman
frequencies and cached insert/copy/distance extras count the complete payload.
Command/distance alphabets of at most four symbols use actual `simpleCode`
widths; literals use their selected lengths. Final byte rounding is checked.

Only a strictly better preparation replaces the incumbent. The final selected
alternative constructs literal encoders and emits once into an exactly sized
output allocation. Primary-only groups retain their original output path.
Candidate order, deduplication, proposal-zero cutoff, strict ties, 80% early
return and explicit baseline tie preference remain unchanged.

The optimization uses the existing input-at-least-8-KiB, recent-distance,
clustered-context gate. It requires the ordinary 79-capacity writer, complete
frames, empty metadata and no HQ commands/models, splits or final-state output.
Other cases retain the existing encoder. Preparation borrows immutable input
and command identities within one group. Its literal key and the common key
cover all supported wire/context parameters. Fixed literal storage is bounded
by 64 trees; it adds no preparation heap allocation. The physical BitWriter
has no counting-mode branch.

## Ordinary-call evidence

Baseline is `289110eb515edf7af24a5a72d88c80bfc164b9d8`. Three process sweeps
reverse version order on the middle sweep. Twelve Silesia files contribute
4/16/64 KiB prefixes, with five interleaved Vort/reference rounds of three
ordinary calls per report. Per-case medians of fifteen samples are followed by
geometric means. Both versions use Zig 0.16.0 ReleaseFast native
`skylake+pku+sgx`, one thread on CPU 2 of an Intel i7-10700K. Formal sampling
ran after compilation. Timed work includes allocation/free; Vort has an
untimed warmup before each primary round, the reference has no explicit warmup.

| Prefixes | Candidate/baseline encoding time |
| --- | ---: |
| 4 KiB, 12 cases | 0.990845 |
| 16 KiB, 12 cases | 0.988771 |
| 64 KiB, 12 cases | 0.975216 |
| All 36 cases | **0.984920** |

The combined point is **1.51% less time**. All input/wire hashes, lengths and
settings agree across versions and sweeps. Five case points regress by at
most 0.94%; complete rows retain these results. The 4 KiB path does not enable
counted alternatives, so its timing difference is not an isolated causal
saving from counting. The exploratory one-sweep ratio 0.974397 is kept apart
from the final result. These points do not prove statistical significance.

The clean local Brotli 1.2.0 reference is commit 558fc647, built with GCC
`-O3 -DNDEBUG -march=native`. Quality, generic mode and actual lgwin16 match.
Current candidate/reference time ratio is **37.1483** and size ratio
**0.995560**. Requested canonical library hashes/API versions are recorded;
actual loaded objects and transitive dependencies remain unverified by the
tool. Results do not establish industry-best performance.

## Resource and correctness evidence

Independent forced-moving allocator ledgers measure actual encoder-owned
requested heap. Each input runs ordinary/profile at no cap, its measured peak,
and peak-minus-one. Ledgers agree between ordinary/profile and between no cap
and exact peak; peak-minus-one rejects with `WorkingMemoryLimitExceeded`.
Lease exit reports zero encoder live bytes while the returned allocation stays
live for the caller; caller free releases it completely.

| Input | Old = new peak bytes | Old to new alloc/remap requests |
| --- | ---: | ---: |
| Dickens 64 KiB | 3,210,608 | 291/166 to 265/144 |
| Mozilla 64 KiB | 2,658,114 | 248/136 to 231/120 |
| Ooffice 64 KiB | 3,236,657 | 291/166 to 265/144 |
| Deterministic JSON 8 KiB | 446,878 | 47/31 to 47/31 |

Resize requests are zero. These tested peaks are unchanged; fewer requests
are not a general reduction in peak memory. JSON produces no counted trial.
The three Silesia inputs each perform four evaluations and two linked emissions;
real wire attempts fall from eighteen to sixteen. Caller-owned Profile storage
grows from 161,840 to 178,240 bytes and is excluded from encoder heap ledgers.
Fixed stack preparation storage is also separate from requested-heap limits.

Forty fixture/configuration combinations compare exact counts, complete emitted
wires and semantic stats with the independent original writer. Tests cover
active alphabet sizes 1–4/complex, more than 128 commands, key mismatches,
readiness and actual allocation failures. They pass 21/21 in native Debug,
ReleaseFast and x86-linux. Eighteen policy/ownership scenarios pass 20/20 in
the same targets, including plain ties and baseline-free/emit-OOM cleanup.
Context ReleaseFast passes 82/82; public profile/resource contracts pass 25/25.
Native/Wasm compile and CLI help checks pass 212/212 with explicit exit 0.

After pulling with rebase, count/emission passes 21/21, policy/ownership 20/20,
public profile/resource 25/25 and combined compile/Wasm/help 219/219, all exit 0.
The v1/v2 report gate passes nineteen tests. Source hashes match formal sampling;
only documentation/evidence was amended after the recorded verification.

Profile schema v2 distinguishes evaluation lengths from actual output wires.
Evaluation references identify recorded events, never fabricated slices.
Selected emissions link to evaluations and the returned event remains a real
wire. The reader accepts valid v1 reports. Truncation does not change selection.
Three inputs by three rounds retain old/new wire identities, context non-time
fields and ordered selection decisions.

[Wasm evidence](brotli-counted-context-wasm.md) preserves the actual 64 KiB
consumer, full input/wires, four evaluations/two linked emissions, exact
Zig/Node decoding, source overlays and frozen replay. The ordinary
[evidence package](data/brotli-counted-context-20261028/) preserves raw timing
epochs, all memory ledgers, source identities, completion logs and reproduction
commands. The full ten-format objective stays active. Next target the remaining
context planning and primary preparation costs with byte/ratio and real-budget
validation.
