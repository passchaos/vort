# Brotli full API evidence probe

This standalone Zig 0.16 probe calls public APIs through the `vort_br` module.
It emits one JSON document on stdout and exits nonzero after writing the JSON
if a same-API wire, memory-cap, decode, or output-preservation contract fails.
It does not measure timing or RSS.

Build once for each frozen source tree:

```sh
zig build-obj -O ReleaseFast /ABSOLUTE/SNAPSHOT/src/br/encoder/record_optimal_object.zig \
  -femit-bin=/tmp/vort-br-full-evidence-20261123/full-api-baseline-record.o
zig build-exe -O ReleaseFast \
  /tmp/vort-br-full-evidence-20261123/full-api-baseline-record.o \
  --dep vort_br \
  -Mroot=/tmp/vort-br-full-evidence-20261123/full_api_probe.zig \
  -Mvort_br=/ABSOLUTE/SNAPSHOT/src/br.zig \
  -femit-bin=/tmp/vort-br-full-evidence-20261123/full-api-baseline
```

The snapshot-matched record object supplies the three external record-kernel
exports required by the public facade, exactly as the repository build does.

Run the full matrix, or first use `--quick` for the <=255-byte smoke subset:

```sh
/tmp/vort-br-full-evidence-20261123/full-api-baseline --label baseline > baseline-full-api.json
/tmp/vort-br-full-evidence-20261123/full-api-variant --label variant > variant-full-api.json
```

The full matrix has 24 case/quality rows, 144 API entries and 576 API passes
(plus one ordinary complete-Alloc reference per row). It covers empty, 1-byte,
3-byte, 255-byte, deterministic random, periodic and text inputs through 8 KiB,
plus 255-byte and 4 KiB RAW dictionary payloads. Every call sets quality 10 or
11, window bits 16, generic mode and `command_state_max_input_kib = 8`; HQ is
left null to exercise the established quality policy. The RAW dictionary has
2048 pseudorandom bytes split into two nonempty prefixes with one empty prefix
between them. The small RAW payload crosses that prefix boundary. Decoding
uses the same dictionary and an exact output length.

API entries are complete-input Alloc and Into, singleton-chunk Append, and
split-chunk Alloc, Into and Append. There is no public complete-input planned
Append API. Split chunks include empty chunks and two cuts at one-third of
the input. Cross-facade byte equality is an observation: `contract_ok` enforces
wire identity only between ordinary/profiled/exact-cap calls of the same API.
The profile pass measures its own peak; the exact and peak-minus-one passes
replay that API and allocator lifecycle. The latter must return
`WorkingMemoryLimitExceeded` and preserve caller storage.

Allocator-taking APIs use an independent runtime tracker backed by the page
allocator. It rejects resize/remap to expose old/new allocation overlap and
counts requested bytes, including profile control. A pre-existing Append
prefix is excluded; a replacement allocation is counted until publication.
The tracker peak must equal the public profile peak and final live bytes must
be zero. Into uses the library's internal allocator; its independent backing
fields are null. Its public profile, exact cap, cap-minus-one, destination
guards and untouched unused output are still checked. The complete memory
profile excludes stack buffers, input, dictionary and borrowed output; this
probe makes no claims about total process memory or performance.

Compare baseline and variant rows by `(case, quality, api)` and retain all
ordinary/profiled/exact-cap wire SHA-256 values, decoded payload SHA-256,
profiles, cap-minus-one outcomes, preservation flags and `contract_ok`.

The optional comparison generator checks those fields and reports all
differences without deriving timing or RSS conclusions:

```sh
python3 /tmp/vort-br-full-evidence-20261123/compare_full_api.py \
  baseline-full-api.json variant-full-api.json > full-api-comparison.json
```

Initial current-source quick validation passed 10 rows, 60 API entries and all
20 Append profile/tracker comparisons. It also confirmed ordinary wire
differences for split tiny/small inputs and for singleton-chunk Append on RAW
dictionary input. These are recorded observations, not same-API violations.
