# decmpfs fixtures

`ditto-type8-200k-a.rsrc.b64` is the Base64 representation of
`golden_big_rsrc.bin` from the `go-apfs` compatibility corpus at commit
`ace1def7bf1963f1f0a471726f0b91ec508dec80`. That corpus records it as a real
macOS `ditto` type-8 resource fork for a 200,000-byte file containing only
ASCII `A` bytes.

The decoded resource fork is 1,554 bytes and has SHA-256
`824b033f7781885f5fd7af619dada3f7528e9c8286a678b302a46cf8ad7ad553`.
Vort keeps the resource bytes only; the corresponding 16-byte `decmpfs` xattr
header is constructed explicitly by tests and differential tooling.
