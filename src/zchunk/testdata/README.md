# zchunk fixtures

`zchunk-1.1.16-manual.zck.hex` was produced by zchunk 1.1.16 from 1,000
copies of `alpha beta gamma\n` using manual chunking. It has a SHA-256 lead and
body digest, SHA-512/128 chunk digests, an empty dictionary entry, and one Zstd
data chunk. The upstream `zck_read_header --verify` and `unzck` tools validate
the fixture.
