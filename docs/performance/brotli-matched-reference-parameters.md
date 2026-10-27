# Brotli reference parameter matching

`planned_encode_bench` accepts `--reference-lgwin` (10–24) and
`--reference-mode` (`generic`, `text`, `font`), with either `=` or separate
values. Defaults remain lgwin 22 and generic. The existing libbrotli one-shot
adapter receives the resolved quality/window/mode for both the validated
reference stream and every timed round.

For the q8 comparison, use:

```text
--quality 8 --planned-quality=8 --planned-mode=generic
--reference-lgwin=16 --reference-mode=generic
```

JSON and CSV retain the API settings and add `vort_wire_window_bits`,
`reference_wire_window_bits` and `parameters_match`. Matching requires an
explicit Vort quality, equal quality/mode settings, and equal windows read
from the actual streams. Quality and mode are encoder settings; RFC 7932 does
not serialize them. libbrotli q0/q1 can raise a requested small window to 18,
so equal requested windows alone do not establish a match.

Every constructed reference stream is decoded by both Vort and libbrotli
before timing. The benchmark reads the window fields from those streams.
The JSON sample gate checks the field types, completeness and matching logic
without needing CSV; when CSV is supplied, it also compares all five new
reference/window/matching columns against JSON. The sample format retains
wire sizes and hashes, so this gate checks declared metadata consistency;
the benchmark and actual C/stream tests supply the header evidence.

Historical CSV columns remain accepted. Historical JSON may omit the three
wire/matching fields or serialize all three as null; these rows retain unknown
window evidence. Partially present fields and inconsistent matching claims
are rejected. The sample schema stays at version 1.

## Evidence checks and explicit performance requirements

`planned_encode_path_gate.py` validates provenance, parameter evidence, input
identity when supplied, positive counters, and the internal `ratio_bytes <=
lazy_bytes` requirement. Add `--require-ratio-no-worse-than-reference` to enforce
the additional auxiliary legacy ratio size target. The repository's small
fixture can opt into that target explicitly; general file evidence uses the
default checks. This option applies to the auxiliary ratio stream, while the
primary quality-selected stream has its own recorded size and time.

The modern q8/generic/lgwin16 Dickens 64 KiB result illustrates the distinction:
primary 24,723 bytes, auxiliary lazy 26,337, auxiliary ratio **25,194**, reference
**25,165**. The auxiliary ratio is 29 bytes larger than the reference. General
validation accepts this valid evidence; the explicit performance requirement
rejects it. The complete 12-row batch and its original JSON are preserved as
`samples/modern-matched-65536.csv` and `.json`, including all unfavorable rows.
The extracted Dickens row supplies the single-input hash regression case.

## Validation evidence

The initial parameter evidence in the [package](data/brotli-matched-reference-20261028/) uses source
commit `3dd417597de62232050f15041c6ce48b87dd9065` plus recorded tool overlays,
Zig 0.16.0, ReleaseFast, and CPU affinity `0,1,3-9,11-15`. The reference API
reported version `0x01000009` (1.0.9). Default SONAME loading leaves the exact
loaded dependency identities unverified; the JSON preserves that scope.

| Configuration | Vort / reference quality | Vort / reference mode | Requested reference lgwin | Actual Vort / reference window | Match |
| --- | --- | --- | ---: | --- | --- |
| Existing defaults | legacy / 3 | generic / generic | 22 | 16 / 22 | false |
| q8 matching | 8 / 8 | generic / generic | 16 | 16 / 16 | true |
| q0 window adjustment | 0 / 0 | generic / generic | 16 | 16 / 18 | false |
| Different modes | 8 / 8 | text / font | 16 | 16 / 16 | false |

The initial parameter validation commands completed with explicit exit code 0: the original
12 Zig tests, four reference-parameter Python tests, nine JSON/CSV sample-gate
tests, four single-iteration configuration runs, pure JSON and JSON+CSV gates
for each run, and both historical/current path gates. The Zig tests cover
invalid parameters before allocation, requested windows 10/16/22/24 across all
three modes, direct `BrotliEncoderCompress` parity, cross decoding, and q0/q1
window adjustment. Single-iteration runs establish behavior, without a
throughput comparison.

The path-gate follow-up adds five Python tests. The real 12-row batch and
extracted Dickens row pass the default gate (exit 0) and fail the explicitly
requested auxiliary performance target (expected exit 1). Both current and
historical small-fixture schemas still pass that explicit target (exit 0).
`path_gate_followup.json` records the commands, actual/expected exits, hashes
and the retained 29-byte disadvantage. No codec or benchmark result changed.
This additional batch used the main workflow's separate candidate executable
and libbrotli 1.2.0; its original executable and data hashes are recorded in
the follow-up file rather than attributed to the initial source snapshot.

Compressed logs include commands and exit status. `source_epoch.json` records
the source tree, tool and executable SHA-256 values; `sources/` preserves the
tool overlays. `source_epoch.initial.json` and `sources-initial/` retain the
earlier gate implementation for its original logs.
[REPRODUCE.md](data/brotli-matched-reference-20261028/REPRODUCE.md)
gives the narrow build/run commands, and `SHA256SUMS` covers the package files.
