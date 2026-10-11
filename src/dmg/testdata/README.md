# DMG fixtures

`hdiutil-hfs-xattrs.dmg.b64` is the Base64 representation of
`test/hfs_xattrs_reference/hdiutil.hfs.dmg` from Mozilla's
`libdmg-hfsplus` repository at commit
`ec239599c1f234a4e01ae3fe51214d0c77e5baa3`. The upstream compatibility
corpus generated it with Apple's `hdiutil`; it contains GPT metadata, free
ranges, and a zlib-compressed HFS partition.

The decoded DMG is 19,756 bytes. Partition 4 is 5,201,920 bytes and has
SHA-256 `69a6e7366f3f71e4847a08542b2088ab56ecb61ba0534b22f84d43abf6266a77`.
That digest was independently reproduced by 7-Zip and dmg2img (the latter's
whole-disk output was sliced to the declared partition length).
