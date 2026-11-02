# PNG byte-stride Paeth flat intervals

Paeth selects decoded left whenever the two upper inputs are equal. The new
`src/png/paeth_bpp1.zig` helper checks sixteen-byte upper intervals and uses
wrapping Sub prefixes when that condition holds. Rows without a flat seventeen
byte upper prefix retain the original scalar loop. Every later interval still
checks the condition; scalar tails, predictor ties and in-place bytes remain
exact. No allocation or checksum-policy change is introduced.

Four focused tests cover the full predictor domain, flat/dense/mixed upper
rows, prefix bounds and aliases. PNG kernel/windowed gates pass 20/20 and
99/99; imx decoder/Reader gates pass 98/98. The helper also runs without NEON
and compiles for x86_64 and big-endian AArch64.

Seven CPU-13 complete-image pairs improve the original image-png oxipng text
fixture 1.05529x strict / 1.06307x ignored-Adler. All fifteen rasters and native
requested heap peaks are unchanged. The full corpus is approximately flat.
Dense-noise public scanline pairs on CPU 12 retain 0.99946x/0.99985x at widths
935/4097, while flat intervals materially reduce the kernel's dependency cost.
These kernel observations do not characterize arbitrary image throughput.

Sparse Adler and ARM-difference predictor candidates were rejected for actual
whole-image regressions. imx's broad ReleaseSafe PNG encoder-filter gate has
existing overflow crashes also reproduced against archived original Vort.
The new decoder evidence does not claim that unrelated broad gate is green.

Complete current/reference pixels, corruption controls, requested heap/RSS,
timings, trial identities and gate output live in the sibling imx report:
`docs/evidence/png-paeth-bpp1-flat.md` and its adjacent evidence directory.
Full local artifacts are in `/nav_env/Temp/imx-png-sparse-adler-20261103/`.
General compression/image functionality, ratio, conformance and performance
leadership remain ongoing goals.
