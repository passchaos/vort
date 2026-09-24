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
| `3852_001.pdf` | 55,966 | 0.4751x | 0.5428x |
| `MIT-CSAIL-TR-2012-021.pdf` | 241,230 | 0.5526x | 0.6006x |
| `P23122276601US_...pdf` | 192,404 | 0.6123x | 0.6680x |
| `Potato_ a hybrid CPU_GPU 2D renderer design.pdf` | 171,705 | 0.4887x | 0.5329x |
| `Potato_ a hybrid CPU_GPU 2D renderer design.zip` | 11,191 | 1.8249x | 1.9747x |
| `PotatoahybridCPUGPU2Drendererdesign.html` | 38,977 | 0.9624x | 1.1096x |
| `launch` | 947 | 0.3307x | 0.4516x |
| `left_hand_img_origin.mp4` | 9,679,689 | 0.9547x | 0.9816x |
| `llm-agent (1).pdf` | 4,143,466 | 0.6266x | 0.6187x |
| `nndl-practice.pdf` | 4,514,176 | 0.5084x | 0.4707x |
| `nndl-v2 (1).pdf` | 7,587,144 | 0.4029x | 0.4018x |
| `output 4/siri-agent@...tar.xz` | 11,720,216 | 1.0034x | 1.0623x |
| `output 4/siri-agent_...arm64.deb` | 11,719,292 | 0.8804x | 1.0135x |
| `release_aarch64.tar.gz` | 23,447,421 | 0.8788x | 1.0593x |
| `release_mininav-exec.tar.gz` | 32,720,642 | 0.9794x | 0.9992x |
| `release_mininav-network.tar.gz` | 24,398,119 | 0.9913x | 1.0085x |
| `release_neuro-setting.tar.gz` | 135,912,332 | 1.0443x | 1.0082x |
| `release_ota-service.tar.gz` | 37,885,681 | 1.0778x | 1.0398x |
| `release_performance-monitor.tar.gz` | 71,424,528 | 1.0030x | 0.9954x |
| `release_robot-boot.tar.gz` | 10,754 | 1.9133x | 1.9328x |
| `release_ros2.tar.gz` | 31,505,008 | 0.9963x | 1.0067x |
| `siri-agent.tar.gz` | 10,584,365 | 1.0866x | 0.9415x |
| `zellij` | 38,933,880 | 0.8358x | 0.8367x |
| `zellij-no-web-aarch64-unknown-linux-musl.tar.gz` | 14,489,265 | 1.0605x | 1.0101x |
| `微信图片_20260909154248_3_313.jpg` | 2,863,288 | 0.9950x | 1.0199x |

The one-shot matrix has 8/25 rows above libzstd, a 0.9624x median ratio, a
0.8271x geometric mean, and a time-aggregated 0.7233x ratio. The reusable
matrix has 12/25 rows above libzstd, a 0.9992x median, a 0.8628x geometric mean,
and a 0.7865x aggregate ratio. Absolute ratios moved with host load even though
each Vort/libzstd pair ran in one process; use the independent-binary A/B
figures for claims about the routing change itself.

Every file was also validated with libzstd levels 3 and 9 through the one-shot
path. Those runs use the same byte-for-byte output checks and a 128 MiB target
per file:

| Compression level/API | Files | Vort wins | Median ratio | Geometric mean | Time-aggregated ratio |
| --- | ---: | ---: | ---: | ---: | ---: |
| level 1 one-shot | 25 | 8 | 0.9624x | 0.8271x | 0.7233x |
| level 1 reusable | 25 | 12 | 0.9992x | 0.8628x | 0.7865x |
| level 3 one-shot | 25 | 7 | 0.9384x | 0.7527x | 0.6118x |
| level 9 one-shot | 25 | 4 | 0.9890x | 0.7804x | 0.6413x |

Thus the matrix validates 100 file/mode combinations: all 25 files in both
level-1 APIs and all 25 files at each additional compression level. All source
hash and decoded-byte comparisons passed.

The remaining worst cases are small inputs dominated by fixed frame setup and
PDFs dominated by literal decoding in blocks that do not satisfy the all-FSE
split requirements. Those paths, followed by the remaining `zellij` Huffman
and sequence loops, are the next optimization targets.
