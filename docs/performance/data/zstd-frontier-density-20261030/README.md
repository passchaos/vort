# Zstd frontier density follow-up

This package compares retained four-entry frontier baseline `01335e97` with a
two-entry-per-position capacity. Dense or discontinuous inputs retain the same
safe behavior: an incomplete cache is discarded logically and the refinement
performs the original matcher search.

- `primary-comparison.json`: 4 KiB btultra2 and btopt controls, eight sweeps.
- `secondary-comparison.json`: 16 KiB btultra2 and dictionary control.
- `btopt-mr-long-comparison.json`: fifteen-pair control for a noisy row.
- matching `.py` files: runners and reducers.
- `source-overlay.tar.xz`: complete two-file source overlay.
- `summary.json`, `identities.txt`, `validation.txt`, `SHA256SUMS`: condensed
  decision, provenance, gates and integrity.

Inputs and the pinned reference library are identified by the parent
[`zstd-cold-btultra2-reuse-20261030`](../zstd-cold-btultra2-reuse-20261030/)
package rather than duplicated.
