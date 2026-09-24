# Zstd `vort-test` corpus comparison

This report covers every regular file found recursively under
`~/Downloads/vort-test` on 2026-09-24: 25 files totaling 474,251,686 bytes.
The corpus intentionally contains already-compressed archives, images, video,
PDFs, executables, and two text files. It is therefore useful for exposing raw
block throughput, block setup overhead, literal-heavy compressed blocks, and
dense sequence execution, but it is not a balanced standard compression
corpus.

The current benchmark uses the raw/all-FSE executor candidate based on
`d7047e6a`, Zig 0.16.0 ReleaseFast on Apple M1 Pro, one codec thread, and
Homebrew libzstd 1.5.7. Each source is compressed once by libzstd level 1, then
decoded through both caller-owned implementations. Before timing, the harness
checks both decoded outputs byte-for-byte against the source. Timed iterations
target at least 128 MiB per file, are capped at 20,000, and each reported row is
the best of five rounds. The input cap is 256 MiB, so the 135,912,332-byte
largest file is included.

| File | Bytes | one-shot Vort/libzstd | reusable Vort/libzstd |
| --- | ---: | ---: | ---: |
| `3852_001.pdf` | 55,966 | 0.4667x | 0.5598x |
| `MIT-CSAIL-TR-2012-021.pdf` | 241,230 | 0.8164x | 0.9530x |
| `P23122276601US_...pdf` | 192,404 | 0.8103x | 0.9345x |
| `Potato_ a hybrid CPU_GPU 2D renderer design.pdf` | 171,705 | 0.9423x | 1.0470x |
| `Potato_ a hybrid CPU_GPU 2D renderer design.zip` | 11,191 | 1.9134x | 2.2819x |
| `PotatoahybridCPUGPU2Drendererdesign.html` | 38,977 | 0.9485x | 1.0746x |
| `launch` | 947 | 0.3261x | 0.4494x |
| `left_hand_img_origin.mp4` | 9,679,689 | 1.0157x | 0.9556x |
| `llm-agent (1).pdf` | 4,143,466 | 0.8431x | 0.7470x |
| `nndl-practice.pdf` | 4,514,176 | 0.6930x | 0.7133x |
| `nndl-v2 (1).pdf` | 7,587,144 | 0.7100x | 0.7126x |
| `output 4/siri-agent@...tar.xz` | 11,720,216 | 0.9993x | 0.9952x |
| `output 4/siri-agent_...arm64.deb` | 11,719,292 | 1.0097x | 0.9852x |
| `release_aarch64.tar.gz` | 23,447,421 | 1.0265x | 1.0279x |
| `release_mininav-exec.tar.gz` | 32,720,642 | 0.9834x | 1.0153x |
| `release_mininav-network.tar.gz` | 24,398,119 | 0.9966x | 0.9152x |
| `release_neuro-setting.tar.gz` | 135,912,332 | 0.9142x | 1.0097x |
| `release_ota-service.tar.gz` | 37,885,681 | 0.9411x | 1.0173x |
| `release_performance-monitor.tar.gz` | 71,424,528 | 0.9938x | 1.0133x |
| `release_robot-boot.tar.gz` | 10,754 | 2.0011x | 1.9938x |
| `release_ros2.tar.gz` | 31,505,008 | 1.0293x | 0.9309x |
| `siri-agent.tar.gz` | 10,584,365 | 0.9994x | 0.9982x |
| `zellij` | 38,933,880 | 0.8619x | 0.9039x |
| `zellij-no-web-aarch64-unknown-linux-musl.tar.gz` | 14,489,265 | 0.9758x | 0.8447x |
| `微信图片_20260909154248_3_313.jpg` | 2,863,288 | 1.1585x | 0.9721x |

The one-shot matrix has 7/25 rows above libzstd, a 0.9758x median ratio, a
0.9206x geometric mean, and a time-aggregated 0.8803x ratio. The reusable
matrix has 9/25 rows above libzstd, a 0.9721x median, a 0.9503x geometric mean,
and a 0.9173x aggregate ratio. Absolute ratios move with host load even though
each Vort/libzstd pair ran in one process; use the independent-binary A/B
figures for claims about the routing change itself.

Every file was also validated with libzstd levels 3 and 9 through the one-shot
path. Those runs use the same byte-for-byte output checks and a 128 MiB target
per file:

| Compression level/API | Files | Vort wins | Median ratio | Geometric mean | Time-aggregated ratio |
| --- | ---: | ---: | ---: | ---: | ---: |
| level 1 one-shot | 25 | 7 | 0.9758x | 0.9206x | 0.8803x |
| level 1 reusable | 25 | 9 | 0.9721x | 0.9503x | 0.9173x |
| level 3 one-shot | 25 | 7 | 0.9850x | 0.8422x | 0.7767x |
| level 9 one-shot | 25 | 12 | 0.9992x | 0.8814x | 0.7026x |

Thus the matrix validates 100 file/mode combinations: all 25 files in both
level-1 APIs and all 25 files at each additional compression level. All source
hash and decoded-byte comparisons passed.

The raw/all-FSE grouped executor and bounded match-copy specialization improve
the previous level-1 one-shot/reusable aggregate ratios from 0.7321x/0.8056x
to 0.8803x/0.9173x. The remaining worst cases are tiny inputs dominated by
fixed frame setup and level-3/9 PDFs whose blocks fall outside the optimized
raw/all-FSE shape. Those paths, followed by the remaining `zellij` Huffman and
sequence loops, are the next optimization targets.
