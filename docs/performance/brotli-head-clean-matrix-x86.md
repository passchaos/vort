# x86-64 Brotli clean HEAD decode matrix

Date: 2026-10-08. Vort baseline: `54e93ed6`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference:
local libbrotli 1.2.0-dev (`558fc647`, `v1.2.0-169-g558fc64`).

## Method

The frozen Vort benchmark executable has SHA-256
`595893d93d2573cae4e1e738b04548c08e59641a2123c99eb00b200e30252ed2`.
The decoder, common, and encoder reference libraries have SHA-256 values
`e3e18631aaa421912afddbef2246eb3e6abe4e15a10f983d31ac2dcbe3d20eb3`,
`3e05a68ce8782d4b7bc6137d5e89cae758fa9c0a1e139075e29c91b3c4307739`,
and `cc82e22aba04d134b95425d936c1d834edc64a1379c008c896d7fe68cd258899`.
Every invocation used the frozen libraries explicitly:

```sh
taskset -c 2 env LD_LIBRARY_PATH=/tmp/vort-brotli-upstream-build \
  /tmp/vort-br-current-reference --iterations 500 --csv OUT
```

Sampling began only after a continuous 60-second window with 2,016 empty
`ps -C zig` observations. Seven complete 13-row processes then ran under a
continuous 20-millisecond monitor. No Zig process appeared. Earlier attempts
that overlapped Spectra builds or tests were discarded wholesale.

## Result

Ratios are Vort throughput divided by libbrotli throughput, calculated from
the unrounded nanosecond totals. All seven runs preserved each row's input
hash, encoded size, decoded checksum, benchmark version, and executable hash.

| Row | Median | Geometric mean | Wins | Range |
| --- | ---: | ---: | ---: | ---: |
| tiny | 27.9758x | 27.9880x | 7/7 | 27.9371x--28.0493x |
| text | 3.8897x | 3.8998x | 7/7 | 3.8492x--3.9458x |
| structured | 3.0150x | 3.0233x | 7/7 | 3.0032x--3.0558x |
| repetitive | 3.3556x | 3.3572x | 7/7 | 3.3242x--3.3790x |
| random4k | 4.9114x | 4.8836x | 7/7 | 4.6769x--4.9346x |
| text q3 | 4.3268x | 4.3256x | 7/7 | 4.2964x--4.3622x |
| structured q3 | 3.3515x | 3.3489x | 7/7 | 3.3216x--3.3735x |
| repetitive q3 | 4.3208x | 4.3331x | 7/7 | 4.3071x--4.3741x |
| structured q4 | 4.6732x | 4.6685x | 7/7 | 4.5914x--4.7233x |
| text q11 | 3.4391x | 3.4361x | 7/7 | 3.4205x--3.4425x |
| structured q11 | 4.4048x | 4.3932x | 7/7 | 4.2979x--4.4440x |
| repetitive q11 | 3.7999x | 3.7988x | 7/7 | 3.7738x--3.8211x |
| clustered q8 | 0.8632x | 0.8626x | 0/7 | 0.8560x--0.8692x |

Twelve rows are consistently above the local reference, but `clustered_q8`
remains about 13.7% below it. This matrix therefore does not establish broad
Brotli decode leadership. It isolates the remaining reference gap to the
1 MiB, 52-literal-tree flat multi-tree workload, whose command/distance
executor remains the next target. The raw nanosecond totals, per-run ratios,
CSV hashes, provenance, and monitoring disposition are recorded in
[brotli-head-clean-matrix-x86-20261008.json](data/brotli-head-clean-matrix-x86-20261008.json).
