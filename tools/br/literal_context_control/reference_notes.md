# Independent Brotli literal context control reference

`reference.py` exposes `Library(path=None)`,
`produce(payload, quality, disable, large=False, window=None) -> bytes`, and
`inspect(wire, allow_large=True) -> dict`. `identity()` returns reference
provenance. The `disable` argument is a required Python bool and is sent to
upstream `BROTLI_PARAM_DISABLE_LITERAL_CONTEXT_MODELING` (parameter **4**).

The default library is a private build from `BROTLI_SOURCE` (default
`~/Work/brotli`). `Library(path)` accepts a previously built
`libbrlc_reference.so` or its directory. Installed Brotli public ABI libraries
can encode/decode streams but expose no complete context-map observer; they
cannot replace this private library for map inspection.

Build and exercise the reference:

```sh
python3 tools/br/literal_context_control/observer/build.py
python3 tools/br/literal_context_control/reference_preflight.py \
  --output /tmp/vort-brlc-reference-preflight.json
```

The build requires Python 3, a C99 compiler (`CC`, default `cc`), a local Brotli
source tree, and the math library. It copies the source to a cache under
`BRLC_REFERENCE_CACHE` (default `/tmp/vort-brlc-reference`) before applying
observer hooks. It never modifies the source checkout. The cache contains the
exact `observer.c`, matching source/header snapshot, original decoder in
`decode.original.c`, patched `c/dec/decode.c`, `manifest.json`, and compiled
private library. The manifest
records source/header SHA-256 values, upstream commit, observer and patched
decoder SHA-256 values, compiler version and exact command, and library SHA-256.
The Python loader checks the library against the manifest. `-fvisibility=hidden`
and `-Wl,-Bsymbolic` keep upstream encoder, decoder, and common symbols private
to this single source-matched library.

The two decoder hooks observe a completed upstream metablock length/header and
the successful completion of **both** upstream `DecodeContextMap` calls. At the
second hook, run length decoding and inverse move-to-front transformation have
already completed. The observer copies the actual upstream literal map and
checks all 64 entries for each literal block type. It also records all four
distance map entries for each distance block type. No Vort parser, encoder
fields, or generated Vort diagnostic state participates in this proof.

`literal_maps_constant` requires equality within each 64-entry literal map.
Different literal block types may select different trees. Literal/command/
distance block splitting, nonzero context modes, nonconstant distance maps,
and static/shared dictionary context selection are independent properties and
do not cause rejection. The inspector uses the upstream static dictionary and
does not interpret or constrain its context map. No external shared dictionary
is attached by this helper's current `produce`/`inspect` interface.

`inspect` requires a complete successful reference decode with no trailing
input. It returns decoded SHA-256 and size, plus complete base64 content and
UTF-8 text for small outputs (default 16 KiB). It bounds decoded output at
64 MiB by default. Compressed metablocks must have observed maps; uncompressed,
metadata and empty metablocks have no literal map and are recorded separately.

The deterministic preflight has UTF-8, JSON, and Zig source fixtures. It calls
parameter 4 with both values at qualities 0, 4, 5, 9 and 11 in standard and
Large Window modes, checks complete decoded content, and requires actual
nonconstant `disable=false` maps for **each** fixture. It also requires an
actual `disable=true` stream with multiple literal block types and one retaining
UTF-8 context mode, tests empty/tiny/binary content, and rejects truncated and
trailing input. Lower quality fixtures may legitimately have constant maps for
both values; byte inequality is not a general requirement of this parameter.
