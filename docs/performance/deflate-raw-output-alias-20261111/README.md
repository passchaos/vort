# Raw Deflate caller-output overlap evidence

This package records the functional repair in
`f74ca1fefd26b35936af94a719ae6bdd9c2c7494`, based on
`6618b0c5833bf48dcc1a3cb99b9cec238f9e67b1`. The
[overview](../deflate-raw-output-alias-20261111.md) describes the contiguous
Raw Deflate contract, reproduced corruption, and coverage limits.

All supplied gates and probe runs completed before packaging. The 72-row
Silesia comparison is a functional compatibility and benchmark executability
smoke with one decode per side, two balanced pairs, and zero warmups. Its
144 paired batches support no throughput or confidence-interval conclusion.

## Exact package contents

| File | Preserved content |
| --- | --- |
| `source-overlay.tar.gz` | Five exact committed files: `src/deflate.zig`, `src/root.zig`, `src/deflate/decoder/output_alias.zig`, `src/deflate/decoder/output_alias_tests.zig`, and `src/tests/deflate_raw_output_alias.zig`. Every hash matches the final smoke. |
| `raw-evidence.tar.gz` | All 25 original logs, original probe README, `probe.zig`, `before-source.sha256`, and exact original `smoke.py`; 29 members. |
| `smoke-rows.tar.gz` | All 72 exact JSON reports and 72 empty stderr files; 144 members. |
| `executables.tar.gz` | Exact `final-probe` and `alias.wasm` binaries. |
| `fixture-manifest.json.gz` | Exact fixture-manifest bytes referenced by the smoke; contains hashes and generator metadata, without raw corpus or wires. Its historical codec timing/source epoch is not the repaired source epoch. |
| `fixture-oracle.json` | Exact five small Raw Deflate fixtures, including dictionary bytes and expected output/consumption, originally checked with Python zlib 1.2.11. |
| `wasm-receipt.json`, `smoke-summary.json` | Exact completed receipts. |
| `gate-summary.json` | Recorded successful gate counts, supplied executor exit codes, log markers, and replay commands. |
| `archive-bindings.json` | Exact archived member hashes, base/fix/source/probe bindings, scenario count derivation, before/after exit codes, and hashes of auxiliary binaries rebuilt from source. |
| `replay-smoke.py` | Portable replay helper using the exact archived probe, five repaired source hashes, pinned reference, and frozen fixture hashes. |
| `verify.py`, `validation-receipt.json`, `SHA256SUMS` | Independent read-only validator, packaging-time validation receipt, and complete checksum inventory including the overview. |

Tar archives use GNU format, sorted members, zero uid/gid/mtime, empty owner
names, and modes 0644 or 0755. Gzip uses level 9, zero timestamp, and no
filename. Logs are archived byte for byte, including any line-ending or panic
formatting. No normalized text derivative replaces an original log.

The exact final probe SHA-256 is
`7e4998d3f19065a1a5b422919b70c64b7c9aa3473ec351263cac696dab8ca6cc`.
The WASI module SHA-256 is
`693543b1572167ac15cda779596a210262579a3ae8481599aada9a6f1173d9e0`.
The before Deflate source SHA-256 is
`c0973bffe09c177339cd0bfa6cc89e6e55b891f462c8f42153303b8d0706ad95`.
The final smoke pins libdeflate 1.26 to SHA-256
`1261b5e2461c0a12995439abea25e042de4f2d899c5f26fb738b023dc2cbff28`;
its source revision, compiler flags, and version-header hash remain in the
exact smoke summary and fixture manifest.

## Verify preserved evidence

From this directory:

```sh
sha256sum -c SHA256SUMS
python3 verify.py
```

The validator checks every package checksum and archive-member hash,
normalized archive metadata, all eight before and eight after outcomes,
complete unchanged backing bytes printed by after probes, gate success text,
the actual recorded WASI exit and binary/receipt binding, five Python zlib
inflates, and all 72 raw smoke rows. It checks sample counts/order, fixture and
reference hashes, reported full-output/count/guard/immutability/consumption
coverage, and the recorded medians. It computes no aggregate timing statistic.

Native historical process exit codes are the completed task executor's
observations; the raw success logs are preserved. The WASI receipt directly
records `execution_started: true` and `actual_exit_code: 0`. The validator
reads those records and does not rerun a gate or timed decoder.

The packaging-time receipt additionally verifies live sources against both
the smoke hashes and the repaired commit, the base source hash, every original
archived artifact byte, and all 108 unique frozen files used by the 72-row smoke
(36 plain inputs and 72 wires). Repeat those optional checks while the original
paths exist:

```sh
python3 verify.py \
  --live-root /home/passchaos/project-z/vort \
  --raw-root /tmp/vort-raw-output-alias-20261111 \
  --fixture-root /tmp/vort-current-decode-matrix-20261111/fixtures
```

## Replay in a separate checkout

Start in the repository. These commands write replay outputs to a separate
directory and preserve the archived evidence:

```sh
alias_archive_dir="$PWD/docs/performance/deflate-raw-output-alias-20261111"
alias_replay_dir="/tmp/vort-raw-output-alias-replay"
mkdir -p "$alias_replay_dir/records" "$alias_replay_dir/references"
git clone --no-hardlinks . "$alias_replay_dir/source"
git -C "$alias_replay_dir/source" checkout f74ca1fefd26b35936af94a719ae6bdd9c2c7494
tar -xzf "$alias_archive_dir/source-overlay.tar.gz" -C "$alias_replay_dir/source"
tar -xzf "$alias_archive_dir/raw-evidence.tar.gz" -C "$alias_replay_dir/records"
tar -xzf "$alias_archive_dir/executables.tar.gz" -C "$alias_replay_dir"
```

For the standalone after cases, use Zig 0.16.0 and the exact archived
`probe.zig`. It prints the independent control, then the alias rejection and
complete backing bytes:

```sh
zig build-exe -O ReleaseSafe --dep deflate \
  "-Mroot=$alias_replay_dir/records/probe.zig" \
  "-Mdeflate=$alias_replay_dir/source/src/deflate.zig" \
  "-femit-bin=$alias_replay_dir/probe-after-safe"
zig build-exe -O ReleaseFast --dep deflate \
  "-Mroot=$alias_replay_dir/records/probe.zig" \
  "-Mdeflate=$alias_replay_dir/source/src/deflate.zig" \
  "-femit-bin=$alias_replay_dir/probe-after-fast"
for alias_case in dictionary stored future-auto future-stored; do
  "$alias_replay_dir/probe-after-safe" "$alias_case"
  "$alias_replay_dir/probe-after-fast" "$alias_case"
done
```

For before reproduction, clone another checkout at base
`6618b0c5833bf48dcc1a3cb99b9cec238f9e67b1`, compile the same probe against
that checkout's `src/deflate.zig`, and run the same four cases in both modes.
The exact original before/after build commands and observed before results
are preserved in `records/README.md`. The ReleaseSafe dictionary and stored
cases terminate with the recorded alias panic; the other before cases return
the incorrect output shown in the overview. Auxiliary standalone probe
binaries are omitted because they can be rebuilt from these two pinned source
commits; their original hashes and sizes remain in `archive-bindings.json`.

Replay native and WASI gates from the repaired checkout:

```sh
cd "$alias_replay_dir/source"
zig test src/deflate.zig -O ReleaseSafe --test-filter 'Deflate raw decode buffer alias contracts'
zig test src/deflate.zig -O Debug --test-filter 'Deflate raw decode buffer alias contracts'
zig test src/deflate.zig -O ReleaseSafe -target x86_64-linux-gnu \
  -mcpu=skylake+pku+sgx --test-filter 'Deflate raw decode buffer alias contracts'
zig build -j2 test --summary all
zig test src/deflate.zig -O ReleaseSafe
zig test src/deflate.zig -O ReleaseSafe -target wasm32-wasi \
  --test-filter 'Deflate raw decode buffer alias contracts' --test-no-exec \
  "-femit-bin=$alias_replay_dir/rebuilt-alias.wasm"
node tools/deflate/clone/wasm_gate.js \
  --output "$alias_replay_dir/replayed-wasm-receipt.json" \
  "$alias_replay_dir/alias.wasm"
```

The last command executes the exact preserved module; substitute the rebuilt
module to exercise the rebuild. Record a new receipt and its actual binary
hash. Rebuilding the full native probe uses:

```sh
zig build -j2 -Doptimize=ReleaseFast -Dcpu=skylake+pku+sgx build-decode-compare --summary all
```

The archived final native probe was Zig 0.16.0 ReleaseFast, x86_64 Linux GNU,
targeting `skylake+pku+sgx`, single threaded and pinned to CPU 15. A rebuilt
binary at another absolute path is not assumed byte-identical. The portable
helper below deliberately requires the exact archived probe for replay.

To replay all 72 frozen wires, reuse the original fixture directory or
regenerate the fixture corpus according to the
[modern decode package](../modern-decode-current-20261111/README.md).
The helper checks all plain and wire hashes before execution. Raw corpus and
wire payloads are not shipped here. The reference archive from that package
contains the exact selected libdeflate:

```sh
tar -xzf "$alias_archive_dir/../modern-decode-current-20261111/reference-libraries.tar.gz" \
  -C "$alias_replay_dir/references"
python3 "$alias_archive_dir/replay-smoke.py" \
  --repo "$alias_replay_dir/source" --probe "$alias_replay_dir/final-probe" \
  --reference "$alias_replay_dir/references/deflate/libdeflate.so.0" \
  --fixture-root /tmp/vort-current-decode-matrix-20261111/fixtures \
  --out-dir "$alias_replay_dir/smoke"
```

The helper writes a fresh `replay-summary.json` and retains every new raw row
and stderr file in an empty output directory. Its CLI and syntax were checked
while packaging; this replay was not executed as a new benchmark campaign.
