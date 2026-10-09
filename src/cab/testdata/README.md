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
  `09f25f73b76058196f27486dbb3ca4ff8f57d5cba5f548db727844155b911244`;
- `cabextract/test/bugs/cve-2010-2801-qtm-flush.cab`, SHA-256
  `78bb4c9540e36d3d4228e22cdff0a5677f9c2dddc4239c322277d0b9125d8364`;
- `libmspack/test/test_files/cabd/cve-2014-9556-qtm-infinite-loop.cab`,
  SHA-256
  `2e6f57d26e12f3f1c0f1f968d7ebb92e77ea7720ea6f9e18f11eb00ef0e845ad`;
- `libmspack/test/test_files/cabd/cve-2018-18584-qtm-max-size-block.cab`,
  SHA-256
  `3ba0c719d8fb12dc531e2a7790c2d15c12d8840de8e4ddc60572c4145181fbf4`.

They validate Stored, MSZIP, LZX, and Quantum extraction. The 26 KiB outer
`large-files-cab` fixture covers a 21-bit LZX window, aligned blocks, 449
CFDATA records, and 32 KiB frame transitions. Its 14,689,228-byte extracted
`large-files.cab` has MD5 `ac923e14971324651015ba44ceb59b36`, independently
verified with libmspack's `cabd_md5` utility. The five `bugs` fixtures pin
bounded rejection of malformed LZX trees/matches and Quantum frame, match, and
archive-size cases previously associated with infinite loops or overflows.
