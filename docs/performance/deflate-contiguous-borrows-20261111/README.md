# Contiguous wrapper borrow evidence, 2026-11-11

The correction protects complete zlib/gzip input/output borrows, preset
dictionaries, full dictionary-set descriptors/bytes and scalar receiver storage
before writes. [The contract](../../formats/deflate-contiguous-wrapper-borrows.md)
documents admission, ordinary errors and the ignored optional dictionary on the
auto-detected gzip route. This is a functional correction, not a speed claim.

`bindings.json` records the fix/base commits, six exact changed Zig sources,
every archive/member hash, and the separate test-contract corrections.
`source-overlay.tar.gz` restores those committed sources over the base checkout.
`evidence.tar.gz` preserves exact before/after probe sources and logs, final
native/Debug/x86 gates, full/public-root results, actual wasm32 binary and
execution receipt. GNU tar members are sorted, uid/gid/mtime zero, with empty
owner names. Gzip timestamps are zero; raw member bytes are not normalized.

Both independently valid two-block fixtures initially returned successful
`abcabc` instead of `abcdef` when output covered later unread payload and
the content checksum was ignored. The repaired probe returns
`InvalidBlockPlan` without changing its backing; independent output remains
`abcdef`. The two fixtures are also Python-zlib validated in the parent work.

The final scope includes 23 caller-output APIs, format-specific combinations,
two-member sets with later/unused dictionary and descriptor hazards,
scalar reset variants, unused output tail, source/dictionary read sharing,
ordinary errors and scalar PNG receiver/row storage. Native focused gates
passed 10 tests, full Deflate 700 and public root 94; actual WASI exited 0.

The two earlier red test logs are preserved as **test-contract corrections**:
they incorrectly expected auto-detected gzip to borrow its deliberately ignored
dictionary argument. That safe alias remains a successful control. They are
not recorded as codec failures or silently discarded from provenance.

Verify the preserved evidence:

```sh
sha256sum -c SHA256SUMS
python3 verify.py --live-root /path/to/vort
```

Replay the probe after extracting `evidence.tar.gz` and selecting the base/fix
checkout as appropriate:

```sh
zig run -OReleaseSafe --dep deflate -Mroot=/path/to/before.zig \
  -OReleaseSafe -Mdeflate=/path/to/vort/src/deflate.zig
zig run -OReleaseSafe --dep deflate -Mroot=/path/to/after.zig \
  -OReleaseSafe -Mdeflate=/path/to/vort/src/deflate.zig
zig test src/deflate.zig -OReleaseSafe --test-filter 'Deflate contiguous'
```

The verifier checks recorded facts and exact bytes; it does not rerun decoders
or establish throughput, peak-memory or industry-best parity.
