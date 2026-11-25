# Gzip rsync edit matrix, 2026-11-25

Scope: Vort codec and CLI at `cd47ad62`, Zig 0.16.0 Debug, native x86-64;
GNU gzip 1.10 (`-n -6 -c`, with and without `--rsyncable`); local rsync
3.2.7 (`-I --no-whole-file --stats`). The Vort comparison uses the library's
plain incremental encoder and `encode-gzip-best-file --rsyncable`, both at the
default level. This is a workflow correctness and byte-count comparison, not
a timing, memory, or compression-level-equivalence claim.

## Reproduce

```sh
corpus="$HOME/Work/corpora/silesia-20261025/files"
tmp=$(mktemp -d)
LC_ALL=C git -c log.showSignature=false log --no-color \
  --format='%H%x09%ct%x09%s' cd47ad62 > "$tmp/vort-changes.log"
zig build run-gzip-rsyncable-diff -- --gnu --report-only \
  --offset 4096 --offset 524288 \
  "$corpus/nci" "$corpus/dickens" "$corpus/samba" "$corpus/x-ray" \
  "$tmp/vort-changes.log"
```

For each source, the tool reads at most 4 MiB and reports its exact digest.
At each offset, it inserts, replaces, or removes 15 bytes. For every encoding
mode and edit, GNU gzip checks the plaintext against the edited input, and rsync
must reconstruct the compressed file byte-for-byte. Literal plus matched rsync
bytes must equal the compressed file size. The Vort CLI and incremental probe
also produce identical rsyncable basis wires with different buffer sizes.

`--report-only` skips the numerical reuse floor on the broad corpus; it does
not skip any correctness check. The single-file `nci` invocation without this
flag still requires the original fivefold reduction at offset 4096 for all
three edits.

## Results

All 30 edit cases and 120 edited wires passed. The [raw rows](rows.txt) retain
source hashes, both wire lengths, and literal byte counts. The ranges below
span all six edits on each source slice.

| Source | Rsyncable literals as % of Vort plain | Vort gzip size increase |
| --- | ---: | ---: |
| Silesia `nci` | 0.62–0.92% | 23.12–23.13% |
| Silesia `dickens` (text) | 0.34–0.81% | 12.19–12.20% |
| Silesia `samba` (tar archive) | 0.40–0.78% | 20.28–20.29% |
| Silesia `x-ray` (binary) | 0.60–1.97% | 3.23–3.24% |
| Vort Git change log | 5.73–90.47% | 4.23% |

Vort transferred fewer literal bytes than GNU rsyncable in 21 of 30 cases,
but its rsyncable gzip was larger in all 30. The `x-ray` replacement at
524,288 is one case where Vort spent more on both: 3,036,476 compressed and
26,252 literal bytes versus GNU's 3,009,354 and 13,002. The change-log
replacement at the same offset was the weakest Vort improvement over plain,
from 17,151 to 15,517 literal bytes, far below the `nci` fivefold threshold.
The next change to the cut policy needs to account for such weak rows, not
just improve the first `nci` insertion.
