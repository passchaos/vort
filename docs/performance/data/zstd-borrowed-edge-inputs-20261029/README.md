# Zstd borrowed edge input evidence

`timings.tar.xz` contains the complete 2026-10-29 current-HEAD A/B output:
144 benchmark invocations as paired CSV and JSON files. Filenames beginning
with `0-` through `7-` are the eight 4 KiB cycles. Filenames beginning with
`large-0-` through `large-3-` are the four 16 KiB or trained-dictionary cycles.

Each JSON file includes the input hash, raw Vort/libzstd timing round, resolved
controls, complete encoder profile, peak requested working memory, Vort and
reference wire size/hash, reference library identity and benchmark provenance.
The benchmark validates the Vort wire through libzstd and the reference wire
through Vort before writing results. The corresponding release binaries are
identified by SHA-256 in `../../zstd-borrowed-edge-inputs.md`; they are not
stored in this repository.

Archive SHA-256:
`f381497939e29083d2397ed14c7ef05b1230b662ef877bf7d0deedd9499faccc`.

This archive deliberately excludes the much larger regenerated HQ/search
differential directories. Their authoritative row counts and zero-exit results
are recorded in the performance note, while the versioned references and
reproducible drivers already live in the repository.
