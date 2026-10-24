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

An advertised window is a format bound, not an allocation or search promise.
The low-quality q0/q1 parsers retain fragment-local matching, with a normal
distance bound no larger than 65520 and no cross-block match history. General
non-HQ Large Window encoding retains at most the smaller of the advertised
history and 65535 bytes. Its existing bounded ordinary and optimal parsers
keep their own candidate/search limits.

That retained-history size is not a universal distance ceiling. Legacy ratio
long-distance augmentation can inspect the available history together with
the current input block, and one-shot ratio candidates retain their existing
input-bounded long-distance work. Such copies may exceed 65535 while remaining
within reachable source bytes and the advertised safe format range. The
implementation does not allocate or search a complete 1 GiB window for these
general paths. Opt-in HQ retains its separately documented window/history and
working-budget behavior.

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

Reusable encoding captures overlapping chunk descriptors, source bytes,
dictionary descriptors and metadata before clearing or replacing its output
storage. Borrowed spans that overlap unused output capacity are also captured.
Returned scratch keeps its existing borrowed lifetime. Caller-buffer failures,
allocation failures and stream reset/continuation use the existing progress
and rollback contracts.

Standalone `StoredStreamOptions` adds only the format flag; it does not expose
the planned encoder's total-budget or HQ controls. Its explicit allocator and
caller-buffer/bound APIs remain available. The CLI rejects unsupported stored
controls instead of silently ignoring them.

## Validation

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
