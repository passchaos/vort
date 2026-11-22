# Deflate dynamic Huffman admission candidate

The isolated source rejects both classified deep mutations at dynamic header admission:
sample 14 raw, SHA256 d388f3fc1cd2103712c3066a8e584b6bb1296a4a3d613a26fbb832179193c929,
and sample 13 rich gzip, SHA256 d7fd70975abfe6a278960867051c9a6ff1555889480a25d131a40297fb3bf654.

Before, Vort accepted raw output 127 bytes and gzip output 20505 bytes. After, both fail
InvalidHuffmanCode; original controls still decode to raw 128 bytes and gzip 20505 bytes.
The observer uses caller capacities 4097/82021. System zlib 1.2.11 independently rejects
both mutations as invalid distances set.

Tree evidence in tree-shapes-reference.json identifies:
- raw: complete CODES and LENS; formerly empty DIST becomes one width-7 symbol.
- gzip: complete CODES and LENS; complete DIST widths 1,1 become incomplete widths 1,3.

Production change:
src/deflate/dynamic/admission.zig implements the Deflate-only length-space policy.
It is called before CODES table construction and before LENS/DISTS tables are used by
the shared Huffman Deflate parser, incremental compact helpers, and Deflate64's
independent parser. Existing EOB guards and dynamic count policies stay in place.
Generic Huffman table/encoder builder source is byte-identical to the frozen baseline;
its incomplete-tree capability remains available to other codecs and kernel oracles.
The validator counts all leaves rather than rejecting unused reserved symbol lengths.
Actual empty-distance use and reserved-symbol decoding keep their existing symbol errors.

Dedicated tests cover the two real mutations; CODES/LENS/DIST oversubscription and
incompleteness; legal complete trees, one-bit singleton LENS/DIST, and empty DIST;
one-shot, heap, append-prefix, dictionary, wrapper, direct chunks and Deflate64 paths;
fragmented and semantic-admitted incremental input, sticky errors and exact progress;
caller guards and valid-input capacity/OOM/exact-size behavior.
Incremental shape failures keep their existing InvalidDynamicBlockHeader category.
First malformed dynamic headers write no caller output. Incremental parsing records
the consumed header prefix; subsequent sticky calls consume/write nothing.

Validation:
- final native dedicated filter: 12 passed.
- final x86-linux-musl dedicated filter: 12 passed.
- final wasm32-wasi dedicated filter through copied Node WASI runner: 12 passed.
- existing Deflate dynamic filter: 74 passed.
- existing Deflate64 dynamic filter: 7 passed.
- repaired semantic holes/linear/modes and fuzz fixture/smoke filters: all passed.
- independent zlib: 5 valid synthetic controls accepted with exact output; 10 malformed
  controls rejected at their expected code-tree/symbol class.
- zig fmt --check passed and git apply --check passed against the frozen source.

Commands run from this temporary directory with its local/global Zig caches:
    zig test src/deflate.zig --test-filter 'Deflate dynamic tree admission contracts'
    zig test src/deflate.zig --test-filter 'Deflate dynamic tree admission contracts' -target x86-linux-musl
    zig test src/deflate.zig --test-filter 'Deflate dynamic tree admission contracts' -target wasm32-wasi -fsingle-threaded --stack 8388608 --test-no-exec -femit-bin=dynamic-tree-final.wasm
    node wasi_test_gate.js deflate-dynamic-admission-final 'Deflate dynamic tree admission contracts' dynamic-tree-final.wasm

Old invalid synthetic fixtures are repaired without weakening the gate:
- the shared parser repeat test had CODES four width-3 leaves and LENS widths 3,1;
  both were incomplete. It now uses complete alphabets and asserts repeat17/18 counts.
- the Deflate64 no-EOB fixture first had illegal singleton CODES and then RLE overrun;
  it now has complete CODES and fills the remaining one distance slot directly,
  reaching the actual missing-EOB check.
- the raw missing-distance test had three width-2 LENS leaves; an unused fourth leaf
  keeps it complete so the test still reaches an actual empty-distance symbol error.
- fuzz and semantic fixture changes are described in fixture-repairs-README.md.
  Generic kernel hole oracles retain the original incomplete tables and archived wire.

Artifacts:
dynamic-tree-validation.patch contains only candidate production/test/fixture changes.
baseline/ retains exact original bytes for modified existing files.
samples/ preserves SHA-verified originals, mutations, sources and baseline Vort outputs.
source-before.sha256 is the frozen working-source manifest; source-after.sha256 includes
the candidate and evidence-only observers. provenance.json records manifest/patch/root
SHA256, changed-file digests, compiler, target and generic builder identity.
verification.json and stderr/stdout/exit-code files preserve pass/fail observations.
Initial legacy fixture failures are retained alongside their corrected gate results.

All changes and caches are in this isolated temporary directory. The main source's
2085 original files were rehashed and confirmed unchanged. No main edits, commits,
main builds or full codec campaign were performed.
Android OTA Puffin has a separate format parser and is outside this candidate's scope.

## Later mainline verification

The preceding paragraphs describe the isolated producer epoch. Mainline
subsequently integrated the dynamic admission and differential reporting
changes. `full-final-gate-receipt.json` records terminal exit zero for
`zig build -j2 test check check-wasm --summary all`: 408/408 steps, 5,827 tests
passed and two skipped, with 5,734 root-library passes. All 60 recorded
changed-source hashes matched at terminal. `source-provenance.json` freezes
that uncommitted worktree, including the preserved unrelated LZ77 experiment.

This full execution precedes the independent Puffin repairs. Their current
Debug/ReleaseFast native/x86/WASI, Android OTA and complete-library compile
results have a separate source manifest and receipts in
`../puffin-dynamic-bounds-20261121/`.

