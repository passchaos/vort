# Brotli metadata compatibility evidence

The baseline is `24993ef257e65630cce169ec20e100dfb8534874`; the final codec,
tools and first tests are bound by `codec-source-manifest.json` to
`e49fce241781ec4849672ffae410bbad89c701ab`. Documentation does not refresh
these source or executable identities.

`new-source-manifest.json` binds the final test revision
`b502fc50d81be96dc622ab4ba3998a53403c618c`. `test-source-delta.json` proves the
only change is the legacy wide-resource test's invalid metadata boundary,
updated from 65537 to the actual 16 MiB maximum plus one. Codec/tool files and
the final external source identity remain unchanged. The first full-family
failure is retained with its original source epoch rather than relabeled.

Each `native-final.tar.gz` / `x86-final.tar.gz` preserves all 252 original
campaign files, including bodies, target/reference streams, decoded outputs
and reports. The corresponding `*-files.json` records every original size and
SHA-256 plus the archive SHA-256. Archive compression is evidence packaging,
not a codec benchmark. The `*-differential.json` reports remain available
without extracting the archives. To inspect individual files:

```sh
tar -xzf native-final.tar.gz
tar -xzf x86-final.tar.gz
```

Each final campaign validates 194 public target encodes, 18 native upstream
metadata streams decoded by Vort, 84 over-limit requests rejected before codec
allocation, 10 malformed streams and one recorded reference-version defect.
All 194 target wires, metadata headers and progress records agree across
native/x86 after excluding their actual target/CPU identity and file paths.
The reports retain all 307 commands and full input/output hashes. Actual
16,777,216-byte metadata bodies are encoded and decoded; numeric boundary
tests and manual wire oracles are distinguished from those real files.

The primary reference is the local libbrotli 1.2.0 experimental build. The
explicit encoder/decoder/common paths, actual `dladdr` symbol sources and file
hashes are recorded. System libbrotli 1.0.9 has a reproducible single-byte
metadata encoder defect; its original invalid stream and decoder error are
retained. Its symbol resolution in the same process is recorded and is not
claimed to be an isolated dependency closure. The 1.2.0 native metadata
operation correctly emits that length.

`alias-lifecycle-audit.md` and `alias-source-epochs.json` distinguish the
temporary simultaneous-source QA failure from the later metadata-only Debug
failure. Zig 0.16's `clearRetainingCapacity` invalidated borrowed bytes before
they reached the independent pending buffer. The final implementation protects
the complete output allocation, source chunks/descriptors and metadata before
clear. Snapshot refusal preserves old output/state; later encoding failures
retain the existing API contract. ReleaseFast passes before this fix were
insufficient evidence of alias safety. Failed logs retain their original
source/test epochs and are followed by fixed-source results.

The metadata gate has 30 filtered tests plus 100 public-root tests. These are
130 executions with different import scopes, not 130 independent metadata
cases. Complete family/build results and rebase checks are recorded separately
in `validation.json` and their logs.

Reproduce with Zig 0.16.0, choosing an actual installed reference directory:

```sh
zig build test-br-metadata --summary all
zig build test-br-metadata -Doptimize=ReleaseFast --summary all
zig build test-br-metadata -Dtarget=x86-linux-gnu -Doptimize=ReleaseFast --summary all
zig build test-br -Doptimize=ReleaseFast --summary all
zig build check --summary all
zig build run --summary all -- --help
zig build run-br-metadata-diff -- --directory /tmp/vort-metadata-native \
  --reference-encoder /tmp/vort-br-general-experimental-build/libbrotlienc.so.1.2.0 \
  --reference-decoder /tmp/vort-br-general-experimental-build/libbrotlidec.so.1.2.0 \
  --reference-common /tmp/vort-br-general-experimental-build/libbrotlicommon.so.1.2.0
```

The x86 campaign applies `-Dtarget=x86-linux-gnu` to the same build step; its
Python reference process remains native. Ordinary test/compiler durations and
the size of these archives are not throughput, requested-memory or RSS ranking
evidence. Full metadata emission still owns body-sized pending output.

`legacy-wire-comparison.json` records 384 exact old/new comparisons: 192 per
target, split into 108 existing final-gate rows and 84 supplemental positive
65536-byte metadata cases. The supplement covers Stored and planned
q0/q1/q4/q8/q10/q11, six API routes and standard/Large Window identities.
All comparisons are byte-identical, and both streams in each pair receive an
independent full-content/consumption check. This is the recorded matrix, not a
claim to exhaust every quality, corpus or settings combination. The bridge
probe only substitutes the new maximum constant in the metadata-only harness;
its inverse substitution restores the original probe byte-for-byte. Old/new
source, bridge, compilation and executable identities are separately recorded.
