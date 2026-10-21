# ARJ test data

`unarc-rs-license-garble.arj.b64` is the Base64 representation of
`crates/unarc-rs/tests/arj/license_crypted.arj` from unarc-rs commit
`b017fed390a8021faa198d0c842c95d13ecbaf6d` (release 0.8.0). The archive uses
legacy ARJ Garble encryption with password `secret`; its binary SHA-256 is
`29b1c579452f5b6ef2c731be8c3be4d788926a1fbf5691f9b1940d895ffcfe65`.
The decoded Apache License payload SHA-256 is
`c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4`.

The source repository publishes the fixture under its repository licenses.

`unarc-rs-multi-test_file.arj.b64`, `.a01.b64`, and `.a02.b64` are the
three-volume `tests/arj/multi/test_file` set from the same commit. Their decoded
logical `TEST.ICY` member is 29,813 bytes with SHA-256
`be8a087b4563b116bd79d2f8b1f0544c2709a70c4787e05a57b7e11ec33a7f74`.
Binary SHA-256 values in volume order are
`f33c9bea36e8b6fd7ebf7f8c144c0bf542528af3e3ef86ee08e69815fd98a404`,
`80c1a51a509eddc9296a904be1f89f0b150aa7d5eb0ff8baa425fda61e552bf6`, and
`caf74286c0b424e38ac7bc03d4176d103ae9e394efcb70372c8898b7d0525f70`.
