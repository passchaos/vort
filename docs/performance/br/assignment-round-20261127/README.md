# Rejected tiled-assignment pilot, 2026-11-27

The candidate is rejected. The first fixed diagnostic pilot completed24 pairs
and48 owning public q8/generic/explicit-window16 processes on CPU2/thread1,
with warm1 and one continuous encode+lengthmix+free interval per process.
The equal12-row paired throughput GM is0.878150548070644; candidate elapsed
GM is1.1387569 times baseline. All12 row point estimates are below0.98.
CI is null; the1.03 target and all row floors fail. No retry, filtering,
formal run, timed controls or historical/reference timed phase followed.
`full_gate_passed=false`: the rejected candidate was never merged and its
full-library test/check/check-wasm gate was not run.

The semantic baseline is committed46d340ac03ab211aa3f745b650e76f0bf530744d.
Its primary ELF963d97be... retains the actual old371b18cb... build identity;
all2,222 Git46d src blobs matched that frozen build snapshot. The new generic
baseline was compiled from actual Git46d src with the same9074b92f... harness
as candidate controls. The rejected candidate contains2,226 source files,
registry SHA11ad3e9985241911513dd94089d1b8f4c8cf2cde3e5dd311caabdacb2e120e1c
and primary ELFda2f2506... . Full SHA values and original literal paths are
retained in the manifests/build receipts; raw files were not rewritten.

`payload/candidate-src.tar.xz` is the complete portable candidate src closure.
`raw/root-rejection/src` keeps all seven changed/added source files visibly,
including phase tests, public tests and the common price-producer test
surface. Root's original candidate.patch and frozen final receipt record
successful `git apply --check` and restoration of src/tools/build to46d.
`raw/baseline-overrides` contains only the four old Git46d files needed to
reconstruct the complete registered baseline source from candidate src.
No duplicate old baseline source tree is stored.

`payload/new-runtime.tar.xz` saves only the new primary ELF, both generic
control ELFs and new record object. Their four build command/exit/stdout/
stderr/source-before/source-after receipts are retained. The original
primary baseline ELF, reference ELF, old object and three libbrotli1.2.0
files remain in the already committed split package. `old-package-link.json`
pins its three parts, joined SHA, Git blob identities and six exact archive
members. Its185,506,284-byte payload is not repeated here.

All84 warm-only preflight outputs and complete initial wires are saved,
including main12×2, public18×2 and small12×2. Baseline/candidate wires and
actual options are equal, with pinned libbrotli1.2.0 external decode
receipts. q10/q11 use the **public default command-state setting255 KiB**;
q11-cap8 is a separate explicit caller. This setting is not a measured
runtime memory allowance, and q8's schedule sentinel is not promoted to
a runtime quota. No caller budget or quality was reduced.

`raw/public-narrow` preserves the first test-harness quota compile failure,
its original source, corrected-source manifests, and final Native/WASI35/35
logs and allocator/requested-stream/selected-site retry observations.
`raw/epoch/seal-attempts.json` separately preserves the incorrect static
32 KiB assertion and its correction from actual options. It caused no codec,
build or sample retry. `raw/independent` keeps Archimedes' frozen verifier and
receipt; it imported no producer and independently recomputed the same
rejection, actual48 exits/order/raw ns, source/ELF bindings and initial wires.

The prospective formal primary would have used only six common rounds on
all12 rows; weak extras would only inform separate row CIs and a disclosed
secondary. That phase was not released or run. The previous split epoch's
all-sample estimator remains its own legitimate predeclared statistic;
this package does not reinterpret old conclusions or multiply epoch ratios.

Run the standalone portable verifier from any location:

```sh
python3 /path/to/assignment-round-20261127/verify.py
```

It checks package SHA bindings, both source closures, all new runtime
artifacts/build receipts, preflight84, the first24/48 pilot schedule and raw
points, Root release, rejection and unreleased phases. It loads no codec,
imports no producer and runs no compiler, benchmark or bootstrap. To also
verify the linked old parts, supply `--old-package /path/to/original-command-split-plans-20261127`.

For manual source restoration, extract candidate-src into a fresh root.
Baseline reconstruction keeps only paths in baseline46d-source-files.json,
replaces the four source-layout.json overrides, and omits candidate-only
files. New runtime members use their original bin/build relative paths.
Old ELF/library replay additionally requires the linked old split package;
raw commands retain their original absolute paths, so relocation requires
path mapping. The independent verifier supports `--map OLD=LOCAL` for this
purpose. This package restores source/bytes and verifies historical results;
it does not promise identical recompilation hashes or timings on another
Zig version, path layout, CPU or host lifecycle.

Only this new package was written. Production and the existing assignment
document remain owned by Root; no codec/build/sample was rerun to create
the archive. No commit was made by the archiving agent.

Package .gitattributes preserves original .plain, .patch and .diff evidence as binary; no raw bytes or original CRLF/context whitespace were rewritten.
