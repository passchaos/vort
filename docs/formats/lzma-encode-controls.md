# LZMA and XZ compression controls

Compression presets select concrete encoder settings. They are independent of
preset content dictionaries. Vort resolves the versioned liblzma 5.8.4 preset
table in Zig; callers can inspect and override the returned configuration.
Parameter parity does not imply identical compressed bytes, compression ratio
or throughput.

```zig
var options = try vort.LzmaEncodeOptions.fromPreset(6, false);
options.size_mode = .known;
options.match_options.?.depth = 96;
const encoded = try vort.encodeLzmaAlloc(allocator, input, options);
defer allocator.free(encoded);

var xz_options = try vort.XzEncodeOptions.fromPreset(9, true);
xz_options.check = .sha256;
xz_options.block_size = 8 * 1024 * 1024;
const xz_frame = try vort.encodeXzAlloc(allocator, input, xz_options);
defer allocator.free(xz_frame);
```

`lzmaResolvePreset(level, extreme)` returns `LzmaCompressionPreset`, including
properties, dictionary size, parse mode and `LzmaMatchOptions`. Levels above 9
are errors. `fromPreset` produces ordinary options; later explicit field
assignments have their ordinary meaning without hidden precedence rules.

All preset properties are lc=3, lp=0, pb=2:

| Level | Dictionary | Mode | Matcher | Nice length | Depth |
| --- | ---: | --- | --- | ---: | ---: |
| 0 | 256 KiB | fast | hc3 | 128 | 4 |
| 1 | 1 MiB | fast | hc4 | 128 | 8 |
| 2 | 2 MiB | fast | hc4 | 273 | 24 |
| 3 | 4 MiB | fast | hc4 | 273 | 48 |
| 4 | 4 MiB | normal | bt4 | 16 | 0 |
| 5 | 8 MiB | normal | bt4 | 32 | 0 |
| 6 | 8 MiB | normal | bt4 | 64 | 0 |
| 7 | 16 MiB | normal | bt4 | 64 | 0 |
| 8 | 32 MiB | normal | bt4 | 64 | 0 |
| 9 | 64 MiB | normal | bt4 | 64 | 0 |

Extreme keeps the dictionary size and selects normal/bt4. Levels 3 and 5 use
nice length 192 and automatic depth; all other extreme levels use nice length
273 and depth 512. Preset 6 is the reference library's default preset. Vort's
existing default options retain their established configuration and output.

## Match search and parsing

`LzmaMatchFinder` selects hc3/hc4 hash chains or bt2/bt3/bt4 binary trees. The
number names the main hash width, not the shortest encodable match. Auxiliary
short hashes retain two-byte and, where applicable, three-byte candidates.
Returned candidates have increasing lengths and one-based byte distances.
Search links use bounded cyclic storage with checked absolute generations;
input length does not require a full-input node array.

`nice_len` accepts 2...273. Its effective value is at least the main hash
width, following liblzma 5.8.4 behavior. It is an early-stop threshold; a found
match may still extend to 273 bytes. The older system liblzma 5.2.5 rejects some
requests below the hash width.

`depth` counts visited main-chain/tree nodes, including candidates with failed
prefix comparisons. Zero selects automatic depth: `4 + effective_nice / 4`
for hash chains and `16 + effective_nice / 2` for binary trees. Auxiliary short
hash probes are separate from this main-search depth. Mode and matcher are
independent; all five matchers support fast and normal parsing.

Fast parsing considers distances, all four repeats and next-position matches.
Greedy selects locally; lazy compares immediate and delayed costs over the
same covered input. Normal parsing
uses a 4096-position cost search derived from current range-coding
probabilities and retains up to eight state/repeat configurations per position.
Probabilities update when the selected tokens are emitted. Both support
ordinary matches of 2...273 bytes and
the special one-byte rep0 form. The existing literal-only, greedy and lazy
modes remain available; default null `match_options` retains legacy behavior.

## Ownership, limits and streaming

Custom encoder dictionary requests cover 4 KiB...64 MiB, sufficient for all
twenty standard/extreme presets. This implementation limit is smaller than
liblzma's full custom encoder range. An advertised container dictionary can
be rounded upward for format compatibility while actual search stays within
the requested history window. LZMA-Alone preserves exact headers for legacy
null match options with narrow dictionaries, including noncanonical requests.
New wide/advanced Alone configurations use a canonical advertised size; ZIP
LZMA properties retain the exact requested value.

`MatchOptions.max_working_memory` limits requested matcher/parser heap. It
defaults to the largest representable value; callers can set a smaller cap.
High dictionary sizes can require substantial search memory. The budget and
`EncodeWorkProfile.peak_working_memory` exclude caller input/dictionary/output
ownership, fixed coding state, OS and allocator bookkeeping. They are not RSS
limits. Checked sizes and allocator failures remain errors; a resource limit
does not silently change parse mode or search settings.

`EncodeWorkProfile` accumulates real matcher probes/comparisons, chain/tree
steps, parser and repetition work, and requested memory peaks until `reset()`.
It includes attempted range coding, failed operations and discarded LZMA2
compressed candidates. Effective nice length, depth and finder describe the
latest validated encoder configuration, including empty input with no search
work. Saturating counters cannot alter encoded output. Each encoding, header
and finish transaction commits model/range/statistics only after success.
A step can accept input, drain pending output or commit earlier transactions
before a later transaction fails. Its snapshot retains that actual progress;
retry drivers use the cumulative input/output differences to resume.

Incremental LZMA1 retains range state, bounded lookahead and requested history;
incremental LZMA2 and XZ preserve properties and search settings across caller
backpressure. Stored LZMA2 fallback retains history and invalidates probability
state, so the next compressed chunk emits the appropriate reset metadata.

XZ blocks are independent. The unchanged default block size is 1 MiB; a larger
dictionary does not establish cross-block history. Configure block size when
longer within-block history is needed. Vort's current LZMA2 writer uses up to
64 KiB plaintext per chunk, while the wire format permits up to 2 MiB in a
compressed chunk. These remain separate compression-quality priorities.

## CLI

Existing encode commands accept named controls after their positional options:

```sh
vort encode-lzma-file input.bin output.lzma --preset=6 --mode=normal
vort encode-xz-file input.bin output.xz --preset=9 --extreme --dict-size=8388608
vort encode-microlzma-file input.bin output.micro --mode=fast --match-finder=hc4 --nice-len=32 --depth=8
```

Named fields override the concrete preset regardless of flag order. The CLI
also accepts `--lc`, `--lp`, `--pb`, `--match-memory` and explicit `--profile`.
Extreme requires a preset. Profile requires an existing preset/matcher option
or fast/normal mode, and preserves that configuration and output bytes.
The MicroLZMA prefix/aligned-prefix commands use the same controls. Scalar
errors are rejected before reading the corpus or opening the destination;
encoded output is published after successful library completion.
