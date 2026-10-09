# CAB interoperability fixtures

`libmspack-simple.cab.hex` and `libmspack-mixed.cab.hex` are byte-for-byte hex
representations of the public cabextract fixtures from libmspack commit
`55d501976171397ccd5d5a7a1ca7da065b1d9a06`:

- `cabextract/test/cabs/simple.cab`, SHA-256
  `590791307b407a6ec6d885542952b7eb6575defde68e06d25bac4f41a9b634fd`;
- `cabextract/test/cabs/mixed.cab`, SHA-256
  `0ce0b55fe705b744d41bb361170c0467db30da0c7f9bdd386d5dade71a78e171`.

They are used to validate stored CAB extraction and MSZIP extraction from a
cabinet that also contains unsupported LZX and Quantum folders.
