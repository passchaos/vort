# Repeat match cache screens

The baseline is Git `26d9eb062da7dedded4aa1e3b639d76a53192d4f`. Neither cache
shape has been adopted. Each `*-screen.tar.xz` preserves its exact candidate
modules, ordinary runner, original commands, raw clocks/wires/profiles and
binary identities; compiled runners and caches are excluded. Both screens
reuse the same verified baseline binary.

`reuse-diagnostic.tar.xz` preserves the separate four-call diagnostic that
executed every original comparison. Its per-position records attribute
repeated work and are not timing measurements. `inputs.tar.xz` preserves the
three actual timed 4 KiB inputs. The manifest points to the identical shared
`baseline-source.tar.xz` in the adjacent `zstd-hq-repeat-screen-20261028`
directory for reproduction.

`frozen-contracts.tar.xz` supplies the candidate and grouped frozen-DP/cache
tests, small known-input/profile fixtures and source-root wrapper. The
validation record includes actual 22/22 terminal statuses for native Debug,
ReleaseFast and x86 Debug, with their source-epoch limits. No Wasm test or
broader product gate is claimed for these unadopted prototypes.

Run `python3 docs/performance/data/zstd-rep-match-cache-screen-20261028/audit.py`
to check archive/source scope, paired wires, actual work accounting, exact
timing summaries, diagnostic fractions, contract terminal records and the
independent libzstd decode records. For replay, extract the baseline, overlay
one candidate, rewrite the archived structured compile/run paths and preserve
the original flags, input identities and balanced order.
