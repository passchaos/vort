# Frozen modern decode matrix, 2026-11-11

This package preserves the completed current-source comparison against
libdeflate 1.26, Zstd 1.6.0, and Brotli 1.2.0. All three cold comparisons show
Vort taking longer on this development host. Across the 72 cold rows per
codec, the geometric means of paired Vort/reference time ratios are
**1.4570417450 for Deflate, 1.3118790485 for Zstd, and 1.2110972428 for
Brotli**. Values above one mean Vort is slower. The 15 groups in
[`summary.json`](summary.json) are the authoritative per-size and lifecycle
results; `matrix.csv` supplies every row's median batch durations, compressed
size, and whole-child RSS.

The measurements are observations from an i7-10700K development host using
`intel_pstate` with the `powersave` governor and turbo enabled. They do not
establish industry leadership or satisfy a dedicated performance-host
acceptance gate. The fixed-corpus confidence intervals describe uncertainty
in the recorded balanced sampling on this host; they do not include corpus,
host, or power-policy variation.

## Package contents and exact bindings

| File | Contents |
| --- | --- |
| `manifest.json` | Full manifest, including all 2,014 source hashes, 216 fixture metadata records, and 360 tasks; semantically identical to the original, formatted in 2,676 lines. |
| `manifest.json.gz` | Exact original manifest bytes, compressed with a zero gzip timestamp. |
| `summary.json` | Exact completed summary bytes. |
| `matrix.csv.gz` | Exact original CSV bytes, including CRLF line endings, compressed with a zero gzip timestamp. |
| `matrix.csv` | Readable CSV with CRLF converted to LF; every field and row remains identical. |
| `raw-rows.tar.gz` | Exact 360 raw row JSON files, 360 stderr files, and 360 RSS sidecars. No raw sample is dropped. |
| `source-overlay.tar.gz` | Exact eight new `tools/decode/*.zig` and `*.py` files plus `build/decode_compare.zig` and `build.zig`; all ten match the frozen source registry. |
| `probe.tar.gz` | Exact measured `bin/vort-decode-compare` executable. |
| `reference-libraries.tar.gz` | Five exact selected shared libraries, SONAME/development symlinks, and the corresponding upstream licenses under `deflate/`, `zstd/`, and `brotli/`. |
| `reference-build-metadata.tar.gz` | Exact reference provenance JSON, libdeflate/Zstd build logs, CMake caches, compile commands, relevant headers, libdeflate verification script, and Brotli CMake cache. |
| `archive-bindings.json` | SHA-256 for every archived regular-file member, all symlink targets, original build/library paths, upstream license revisions, and exact/readable CSV bindings. |
| `cold-size-ratios.svg` | Scientific plot of the nine cold size groups and their recorded 95% intervals, with line-end spaces removed and XML geometry preserved. |
| `verify.py`, `validation-receipt.json`, `SHA256SUMS` | Independent read-only package validator, recorded validation result, and complete package checksum inventory. |

All tar archives use GNU tar, lexicographically ordered members, uid/gid/mtime
zero, and empty owner names. Gzip has level 9, an empty filename, and mtime
zero. Regular files have mode 0644, selected binaries have mode 0755, and
symlinks have mode 0777. `archive-bindings.json` retains exact member-byte
hashes separately from container hashes.

The codec source base is
`4bca528b36e2c9ac9065826000b3ee66e6c65966`. The frozen current tree's full
source-registry digest is
`79c48dbdf783abd8767cc0767f10a82922d1dbcf243de9fdba7f97ce2291353d`.
The codec files under `src/` were unchanged from that base; the source overlay
adds the measurement harness and its build registration. The measured
ReleaseFast Zig 0.16.0 executable, targeting x86_64 Linux GNU with
`skylake+pku+sgx`, has SHA-256
`eddd7b5deaef84f1dc7fc50cc736cb64e0083b6e02e6a40ae8298c8ccc5bb8ba`.
Each row records that executable hash, its command, selected absolute library
paths, mapped library closure, and CPU affinity.

| Reference | Source revision | Exact selected binary SHA-256 |
| --- | --- | --- |
| libdeflate 1.26 | `92e6a0db9fa848d742f9eb286c92afc60f2c3dda` | `1261b5e2461c0a12995439abea25e042de4f2d899c5f26fb738b023dc2cbff28` |
| Zstd 1.6.0 | `01b7154f1172432f8abe9b3bb9909e14a1176b7d` | `ff67de9643e7cc0ce88265af3a6f4503c09ef107c094186980484751914ac9c8` |
| Brotli 1.2.0 encoder | `558fc647cdaf391228d614ca85f711e02e4e583b` | `916611262bd0975d4b75e6a19d957de5747eb182f2c36022a459bd21b6e40b6d` |
| Brotli 1.2.0 decoder | Same Brotli revision | `916a4e22b249bb9b5024ed6d6956431fbcdea31f0cf157474de36c529a961750` |
| Brotli 1.2.0 common | Same Brotli revision | `d049d028ce0ee836b2f90579b1fba73ac2c8cdde4e2014721eb93c107a399dfb` |

libdeflate and Zstd were built with GCC 11.4.0 and
`-O3 -DNDEBUG -march=skylake`; Brotli used CMake Release with
`-O3 -march=skylake` plus the Release flags. The libdeflate version is declared
from its pinned, hashed header because that library has no runtime version
query. Zstd's version and both Brotli ABI versions were queried. The five
archived libraries are the selected codec references; incidental process
libraries, including the host C runtime, remain documented in each row's
mapped-library list. The original host platform was
`Linux-6.8.0-79-generic-x86_64-with-glibc2.35`.

## Matrix, lifecycle, and timing scope

There are 12 Silesia files, three sizes (first 65,536 bytes, first 1,048,576
bytes, and full input), three codecs, and two producer levels per codec:
Deflate 6/9, Zstd 3/19, and Brotli 6/11. This gives **216 encoded fixtures**.
Each Deflate and Zstd fixture has cold and prepared tasks, while each Brotli
fixture has a cold task, for **360 measured tasks**.

Every task retains two balanced warmup pairs and six balanced measured pairs,
alternating Vort first and reference first. The full matrix retains **720
warmup pairs and 2,160 measured pairs**, with three AB and three BA measured
pairs per row. Each side executes 100 decodes per batch at 64 KiB, 20 at
1 MiB, and one for full inputs. All work runs single threaded in isolated
children pinned to logical CPU 15. CSV durations are **per batch**; decode
throughput uses `input_bytes * iterations / batch_seconds`.

| Codec and lifecycle | Vort API | Reference API | Comparison role |
| --- | --- | --- | --- |
| Deflate cold | `decodeRawDeflate` | allocate + `libdeflate_deflate_decompress_ex` + free each decode | Matched cold |
| Deflate prepared | `decodeRawDeflate` | `libdeflate_deflate_decompress_ex` with retained decompressor | Reference-only prepared; Vort API remains the cold facade |
| Zstd cold | `decodeFrameInto` | `ZSTD_decompress` | Matched cold |
| Zstd prepared | `NativeFrameDecoder.decodeIntoSlice` | `ZSTD_decompressDCtx` with retained DCtx | Matched prepared; priming precedes warmups and measurement |
| Brotli cold | `brDecodeStreamInto` | `BrotliDecoderDecompress` with one-shot state and internal heap per call | Matched cold |

Brotli has no supported prepared-reset comparison here, so no prepared
Brotli rows were measured. Prepared priming, wire generation, file I/O,
library loading, buffer allocation, and post-batch full validation are outside
the timed decoder batches. Internal allocation and state creation performed
by each selected cold API are included.

The probe validates the output byte count on **every decode**, records a
count/first-byte mix for every batch, and checks the **full final output**,
input/wire immutability, and 64-byte guards after every batch, including
warmups. All input, wire, and output buffers have the same 64-byte alignment.
Deflate exposes exact consumed input counts on both sides, checked after
each batch; the selected Zstd and Brotli one-shot APIs do not expose that
count, and their reports explicitly set exact-consumption coverage to false.
The raw rows retain these validation flags and the complete balanced samples.
All 360 recorded stderr files are empty. RSS is `/usr/bin/time`'s peak for the
whole isolated child, including loaded libraries, buffers, validation, and
contexts; it is not codec-only heap usage.

`summary.json` computes equal-weight row means of all six paired log time
ratios, then geometric means across each fixed 24-row size/lifecycle group.
Its 2,000 bootstrap resamples sample within each row and AB/BA order stratum,
preserving the corpus rows and order balance. No minima are selected and
warmups are excluded from the summaries. `matrix.csv`'s individual row time
ratios use the medians of all six side durations, so they are distinct from
the paired-log statistic in the group summaries.

## Reproduce from source and archived references

The package omits raw corpus and encoded wire payloads. The full Silesia
inputs total 211,938,580 bytes. The original frozen directory held 36 plain
files and 216 wires, totaling 619,064,339 bytes. Every input and wire hash,
length, first input byte, and generator setting is retained in the manifest.
Deflate generation used Python's zlib runtime **1.2.11** with raw window
bits -15; Zstd used `ZSTD_compress`; Brotli used `BrotliEncoderCompress` with
window bits 22 and generic mode. Each producer's output was decoded by its
independent reference before timing. A different zlib producer version can
produce a different Deflate wire even when the plain corpus matches.

Start from this repository, use a separate checkout, and set `silesia_dir` to
the 12 uncompressed named corpus files. The preserved probe provides the
exact executable used for this epoch. A reproduction on another host or at
another time creates a fresh measurement epoch with its own host binding.

```sh
decode_archive_dir="$PWD/docs/performance/modern-decode-current-20261111"
decode_repro_root="/tmp/vort-modern-decode-reproduce"
silesia_dir="/path/to/silesia"
mkdir -p "$decode_repro_root/references"
git clone --no-hardlinks . "$decode_repro_root/source"
git -C "$decode_repro_root/source" checkout 4bca528b36e2c9ac9065826000b3ee66e6c65966
tar -xzf "$decode_archive_dir/source-overlay.tar.gz" -C "$decode_repro_root/source"
tar -xzf "$decode_archive_dir/reference-libraries.tar.gz" -C "$decode_repro_root/references"
tar -xzf "$decode_archive_dir/probe.tar.gz" -C "$decode_repro_root"

python3 - "$decode_archive_dir/manifest.json" "$decode_repro_root" <<'PY'
import json
from pathlib import Path
import sys
manifest = json.loads(Path(sys.argv[1]).read_text())
root = Path(sys.argv[2]).resolve()
references = manifest['references']
for codec, reference in references.items():
    roles = ('encoder', 'decoder', 'common') if codec == 'brotli' else ('path',)
    for role in roles:
        reference[role] = str(root / 'references' / codec / Path(reference[role]).name)
    reference.pop('file_sha256', None)  # matrix.py hashes the relocated files.
(root / 'references.json').write_text(json.dumps(references, indent=2) + '\n')
PY

LD_LIBRARY_PATH="$decode_repro_root/references/brotli" \
python3 "$decode_repro_root/source/tools/decode/matrix.py" \
  --references "$decode_repro_root/references.json" \
  --probe "$decode_repro_root/bin/vort-decode-compare" \
  --corpus "$silesia_dir" --out-dir "$decode_repro_root/matrix" \
  --cpu 15 --target-cpu skylake+pku+sgx \
  --sizes 65536,1048576,full --lifecycles cold,prepared \
  --rounds 6 --warmup 2 --bootstrap 2000 \
  --iterations-64k 100 --iterations-1m 20 --iterations-full 1
```

To regenerate and check fixture identity before running timings, add
`--prepare-only` to that matrix command, then check the plain and encoded hashes:

```sh
python3 - "$decode_archive_dir/manifest.json" "$decode_repro_root/matrix/manifest.json" <<'PY'
import json
from pathlib import Path
import sys
def identity(path):
    fixtures = json.loads(Path(path).read_text())['fixtures']
    return {f['key']: (f['input_sha256'], f['encoded_sha256'], f['input_bytes'],
                      f['encoded_bytes'], f['generator']) for f in fixtures}
assert identity(sys.argv[1]) == identity(sys.argv[2]), 'Fixture identity differs'
print('All 216 fixture hashes, lengths, and generator settings match')
PY
```

The matrix command can subsequently resume its new output directory. Its resume contract rejects
source, probe, reference, settings, or host-policy drift. Original absolute
paths remain in the archived records; relocated paths belong to the new
epoch. Do not overwrite the archived manifest to make a resumed run fit.

To rebuild the probe instead, use Zig 0.16.0 in the overlaid source checkout:

```sh
cd "$decode_repro_root/source"
zig build -j2 -Doptimize=ReleaseFast -Dcpu=skylake+pku+sgx build-decode-compare
```

Pass that newly built `zig-out/bin/vort-decode-compare` as `--probe`. Record
its actual SHA-256 in the new epoch; a rebuild at a different absolute path
is not assumed to have the same executable bytes.

## Verify the archive without benchmark execution

```sh
cd "$decode_archive_dir"
sha256sum -c SHA256SUMS
python3 verify.py
```

The independent standard-library validator checks every package checksum,
archive member's byte hash and normalized metadata, all five library hashes
and nine symlinks, source overlay and probe hashes, exact manifest content,
exact original compressed CSV and its LF-only readable equivalent, SVG geometry,
all 360 task identities, warmups/order/counts, recorded validation and mapped
library bindings, RSS sidecars, and CSV fields. It independently reproduces
all 15 paired-log bootstrap summaries and their exact stored intervals.
It reads the preserved evidence; it does not rerun timed decoders.

`validation-receipt.json` also records the packaging-time comparison against
all 2,014 live source files and all 252 unique frozen plain/wire files. To
repeat those optional checks while the original workspace and fixtures exist:

```sh
python3 verify.py \
  --live-root /home/passchaos/project-z/vort \
  --fixture-root /tmp/vort-current-decode-matrix-20261111/fixtures
```

The SHA-256 inventory includes the receipt itself and was frozen after
receipt generation. The normal verification command checks the final
inventory as well as reproducing the receipt's core evidence validation.
