# Brotli adaptive-distance counted context evidence

- `final-ab.tar.xz`: three case-paired alternating sweeps over 36 Silesia
  prefixes, with five raw Vort/reference rounds and three timed encodes per
  round. Baseline/candidate order reverses for every adjacent case pair.
- `profiles.tar.xz`: current-parent and final-candidate q8 profile reports for
  Mozilla, Dickens and MR 64 KiB, plus the successful profile gate report.
- `inputs.tar.xz`: the exact 36 input prefixes used by the final campaign.
- `excluded-stale-baseline.tar.xz`: an excluded discovery epoch whose baseline
  predates the DEFLATE fixed-cost commit and therefore changes NCI/XML wires.
- `excluded-timing-epochs.tar.xz`: later excluded measurements with a mismatched
  object, compiler/test overlap, module-layout experiment, or process-wide CPU
  frequency drift. None contributes samples to `final-ab.tar.xz`.
- `audit.py`: verifies identities, 15-sample medians, bucket/all-corpus gates,
  sweep direction and complete wire/settings equality.

Binary and reference identities are in `identities.txt`. The baseline was
compiled from a clean `git archive` of `ef409b59`; it is not the older
`7ffbbe39` executable preserved in the excluded epoch.

Archive SHA-256 values:

- `final-ab.tar.xz`: `54bcba099cd757d9f7b111a4f3d1ad47d4e61e194d48f96d182b04bd7ca753b7`
- `profiles.tar.xz`: `fb48d6e0018574315db8d1c59054a576017e3379215422748f8c60f9e7cd8f7e`
- `inputs.tar.xz`: `0a75d3c056c83695c9d98735ee2ea5b6f733671572483acb1c92bb9e7ee2557b`
- `excluded-stale-baseline.tar.xz`: `a9f72b1295eec996c990992fe8cbf7b8521bbe0836192ee021d881a4b46da4a0`
- `excluded-timing-epochs.tar.xz`: `c65ebc1a941488d90ee1cb9a6ca969a2fedd32fe23eaf80b2e7050019e55d1a7`
