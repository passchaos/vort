# Zstd encoding with common requested HQ controls

`run-zstd-encode-bench -- --match-hq` now explicitly configures both Vort and
libzstd's ordinary allocating encoders. It records the requested reference
parameters, Vort's resolved settings and separate diagnostics, actual frame
headers, dictionary identity and alternating raw timing rounds. The feature
is saved in `50e709ce`, alongside the retained state-shift runtime `e29650ca`.
The [evidence package](data/zstd-common-hq-20261028/) contains exact tool sources,
functional gates and the real-input campaign.

The existing level benchmark continues to compare product presets. Selecting
a Vort strategy there does not configure the reference strategy. The explicit
HQ mode uses `ZSTD_compress2` with the requested strategy, window, search log,
minimum, target length, checksum, content size and zero workers. It requires
an explicit reference library file and samples JSON. Defaults are reference
level 3, window log 17, search depth 64, nice length 64, minimum 3, and both
frame flags enabled. It supports btopt, btultra and btultra2, raw and standard
dictionaries, windows 10...30 and representable search depths 2...65536.
An explicit level zero retains its user-facing value and records libzstd's
normalized reference level three.

Depth `D` maps to `searchLog=log2(D)` and therefore must be a power of two.
This aligns a nominal budget; the actual tree visits and parser algorithms
differ. Minimum 3 or 4 is accepted. The reference's unassigned hash/chain
parameters remain level defaults, and their getter values remain zero default
sentinels. `ZSTD_CCtx_getParameter` reports requested parameters, which are
never labeled as applied internal values. `dict_id` in that record means the
dictionary-ID flag; the actual numeric ID comes from each wire header.

Both requested block ceilings equal `min(2^windowLog,128 KiB)`. Smaller explicit
ceilings are rejected because they would require the reference's experimental
block-size control. Vort's history cap is set to the requested window. Small
single-segment frames can declare a tighter actual window through their content
size; both actual headers remain recorded. Vort retains bounded/sample-length
HQ parsing without a price quota. These controls describe a reproducible
pairing without asserting identical internal search behavior.

For example:

```sh
zig build run-zstd-encode-bench -- \
  --match-hq --strategy btopt --window-log 15 \
  --path corpus/input --iterations 1 --rounds 2 \
  --libzstd /path/to/libzstd.so \
  --csv /tmp/common-hq.csv --samples-json /tmp/common-hq.json
```

Ordinary timing includes allocating encode, output-length consumption and
output release. Dictionary files are read outside timing; per-call Vort
dictionary parsing and reference context creation/loading are included.
Validation decodes both directions, and Vort's independent profiled encode
must reproduce the ordinary wire before any measured rounds. Diagnostic
counters are disabled in the timed calls. CSV retains independent minima;
samples JSON also records the median and each alternating round.

## Functional checks

`test-zstd-reference-parameters` exercises explicit libraries through the
ordinary reference path. Both local 1.6.0 and system 1.4.8 pass 14 parameter,
default, failure and streaming checks, five frozen legacy advanced-wire cases
and eight raw/full dictionary bidirectional cases per library. The Debug
probe uses LLVM because its imported optimized decoder contains assembly
alignment directives unsupported by the other Zig backend.

`test-zstd-common-hq-bench` validates the actual benchmark and evidence on both
versions. Each completes 14 bounded commands, 22 rows and 44 raw rounds,
including windows 15/17, two strategies, all checksum/content-size flag pairs
and raw/full dictionaries. It observes six actual dictionary references.
Each gate rejects 25 invalid CLI/output-alias cases, 37 fabricated parameter/
profile evidence cases and eight dictionary-identity failures. Failed commands
leave existing outputs and source files intact and create no new outputs.
The older path benchmark and nine existing sample-gate tests also pass.
The subsequent level-zero boundary fix in `a66c067d` expands each final
functional campaign to 15 commands, 24 rows and 48 raw rounds, with two extra
negative checks for incorrectly recording normalized level zero. Both library
versions and the final cached build check pass. The real-input measurements
below retain the earlier exact tool-source epoch and explicit level three.

## Real-input comparison

The CPU-2 campaign uses Intel i7-10700K, Zig 0.16.0 LLVM ReleaseFast and
Skylake code generation, matching local libzstd 1.6.0 headers/runtime. The
retained inputs are Silesia Dickens/Mozilla/MR prefixes and the previously
trained 4096-byte standard dictionary with its 8192-byte reference input.
Two alternating rounds use depth 64, nice length 64 and minimum 3. The 4 KiB
inputs request window 15, and 16 KiB/trained inputs request window 17. Both
checksums and content sizes are enabled. All reports pass the frozen-input,
dictionary, requested-control, raw-round and library/executable identity gate.

Each table cell is `median Vort time / median reference time`, followed by
`Vort encoded bytes / reference encoded bytes`.

| Input | btopt time; size | btultra2 time; size |
| --- | ---: | ---: |
| Dickens 4 KiB | 27.69; 0.9980 | 54.94; 0.9961 |
| Mozilla 4 KiB | 166.70; 0.9851 | 490.11; 0.9698 |
| MR 4 KiB | 39.53; 0.9631 | 70.05; 0.9908 |
| Dickens 16 KiB | 28.77; 1.0048 | 54.90; 1.0058 |
| Mozilla 16 KiB | 80.51; 0.9962 | 190.99; 0.9878 |
| MR 16 KiB | 143.14; 0.9885 | 413.50; 0.9938 |
| Trained input 8 KiB | 58.62; 1.0127 | 141.24; 1.0127 |

The size ratios are close to these reference settings, while HQ encoding still
has a substantial throughput gap. MR 16 KiB btultra2 evaluates 40,546,314
transitions. The dictionary configurations preserve 78/87 actual references
and one parsing pass. Full raw clocks, settings and profiles show the work
behind each observation rather than deriving a general rank from the names
of the strategies.

These two-round observations include recorded background compiler load,
short prefixes and cold allocating contexts, without a separate warmed-run
or memory comparison. They are an exploratory baseline. Next reduce repeated
state-key scans and unnecessary HQ transitions, widen full-file and platform
coverage, and compare ratio/speed/memory together. The complete ten-format
functionality/performance goal remains active.
