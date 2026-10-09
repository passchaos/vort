# 7z interoperability fixtures

`7zip-bcj2.7z.hex` is a byte-for-byte hex representation of a deterministic
archive emitted by 7-Zip 21.07 with `BCJ2 + LZMA2`, an uncompressed Next Header,
and timestamps disabled. Its SHA-256 is
`da76842e672a8382dd903ea25fb4b9b8a38a1d61dc865f54303288924e0b93ae`.

The archive contains `code.bin` (9,216 bytes), whose MD5 is
`2f299cef81f2f837cbcd62726befc2e2`. The payload repeats representative CALL,
JUMP, and conditional-JUMP instructions so all three BCJ2 side streams and the
range-coded decision stream are exercised.
