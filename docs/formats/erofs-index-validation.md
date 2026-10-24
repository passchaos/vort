# EROFS compressed index validation

The shared slice/Source reader validates full and compact compressed indexes
as it scans each extent. Inline and fragment inode-tail scans apply the same
rules before using tail metadata.

Every NONHEAD has a positive backward logical-cluster distance. It may point
to the current head or to an already validated NONHEAD in the same extent.
It cannot cross the most recent head, refer to a nonexistent earlier item,
or terminate in a zero-distance cycle. A CBLKCNT record normalizes to a
distance of one and must immediately follow its head. Head offsets must fit
inside the logical cluster.

Full indexes store the backward distance in delta0. Compact ordinary items
store it in lo, while the final item of each eight-byte/two-item or
32-byte/sixteen-item pack stores the forward distance there instead. Its
backward distance comes from the predecessor: one after a head, two after a
CBLKCNT, or predecessor distance plus one after an ordinary NONHEAD. A final
CBLKCNT itself still has backward distance one.

Compact item width is checked before reading its pack. Four-byte paired
items have 16 encoded bits and support logical-cluster bits through 14;
two-byte items have 14 encoded bits and support bits through 12. Each needs
two type bits in addition to `max(cluster_bits, 12)` offset bits. Wider
declarations return `UnsupportedErofsFeature`. A short inode can advertise
COMPACTED_2B while using only four-byte packs, so the actual pack width decides
support rather than that flag alone. Legal 8/16 KiB four-byte layouts remain
readable, including those with an unused COMPACTED_2B flag.

The validator retains only the next index and the current head index. Since
each previous link was checked before the next one, every accepted backward
chain terminates at the head. Validation needs no index table, recursive
walk, allocation or additional Source reads. It does not check forward
lookahead consistency. Future forward-distance checks must retain the original
reader's compatibility handling for zero delta1 values from pre-1.0 mkfs.

Malformed links return `InvalidErofs` while the existing `IntegerOverflow`,
`TruncatedFrame` and Source errors retain their meanings. Extraction failures
remain sticky, preserve the output buffer and delivered position of the
failing call, release decoded caches, and leave a Sink unfinished. A completed
earlier extent can already have been delivered before a later index fails.
Whole-file and range traversal retain the shared reader's finish checks for
later metadata; partial output is not evidence that the entire index is valid.

The [independent positional oracle](../../tools/erofs/nonhead-oracle.md)
exercises the backward path which fsck's whole-file extraction can skip.
