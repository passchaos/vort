# Zstd `vort-test` corpus comparison

This report covers every regular file found recursively under
`~/Downloads/vort-test` on 2026-09-24: 25 files totaling 474,251,686 bytes.
The corpus intentionally contains already-compressed archives, images, video,
PDFs, executables, and two text files. It is therefore useful for exposing raw
block throughput, block setup overhead, literal-heavy compressed blocks, and
dense sequence execution, but it is not a balanced standard compression
corpus.

The current benchmark uses the small-block raw/all-FSE routing candidate based
on `ac4ef4ae`, Zig 0.16.0 ReleaseFast on Apple M1 Pro, one codec thread, and
Homebrew libzstd 1.5.7. Each source is compressed once by libzstd level 1, then
decoded through both caller-owned implementations. Before timing, the harness
checks both decoded outputs byte-for-byte against the source. Timed iterations
target at least 128 MiB per file, are capped at 20,000, and each reported row is
the best of five rounds. The input cap is 256 MiB, so the 135,912,332-byte
largest file is included.

| File | Bytes | one-shot Vort/libzstd | reusable Vort/libzstd |
| --- | ---: | ---: | ---: |
| `3852_001.pdf` | 55,966 | 0.7488x | 0.8346x |
| `MIT-CSAIL-TR-2012-021.pdf` | 241,230 | 0.8151x | 0.9325x |
| `P23122276601US_...pdf` | 192,404 | 0.8799x | 0.8972x |
| `Potato_ a hybrid CPU_GPU 2D renderer design.pdf` | 171,705 | 0.9199x | 1.0442x |
| `Potato_ a hybrid CPU_GPU 2D renderer design.zip` | 11,191 | 1.8861x | 2.0767x |
| `PotatoahybridCPUGPU2Drendererdesign.html` | 38,977 | 0.9655x | 1.1028x |
| `launch` | 947 | 0.3230x | 0.4567x |
| `left_hand_img_origin.mp4` | 9,679,689 | 0.9095x | 0.8393x |
| `llm-agent (1).pdf` | 4,143,466 | 0.7558x | 0.7978x |
| `nndl-practice.pdf` | 4,514,176 | 0.6708x | 0.6418x |
| `nndl-v2 (1).pdf` | 7,587,144 | 0.7251x | 0.7243x |
| `output 4/siri-agent@...tar.xz` | 11,720,216 | 0.9854x | 0.9817x |
| `output 4/siri-agent_...arm64.deb` | 11,719,292 | 0.8977x | 0.9212x |
| `release_aarch64.tar.gz` | 23,447,421 | 0.9758x | 0.9530x |
| `release_mininav-exec.tar.gz` | 32,720,642 | 0.9945x | 0.9818x |
| `release_mininav-network.tar.gz` | 24,398,119 | 0.9379x | 1.0454x |
| `release_neuro-setting.tar.gz` | 135,912,332 | 1.0297x | 1.0136x |
| `release_ota-service.tar.gz` | 37,885,681 | 0.9818x | 0.9953x |
| `release_performance-monitor.tar.gz` | 71,424,528 | 0.9610x | 0.9969x |
| `release_robot-boot.tar.gz` | 10,754 | 2.1252x | 1.9281x |
| `release_ros2.tar.gz` | 31,505,008 | 0.9817x | 0.9854x |
| `siri-agent.tar.gz` | 10,584,365 | 0.9518x | 0.9689x |
| `zellij` | 38,933,880 | 0.8671x | 0.8684x |
| `zellij-no-web-aarch64-unknown-linux-musl.tar.gz` | 14,489,265 | 1.0193x | 1.0650x |
| `微信图片_20260909154248_3_313.jpg` | 2,863,288 | 0.8842x | 0.8616x |

The one-shot matrix has 4/25 rows above libzstd, a 0.9379x median ratio, a
0.9180x geometric mean, and a time-aggregated 0.8878x ratio. The reusable
matrix has 7/25 rows above libzstd, a 0.9689x median, a 0.9542x geometric mean,
and a 0.8903x aggregate ratio. Absolute ratios move with host load even though
each Vort/libzstd pair ran in one process; use the independent-binary A/B
figures for claims about the routing change itself.

Every file was also validated with libzstd levels 3 and 9 through the one-shot
path. Those runs use the same byte-for-byte output checks and a 128 MiB target
per file:

| Compression level/API | Files | Vort wins | Median ratio | Geometric mean | Time-aggregated ratio |
| --- | ---: | ---: | ---: | ---: | ---: |
| level 1 one-shot | 25 | 4 | 0.9379x | 0.9180x | 0.8878x |
| level 1 reusable | 25 | 7 | 0.9689x | 0.9542x | 0.8903x |
| level 3 one-shot | 25 | 9 | 0.9729x | 0.8851x | 0.7956x |
| level 9 one-shot | 25 | 5 | 0.9273x | 0.8894x | 0.7040x |

Thus the matrix validates 100 file/mode combinations: all 25 files in both
level-1 APIs and all 25 files at each additional compression level. All source
hash and decoded-byte comparisons passed.

The raw/all-FSE grouped executor and bounded match-copy specialization raised
the first follow-up's level-1 one-shot/reusable aggregate ratios from
0.7321x/0.8056x to 0.8803x/0.9173x. The subsequent small-block routing change
uses independent-binary A/B for its performance claim because the absolute
libzstd ratios vary with host load; its current full-matrix ratios are shown
above. The remaining worst cases are tiny inputs dominated by fixed frame
setup and level-3/9 PDFs whose blocks still fall outside the optimized
raw/all-FSE shape. Those paths, followed by the remaining `zellij` Huffman and
sequence loops, are the next optimization targets.
