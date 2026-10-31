# Zstd HQ per-choice prices and inlined edges

The ordered HQ edge path now reuses the exact literal-length and offset price
terms for one node/offset choice. Match length remains independently priced.
The first admitted edge calls the original complete sequence-price routine;
only a successful result publishes the cached base. This preserves the original
LL, ML and OF validation order. Later edges still admit work, update profiles,
validate their ML and check accumulated u64 cost before insertion or spill.

Preparation is restricted to ordered contexts and ranges with
`maximum - minimum >= 4`, after the existing short-range return. Each choice
starts a fresh local cache, including offset aliases of repeated distances.
The node, choice and entropy model stay immutable during enumeration. Generic
contexts retain complete pricing. Edge extension is explicitly inlined, and
the optional cache pointer avoids a separate runtime gate argument. The small
`prepared_price.zig` module owns the price invariant; search and insertion
semantics remain in their existing modules.

There is no new requested heap allocation. The exact LL/OF base and ML term
are nonnegative; legal symbol prices, extra bits and the long-offset penalty
bound the complete u32 price at 71,424. Zero is a valid cached base. This change
does not reduce search depth, candidate lengths, state width or admitted work.

## Ordinary matched measurements

The baseline is the preceding strict-cost implementation plus the current
fixed-window safety increment, reconstructed from `fdcc266e` and the frozen
source overlay. It is not a clean-HEAD comparison. Both ordinary executables
use Zig 0.16.0 LLVM ReleaseFast, x86-64/Skylake, an Intel i7-10700K, one codec
thread pinned to CPU 2, and the public allocating native-frame API with control
and memory profiles disabled in the timed call. Timing includes caller frame
release. Input setup, hashing, diagnostic encoding and decoding are outside
that interval.

Eight alternating AB/BA sweeps use two alternating Vort/libzstd rounds per
process. Sixteen input/strategy configurations produce 160 serial processes
and sixteen samples per side/configuration. Pure-repetition controls batch
100 encodes and random controls batch 20; all other cases use one encode.
The input prefixes, dictionaries, executable identities and raw clocks are
frozen. No compiler or codec-validation campaign overlaps formal timing.

| Scope | Candidate / baseline time | Paired wins |
| --- | ---: | ---: |
| Three real 4 KiB files, btultra2 | `0.891906` | `23/24` |
| Three real 16 KiB files, btultra2 | `0.845568` | `23/24` |
| Three real 4 KiB files, btopt | `0.881483` | `24/24` |
| Trained dictionary, btultra2 | `0.841684` | `8/8` |
| Periodic 4 KiB, btultra2 / btopt | `0.826643 / 0.743922` | `8/8 / 8/8` |
| Pure repetition 4 KiB, btultra2 / btopt | `0.986752 / 0.999144` | `5/8 / 5/8` |
| Random 4 KiB, btultra2 / btopt | `0.994819 / 0.998760` | `7/8 / 3/8` |

All complete wire signatures, resolved/requested settings, diagnostic counters
and requested working-memory peaks are identical. All nine real-file points
improve by their median ratio; Mozilla 4 KiB and MR 16 KiB btultra2 are
`0.747389` and `0.747711`. These are measured point estimates, not a statistical
significance or all-corpus/platform claim. Results from previous epochs are
not multiplied into a cumulative speedup.

The reference is the local libzstd 1.6.0 shared object, SHA256
`c76f4c4457df67a5e0c7bb6bb4f58b9857cf4f2cdd7925bfb9345daac4e6b83e`.
Public requested HQ depth/nice/minimum are 64/64/3, windows are 15/17, checksum
and content size are enabled, and workers are zero. Unspecified reference
hash/chain parameters retain its level-3 defaults. This matches the requested
controls, not the two implementations' algorithms or actual visited work.

| Scope | Vort / libzstd time | Vort / libzstd compressed size |
| --- | ---: | ---: |
| Real 4 KiB btultra2 | `51.864742` | `0.985492` |
| Real 16 KiB btultra2 | `55.863803` | `0.995786` |
| Real 4 KiB btopt | `33.135267` | `0.981975` |
| Trained dictionary btultra2 | `55.059205` | `1.012701` |

Periodic synthetic input retains particularly excessive work: btultra2 and
btopt time ratios are `37826.011 / 5363.705` while wire-size ratios are both
one. The 4 KiB periodic input produces a 25-byte frame but admits
34,000,436 btultra2 price evaluations over two passes and 4,993,915 btopt
evaluations over one. The two btultra2 passes return two plan matches in total.
Random btultra2 has no match transitions and still performs two HQ passes,
requests a 4,616,748-byte working-memory peak and chooses the same 4,110-byte
raw frame as libzstd. Random controls retain time ratios `6.553 / 6.109`. Pure-repetition
controls are faster and smaller than the reference in this narrow measurement.
The former `58.37 / 65.74` real-file gap belongs to the preceding dated epoch;
the table above is the newly measured result. Broad HQ search design and
unnecessary work on simple inputs remain much larger issues than this price
and call-overhead increment.

## Candidate selection and controls

The first ungated cache improves real/dictionary files but regresses the
pure-repetition controls. A five-way control screen, a four-way real-file
screen, then a baseline/inline/combined screen compare helper gates, nullable
cache arguments and explicit edge inlining. All are retained separately.
The combined candidate wins the three real-file aggregate comparisons against
pure inlining and is selected for the formal campaign.

An independent pre-formal, larger-iteration control screen still records
combined pure-repetition ratios `1.022634 / 1.050444` for btopt/btultra2. Its
formal counterparts are near parity. Those rows have zero price evaluations,
so the variation cannot be attributed to saved price computations. Both raw
campaigns remain in the package; microsecond controls do not establish a gain
for all small inputs. The combined executable is 38,128 bytes larger than the
baseline. That binary delta is not a requested-heap or RSS measurement.

A symbol-only baseline diagnostic finds edge extension at 58.26% of 1,086
user-cycle samples, candidate traversal at 14.94% and insertion at 8.94%.
Candidate compilation overlapped that diagnostic, so it is excluded from all
speed claims and provides only exploratory hotspot evidence.

## Exactness and verification

Independent frozen-baseline contracts compare 570,064 ordinary/known-code
prices, 448 full state cases, 704 small-quota prefixes and 24 generic/untagged/
zero controls. Nodes, row tags, spill continuations, model immutability and
every profile field agree. Invalid LL/ML/OF, repeat validation, early return,
u64 exact-fit/overflow and quota error order are included. The selected combined
candidate passes native Debug/ReleaseFast, 32-bit x86 Debug and actual
wasm32-wasi ReleaseFast, three tests on each target. Pure inlining also passes
its actual edge oracle; its unused cache primitive is explicitly skipped.

The shipping module adds production regressions for the complete legal ML
range, every LL bucket and ML endpoint, offset penalties, zero bases, failed
first-price publication, preparation thresholds, repeated-choice aliases and
every small admitted quota prefix. Their explicit HQ test-coordinator import
also makes a precise root filter collect all three named tests. Initial
anonymous-only filtered runs and a standalone module-root correction are
retained as setup diagnostics, not target-test passes.

Complete Zstd Debug and ReleaseFast suites each pass 1214/1214; the final
registered root filter passes 17/17 in both modes, including all three new
named regressions. An unchanged shipping-source snapshot executes the named
regressions on x86 Debug and actual Wasm ReleaseFast, 9/9 each. The public HQ
Wasm gate passes four operations and 7/7 build steps. The independent reference
campaign passes 41 groups, eight historical frozen wires, precise work limits,
reusable cycles and source identity checks with libzstd 1.6.0 and system 1.4.8.
An actual shipping executable binds all sixteen measured full wires, settings
and profiles; its incidental clocks are excluded from formal timing.

Final `check` / `check-wasm` passes 212/212 steps, CLI help exits zero, and
format/diff checks pass. Those broad checks compile repository consumers;
full runtime execution in this increment is Zstd only. All gates reached
terminal exit zero. Unrelated Bzip2 changes remain unstaged, so this increment
is left uncommitted under the repository's collaboration rule.

The source overlays, ordinary and exploratory raw reports, executable/reference
identities, standalone contracts, replay commands and independent reducer are
in [`data/zstd-choice-price-20261031/`](data/zstd-choice-price-20261031/).

Next work should locate and reduce excessive admitted transitions on periodic
inputs, then measure larger real files and persistent streaming/dictionary
paths. Brotli command pricing/context preparation and Deflate multi-block
entropy-aware planning remain priorities within the full compression goal.
