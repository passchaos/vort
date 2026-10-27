# Brotli large-window writer stack in WebAssembly

The public Debug WebAssembly gate previously trapped while writing a Large
Window HQ final block. `encodeCommandPlanWithLargeWindowWrite` forced both its
adaptive and ordinary implementations into one frame, although a call uses
only one implementation. The fix gives each specialization a separate
`noinline` body and keeps the dispatcher small. API, allocation policy, tree
planning and serialization remain the same.

The failure reproduces on baseline commit
`718558333bd1bab3202c461f56d8d02762def614`, before the fused suffix bounds change.
All 1,469 tracked source files in the baseline snapshot were checked against
that commit. The candidate snapshot differs only in `src/br.zig`.

Both snapshots ran the unchanged `test-br-public-wasm` gate with Zig 0.16.0,
`wasm32-wasi`, Debug, Node v26.10.0 and the original **8,388,608-byte stack**.
Compilation and execution used CPU affinity `0,1,3-9,11-15`. The baseline
completed with exit code 1; the candidate completed with exit code 0, including
HQ round trips, total memory quotas, whole-block parsing and complete-length
search and budget assertions.

## Actual stack evidence

Sizes below come from the compiled Wasm functions' stack-pointer subtraction,
not estimates from Zig type sizes.

| Function frame | Baseline bytes | Candidate bytes |
| --- | ---: | ---: |
| Parent `encodeCommandPlanWithOptionsWrite` | 2,156,336 | 2,156,336 |
| Large-window dispatcher | 5,656,208 | 384 |
| Adaptive large-window body | Included in dispatcher | 3,425,600 |
| Ordinary large-window body | Included in dispatcher | 2,230,288 |

The HQ ordinary branch's parent/dispatcher/body frames therefore fall from
7,812,544 to 4,387,008 bytes. Other callers also consume stack, so these sums
are not complete chain peaks.

A separate diagnostic exposes the existing mutable stack global without
changing its value, instructions or stack allocation. Running
`brWasmCompleteLengthsSmoke` on the baseline starts at 8,388,608 and traps at
**−466,528** (unsigned 4,294,500,768), confirming stack underflow. The candidate
returns 0 and restores the pointer to 8,388,608. The full passing gate runs the
unmodified candidate Wasm; the extra export is used only for diagnosis.

## Native validation and reproduction

The candidate also completed `test-br-large-window` and the filtered
`Brotli HQ complete lengths actual public wire` test in ReleaseFast, both with
exit code 0. A separate native harness compared baseline and candidate output
bytes for 32 cases: qualities 10/11, standard/Large Window, bounded/whole-block
parsing, sampled/complete lengths, and two inputs. Every stream matched.

From each source snapshot, run:

```sh
taskset -c 0,1,3-9,11-15 zig build -j3 test-br-public-wasm --verbose
taskset -c 0,1,3-9,11-15 zig build -j3 test-br-large-window -Doptimize=ReleaseFast
taskset -c 0,1,3-9,11-15 zig build -j2 test-br -Doptimize=ReleaseFast \
  -Dbr-test-filter='Brotli HQ complete lengths actual public wire'
```

The [evidence directory](data/brotli-large-writer-stack-20261028/) contains full
gate logs, explicit completion codes, source and Wasm hashes, the source patch,
the wire-parity harness and frame JSON. `wasm_stack_frames.py INPUT.wasm`
extracts frame sizes from this Zig build's prologues.
`export_stack_global.py INPUT.wasm PROBE.wasm` exposes the sole mutable i32
stack global for `node stack-trace.js PROBE.wasm`; the script rejects a
different global layout.

This evidence isolates the frame fix from the simultaneous suffix optimization.
It establishes the existing gate's correctness and stack regression; it makes
no throughput claim and does not measure a general maximum stack requirement.

The final combined worktree (fused suffix `3c5e3cb6` plus this writer patch)
also completes the unchanged 8 MiB public Wasm Debug gate with exit code 0.
`current-combined.json` retains its source hashes and explicit completion,
alongside the 210-step `check check-wasm` and actual CLI-help results. The
combined Wasm log is separate from the isolated baseline/fix experiment.
After remote rebase, the same source hashes pass the focused Debug search
tests (79/79) and full native/Wasm compile checks in 213 successful steps.
`post-rebase-final.log.xz` retains the final combined gate output.
