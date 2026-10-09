# CAB interoperability fixtures

The `libmspack-*.cab.hex` files are byte-for-byte hex representations of public
cabextract fixtures from libmspack commit
`55d501976171397ccd5d5a7a1ca7da065b1d9a06`:

- `cabextract/test/cabs/simple.cab`, SHA-256
  `590791307b407a6ec6d885542952b7eb6575defde68e06d25bac4f41a9b634fd`;
- `cabextract/test/cabs/mixed.cab`, SHA-256
  `0ce0b55fe705b744d41bb361170c0467db30da0c7f9bdd386d5dade71a78e171`;
- `cabextract/test/cabs/large-files-cab.cab`, SHA-256
  `7137966abdffca1c3cfcf4119bc5a6d2f91f2e546e98f3a2ee013f9aa33b93df`;
- `cabextract/test/bugs/lzx-main-tree-no-lengths.cab`, SHA-256
  `fd0ce6a326f735e4ad4bad8704f515a9eea9a0317e2a3b3c535ae3a15ca7d434`;
- `cabextract/test/bugs/lzx-premature-matches.cab`, SHA-256
  `09f25f73b76058196f27486dbb3ca4ff8f57d5cba5f548db727844155b911244`.

They are used to validate stored CAB extraction and MSZIP extraction from a
cabinet that also contains LZX and Quantum folders. The 26 KiB outer
`large-files-cab` fixture covers a 21-bit LZX window, aligned blocks, 449
CFDATA records, and 32 KiB frame transitions. Its 14,689,228-byte extracted
`large-files.cab` has MD5 `ac923e14971324651015ba44ceb59b36`, independently
verified with libmspack's `cabd_md5` utility. The two small `bugs` fixtures pin
rejection of an empty main tree and a match sequence that overruns its block.
