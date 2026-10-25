# Exact Brotli literal alphabet evidence, 2026-10-25

Baseline ordinary runtime is d689a411. The candidate changes supported literal
symbol ranking while retaining complete u32 frequencies, descending frequency
and ascending-symbol ties. It reads only parent support frequency entries and
uses fixed local scratch; unsupported entries may be undefined.

- `baseline14/`: current d689 ordinary q8 baseline with14 frozen64KiB inputs,
  five alternating Vort/reference rounds each, requested reference-file hashes,
  source/executable/input identities and compiler monitor.
- `pdq-candidate-source/`, `pdq-alphabet-*`, `pdq-micro-build/`,
  `pdq-microbench/`, `pdq-micro-executable.json`, `pdq-decision.json`: correct
  complete-key PDQ candidate, rejected before public measurements because most
  random/mixed/control pools were slower. Its raw hashes and all outcomes are
  retained. Worst-order/tie wins are not a general speed benefit.
- `radix-*`, `microbench/`: replacement stable frequency-byte radix and new
  exact digit/skip/pass-parity tests. Same32-slot input pools and identities
  as PDQ; compiler-free accepted microbench measures collection, ordering and
  same complete two-output checksum. Identical tie slots are not32 distinct
  inputs. Sparse full support contains85/86 live symbols.
- `context-debug/`, `context-x86/`, `br-family/`, `complete-check/`:
  integration, ownership/candidate and broad frozen-source validation.
- `public14/`, `profile14/`, `paired14/`: final ordinary, actual context and
  supplemental alternating version processes. All frozen output identities,
  candidate/selection and non-time detail counts are checked against the prior
  runtime. Profile times are nested/nonadditive and not ordinary throughput.
- `hotspot-review.md`, `detail-median-audit.json`, `final-kernel-review.md`,
  `bench-review.md`: independent read-only boundaries and invariant reviews.
- `post-rebase/`: final handoff checks, separate from timing measurements.

Stable passes sort all four complete frequency bytes, skipping only constant
digits. Initial symbol-ascending input gives tie order without a symbol-byte
pass. u16 counts/positions retain256; tail arrays and unsupported frequencies
are not part of valid reads. Exact output/reference tests use independent
selection scans rather than reproducing packed keys/radix.

Reference library hashes identify requested files rather than all loader
closure; quality/default-window comparisons do not establish equal algorithms.
Local stack and requested heap differ from full stack/RSS. Current speed points
must not be generalized to all quality, platform, streaming or corpus behavior.
No corpus contents, compiler objects or executables are checked in. Raw tool
logs/disassembly may retain original trailing whitespace, bound by their hashes.
