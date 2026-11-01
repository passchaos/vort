# Incremental Brotli: inline the plain history-copy decision

## Hypothesis

After the short-span copy change, a call-graph profile of the incremental
decoder on `samba.64k.q6` attributes 34.61% to `copy_decoder.step`, 20.22% to
`readDistance`, 17.81% to `readCommand`, 8.03% to `memcpy`, 5.88% to
`beginCopy` and 5.42% to `copySpan`. The annotated `beginCopy` is dominated by
its prologue, decoder-field reloads and the `self.phase = .copy` store: it is
an out-of-line call that runs once per command only to classify a distance that
almost always targets the history ring.

`libbrotli` keeps this decision inline in `ProcessCommandsInternal`: it checks
`s->distance_code > s->max_distance`, then either takes the dictionary path or
updates the recent-distance ring and copies immediately.

## Experiment

`tryBeginHistoryCopy` is a small inline helper used by both distance entry
points in the `.distance` phase. It handles the common case when no shared
dictionary is attached and the distance fits the RFC window:

```zig
if (self.shared_dictionary_size != 0) return false;
const distance = self.copy_distance;
if (distance == 0 or distance > self.maxBackwardDistance()) return false;
const remaining = self.decoded_len - self.total_output;
if (distance > self.history.len) return self.fail(.copy, error.InvalidMatch);
if (self.pending_copy > remaining) return self.fail(.copy, error.CorruptFrame);
if (self.update_distance_ring) pushLastDistance(&self.last_distances, distance);
self.update_distance_ring = false;
self.phase = .copy;
return true;
```

The checks mirror `shared_dictionary.classifyDistance` exactly: with
`shared_dictionary_size == 0`, any distance within `max_backward_distance`
classifies as `.history`, and the history arm rejects a distance larger than the
caller's ring and a copy that overruns the meta-block. Compound and static
dictionary targets still fall through to the existing out-of-line `beginCopy`.

## Result

A four-sweep 48-row screen compares the committed decoder (`stream-span4c`)
with the candidate (`stream-hfast`) on the 12 Brotli files at q6/q11 and
64 KiB/1 MiB. Lower is faster.

| Scope | q6 | q11 |
| --- | ---: | ---: |
| 64 KiB | 0.9782 | 0.9853 |
| 1 MiB | 0.9782 | 0.9834 |

Forty-six of 48 rows improve; the worst row is `1.0043` (`nci.64k.q11`) and
the best is `0.9622` (`sao.64k.q6`). The profile share of `beginCopy` drops to
the residual dictionary paths. The complete ReleaseFast Brotli suite passes
1504/1505 with one platform skip, and `zig build -j2 check` exits zero.

## Conclusion

The common incremental copy now takes the same inline shape as upstream:
classify, update the recent-distance ring, set the phase, and copy. Only
dictionary-backed distances keep the out-of-line classifier.

Raw comparison files, records and binaries stay local under
`/tmp/vort-br-lookup-20261101/` (`hfastab-comparison.json`,
`hfastab-raw.json`, `stream-hfast`, `stream-span4c`).
