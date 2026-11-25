# Brotli CLI standard streams

## Decoding

`decode-br-file-to` accepts `-` for either endpoint. Use `./-` to address a
file literally named `-`.

```sh
vort decode-br-file-to - - < data.br > data.bin
vort decode-br-file-to data.br - 1048576
vort decode-br-file-to - data.bin --large-window < wide.br
```

When either endpoint is `-`, the command uses the library's incremental
Brotli decoder. It accepts one stream with no whole-file compressed input
limit. The optional `max_output` caps decoded bytes. The default admits only
standard Brotli windows; `--large-window` explicitly enables the incompatible
Large Window extension. History grows with decoded data up to the admitted
window rather than staging the whole stream.

When stdout is the destination, it carries only decoded bytes and may publish
output before stdin closes. The command still rejects truncation or trailing
bytes, even if those bytes arrive in a later read. Output already written to
stdout cannot be withdrawn. When decoding stdin to a named file, the command is
quiet on success and replaces the destination only after the entire stream,
including EOF, is validated. Two named paths retain the original one-shot
route and summary.

`zig build test-br-stdio-cli` runs native and WASI checks using upstream
Brotli fixtures, including a flushed prefix, output limits, and Large Window
admission. `zig build test-zstd-stdio-cli` exercises the same CLI transport
with Zstd concatenation and checksum semantics.

## Encoding

```sh
vort encode-br-stream-file - - < data.bin > data.br
vort encode-br-stream-file - data.br --max-input-len=1048576 < data.bin
vort encode-br-stream-file data.bin - --large-window --window-bits=25 > wide.br
```

`encode-br-stream-file` accepts `-` for either endpoint and feeds short reads
to the incremental encoder. It does not need to know the total input length.
The same quality, window, memory, `--max-input-len` and `--max-output-len`
controls apply. Large Window encoding remains opt-in.

Stdout contains only compressed bytes when selected. When either endpoint is
`-`, profiles requested by `--profile` or `--memory-profile` go to stderr and
no success summary is written. A named output is replaced only after
successful completion; output already sent to stdout cannot be withdrawn.
Existing named stream-file and one-shot commands keep their behavior.

`zig build test-br-encode-stdio-cli` checks native and WASI encoding, input and
output limits, and preservation of the target on failure.

## RAW dictionaries

```sh
vort encode-br-stream-file - - --dictionary=prefix.dict < data.bin > data.br
vort decode-br-file-to data.br - --dictionary=prefix.dict > data.bin
```

`--dictionary=PATH` (or `--dictionary PATH`) loads one regular file as RAW
Brotli history, compatible with upstream Brotli's `--dictionary` option.
It applies to planned file, streaming and hex encoding, file and hex decoding,
and `size-br-file`. The stored encoders reject it because they never emit
matches. An empty file is equivalent to no dictionary.

The default dictionary-file cap is 32 MiB. `--max-dictionary-bytes=BYTES`
requires a dictionary and sets an inclusive cap, subject to the codec's RAW
size limit on the current target. Dictionary bytes are separate from
encoder-owned working memory and input or output byte limits. The file is
loaded before any payload output, so dictionary admission errors
leave existing destinations unchanged.

Brotli stores no dictionary ID or checksum for RAW history. Use the identical
bytes when decoding a stream that references a dictionary. A missing or
incorrect dictionary can cause either a decode error or incorrect plaintext.
`zig build test-br-dictionary-cli` covers native and WASI file and pipe routes.
A separate native cross-check with upstream Brotli 1.2.0 verified both
encoding directions on streams that actually reference RAW history.
