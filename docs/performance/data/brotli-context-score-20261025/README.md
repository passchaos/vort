# Brotli context scoring evidence, 2026-10-25

The shared exact-score cache candidate was rejected as a default speed
optimization. Candidate and restored-runtime artifacts must be interpreted
with their own source/executable identities.

- `candidate-source/`: the three changed candidate codec modules, saved before
  restoration, with SHA-256 manifest.
- `candidate-source-parent/`: changed diagnostic/QA files from the candidate
  epoch. Its manifest also hashes the original candidate `src/br.zig`; that
  2.46 MB duplicate is intentionally omitted from this checked-in package.
  The corresponding Git base plus recorded diff/source identities and full
  source snapshots remain the source binding.
- `baseline14/`, `public14/`, `profile14/`, `paired14/`: old/candidate ordinary
  and observed q8 rounds. Five rounds per frozen 64KiB input and three
  alternating version process pairs; requested competitor-file identities
  and compiler observations retained. `analysis.json` and `analyze.py` bind
  comparisons to exactly fourteen unique inputs and five rounds.
- `decision.json`: no positive public speed benefit, withdrawal decision.
- `cache-review.md`, `diagnostic-review.md`, `experiment-assessment.md`,
  `elf-review.*`, `elf-evidence/`: candidate safety, counting and ELF evidence.
- `context-debug/` and `context-releasefast/`: initial QA assumption failure.
  `context-*-fixed/`/`context-x86/` correct that failure by replaying actual
  allocations. These are candidate tests, not restored-runtime executions.
- `tool-build/`: both candidates compile successfully, but diagnostic-only
  flags forwarded to the public benchmark cause `UnknownArgument`.
  `public-build-smoke/` is the separate passing public smoke.
- `legacy-profile-gates/`: old whole-source read fails `StreamTooLong`.
  `legacy-profile-gates-fixed/`: fixed bounded source reading compiles, but
  missing `zig-out` directory prevents CSV creation. After directory creation,
  `legacy-profile-gates-final/` passes. These attempts are retained rather
  than rewritten as successful runs.
- `br-family/`: codec execution passes 1421 with one skip. Its broad source
  sentinel detects the three independently edited legacy tool files while
  all codec/build files stay fixed; `source-scope-audit.json` distinguishes
  that tool epoch change from codec failure.
- `restored-*`, `restored-review.md`, `restored-static-verification.json`,
  `restored-elf-review.*`: final ordinary per-mode cluster cache/direct
  baseline and suffix policy, separate verification and source bindings.
- `restored-public14/`, `restored-profile14/`, `restored-paired14/`:
  ordinary, actual diagnostic and supplemental version pairs for the final
  restored runtime. Candidate ratios are not substituted for these results.
- `post-rebase/`: final handoff checks, independent of candidate timings.

Profile nested times are not additive and include observer overhead. Scope/
mode hit categories can overlap. A cache hit is not proof of new work avoided
relative to the old policy. ABI size and local stack reservations are not
whole stack, requested heap or RSS. Reference-file hashes bind requested files,
not all loader dependencies or every platform/quality setting.

No corpus data, executable or object files are included. Source/command, input
identity, output identity and raw results are retained as textual artifacts.
