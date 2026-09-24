# Zstd `vort-test` corpus comparison

This report covers every regular file found recursively under
`~/Downloads/vort-test` on 2026-09-24: 25 files totaling 474,251,686 bytes.
The corpus intentionally contains already-compressed archives, images, video,
PDFs, executables, and two text files. It is therefore useful for exposing raw
block throughput, block setup overhead, literal-heavy compressed blocks, and
dense sequence execution, but it is not a balanced standard compression
corpus.

The benchmark uses the decoder after `7715d03e` plus the full-block split
routing change, Zig 0.16.0 ReleaseFast on Apple M1 Pro, one codec thread, and
Homebrew libzstd 1.5.7. Each source is compressed once by libzstd level 1, then
decoded through both caller-owned implementations. Before timing, the harness
checks both decoded outputs byte-for-byte against the source. Timed iterations
target at least 256 MiB per file, are capped at 20,000, and each reported row is
the best of five rounds. The input cap was raised from 128 MiB to 256 MiB so
the 135,912,332-byte largest file is included.

| File | Bytes | one-shot Vort/libzstd | reusable Vort/libzstd |
| --- | ---: | ---: | ---: |
| `3852_001.pdf` | 55,966 | 0.4653x | 0.5536x |
| `MIT-CSAIL-TR-2012-021.pdf` | 241,230 | 0.5280x | 0.5723x |
| `P23122276601US_...pdf` | 192,404 | 0.6085x | 0.6430x |
| `Potato_ a hybrid CPU_GPU 2D renderer design.pdf` | 171,705 | 0.4701x | 0.5329x |
| `Potato_ a hybrid CPU_GPU 2D renderer design.zip` | 11,191 | 2.1773x | 2.0291x |
| `PotatoahybridCPUGPU2Drendererdesign.html` | 38,977 | 0.9443x | 1.1018x |
| `launch` | 947 | 0.3256x | 0.4548x |
| `left_hand_img_origin.mp4` | 9,679,689 | 0.9793x | 1.0027x |
| `llm-agent (1).pdf` | 4,143,466 | 0.6484x | 0.6192x |
| `nndl-practice.pdf` | 4,514,176 | 0.4738x | 0.4815x |
| `nndl-v2 (1).pdf` | 7,587,144 | 0.5848x | 0.5987x |
| `output 4/siri-agent@...tar.xz` | 11,720,216 | 0.9405x | 0.9427x |
| `output 4/siri-agent_...arm64.deb` | 11,719,292 | 0.9342x | 0.9596x |
| `release_aarch64.tar.gz` | 23,447,421 | 0.9453x | 0.9633x |
| `release_mininav-exec.tar.gz` | 32,720,642 | 0.9905x | 0.9912x |
| `release_mininav-network.tar.gz` | 24,398,119 | 0.9744x | 0.9778x |
| `release_neuro-setting.tar.gz` | 135,912,332 | 1.0123x | 0.9721x |
| `release_ota-service.tar.gz` | 37,885,681 | 0.9482x | 1.0086x |
| `release_performance-monitor.tar.gz` | 71,424,528 | 0.9919x | 1.0208x |
| `release_robot-boot.tar.gz` | 10,754 | 2.0423x | 2.1333x |
| `release_ros2.tar.gz` | 31,505,008 | 0.9840x | 0.9886x |
| `siri-agent.tar.gz` | 10,584,365 | 1.0462x | 0.9776x |
| `zellij` | 38,933,880 | 0.8796x | 0.8802x |
| `zellij-no-web-aarch64-unknown-linux-musl.tar.gz` | 14,489,265 | 0.9923x | 0.9534x |
| `微信图片_20260909154248_3_313.jpg` | 2,863,288 | 0.9692x | 1.0042x |

The one-shot matrix has 4/25 rows above libzstd, a 0.9453x median ratio, a
0.8356x geometric mean, and a time-aggregated 0.7321x ratio. The reusable
matrix has 7/25 rows above libzstd, a 0.9633x median, a 0.8680x geometric mean,
and a 0.8056x aggregate ratio. Absolute ratios moved with host load even though
each Vort/libzstd pair ran in one process; use the independent-binary A/B
figures for claims about the routing change itself.

Every file was also validated with libzstd levels 3 and 9 through the one-shot
path. Those runs use the same byte-for-byte output checks and a 128 MiB target
per file:

| Compression level/API | Files | Vort wins | Median ratio | Geometric mean | Time-aggregated ratio |
| --- | ---: | ---: | ---: | ---: | ---: |
| level 1 one-shot | 25 | 4 | 0.9453x | 0.8356x | 0.7321x |
| level 1 reusable | 25 | 7 | 0.9633x | 0.8680x | 0.8056x |
| level 3 one-shot | 25 | 5 | 0.9721x | 0.7716x | 0.6527x |
| level 9 one-shot | 25 | 7 | 0.9620x | 0.7952x | 0.6492x |

Thus the matrix validates 100 file/mode combinations: all 25 files in both
level-1 APIs and all 25 files at each additional compression level. All source
hash and decoded-byte comparisons passed.

The remaining worst cases are small inputs dominated by fixed frame setup and
PDFs dominated by literal decoding in blocks that do not satisfy the all-FSE
split requirements. Those paths, followed by the remaining `zellij` Huffman
and sequence loops, are the next optimization targets.
