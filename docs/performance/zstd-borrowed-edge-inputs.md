# Zstd HQ edge expansion borrows stable input snapshots

The HQ parser now keeps the public `candidate` node argument by value but
passes pointers to that stable snapshot and to the immutable local repeat
choice array into the private edge-expansion loop. This removes repeated
`Node` and `rep.Choice` value arguments from every admitted transition without
changing candidate enumeration, price admission, profile accounting, node
construction, target insertion or spill selection.

The public value boundary is intentional. A candidate may originate in the
same DP row that later insertions move, so borrowing the caller's row element
would not be safe. New frozen-reference tests exercise real source-row aliases
at every slot of widths 1, 8 and 16 across tagged and untagged tables,
bounded and whole-block nodes, sampled and complete match lengths, finite
price prefixes, denial-before-work and overflow-after-admission.

## Current-HEAD measurements

The baseline executable was built from `ea843c91` immediately before the
source change. The candidate was built after the change, including the prior
cost-first and known-ML optimizations. Both use Zig 0.16.0 ReleaseFast on an
Intel Core i7-10700K and were pinned to logical CPU 2. Their SHA-256 identities
are respectively
`e1f76b119e29cad989a4c14b5a1d9d7931ed8a9080898fbeddecd9491ae4afcd`
and
`2b8f98a5a17e000941b17e6fb5bda208b8572e18622bc38956f1e6195369bbb8`.
The independent reference is libzstd 1.6.0 with SHA-256
`c76f4c4457df67a5e0c7bb6bb4f58b9857cf4f2cdd7925bfb9345daac4e6b83e`.
The complete raw A/B CSV/JSON set is retained in
[`data/zstd-borrowed-edge-inputs-20261029/timings.tar.xz`](data/zstd-borrowed-edge-inputs-20261029/timings.tar.xz).

The first matrix uses the first 4096 bytes of Silesia Dickens, Mozilla and MR,
window log 15, checksum/content size, and aligned btopt or btultra2 controls.
Eight AB/BA cycles alternate the two separately compiled executables. Ratios
below are candidate median time divided by baseline median time.

| Input | btopt ratio | btultra2 ratio |
| --- | ---: | ---: |
| Dickens 4 KiB | 0.984917 | 0.992855 |
| Mozilla 4 KiB | 0.967054 | 0.967744 |
| MR 4 KiB | 0.998989 | 0.980601 |

The six-row geometric ratio is `0.981955`, or about 1.8% less ordinary encode
time. Paired candidate wins are 6/8, 4/8, 8/8, 8/8, 6/8 and 7/8 in table
order. No configuration has a slower aggregate median.

A separate four-cycle matrix uses 16 KiB Dickens and Mozilla plus the existing
8 KiB reference input and 4096-byte libzstd-trained standard dictionary. Its
window log is 17. The trained cases keep 78 btopt and 87 btultra2 actual
dictionary sequences.

| Input | btopt ratio | btultra2 ratio |
| --- | ---: | ---: |
| Dickens 16 KiB | 0.985167 | 0.998557 |
| Mozilla 16 KiB | 0.968388 | 0.971325 |
| Trained dictionary 8 KiB | 0.977225 | 0.968201 |

The second matrix geometric ratio is `0.978084`, or about 2.2% less ordinary
encode time. Five configurations win all four paired cycles; Dickens
btultra2 is 2/4 and near parity. Across both matrices, 144 ordinary timed
encodes and 288 cross-codec decodes pass. For each input and strategy, complete
Vort wire hashes, encoder-control profiles and requested peak working memory
are identical between baseline and candidate in every cycle.

The benchmark command shape was:

```sh
taskset -c 2 $executable \
  --match-hq --strategy btopt --window-log 15 \
  --content-checksum true --content-size true --level 3 \
  --iterations 1 --rounds 1 --limit 4096 \
  --libzstd /home/passchaos/Work/zstd/lib/libzstd.so.1.6.0 \
  --path /home/passchaos/Work/corpora/silesia-20261025/files/dickens \
  --csv $cycle.csv --samples-json $cycle.json
```

Each invocation validates the Vort wire with libzstd and the reference wire
with Vort outside the timed loop. The profile encode is also outside the timed
loop and must reproduce the timed wire. These short, background-loaded samples
support retaining a low-risk exact optimization; they do not establish
statistical significance, full-corpus throughput or industry leadership.

## Verification

The exact frozen-reference suite passes all 79 tests in native Debug,
native ReleaseFast and actual 32-bit x86 Debug. Existing ReleaseFast HQ search
and general HQ test steps pass. The executed wasm32-wasi HQ search gate passes
whole-complete, full-span, incremental retry and unsupported-control cases.
Versioned bidirectional compatibility checks pass 41 HQ-search rows and 52 HQ
control rows. Continue with wider clean-host measurements and larger reductions
in transition count; the remaining gap to libzstd is still substantial.
