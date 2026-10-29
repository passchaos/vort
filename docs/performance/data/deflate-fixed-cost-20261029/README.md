# DEFLATE fixed-cost evidence

- `deflate-size-pairs.tar.xz` retains 72 baseline/candidate pairs covering
  three 64 KiB inputs, eight encoder modes and three alternating cycles.
- `zstd-proxy-pairs.tar.xz` retains 24 baseline/candidate benchmark invocations
  covering three 128 KiB inputs and four alternating cycles. Each JSON record
  includes input, executable/reference provenance, wire size/hash and raw time.

The separately compiled baseline is commit `2fd40c47`; the candidate includes
only the uncommitted fixed-cost correction described in
`../../deflate-fixed-emission-cost.md`. Binary identities and commands are
recorded in `identities.txt` and `commands.txt`.

Archive SHA-256 values:

- `deflate-size-pairs.tar.xz`:
  `7a95ca978081fbaaa6006a445f7b83a41d6f4e3f01bf3fc619d05c2bd479c905`
- `zstd-proxy-pairs.tar.xz`:
  `f6ef2909c2526aa35e556f52be5b2d6e9ab79baf77cb1fe6ae824d2d6140d42f`
