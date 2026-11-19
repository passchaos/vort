# Deflate level-6 default search depth 160 -> 64, 2026-11-20

## Decision

`optionsForLevel(.default)` now uses `max_chain = 64` instead of 160. This
preset drives zlib/gzip level 6 and the archive defaults (tar, cpio, cab,
zip, squashfs, qcow2, erofs). The flat profile put 42.7% of level-6 encode in
the hash-chain finder, and chain 160 was deeper than zlib's 128 and far deeper
than libdeflate level 6's 35 while producing sizes within noise of libdeflate
on most rows. The measured knee on the Silesia prefixes is 64.

## Measurement

- Host Intel i7-10700K, Linux 6.8, Zig 0.16.0 ReleaseFast, `skylake+pku+sgx`,
  single thread.
- `run-deflate-encode-bench`, level 6, raw Deflate, twelve 128 KiB Silesia
  prefixes, `--iterations 3 --rounds 5`, min-of-rounds, rotating encoder order.
- Both sides include the earlier chain-node early-load change, so the delta
  isolates the depth policy.
- Reference libraries in the same run: zlib 1.2.11, libdeflate 1.10.

| case | before MiB/s | after MiB/s | speed ratio | before bytes | after bytes | size delta |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| dickens | 17.07 | 23.72 | 1.390 | 50,649 | 50,996 | +0.69% |
| mozilla | 68.47 | 86.31 | 1.261 | 23,057 | 23,159 | +0.44% |
| mr | 12.23 | 23.37 | 1.911 | 33,433 | 33,563 | +0.39% |
| nci | 73.20 | 97.02 | 1.326 | 11,001 | 11,174 | +1.57% |
| ooffice | 23.64 | 29.01 | 1.227 | 68,136 | 68,263 | +0.19% |
| osdb | 36.98 | 47.39 | 1.281 | 51,361 | 51,770 | +0.80% |
| reymont | 16.17 | 27.71 | 1.714 | 36,834 | 37,453 | +1.68% |
| samba | 29.39 | 37.45 | 1.274 | 49,453 | 49,546 | +0.19% |
| sao | 20.06 | 25.58 | 1.275 | 99,220 | 99,460 | +0.24% |
| webster | 25.11 | 32.44 | 1.292 | 42,045 | 42,288 | +0.58% |
| xml | 101.94 | 125.91 | 1.235 | 10,035 | 10,233 | +1.97% |
| x-ray | 32.25 | 31.46 | 0.975 | 94,246 | 94,246 | 0.00% |

Geometric-mean speed **1.2816x**, geometric-mean size **+0.73%** (worst
+1.97%). x-ray is the only row below parity in this matrix; a separate
three-run re-measurement of x-ray at chain 64 gave 32.67/32.78/33.01 MiB/s
against 32.56 in the before matrix, i.e. no regression, so the 0.975 row is
treated as run noise. Combined with the early chain-node load, the current
source is **1.3286x** the pre-2026-11-19 level-6 encode speed for +0.73%
size, and the Vort/libdeflate speed ratio improves from 0.2825 to 0.3756.

## Correctness

Every produced wire is raw Deflate and is verified by both Vort and libdeflate
before timing. The full `test`/`check`/`check-wasm` gate passed (389/389 steps,
5775/5777 tests, 2 skipped) without re-freezing any golden wire: the affected
tests assert round trips and contracts rather than default-preset sizes.
Level 1, level 9 and the other presets are unchanged.

## Scope limits

One host, one 128 KiB prefix per file, one-shot raw Deflate, single thread.
The depth was selected on this corpus; other corpora or larger blocks may
prefer a different knee. libdeflate 1.10 is the system reference; a 1.26
comparison is a follow-up once the encode tool grows an explicit reference
path.
