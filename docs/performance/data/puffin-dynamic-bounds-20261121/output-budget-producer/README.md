# Independent Puffin incremental output budget delta

Base: the frozen empty-distance/count candidate at
/tmp/vort-puffin-empty-distance.6tqeoW, patch SHA256
1ac63a4552aef3ad23bce2c8b4cf537e8881a2e90768d63d7afcd3a566d8812c.
This delta is confined to a new temporary source copy. It does not edit the
base archive/source, main repository, or main-ready directory. Mainline may
integrate independently; no claim is made that current mainline still equals
this older frozen baseline.

Before public root API evidence, 65535-byte stored and fixed-literal blocks,
max_output_len=16:
- a 1024-byte FixedBufferAllocator fails OutOfMemory before the block-end cap.
  Both cases report allocated=freed874 bytes.
- growing heap reaches OutputLimitExceeded only after cumulative320654 bytes
  across17 successful allocations.

After, the same cases return OutputLimitExceeded with either allocator.
Both report allocated=freed389 bytes and3 successful heap allocations.

The builder now checks metadata, length-distance, end and literal-flush output
before appending. Pending literals are included with their1B/3B run header;
the next token is included before flushing pending literals. Literal additions
are checked before buffer growth. Whole-block defensive checks are retained.
This is early rejection by the logical serialized output cap. It is not a
physical allocator cap: metadata scratch and ArrayList growth capacity still
have fixed/allocation overhead, as the389 bytes versus cap16 witness shows.

Error order:
- format errors already parsed retain their original error contract.
- a known upcoming token/literal exceeding the cap returns OutputLimitExceeded
  immediately. Later malformed or trailing input is not parsed to reproduce
  the former late error precedence.

Dedicated source: src/android_ota/puffin_output_budget_tests.zig.
Tests cover stored/fixed exact and one-below caps at all offsets0..7;
literal127/128 header1B/3B boundary; match129/130 token3B/4B boundary;
both boundaries with missing EOB to prove early rejection; large stored/fixed
with cap16 and a1024-byte fixed heap; parsed invalid LEN/NLEN before cap0;
budget-before-trailing precedence; and OOM cleanup/retry using small fixed128.
Prior empty-distance/count/canonical-incomplete Puffin contracts remain intact.

Final same-source tests:
- native:15/15 passed.
- x86-linux-musl:15/15 passed.
- wasm32-wasi through Node WASI runner:15/15 passed.
- zig fmt --check and git apply --check against the frozen baseline passed.

Commands from this directory, with its local/global Zig cache directories:
    zig test src/puffin_focused_tests.zig --test-filter 'Puffin'
    zig test src/puffin_focused_tests.zig --test-filter 'Puffin' -target x86-linux-musl
    zig test src/puffin_focused_tests.zig --test-filter 'Puffin' -target wasm32-wasi -fsingle-threaded --stack 8388608 --test-no-exec -femit-bin=puffin-budget-final.wasm
    node wasi_test_gate.js puffin-output-budget 'Puffin' puffin-budget-final.wasm

puffin-output-budget.patch contains only the builder delta, its dedicated
test file and test entry. baseline/ retains original codec bytes.
before/after/final-probe logs preserve public behavior/allocation metrics.
final-native/final-x86 stderr and final-wasi.json preserve executed gates.
provenance.json records base archive/patch/source identities, candidate source
and patch SHA256, exact commands/targets, error/memory scope and case metrics.
source-before/source-after manifests identify the complete isolated sources.

