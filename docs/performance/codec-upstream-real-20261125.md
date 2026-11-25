# Additional full-file upstream codec conformance, 2026-11-25

Scope: clean Vort `bb9e56ef`, Zig 0.16.0 ReleaseFast. These runs check
conformance, not performance or complete coverage of any upstream API. The
inputs are entire files from the public Silesia corpus, not truncated prefixes.
They extend the [previous receipt](codec-upstream-real-20261124.md) with four
more files and a separate wide Brotli run.

| File | Plaintext bytes | SHA-256 |
| --- | ---: | --- |
| x-ray | 8,474,240 | `7de9fce1405dc44ae5e6813ed21cd5751e761bd4265655a005d39b9685d1c9ad` |
| nci | 33,553,445 | `fc63a31770947b8c2062d3b19ca94c00485a232bb91b502021948fee983e1635` |
| samba | 21,606,400 | `93ba07bc44d8267789c1d911992f40b089ffa2140b4a160fac11ccae9a40e7b2` |
| reymont | 6,627,202 | `0eac0114a3dfe6e2ee1f345a0f79d653cb26c3bc9f0ed79238af4933422b7578` |

## Flushed upstream streams

System libz 1.2.11, local libzstd 1.6.0 (`01b7154f`), and local libbrotli
1.2.0 (`558fc64`) produce and consume their respective reference wires. The
reference encoders flush every 64 KiB. All 20 complete wires pass the upstream
and Vort one-shot/exact-size checks. Both incremental schedules agree on all
40 complete runs and all 40 final-byte cuts; no published prefix differs from
the known plaintext.

```sh
corpus="$HOME/Work/corpora/silesia-20261025/files"
LD_LIBRARY_PATH="$HOME/Work/brotli/build-vort:$HOME/Work/zstd/lib" \
  zig build -j4 -Doptimize=ReleaseFast run-codec-differential-fuzz -- \
  --real-limit=67108864 --real-file="$corpus/x-ray" --real-file="$corpus/nci" \
  --real-file="$corpus/samba" --real-file="$corpus/reymont"
```

## Standard wide Brotli streams

Libbrotli 1.2.0 produces standard `lgwin=22`, quality-6 frames without forced
flushes. All three complete wires and both incremental schedules pass, and
all six final-byte cuts are rejected with the correct published prefix. The
contiguous, joined, direct-chunk and short-read source preflight routes pass;
source staging publishes the same plaintext without rereading the source.
These routes report zero requested codec heap, not zero caller workspace.

| File | Farthest distance | Compressed meta-blocks | Wire SHA-256 |
| --- | ---: | ---: | --- |
| reymont | 4,194,203 | 1 | `aeb194fe46e065aa4e63ea9ec1f7cc7ae59c4af1f8d0670a6bb62452f05bc000` |
| x-ray | 2,597,806 | 3 | `22cc70a5b39ed41d15b613a021d471fdcfec145821bcc524e6f98eb86e7bd010` |
| nci | 4,194,249 | 4 | `cb5253055b501855ccf1d76f9d049fa4ead9905f1741121a477dd79dae46b1e5` |

The legacy fixed-history preflight reports an unsupported feature on `reymont`
and `nci`. Caller-history preflight succeeds on both; the legacy contract
remains unchanged. `x-ray` succeeds on both routes, so a wide copy alone does
not imply that a stream needs the extra preflight context history.

```sh
LD_LIBRARY_PATH="$HOME/Work/brotli/build-vort" \
  zig build -j4 -Doptimize=ReleaseFast run-codec-differential-fuzz -- \
  --real-brotli-wide --real-limit=67108864 --real-file="$corpus/reymont" \
  --real-file="$corpus/x-ray" --real-file="$corpus/nci"
```

## Remaining workflow gaps checked separately

Libbrotli 1.2.0 generated a valid 42-byte Large Window stream at quality 6
and `lgwin=25`, independently decoded with its Large Window opt-in. Vort's
library already accepted it with the equivalent option, but the baseline
CLI rejected it and offered no decode opt-in. `test-br-large-window-decode-cli`
retains the fixture and distinguishes explicit opt-in from default rejection.

GNU gzip 1.10 has a separate `--rsyncable` encoding workflow not exposed by
the audited Vort baseline. This is not a wire-decode difference. For the first
4 MiB of `nci` with `VORT_RSYNCPROBE` inserted at byte 4096, `gzip -n -6`
and local rsync 3.2.7 with `-I --no-whole-file --stats` produced 359,973
literal bytes transferred. Adding `--rsyncable` reduced that to 4,079 bytes,
with edited compressed size changing from 418,073 to 434,579 bytes. Both
streams decode exactly with GNU gzip. These reference workflow measurements
are not a Vort throughput or compression-ratio comparison.

## Larger-file recheck after workspace and lifecycle changes

On clean `6270d488`, Zig 0.16.0 ReleaseFast and the same local upstream
libraries produced 15 flushed wires from the following complete files.
Both incremental schedules passed all 30 complete runs and all 30 final-byte
truncation checks. The `mozilla` input alone is 51,220,480 bytes. This checks
wire and stream contracts, not throughput or library-wide feature parity.

| File | Plaintext bytes | SHA-256 |
| --- | ---: | --- |
| mozilla | 51,220,480 | `657fc3764b0c75ac9de9623125705831ebbfbe08fed248df73bc2dc66e2a963b` |
| dickens | 10,192,446 | `b24c37886142e11d0ee687db6ab06f936207aa7f2ea1fd1d9a36763c7a507e6a` |
| xml | 5,345,280 | `0e82e54e695c1938e4193448022543845b33020c8be6bf3bf3ead2224903e08c` |

```sh
corpus="$HOME/Work/corpora/silesia-20261025/files"
LD_LIBRARY_PATH="$HOME/Work/brotli/build-vort:$HOME/Work/zstd/lib" \
  zig build -j4 -Doptimize=ReleaseFast run-codec-differential-fuzz -- \
  --real-limit=67108864 --real-file="$corpus/mozilla" \
  --real-file="$corpus/dickens" --real-file="$corpus/xml"
```
