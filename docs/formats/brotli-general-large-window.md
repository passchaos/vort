# Brotli Large Window outside HQ parsing

`PlannedEncodeOptions.large_window`, `PlannedStreamChunksOptions.large_window`
and `StoredStreamOptions.large_window` explicitly select the Large Window
extension independently of HQ parsing. The planned controls cover q0...q11,
generic/text/font modes and the legacy fast/balanced/ratio levels. Stored,
chunked, reusable and incremental encoding use the same format selection.

True accepts window bits 10...30 and writes the 14-bit extension identity even
when the requested width is at most 24. False retains the established RFC
window validation, defaults and wire. General decoders still require
`allow_large_window = true`; strict default decoding rejects the extension
independently of how small the chosen window is.

## Declared window and actual search

The [large-history increment](../performance/brotli-large-history-functional-baseline.md)
implements explicit Large Window history growth and retains both old ratio and
new history candidates for exact selection. Completed family/build and
test-only adaptive verification are recorded there. The encoder
retains accepted history for non-HQ q2+ and legacy non-fragment paths up to the
advertised distance, growing with actual data rather than preallocating the
complete window30 buffer. q0/q1 remain fragment-local, with no cross-block match
history and a normal distance bound no larger than 65520. Standard-format policy
and its existing ratio augmentation are unchanged.

The shared near matcher keeps its original 65,535-byte suffix and u16 tokens.
A separate history augmenter uses three-byte anchors, matches of 3...258 bytes,
512-candidate chain limits and reachable-band strides of 1/2/4/8/16, creating
wide copy commands. Baseline and literal-only proposals remain available, and
full-wire exact costs select an alternative only when it improves strictly.
This includes q2/q3 inputs with no near copy. The bounded candidate set is not
an exhaustive search or optimality guarantee.

Public non-fragment one-shot q2...q11 and legacy routes also consider wide
copies within the available input, with empty external history. A one-shot
distance above 64 KiB does not prove cross-block history retention; streaming,
chunked and reusable old-block cases are validated separately. Original ratio
candidates remain available for exact comparison. The ordinary q11-over-q10
size guarantee applies to the no-shared-dictionary quality route; the prepared
shared-dictionary pipeline has no blanket version of that guarantee.

The previous completed non-HQ Large Window baseline retained at most 65,535
bytes across blocks; its legacy ratio/current-block augmentation could already
emit greater distances. That older scope remains in dated reports. Opt-in HQ
keeps its separately documented window/history and working-budget behavior.

## Entropy and dictionary behavior

The format is propagated through ordinary and compound/static dictionary
commands, distance-parameter scoring, literal/command/distance entropy
splitting, adaptive blocks and stored fallbacks. The q0...q3 compact writers
use the Large Window distance alphabet and appropriate wire symbol width;
unused compact lengths are padded, and candidates outside that writer's
representable subset use the existing general writer.

Same-last-distance recoding retains exact cache semantics and initializes the
prepared alphabets for the actual format capacity before using them. General
and HQ paths cannot exchange a standard-format candidate with an extension
candidate simply because their decoded bytes match.

Upstream q0/q1 encoders may force a width of at least 18 and, in a nonexperimental
build, may ignore the requested extension. Vort's explicit format request is
checked on Vort's actual wire. Independent reference-generated frames are
decoded using their actual header rather than asserting that the upstream
encoder made the same header choice.

Serialized shared dictionaries have a separate reference-build boundary:
upstream attachment is guarded by `BROTLI_EXPERIMENTAL`. A normal build's
rejection of that type is not proof that a descriptor is malformed. Reference
reports retain the build flag and attachment result and test an experimental
reference when available; RAW attachments are verified independently.

## Ownership and resource contracts

All newly enabled planned candidates use the original
[`max_total_working_memory`](brotli-total-encode-memory.md) allocator authority.
HQ workspace limits remain separate. General paths cannot bypass the existing
total budget while preparing a new format, dictionary or stored fallback.

For the large-history candidate, actual history growth is admitted before wire
publication, followed by an allocation-free prepared append. Adaptive branches
reserve rollback capacity before clearing history storage. All real history
copies, rollback buffers and candidate/matcher allocations remain subject to
the existing quota; one retained-history value does not represent the entire
working set. Metadata and flush preserve match history, while reset/next-stream
start an independent frame. Native Debug/ReleaseFast and x86 ReleaseFast
filtered contracts each pass 27/27, and each native/x86 reference matrix passes
450/450. Final legacy refresh matches 216 main and 120 reset comparisons against
saved old wires, with 336 new streams independently decoded. The complete
native ReleaseFast family at the corrected codec revision reports 1432
passed and one skipped out of 1433; the skipped host-overflow gate passes
separately on x86. Build checks pass 182/182. A later test-only adaptive matrix
passes on all three configurations, including actual greater-than-64-KiB
history, branch growth failures before clear and retry. Its source scope is
distinct from unchanged codec/reference results.

The retained history length is capped by actual accepted data and the window,
but geometric allocation reserves may exceed that length or the logical window
bound. The quota charges actual capacities and simultaneous branch copies,
rather than treating the history length as an exact heap bound.

Reusable encoding captures overlapping chunk descriptors, source bytes,
dictionary descriptors and metadata before clearing or replacing its output
storage. Borrowed spans that overlap unused output capacity are also captured.
Returned scratch keeps its existing borrowed lifetime. Caller-buffer failures,
allocation failures and stream reset/continuation use the existing progress
and rollback contracts.

Standalone `StoredStreamOptions` accepts the format flag and the subsequent
[stored requested-heap controls](brotli-stored-memory.md). Its explicit
allocator and caller-buffer/bound APIs remain available. HQ and compression
policy controls are still inapplicable to stored encoding and are rejected by
the CLI instead of being silently ignored.

## Validation

The commands and reference scope below describe the preceding completed Large
Window format increment. Current large-history results are recorded in the
new functional baseline, without relabeling earlier evidence. The initial
legacy-fast 64 KiB parser failures and their full-hash-planner fix retain
separate source epochs; native/x86 wire/history equality does not imply identical
geometrically allocated capacities or memory profiles.

```sh
zig build test-br-general-large-window -Doptimize=Debug --summary all
zig build test-br-general-large-window -Doptimize=ReleaseFast --summary all
zig build test-br-general-large-window -Dtarget=x86-linux-musl -Doptimize=ReleaseFast --summary all
zig build test-br-general-window-cli -Doptimize=Debug --summary all
```

The reference campaign `run-br-general-large-window-diff` covers both format
identities, all qualities, legacy levels, stored and public ownership models,
dictionaries, metadata and failure behavior. Default comparisons use an
independent pre-change source archive. Search counters, functional checks and
their durations do not establish an industry-wide ratio or throughput result.
