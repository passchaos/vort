# Zstd cold btultra2 reuse evidence

This package compares clean baseline `8ad5b3ea` with cold-btultra2-only
workspace, match-frontier and repeat-length reuse.

- `primary-comparison.json`: 4 KiB Dickens/Mozilla/MR btopt control and active
  btultra2 rows, eight alternating sweeps.
- `secondary-comparison.json`: 16 KiB active rows and trained-dictionary
  control, eight alternating sweeps.
- `mozilla-long-comparison.json`: fifteen additional Mozilla pairs.
- `primary.py`, `secondary.py`, `mozilla_long.py`: ordinary runners/reducers.
- `inputs.tar.xz`: exact corpus prefixes and trained dictionary/reference.
- `hq-search-report.json.xz`: 41-row search differential and eight frozen rows.
- `hq-controls-report.json.xz`: 52-row controls differential and 56 frozen rows.
- `source-overlay.tar.xz`: complete candidate production and focused-test
  source overlay.
- `summary.json`, `identities.txt`, `validation.txt`, `SHA256SUMS`: decision,
  provenance, gates and integrity.

Extract the overlay over a clean baseline archive, link the repository's
sibling `vail` checkout, build independent ReleaseFast benchmark executables,
update executable paths in the scripts, and run on an otherwise idle CPU 2.
