# ZFS compression fixtures

`openzfs-lzjb.bin.b64` is an LZJB block generated directly by OpenZFS
`zfs_lzjb_compress_buf()` at commit
`4542a317e2fa524e24c1c28b6fbca9cd3634ba56`. The 469-byte block expands to
11,700 bytes containing `OpenZFS pinned LZJB payload 0123456789\n` repeated
300 times. Its compressed SHA-256 is
`79c02e33a1ddfbdab53003b99d4ad5484974b87185bf7201c8808dd8e2722665`.
