# Withdrawn prepared-pricing evidence

Both experiments compare against Git revision
`bdae5ce7128e30fee20e20e16612844a818cf1ff`. Their original `/tmp` paths and
commands describe the measured runs. `production_changes` in the original
provenance JSON names the prototype overlay files; neither overlay was
integrated into the production source.

- `baseline-source.tar.xz`: exact Git snapshot of `src`, `build.zig` and
  `build.zig.zon`, shared by both experiments.
- `optional-experiment.tar.xz` and `peeled-experiment.tar.xz`: modified source,
  pricing contract bridge, runner, screen driver, proof, assembly, commands,
  raw run JSON/stdout/stderr and all wire bytes.
- `inputs.tar.xz` and `input-manifest.json`: actual timed input bytes and their
  source identities.
- `optional-results.json.xz` and `peeled-results.json.xz`: complete measurements,
  profiles, validation totals and source/binary identities, also available
  inside their archives. Test terminal records are separately readable.
- `manifest.json`: archive/member hashes, exact baseline source hashes,
  shared object identity/build command and the parent audit.

Run `python3 docs/performance/data/zstd-prepared-pricing-20261028/audit.py`
from the repository to verify archive/source/input identities, paired wires
and complete profiles, raw timing summaries and test terminal records.

To reproduce, extract the shared baseline into two directories, overlay the
chosen experiment's `candidate/src` onto one, and extract its runner and the
inputs. Rewrite the original structured command path arguments to the new
directories. Build the shared Huffman object from
`src/zstd_huffman_x2_object.zig` with Zig 0.16.0, `-OReleaseFast -fllvm
-mcpu=skylake`; the original complete object command is in `manifest.json`.
Compile each runner with the corresponding `-Mzstd=.../src/zstd.zig` and that
object, following the archived `compile-commands.json`. Run the archived
pricing/HQ test commands after rewriting their paths, then execute each
runner with `INPUT OUTPUT btopt|btultra2 none` on CPU 2. The original screen
driver contains the two-round balancing order and comparison logic.

Compiled runner binaries and caches are excluded from these archives; their
actual SHA-256 identities remain recorded. This package preserves a negative
decision and does not claim portable speedup or upstream performance parity.
