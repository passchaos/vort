# Optimal LZ77 parser window contracts

The generic optimal parser has two price sources with different window limits.
Fixed-Huffman proxy prices cover distances through 32,768. Caller-supplied
prices can cover the complete u16 token-distance range through 65,535.

| API | Accepted window | Unsupported window result |
| --- | --- | --- |
| `optimalPlanAlloc`, `optimalPlanReuse` | `0...32768` | `InvalidBlockPlan` before allocation or scratch mutation |
| `optimalPlanAllocProfiled`, `optimalPlanReuseProfiled` | `0...32768` | `InvalidBlockPlan` before allocation or scratch mutation; existing profile reset remains |
| `PreparedOptimal.planFixedAlloc` | `0...32768` | `InvalidBlockPlan` before clearing tokens or allocating a returned plan |
| Allocating/reusable/prepared modeled solves | `0...65535` with a valid complete model | `InvalidBlockPlan` for unsupported range or invalid prices |

A zero window is valid and produces literal tokens. A modeled zero window
requires only the unused distance entry zero. For other modeled windows,
`OptimalCostModel.distance` must have at least `window_len + 1` entries;
entries 1 through the window must be nonzero, as must all literal and supported
length prices. Format encoders additionally enforce their own wire-distance
limits.

`PreparedOptimal.init` builds a shared match index and DP workspace before the
caller chooses fixed or modeled pricing. It therefore continues to allow wide
prepared windows used by modeled solves. `planFixedAlloc` checks its narrower
price coverage before touching that workspace. A rejected fixed solve preserves
initialized costs, steps, tokens, buffer addresses, lengths and capacities,
and a subsequent supported solve can reuse the owner. A failing allocator at
request zero still reports `InvalidBlockPlan` for invalid fixed windows.

The common fixed solve rejects its unsupported window before allocating DP or
index storage. Prepared fixed solve performs the same check before clearing
tokens. Both checks use the same internal validation helper. Profile entry
points retain their established profile initialization and clock-read behavior;
the scratch and allocator contract applies to the parser workspace.

Previously, a four-byte match at distance 32,769 could index beyond the
32,769-entry fixed distance-cost table and panic in Debug. Tiny or empty inputs
could accept the same unsupported option because they never reached that
lookup. Rejection is now consistent across input sizes and all fixed entry
points. Internal DEFLATE, Zstd and Brotli fixed-price callers already use or
clamp to supported 32 KiB windows.

## Validation

An independent baseline/candidate module oracle checks 64 invalid calls under
a failing allocator, 30 supported configurations over five fixed APIs
(150 token/stat comparisons), and actual far-distance modeled/prepared plans
at windows 32,769 and 65,535. Native Debug/ReleaseFast, 32-bit x86 Debug and
actual wasm32-wasi ReleaseFast pass the oracle. Library LZ77 Debug/ReleaseFast
suites pass 98/98, and targeted x86/Wasm suites pass 5/5.

A separate public codec comparison verifies 36 complete baseline/candidate
wires: raw DEFLATE levels 8/9, Zstd native/optimal selection and Brotli q10/q11,
over empty, tiny, repetitive, source, structured and low-entropy inputs. All
wires remain byte-identical and decode natively. External Python zlib 1.2.11,
Brotli 1.2.0 and system Zstd 1.4.8 decoders also recover exact plaintext; the
native Brotli/Zstd destinations retain independent guards. Native/Wasm compile
checks complete at 212/212 build steps and CLI help also exits 0. This is behavior and safety
evidence, with no encode-throughput claim.

The frozen source, regression witness, contract logs, public wires and replay
commands are in [`../performance/data/fixed-optimal-window-20261031/`](../performance/data/fixed-optimal-window-20261031/).
