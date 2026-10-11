# CHD v5 interoperability fixtures

These fixtures were produced with the static Linux x64 build of MAME
`chdman 0.289`. They are bzip2-compressed and base64-armored so the repository
remains text-only.

- `lzma.chd`, `huff.chd`, and `zstd.chd` contain the same 32 KiB raw payload.
  The eight 4 KiB hunks cover compressed data, incompressible raw fallback,
  all-zero data, and backward self references.
- `parent.chd` is the zlib hard-disk form of that payload and carries `GDDD`
  geometry metadata.
- `child.chd` uses the parent SHA-1 plus aligned parent map entries for all
  hunks and carries the same checksummed geometry metadata.
- `shifted-child.chd` shifts the parent payload by one 512-byte unit. Its first
  seven entries exercise unaligned parent-unit ranges crossing hunk boundaries;
  its final hunk uses zlib for the zero-padded tail.

The decoded payload SHA-256 is
`0dcde7c94a6d08ba49304eb929e45dbf9460e018db91060efd692cd516750824`.
All source CHDs passed `chdman verify`; `chdman extractraw` produced identical
payloads for every codec and for the parent/child pair.
