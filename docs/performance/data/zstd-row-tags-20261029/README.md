# Exact row key tags

The measured baseline is `93926461`; the retained implementation is
`85c03b1a`. The baseline's exact source/build members are shared with the
adjacent repeat-screen package, and its identities are rechecked against the
measured revision in this manifest. No compiled native runners/caches are
copied; their actual binary identities and structured commands remain recorded.

`ordinary-screen.tar.xz`, `inputs.tar.xz` and `results.json.xz` freeze the
two-round six-configuration 4 KiB experiment, exact candidate modules, short
property bridge, ordinary runner, code generation, raw profiles and wires.
`large-trained` separately freezes one balanced round on Mozilla 16 KiB and a
trained-dictionary 8 KiB input, including actual input/dictionary bytes and the
unchanged large-input runner. The two epochs are not pooled into one timing
sample. Independent local libzstd decode records cover all 32 wire artifacts.

`final-source-contracts.tar.xz` freezes the retained source and grouped contract
tests, including full frozen old DP/edge/HQ modules. The integrated source adds
comments, width assertions and test registration after timing. Snapshot-native
Debug/ReleaseFast/x86 checks pass 14/14; the registered source-root native/x86
and executed WASI checks pass 15/15. `current-validation.json` records final
terminal commands for these and the focused, ZIP, reference, benchmark and
build gates. The WASI image and its Node runner are retained for direct replay.

The `deferred-sorted-sentinel` directory preserves the independent lower-memory
alternative that skips trailing sentinel checks only on sorted rows. It has
its own 24-wire/full-profile screen and three-target frozen contracts; it was
not combined with the adopted tag index. Reproduction uses the same shared
baseline and its separately archived source diff.

Run this directory's `audit.py` to check archives, source identities, exact
timing calculations, wire/profile agreement, requested heap changes and all
terminal/reference records. To rerun, extract the shared baseline and overlay
the measured candidate or final contracts, rewrite original structured path
arguments and retain the recorded flags, CPU affinity and input identities.
The report documents the extra sixteen requested heap bytes per DP row.
