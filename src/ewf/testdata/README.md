# EWF interoperability fixtures

These fixtures were generated with libewf `20260924` and then compressed with
system Bzip2 before Base64 encoding. The Bzip2 layer is repository storage only;
the embedded payload is the original E01 segment byte stream parsed by Vort.

`libewf-encase6-mixed.E01.bz2.b64` contains four 8 KiB chunks generated with
`ewfacquirestream -b 16 -c deflate:fast -f encase6`. Its table contains the
compressed/raw pattern `true,false,true,true`.

- raw media SHA-256: `6a98be9974d949201d398787f433d1c3c529caaf6227a0834d173071b2bac68c`
- E01 SHA-256: `cd63bb0cf21cabea437c8e356b30046968ea470035111811e40e94fab256d9d8`
- stored Bzip2 SHA-256: `3683b864ba8b3f14db9a8aa0afe88ec6da5441501f63b6d06acc4157348910aa`

`libewf-multi-raw.E01...E04.bz2.b64` is a four-segment, 3 MiB image generated
with `-b 64 -c deflate:none -f encase6 -S 1048576`. Each of its 96 chunks is
filled with byte `(chunk_index * 17 + 3) & 0xff`.

- raw media SHA-256: `4f0fee9d6c5f1cef35d545607b13a8fe2af817859e9e7113baf0c3893fb5753a`
- E01 Bzip2 SHA-256: `12f294e847e8245fb932df1b5326ece125f927a1d384e1822f688cc5e44e8266`
- E02 Bzip2 SHA-256: `ee19bdb5caad1e906c79c539b094d9979f0d4107b7a3502701360b4ff95c6422`
- E03 Bzip2 SHA-256: `34974a6a32393810276ca2ff66ee8176ac3852170aa3e296dd7b8b3b462f2615`
- E04 Bzip2 SHA-256: `9e838043e3b5624ffebee197b60a55b265a6446669d0b744fab5a5f404af350f`
