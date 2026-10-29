# Brotli PreparedOptimal screen evidence

This directory records a rejected q10/q11 predecessor-reuse experiment against
clean baseline `235779e4f3f9803944d14a7b9a39ce3e27ed7c6c`.

- `retained-compact.json`: reuse the compact predecessor while retaining all
  fixed-solve workspace.
- `released-compact.json`: retain only the compact predecessor between passes.
- `modeled-compact.json`: also change the independent modeled control to the
  compact predecessor representation.
- `released-native.json`: retain only a native-word predecessor between passes.
- `screen.py`: H/L/R runner and reducer. Its executable paths identify the
  final native epoch; substitute rebuilt paths for replay.
- `candidate-native-overlay.tar.xz`: final native-reuse candidate sources.
- `layout-native-overlay.tar.xz`: identical layout with reuse disabled.
- `summary.json`: condensed ratios and decision.
- `identities.txt`: source, toolchain, CPU and executable identities.
- `validation.txt`: correctness, test and rollback boundary.
- `SHA256SUMS`: integrity manifest for the retained files.

Every epoch used three rotating process sweeps over Dickens, MR and NCI at 16
and 32 KiB, q10/q11, with fifteen timed samples per side and case. All compared
input, wire and settings signatures were identical. Lower ratios are faster.

The overlays are complete replacements for the listed source paths. Extract an
overlay over a clean archive of the baseline, link the sibling `vail` checkout,
build `vort-br-planned-encode-bench` in ReleaseFast, update the three executable
paths in `screen.py`, and rerun on an otherwise idle fixed CPU.
