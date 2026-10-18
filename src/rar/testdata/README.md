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
