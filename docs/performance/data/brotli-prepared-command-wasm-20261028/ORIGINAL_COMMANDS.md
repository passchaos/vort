# Public prepared command/distance Wasm regression

baseline/src/br.zig is d5e8e780; candidate/src is the frozen integration epoch.
The baseline only receives the diagnostic probe and current prepared Key module.
Its encoder does not import prepared_command_distance.zig. The record object
source/ABI/command-encoding helper are equal between snapshots.

```sh
taskset -c 0,1,3-9,11-15 zig build-obj -OReleaseFast -target wasm32-wasi -Mroot=candidate/src/br/encoder/record_optimal_object.zig -femit-bin=record-wasm.o
taskset -c 0,1,3-9,11-15 zig build-obj -OReleaseFast -Mroot=candidate/src/br/encoder/record_optimal_object.zig -femit-bin=record-native.o
taskset -c 0,1,3-9,11-15 zig test record-native.o -OReleaseFast -Mroot=candidate/src/prepared_wasm_root.zig --test-filter 'Brotli prepared public wasm fixture'
taskset -c 0,1,3-9,11-15 zig build-exe record-wasm.o -fno-entry -rdynamic --stack 8388608 -fsingle-threaded -OReleaseFast -target wasm32-wasi -Mroot=baseline/src/prepared_wasm_root.zig -femit-bin=baseline.wasm
taskset -c 0,1,3-9,11-15 zig build-exe record-wasm.o -fno-entry -rdynamic --stack 8388608 -fsingle-threaded -OReleaseFast -target wasm32-wasi -Mroot=candidate/src/prepared_wasm_root.zig -femit-bin=candidate.wasm
taskset -c 0,1,3-9,11-15 node gate.js baseline.wasm candidate.wasm wires
```

The 64 KiB deterministic mixed fixture has 1299 decoded commands, 88 active
command entries, one complex command tree, 152 recent copies, and two actual
preferred candidate groups with at least two reusable wire configurations.
Ordinary/profile output is byte-identical; Zig exact decode and Node native
Brotli decode reproduce the complete fixture. Both modules verify a Key offset
above 2^32. The complete baseline/candidate wire is 14362 bytes with SHA-256
b6eb2991d9848de02c4079a698b23328d122550b2af0dc119326219da6f96762.
This is correctness evidence, without a throughput claim.
