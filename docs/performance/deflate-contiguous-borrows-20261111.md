# Contiguous wrapper borrow correction, 2026-11-11

Commit `e0f3cd17d6ff9622a02cf29741f4008be7b41cba` closes contiguous zlib/gzip
input/output, full dictionary-set and scalar receiver borrow gaps. The previous
implementation could overwrite a later stored-block payload and return
successful `abcabc` instead of `abcdef` when its checksum was ignored.
The corrected call rejects the overlap with `InvalidBlockPlan` before writes,
leaves backing bytes unchanged and accepts an independent retry.

Common prefix paths, specialized Stored, concatenated members and complete
dictionary-set descriptor/byte ranges are admitted before payload output.
Scalar Raw/zlib/gzip reset and PNG setup protect mutable receivers before
error recording or binding installation. Full output tails are included,
and existing output reuse and read-only input/dictionary sharing remain valid.

Automatic detection of gzip continues to ignore its optional dictionary
argument. That unused argument can share output storage safely. Two earlier
red test iterations assumed a broader borrow than the API actually used;
they remain preserved as contract corrections, with successful controls in
the final tests, rather than being classified as codec failures.

Final validation passed 10 focused Debug/ReleaseSafe/x86/actual-WASI tests,
700 full Deflate tests and the 94-test public-root build gate. The independent
before/after probe, exact changed source and all raw gate logs are preserved in
the [evidence package](deflate-contiguous-borrows-20261111/README.md).
See [the API contract](../formats/deflate-contiguous-wrapper-borrows.md) for
ownership and error behavior. This package makes no throughput or leadership
claim and does not replace the earlier modern decode performance matrix.
