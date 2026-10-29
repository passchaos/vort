# Brotli adaptive-distance shared-preparation evidence

- `final-ab.tar.xz`: three case-paired alternating sweeps over 36 Silesia
  prefixes. Each JSON preserves five raw Vort/reference rounds; each round
  contains three timed encodes.
- `profiles.tar.xz`: current-parent and final-candidate q8 profiles for Mozilla,
  Dickens, and MR 64 KiB, plus both successful profile-gate reports.
- `inputs.tar.xz`: the exact 36 prefixes used by the campaign.
- `summary.json`: final medians, bucket ratios, sweep ratios, reference ratios,
  and per-case results.
- `audit.py`: independently reconstructs the 216 rows, identities, 15-sample
  medians, buckets, sweeps, and retention gates from `final-ab.tar.xz`.
- `commands.txt` and `identities.txt`: exact build/run shape and artifact hashes.

The baseline is a clean `git archive` of `47ff561d`. The candidate contains the
shared adaptive-distance preparation change. Timing uses ordinary ReleaseFast
executables; instrumented profiles are diagnostic only.

Archive SHA-256 values:

- `final-ab.tar.xz`: `e6a27e8332921d0693dcc75bc3aa4da1760c8933b89d0f9e0043a976bec33fba`
- `profiles.tar.xz`: `d226faf73f22921e14cf4b78b242d732a499e211b321e5d30d5a0ca0d49ebd6a`
- `inputs.tar.xz`: `0a75d3c056c83695c9d98735ee2ea5b6f733671572483acb1c92bb9e7ee2557b`
- `summary.json`: `7135900688e7e95ea318cff8143985f18b58b68191b939e1dbdaaf062787b93d`
