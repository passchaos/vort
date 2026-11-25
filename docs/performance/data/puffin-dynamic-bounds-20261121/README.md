# Puffin structural conversion evidence

This package preserves the independent Puffin follow-up to the Deflate
dynamic-codebook differential campaign. Ordinary inflate validity and Puffin
metadata/token conversion have separate contracts and acceptance results.

## Frozen producer

`producer/` and `puffin-evidence.tar.xz` contain the same immutable isolated
production/test increment, public before/after probes, a Python-generated
expected Puffin fixture, source manifests and pinned AOSP source evidence.
`producer/evidence.sha256` verifies its standalone files;
`producer-archive.sha256` verifies the archive. Mainline files were unchanged
during the producer's runs.

The patch is `producer/puffin-empty-distance.patch` (SHA-256
`1ac63a4552aef3ad23bce2c8b4cf537e8881a2e90768d63d7afcd3a566d8812c`).
Native, x86-linux-musl and actual WASI each pass 14/14 runner tests. The
public original sample transforms to the independently expected 218 bytes
and restores its original 991 meaningful bits / 124 raw bytes. The malformed
320-entry count witness changes from SIGABRT to `InvalidPuffinStream`.

`producer/README.md` lists exact rerun commands and the structural/error
scope. `producer/provenance.json` binds codec/test source digests, targets,
WASI executable identity and the absence of mainline edits. AOSP evidence
uses commit `56246e65146cbf7b736343c95a3e8ed970b9d106`; its scope is source
inspection rather than a binary compatibility run.

## Main-owner maximum-distance extension

`maximum-distance-extension.patch` adds a representable match-first token
with distance 32768 (`0x7fff` encoded). Its source is a separate isolated
copy of the frozen producer; the producer archive is unchanged. The fixture
has an assigned distance symbol 29 plus all 13 extra bits and preserves
Deflate/Puffin wire equality at offsets 0 through 7.

The independent Android OTA root module passes 38/38 tests with this
extension. Its dedicated build gate passes 11/11 steps, 76/76 native/x86
runner tests and 38/38 actual WASI tests. The WASI executable digest and
terminal status are in `maximum-distance-isolated-wasi.json`.

## Stored padding and output quota follow-ups

`padding-audit/` retains 52 hashed artifacts and complete zlib-valid 88/96-bit
fixtures. The SHA-identified existing CLI admitted unrepresentable stored
padding; original-bit-length Huff failed, and a shorter Huff could change
the block type while retaining plaintext. Mainline now refuses values above
31 and preserves representable values in six/seven-bit alignment fields.

`output-budget-producer/` and `puffin-output-budget-evidence.tar.xz` preserve
the separate resource-only delta and its 15/15 tests per target. For identical
65,535-byte stored/fixed blocks at cap 16, FBA1024 changes from `OutOfMemory`
to `OutputLimitExceeded`. Growing-heap cumulative requested bytes/allocations
change from 320,654/17 to 389/3, with every allocation freed. This measures
logical quota refusal and allocation requests, not a physical hard heap cap.

## Integrated source

`mainline-source-provenance.json` freezes the combined code. Debug passes
20/20 build steps and 246/246 native tests (78 Puffin native/x86 plus 168
Android OTA); actual WASI passes 39/39 and the entire library suite compiles.
ReleaseFast passes 11/11 steps, 78/78 native/x86 and 39/39 actual WASI. Separate
logs, terminal receipts and captured Node stdout bind each source/mode and
WASM executable SHA. The pre-Puffin full 408-step/5827-pass/two-skip snapshot
has its own receipt in the neighboring Deflate evidence package.

These are functional results; no throughput samples or leadership claim are
included. The full suite execution belongs to the pre-Puffin snapshot;
post-integration validation is the focused native/x86/WASI matrix, complete
library compilation and broader Android OTA/CLI smoke.
