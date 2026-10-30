# Zstd cross-pass repeat evidence diagnostic

This package records a rejected diagnostic against baseline
`ff7c65e95ffd531b0675a3fb561494f5d442cd46`.

- `diag4.json` / `diag16.json`: complete benchmark/profile reports.
- `source-overlay.tar.xz`: diagnostic-only source overlay.
- `summary.json`: reduced request/hit/probe statistics and decision.
- `identities.txt`: source, executable, reference, compiler and CPU identity.
- `commands.txt`: build and replay command shapes.
- `validation.txt`: scope and rollback boundary.
- `SHA256SUMS`: integrity manifest.

Corpus inputs and libzstd identities are inherited from the parent
[`zstd-cold-btultra2-reuse-20261030`](../zstd-cold-btultra2-reuse-20261030/)
package.
