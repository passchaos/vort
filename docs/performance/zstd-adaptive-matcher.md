# Zstd matcher sizing and block index policy

Date: 2026-10-31. [Frozen evidence and audit](data/zstd-adaptive-matcher-20261031/README.md).

The local-optimal parser now chooses its matcher from the validated input,
prefix and retained-window intersection. When a hash table can shrink below
65,536 entries (`min(prefixLen + block.len, window_len + 1) <= 32768`), it uses
a source-sized table, down to 256 entries. Otherwise it
keeps the original full matcher. The two variants share one333-line kernel;
their wrappers are17/19lines. Full mode retains its original descriptor layout,
Node16 representation, resource calculations and exact matching trace.

Dictionary/history prefixes are fully indexed. With any retained prefix,
block advancement also remains fully indexed. Only a prefix-free local parse
using a smaller table samples long skipped spans: spans above128 positions
index every eighth position and keep their final64 positions dense. This is a
deterministic ratio/work heuristic; all returned matches still compare exact
source bytes under the original generation/window checks.

## Ordinary evidence

The reference is local libzstd1.6.0, with the same requested HQ strategy,
depth64, nice64, minimum3 and content/checksum flags used in the preceding
local-optimal epoch. Zig0.16.0 LLVM ReleaseFast runs use i7-10700K and one
codec thread on CPU2. Compilers and separate verification runs do not overlap
formal timings. Input setup, profiles, hashes and decoder checks remain outside
the ordinary allocating encode/free interval.

The design follows source-sized matching tables and selective BT insertion in
local zstd commit `01b7154f1172432f8abe9b3bb9909e14a1176b7d`, especially
`lib/compress/zstd_opt.c`. Vort retains its own hash/chain policy and uses a
stride-eight skip with a dense 64-position tail; source resemblance does not
establish reference algorithm equivalence.

Five initial variants isolate sized tables, sparse indexing, their combination
and cold two-pass capacity reuse. The final policy is separately measured
against the current local-optimal baseline.

| Final policy scope | New / baseline time | New / baseline size |
| --- | ---: | ---: |
| Three real4KiB btultra2 files | `0.875936` | `1.000000` |
| Three real16KiB btultra2 files | `0.972982` | `0.999923` |
| Three real4KiB btopt files | `0.889787` | `1.000000` |
| 256-byte real prefixes, btopt / btultra2 | `0.252047 / 0.200969` | `1.000000` |
| 1KiB real prefixes, btopt / btultra2 | `0.531371 / 0.495488` | `1.000000` |
| Periodic4KiB, btopt / btultra2 | `0.203531 / 0.237623` | `1.000000` |
| All twelve64KiB Silesia prefixes, btultra2 | `0.994517` | `1.000000` |
| All twelve128KiB prefixes, btultra2 | `0.988312` | `1.000000` |
| Three actual1MiB inputs, btultra2 | `0.988568` | `1.000000` |

Ratios are geometric means of per-case medians. Primary/short campaigns use
three alternating sweeps; wide campaigns use two. The final policy keeps all
27 large-input complete wires identical. One256-byte btultra2 case reduces
parser requested-heap peak from552,656 to30,416bytes. These are requested bytes,
not process RSS or a complete industry ranking. Larger files deliberately use
the original matcher because the new full-size variant had no stable benefit.

The initial all-source sparse combination grew the trained dictionary output
0.34% and had a2.50% one-MiB time regression. Keeping prefix-backed and
full-sized matching unchanged avoids those tradeoffs in the selected policy.
Cold two-pass Scratch reuse reduces14 allocations to9 with identical plans,
but its measured large-input gains are inconsistent; it remains an unadopted
experimental variant. No speedup is attributed to allocation counts alone.

## Final-source reference check

Separate final-source campaigns alternate the selected prototype and the live
runner for two sweeps. All 55 case/configuration rows produce identical complete
wires. These measurements are a separate epoch from the A/B table above.

| Live btultra2 scope | Live / libzstd time | Live / libzstd size | Live / selected time |
| --- | ---: | ---: | ---: |
| All twelve 64 KiB Silesia prefixes | `3.127111` | `1.004801` | `0.994192` |
| All twelve 128 KiB prefixes | `3.176228` | `1.005144` | `0.998238` |
| Three actual 1 MiB inputs | `4.569109` | `0.992800` | `1.000132` |

The final 4 KiB periodic controls still take `8.169298x` reference time for
btopt and `13.303064x` for btultra2, despite the internal A/B improvement. The
256-byte real prefixes take `8.753451x / 5.948718x`, respectively. Small-table
savings therefore close only part of the remaining encoder gap. These prefixes
and three multi-block inputs do not establish a full-file or industry ranking.

## Contracts and validation

Active hash masks are separate from retained allocation capacity. Prepare,
fork, movement, generation reuse, source immutability and partial allocation
failure use checked ownership and exact growth-peak accounting. Independent
raw-baseline tests preserve full-mode frontiers, all nodes/heads, profile fields,
required bytes and descriptor offsets. Failure injection covers every actual
growth allocation, including the different two/four-allocation cases.

Actual source-policy tests cover32768/32769, prefix crossings and window
intersections with an independent allocator meter. Required memory equals
actual peak; exact quotaN retains the complete plan,0/N−1 refuse and clean up,
and one-below memory refuses before allocation. Concrete matcher references
verify that the observed route matches the intended policy.

The native Zstd suite passes 1246/1246 tests in Debug and ReleaseFast, and
`check check-wasm` completes 212/212 build steps. Independent full-baseline
comparisons run 19 named matcher tests, 25 total, in native Debug/ReleaseFast,
32-bit x86 Debug and actual WASI ReleaseFast. Public policy tests run three
named tests, 15 total, in each native mode. Reference, CLI, help and the public
Wasm gate's six operations complete with observed exit code zero. The frozen
package includes both executed Wasm modules and the independent oracle source
overlays. Old beam, whole/complete coverage, dictionary/retry semantics and
strict archived wire tests remain covered.

The frozen reducer independently verifies all 404 benchmark process records
and 165 case/configuration rows across nine serial campaigns, input/report
hashes, complete wires, medians, reference ratios and recorded validation
terminals. The live audit additionally checks all seven native benchmark
binaries and the 66 archived shipping source files. Native binary identities
are recorded in the package; their bytes remain in the local experiment folder.
Unrelated Bzip2 work prevents a safe focused commit;
this increment remains uncommitted under repository workflow instructions.

Next work should improve persistent matching/index reuse across blocks and
cost-model quality, and continue Brotli prepared entropy/command parsing and
Deflate compact matching evidence. The industry-best objective remains active.
