# Known-frontier mismatch caps and phase lifetime: rejected V9 pilot

V9 is **not accepted or merged**. The predeclared two-round twelve-file pilot
has candidate/baseline throughput geometric mean **0.99876765x**, with NCI
**0.98642442x**. It did not reach the ROI for continuing to full acceptance.
Every raw observation remains; no CI or formal control-gate conclusion is
claimed from two rounds. This package is independent of the rejected V8
adjacent-LCP memo package and does not replace or combine its observations.

V9 caps `matchLength` at the already-known frontier `k` only when a real byte
mismatch at that frontier proves the match cannot extend farther. Candidate
full-stop handling still compares with **original `max_len`**, not the capped
query limit. It also releases completed lazy-proposal workspace at the phase
boundary. No matching cache or new allocation is introduced by the comparison
cap. These two changes were measured together; the pilot cannot assign loss
or gain to the cap or phase release independently, or to pointer/layout effects.

## Exact baseline, source and executed scope

The baseline is the actual accepted V7 ELF
`437dc07dbc242dbdfc8d4d1399ef83e0790a6471a1ea5724fcc4aecc859a49ec`,
with original stamp `b199db72+paired-search-histogram-proposals-v7`. Its public
code matches main `7b575072`, as recorded in the original build receipt. The
candidate stamp remains `7b575072+frontier-capped-match-v9`, ELF
`d39d351aa5111099dffa15a00e9a2be623c47cdb75125b7cc53864581918cb88`.
The stale c2 wording and legacy old_exact/current slot names in the raw settings
are retained; they do not relabel the actual baseline as c2 or V8.

Both variants use the same public-API probe/provenance code, ordinary allocating
q8/generic/explicit-window16, Zig0.16 ReleaseFast, x86_64-linux-gnu,
skylake+pku+sgx, i7-10700K, CPU2, one declared codec thread. Inputs are twelve
actual 65,536-byte Silesia prefixes, without normalization, padding or repetition.
Each process performs one untimed encode/free warmup and one measured continuous
owned allocating encode/length-mix/free call. Hardware/cache warming does not
make this a caller-owned warmed/prepared/streaming API comparison.

Only **24 pairs / 48 timed calls** were completed: all twelve rows in round0
baseline/candidate order, then the same twelve in round1 candidate/baseline order.
Each row's elapsed ratio is exp(mean of the two log candidate/baseline raw time
ratios); its reciprocal is the throughput ratio. The twelve row ratios receive
equal geometric weight. No independent minimum or outlier deletion is used.

| Input | Candidate / baseline throughput |
| --- | ---: |
| dickens | 0.99415378x |
| mozilla | 0.98764758x |
| mr | 1.00854853x |
| nci | 0.98642442x |
| ooffice | 1.02197300x |
| osdb | 0.97018940x |
| reymont | 0.98643329x |
| samba | 0.98565509x |
| sao | 1.02630149x |
| webster | 0.97984519x |
| x-ray | 1.08378988x |
| xml | 0.96004422x |

The original six-round/weak-row settings remain as planning provenance. They
are not completed V9 acceptance samples, CIs, or formal public-control gates.
Root's other experiments and the retained V8 package have separate sources and
cannot be multiplied into this pilot.

## Recorded correctness and initial wires

The two targeted frontier fixtures passed **2/2**, checking original full-stop
handling and shorter mismatches under eight/thirty-two frontiers. An earlier
ordinary-parser gate passed **12/12**; after the final fixtures were present,
`parser-final-native.stderr` records the actual final **14/14** scalar/parser
gate. Both original logs are archived. The final14 result is used for final
coverage, without pretending the earlier12 log had fourteen entries.

All **24 complete initial wires** are exactly byte-identical between variants
and were decoded with pinned libbrotli1.2.0 before timing. The library file bytes,
version, mapping/decode receipt, complete wires and argv/exits are retained.
Archival verification checks the receipt and bytes; it does not execute the
libraries or infer a new loader-closure proof. Timed outputs check only initial
length/mix, not a complete timed-wire SHA or decode.

The candidate has **2,200 frozen src entries and zero generated cache entries**.
Both successful record/probe build stages, probe code, source manifest and ELF
identities are bound. The accepted V7 source snapshot and original manifest/stamp
remain independent; its generated Python cache is explicitly excluded as an
artifact while that historical manifest is preserved.

## Portable content-addressed replay

`raw.tar.gz` and `archive-bindings.json` preserve every source, probe, manifest,
argv, log, raw pilot sample, input, initial wire, reference library and recorded
gate identity. Exact repeated contents share SHA-addressed blob members through
explicit logical file mappings. ELF blobs use gzip and bind both stored and
uncompressed byte length/SHA; no source/raw observation is silently removed.
Compiler/Git caches and generated Python bytecode are excluded.

`verify.py` reads only these package files. It validates complete tar membership,
logical bytes and ELF decompression hashes, both source snapshots/build stamps,
reference/input hashes, all24 initial wire bytes, AB/BA/process exits, all48 timed
calls, every saved row mean and GM, the targeted2/earlier12/final14 gate logs.
It never executes a codec, ELF, recorded argv, archived runner or decoder.

```sh
cd docs/performance/br/frontier-caps-20261126
sha256sum -c SHA256SUMS
PYTHONDONTWRITEBYTECODE=1 python3 verify.py
```

Copying the five package files preserves replay behavior without the old /tmp
paths. Actual replay outcome is recorded inside archive-bindings.json. This is
an observational rejected-pilot record, not an accepted speedup, CI, RSS result
or industry ranking. Known-frontier cap and phase release remain a joint scope.
