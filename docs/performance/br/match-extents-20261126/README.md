# Adjacent match extents and proposal phase lifetime: rejected V8 pilot

The combined V8 candidate is **not accepted or merged**. Its predeclared
two-round twelve-file pilot gives candidate/baseline throughput geometric mean
**0.99258945x**, with NCI **0.98356974x**, Mozilla **0.96273265x** and Webster
**0.94046180x**. These observations do not justify the next full acceptance
campaign. No confidence interval or industry-leadership claim is made from
this pilot; all observations and negative rows are retained.

V8 combines an exact adjacent-LCP memo with earlier release of the completed
lazy-proposal phase's workspace. The memo stores **512 u64 values / 4 KiB** and
falls back for unsupported or nonadjacent queries. The two changes were
measured together. This pilot cannot assign the observed differences to
cache lookup, pointer identity, layout, or either change in isolation.

## Exact baseline, source and lifecycle

The baseline is the **actual accepted V7** ELF
`437dc07dbc242dbdfc8d4d1399ef83e0790a6471a1ea5724fcc4aecc859a49ec`.
Its original build stamp remains `b199db72+paired-search-histogram-proposals-v7`;
the build receipt records that its public code matches main `7b575072`.
The candidate stamp is `7b575072+adjacent-match-extents-v8`, ELF
`f702d993d709f138976633fe0ccaa846898624cd896ac15bf751238cafa2b6a0`.
Legacy `old_exact`/`current` slot names and the stale c2 wording in
`settings.json` are preserved raw. They do **not** make this comparison V8/c2.

Both variants use the same unchanged public-API probe and provenance code:
ordinary allocating q8/generic/explicit window16, Zig0.16 ReleaseFast,
`x86_64-linux-gnu`, `skylake+pku+sgx`, i7-10700K, CPU2, one declared codec
thread. Each process performs one untimed allocating encode/free warmup and
one timed allocating encode/length-mix/free. Inputs are twelve actual Silesia
65,536-byte prefixes, without repetition, padding, normalization or corpus
replacement. Caller-owned warmed/prepared/streaming APIs are not measured.

The complete pilot contains **24 paired observations / 48 timed calls**.
Round0 runs baseline then candidate; round1 reverses that order for every
file. For each corpus row, the reducer takes the mean of the two log
candidate/baseline elapsed ratios, exponentiates it, and takes its reciprocal
as throughput ratio. The twelve throughput ratios receive equal geometric
weight. It does not select an independent minimum or discard an outlier.

| Input | Candidate / baseline throughput |
| --- | ---: |
| dickens | 1.00209976x |
| mozilla | 0.96273265x |
| mr | 0.99031364x |
| nci | 0.98356974x |
| ooffice | 1.03668794x |
| osdb | 0.98776840x |
| reymont | 0.98238846x |
| samba | 0.99945870x |
| sao | 1.02478239x |
| webster | 0.94046180x |
| x-ray | 0.99565730x |
| xml | 1.00880522x |

The planned six-round/full-control thresholds remain in the original settings,
but only the two-round pilot was completed here. This package does not claim
that a full acceptance or full Brotli performance gate ran for V8. Root's later
V9 mismatch-cap investigation is a separate source/experiment and does not
modify or replace this frozen V8 evidence.

## Correctness and verification coverage

Recorded standalone extent-kernel verification passes **9/9** entries
(eight named contracts plus import), and the actual ordinary-modeled scalar
gate passes **14/14**. Their original argv, exit files and stdout/stderr logs
are archived. All **24 complete initial wires** are byte-identical across
baseline/candidate and were decoded with pinned libbrotli **1.2.0** before
timing. The library bytes, runtime-version and mapping receipt are retained.
This archival replay hashes them and checks the recorded decode receipt; it
does not load a library or decode again, or infer a broader loader closure.

Each timed output checks length and mix; complete timed-wire SHA/decode was
not measured. That scope remains explicit in every process report. Both build
receipts retain successful record/probe stage exits. The V8 snapshot has
**2,203 frozen src entries and zero generated Python-cache entries**.
The accepted V7 source manifest/stamp is retained separately; its one generated
cache entry is explicitly excluded as an artifact rather than relabeled as
codec source. All remaining baseline source bytes match that original manifest.

## Content-addressed archive and portable replay

`raw.tar.gz` stores **3,190** exact content-addressed members for **5,561**
logical files. `archive-bindings.json` lists every logical byte length/SHA,
stored member length/SHA, source path, snapshot identity and archive SHA.
Identical contents share a member through explicit mappings; no raw sample,
wire, argv, log or source file is silently removed. ELF objects are gzip blobs
with their original uncompressed identity also bound; replay decompresses and
hashes bytes without executing them. Compiler caches, Git administration and
generated Python bytecode are excluded. The original input/reference/source
paths stay in their raw metadata without becoming replay dependencies.

`verify.py` reads only this package. It checks full tar membership, every
logical byte identity, both source manifests and ELF identities, common probe,
reference hashes, the 24 wire-byte pairs, process exits and AB/BA order,
48 timed-call counts, and every saved per-row pilot mean/aggregate. No archived
runner, recorded argv, codec, ELF or library is executed.

```sh
cd docs/performance/br/match-extents-20261126
sha256sum -c SHA256SUMS
PYTHONDONTWRITEBYTECODE=1 python3 verify.py
```

Copying these five package files to another directory preserves the replay
paths. The verification receipt embedded in `archive-bindings.json` records
the actual archival replay outcome. This is a rejected pilot observation
package, not a performance ratchet, CI, memory/RSS result, or new codec run.
