# Zstd skippable payload and pending-limit admission, 2026-11-20

Both public incremental Zstd encoders could accept payload that overlapped
their receiver or writable memory profile, then change those bytes while
constructing the frame. The serial header append could grow pending output and
update the caller memory profile before reading a payload borrowed from that
profile. Four before regressions observed modified payload despite success.

Skippable payload admission now precedes prefix activation, allocator binding,
observer publication and queue locks. It protects complete owned capacity,
receiver/facade state and current exclusive/shared observers. Read-only
dictionary/payload sharing remains supported, and successful calls own their
serialized copy so callers may immediately overwrite their input.

Parallel output retention limits were checked after serializing and committing
the request. A rejected header/payload could leave the encoder busy with output
already queued. New requests now check the full checked `8 + payload.len`
before mutation. Previously accepted output remains resumable when a caller
temporarily lowers and later raises its output limit.

## Validation

The before runner reported 15 passes and five failures: four payload mutation
cases and the pending-limit commit case. Current skippable regressions pass
30/30 runner tests. Prefix lifecycle and step neighbors pass 27/27 and 26/26.
Cases include receiver, complete/spare owned capacity, current/shared observers,
native held-mutex rejection, immutable input sharing, payload release after
copy, fresh/done and magicless/busy boundaries, integer limits, once-prefix
semantics, atomic pending refusal and accepted-output limit recovery.

Serial physical OOM remains directly retryable; parallel OOM remains sticky
with the documented prefix ID synchronization. Pre-admission failures preserve
the facade, allocator, prefix state, caller bytes and profile bytes.

Current combined lifecycle contracts pass 33/33 build steps and 190/190
native/x86 runner tests, with actual WASI execution of all three codec families.
Complete current test-suite/lifecycle WASI compilation passes 14/14 steps.
Current reference interoperability passes all 171 libzstd 1.6.0 cases.

[Raw evidence](data/zstd-skippable-lifecycle-20261120/) retains before/after,
neighbor, architecture, compilation and reference logs. The preceding complete
ReleaseSafe library run binds its earlier source snapshot and passed 5,716
tests with two skipped. This later increment has the current-source validation
scopes above. The overall compression goal remains active.
