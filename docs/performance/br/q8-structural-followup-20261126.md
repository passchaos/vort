# q8 structural follow-up after rejected emission pilots

Status: source and existing-evidence audit; no new encoder adopted or timing
collected. The [historical/current-main comparison](q8-main-history-20261126/README.md)
shows `8ccd54a5 / 0a673757` elapsed 3.20317086x for wire size 0.95658086x.
The [local](counted-distance-local-20261126/README.md) and
[global](final-entropy-bound-20261126/README.md) emission pilots are separately
rejected below the fixed 1.03 target. Their ratios must not be combined.

## Confirmed growth in default work

The following are source-history facts, not measured per-commit attribution.
The public lane remains q8/generic/explicit window16.

| Commit | Change to the existing q8 route |
| --- | --- |
| `cf4e870c` | Enables entropy feedback while retaining max-chain 128, nice-length 192, max-candidates 64 and the 64 KiB optimal ceiling. After seed optimal commands, a feedback model, modeled DP and complete Lazy/context/split candidate group run. |
| `321361bb` | Changes the extra-feedback input gate from `>64 KiB` to `>=64 KiB`. Both model2 and repcode-bonus slots already existed; q8's 64 KiB ceiling previously made this loop unreachable. It now covers all twelve inputs of the direct history matrix. |
| `0a0c605c` | Retains the parameter-only floor and adds `encodeDistanceParameterSearchWithSplitsAllocRecorded`. Forced-recent baseline and an optional parameter alternate each enter complete Lazy/context/split selection. At the sampled endpoint this split chain can run even when the prepared parameter pair emits no output. |

At `8ccd54a5`, `feedback_rounds.runExtra` already shares one input-dependent
candidate scan for the last two independently priced DPs, following
`7b575072`. Do not describe them as two separate scans, or replace their
independent models, costs, commands or strict arbitration with one frontier.
There is no old-source stage profile that apportions the observed 3.20317x
regression among these commits.

## Larger boundary to investigate

The archived 36 current-source traces contain 1,029 complete outputs, 993
losers and 1,746 evaluations. Total outer diagnostic time is 4,378,976,984 ns;
exclusive context proposals are 1,323,801,138 ns (30.23%), optimal parsing
1,000,709,287 ns (22.85%) and wire emission 722,728,845 ns (16.50%). These
fractions route investigation; they are not projected speedups. All event
streams are complete, but eighteen context-detail prefixes are truncated.

The [older ordinary nonrecent preparation prototype](../data/brotli-nonrecent-context-full-20261123/README.md)
already fails its full-operation target and row floors. Repeating that
extension is lower priority than finding repeated model construction across
preferred-context selection and final entropy splitting.

The [pure-data opportunity audit](literal-model-opportunity-20261126/README.md)
replays 417 nonrecent physical outputs over all 36 complete traces, and 238
metadata-matching final literal-build opportunities over the first stored
round of each input. Ten inputs have such slots; NCI/XML have zero and are
controls for added capture/allocation costs. The 238 slots are not verified
cache hits: the event metadata does not retain complete commands or literal
histograms. At most five distinct preferred metadata slots and a largest
tree-count sum of 27 are observed; no memory layout or throughput is measured.

The proposed next slice retains literal alphabets, lengths and normalized
context from one immutable input/command group for reuse by final split
candidates. It must separate these model facts from full prepared State:
header bits, command/distance payload costs, final wire size, temporal literal
splits and same-last recoding depend on additional candidate state. Matching
command counts or profile option fields alone does not prove model identity.
Use the actual input and command identity plus every literal-policy field,
preserve the fallback writer on a miss, and publish only complete models.

Place this owner in `encodeFinalCommandCandidateGroup`, whose preferred and
final-split calls share immutable commands. Do not begin with the earlier
short-match loop: it mutates `command_storage` while reusing its address, so
pointer/length alone would wrongly accept an old model there. Retain at most
the existing context/plain slots and allocate only active trees rather than
embedding five maximum-size prepared States. Whole-operation requested-heap
and exact-cap measurements must determine the accepted resource budget.

Before adoption, prove unchanged candidate order, full wires, accepted stats,
strict ties and excluded-mode routes; run native/WASI, quota and actual OOM
cleanup gates, then a fresh public whole-operation A/B with every applicable
row/control at least 0.98x and target GM at least 1.03x with CI excluding parity.
Reuse must not reduce quality, disable feedback rounds or discard candidates.

An independent later slice may share an immutable four-anchor predecessor
index between the first modeled DP and the existing final paired solve.
`lz77.PreparedOptimal` currently retains a three-byte index; it is not a
drop-in oracle for that four-anchor route. Model-dependent DP state and match
frontiers remain separate. A cached distance-parameter choice is another
smaller boundary, requiring distinct states for unsearched and searched with
no alternate, and unchanged distance-key/split-options projection.
