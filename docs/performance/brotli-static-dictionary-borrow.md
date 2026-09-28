# Brotli identity dictionary borrowing

Date: 2026-09-28

## Motivation

The `clustered_q8` reference workload contains 4,255 Brotli static-dictionary
copies producing 30,349 bytes. The address-level transform path previously
copied every selected base word into a 64-byte scratch buffer, even for
transform zero, before the decoder copied the same bytes from scratch into its
output.

Transform zero has no prefix, suffix, omission, or case conversion. Its result
is therefore already represented exactly by the immutable slice in the
embedded RFC 7932 dictionary. `static_dictionary.transform` now returns that
slice directly. All other 120 transforms continue through the existing
materialization path, so their prefix, suffix, omission, and byte-oriented
uppercase semantics are unchanged.

The returned type was already `[]const u8`, and decode callers consume it
immediately with `@memcpy`, so the borrowed slice does not introduce mutable
aliasing or lifetime requirements.

## Correctness evidence

The static-dictionary module test now proves that transform zero returns the
embedded word pointer and leaves the caller's scratch buffer untouched. The
existing representative address-versus-word oracle and exhaustive direct
comparison cover every transform shape:

```sh
zig test src/br/static_dictionary.zig -OReleaseFast
```

All six module tests pass. Broader validation used a local Brotli build
reporting API version 1.2.0:

```sh
python3 tools/br/reference_bench_gate.py \
  --csv /tmp/vort-br-borrow-identity-full.csv \
  --enforce-throughput \
  --executable /tmp/vort-br-reference-borrow-identity
python3 tools/br/real_corpus_diff_smoke.py
DYLD_LIBRARY_PATH=/tmp/vort-brotli-reference.UjgVSa \
  zig build -Doptimize=ReleaseFast run-br-upstream-multiblock-diff -j1
```

The 13-row reference gate and seven manifest-smoke tests pass. The upstream
differential passes 7,056 one-shot cases, 7,056 progressive cases, 99 core
cases, 64 high-tree truncation cases, and the operation-schedule and Large
Window matrices.

## Paired result

The baseline is commit `d1ffc878`. Separate ReleaseFast binaries for the
baseline and candidate were run in alternating order for 15 pairs. Each
`clustered_q8` row records 100 timed decodes selected from the benchmark's five
samples. The source is 1 MiB and the Brotli stream is 52,622 bytes. The target
is aarch64 macOS with Zig 0.16.0 and `target_cpu=apple_m1`; CPU affinity was
unavailable.

| metric | baseline | borrowed identity word |
| --- | ---: | ---: |
| median Vort throughput | 1203.25 MiB/s | 1244.89 MiB/s |
| median Vort/libbrotli ratio | 0.7551x | 0.7834x |
| paired median speedup | 1.0000x | 1.0355x |
| paired geometric-mean speedup | 1.0000x | 1.0366x |
| paired wins | - | 15 / 15 |

The individual paired ratios range from 1.0296x to 1.0463x. A separate full
13-row run measures `clustered_q8` at 1252.00 MiB/s and 0.7835x local
libbrotli. Larger non-dictionary controls remain within 0.4% of their preceding
run, apart from positive movement.

## Rejected alternatives

- Extending the fixed 16-byte match copy to every non-overlapping match gave a
  1.0040x paired median but a 0.9986x geometric mean and only 9/15 wins, so it
  was removed.
- Prepacking all transform prefixes and suffixes replaced short scans with
  extra fixed-width stores and screened at 0.9735x baseline throughput. It was
  removed before the final comparison.

This result is specific to identity-heavy static-dictionary decode. Brotli
leadership remains open; the measured dictionary-heavy case is still about
21.7% below local libbrotli 1.2.0.
