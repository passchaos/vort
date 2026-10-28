# Literal-tree cache experiments: withdrawn

Experiments against `b6c3f92f` did not establish a stable ordinary-call speed
advantage. Production source was restored unchanged. The
[evidence package](data/brotli-tree-cache-experiments-20261028/) preserves
final source overlays, raw reports, identities and validation artifacts.

The first design folded high FNV fingerprint words into the set index. Sixty-four
fixed-total histograms with frequencies divisible by 32 occupy one original
set and 29 folded sets, but actual q8 cache misses did not improve consistently.
That mapping was withdrawn.

The second design doubled capacity from 128 to 256 entries at the same cache
size and alignment. A 524-byte entry held the complete histogram as u16,
32-bit fingerprint/score and packed rank/mode/valid metadata. Every frequency
was compared after a fingerprint match. Unsupported publication left state
unchanged. Four-way rank LRU was independent of wrapping timestamps. Reference
and out-of-range inputs retained the old cache. Weak small-input points led
to a 32 KiB gate, followed by explicit eight-lane integer conversion/comparison.

| Experiment | 36-prefix candidate/baseline encoding time |
| --- | ---: |
| Scalar, all inputs, one sweep | 0.998280 |
| Scalar, gated, one sweep | 0.996195 |
| Vector, gated, one sweep | 1.000946 |
| Vector, gated, three sweeps | **0.997881** |

The final 4/16/64 KiB ratios are 0.996802/1.000433/0.996412. Short inputs do not
enable the gated path. Small, inconsistent points do not prove statistical
significance or justify retaining the extra codec machinery.

Both versions use Zig 0.16.0 ReleaseFast native `skylake+pku+sgx`, one thread
on CPU 2 of Intel i7-10700K, twelve Silesia 4/16/64 KiB prefixes and matching
q8/generic/actual-lgwin16. Three final sweeps reverse version order on the
middle sweep; each report has five interleaved Vort/reference rounds of three
calls. Per-case medians of fifteen samples produce the geometric ratios.
Timing includes allocation/free. Vort has an untimed primary-round warmup;
reference has none explicitly. The requested Brotli 1.2.0 native GCC reference
is 558fc647, built `-O3 -DNDEBUG -march=native`; loaded objects/dependencies
remain unverified by this tool epoch. All input/wire/settings identities agree.

Correctness passed: native Debug/ReleaseFast and actual scalar/SIMD128 Wasm
cache tests 7/7 including imports, independent LRU/owner/counter/collision and
publication checks, complete capacity and same-size assertions. Context
reference/randomized plus actual 65535/65536 literal-count boundary tests pass
83/83. Public q8 Wasm retains the same 14,362-byte stream and exact Zig/Node
decoding. These checks do not establish a performance benefit.

Final vector/gated source bytes are frozen. Earlier scalar/all-input source
bytes were not separately frozen; raw reports keep their executable identities
and commands, and are not interchangeable with final source. Reproduction
uses base `b6c3f92f`, final overlays, the unchanged six-file ordinary runner,
explicit reference build and preserved scripts. A rerun is a new epoch.

Actual q8 misses fell modestly: Mozilla 1994 to 1932, Dickens 620 to 617 and
MR 913 to 900 over two recorded preferred groups. Conflict counts also include
capacity effects. Next investigate complex-prefix score reuse by code-length
shape, preserving exact scores, bounded storage and public wire comparison.
