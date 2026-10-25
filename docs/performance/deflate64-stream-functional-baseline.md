# Deflate64 incremental compressed encoding baseline

Date: 2026-10-25. Baseline: `0cf32f1f`. The long-term goal of industry-best
functionality and performance remains incomplete.

ZIP method 9 incremental writing previously routed through the stored-only
Deflate64 encoder. This increment adds a library-owned compressed incremental
encoder and routes the ZIP adapter through it. Caller input/output is resumable,
matching covers the full Deflate64 distance/length range, and owned working
storage stays bounded rather than staging a complete member.

## Public encoder and wire behavior

`deflate64.IncrementalEncoder` / `Deflate64IncrementalEncoder` expose lazy
`init`, `initWithOptions` and `initExactSize`, `step`, flush/finish/reset methods,
`failedProgress`, `snapshot` and `deinit`. Initial state allocates nothing.
The former `IncrementalStoredEncoder` remains intact. One-shot APIs also retain
previous behavior: fixed/stored planning with matches at most258 and distances
at most65535. They are not silently widened by this increment.

New defaults are `.adaptive`, block_len128KiB, max_chain128 and nice_length65538.
Explicit `.fixed` or `.stored` strategies select the format. Block sizes1...128KiB
bound retained input. All variants preserve continuous bit packing and a64KiB
history across blocks. A block filled exactly to its limit waits for more input,
flush or finish to determine BFINAL, keeping byte selection independent of caller
chunk sizes.

A cohesive block-local matcher owns32768 hash heads and65536 previous links,
using u32 indexes and usize match length/distance. Its coordinates cover retained
history plus one current block (at most196608 bytes), avoiding cumulative stream
positions in matching arithmetic. Search precedes insertion at the current
position, preserving the ring slot for distance65536. Planning and emission
rebuild/replay the same matcher rather than retaining an unbounded token list.

Lengths3...65538 and distances1...65536 use the actual Deflate64 wire. Length258
uses symbol284 with extra31. Extended lengths use symbol285 plus16 extra bits;
65538 carries65535. Distance65536 uses symbol31 plus14 bits with16383.
The new stream's stored alternative splits each admitted block into pieces of
at most65535 bytes, while only the last stream block has BFINAL.

Adaptive arbitration compares exact continuous bit costs from the current
0...7-bit offset. Final candidates include last-byte padding; ties retain stored.
Pending capacity admission occurs before block publication. The old one-shot
encoded bound is not used for a differently segmented incremental stream.
Dynamic Huffman and preset dictionaries are not introduced by this encoder.

## Progress, errors and bounded ownership

Options and the entire offered input slice's total-input limit/pledge are checked
before consuming input or draining output. Exceeding the limit therefore reports
zero progress for that offer. Pending output counts complete bytes retained for
one emission event; final padding is included. The non-final residual is at most
seven bits. These contracts do not define an RSS limit.

Step failures are sticky until reset. The first failure stores that call's actual
accepted input and delivered output, including a delivered prefix before later
allocation/capacity failure. Subsequent step/flush/finish calls do not mutate
caller buffers or resume a partially failed encoding event. Explicit reset clears
semantic/failure state and retains owned capacities; resetExactSize changes the
pledge. Diagnostic snapshots report progress/state and do not implement clone
or checkpoint restoration.

Block flush emits the accepted non-final block and preserves history. Partial
flush adds one empty fixed marker. Sync flush adds an empty stored byte boundary.
Full flush clears history at the same sync boundary, including upgrade of an
already-completed sync without duplicate bytes. Finish validates the pledge,
emits BFINAL once and reports done only after pending bytes drain.

Owned buffers are bounded by block size,64KiB history and one pending event.
The hash tables carry393216 payload bytes. The maximum forced-fixed event for
128KiB literal input requires147459 pending bytes; plain/history/index/pending
requested payload bounds total737283 bytes. That derived bound excludes state,
stack, allocator overhead and caller buffers. Smaller settings/reset may retain
capacities from a prior larger valid configuration; requested pending limit
constrains the current event, not automatic shrinking.

A separate bounded-ownership test reuses4KiB input for1024 blocks (4MiB) and
discards only already-delivered wire. After32 warm blocks, all later steps keep
allocation count and live requested bytes unchanged. It checks progress/guards,
retained input/pending bounds, history<=65536, final counts and complete release.
The test does not allocate a complete input/wire collector or measure process
RSS. Existing round trips and independent token parsing provide output coverage.

## ZIP integration

ZIP's Deflate64 options and State now use the compressed incremental encoder,
changing the default from65535-byte stored-only blocks to128KiB adaptive planning.
Existing explicit4096-byte options remain valid. `beginEntry` checks options,
expected-size conversion and input limits before header/metadata publication.
Known/unknown sizes, ZIP32/ZIP64, descriptors and compression-method metadata use
the same archive machinery.

The adapter accounts Deflate64 failure progress. Ordinary, ZipCrypto and WinZip
AES routes encrypt/account only the delivered codec prefix. PKWARE Strong's
bridge accounts accepted input/CRC but does not charge unpublished bridge bytes
as caller ciphertext. The existing ZIP poisoned-state policy stops retries.
Snapshot remains counters, with no newly inferred deep-copy capability.

Seven new ZIP contracts compare known/unknown entries and ZIP32/ZIP64 at one-byte
input/output, check descriptors/CRC/metadata and actual fixed compression, reject
input/pending caps with exact progress, and exercise ZipCrypto, AES128 AE1 and
PKWARE AES128. Encrypted pending failures retain only their actual encryption
header in archive/compressed counts while accepting exactly64 bytes before the
codec failure; the undispatched ciphertext is not charged.

## Independent validation

The complete Deflate64 family passes183/183 in native Debug, native ReleaseFast
and actual32-bit x86 ReleaseFast under stable source. A separate bit-by-bit fixed/
stored inspector reconstructs output, distances and lengths without using the
new matcher/emitter. Actual encoder streams contain distance65536, length65538,
and258 with code284. Empty/tiny/random/repetitive/large inputs, three strategies,
input/output quotas0/1/5, chunk-independent wire, block/partial/sync/full flush,
cross-block history, reset, pledge/cap and selected real allocation failures pass.
Explicit stored mode with65535-byte blocks matches the unchanged stored API.

The complete ReleaseFast ZIP/codec suite passes1988/1988 and final build
checks pass176/176 under stable complete source snapshots. Its first run passed
1987/1988: the lone old test still expected stored-only output from method9.
Selecting explicit `.stored` preserves that test's original purpose, with all
production behavior unchanged. The successful full rerun is recorded separately.

ZIP's focused suite passes41/41 on native Debug and x86 ReleaseFast, including
seven new method9 contracts. Initial errors are retained: a module/type `Error`
alias ambiguity was fixed by qualified type names, a test runtime placeholder
needed explicit u32, and resetExactSize test calls were corrected to its single
size parameter. These did not alter coding algorithms. One earlier x86 ZIP run
had stable codec/test sources but a build-route addition during its broad runner
snapshot; the source-scope audit records that change, and the final x86 run has
a fully stable snapshot.

`run-deflate64-stream-diff` builds an explicit fixture tool using the public
library. Seven deterministic cases produce28 raw/ZIP artifacts per target from
one-byte and mixed quotas, including zero-output offers. All boundary artifacts
come from the actual encoder, not hand-authored token streams. An independent
Python parser verifies fixed/stored/dynamic token geometry, complete output,
headers, CRC and descriptors, then UnZip6.00 with USE_DEFLATE64 tests/extracts
full members. Python zipfile is used only for ZIP metadata.

Native and x86 each pass7/7 build/run steps,28 artifacts and42 member content
checks, with58 recorded commands per target. Their source/executable/input/output
identities and UnZip executable/version are retained. One-/mixed-quota wire is
identical. The actual long-length raw stream is6 bytes for65539 repeated bytes;
70003 repeated bytes use10 bytes. A65536-byte random prefix plus its duplicate
produces69098 fixed-coded bytes and an actual65536-distance match. These are
functional fixtures and encoded sizes, not competitor throughput/ratio leadership.

The [evidence package](data/deflate64-stream-20261025/artifact-manifest.json)
records both targets, exact token/cap/ownership contracts,
source snapshots, failed attempts and fixes, ZIP encryption/progress tests,
reference identities and final handoff checks. Broader dynamic planning,
dictionaries, match-parser quality and full speed/ratio/memory comparisons remain
open. The new greedy parser can admit a far-distance three-byte match that costs
more than three low-byte literals; complete adaptive block arbitration remains
correct, while per-token profitability is a future ratio improvement.
