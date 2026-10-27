# Prepared command/distance Wasm regression

The public q8/generic regression compares the shared-preparation integration
with source commit `d5e8e780f4c28f362c64b152e71988a52351667c` in actual
wasm32-wasi ReleaseFast modules, using the original 8 MiB stack.

Its deterministic 64 KiB mixed fixture contains random high-byte/lowercase
regions and repeated text. Four consecutive records share a span, while group
lengths vary. The successful epoch verifies these actual witnesses:

| Witness | Both modules |
| --- | ---: |
| Decoded commands | 1,299 |
| Active command entries | 88 |
| Complex command trees | 1 |
| Recent copies | 152 |
| Preferred groups with at least two reusable wire candidates | 2 |

These groups cross the production recent-distance gate and the 128-command
boundary. Public header/profile APIs establish the witnesses. Each module
also checks ordinary/profile wire equality, exact Zig decoding, and a Key
offset above `2^32`. Node's native Brotli decoder verifies the complete input.

The baseline and integration emit identical **14,362-byte** wires, SHA-256
`b6eb2991d9848de02c4079a698b23328d122550b2af0dc119326219da6f96762`.
Both module builds and the full-wire gate exited 0. The native fixture exited
0 with 25 passing tests: one substantive fixture and 24 dependency import tests.

The [evidence package](data/brotli-prepared-command-wasm-20261028/) preserves
complete baseline/integration source archives, per-file SHA manifests, frozen
modules, input/wires, source epoch and compressed completion logs. The baseline
receives the diagnostic probe and Key module; its encoder does not import that
module. The record-object source/ABI/helper were identical in both snapshots.

Earlier 8 KiB compile/coverage failures have separately labelled diagnostic
epochs and are excluded from the successful witness counts. Their exact source
snapshots were not retained; the complete successful 64 KiB sources are frozen.

Run `python3 replay.py --output EMPTY_DIR` from the package to replay raw frozen
modules and the CI Brotli-compressed baseline. Add `--rebuild` to restore and
compile both source snapshots plus the native fixture. `SHA256SUMS` verifies
the package. The main `test-br-prepared-command-wasm`/CI entry uses the compressed
baseline. Performance evidence is maintained separately.
