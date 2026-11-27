# Assignment phase public native/WASI contracts

PASS; HEAVY0. Native ReleaseSafe and actual wasm32-wasi ReleaseSafe build/run actualexit0,35/35 each. This is the selected public test plus anonymous import-registration tests, not a full codec acceptance gate.

First attempt0 compiled no codec:default1000 comptime branch quota was exceeded in the test helper classifying context-profile fields. Its complete original SOURCE and failed build stdout/stderr/actualexit1 are preserved. The only subsequent change is @setEvalBranchQuota(20000) in that helper; SOURCE-attempt-1 is an independent full2226-file copy. No production or protocol change occurred.

All four64KiB Mozilla/Xray/NCI/XML old-grouped/new-tile public wires equal independent saved gold and decode exactly. Four repeated allocating pairs after other inputs preserve full bytes. q4/q6/q10/q11-cap8, ratio, window10/16/22, metadata,4096-byte repetitive and opaque callers compare complete public old/new wires and decode. These are repeated allocating calls, not a warmed caller-owned context.

Profile comparison ignores *_ns fields and compares all recorded event semantics, complete context details, assignment contexts/comparisons/rounds, proposal tree/mode/savings shapes and scorer counts. Old three class counters are0; new narrow+wide+light equals assignment_contexts on every detail. Actual proposal-cache hits retain zero scorer work. Mozilla narrow38984 and Xray27468, each3 proposal-cache hits; NCI16760/XML21520, each2 hits, on both targets. q4/q6 small profile rows have0 narrow; q10/q11 have34192/45480. No fresh-builder timing or throughput claim is made.

| Target/corpus | Old = new peak | Old = new attempts | Old = new cumulative allocated/freed |
| --- | ---: | ---: | ---: |
| native/mozilla | 5115910 | 681 | 30505144 |
| native/xray | 8168439 | 978 | 55586279 |
| wasi/mozilla | 4430770 | 688 | 26033300 |
| wasi/xray | 7398019 | 993 | 48103594 |

Both memory screens pass before caps/OOM samples. Every successful allocation request length, attempt count, cumulative bytes, forced-moving-growth refusals and whole-operation requested peak is identical. Independent allocator/profile peaks agree; all operations finish live0/active0/allocated==freed. Requested heap excludes stack, RSS and allocator/backing-page metadata. No heap is introduced by the assignment kernel.

Per target, two exactpeak successes preserve full gold; two peakminus1 calls return WorkingMemoryLimitExceeded without induced backing OOM, then succeed after unlimited retry. Three distinct observed allocation sites per corpus receive controlled backing OutOfMemory and successful unlimited retry:Native Mozilla0/395/680,Xray0/669/977; WASI Mozilla0/402/687,Xray0/678/992. These are actual current-source ordinals selected from first/peak/final requests, not copied historical N. No681/688 full sweep was repeated.

Native failure stacks and exact caller return addresses are retained. Xray977 stack identifies bit_writer.appendZeroByte and adaptive split wire emission; peak sites identify feedback planning. No unsupported exact header/transfer label is asserted. WASI caller return addresses are0 and no native source-stack phase is inferred from them. The source assertions show cleanup and exact retry; physical host memory exhaustion is not claimed.

Reused native/WASI record objects match their original hashes and all three current non-stdlib transitive record source files. Zig0.16.0,Native x86_64-linux-gnu skylake+pku+sgx ReleaseSafe,CPU9; WASI ReleaseSafe single-threaded,Node WASI _start,no preopens.16MiB WASI stack is a test-harness setting only. Full argv/cwd/stdout/stderr and actual terminal exits,source maps,ELF/WASM/runner identities are retained.

Entry files:summary.json,identity.json,source-verification.json,test-harness-quota-fix.diff,attempt-0/native-build.*,attempt-1/{native,wasi}-{build,run}.*,SOURCE/,SOURCE-attempt-1/. Both frozen source copies and all seven current selected sources match after validation.

Only src/br/encoder/assignment/phase_public_tests.zig was edited by this worker. Root/module/old tests were not edited; no commit/push. Root owns final-current full-library gates and the separately declared performance preflight/pilot.

Completed UTC:2026-11-27T01:29:53.889094+00:00.
