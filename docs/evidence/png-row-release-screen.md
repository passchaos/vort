# PNG window row-release reference boundary

The production window decoder is unchanged. A new near-code regression checks
that only complete rows outside 32-KiB history are released, partial rows stay
untouched, repeated drains do not duplicate progress, and a malformed later
filter publishes only preceding valid rows with matching Adler state. The named
window test target includes this test explicitly.

Three candidate row loops were withdrawn after causal imx decode testing on
AArch64 CPU 12. Hoisting the complete-row count is neutral in aggregate but
regresses Kodak17 to 0.988321x strict and 0.987227x no-Adler throughput, with
0/7 positive pairs in both policies. Avoiding per-step division still reaches
only 0.991707x no-Adler. A separately sectioned RGBA drainer leaves RGB on the
original source loop but still regresses Kodak17 no-Adler to 0.988682x. All
pixel and heap identities remain exact. Product sources were restored exactly.

Full paired samples, compiler identities, the independent grayscale-route
screen and profile are recorded in the neighboring imx checkout at
`docs/evidence/png-row-release-screen/`. The local archive is
`/nav_env/Temp/imx-png-gray-window-20261101`. No PNG throughput gain is claimed.
