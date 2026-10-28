# Zstd repeat-key verification on large blocks and a trained dictionary

The retained three-word comparison in `8bfcd26f` also preserves output on
64/128 KiB real data and a genuinely trained standard dictionary. Baseline is
`b04a9019`; the two native runner sources differ only in repeat-key comparison.
The [evidence package](data/zstd-large-trained-20261028/) includes input/wire
bytes, profile results, exact commands, source and binary identities, training
parameters and reproducible runner source.

This is one balanced exploratory CPU-4 round on Intel i7-10700K, Zig 0.16.0
LLVM ReleaseFast and Skylake code generation. The earlier full-library RF
compiler remained active throughout. Ordinary allocating encode is timed;
input/dictionary construction, output free, decode, hashing and the subsequent
independent profiled encode are outside its interval. Requested window log is
17. File block maximum matches the 64/128 KiB size; the dictionary case uses
16 KiB blocks. No running process was restarted when a large call took longer
than the earlier small-input screen limit.

| File | Size | btopt candidate/baseline time | btultra2 candidate/baseline time |
| --- | ---: | ---: | ---: |
| Dickens | 64 KiB | 0.6506 | 0.5919 |
| Dickens | 128 KiB | 0.6299 | 0.5563 |
| Mozilla | 64 KiB | 0.3357 | 0.2762 |
| Mozilla | 128 KiB | 0.3124 | 0.2677 |
| MR | 64 KiB | 0.3623 | 0.2514 |
| Trained dictionary input | 8 KiB | 0.4472 | 0.3478 |

Mozilla 128 KiB btultra2 changes from 56.337 s to 15.079 s. These long calls
completed normally. All 24 ordinary encodes, 48 native decodes and complete
profile comparisons pass; complete wire bytes agree for every configuration.
The broad improvement remains an observation on this bounded matrix and
background load, rather than a general compressor or competitor ranking.

The dictionary was trained by local libzstd 1.6.0 `ZDICT_trainFromBuffer` on
192 actual 1 KiB samples from Dickens, Mozilla and MR (196,608 sample bytes),
with 4096-byte dictionary capacity. The retained 4096-byte standard dictionary
is parsed through `initFromStandardDictionary`, including its entropy tables,
ID and initial repcodes. The 8 KiB input concatenates eight source samples;
both encoders use the same borrowed dictionary. btopt reports 78 actual
dictionary sequences and btultra2 reports 87. Their two wires differ by strategy
but each remains identical across baseline/candidate and decodes with the
trained dictionary.

## First-slot insertion experiment: withdrawn

A separate candidate checks the first row entry before the general duplicate
scan. For a finite equal-key first entry, the old implementation replaces only
slot zero and performs no sorting; direct update/rejection is therefore exact.
If that entry does not match, scanning from slot one preserves the remainder
of the original loop. The sentinel guard and every tie rule are unchanged, and
the proof does not require sorted input rows.

Frozen-oracle Debug tests and two AB/BA rounds preserve all wires and profiles:
72 ordinary encodes and 144 decodes pass across twelve synthetic configurations
and six Silesia 4 KiB configurations. However, periodic 4 KiB btopt/btultra2
time ratios regress to 1.0670/1.0415 relative to the retained three-word version.
Mozilla also regresses in both rounds. Insert code grows from 577 to 811 bytes.
This shortcut is archived and excluded from production. Further changes to
insertion should target measured work rather than assume redundant source
comparisons imply a better ordinary encoder.

Next compare the retained HQ encoder with matched libzstd settings, expand
trained-dictionary/large-block corpus coverage, and reduce transition pricing
or match-search cost while preserving documented admission semantics. The
full deflate/zstd/brotli/lz4/xz/zip/rar/tar/bzip2/snappy goal remains active.
