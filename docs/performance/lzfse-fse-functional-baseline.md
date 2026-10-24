# LZFSE FSE writer functional baseline

Date: 2026-10-23. Zig 0.16.0, Linux x86-64, ReleaseFast library probe. Apple
reference: `e634ca58b4821d9f3d560cdc6df5dec02ffc93fd`. This report records real
V1/V2 compressed-block interoperability, deterministic bytes, size observations
and resource/error behavior. It does not claim Apple throughput, memory or
compression-quality leadership.

```sh
zig build run-lzfse-fse-diff -Doptimize=ReleaseFast -- \
  --lzfse /path/to/apple/lzfse --reference-dir /path/to/apple/source \
  --report /tmp/lzfse-fse.json
zig build run-lzfse-cli-diff -- --lzfse /path/to/apple/lzfse
zig build run-lzfse-diff -- --lzfse /path/to/apple/lzfse
```

The dedicated matrix contains 264 cases: 222 public encodes, 28 direct V1/V2
plans, eight limit/caller-output cases and six allocation-failure campaigns.
Vort and Apple independently decode every valid result. It produces 80 V1 and
141 V2 blocks; public encoding emits 189 FSE blocks, including 79 selected by
auto/default policy. Sixty-five V2-to-V1 conversions preserve payload bytes and
decode through both implementations. Reference-encoded files additionally
decode through Vort. The source and input/output hashes are retained.

Coverage includes literal lane tails, all L/M/D value-width endpoints,
single-symbol zero-byte literal payloads, repeated-distance zero, maximum
2359-byte matches, actual 262139-byte distance and cross-block history. A
count-limited corpus has three FSE blocks with exactly 40000 literals each.
Another public case emits one FSE block with 120000 decoded bytes and 51
records, proving that the writer has no artificial 32 KiB FSE limit. Plans
stop at the format's literal/record caps and report the exact consumed prefix.

Selected generated-family observations with a 64 KiB maximum block span are:

| Family | Input bytes | LZVN strategy | V2 auto | V2 FSE strategy |
| --- | ---: | ---: | ---: | ---: |
| text | 268000 | 2444 | 918 | 925 |
| JSON | 465016 | 111509 | 47221 | 47221 |
| source | 219600 | 1970 | 762 | 762 |
| zeros | 100000 | 792 | 340 | 340 |
| random | 200000 | 200036 | 200036 | 200036 |

Seven retained families have a smaller FSE representation than their LZVN
representation. These are internal strategy observations on generated inputs,
not a balanced standard-corpus or competing-encoder benchmark. The policies
compare full serialized blocks over the same candidate prefix. If a
count-limited FSE prefix loses, the writer keeps the original requested legacy
block, avoiding unnecessary raw/LZVN fragmentation. Changed FSE boundaries
mean there is no universal whole-stream ordering between auto and LZVN.

The codec tests verify normalization support/sums, every frequency code 0...1024,
header fields, all padding lengths, reverse states and full value ranges. Public
tests independently decode emitted L/M/D records to check Summary ownership;
rejected candidates are excluded. They cover every strategy/version, legacy
LZVN bytes, `use_lzvn=false` stored behavior, the original encodeInto argument
order, exact output/working limits and complete OOM cleanup. The differential
allocation campaigns inject 51 failures and retain caller data.

The CLI matrix passes 53 cases: 24 successful encodes, 29 protected failures and
22 same-input/output-path cases. Flags, precise limits and errors preserve
existing destinations, and atomic replacement cleans temporary files even when
the destination is a nonempty directory. Every successful CLI wire matches
the public probe and decodes through Vort and Apple. The existing CLI
differential additionally covers 24 self cases, five reference encodes,
24 external decodes, 44 V1 cases and six malformed streams, with 38 actual
Vort-generated FSE blocks.

Apple's CLI treats a zero-byte decode result as failure and repeatedly grows
its output buffer, so it rejects valid empty streams. A small status wrapper
links the unmodified Apple static library and verifies status, EOS and complete
input consumption for the 12-byte empty Vort stream. Nonempty cases continue
through the official CLI. This reference limitation is recorded rather than
changing the library or skipping native empty-stream validation.

The matcher has fixed `8 * 2^hash_log` bucket storage (256 KiB by default), a
bounded borrowed history suffix and one count-bounded Plan. The working budget
counts dynamic Plan/header/payload/candidate/returned-stream bytes; caller input,
stack tables and allocator bookkeeping are excluded. Broad RSS, reusable-state,
streaming and throughput comparisons remain open.

Exact evidence is in [the FSE JSON](data/lzfse-fse-x86-20261023.json) and
[the CLI JSON](data/lzfse-cli-fse-x86-20261023.json).
