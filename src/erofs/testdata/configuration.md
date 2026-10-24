# Configuration distance fixtures

`config-long-distance.bin.b64` contains 8192 xorshift32 bytes (seed
`0x253191a7`, shifts 13/17/5), repeated once for 16384 total bytes.
`config-long-distance.deflate.b64` comes from Python/zlib 1.2.11 raw DEFLATE
level 9. `config-long-distance.microlzma.b64` comes from XZ Utils 5.8.4 through
`tools/microlzma/xz_probe.c` with 32 KiB dictionary and lc/lp/pb 3/0/2.

Both streams refer to data more than 4 KiB back. Native tests require complete
decoding with the normal history, successful prefix decoding before the long
match, and rejection when a 4 KiB declared history cannot satisfy the match.
These tests cover full and partial output and allocation cleanup; small
configuration values are not treated merely as parser metadata.

`tools/erofs/configuration_diff.py` uses the independent dual-codec fixtures
to validate legal small configurations, a cross-block extension and corrupt
length/mask/declaration cases against the original fsck.erofs 1.9.4-g5fcb2f76.
