# Known sampled ML symbol evidence

The measured baseline is `e654641d`; the retained implementation is
`8819c178`. `baseline-source.tar.xz` freezes source/build inputs, excluding
docs and caches. `ordinary-screen.tar.xz` preserves the exact candidate
helper/edge source, runner, structured compiler commands, generated code,
raw small-input clocks, profiles and wire bytes. `inputs.tar.xz` freezes the
actual three 4 KiB inputs. Compiled native runners are excluded and their
measured SHA-256 identities remain recorded.

`current-hotspots.tar.xz` separately preserves ordinary-only frame-pointer
sampling and exact global IP-period attribution. `snapshot-contracts.tar.xz`
contains the frozen pricing/edge oracles, seven-model test suite, small generic
helper adaptation and actual three-target 7/7 terminal records.

The two larger-input archives are deliberately separate:

- `large-overlap.tar.xz` is the first one-round matrix with observed direct
  CPU-2 compilation overlap; correctness passes but performance is inconclusive.
- `large-followup.tar.xz` reuses those exact binaries in two independent rounds.
  It preserves affinity changes, restoration and an explicit correction:
  process-leader affinity did not prove all later compiler children isolated.
  Background snapshots did not observe high CPU process leaders on CPU 2.

Both include raw profiles, wire bytes, original commands and dictionary/input
identities. The first archive includes actual large inputs and dictionary bytes;
the follow-up commands use those same frozen inputs. Independent libzstd
decode records cover all 60 wire artifacts across the three epochs.

`source-contracts.tar.xz` freezes the retained source/test files; the WASI image
and its Node runner are retained for execution. Final source, terminal and
bidirectional reference records are separate from timing. The documentation
comment addition after reference campaigns is explicitly recorded as such.

Run this directory's `audit.py` to verify archives, source scope, wire/profile
identity, exact timing summaries, raw sample periods, portable contracts and
terminal/reference records. Replay extracts the baseline plus candidate or
final overlay, rewrites structured path arguments and retains flags, affinity,
round order and input identities. The report explains the limits of each epoch.
