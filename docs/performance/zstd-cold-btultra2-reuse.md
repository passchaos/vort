# Zstd cold btultra2 evidence reuse

Cold `btultra2` runs two bounded optimal passes: the first gathers statistics,
then the second restarts from the original input and repeat state under refined
entropy prices. This increment gives that exact two-pass path a caller-owned
scratch, a model-independent match-frontier cache and a per-position repeat
match-length cache.

The design follows upstream Zstd's workspace-reuse principle without adopting
its single-state parser. Vort still retains its 16-state repeat-history beam,
checked `u64` prices, complete candidate order, exact offset selectors and
first-versus-refined Plan arbitration.

## Strict routing boundary

Reuse is entered only when all existing cold-warm conditions hold:

- requested strategy is `btultra2`;
- input contains more than eight bytes;
- dictionary/history prefix is empty;
- entropy has not been initialized by an earlier block;
- entropy origin is predefined.

`btopt`, `btultra`, lazy strategies, dictionary/history inputs, initialized
entropy and tiny blocks still call the original `dp.plan` specialization. The
ordinary DP module does not import the new caches or carry a runtime mode
branch. Tests require all new counters to remain zero on those paths.

## Reused and rebuilt state

Both passes reuse allocation capacity for nodes, row tags, literal-prefix
storage, spill state and the tree matcher. The first pass copies each borrowed
matcher frontier into a bounded four-entry-per-position cache. Replay is
allowed only if positions were recorded consecutively through the complete
block; any hole or capacity overflow makes the second pass reset and search
again.

The two passes always rebuild DP nodes, tags, prices, pending literals, repeat
states and the per-position repeat-length cache. Price admission is independent
per pass. First-pass final repeats are never used to seed the refinement.

The frontier uses the existing naturally aligned `tree.Match`, so matcher
layout and code generation remain unchanged outside the cold path. Its fixed
requested heap is:

```text
(positions + 1) * 4 + positions * 4 * sizeof(tree.Match)
= 68 * positions + 4 bytes on x86-64
```

This is included in `requiredWorkingMemory`; exact cap succeeds and cap minus
one fails before allocation. Backing allocator failures propagate rather than
silently disabling the optimization.

## Ordinary A/B

Baseline is clean `8ad5b3ea`. Independent ReleaseFast executables ran on
logical CPU 2 against the same pinned libzstd 1.6.0. Each primary and secondary
case has eight alternating process sweeps and sixteen samples per side.

### 4 KiB primary

| Strategy / input | Candidate / baseline | Paired wins | Requested peak |
| --- | ---: | ---: | ---: |
| btultra2 Dickens | `0.947439` | 8/8 | `4,469,288 -> 4,747,820` |
| btultra2 Mozilla | `0.993807` | 5/8 | `4,469,288 -> 4,747,820` |
| btultra2 MR | `0.949498` | 6/8 | `4,469,288 -> 4,747,820` |
| **btultra2 geomean** | **`0.963346`** | **19/24** | `+278,532` |

The uncertain Mozilla row received fifteen additional alternating pairs:
`0.989001`, with 14/15 paired wins and thirty samples per side.

The unmodified btopt control has zero cache counters, identical requested peak
and a three-row timing geomean of `0.993763`; its maximum row is `1.000484`.

### 16 KiB and dictionary secondary

| Input | Candidate / baseline | Paired wins | Frontier result |
| --- | ---: | ---: | --- |
| Dickens | `0.954945` | 8/8 | replay |
| Mozilla | `0.990484` | 8/8 | complete-record fallback |
| MR | `0.994792` | 6/8 | complete-record fallback |
| **geomean** | **`0.979910`** | **22/24** | mixed |

The candidate peak is `6,205,996` versus `5,091,880` bytes, exactly the fixed
`1,114,116`-byte frontier delta. The trained-dictionary control cannot enter
the cold path: every cache counter and the peak are unchanged, while its time
ratio is `1.006443`.

Every A/B row preserves input, requested settings and complete Vort/reference
wire identity. Non-cache profile fields are unchanged where the original path
is selected. Raw reports, scripts, inputs, source overlay and differential
reports are retained in
[`data/zstd-cold-btultra2-reuse-20261030/`](data/zstd-cold-btultra2-reuse-20261030/).
