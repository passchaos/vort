# Brotli CLI standard streams

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
