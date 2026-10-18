# RAR legacy solid fixtures

`rar15-solid.rar.b64` is the 197-byte `solid_flag_cleared_rar15.rar` fixture
from `rars` 0.9.4. It contains two equal 2,700-byte members and deliberately
relies on the archive-level solid flag while the second file flag is clear.

`rar20-solid.rar.b64` is the 281-byte `rar250/SOLID.RAR` fixture from the same
redistributable test corpus. It contains a 15,840-byte first member and a
13,800-byte solid continuation whose packed payload reuses RAR20 history and
tables.

Both are stored as Base64 so repository diffs remain reviewable. Tests decode
them in memory and pin their existing CRC-32 fields; the external RAR matrix
also compares extraction with 7-Zip/unrar when those tools are available.

`rar15-encrypted.rar.b64` is the 2,129-byte RAR 1.54
`rar154/readme_154_password.rar` fixture from the same corpus. Its packed
RAR15 stream is encrypted with password `password`; the 4,198-byte output is
the corpus `README.md` with SHA-256
`f3d51f2d627fdb20b876e61f9e7772d7b8bf869ca03aeea49d8a9b3153de6eff`.

`rar20-encrypted.rar.b64` is WinRAR 2.02's 254-byte
`rar202/comment_psw.rar`, password `password`. It contains two encrypted RAR20
members, `file1\r\n` and `file2\r\n`. Modern unrar reports three unrelated
legacy-comment header warnings but tests both encrypted members successfully.

`rar15-rar20-mixed-solid.rar.b64` is a deterministic 1,549-byte
RAR15→RAR20→RAR15 solid chain generated with the independent `rars` 0.9.4
literal encoders and standard RAR4 headers. Its four-bit de Bruijn payloads
avoid cross-member matches so the fixture isolates generation switching,
algorithm-private table retention and the shared window/distance boundary.
Unrar 6.21 tests all three members successfully; 7-Zip 26.04 reports a data
error on the RAR20 member because it instantiates separate generation decoders.
