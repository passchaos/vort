# Zstd HQ search evidence

`index.json` lists original text files and deterministic tar.gz bundles with
byte counts and SHA-256. Each stage retains its own source and artifact
identity; later non-input additions are distinguished from actual compiled
source changes. Functional work counts and durations are not benchmarks.

The parser/QA/default archives, formal aggregate, complete family, CLI,
versioned reference campaign, Wasm and integration checks have separate bundles.
Original tool/QA failures and corrected stages remain in their reports. Full
source ZIPs, compiler caches, ELF/Wasm and binary wire files are not duplicated
in Git; their identity and local paths remain in the archived reports.

The original 64-entry aggregate omitted two incrementally named tests from its
filter. Those tests passed their own native/x86 runs and the full 1053-test
family; the enlarged filter is used for final integration and rebase checks.
Do not reinterpret the original aggregate as a larger executed test set.

See the [functional baseline](../../zstd-hq-search-functional-baseline.md) for
parameter, safety, coverage and remaining quality/performance boundaries.
