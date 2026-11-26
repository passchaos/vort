# Literal-model public regression fixtures

These are independent CF/C2 full-wire gold and raw 65,536-byte inputs copied
from the frozen data set under
`/tmp/vort-br-global-entropy-bound-ab.lf41tsx3/benchmark/`.
The copy verified every size and SHA256 against `fixtures.json`; no encoder,
decoder, compiler or timing process ran during fixture preparation.

| Corpus | Raw SHA256 | Gold bytes | Gold SHA256 |
| --- | --- | ---: | --- |
| Mozilla | `b0050240663f54371d372303eeaba0a59ab0758bcd565f4f639d06561e6bc996` | 13924 | `29686649968e0dadd3dec91675d545298aa37fbbb58c00e3b6277881f9a6d2eb` |
| Xray | `b5a07146616bcd7c2d10071d41e07d204de0ac629c4ca37d8e867ff00574d0d8` | 41180 | `53c68176c0cb8c2ffd1759afa6f786fc277750d1108fe12037c822e0d19df288` |
| NCI | `b01b411ac3b5ce2fbf37242c0c59d2d236d2f7039937c1b1a0f18f4cc02549fe` | 4206 | `5e82ff1682e22f8b9e9bbe0f06f49e43b6679bcc736f691a24261295a1d13615` |
| XML | `e32aff2bebf00105a17dd57f5490c1986d17543cee837b42eb56b3e0e6f8e7f1` | 4407 | `e6446e2083669a87277a22328ceae0f3a3b4e227129c401c10bde2f110d28658` |

Frozen `policy-frozen.json` identifies clean CF baseline
`cf442dee0144f4c0cc1823474f77c7e8b1685f2e`, public quality 8 / generic /
explicit standard window16. Its `README.md` and preflight receipts bind the
saved CF/C2 gold to complete byte equality and prior libbrotli 1.2.0 decoding.
Raw identities also point to the retained
`/tmp/vort-current-decode-matrix-20261111/fixtures/{name}.65536.plain` corpus.
Only these raw/gold bytes were copied; no source files, rejected local-pilot
implementation or historical timing samples enter the tests.

`public_tests.zig` hashes both embedded inputs and gold, compares reuse-disabled
and reuse-enabled complete public wires against the independent gold, and
requires real group/hit activation on Mozilla or Xray. NCI/XML are full-wire
controls without a fabricated zero-hit assumption.

Large Window scope checks compare complete wires and excluded groups; the
standard-only test decoder does not claim a Large Window round trip. The
single-byte RAW prefix control cannot match its nonzero ASCII input and does
not claim dictionary-match coverage. Owner capacity and OOM contracts remain
in the dedicated model unit tests.

The writer's primary variant matrix contains 162 complete wire/stats/model
oracles: 126 zero-history fresh-frame round trips and 36 nonzero seeded-history
private-writer configurations. The latter retain all literal-model and pure-bit
checks; a stream prefix does not serialize their required preceding context.
One diagnostic compares uncached/cached standard decoding of an identical
seeded-history wire, separately from the 126 valid fresh-frame decodes. Extra
prepared-state, reverse-cold-header, scope and public tests are outside these
primary-matrix counts.
