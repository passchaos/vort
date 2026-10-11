# LZMS fixtures

`lzms-small.bin.b64` was compressed from `lzms-small.txt` with wimlib commit
`cd5e231c348c255ae5088873b5a66ee0eb96fa07`, compression type LZMS, and level
50. The decoded payload is 695 bytes with SHA-256
`45d26bf8dc7eb183b106bccc03b928e711871ba48b4b2b9bc327eb5219ea58d8`;
the 200-byte raw block has SHA-256
`ce55f33e830fe3065239bf382d08a68e686807fc0d189244f28eace17bcf3377`.

The block is stored as base64 so repository transport remains text-only.
