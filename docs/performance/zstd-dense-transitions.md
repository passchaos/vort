# Zstd dense sequence transition extraction

The dense FSE/Huffman sequence decoder now extracts its three state-transition
fields together. Their logical LL/ML/OF order and values are unchanged. This
targets the specialized path used by the real reference corpus, rather than
the generic sequence reader whose earlier reservoir trial had limited coverage.

## Algorithm and correctness

The existing decoder prepares one bounded sequence field group. Offset, match
and literal extra bits retain their original reads. For a non-terminal
sequence, the remaining LL/ML/OF fields total at most 27 bits. The new helper
extracts that joined value once and splits it by the three widths. Each width
is at most nine bits, and zero-width transitions remain valid. Ungrouped tails,
the final sequence, FSE tables, repeat offsets, literal decoding, match copying,
state layout and error ordering retain their established behavior.

The permanent scalar oracle compares 174,000 width, offset and value
combinations against the original three reads, including consumed bits and
next states. A separate instrumented decoder compares 20,627,686 actual
sequences with the frozen decoder, checking fields, FSE states, repeat offsets
and remaining bits. The new branch covers 36/48 prefix frames and 58/72
all-scope frames, with 20,616,456 joined transition reads. These counts establish
coverage; ordinary whole-call timing determines adoption.

All 72 Zstd reference frames pass Into/Alloc/reusable/incremental comparisons,
ten truncations and six mutations per frame, N−1 output capacity, complete
contents and output guards. Primitive and public tests run on native Debug/
ReleaseFast, x86 and actual WASI. Final live WASI checks also exercise the
forced dense checked/wildcopy paths and an actual Mozilla 64 KiB frame.

## Independent experiments

The same source epoch also tests three other Zstd changes: predefined tables
initialized through metadata rather than a 12 KiB clear, empty frame optional
state initialized without clearing payload storage, and contiguous FSE symbol
fill followed by grouped spreading. Each preserves tables or inactive-storage
semantics through an independent oracle. A separate Brotli candidate processes
up to four staged 10-bit literal hits per chunk without changing its tables.

The first screen has 864 serial Zstd processes and 432 serial Brotli processes.
The corpus is all twelve Silesia files at 64 KiB, 1 MiB and their actual full
lengths. Empty frame initialization, FSE spreading and Brotli literal chunks
do not meet the overall throughput adoption bar and remain isolated.

## Clean paired follow-up

Four alternating sweeps compare baseline, dense, dense plus metadata, and
fixed libzstd 1.6.0, producing 1,152 serial processes over 72 frames. An earlier
follow-up overlapped a late-notified test-driver compiler; that epoch is saved
as diagnostic only. The clean epoch starts after all other CPU jobs terminate.

Both candidates use the ordinary public Into API. Input loading, output
allocation/free, warm decode, complete output checks and hashing are outside
the timer. Each process checks the complete expected output and guards. Raw
stdout, medians, process intervals and input/wire/source/binary/library hashes
are independently reduced. The CPU is an Intel i7-10700K, logical CPU2, Zig
0.16.0 ReleaseFast, GNU target with `skylake+pku+sgx`.

| Producer level / scope | Dense / baseline time | Dense + metadata / baseline |
| --- | ---: | ---: |
| 3 / 64 KiB | 0.977309 | 0.976399 |
| 3 / 1 MiB | 0.963106 | 0.956596 |
| 3 / full | 0.954197 | 0.952824 |
| 19 / 64 KiB | 0.964236 | 0.962377 |
| 19 / 1 MiB | 0.966390 | 0.968972 |
| 19 / full | 0.946702 | 0.950605 |

Across all cases, dense takes 0.961942 of baseline time. Dense plus metadata
takes 0.961253, only about 0.07% less than dense and with a larger worst-case
ratio. Only the dense transition change is adopted. Its prototype full-file
reduction is 4.6–5.3%; final-source measurements remain separately recorded.
No factors are multiplied across epochs, and these point estimates do not
establish overall performance leadership.

## Final-source results

The adopted source passes the complete native Zstd Debug suite (1,248 tests),
the complete ReleaseFast suite (1,249 tests, including the added drain test),
and 212/212 native/WASI compile checks. The drain contract separately passes
native Debug and actual WASI Debug/ReleaseFast. Focused live WASI helper,
forced dense checked/wildcopy and real Mozilla tests pass, with source hashes
matching live. All 216 shared external frames decode correctly through the
current public APIs, with complete output hashes and guards.

A separate final-source epoch uses the same driver, build options and objects
as its baseline. Four alternating serial sweeps produce 864 processes over
all 72 Zstd reference frames. The independent audit recomputes every median
and summary from raw stdout, checks process intervals and verifies all
input/wire/binary/library hashes.

| Producer / scope | Final / baseline time | Final / libzstd time |
| --- | ---: | ---: |
| 3 / 64k | 0.983104 | 1.728535 |
| 3 / 1m | 0.961102 | 1.722497 |
| 3 / full | 0.950694 | 1.663755 |
| 19 / 64k | 0.957891 | 1.804300 |
| 19 / 1m | 0.964040 | 1.714793 |
| 19 / full | 0.952755 | 1.689781 |

Final-source full-file time falls 4.7–4.9%; the 1 MiB cases fall 3.6–3.9%.
The worst observed case ratio is 1.023427, and the all-case geometric mean is
0.961539. Full-file decoding still takes about 1.66–1.69x reference time.
This final-source epoch supports the adopted claim; its ratios are not
multiplied with the prototype screens. The new extraction helper adds no
heap allocation. A broad decoder heap/RSS ranking was not measured here.

## Small-output streaming contract

An independent regression corrected a test driver that called `finish()` as
soon as compressed input was accepted, before draining `need_output`. The
decoder already supports recoverable `OutputTooSmall` from early `finish()`.
With 4,093-byte input fragments and a reused 4,096-byte output buffer, baseline
and candidate decode all 72 reference frames. Their 132,981 paired steps have
identical status, progress and bytes; complete contents, consumption and guards
pass with zero finish errors. A permanent one-byte-output test verifies early
finish, continued draining and successful final finish. Its 17-byte fixture is
independently decoded by libzstd. This is a clarified and tested driver
contract, not a new decoder feature.

## Evidence and next work

The [evidence package](data/zstd-main-decode-20261101/README.md) retains complete
frozen source, independent overlays, actual process logs, assembly proof,
poison/cursor oracles and rejected experiments. It references the prior
216-wire corpus archive by hash without duplicating its large inputs. Final
live tests, build checks and timing are appended as a distinct source epoch.

The industry-best decoder objective remains open. Specialized sequence and
copy costs, FSE table lifecycle, small frames, dictionary/reusable APIs, memory
and broader CPUs still need work. Brotli's literal chunk trial regresses despite
broad coverage, so its primary context/table dependency chain requires another
design. Known baseline stack/resource limitations remain separately tracked.
