# Exact ordinal match index, 2026-11-03

Fixed-price optimal parsing can traverse a four-byte index while preserving
every matching candidate reachable through the original three-byte hash
chain. This reduces rejected-prefix work without changing DP costs, token
order, search quotas or complete Brotli output. Index construction, admission,
ownership and the bounded cursor live in `src/lz77/ordinal_index.zig`; their
independent tests use cohesive candidate, boundary, admission and resource
modules.

## Candidate equivalence and bounded work

Each old three-byte predecessor receives an ordinal in its bucket, including
false hash collisions. Complete four-byte equality implies equal old
three-byte hashes, so `ordinal[position] - ordinal[candidate]` is exactly the
candidate's one-based position in the original chain. Only candidates within
the old `max_chain` and window limits are returned.

Four-byte hash collisions may belong to other old buckets. They cannot safely
consume the old quota or participate in ordinal subtraction. After visiting
at most `max_chain` four-chain nodes, the cursor resumes the original chain,
counting its original nodes and skipping coordinates already visited through
the four-chain. The frontier records only processed nodes. This preserves
matching-candidate order and gives at most twice the original node budget,
including an encountered window stop. The existing candidate budget, maximum
match length, strict cost ties and length-choice frontier remain unchanged.

A direct four-hash replacement is not equivalent. A 713-byte control moves a
true match from old rank 1 to new rank 129 behind foreign collisions, exceeding
quota 128. Its fixed DP cost grows 5,829 to 5,837. The exact cursor retains the
old candidate in this control; a separate two-KiB oracle exercises the actual
fallback and verifies no repeated candidates.

## Admission and storage

The new representation is considered only for fixed parsing with minimum
match at least four, chain budget at least 32 and input 8–64 KiB. Modeled,
prepared, tiny and larger-input routes retain the original index.

While constructing the original index, one position is sampled per eight-byte
group. The offset rotates through all alignments over 64 bytes: positions
`0,9,18,27,36,45,54,63`. A differing four-byte prefix with an old predecessor
within one eighth of the actual search window contributes to admission. The
new index is built only when these contributions exceed one quarter of all
valid sample positions. The actual parser window is unchanged. This cheap
deterministic estimate selects an execution path; either path retains the
same logical candidates and output.

For `m = input_len - 3` valid four-byte positions, the sample count is
`8*(m/64)` plus the number of those eight offsets below `m%64`. Rotating the
offset avoids the fixed-alignment bias observed on MR: a fixed zero offset
samples only 4.03% mismatches, while rotating samples 30.73%, near its 31.16%
complete-position statistic. Restricting the estimate to nearby predecessors
avoids building a second index for largely unique random prefixes.

The retained old predecessor array is u32. Two additional arrays, ordinals
and four-byte predecessors, are u16. At 65,536 bytes the maximum ordinal is
65,534 and the last valid four-byte start is 65,532, distinct from sentinel
65,535. Both builders reuse the existing head workspace. Additional active
index storage is `4*input_len`, or 256 KiB at 64 KiB, with no extra head table.
ArrayList capacity can exceed this logical size; reusable state retains it
across calls and frees it through the explicit allocator at deinit.

`OptimalSearchProfile.index_bytes` and Brotli `optimal_index_bytes` describe
the active logical index, rather than peak or resident heap. Whole-encoder
allocator tracking includes the actual new capacities. Zstd's recursive
capacity getter also includes them when a later call uses the old route or
first enables tracking.

## Ordinary public q8 evidence

Baseline codec source: `e978336e`. Both executables use the public q8 quality
API through `tools/br/planned_encode_bench.zig`: quality 8, generic mode and
actual wire window 16, with Brotli reference quality/mode/window matched.
Twelve Silesia sources at 4/16/64 KiB plus random 16/64 KiB and repetitive
64 KiB controls give 39 inputs. Three outer sweeps alternate binary order,
verify 234 processes and retain all five alternating Vort/reference timing
rounds at three encodes per round. Each row uses the median paired time ratio.
All complete input, Vort wire and reference wire bindings remain identical.

Host: Intel Core i7-10700K, logical CPU2, one codec thread. Vort uses Zig
0.16.0 ReleaseFast, GNU x86-64, `skylake+pku+sgx`. Reference Brotli 1.2.0 is
clean source `558fc647cdaf391228d614ca85f711e02e4e583b`, CMake Release,
`-O3 -march=skylake`, using the pinned encoder/decoder/common loader closure
recorded in [interval-cost evidence](interval-cost.md).

| Real-input scope | Geometric paired time ratio | Faster row medians |
| --- | ---: | ---: |
| 4 KiB | 0.99791 | 8/12 |
| 16 KiB | 0.98713 | 12/12 |
| 64 KiB | 0.95697 | 12/12 |
| All 36 real inputs | 0.98051 | 32/36 |

The real-input matrix improves about 1.95% overall and 4.30% at 64 KiB.
MR/Dickens 64 KiB medians are 0.94304/0.89447; Mozilla is 0.99865. The weakest
rows are SAO/Dickens 4 KiB at 1.00451/1.00442. Random 16/64 KiB controls are
0.99531/0.99807, and the repetitive control is 0.97359. Small changes in
unadmitted controls are not attributed to avoided match work.
[All row results](ordinal-index-20261103.csv) retain independent medians,
paired ratios and win counts. The separate reference epoch remains 31.27
times native Brotli latency geometrically at size 0.99556 times reference.

Eleven longer alternating pairs at seven encodes per round give:

| Input | Median paired ratio | Geometric paired ratio | Wins |
| --- | ---: | ---: | ---: |
| MR 64 KiB | 0.92768 | 0.92878 | 11/11 |
| Dickens 64 KiB | 0.88697 | 0.88741 | 11/11 |
| Mozilla 64 KiB | 0.99708 | 0.99611 | 8/11 |
| Dickens 4 KiB | 0.99799 | 1.00201 | 8/11 |
| SAO 4 KiB | 1.00042 | 1.00077 | 5/11 |
| Random 64 KiB | 0.99249 | 0.98846 | 7/11 |

The targets improve about 7.2% and 11.3% at the longer median comparison.
The earlier weak small-input and random controls do not retain a material
median regression; the Dickens 4 KiB geometric value still shows small
positive movement, and unadmitted controls are not counted as direct index
wins. All 132 processes preserve complete wires.

An initial long run shared
CPU2 with a newly started compiler and is excluded. The accepted long run
starts after all compiler threads were moved away from CPU2 and its CPU10
sibling. Ordinary matrix timing completed before that compilation began.

## Independent validation

Candidate oracles construct predecessor chains independently, then compare
every returned ID and its order with the original quota-limited chain. They
cover foreign collisions, fallback at valid/invalid frontiers, zero/one/128
budgets, window neighbors, poisoned tails, immutable input/index arrays and
the full 65,536 boundary. A 65,537 helper request refuses before allocation;
the public parser retains its old route for this size. Admission tests use
u128 mathematics and independent offset enumeration, including usize limits,
and compare actual builders against independent predecessor/reference counts.

The 110-case plan oracle compares every token, DP cost/step and stats value
with the original index. All non-time frontier and candidate-budget profile
fields agree; physical traversal and active-index bytes intentionally differ.
Independent replay, warmed allocation-free reuse, real failures in both new
arrays and admit→decline→poison→admit transitions retain ownership and cleanup.
Native Debug/ReleaseSafe/ReleaseFast checks pass.

A Zstd reusable-owner test first allocates ordinal state, switches to the old
route, then enables the real public memory profile. Its independent allocation
ledger equals the recursive capacity getter before tracking and equals getter
plus control allocation afterward. A separately allocated standard decoder
verifies output; final encoder deinit balances all requested allocations.
This resource test passes 24 tests including imports.

Final ReleaseSafe suites pass 594 Deflate, 1,510 Brotli plus one skip, and
1,266 Zstd tests. The build-integrated Brotli/Zstd command exits zero. Actual
32-bit x86 ordinal tests pass 4/4, including the plan and candidate/admission
oracles. The public prepared-command Wasm gate preserves the frozen complete
wire and passes Zig/Node decoding. The default `check check-wasm` command
completes 212/212 build steps with exit zero. The older extra ReleaseSafe
whole-library compile remains pending and is not counted as a completed
current gate. Earlier full-suite runs belong to earlier admission variants
and are not substituted for final-source verification.

## Reproduction and artifact bindings

`zig-out/br-ordinal-index-20261103` retains source variants, frozen binaries,
every raw timing round, `matrix-near.py`, `long-near-clean.py`, independent
oracle logs, source/ELF comparisons and final validation. Direct-four-index
work counts and the collision control remain in
`zig-out/br-optimal-prefix-bound-20261103/index-*`.

```sh
python3 zig-out/br-ordinal-index-20261103/matrix-near.py
python3 zig-out/br-ordinal-index-20261103/long-near-clean.py
zig test src/lz77.zig -OReleaseSafe --test-filter 'optimal'
zig test src/deflate.zig -OReleaseSafe
zig build -j2 test-br test-zstd -Doptimize=ReleaseSafe --summary all -- --test-timeout 900s
zig build -j4 check check-wasm --summary all
```

| Binding | SHA-256 |
| --- | --- |
| Baseline binary | `4db91060656767976aef9d4102784a6af8245cf154984d938b500cfbf3b89ad7` |
| Measured candidate binary | `312b279447cf723e0dec6ce70c021032f72db6967a888b625a75e46191a1aa32` |
| Final binary | `bb3bdaa0ee0f0390e5349d089c0cdd53477d2de7bd93e3192637b06a01292c6a` |
| Matrix report | `54afcffdff3cf937c659cf5b9433fe8dbe81de16ee55cbc1d75412a0a12b5ea1` |

All ten executable sections in the final binary match the measured candidate.
Broader parsing/model quality, context search, candidate emission, streaming,
memory and platform comparisons remain work. The Deflate/Zstd/Brotli
industry-best objective stays active.
