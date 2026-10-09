# 7z interoperability fixtures

`7zip-bcj2.7z.hex` is a byte-for-byte hex representation of a deterministic
archive emitted by 7-Zip 21.07 with `BCJ2 + LZMA2`, an uncompressed Next Header,
and timestamps disabled. Its SHA-256 is
`da76842e672a8382dd903ea25fb4b9b8a38a1d61dc865f54303288924e0b93ae`.

The archive contains `code.bin` (9,216 bytes), whose MD5 is
`2f299cef81f2f837cbcd62726befc2e2`. The payload repeats representative CALL,
JUMP, and conditional-JUMP instructions so all three BCJ2 side streams and the
range-coded decision stream are exercised.

`7zip-aes-data.7z.hex` and `7zip-aes-header.7z.hex` are 7-Zip 21.07 archives
using password `seven-zip-password` and the default cycles power 19. The first
uses Copy + 7zAES with a plain header; the second uses LZMA2 + 7zAES and an
encrypted encoded header. Their SHA-256 values are respectively
`fae5daa35eb318a01fc897f84f19fc6041981e2c2b4bec22e6ced9fc926a3652` and
`320664916899a305deb9e383143592d40d2f16c3b25a317fe4fbf552d6209075`.
Both contain `aes.txt` with bytes `Vort 7z AES fixture\n`, SHA-256
`92209080d9d4ecd4b01115ba8243ecb07062fb0f738327d9e6b17f5dde298da3`.
