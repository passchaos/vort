const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const vort_mod = b.addModule("vort", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const vort_mod_releasefast = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });
    const br_record_optimal_obj = b.addObject(.{
        .name = "vort-br-record-optimal",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/br/encoder/record_optimal_object.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const br_record_optimal_releasefast_obj = b.addObject(.{
        .name = "vort-br-record-optimal-releasefast",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/br/encoder/record_optimal_object.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });
    const zstd_huffman_x2_obj = b.addObject(.{
        .name = "vort-zstd-huffman-x2",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/zstd_huffman_x2_object.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const zstd_huffman_x2_releasefast_obj = b.addObject(.{
        .name = "vort-zstd-huffman-x2-releasefast",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/zstd_huffman_x2_object.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });
    const wasm_target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .wasi });
    const wasm_br_record_optimal_obj = b.addObject(.{
        .name = "vort-br-record-optimal-wasm-check",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/br/encoder/record_optimal_object.zig"),
            .target = wasm_target,
            .optimize = optimize,
        }),
    });
    const wasm_zstd_huffman_x2_obj = b.addObject(.{
        .name = "vort-zstd-huffman-x2-wasm-check",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/zstd_huffman_x2_object.zig"),
            .target = wasm_target,
            .optimize = optimize,
        }),
    });
    const wasm_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = wasm_target,
        .optimize = optimize,
    });
    wasm_mod.addObject(wasm_br_record_optimal_obj);
    wasm_mod.addObject(wasm_zstd_huffman_x2_obj);
    const wasm_lib = b.addLibrary(.{ .name = "vort-wasm-check", .root_module = wasm_mod });
    const wasm_check_step = b.step("check-wasm", "Compile the complete Vort library for wasm32-wasi");
    wasm_check_step.dependOn(&wasm_lib.step);
    const br_record_classifier_tests = b.addTest(.{
        .name = "vort-br-record-classifier-tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/br/encoder/record_classifier.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_br_record_classifier_tests = b.addRunArtifact(br_record_classifier_tests);
    const br_record_optimal_object_tests = b.addTest(.{
        .name = "vort-br-record-optimal-object-tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/br/encoder/record_optimal_object.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_br_record_optimal_object_tests = b.addRunArtifact(br_record_optimal_object_tests);
    vort_mod.addObject(br_record_optimal_obj);
    vort_mod.addObject(zstd_huffman_x2_obj);
    vort_mod_releasefast.addObject(br_record_optimal_releasefast_obj);
    vort_mod_releasefast.addObject(zstd_huffman_x2_releasefast_obj);
    const benchmark_provenance_mod = b.createModule(.{
        .root_source_file = b.path("tools/benchmark_provenance.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });

    const lib = b.addLibrary(.{
        .name = "vort",
        .root_module = vort_mod,
    });
    b.installArtifact(lib);

    const tests_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    tests_mod.addObject(br_record_optimal_obj);
    tests_mod.addObject(zstd_huffman_x2_obj);

    const tests = b.addTest(.{
        .name = "vort-tests",
        .root_module = tests_mod,
    });
    const run_tests = b.addRunArtifact(tests);
    const zstd_huffman_x2_tests = b.addTest(.{
        .name = "vort-zstd-huffman-x2-tests",
        .root_module = tests_mod,
        .filters = &.{"wide X2"},
    });
    const run_zstd_huffman_x2_tests = b.addRunArtifact(zstd_huffman_x2_tests);
    const zstd_huffman_x2_test_step = b.step("test-zstd-huffman-x2", "Run focused wide Huffman X2 correctness tests");
    zstd_huffman_x2_test_step.dependOn(&run_zstd_huffman_x2_tests.step);
    const ar_deb_tests = b.addTest(.{
        .name = "vort-ar-deb-tests",
        .root_module = tests_mod,
        .filters = &.{ "ar ", "Debian package" },
    });
    const run_ar_deb_tests = b.addRunArtifact(ar_deb_tests);
    const ar_deb_test_step = b.step("test-ar-deb", "Run focused Unix ar and Debian package tests");
    ar_deb_test_step.dependOn(&run_ar_deb_tests.step);
    const rpm_tests = b.addTest(.{
        .name = "vort-rpm-tests",
        .root_module = tests_mod,
        .filters = &.{"RPM "},
    });
    const run_rpm_tests = b.addRunArtifact(rpm_tests);
    const rpm_test_step = b.step("test-rpm", "Run focused RPM header and package tests");
    rpm_test_step.dependOn(&run_rpm_tests.step);
    const bgzf_tests = b.addTest(.{
        .name = "vort-bgzf-tests",
        .root_module = tests_mod,
        .filters = &.{"BGZF "},
    });
    const run_bgzf_tests = b.addRunArtifact(bgzf_tests);
    const bgzf_test_step = b.step("test-bgzf", "Run focused BGZF block and range tests");
    bgzf_test_step.dependOn(&run_bgzf_tests.step);
    const snappy_framing_tests = b.addTest(.{
        .name = "vort-snappy-framing-tests",
        .root_module = tests_mod,
        .filters = &.{ "Xerial Snappy", "Hadoop Snappy", "Snappy framing" },
    });
    const run_snappy_framing_tests = b.addRunArtifact(snappy_framing_tests);
    const snappy_framing_test_step = b.step("test-snappy-framing", "Run focused Xerial and Hadoop Snappy tests");
    snappy_framing_test_step.dependOn(&run_snappy_framing_tests.step);
    const hadoop_lz4_tests = b.addTest(.{
        .name = "vort-hadoop-lz4-tests",
        .root_module = tests_mod,
        .filters = &.{"Hadoop LZ4"},
    });
    const run_hadoop_lz4_tests = b.addRunArtifact(hadoop_lz4_tests);
    const hadoop_lz4_test_step = b.step("test-hadoop-lz4", "Run focused Hadoop LZ4 framing tests");
    hadoop_lz4_test_step.dependOn(&run_hadoop_lz4_tests.step);
    const lz4_legacy_tests = b.addTest(.{
        .name = "vort-lz4-legacy-tests",
        .root_module = tests_mod,
        .filters = &.{"LZ4 legacy"},
    });
    const run_lz4_legacy_tests = b.addRunArtifact(lz4_legacy_tests);
    const lz4_legacy_test_step = b.step("test-lz4-legacy", "Run focused LZ4 legacy frame tests");
    lz4_legacy_test_step.dependOn(&run_lz4_legacy_tests.step);
    const lznt1_tests = b.addTest(.{
        .name = "vort-lznt1-tests",
        .root_module = tests_mod,
        .filters = &.{"LZNT1"},
    });
    const run_lznt1_tests = b.addRunArtifact(lznt1_tests);
    const lznt1_test_step = b.step("test-lznt1", "Run focused Windows LZNT1 codec tests");
    lznt1_test_step.dependOn(&run_lznt1_tests.step);
    const xpress_tests = b.addTest(.{
        .name = "vort-xpress-tests",
        .root_module = tests_mod,
        .filters = &.{ "XPRESS plain", "XPRESS Huffman" },
    });
    const run_xpress_tests = b.addRunArtifact(xpress_tests);
    const xpress_test_step = b.step("test-xpress", "Run focused Windows XPRESS codec tests");
    xpress_test_step.dependOn(&run_xpress_tests.step);
    const lzfse_tests = b.addTest(.{
        .name = "vort-lzfse-tests",
        .root_module = tests_mod,
        .filters = &.{ "LZFSE", "LZVN" },
    });
    const run_lzfse_tests = b.addRunArtifact(lzfse_tests);
    const lzfse_test_step = b.step("test-lzfse", "Run focused LZFSE and LZVN tests");
    lzfse_test_step.dependOn(&run_lzfse_tests.step);
    const zchunk_tests = b.addTest(.{
        .name = "vort-zchunk-tests",
        .root_module = tests_mod,
        .filters = &.{"zchunk "},
    });
    const run_zchunk_tests = b.addRunArtifact(zchunk_tests);
    const zchunk_test_step = b.step("test-zchunk", "Run focused zchunk container tests");
    zchunk_test_step.dependOn(&run_zchunk_tests.step);
    const squashfs_tests = b.addTest(.{
        .name = "vort-squashfs-tests",
        .root_module = tests_mod,
        .filters = &.{"SquashFS"},
    });
    const run_squashfs_tests = b.addRunArtifact(squashfs_tests);
    const squashfs_test_step = b.step("test-squashfs", "Run focused SquashFS parser and extraction tests");
    squashfs_test_step.dependOn(&run_squashfs_tests.step);
    const erofs_tests = b.addTest(.{
        .name = "vort-erofs-tests",
        .root_module = tests_mod,
        .filters = &.{"EROFS"},
    });
    const run_erofs_tests = b.addRunArtifact(erofs_tests);
    const erofs_test_step = b.step("test-erofs", "Run focused EROFS reader and writer tests");
    erofs_test_step.dependOn(&run_erofs_tests.step);
    const hadoop_lzo_index_tests = b.addTest(.{
        .name = "vort-hadoop-lzo-index-tests",
        .root_module = tests_mod,
        .filters = &.{"Hadoop LZO index"},
    });
    const run_hadoop_lzo_index_tests = b.addRunArtifact(hadoop_lzo_index_tests);
    const hadoop_lzo_index_test_step = b.step("test-hadoop-lzo-index", "Run focused Hadoop LZO index tests");
    hadoop_lzo_index_test_step.dependOn(&run_hadoop_lzo_index_tests.step);

    const test_step = b.step("test", "Run vort unit tests");
    test_step.dependOn(&run_tests.step);
    test_step.dependOn(&run_br_record_classifier_tests.step);
    test_step.dependOn(&run_br_record_optimal_object_tests.step);

    const cli_exe = b.addExecutable(.{
        .name = "vort",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/cli.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });

    const run_cli = b.addRunArtifact(cli_exe);
    if (b.args) |args| run_cli.addArgs(args);
    const run_step = b.step("run", "Run the vort CLI smoke example");
    run_step.dependOn(&run_cli.step);

    const cli_releasefast_exe = b.addExecutable(.{
        .name = "vort-releasefast",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/cli.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod_releasefast },
            },
        }),
    });

    const bench_exe = b.addExecutable(.{
        .name = "vort-bench-checksum",
        .root_module = b.createModule(.{
            .root_source_file = b.path("bench/checksum.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });

    const run_bench = b.addRunArtifact(bench_exe);
    if (b.args) |args| run_bench.addArgs(args);
    const bench_step = b.step("bench-checksum", "Run Adler-32/CRC-32 checksum throughput smoke benchmark");
    bench_step.dependOn(&run_bench.step);

    const run_checksum_bench_csv = b.addRunArtifact(bench_exe);
    run_checksum_bench_csv.addArgs(&.{ "--csv", "zig-out/vort-checksum-bench.csv" });
    const checksum_bench_csv_step = b.step("bench-checksum-csv", "Write per-checksum throughput CSV to zig-out");
    checksum_bench_csv_step.dependOn(&run_checksum_bench_csv.step);

    const checksum_bench_gate = b.addSystemCommand(&.{
        "python3",
        "tools/checksum_bench_gate.py",
        "--csv",
        "zig-out/vort-checksum-bench.csv",
    });
    checksum_bench_gate.step.dependOn(checksum_bench_csv_step);
    const checksum_bench_gate_step = b.step("run-checksum-bench-gate", "Validate checksum benchmark CSV");
    checksum_bench_gate_step.dependOn(&checksum_bench_gate.step);

    const deflate_bench_exe = b.addExecutable(.{
        .name = "vort-bench-deflate-decode",
        .root_module = b.createModule(.{
            .root_source_file = b.path("bench/deflate_decode.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });

    const run_deflate_bench = b.addRunArtifact(deflate_bench_exe);
    if (b.args) |args| run_deflate_bench.addArgs(args);
    const deflate_bench_step = b.step("bench-deflate-decode", "Run deflate/zlib/gzip decode throughput smoke benchmark");
    deflate_bench_step.dependOn(&run_deflate_bench.step);

    const corpus_decode_bench_exe = b.addExecutable(.{
        .name = "vort-bench-corpus-decode",
        .root_module = b.createModule(.{
            .root_source_file = b.path("bench/corpus_decode.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_corpus_decode_bench = b.addRunArtifact(corpus_decode_bench_exe);
    const corpus_decode_bench_step = b.step("bench-corpus-decode", "Run real-corpus raw/zlib/gzip decode throughput smoke benchmark");
    corpus_decode_bench_step.dependOn(&run_corpus_decode_bench.step);

    const zlib_decode_bench_exe = b.addExecutable(.{
        .name = "vort-zlib-decode-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/zlib_decode_bench.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod_releasefast },
                .{ .name = "benchmark_provenance", .module = benchmark_provenance_mod },
            },
        }),
    });

    const deflate_decode_stage_report_exe = b.addExecutable(.{
        .name = "vort-deflate-decode-stage-report",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/deflate_decode_stage_report.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_deflate_decode_stage_report = b.addRunArtifact(deflate_decode_stage_report_exe);
    if (b.args) |args| run_deflate_decode_stage_report.addArgs(args);
    const deflate_decode_stage_report_step = b.step("run-deflate-decode-stage-report", "Report raw inflate vs zlib wrapper/checksum decode stages");
    deflate_decode_stage_report_step.dependOn(&run_deflate_decode_stage_report.step);

    const run_deflate_decode_stage_report_csv = b.addRunArtifact(deflate_decode_stage_report_exe);
    run_deflate_decode_stage_report_csv.addArgs(&.{ "--csv", "zig-out/vort-deflate-decode-stage-report.csv" });
    const deflate_decode_stage_report_csv_step = b.step("run-deflate-decode-stage-report-csv", "Write raw inflate vs zlib wrapper/checksum stage CSV to zig-out");
    deflate_decode_stage_report_csv_step.dependOn(&run_deflate_decode_stage_report_csv.step);

    const run_deflate_decode_stage_report_csv_repeat3 = b.addRunArtifact(deflate_decode_stage_report_exe);
    run_deflate_decode_stage_report_csv_repeat3.addArgs(&.{ "--repeat", "3", "--builtins-plus-files", "README.md", "docs/roadmap.md", "--csv", "zig-out/vort-deflate-decode-stage-report-repeat3.csv" });
    const deflate_decode_stage_report_csv_repeat3_step = b.step("run-deflate-decode-stage-report-csv-repeat3", "Write median-of-3 raw inflate vs zlib wrapper/checksum stage CSV to zig-out");
    deflate_decode_stage_report_csv_repeat3_step.dependOn(&run_deflate_decode_stage_report_csv_repeat3.step);

    const run_deflate_decode_stage_report_dashboard = b.addRunArtifact(deflate_decode_stage_report_exe);
    run_deflate_decode_stage_report_dashboard.addArgs(&.{ "--csv", "zig-out/vort-deflate-decode-stage-report.csv", "--markdown", "zig-out/vort-deflate-decode-stage-report.md", "--json", "zig-out/vort-deflate-decode-stage-report.json" });
    const deflate_decode_stage_report_dashboard_step = b.step("run-deflate-decode-stage-report-dashboard", "Write raw inflate vs zlib wrapper/checksum stage dashboard to zig-out");
    deflate_decode_stage_report_dashboard_step.dependOn(&run_deflate_decode_stage_report_dashboard.step);

    const deflate_dynamic_decode_profile_exe = b.addExecutable(.{
        .name = "vort-deflate-dynamic-decode-profile",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/deflate_dynamic_decode_profile.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_deflate_dynamic_decode_profile = b.addRunArtifact(deflate_dynamic_decode_profile_exe);
    if (b.args) |args| run_deflate_dynamic_decode_profile.addArgs(args);
    const deflate_dynamic_decode_profile_step = b.step("run-deflate-dynamic-decode-profile", "Profile dynamic deflate Huffman decode hit/miss counters");
    deflate_dynamic_decode_profile_step.dependOn(&run_deflate_dynamic_decode_profile.step);

    const run_deflate_dynamic_decode_profile_csv = b.addRunArtifact(deflate_dynamic_decode_profile_exe);
    run_deflate_dynamic_decode_profile_csv.addArgs(&.{ "--builtins-plus-files", "README.md", "docs/roadmap.md", "--csv", "zig-out/vort-deflate-dynamic-decode-profile.csv" });
    const deflate_dynamic_decode_profile_csv_step = b.step("run-deflate-dynamic-decode-profile-csv", "Write dynamic deflate Huffman decode profile CSV to zig-out");
    deflate_dynamic_decode_profile_csv_step.dependOn(&run_deflate_dynamic_decode_profile_csv.step);

    const deflate_dynamic_decode_profile_gate = b.addSystemCommand(&.{
        "python3",
        "tools/deflate_dynamic_decode_profile_gate.py",
        "--csv",
        "zig-out/vort-deflate-dynamic-decode-profile.csv",
    });
    deflate_dynamic_decode_profile_gate.step.dependOn(deflate_dynamic_decode_profile_csv_step);
    const deflate_dynamic_decode_profile_gate_step = b.step("run-deflate-dynamic-decode-profile-gate", "Validate dynamic deflate decode profile CSV");
    deflate_dynamic_decode_profile_gate_step.dependOn(&deflate_dynamic_decode_profile_gate.step);

    const deflate_huffman_build_bench_exe = b.addExecutable(.{
        .name = "vort-deflate-huffman-build-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/deflate_huffman_build_bench.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_deflate_huffman_build_bench_csv = b.addRunArtifact(deflate_huffman_build_bench_exe);
    run_deflate_huffman_build_bench_csv.addArgs(&.{ "--csv", "zig-out/vort-deflate-huffman-build-bench.csv" });
    const deflate_huffman_build_bench_csv_step = b.step("run-deflate-huffman-build-bench-csv", "Write focused DEFLATE Huffman table build benchmark CSV");
    deflate_huffman_build_bench_csv_step.dependOn(&run_deflate_huffman_build_bench_csv.step);

    const deflate_huffman_build_bench_gate = b.addSystemCommand(&.{
        "python3",
        "tools/deflate_huffman_build_bench_gate.py",
        "--csv",
        "zig-out/vort-deflate-huffman-build-bench.csv",
    });
    deflate_huffman_build_bench_gate.step.dependOn(deflate_huffman_build_bench_csv_step);
    const deflate_huffman_build_bench_gate_step = b.step("run-deflate-huffman-build-bench-gate", "Validate DEFLATE Huffman table build benchmark CSV");
    deflate_huffman_build_bench_gate_step.dependOn(&deflate_huffman_build_bench_gate.step);

    const huffman_length_bench_exe = b.addExecutable(.{
        .name = "vort-huffman-length-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/huffman_length_bench.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_huffman_length_bench = b.addRunArtifact(huffman_length_bench_exe);
    if (b.args) |args| run_huffman_length_bench.addArgs(args);
    const huffman_length_bench_step = b.step("bench-huffman-length", "Benchmark sparse and dense Huffman code-length construction");
    huffman_length_bench_step.dependOn(&run_huffman_length_bench.step);

    const run_huffman_length_bench_csv = b.addRunArtifact(huffman_length_bench_exe);
    run_huffman_length_bench_csv.addArgs(&.{ "--iterations", "4096", "--csv", "zig-out/vort-huffman-length-bench.csv" });
    const huffman_length_bench_gate = b.addSystemCommand(&.{
        "python3",
        "tools/huffman_length_bench_gate.py",
        "--csv",
        "zig-out/vort-huffman-length-bench.csv",
    });
    huffman_length_bench_gate.step.dependOn(&run_huffman_length_bench_csv.step);
    const huffman_length_bench_gate_step = b.step("run-huffman-length-bench-gate", "Require Huffman code-length construction speedups");
    huffman_length_bench_gate_step.dependOn(&huffman_length_bench_gate.step);

    const deflate_code_length_rle_bench_exe = b.addExecutable(.{
        .name = "vort-deflate-code-length-rle-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/deflate_code_length_rle_bench.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "code_length_rle", .module = b.createModule(.{
                    .root_source_file = b.path("src/deflate/dynamic/code_length_rle.zig"),
                    .target = target,
                    .optimize = optimize,
                }) },
            },
        }),
    });
    const run_deflate_code_length_rle_bench = b.addRunArtifact(deflate_code_length_rle_bench_exe);
    if (b.args) |args| run_deflate_code_length_rle_bench.addArgs(args);
    const deflate_code_length_rle_bench_step = b.step("bench-deflate-code-length-rle", "Benchmark fused dynamic-header code-length RLE planning");
    deflate_code_length_rle_bench_step.dependOn(&run_deflate_code_length_rle_bench.step);

    const run_deflate_code_length_rle_bench_csv = b.addRunArtifact(deflate_code_length_rle_bench_exe);
    run_deflate_code_length_rle_bench_csv.addArgs(&.{ "--iterations", "100000", "--csv", "zig-out/vort-deflate-code-length-rle-bench.csv" });
    const deflate_code_length_rle_bench_gate = b.addSystemCommand(&.{
        "python3",
        "tools/deflate_code_length_rle_bench_gate.py",
        "--csv",
        "zig-out/vort-deflate-code-length-rle-bench.csv",
    });
    deflate_code_length_rle_bench_gate.step.dependOn(&run_deflate_code_length_rle_bench_csv.step);
    const deflate_code_length_rle_bench_gate_step = b.step("run-deflate-code-length-rle-bench-gate", "Require fused dynamic-header RLE speedups");
    deflate_code_length_rle_bench_gate_step.dependOn(&deflate_code_length_rle_bench_gate.step);

    const deflate_huffman_lookup_bench_exe = b.addExecutable(.{
        .name = "vort-deflate-huffman-lookup-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/deflate_huffman_lookup_bench.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_deflate_huffman_lookup_bench_csv = b.addRunArtifact(deflate_huffman_lookup_bench_exe);
    run_deflate_huffman_lookup_bench_csv.addArgs(&.{ "--csv", "zig-out/vort-deflate-huffman-lookup-bench.csv" });
    const deflate_huffman_lookup_bench_csv_step = b.step("run-deflate-huffman-lookup-bench-csv", "Write focused DEFLATE Huffman lookup benchmark CSV");
    deflate_huffman_lookup_bench_csv_step.dependOn(&run_deflate_huffman_lookup_bench_csv.step);

    const deflate_huffman_lookup_bench_gate = b.addSystemCommand(&.{
        "python3",
        "tools/deflate_huffman_lookup_bench_gate.py",
        "--csv",
        "zig-out/vort-deflate-huffman-lookup-bench.csv",
    });
    deflate_huffman_lookup_bench_gate.step.dependOn(deflate_huffman_lookup_bench_csv_step);
    const deflate_huffman_lookup_bench_gate_step = b.step("run-deflate-huffman-lookup-bench-gate", "Validate DEFLATE Huffman lookup benchmark CSV");
    deflate_huffman_lookup_bench_gate_step.dependOn(&deflate_huffman_lookup_bench_gate.step);

    const deflate_chunked_huffman_bench_exe = b.addExecutable(.{
        .name = "vort-deflate-chunked-huffman-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/deflate_chunked_huffman_bench.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_deflate_chunked_huffman_bench_csv = b.addRunArtifact(deflate_chunked_huffman_bench_exe);
    run_deflate_chunked_huffman_bench_csv.addArgs(&.{ "--csv", "zig-out/vort-deflate-chunked-huffman-bench.csv" });
    const deflate_chunked_huffman_bench_csv_step = b.step("run-deflate-chunked-huffman-bench-csv", "Write chunked Huffman decode benchmark CSV");
    deflate_chunked_huffman_bench_csv_step.dependOn(&run_deflate_chunked_huffman_bench_csv.step);

    const deflate_chunked_huffman_bench_gate = b.addSystemCommand(&.{
        "python3",
        "tools/deflate_chunked_huffman_bench_gate.py",
        "--csv",
        "zig-out/vort-deflate-chunked-huffman-bench.csv",
    });
    deflate_chunked_huffman_bench_gate.step.dependOn(deflate_chunked_huffman_bench_csv_step);
    const deflate_chunked_huffman_bench_gate_step = b.step("run-deflate-chunked-huffman-bench-gate", "Validate chunked Huffman decode benchmark CSV");
    deflate_chunked_huffman_bench_gate_step.dependOn(&deflate_chunked_huffman_bench_gate.step);

    const deflate_match_copy_bench_exe = b.addExecutable(.{
        .name = "vort-deflate-match-copy-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/deflate_match_copy_bench.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_deflate_match_copy_bench_csv = b.addRunArtifact(deflate_match_copy_bench_exe);
    run_deflate_match_copy_bench_csv.addArgs(&.{ "--csv", "zig-out/vort-deflate-match-copy-bench.csv" });
    const deflate_match_copy_bench_csv_step = b.step("run-deflate-match-copy-bench-csv", "Write focused DEFLATE match-copy microbenchmark CSV");
    deflate_match_copy_bench_csv_step.dependOn(&run_deflate_match_copy_bench_csv.step);

    const deflate_match_copy_bench_gate = b.addSystemCommand(&.{
        "python3",
        "tools/deflate_match_copy_bench_gate.py",
        "--csv",
        "zig-out/vort-deflate-match-copy-bench.csv",
    });
    deflate_match_copy_bench_gate.step.dependOn(deflate_match_copy_bench_csv_step);
    const deflate_match_copy_bench_gate_step = b.step("run-deflate-match-copy-bench-gate", "Validate DEFLATE match-copy microbenchmark CSV");
    deflate_match_copy_bench_gate_step.dependOn(&deflate_match_copy_bench_gate.step);

    const deflate_extra_bits_bench_exe = b.addExecutable(.{
        .name = "vort-deflate-extra-bits-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/deflate_extra_bits_bench.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_deflate_extra_bits_bench_csv = b.addRunArtifact(deflate_extra_bits_bench_exe);
    run_deflate_extra_bits_bench_csv.addArgs(&.{ "--repeat", "3", "--csv", "zig-out/vort-deflate-extra-bits-bench.csv" });
    const deflate_extra_bits_bench_csv_step = b.step("run-deflate-extra-bits-bench-csv", "Write focused DEFLATE extra-bit reader benchmark CSV");
    deflate_extra_bits_bench_csv_step.dependOn(&run_deflate_extra_bits_bench_csv.step);

    const deflate_extra_bits_bench_gate = b.addSystemCommand(&.{
        "python3",
        "tools/deflate_extra_bits_bench_gate.py",
        "--csv",
        "zig-out/vort-deflate-extra-bits-bench.csv",
    });
    deflate_extra_bits_bench_gate.step.dependOn(deflate_extra_bits_bench_csv_step);
    const deflate_extra_bits_bench_gate_step = b.step("run-deflate-extra-bits-bench-gate", "Validate DEFLATE extra-bit reader benchmark CSV");
    deflate_extra_bits_bench_gate_step.dependOn(&deflate_extra_bits_bench_gate.step);

    const chunk_cursor_bench_exe = b.addExecutable(.{
        .name = "vort-chunk-cursor-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/chunk_cursor_bench.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_chunk_cursor_bench_csv = b.addRunArtifact(chunk_cursor_bench_exe);
    run_chunk_cursor_bench_csv.addArgs(&.{ "--csv", "zig-out/vort-chunk-cursor-bench.csv" });
    const chunk_cursor_bench_csv_step = b.step("run-chunk-cursor-bench-csv", "Write focused chunk cursor microbenchmark CSV");
    chunk_cursor_bench_csv_step.dependOn(&run_chunk_cursor_bench_csv.step);

    const chunk_cursor_bench_gate = b.addSystemCommand(&.{
        "python3",
        "tools/chunk_cursor_bench_gate.py",
        "--csv",
        "zig-out/vort-chunk-cursor-bench.csv",
    });
    chunk_cursor_bench_gate.step.dependOn(chunk_cursor_bench_csv_step);
    const chunk_cursor_bench_gate_step = b.step("run-chunk-cursor-bench-gate", "Validate chunk cursor microbenchmark CSV");
    chunk_cursor_bench_gate_step.dependOn(&chunk_cursor_bench_gate.step);

    const chunked_zlib_bench_report_exe = b.addExecutable(.{
        .name = "vort-chunked-zlib-bench-report",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/chunked_zlib_bench_report.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_chunked_zlib_bench_report = b.addRunArtifact(chunked_zlib_bench_report_exe);
    if (b.args) |args| run_chunked_zlib_bench_report.addArgs(args);
    const chunked_zlib_bench_report_step = b.step("run-chunked-zlib-bench-report", "Report contiguous vs chunked zlib decode throughput");
    chunked_zlib_bench_report_step.dependOn(&run_chunked_zlib_bench_report.step);

    const run_chunked_zlib_bench_report_csv = b.addRunArtifact(chunked_zlib_bench_report_exe);
    run_chunked_zlib_bench_report_csv.addArgs(&.{ "--csv", "zig-out/vort-chunked-zlib-bench-report.csv" });
    const chunked_zlib_bench_report_csv_step = b.step("run-chunked-zlib-bench-report-csv", "Write contiguous vs chunked zlib decode throughput CSV to zig-out");
    chunked_zlib_bench_report_csv_step.dependOn(&run_chunked_zlib_bench_report_csv.step);

    const run_chunked_zlib_bench_report_csv_repeat3 = b.addRunArtifact(chunked_zlib_bench_report_exe);
    run_chunked_zlib_bench_report_csv_repeat3.addArgs(&.{ "--repeat", "3", "--csv", "zig-out/vort-chunked-zlib-bench-report-repeat3.csv" });
    const chunked_zlib_bench_report_csv_repeat3_step = b.step("run-chunked-zlib-bench-report-csv-repeat3", "Write median-of-3 contiguous vs chunked zlib decode throughput CSV to zig-out");
    chunked_zlib_bench_report_csv_repeat3_step.dependOn(&run_chunked_zlib_bench_report_csv_repeat3.step);

    const run_chunked_zlib_bench_report_dashboard = b.addRunArtifact(chunked_zlib_bench_report_exe);
    run_chunked_zlib_bench_report_dashboard.addArgs(&.{ "--repeat", "3", "--csv", "zig-out/vort-chunked-zlib-bench-report-repeat3.csv", "--markdown", "zig-out/vort-chunked-zlib-bench-report.md" });
    const chunked_zlib_bench_report_dashboard_step = b.step("run-chunked-zlib-bench-report-dashboard", "Write repeat3 contiguous vs chunked zlib decode dashboard artifacts");
    chunked_zlib_bench_report_dashboard_step.dependOn(&run_chunked_zlib_bench_report_dashboard.step);

    const chunked_zlib_bench_report_gate = b.addSystemCommand(&.{
        "python3",
        "tools/chunked_zlib_bench_gate.py",
        "--csv",
        "zig-out/vort-chunked-zlib-bench-report-repeat3.csv",
    });
    chunked_zlib_bench_report_gate.step.dependOn(chunked_zlib_bench_report_dashboard_step);
    const chunked_zlib_bench_report_gate_step = b.step("run-chunked-zlib-bench-report-gate", "Validate repeat3 contiguous vs chunked zlib decode throughput CSV");
    chunked_zlib_bench_report_gate_step.dependOn(&chunked_zlib_bench_report_gate.step);

    const png_streaming_zlib_bench_report_exe = b.addExecutable(.{
        .name = "vort-png-streaming-zlib-bench-report",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/png_streaming_zlib_bench_report.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_png_streaming_zlib_bench_report = b.addRunArtifact(png_streaming_zlib_bench_report_exe);
    if (b.args) |args| run_png_streaming_zlib_bench_report.addArgs(args);
    const png_streaming_zlib_bench_report_step = b.step("run-png-streaming-zlib-bench-report", "Report PNG streaming zlib scanline throughput");
    png_streaming_zlib_bench_report_step.dependOn(&run_png_streaming_zlib_bench_report.step);

    const run_png_streaming_zlib_bench_report_csv_repeat3 = b.addRunArtifact(png_streaming_zlib_bench_report_exe);
    run_png_streaming_zlib_bench_report_csv_repeat3.addArgs(&.{ "--repeat", "3", "--csv", "zig-out/vort-png-streaming-zlib-bench-report-repeat3.csv" });
    const png_streaming_zlib_bench_report_csv_repeat3_step = b.step("run-png-streaming-zlib-bench-report-csv-repeat3", "Write repeat3 PNG streaming zlib scanline throughput CSV");
    png_streaming_zlib_bench_report_csv_repeat3_step.dependOn(&run_png_streaming_zlib_bench_report_csv_repeat3.step);

    const png_streaming_zlib_bench_report_gate = b.addSystemCommand(&.{
        "python3",
        "tools/png_streaming_zlib_bench_gate.py",
        "--csv",
        "zig-out/vort-png-streaming-zlib-bench-report-repeat3.csv",
    });
    if (optimize == .ReleaseFast) png_streaming_zlib_bench_report_gate.addArg("--enforce-throughput");
    png_streaming_zlib_bench_report_gate.step.dependOn(png_streaming_zlib_bench_report_csv_repeat3_step);
    const png_streaming_zlib_bench_report_gate_step = b.step("run-png-streaming-zlib-bench-report-gate", "Validate repeat3 PNG streaming zlib scanline throughput CSV");
    png_streaming_zlib_bench_report_gate_step.dependOn(&png_streaming_zlib_bench_report_gate.step);

    const png_scanline_bench_exe = b.addExecutable(.{
        .name = "vort-png-scanline-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/png_scanline_bench.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_png_scanline_bench_csv = b.addRunArtifact(png_scanline_bench_exe);
    run_png_scanline_bench_csv.addArgs(&.{ "--csv", "zig-out/vort-png-scanline-bench.csv" });
    if (optimize == .ReleaseFast) run_png_scanline_bench_csv.addArgs(&.{ "--repeat", "3" });
    const png_scanline_bench_csv_step = b.step("run-png-scanline-bench-csv", "Write focused PNG scanline reconstruction benchmark CSV");
    png_scanline_bench_csv_step.dependOn(&run_png_scanline_bench_csv.step);

    const png_scanline_bench_gate = b.addSystemCommand(&.{
        "python3",
        "tools/png_scanline_bench_gate.py",
        "--csv",
        "zig-out/vort-png-scanline-bench.csv",
    });
    if (optimize == .ReleaseFast) png_scanline_bench_gate.addArgs(&.{ "--enforce-throughput", "--min-repeat", "3" });
    png_scanline_bench_gate.step.dependOn(png_scanline_bench_csv_step);
    const png_scanline_bench_gate_step = b.step("run-png-scanline-bench-gate", "Validate focused PNG scanline reconstruction benchmark CSV");
    png_scanline_bench_gate_step.dependOn(&png_scanline_bench_gate.step);

    const zlib_relaxed_report_exe = b.addExecutable(.{
        .name = "vort-zlib-relaxed-report",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/zlib_relaxed_report.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });

    const run_zlib_relaxed_report = b.addRunArtifact(zlib_relaxed_report_exe);
    run_zlib_relaxed_report.addArgs(&.{ "--json", "zig-out/vort-zlib-relaxed-report.json", "--markdown", "zig-out/vort-zlib-relaxed-report.md" });
    const zlib_relaxed_report_step = b.step("run-zlib-relaxed-report", "Write zlib/gzip relaxed decode options JSON report");
    zlib_relaxed_report_step.dependOn(&run_zlib_relaxed_report.step);

    const zlib_relaxed_report_gate = b.addSystemCommand(&.{
        "python3",
        "tools/zlib_relaxed_report_gate.py",
        "--summary",
        "zig-out/vort-zlib-relaxed-report-gate.json",
    });
    zlib_relaxed_report_gate.step.dependOn(zlib_relaxed_report_step);
    const zlib_relaxed_report_gate_step = b.step("run-zlib-relaxed-report-gate", "Validate zlib/gzip relaxed decode options report budgets");
    zlib_relaxed_report_gate_step.dependOn(&zlib_relaxed_report_gate.step);

    const zlib_encode_bench_exe = b.addExecutable(.{
        .name = "vort-zlib-encode-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/zlib_encode_bench.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod_releasefast },
                .{ .name = "benchmark_provenance", .module = benchmark_provenance_mod },
            },
        }),
    });

    const deflate_encode_bench_exe = b.addExecutable(.{
        .name = "vort-bench-deflate-encode",
        .root_module = b.createModule(.{
            .root_source_file = b.path("bench/deflate_encode.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });

    const run_deflate_encode_bench = b.addRunArtifact(deflate_encode_bench_exe);
    if (b.args) |args| run_deflate_encode_bench.addArgs(args);
    const deflate_encode_bench_step = b.step("bench-deflate-encode", "Run fixed deflate encode throughput smoke benchmark");
    deflate_encode_bench_step.dependOn(&run_deflate_encode_bench.step);

    const zlib_ng_root = b.option([]const u8, "zlib-ng-root", "Use a zlib-ng compat build for the incremental DEFLATE benchmark");
    const deflate_incremental_encode_bench_exe = b.addExecutable(.{
        .name = "vort-bench-deflate-incremental-encode",
        .root_module = b.createModule(.{
            .root_source_file = b.path("bench/deflate/incremental_encode.zig"),
            .target = target,
            // Performance gates must not silently benchmark Debug when the
            // caller omits -Doptimize. Keep this dedicated artifact fixed.
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod_releasefast },
            },
        }),
    });
    const deflate_incremental_decode_bench_exe = b.addExecutable(.{
        .name = "vort-bench-deflate-incremental-decode",
        .root_module = b.createModule(.{
            .root_source_file = b.path("bench/deflate/incremental_decode.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod_releasefast },
            },
        }),
    });
    const zlib_translate = b.addTranslateC(.{
        .root_source_file = if (zlib_ng_root) |root| .{ .cwd_relative = b.pathJoin(&.{ root, "build/zlib.h" }) } else b.path("bench/deflate/zlib_compat.h"),
        .target = target,
        .optimize = .ReleaseFast,
    });
    if (zlib_ng_root) |root| {
        zlib_translate.addIncludePath(.{ .cwd_relative = b.pathJoin(&.{ root, "build" }) });
        zlib_translate.defineCMacro("VORT_ZLIB_BENCH_NAME", "\"zlib-ng-2.3.90-level6\"");
        deflate_incremental_encode_bench_exe.root_module.addObjectFile(.{ .cwd_relative = b.pathJoin(&.{ root, "build/libz.a" }) });
        deflate_incremental_decode_bench_exe.root_module.addObjectFile(.{ .cwd_relative = b.pathJoin(&.{ root, "build/libz.a" }) });
    } else {
        zlib_translate.linkSystemLibrary("z", .{});
        zlib_translate.defineCMacro("VORT_ZLIB_BENCH_NAME", "\"zlib-1.3-level6\"");
        deflate_incremental_encode_bench_exe.root_module.linkSystemLibrary("z", .{});
        deflate_incremental_decode_bench_exe.root_module.linkSystemLibrary("z", .{});
    }
    const zlib_compat_mod = zlib_translate.createModule();
    deflate_incremental_encode_bench_exe.root_module.addImport("zlib", zlib_compat_mod);
    deflate_incremental_decode_bench_exe.root_module.addImport("zlib", zlib_compat_mod);
    const run_deflate_incremental_encode_bench = b.addRunArtifact(deflate_incremental_encode_bench_exe);
    if (b.args) |args| run_deflate_incremental_encode_bench.addArgs(args);
    const deflate_incremental_encode_bench_step = b.step("bench-deflate-incremental-encode", "Compare persistent and rebuilt incremental DEFLATE match indexes");
    deflate_incremental_encode_bench_step.dependOn(&run_deflate_incremental_encode_bench.step);

    const run_deflate_incremental_decode_bench = b.addRunArtifact(deflate_incremental_decode_bench_exe);
    if (b.args) |args| run_deflate_incremental_decode_bench.addArgs(args);
    const deflate_incremental_decode_bench_step = b.step("bench-deflate-incremental-decode", "Compare reusable Vort and zlib incremental gzip decode");
    deflate_incremental_decode_bench_step.dependOn(&run_deflate_incremental_decode_bench.step);

    const deflate_incremental_decode_gate = b.addSystemCommand(&.{
        "python3",
        "tools/deflate_incremental_decode_gate.py",
    });
    const run_deflate_incremental_decode_gate_bench = b.addRunArtifact(deflate_incremental_decode_bench_exe);
    run_deflate_incremental_decode_gate_bench.addArg("200");
    deflate_incremental_decode_gate.addArg("--csv");
    deflate_incremental_decode_gate.addFileArg(run_deflate_incremental_decode_gate_bench.captureStdOut(.{}));
    deflate_incremental_decode_gate.addArg("--expect-competitor");
    deflate_incremental_decode_gate.addArg(if (zlib_ng_root != null) "zlib-ng" else "zlib");
    const deflate_incremental_decode_gate_step = b.step("run-deflate-incremental-decode-gate", "Validate reusable Vort/zlib incremental gzip decode coverage and regression bounds");
    deflate_incremental_decode_gate_step.dependOn(&deflate_incremental_decode_gate.step);

    const deflate_incremental_encode_gate = b.addSystemCommand(&.{
        "python3",
        "tools/deflate_incremental_encode_gate.py",
    });
    const run_deflate_incremental_encode_gate_bench = b.addRunArtifact(deflate_incremental_encode_bench_exe);
    run_deflate_incremental_encode_gate_bench.addArg("32");
    const deflate_incremental_encode_gate_output = run_deflate_incremental_encode_gate_bench.captureStdOut(.{});
    deflate_incremental_encode_gate.addArg("--csv");
    deflate_incremental_encode_gate.addFileArg(deflate_incremental_encode_gate_output);
    deflate_incremental_encode_gate.addArg("--expect-competitor");
    deflate_incremental_encode_gate.addArg(if (zlib_ng_root != null) "zlib-ng" else "zlib");
    const deflate_incremental_encode_gate_step = b.step("run-deflate-incremental-encode-gate", "Require persistent lazy DEFLATE speed and size non-regression");
    deflate_incremental_encode_gate_step.dependOn(&deflate_incremental_encode_gate.step);

    const native_parallel_bench_exe = b.addExecutable(.{
        .name = "vort-bench-native-parallel",
        .root_module = b.createModule(.{
            .root_source_file = b.path("bench/native_parallel.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_native_parallel_bench = b.addRunArtifact(native_parallel_bench_exe);
    if (b.args) |args| run_native_parallel_bench.addArgs(args);
    const native_parallel_bench_step = b.step("bench-native-parallel", "Compare native planned/parallel/thread-pool/work-queue encoders");
    native_parallel_bench_step.dependOn(&run_native_parallel_bench.step);

    const native_parallel_corpus_report = b.addSystemCommand(&.{ "python3", "tools/native_parallel_corpus_report.py" });
    native_parallel_corpus_report.addArtifactArg(native_parallel_bench_exe);
    if (b.args) |args| native_parallel_corpus_report.addArgs(args);
    const native_parallel_corpus_report_step = b.step("run-native-parallel-corpus-report", "Run native parallel/thread-pool benchmark across Silesia files");
    native_parallel_corpus_report_step.dependOn(&native_parallel_corpus_report.step);

    const native_parallel_dashboard = b.addSystemCommand(&.{ "python3", "tools/native_parallel_corpus_report.py" });
    native_parallel_dashboard.addArtifactArg(native_parallel_bench_exe);
    native_parallel_dashboard.addArgs(&.{ "--markdown", "zig-out/vort-native-parallel-dashboard.md" });
    if (b.args) |args| native_parallel_dashboard.addArgs(args);
    const native_parallel_dashboard_step = b.step("run-native-parallel-dashboard", "Write native parallel Silesia benchmark dashboard to zig-out");
    native_parallel_dashboard_step.dependOn(&native_parallel_dashboard.step);

    const native_parallel_full_dashboard = b.addSystemCommand(&.{ "python3", "tools/native_parallel_corpus_report.py" });
    native_parallel_full_dashboard.addArtifactArg(native_parallel_bench_exe);
    native_parallel_full_dashboard.addArgs(&.{ "--full", "--markdown", "zig-out/vort-native-parallel-full-dashboard.md" });
    if (b.args) |args| native_parallel_full_dashboard.addArgs(args);
    const native_parallel_full_dashboard_step = b.step("run-native-parallel-full-dashboard", "Write full native parallel Silesia benchmark dashboard to zig-out");
    native_parallel_full_dashboard_step.dependOn(&native_parallel_full_dashboard.step);

    const native_parallel_multi_dashboard = b.addSystemCommand(&.{ "python3", "tools/native_parallel_corpus_report.py" });
    native_parallel_multi_dashboard.addArtifactArg(native_parallel_bench_exe);
    native_parallel_multi_dashboard.addArgs(&.{ "--standard-suite", "--markdown", "zig-out/vort-native-parallel-multi-corpus-dashboard.md" });
    if (b.args) |args| native_parallel_multi_dashboard.addArgs(args);
    const native_parallel_multi_dashboard_step = b.step("run-native-parallel-multi-corpus-dashboard", "Discover standard corpora and write native parallel benchmark dashboard to zig-out");
    native_parallel_multi_dashboard_step.dependOn(&native_parallel_multi_dashboard.step);

    const native_parallel_multi_full_dashboard = b.addSystemCommand(&.{ "python3", "tools/native_parallel_corpus_report.py" });
    native_parallel_multi_full_dashboard.addArtifactArg(native_parallel_bench_exe);
    native_parallel_multi_full_dashboard.addArgs(&.{ "--standard-suite", "--full", "--markdown", "zig-out/vort-native-parallel-multi-corpus-full-dashboard.md" });
    if (b.args) |args| native_parallel_multi_full_dashboard.addArgs(args);
    const native_parallel_multi_full_dashboard_step = b.step("run-native-parallel-multi-corpus-full-dashboard", "Discover standard corpora and write full native parallel benchmark dashboard to zig-out");
    native_parallel_multi_full_dashboard_step.dependOn(&native_parallel_multi_full_dashboard.step);

    const native_thread_pool_full_dashboard = b.addSystemCommand(&.{ "python3", "tools/native_parallel_corpus_report.py" });
    native_thread_pool_full_dashboard.addArtifactArg(native_parallel_bench_exe);
    native_thread_pool_full_dashboard.addArgs(&.{ "--standard-suite", "--full", "--modes", "thread_pool", "--markdown", "zig-out/vort-native-thread-pool-full-dashboard.md" });
    if (b.args) |args| native_thread_pool_full_dashboard.addArgs(args);
    const native_thread_pool_full_dashboard_step = b.step("run-native-thread-pool-full-dashboard", "Write full standard-corpus native thread-pool benchmark dashboard to zig-out");
    native_thread_pool_full_dashboard_step.dependOn(&native_thread_pool_full_dashboard.step);

    const fuzz_smoke_exe = b.addExecutable(.{
        .name = "vort-fuzz-smoke",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/fuzz_smoke.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });

    const run_fuzz_smoke = b.addRunArtifact(fuzz_smoke_exe);
    const fuzz_smoke_step = b.step("run-fuzz-smoke", "Run deterministic malformed-frame smoke corpus");
    fuzz_smoke_step.dependOn(&run_fuzz_smoke.step);

    const fuzz_corpus_exe = b.addExecutable(.{
        .name = "vort-fuzz-corpus",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/fuzz_corpus.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });

    const run_fuzz_corpus = b.addRunArtifact(fuzz_corpus_exe);
    if (b.args) |args| run_fuzz_corpus.addArgs(args);
    const fuzz_corpus_step = b.step("run-fuzz-corpus", "Run extensible hex-sample fuzz corpus harness");
    fuzz_corpus_step.dependOn(&run_fuzz_corpus.step);

    const run_deflate_wrapper_fuzz_corpus = b.addRunArtifact(fuzz_corpus_exe);
    run_deflate_wrapper_fuzz_corpus.addArgs(&.{ "--file", "corpus/deflate-wrapper-smoke.hex" });
    const deflate_wrapper_fuzz_corpus_step = b.step("run-deflate-wrapper-fuzz-corpus", "Run raw/zlib/gzip wrapper hex-sample fuzz corpus");
    deflate_wrapper_fuzz_corpus_step.dependOn(&run_deflate_wrapper_fuzz_corpus.step);

    const run_native_fuzz_corpus = b.addRunArtifact(fuzz_corpus_exe);
    run_native_fuzz_corpus.addArgs(&.{ "--file", "corpus/native-smoke.hex" });
    const native_fuzz_corpus_step = b.step("run-native-fuzz-corpus", "Run native VORT hex-sample fuzz corpus");
    native_fuzz_corpus_step.dependOn(&run_native_fuzz_corpus.step);

    const run_native_fuzz_corpus_dashboard = b.addRunArtifact(fuzz_corpus_exe);
    run_native_fuzz_corpus_dashboard.addArgs(&.{
        "--file",
        "corpus/native-smoke.hex",
        "--json",
        "zig-out/vort-native-fuzz-corpus.json",
        "--markdown",
        "zig-out/vort-native-fuzz-corpus.md",
    });
    const native_fuzz_corpus_dashboard_step = b.step("run-native-fuzz-corpus-dashboard", "Write native VORT fuzz corpus dashboard artifacts");
    native_fuzz_corpus_dashboard_step.dependOn(&run_native_fuzz_corpus_dashboard.step);

    const run_deflate_wrapper_fuzz_corpus_dashboard = b.addRunArtifact(fuzz_corpus_exe);
    run_deflate_wrapper_fuzz_corpus_dashboard.addArgs(&.{
        "--file",
        "corpus/deflate-wrapper-smoke.hex",
        "--json",
        "zig-out/vort-deflate-wrapper-fuzz-corpus.json",
        "--markdown",
        "zig-out/vort-deflate-wrapper-fuzz-corpus.md",
    });
    const deflate_wrapper_fuzz_corpus_dashboard_step = b.step("run-deflate-wrapper-fuzz-corpus-dashboard", "Write raw/zlib/gzip wrapper fuzz corpus dashboard artifacts");
    deflate_wrapper_fuzz_corpus_dashboard_step.dependOn(&run_deflate_wrapper_fuzz_corpus_dashboard.step);

    const fuzz_corpus_coverage_smoke = b.addSystemCommand(&.{ "python3", "tools/fuzz_corpus_coverage_smoke.py", "--summary", "zig-out/vort-fuzz-corpus-coverage-smoke.json" });
    fuzz_corpus_coverage_smoke.step.dependOn(deflate_wrapper_fuzz_corpus_dashboard_step);
    const fuzz_corpus_coverage_smoke_step = b.step("run-fuzz-corpus-coverage-smoke", "Validate wrapper fuzz corpus coverage minimums");
    fuzz_corpus_coverage_smoke_step.dependOn(&fuzz_corpus_coverage_smoke.step);

    const native_fuzz_corpus_coverage_smoke = b.addSystemCommand(&.{
        "python3",
        "tools/fuzz_corpus_coverage_smoke.py",
        "--report",
        "zig-out/vort-native-fuzz-corpus.json",
        "--coverage",
        "tools/native_fuzz_corpus_expected_coverage.json",
        "--summary",
        "zig-out/vort-native-fuzz-corpus-coverage-smoke.json",
    });
    native_fuzz_corpus_coverage_smoke.step.dependOn(native_fuzz_corpus_dashboard_step);
    const native_fuzz_corpus_coverage_smoke_step = b.step("run-native-fuzz-corpus-coverage-smoke", "Validate native fuzz corpus coverage minimums");
    native_fuzz_corpus_coverage_smoke_step.dependOn(&native_fuzz_corpus_coverage_smoke.step);

    const fuzz_target_exe = b.addExecutable(.{
        .name = "vort-fuzz-target",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/fuzz_target.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_fuzz_target = b.addRunArtifact(fuzz_target_exe);
    const fuzz_target_step = b.step("run-fuzz-target", "Run raw-byte parser fuzz target smoke");
    fuzz_target_step.dependOn(&run_fuzz_target.step);

    const libfuzzer_smoke_exe = b.addExecutable(.{
        .name = "vort-libfuzzer-smoke",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/fuzz_libfuzzer.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_libfuzzer_smoke = b.addRunArtifact(libfuzzer_smoke_exe);
    const libfuzzer_smoke_step = b.step("run-libfuzzer-smoke", "Run exported LLVMFuzzerTestOneInput smoke");
    libfuzzer_smoke_step.dependOn(&run_libfuzzer_smoke.step);

    const afl_smoke_exe = b.addExecutable(.{
        .name = "vort-afl-smoke",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/fuzz_afl.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_afl_smoke = b.addRunArtifact(afl_smoke_exe);
    if (b.args) |args| run_afl_smoke.addArgs(args);
    const afl_smoke_step = b.step("run-afl-smoke", "Run AFL-style file-input fuzz driver smoke");
    afl_smoke_step.dependOn(&run_afl_smoke.step);

    const checksum_diff_exe = b.addExecutable(.{
        .name = "vort-checksum-diff",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/checksum_diff.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });

    const run_checksum_diff = b.addRunArtifact(checksum_diff_exe);
    const checksum_diff_step = b.step("run-checksum-diff", "Run checksum differential smoke against Zig std reference hashes");
    checksum_diff_step.dependOn(&run_checksum_diff.step);

    const checksum_zlib_diff = b.addSystemCommand(&.{ "python3", "tools/checksum_zlib_diff.py" });
    checksum_zlib_diff.addArtifactArg(cli_exe);
    const checksum_zlib_diff_step = b.step("run-checksum-zlib-diff", "Run checksum differential smoke against Python zlib and system gzip trailers");
    checksum_zlib_diff_step.dependOn(&checksum_zlib_diff.step);

    const zlib_diff_exe = b.addExecutable(.{
        .name = "vort-zlib-diff",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/zlib_diff.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });

    const run_zlib_diff = b.addRunArtifact(zlib_diff_exe);
    const zlib_diff_step = b.step("run-zlib-diff", "Run zlib stored-deflate wrapper smoke");
    zlib_diff_step.dependOn(&run_zlib_diff.step);

    const gzip_diff_exe = b.addExecutable(.{
        .name = "vort-gzip-diff",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/gzip_diff.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });

    const run_gzip_diff = b.addRunArtifact(gzip_diff_exe);
    const gzip_diff_step = b.step("run-gzip-diff", "Run gzip stored-deflate wrapper smoke");
    gzip_diff_step.dependOn(&run_gzip_diff.step);

    const python_zlib_diff = b.addSystemCommand(&.{ "python3", "tools/python_zlib_diff.py" });
    python_zlib_diff.addArtifactArg(cli_exe);
    const python_zlib_diff_step = b.step("run-python-zlib-diff", "Run black-box differential smoke against Python zlib");
    python_zlib_diff_step.dependOn(&python_zlib_diff.step);

    const python_zlib_diff_dashboard = b.addSystemCommand(&.{ "python3", "tools/python_zlib_diff.py" });
    python_zlib_diff_dashboard.addArtifactArg(cli_exe);
    python_zlib_diff_dashboard.addArgs(&.{ "--summary", "zig-out/vort-python-zlib-diff-smoke.json" });
    const python_zlib_diff_dashboard_step = b.step("run-python-zlib-diff-dashboard", "Write Python zlib differential smoke summary to zig-out");
    python_zlib_diff_dashboard_step.dependOn(&python_zlib_diff_dashboard.step);

    const gzip_cli_diff = b.addSystemCommand(&.{ "python3", "tools/gzip_cli_diff.py" });
    gzip_cli_diff.addArtifactArg(cli_exe);
    const gzip_cli_diff_step = b.step("run-gzip-cli-diff", "Run black-box differential smoke against system gzip CLI");
    gzip_cli_diff_step.dependOn(&gzip_cli_diff.step);

    const bgzf_diff = b.addSystemCommand(&.{ "python3", "tools/bgzf/diff.py", "--cli" });
    bgzf_diff.addArtifactArg(cli_exe);
    if (b.args) |args| bgzf_diff.addArgs(args);
    const bgzf_diff_step = b.step("run-bgzf-diff", "Validate blocked gzip/BGZF against Python zlib and optional gzip");
    bgzf_diff_step.dependOn(&bgzf_diff.step);

    const snappy_framing_diff = b.addSystemCommand(&.{ "python3", "tools/snappy_framing/diff.py", "--cli" });
    snappy_framing_diff.addArtifactArg(cli_exe);
    if (b.args) |args| snappy_framing_diff.addArgs(args);
    const snappy_framing_diff_step = b.step("run-snappy-framing-diff", "Validate Xerial and Hadoop Snappy framing against optional snappy-java");
    snappy_framing_diff_step.dependOn(&snappy_framing_diff.step);

    const hadoop_lz4_diff = b.addSystemCommand(&.{ "python3", "tools/hadoop_lz4/diff.py", "--cli" });
    hadoop_lz4_diff.addArtifactArg(cli_exe);
    const hadoop_lz4_diff_step = b.step("run-hadoop-lz4-diff", "Validate Hadoop LZ4 framing against Python lz4.block");
    hadoop_lz4_diff_step.dependOn(&hadoop_lz4_diff.step);

    const lz4_legacy_diff = b.addSystemCommand(&.{ "python3", "tools/lz4_legacy/diff.py", "--cli" });
    lz4_legacy_diff.addArtifactArg(cli_exe);
    if (b.args) |args| lz4_legacy_diff.addArgs(args);
    const lz4_legacy_diff_step = b.step("run-lz4-legacy-diff", "Validate LZ4 legacy frames against the system lz4 CLI");
    lz4_legacy_diff_step.dependOn(&lz4_legacy_diff.step);

    const lznt1_diff = b.addSystemCommand(&.{ "python3", "tools/lznt1/diff.py", "--cli" });
    lznt1_diff.addArtifactArg(cli_exe);
    if (b.args) |args| lznt1_diff.addArgs(args);
    const lznt1_diff_step = b.step("run-lznt1-diff", "Validate Windows LZNT1 against the optional Python reference");
    lznt1_diff_step.dependOn(&lznt1_diff.step);

    const xpress_diff = b.addSystemCommand(&.{ "python3", "tools/xpress/diff.py", "--cli" });
    xpress_diff.addArtifactArg(cli_exe);
    if (b.args) |args| xpress_diff.addArgs(args);
    const xpress_diff_step = b.step("run-xpress-diff", "Validate Windows XPRESS plain and Huffman against pinned references");
    xpress_diff_step.dependOn(&xpress_diff.step);

    const lzfse_diff = b.addSystemCommand(&.{ "python3", "tools/lzfse/diff.py", "--cli" });
    lzfse_diff.addArtifactArg(cli_exe);
    if (b.args) |args| lzfse_diff.addArgs(args);
    const lzfse_diff_step = b.step("run-lzfse-diff", "Validate LZFSE and LZVN streams against the optional Apple reference CLI");
    lzfse_diff_step.dependOn(&lzfse_diff.step);

    const zchunk_diff = b.addSystemCommand(&.{ "python3", "tools/zchunk/diff.py", "--cli" });
    zchunk_diff.addArtifactArg(cli_exe);
    if (b.args) |args| zchunk_diff.addArgs(args);
    const zchunk_diff_step = b.step("run-zchunk-diff", "Validate zchunk files against optional zck/unzck tools");
    zchunk_diff_step.dependOn(&zchunk_diff.step);

    const squashfs_writer_probe = b.addExecutable(.{
        .name = "vort-squashfs-writer-probe",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/squashfs/writer_probe.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "vort", .module = vort_mod }},
        }),
    });
    const squashfs_diff = b.addSystemCommand(&.{ "python3", "tools/squashfs/diff.py", "--cli" });
    squashfs_diff.addArtifactArg(cli_exe);
    squashfs_diff.addArg("--writer");
    squashfs_diff.addArtifactArg(squashfs_writer_probe);
    if (b.args) |args| squashfs_diff.addArgs(args);
    const squashfs_diff_step = b.step("run-squashfs-diff", "Validate SquashFS extraction against optional squashfs-tools");
    squashfs_diff_step.dependOn(&squashfs_diff.step);

    const erofs_writer_probe = b.addExecutable(.{
        .name = "vort-erofs-writer-probe",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/erofs/writer_probe.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "vort", .module = vort_mod }},
        }),
    });
    const erofs_diff = b.addSystemCommand(&.{ "python3", "tools/erofs/diff.py", "--cli" });
    erofs_diff.addArtifactArg(cli_exe);
    erofs_diff.addArg("--writer");
    erofs_diff.addArtifactArg(erofs_writer_probe);
    if (b.args) |args| erofs_diff.addArgs(args);
    const erofs_diff_step = b.step("run-erofs-diff", "Validate EROFS reading and writing against optional erofs-utils");
    erofs_diff_step.dependOn(&erofs_diff.step);

    const hadoop_lzo_index_diff = b.addSystemCommand(&.{ "python3", "tools/hadoop_lzo_index/diff.py", "--cli" });
    hadoop_lzo_index_diff.addArtifactArg(cli_exe);
    if (b.args) |args| hadoop_lzo_index_diff.addArgs(args);
    const hadoop_lzo_index_diff_step = b.step("run-hadoop-lzo-index-diff", "Validate Hadoop LZO indexes against an independent scanner and optional lzop");
    hadoop_lzo_index_diff_step.dependOn(&hadoop_lzo_index_diff.step);

    const zip_writer_probe_exe = b.addExecutable(.{
        .name = "vort-zip-writer-probe",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/zip/writer_probe.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{.{ .name = "vort", .module = vort_mod_releasefast }},
        }),
    });
    const zip_diff = b.addSystemCommand(&.{ "python3", "tools/zip/diff.py", "--cli" });
    zip_diff.addArtifactArg(cli_exe);
    zip_diff.addArg("--writer");
    zip_diff.addArtifactArg(zip_writer_probe_exe);
    if (b.args) |args| zip_diff.addArgs(args);
    const zip_diff_step = b.step("run-zip-diff", "Validate ZIP32/ZIP64 Reduce, Shrink, Implode, DCL Implode, Deflate64, Bzip2, LZMA, Zstandard, XZ, and PPMd interoperability");
    zip_diff_step.dependOn(&zip_diff.step);

    const bzip2_diff = b.addSystemCommand(&.{ "python3", "tools/bzip2/diff.py", "--cli" });
    bzip2_diff.addArtifactArg(cli_exe);
    const bzip2_diff_step = b.step("run-bzip2-diff", "Validate dependency-free Bzip2 encode/decode against Python bz2");
    bzip2_diff_step.dependOn(&bzip2_diff.step);

    const xz_diff = b.addSystemCommand(&.{ "python3", "tools/xz/diff.py", "--cli" });
    xz_diff.addArtifactArg(cli_exe);
    if (b.args) |args| xz_diff.addArgs(args);
    const xz_diff_step = b.step("run-xz-diff", "Validate XZ/LZMA2 and standard filter interoperability with Python lzma and xz");
    xz_diff_step.dependOn(&xz_diff.step);

    const lzma_diff = b.addSystemCommand(&.{ "python3", "tools/lzma/diff.py", "--cli" });
    lzma_diff.addArtifactArg(cli_exe);
    const lzma_diff_step = b.step("run-lzma-diff", "Validate dependency-free LZMA-Alone encoding and decoding against Python lzma and xz");
    lzma_diff_step.dependOn(&lzma_diff.step);

    const compress_z_diff = b.addSystemCommand(&.{ "python3", "tools/compress_z/diff.py", "--cli" });
    compress_z_diff.addArtifactArg(cli_exe);
    const compress_z_diff_step = b.step("run-compress-z-diff", "Validate Unix compress (.Z) encode/decode interoperability");
    compress_z_diff_step.dependOn(&compress_z_diff.step);

    const lzip_diff = b.addSystemCommand(&.{ "python3", "tools/lzip/diff.py", "--cli" });
    lzip_diff.addArtifactArg(cli_exe);
    const lzip_diff_step = b.step("run-lzip-diff", "Validate lzip encoding and decoding against Python lzma and the optional lzip CLI");
    lzip_diff_step.dependOn(&lzip_diff.step);

    const lzf_diff = b.addSystemCommand(&.{ "python3", "tools/lzf/diff.py", "--cli" });
    lzf_diff.addArtifactArg(cli_exe);
    if (b.args) |args| lzf_diff.addArgs(args);
    const lzf_diff_step = b.step("run-lzf-diff", "Validate raw/framed LZF against the optional upstream lzf CLI");
    lzf_diff_step.dependOn(&lzf_diff.step);

    const lha_diff = b.addSystemCommand(&.{ "python3", "tools/lha/diff.py", "--cli" });
    lha_diff.addArtifactArg(cli_exe);
    if (b.args) |args| lha_diff.addArgs(args);
    const lha_diff_step = b.step("run-lha-diff", "Validate LHA level 0/1/2 and common LH/LArc methods against optional lhasa");
    lha_diff_step.dependOn(&lha_diff.step);

    const ar_writer_probe_exe = b.addExecutable(.{
        .name = "vort-ar-writer-probe",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/ar/writer_probe.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{.{ .name = "vort", .module = vort_mod_releasefast }},
        }),
    });
    const ar_diff = b.addSystemCommand(&.{ "python3", "tools/ar/diff.py", "--cli" });
    ar_diff.addArtifactArg(cli_exe);
    ar_diff.addArg("--writer");
    ar_diff.addArtifactArg(ar_writer_probe_exe);
    if (b.args) |args| ar_diff.addArgs(args);
    const ar_diff_step = b.step("run-ar-diff", "Validate GNU/BSD Unix ar reading and writing against optional GNU ar");
    ar_diff_step.dependOn(&ar_diff.step);

    const deb_diff = b.addSystemCommand(&.{ "python3", "tools/deb/diff.py", "--cli" });
    deb_diff.addArtifactArg(cli_exe);
    if (b.args) |args| deb_diff.addArgs(args);
    const deb_diff_step = b.step("run-deb-diff", "Validate Debian binary package reading and writing against optional dpkg-deb");
    deb_diff_step.dependOn(&deb_diff.step);

    const rpm_diff = b.addSystemCommand(&.{ "python3", "tools/rpm/diff.py", "--cli" });
    rpm_diff.addArtifactArg(cli_exe);
    if (b.args) |args| rpm_diff.addArgs(args);
    const rpm_diff_step = b.step("run-rpm-diff", "Validate RPM header and bounded CPIO payload decoding against optional 7-Zip");
    rpm_diff_step.dependOn(&rpm_diff.step);

    const arj_diff = b.addSystemCommand(&.{ "python3", "tools/arj/diff.py", "--cli" });
    arj_diff.addArtifactArg(cli_exe);
    if (b.args) |args| arj_diff.addArgs(args);
    const arj_diff_step = b.step("run-arj-diff", "Validate ARJ methods 0-4 against optional ARJ and 7-Zip tools");
    arj_diff_step.dependOn(&arj_diff.step);

    const arc_diff = b.addSystemCommand(&.{ "python3", "tools/arc/diff.py", "--cli" });
    arc_diff.addArtifactArg(cli_exe);
    if (b.args) |args| arc_diff.addArgs(args);
    const arc_diff_step = b.step("run-arc-diff", "Validate ARC/PAK methods 1-9 against the optional ARC tool");
    arc_diff_step.dependOn(&arc_diff.step);

    const cpio_writer_probe_exe = b.addExecutable(.{
        .name = "vort-cpio-writer-probe",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/cpio/writer_probe.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{.{ .name = "vort", .module = vort_mod_releasefast }},
        }),
    });
    const cpio_diff = b.addSystemCommand(&.{ "python3", "tools/cpio/diff.py", "--cli" });
    cpio_diff.addArtifactArg(cli_exe);
    cpio_diff.addArg("--writer");
    cpio_diff.addArtifactArg(cpio_writer_probe_exe);
    if (b.args) |args| cpio_diff.addArgs(args);
    const cpio_diff_step = b.step("run-cpio-diff", "Validate CPIO header formats, metadata, and compression wrappers against optional GNU cpio");
    cpio_diff_step.dependOn(&cpio_diff.step);

    const rar_writer_probe_exe = b.addExecutable(.{
        .name = "vort-rar-writer-probe",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/rar/writer_probe.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{.{ .name = "vort", .module = vort_mod_releasefast }},
        }),
    });
    const rar_diff = b.addSystemCommand(&.{ "python3", "tools/rar/diff.py", "--cli" });
    rar_diff.addArtifactArg(cli_exe);
    rar_diff.addArg("--writer");
    rar_diff.addArtifactArg(rar_writer_probe_exe);
    if (b.args) |args| rar_diff.addArgs(args);
    const rar_diff_step = b.step("run-rar-diff", "Validate RAR29/RAR50 writing plus legacy decoding against optional 7-Zip and rars");
    rar_diff_step.dependOn(&rar_diff.step);

    const lzop_diff = b.addSystemCommand(&.{ "python3", "tools/lzop/diff.py", "--cli" });
    lzop_diff.addArtifactArg(cli_exe);
    const lzop_diff_step = b.step("run-lzop-diff", "Validate LZO1X/LZOP encoding and decoding against optional lzop");
    lzop_diff_step.dependOn(&lzop_diff.step);

    const seven_zip_writer_probe_exe = b.addExecutable(.{
        .name = "vort-seven-zip-writer-probe",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/seven_zip/writer_probe.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{.{ .name = "vort", .module = vort_mod_releasefast }},
        }),
    });
    const seven_zip_diff = b.addSystemCommand(&.{ "python3", "tools/seven_zip/diff.py", "--cli" });
    seven_zip_diff.addArtifactArg(cli_exe);
    seven_zip_diff.addArg("--writer");
    seven_zip_diff.addArtifactArg(seven_zip_writer_probe_exe);
    if (b.args) |args| seven_zip_diff.addArgs(args);
    const seven_zip_diff_step = b.step("run-seven-zip-diff", "Validate common 7z codecs and linear filters against 7-Zip");
    seven_zip_diff_step.dependOn(&seven_zip_diff.step);

    const tar_writer_probe_exe = b.addExecutable(.{
        .name = "vort-tar-writer-probe",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/tar/writer_probe.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{.{ .name = "vort", .module = vort_mod_releasefast }},
        }),
    });
    const tar_diff = b.addSystemCommand(&.{ "python3", "tools/tar/diff.py", "--cli" });
    tar_diff.addArtifactArg(cli_exe);
    tar_diff.addArg("--writer");
    tar_diff.addArtifactArg(tar_writer_probe_exe);
    if (b.args) |args| tar_diff.addArgs(args);
    const tar_diff_step = b.step("run-tar-diff", "Validate TAR and common compressed tarballs against Python tarfile, Brotli, lzma, and optional LZF");
    tar_diff_step.dependOn(&tar_diff.step);

    const cab_diff = b.addSystemCommand(&.{ "python3", "tools/cab/diff.py", "--cli" });
    cab_diff.addArtifactArg(cli_exe);
    const cab_diff_step = b.step("run-cab-diff", "Validate CAB writing with libarchive and Stored/MSZIP/LZX/Quantum extraction against libmspack fixtures");
    cab_diff_step.dependOn(&cab_diff.step);

    const br_stored_cli_diff = b.addSystemCommand(&.{ "python3", "tools/br_stored_cli_diff.py" });
    br_stored_cli_diff.addArtifactArg(cli_exe);
    const br_stored_cli_diff_step = b.step("run-br-stored-cli-diff", "Run black-box smoke for dependency-free Brotli stored streams against Node Brotli");
    br_stored_cli_diff_step.dependOn(&br_stored_cli_diff.step);

    const br_literal_cli_diff = b.addSystemCommand(&.{ "python3", "tools/br_literal_cli_diff.py" });
    br_literal_cli_diff.addArtifactArg(cli_exe);
    const br_literal_cli_diff_step = b.step("run-br-literal-cli-diff", "Run black-box smoke for minimal dependency-free Brotli literal blocks against Node Brotli");
    br_literal_cli_diff_step.dependOn(&br_literal_cli_diff.step);

    const br_rle_probe_exe = b.addExecutable(.{
        .name = "vort-br-rle-probe",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/br_rle_probe.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{.{ .name = "vort", .module = vort_mod_releasefast }},
        }),
    });
    const br_rle_node_diff = b.addSystemCommand(&.{ "python3", "tools/br_rle_node_diff.py" });
    br_rle_node_diff.addArtifactArg(br_rle_probe_exe);
    const br_rle_node_diff_step = b.step("run-br-rle-node-diff", "Validate compressed Brotli RLE output with Node");
    br_rle_node_diff_step.dependOn(&br_rle_node_diff.step);

    const br_planned_corpus_exe = b.addExecutable(.{
        .name = "vort-br-planned-corpus",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/br_planned_corpus.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{.{ .name = "vort", .module = vort_mod_releasefast }},
        }),
    });
    const run_br_planned_corpus = b.addRunArtifact(br_planned_corpus_exe);
    const br_planned_corpus_step = b.step("run-br-planned-corpus", "Run planner-backed Brotli text/JSON/log corpus smoke");
    br_planned_corpus_step.dependOn(&run_br_planned_corpus.step);
    const br_planned_probe_exe = b.addExecutable(.{
        .name = "vort-br-planned-probe",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/br_planned_probe.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{.{ .name = "vort", .module = vort_mod_releasefast }},
        }),
    });
    const br_planned_node_diff = b.addSystemCommand(&.{ "python3", "tools/br_planned_node_diff.py" });
    br_planned_node_diff.addArtifactArg(br_planned_probe_exe);
    const br_planned_node_diff_step = b.step("run-br-planned-node-diff", "Validate planner-backed Brotli corpora with Node");
    br_planned_node_diff_step.dependOn(&br_planned_node_diff.step);
    const br_planned_encode_bench_exe = b.addExecutable(.{
        .name = "vort-br-planned-encode-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/br/planned_encode_bench.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod_releasefast },
                .{ .name = "benchmark_provenance", .module = benchmark_provenance_mod },
            },
        }),
    });
    const run_br_planned_encode_bench = b.addRunArtifact(br_planned_encode_bench_exe);
    if (b.args) |args| run_br_planned_encode_bench.addArgs(args);
    const br_planned_encode_bench_step = b.step("run-br-planned-encode-bench", "Compare planner-backed Brotli encode with libbrotli");
    br_planned_encode_bench_step.dependOn(&run_br_planned_encode_bench.step);
    const run_br_planned_encode_bench_csv = b.addRunArtifact(br_planned_encode_bench_exe);
    run_br_planned_encode_bench_csv.addArgs(&.{ "--iterations", "100", "--csv", "zig-out/vort-br-planned-encode-bench.csv" });
    const br_planned_encode_bench_gate = b.addSystemCommand(&.{ "python3", "tools/br/planned_encode_bench_gate.py", "--csv", "zig-out/vort-br-planned-encode-bench.csv" });
    br_planned_encode_bench_gate.addArg("--executable");
    br_planned_encode_bench_gate.addArtifactArg(br_planned_encode_bench_exe);
    br_planned_encode_bench_gate.step.dependOn(&run_br_planned_encode_bench_csv.step);
    const br_planned_encode_bench_gate_step = b.step("run-br-planned-encode-bench-gate", "Validate planner-backed Brotli encode A/B CSV");
    br_planned_encode_bench_gate_step.dependOn(&br_planned_encode_bench_gate.step);
    const run_br_planned_encode_path_csv = b.addRunArtifact(br_planned_encode_bench_exe);
    run_br_planned_encode_path_csv.addArgs(&.{
        "--iterations", "10",
        "--path",       "corpus/native-library-bench-small.txt",
        "--limit",      "32768",
        "--csv",        "zig-out/vort-br-planned-encode-path.csv",
    });
    const br_planned_encode_path_gate = b.addSystemCommand(&.{
        "python3", "tools/br/planned_encode_path_gate.py",
        "--csv",   "zig-out/vort-br-planned-encode-path.csv",
    });
    br_planned_encode_path_gate.addArg("--executable");
    br_planned_encode_path_gate.addArtifactArg(br_planned_encode_bench_exe);
    br_planned_encode_path_gate.addArgs(&.{
        "--input", "corpus/native-library-bench-small.txt",
        "--limit", "32768",
    });
    br_planned_encode_path_gate.step.dependOn(&run_br_planned_encode_path_csv.step);
    const br_planned_encode_path_gate_step = b.step("run-br-planned-encode-path-gate", "Validate file-backed Brotli encode A/B CSV");
    br_planned_encode_path_gate_step.dependOn(&br_planned_encode_path_gate.step);
    const br_planned_chunks_bench_exe = b.addExecutable(.{
        .name = "vort-br-planned-chunks-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/br/planned_chunks_bench.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{.{ .name = "vort", .module = vort_mod_releasefast }},
        }),
    });
    const run_br_planned_chunks_bench = b.addRunArtifact(br_planned_chunks_bench_exe);
    if (b.args) |args| run_br_planned_chunks_bench.addArgs(args);
    const br_planned_chunks_bench_step = b.step("run-br-planned-chunks-bench", "Measure one Brotli multi-block stream against separate frames");
    br_planned_chunks_bench_step.dependOn(&run_br_planned_chunks_bench.step);
    const run_br_planned_chunks_bench_csv = b.addRunArtifact(br_planned_chunks_bench_exe);
    run_br_planned_chunks_bench_csv.addArg("100");
    const br_planned_chunks_bench_gate = b.addSystemCommand(&.{
        "python3", "tools/br/planned_chunks_bench_gate.py", "--csv",
    });
    br_planned_chunks_bench_gate.addFileArg(run_br_planned_chunks_bench_csv.captureStdOut(.{}));
    const br_planned_chunks_bench_gate_step = b.step("run-br-planned-chunks-bench-gate", "Validate Brotli multi-block encode benchmark");
    br_planned_chunks_bench_gate_step.dependOn(&br_planned_chunks_bench_gate.step);
    const br_planned_stage_profile_exe = b.addExecutable(.{
        .name = "vort-br-planned-stage-profile",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/br/planned_stage_profile.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{.{ .name = "vort", .module = vort_mod_releasefast }},
        }),
    });
    const run_br_planned_stage_profile = b.addRunArtifact(br_planned_stage_profile_exe);
    const br_planned_stage_profile_step = b.step("run-br-planned-stage-profile", "Report planner-backed Brotli token/command/alphabet shape");
    br_planned_stage_profile_step.dependOn(&run_br_planned_stage_profile.step);
    const br_ratio_stage_profile_exe = b.addExecutable(.{
        .name = "vort-br-ratio-stage-profile",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/br/ratio_stage_profile.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod_releasefast },
                .{ .name = "benchmark_provenance", .module = benchmark_provenance_mod },
            },
        }),
    });
    const br_record_optimal_audit_exe = b.addExecutable(.{
        .name = "vort-br-record-optimal-audit",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/br/record_optimal_audit.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .link_libc = true,
            .imports = &.{.{ .name = "vort", .module = vort_mod_releasefast }},
        }),
    });
    const run_br_record_optimal_audit = b.addRunArtifact(br_record_optimal_audit_exe);
    const br_record_optimal_audit_step = b.step("run-br-record-optimal-audit", "Audit fixed-record Brotli optimal candidates");
    br_record_optimal_audit_step.dependOn(&run_br_record_optimal_audit.step);
    const br_record_optimal_shape_exe = b.addExecutable(.{
        .name = "vort-br-record-optimal-shape",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/br/record_optimal_shape.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{.{ .name = "vort", .module = vort_mod_releasefast }},
        }),
    });
    const run_br_record_optimal_shape = b.addRunArtifact(br_record_optimal_shape_exe);
    const br_record_optimal_shape_step = b.step("run-br-record-optimal-shape", "Report fixed-record Brotli plan structure");
    br_record_optimal_shape_step.dependOn(&run_br_record_optimal_shape.step);
    const run_br_record_optimal_shape_gate = b.addRunArtifact(br_record_optimal_shape_exe);
    const br_record_optimal_shape_gate = b.addSystemCommand(&.{ "python3", "tools/br/record_optimal_shape_gate.py" });
    br_record_optimal_shape_gate.setStdIn(.{ .lazy_path = run_br_record_optimal_shape_gate.captureStdOut(.{}) });
    const br_record_optimal_shape_gate_step = b.step("run-br-record-optimal-shape-gate", "Validate fixed-record Brotli plan structure");
    br_record_optimal_shape_gate_step.dependOn(&br_record_optimal_shape_gate.step);
    const run_br_ratio_stage_profile = b.addRunArtifact(br_ratio_stage_profile_exe);
    if (b.args) |args| run_br_ratio_stage_profile.addArgs(args);
    const br_ratio_stage_profile_step = b.step("run-br-ratio-stage-profile", "Profile Brotli ratio candidate stages and optimal search");
    br_ratio_stage_profile_step.dependOn(&run_br_ratio_stage_profile.step);
    const run_br_ratio_stage_profile_csv = b.addRunArtifact(br_ratio_stage_profile_exe);
    run_br_ratio_stage_profile_csv.addArgs(&.{ "--iterations", "3", "--csv", "zig-out/vort-br-ratio-stage-profile.csv" });
    const br_ratio_stage_profile_gate = b.addSystemCommand(&.{ "python3", "tools/br/ratio_stage_profile_gate.py", "--csv", "zig-out/vort-br-ratio-stage-profile.csv", "--executable" });
    br_ratio_stage_profile_gate.addArtifactArg(br_ratio_stage_profile_exe);
    br_ratio_stage_profile_gate.step.dependOn(&run_br_ratio_stage_profile_csv.step);
    const br_ratio_stage_profile_gate_step = b.step("run-br-ratio-stage-profile-gate", "Validate Brotli ratio stage profile coverage and counters");
    br_ratio_stage_profile_gate_step.dependOn(&br_ratio_stage_profile_gate.step);
    const br_planned_stage_bench_exe = b.addExecutable(.{
        .name = "vort-br-planned-stage-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/br/planned_stage_bench.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{.{ .name = "vort", .module = vort_mod_releasefast }},
        }),
    });
    const run_br_planned_stage_bench = b.addRunArtifact(br_planned_stage_bench_exe);
    if (b.args) |args| run_br_planned_stage_bench.addArgs(args);
    const br_planned_stage_bench_step = b.step("run-br-planned-stage-bench", "Measure LZ77 parser share of planner-backed Brotli encoding");
    br_planned_stage_bench_step.dependOn(&run_br_planned_stage_bench.step);
    const br_lazy_sweep_exe = b.addExecutable(.{
        .name = "vort-br-lazy-sweep",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/br/lazy_sweep.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{.{ .name = "vort", .module = vort_mod_releasefast }},
        }),
    });
    const run_br_lazy_sweep = b.addRunArtifact(br_lazy_sweep_exe);
    const br_lazy_sweep_step = b.step("run-br-lazy-sweep", "Sweep Brotli lazy planner ratio parameters");
    br_lazy_sweep_step.dependOn(&run_br_lazy_sweep.step);

    const br_command_lut_bench_exe = b.addExecutable(.{
        .name = "vort-bench-br-command-lut",
        .root_module = b.createModule(.{
            .root_source_file = b.path("bench/br_command_lut.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{.{ .name = "br_command_lut", .module = b.createModule(.{
                .root_source_file = b.path("src/br/command_lut.zig"),
                .target = target,
                .optimize = .ReleaseFast,
            }) }},
        }),
    });
    const run_br_command_lut_bench = b.addRunArtifact(br_command_lut_bench_exe);
    if (b.args) |args| run_br_command_lut_bench.addArgs(args);
    const br_command_lut_bench_step = b.step("bench-br-command-lut", "Compare Brotli command table and formula");
    br_command_lut_bench_step.dependOn(&run_br_command_lut_bench.step);

    const br_stored_corpus_exe = b.addExecutable(.{
        .name = "vort-br-stored-corpus",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/br_stored_corpus.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_br_stored_corpus = b.addRunArtifact(br_stored_corpus_exe);
    const br_stored_corpus_step = b.step("run-br-stored-corpus", "Run dependency-free Brotli stored stream corpus smoke");
    br_stored_corpus_step.dependOn(&run_br_stored_corpus.step);

    const br_static_dictionary_report_exe = b.addExecutable(.{
        .name = "vort-br-static-dictionary-report",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/br_static_dictionary_report.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_br_static_dictionary_report = b.addRunArtifact(br_static_dictionary_report_exe);
    if (b.args) |args| run_br_static_dictionary_report.addArgs(args);
    const br_static_dictionary_report_step = b.step("run-br-static-dictionary-report", "Report Brotli static dictionary subset coverage");
    br_static_dictionary_report_step.dependOn(&run_br_static_dictionary_report.step);

    const run_br_static_dictionary_report_dashboard = b.addRunArtifact(br_static_dictionary_report_exe);
    run_br_static_dictionary_report_dashboard.addArgs(&.{
        "--csv",
        "zig-out/vort-br-static-dictionary-report.csv",
        "--json",
        "zig-out/vort-br-static-dictionary-report.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-report.md",
    });
    const br_static_dictionary_report_dashboard_step = b.step("run-br-static-dictionary-report-dashboard", "Write Brotli static dictionary subset coverage artifacts");
    br_static_dictionary_report_dashboard_step.dependOn(&run_br_static_dictionary_report_dashboard.step);

    const br_static_dictionary_report_smoke = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_report_smoke.py",
        "--csv",
        "zig-out/vort-br-static-dictionary-report.csv",
        "--json",
        "zig-out/vort-br-static-dictionary-report.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-report.md",
        "--required",
        "tools/br_static_dictionary_required_coverage.json",
    });
    br_static_dictionary_report_smoke.step.dependOn(br_static_dictionary_report_dashboard_step);
    const br_static_dictionary_report_smoke_step = b.step("run-br-static-dictionary-report-smoke", "Validate Brotli static dictionary coverage artifacts");
    br_static_dictionary_report_smoke_step.dependOn(&br_static_dictionary_report_smoke.step);

    const br_static_dictionary_report_negative_smoke = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_report_negative_smoke.py",
        "--summary",
        "zig-out/vort-br-static-dictionary-report-negative-smoke.json",
    });
    const br_static_dictionary_report_negative_smoke_step = b.step("run-br-static-dictionary-report-negative-smoke", "Validate Brotli static dictionary coverage negative cases");
    br_static_dictionary_report_negative_smoke_step.dependOn(&br_static_dictionary_report_negative_smoke.step);

    const br_static_dictionary_source_audit = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_source_audit.py",
        "--summary",
        "zig-out/vort-br-static-dictionary-source-audit.json",
        "--generated-zig",
        "zig-out/vort-br-static-dictionary-generated.zig",
    });
    if (b.args) |args| br_static_dictionary_source_audit.addArgs(args);
    const br_static_dictionary_source_audit_step = b.step("run-br-static-dictionary-source-audit", "Validate Brotli static dictionary source anchors");
    br_static_dictionary_source_audit_step.dependOn(&br_static_dictionary_source_audit.step);

    const br_static_dictionary_source_audit_negative_smoke = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_source_audit_negative_smoke.py",
        "--summary",
        "zig-out/vort-br-static-dictionary-source-audit-negative-smoke.json",
    });
    const br_static_dictionary_source_audit_negative_smoke_step = b.step("run-br-static-dictionary-source-audit-negative-smoke", "Validate Brotli static dictionary source-audit negative cases");
    br_static_dictionary_source_audit_negative_smoke_step.dependOn(&br_static_dictionary_source_audit_negative_smoke.step);

    const br_static_dictionary_candidate_report = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_candidate_report.py",
        "--json",
        "zig-out/vort-br-static-dictionary-candidates.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-candidates.md",
    });
    const br_static_dictionary_candidate_report_step = b.step("run-br-static-dictionary-candidate-report", "Report Brotli static dictionary candidate tuples from source anchors");
    br_static_dictionary_candidate_report_step.dependOn(&br_static_dictionary_candidate_report.step);

    const br_static_dictionary_candidate_report_smoke = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_candidate_report_smoke.py",
        "--json",
        "zig-out/vort-br-static-dictionary-candidates.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-candidates.md",
    });
    br_static_dictionary_candidate_report_smoke.step.dependOn(br_static_dictionary_candidate_report_step);
    const br_static_dictionary_candidate_report_smoke_step = b.step("run-br-static-dictionary-candidate-report-smoke", "Validate Brotli static dictionary candidate report artifacts");
    br_static_dictionary_candidate_report_smoke_step.dependOn(&br_static_dictionary_candidate_report_smoke.step);

    const br_static_dictionary_candidate_upstream_smoke = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_candidate_upstream_smoke.py",
        "--summary",
        "zig-out/vort-br-static-dictionary-candidate-upstream-smoke.json",
        "--json",
        "zig-out/vort-br-static-dictionary-candidates-upstream.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-candidates-upstream.md",
    });
    const br_static_dictionary_candidate_upstream_smoke_step = b.step("run-br-static-dictionary-candidate-upstream-smoke", "Validate Brotli candidate report upstream-source mode");
    br_static_dictionary_candidate_upstream_smoke_step.dependOn(&br_static_dictionary_candidate_upstream_smoke.step);

    const br_static_dictionary_node_probe = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe.addArgs(&.{
        "--candidates",
        "zig-out/vort-br-static-dictionary-candidates.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe.md",
        "--require-vort-ok",
    });
    if (b.args) |args| br_static_dictionary_node_probe.addArgs(args);
    br_static_dictionary_node_probe.step.dependOn(br_static_dictionary_candidate_report_step);
    const br_static_dictionary_node_probe_step = b.step("run-br-static-dictionary-node-probe", "Probe Brotli static dictionary candidates against Node and Vort");
    br_static_dictionary_node_probe_step.dependOn(&br_static_dictionary_node_probe.step);

    const br_static_dictionary_node_probe_wide = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_wide.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_wide.addArgs(&.{
        "--candidates",
        "zig-out/vort-br-static-dictionary-candidates.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-wide.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-wide.md",
        "--limit",
        "160",
        "--require-vort-ok",
    });
    br_static_dictionary_node_probe_wide.step.dependOn(br_static_dictionary_candidate_report_step);
    const br_static_dictionary_node_probe_wide_step = b.step("run-br-static-dictionary-node-probe-wide", "Probe a wider Brotli static dictionary candidate prefix against Node and Vort");
    br_static_dictionary_node_probe_wide_step.dependOn(&br_static_dictionary_node_probe_wide.step);

    const br_static_dictionary_node_probe_full = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_full.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_full.addArgs(&.{
        "--candidates",
        "zig-out/vort-br-static-dictionary-candidates.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-full.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-full.md",
        "--all-candidates",
        "--require-vort-ok",
        "--require-no-size-winners",
    });
    br_static_dictionary_node_probe_full.step.dependOn(br_static_dictionary_candidate_report_step);
    const br_static_dictionary_node_probe_full_step = b.step("run-br-static-dictionary-node-probe-full", "Probe every Brotli static dictionary candidate against Node and Vort");
    br_static_dictionary_node_probe_full_step.dependOn(&br_static_dictionary_node_probe_full.step);

    const br_static_dictionary_node_probe_upstream = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_upstream.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_upstream.addArgs(&.{
        "--candidates",
        "zig-out/vort-br-static-dictionary-candidates-upstream.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-upstream.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-upstream.md",
        "--all-candidates",
        "--require-vort-ok",
    });
    br_static_dictionary_node_probe_upstream.step.dependOn(br_static_dictionary_candidate_upstream_smoke_step);
    const br_static_dictionary_node_probe_upstream_step = b.step("run-br-static-dictionary-node-probe-upstream", "Probe upstream Brotli static dictionary candidates against Node and Vort");
    br_static_dictionary_node_probe_upstream_step.dependOn(&br_static_dictionary_node_probe_upstream.step);

    const br_static_dictionary_candidate_report_upstream80 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_candidate_report.py",
        "--json",
        "zig-out/vort-br-static-dictionary-candidates-upstream80.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-candidates-upstream80.md",
        "--source-limit",
        "80",
    });
    if (b.args) |args| br_static_dictionary_candidate_report_upstream80.addArgs(args);
    const br_static_dictionary_candidate_report_upstream80_step = b.step("run-br-static-dictionary-candidate-report-upstream80", "Report Brotli candidates from a local upstream source-limit 80 slice (pass -- --brotli-common-dir <path>)");
    br_static_dictionary_candidate_report_upstream80_step.dependOn(&br_static_dictionary_candidate_report_upstream80.step);

    const br_static_dictionary_candidate_report_upstream80_for_probe = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_candidate_report.py",
        "--json",
        "zig-out/br-static-dictionary-candidates-upstream80-probe.json",
        "--markdown",
        "zig-out/br-static-dictionary-candidates-upstream80-probe.md",
        "--source-limit",
        "80",
    });
    if (b.args) |args| br_static_dictionary_candidate_report_upstream80_for_probe.addArgs(args);

    const br_static_dictionary_node_probe_upstream80 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_upstream80.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_upstream80.addArgs(&.{
        "--candidates",
        "zig-out/br-static-dictionary-candidates-upstream80-probe.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-upstream80.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-upstream80.md",
        "--all-candidates",
        "--require-vort-ok",
    });
    br_static_dictionary_node_probe_upstream80.step.dependOn(&br_static_dictionary_candidate_report_upstream80_for_probe.step);
    const br_static_dictionary_node_probe_upstream80_step = b.step("run-br-static-dictionary-node-probe-upstream80", "Probe local upstream source-limit 80 Brotli candidates (pass -- --brotli-common-dir <path>)");
    br_static_dictionary_node_probe_upstream80_step.dependOn(&br_static_dictionary_node_probe_upstream80.step);

    const br_static_dictionary_candidate_report_upstream128 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_candidate_report.py",
        "--json",
        "zig-out/vort-br-static-dictionary-candidates-upstream128.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-candidates-upstream128.md",
        "--source-limit",
        "128",
    });
    if (b.args) |args| br_static_dictionary_candidate_report_upstream128.addArgs(args);
    const br_static_dictionary_candidate_report_upstream128_step = b.step("run-br-static-dictionary-candidate-report-upstream128", "Report Brotli candidates from a local upstream source-limit 128 slice (pass -- --brotli-common-dir <path>)");
    br_static_dictionary_candidate_report_upstream128_step.dependOn(&br_static_dictionary_candidate_report_upstream128.step);

    const br_static_dictionary_candidate_report_upstream128_for_probe = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_candidate_report.py",
        "--json",
        "zig-out/br-static-dictionary-candidates-upstream128-probe.json",
        "--markdown",
        "zig-out/br-static-dictionary-candidates-upstream128-probe.md",
        "--source-limit",
        "128",
    });
    if (b.args) |args| br_static_dictionary_candidate_report_upstream128_for_probe.addArgs(args);

    const br_static_dictionary_node_probe_upstream128 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_upstream128.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_upstream128.addArgs(&.{
        "--candidates",
        "zig-out/br-static-dictionary-candidates-upstream128-probe.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-upstream128.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-upstream128.md",
        "--all-candidates",
        "--require-vort-ok",
    });
    br_static_dictionary_node_probe_upstream128.step.dependOn(&br_static_dictionary_candidate_report_upstream128_for_probe.step);
    const br_static_dictionary_node_probe_upstream128_step = b.step("run-br-static-dictionary-node-probe-upstream128", "Probe local upstream source-limit 128 Brotli candidates (pass -- --brotli-common-dir <path>)");
    br_static_dictionary_node_probe_upstream128_step.dependOn(&br_static_dictionary_node_probe_upstream128.step);

    const br_static_dictionary_candidate_report_upstream256 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_candidate_report.py",
        "--json",
        "zig-out/vort-br-static-dictionary-candidates-upstream256.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-candidates-upstream256.md",
        "--source-limit",
        "256",
    });
    if (b.args) |args| br_static_dictionary_candidate_report_upstream256.addArgs(args);
    const br_static_dictionary_candidate_report_upstream256_step = b.step("run-br-static-dictionary-candidate-report-upstream256", "Report Brotli candidates from a local upstream source-limit 256 slice (pass -- --brotli-common-dir <path>)");
    br_static_dictionary_candidate_report_upstream256_step.dependOn(&br_static_dictionary_candidate_report_upstream256.step);

    const br_static_dictionary_candidate_report_upstream256_for_probe = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_candidate_report.py",
        "--json",
        "zig-out/br-static-dictionary-candidates-upstream256-probe.json",
        "--markdown",
        "zig-out/br-static-dictionary-candidates-upstream256-probe.md",
        "--source-limit",
        "256",
    });
    if (b.args) |args| br_static_dictionary_candidate_report_upstream256_for_probe.addArgs(args);

    const br_static_dictionary_node_probe_upstream256 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_upstream256.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_upstream256.addArgs(&.{
        "--candidates",
        "zig-out/br-static-dictionary-candidates-upstream256-probe.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-upstream256.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-upstream256.md",
        "--all-candidates",
        "--require-vort-ok",
        "--require-no-size-winners",
    });
    br_static_dictionary_node_probe_upstream256.step.dependOn(&br_static_dictionary_candidate_report_upstream256_for_probe.step);
    const br_static_dictionary_node_probe_upstream256_step = b.step("run-br-static-dictionary-node-probe-upstream256", "Probe local upstream source-limit 256 Brotli candidates (pass -- --brotli-common-dir <path>)");
    br_static_dictionary_node_probe_upstream256_step.dependOn(&br_static_dictionary_node_probe_upstream256.step);

    const br_static_dictionary_candidate_report_upstream512 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_candidate_report.py",
        "--json",
        "zig-out/vort-br-static-dictionary-candidates-upstream512.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-candidates-upstream512.md",
        "--source-limit",
        "512",
    });
    if (b.args) |args| br_static_dictionary_candidate_report_upstream512.addArgs(args);
    const br_static_dictionary_candidate_report_upstream512_step = b.step("run-br-static-dictionary-candidate-report-upstream512", "Report Brotli candidates from a local upstream source-limit 512 slice (pass -- --brotli-common-dir <path>)");
    br_static_dictionary_candidate_report_upstream512_step.dependOn(&br_static_dictionary_candidate_report_upstream512.step);

    const br_static_dictionary_candidate_report_upstream512_for_probe = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_candidate_report.py",
        "--json",
        "zig-out/br-static-dictionary-candidates-upstream512-probe.json",
        "--markdown",
        "zig-out/br-static-dictionary-candidates-upstream512-probe.md",
        "--source-limit",
        "512",
    });
    if (b.args) |args| br_static_dictionary_candidate_report_upstream512_for_probe.addArgs(args);

    const br_static_dictionary_node_probe_upstream512 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_upstream512.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_upstream512.addArgs(&.{
        "--candidates",
        "zig-out/br-static-dictionary-candidates-upstream512-probe.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-upstream512.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-upstream512.md",
        "--all-candidates",
        "--require-vort-ok",
        "--require-no-size-winners",
    });
    br_static_dictionary_node_probe_upstream512.step.dependOn(&br_static_dictionary_candidate_report_upstream512_for_probe.step);
    const br_static_dictionary_node_probe_upstream512_step = b.step("run-br-static-dictionary-node-probe-upstream512", "Probe local upstream source-limit 512 Brotli candidates (pass -- --brotli-common-dir <path>)");
    br_static_dictionary_node_probe_upstream512_step.dependOn(&br_static_dictionary_node_probe_upstream512.step);

    const br_static_dictionary_candidate_report_upstream1024 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_candidate_report.py",
        "--json",
        "zig-out/vort-br-static-dictionary-candidates-upstream1024.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-candidates-upstream1024.md",
        "--source-limit",
        "1024",
    });
    if (b.args) |args| br_static_dictionary_candidate_report_upstream1024.addArgs(args);
    const br_static_dictionary_candidate_report_upstream1024_step = b.step("run-br-static-dictionary-candidate-report-upstream1024", "Report Brotli candidates from a local upstream source-limit 1024 slice (pass -- --brotli-common-dir <path>)");
    br_static_dictionary_candidate_report_upstream1024_step.dependOn(&br_static_dictionary_candidate_report_upstream1024.step);

    const br_static_dictionary_node_probe_upstream1024_0_1024 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_upstream1024_0_1024.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_upstream1024_0_1024.addArgs(&.{
        "--candidates",
        "zig-out/vort-br-static-dictionary-candidates-upstream1024.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-upstream1024-0-1024.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-upstream1024-0-1024.md",
        "--start-index",
        "0",
        "--limit",
        "1024",
        "--require-vort-ok",
    });
    br_static_dictionary_node_probe_upstream1024_0_1024.step.dependOn(br_static_dictionary_candidate_report_upstream1024_step);
    const br_static_dictionary_node_probe_upstream1024_0_1024_step = b.step("run-br-static-dictionary-node-probe-upstream1024-0-1024", "Probe upstream1024 Brotli candidates [0, 1024) against Node and Vort");
    br_static_dictionary_node_probe_upstream1024_0_1024_step.dependOn(&br_static_dictionary_node_probe_upstream1024_0_1024.step);

    const br_static_dictionary_node_probe_upstream1024_1024_2048 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_upstream1024_1024_2048.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_upstream1024_1024_2048.addArgs(&.{
        "--candidates",
        "zig-out/vort-br-static-dictionary-candidates-upstream1024.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-upstream1024-1024-2048.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-upstream1024-1024-2048.md",
        "--start-index",
        "1024",
        "--limit",
        "1024",
        "--require-vort-ok",
    });
    br_static_dictionary_node_probe_upstream1024_1024_2048.step.dependOn(br_static_dictionary_candidate_report_upstream1024_step);
    const br_static_dictionary_node_probe_upstream1024_1024_2048_step = b.step("run-br-static-dictionary-node-probe-upstream1024-1024-2048", "Probe upstream1024 Brotli candidates [1024, 2048) against Node and Vort");
    br_static_dictionary_node_probe_upstream1024_1024_2048_step.dependOn(&br_static_dictionary_node_probe_upstream1024_1024_2048.step);

    const br_static_dictionary_node_probe_upstream1024_2048_3072 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_upstream1024_2048_3072.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_upstream1024_2048_3072.addArgs(&.{
        "--candidates",
        "zig-out/vort-br-static-dictionary-candidates-upstream1024.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-upstream1024-2048-3072.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-upstream1024-2048-3072.md",
        "--start-index",
        "2048",
        "--limit",
        "1024",
        "--require-vort-ok",
    });
    br_static_dictionary_node_probe_upstream1024_2048_3072.step.dependOn(br_static_dictionary_candidate_report_upstream1024_step);
    const br_static_dictionary_node_probe_upstream1024_2048_3072_step = b.step("run-br-static-dictionary-node-probe-upstream1024-2048-3072", "Probe upstream1024 Brotli candidates [2048, 3072) against Node and Vort");
    br_static_dictionary_node_probe_upstream1024_2048_3072_step.dependOn(&br_static_dictionary_node_probe_upstream1024_2048_3072.step);

    const br_static_dictionary_node_probe_upstream1024_3072_4096 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_upstream1024_3072_4096.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_upstream1024_3072_4096.addArgs(&.{
        "--candidates",
        "zig-out/vort-br-static-dictionary-candidates-upstream1024.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-upstream1024-3072-4096.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-upstream1024-3072-4096.md",
        "--start-index",
        "3072",
        "--limit",
        "1024",
        "--require-vort-ok",
    });
    br_static_dictionary_node_probe_upstream1024_3072_4096.step.dependOn(br_static_dictionary_candidate_report_upstream1024_step);
    const br_static_dictionary_node_probe_upstream1024_3072_4096_step = b.step("run-br-static-dictionary-node-probe-upstream1024-3072-4096", "Probe upstream1024 Brotli candidates [3072, 4096) against Node and Vort");
    br_static_dictionary_node_probe_upstream1024_3072_4096_step.dependOn(&br_static_dictionary_node_probe_upstream1024_3072_4096.step);

    const br_static_dictionary_node_probe_upstream1024_4096_5120 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_upstream1024_4096_5120.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_upstream1024_4096_5120.addArgs(&.{
        "--candidates",
        "zig-out/vort-br-static-dictionary-candidates-upstream1024.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-upstream1024-4096-5120.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-upstream1024-4096-5120.md",
        "--start-index",
        "4096",
        "--limit",
        "1024",
        "--require-vort-ok",
    });
    br_static_dictionary_node_probe_upstream1024_4096_5120.step.dependOn(br_static_dictionary_candidate_report_upstream1024_step);
    const br_static_dictionary_node_probe_upstream1024_4096_5120_step = b.step("run-br-static-dictionary-node-probe-upstream1024-4096-5120", "Probe upstream1024 Brotli candidates [4096, 5120) against Node and Vort");
    br_static_dictionary_node_probe_upstream1024_4096_5120_step.dependOn(&br_static_dictionary_node_probe_upstream1024_4096_5120.step);

    const br_static_dictionary_node_probe_upstream1024_5120_6144 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_upstream1024_5120_6144.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_upstream1024_5120_6144.addArgs(&.{
        "--candidates",
        "zig-out/vort-br-static-dictionary-candidates-upstream1024.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-upstream1024-5120-6144.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-upstream1024-5120-6144.md",
        "--start-index",
        "5120",
        "--limit",
        "1024",
        "--require-vort-ok",
    });
    br_static_dictionary_node_probe_upstream1024_5120_6144.step.dependOn(br_static_dictionary_candidate_report_upstream1024_step);
    const br_static_dictionary_node_probe_upstream1024_5120_6144_step = b.step("run-br-static-dictionary-node-probe-upstream1024-5120-6144", "Probe upstream1024 Brotli candidates [5120, 6144) against Node and Vort");
    br_static_dictionary_node_probe_upstream1024_5120_6144_step.dependOn(&br_static_dictionary_node_probe_upstream1024_5120_6144.step);

    const br_static_dictionary_node_probe_upstream1024_6144_tail = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_upstream1024_6144_tail.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_upstream1024_6144_tail.addArgs(&.{
        "--candidates",
        "zig-out/vort-br-static-dictionary-candidates-upstream1024.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-upstream1024-6144-tail.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-upstream1024-6144-tail.md",
        "--start-index",
        "6144",
        "--limit",
        "1024",
        "--require-vort-ok",
        "--require-no-size-winners",
    });
    br_static_dictionary_node_probe_upstream1024_6144_tail.step.dependOn(br_static_dictionary_candidate_report_upstream1024_step);
    const br_static_dictionary_node_probe_upstream1024_6144_tail_step = b.step("run-br-static-dictionary-node-probe-upstream1024-6144-tail", "Probe upstream1024 Brotli tail candidates [6144, end) against Node and Vort");
    br_static_dictionary_node_probe_upstream1024_6144_tail_step.dependOn(&br_static_dictionary_node_probe_upstream1024_6144_tail.step);

    const br_static_dictionary_candidate_report_upstream2048 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_candidate_report.py",
        "--json",
        "zig-out/vort-br-static-dictionary-candidates-upstream2048.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-candidates-upstream2048.md",
        "--source-limit",
        "2048",
    });
    if (b.args) |args| br_static_dictionary_candidate_report_upstream2048.addArgs(args);
    const br_static_dictionary_candidate_report_upstream2048_step = b.step("run-br-static-dictionary-candidate-report-upstream2048", "Report Brotli candidates from a local upstream source-limit 2048 slice (pass -- --brotli-common-dir <path>)");
    br_static_dictionary_candidate_report_upstream2048_step.dependOn(&br_static_dictionary_candidate_report_upstream2048.step);

    const br_static_dictionary_node_probe_upstream2048_6137_7161 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_upstream2048_6137_7161.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_upstream2048_6137_7161.addArgs(&.{
        "--candidates",
        "zig-out/vort-br-static-dictionary-candidates-upstream2048.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-upstream2048-6137-7161.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-upstream2048-6137-7161.md",
        "--start-index",
        "6137",
        "--limit",
        "1024",
        "--require-vort-ok",
        "--require-no-size-winners",
    });
    br_static_dictionary_node_probe_upstream2048_6137_7161.step.dependOn(br_static_dictionary_candidate_report_upstream2048_step);
    const br_static_dictionary_node_probe_upstream2048_6137_7161_step = b.step("run-br-static-dictionary-node-probe-upstream2048-6137-7161", "Probe upstream2048 Brotli candidates [6137, 7161) against Node and Vort");
    br_static_dictionary_node_probe_upstream2048_6137_7161_step.dependOn(&br_static_dictionary_node_probe_upstream2048_6137_7161.step);

    const br_static_dictionary_node_probe_upstream2048_7161_8185 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_upstream2048_7161_8185.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_upstream2048_7161_8185.addArgs(&.{
        "--candidates",
        "zig-out/vort-br-static-dictionary-candidates-upstream2048.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-upstream2048-7161-8185.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-upstream2048-7161-8185.md",
        "--start-index",
        "7161",
        "--limit",
        "1024",
        "--require-vort-ok",
        "--require-no-size-winners",
    });
    br_static_dictionary_node_probe_upstream2048_7161_8185.step.dependOn(br_static_dictionary_candidate_report_upstream2048_step);
    const br_static_dictionary_node_probe_upstream2048_7161_8185_step = b.step("run-br-static-dictionary-node-probe-upstream2048-7161-8185", "Probe upstream2048 Brotli candidates [7161, 8185) against Node and Vort");
    br_static_dictionary_node_probe_upstream2048_7161_8185_step.dependOn(&br_static_dictionary_node_probe_upstream2048_7161_8185.step);

    const br_static_dictionary_node_probe_upstream2048_8185_9209 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_upstream2048_8185_9209.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_upstream2048_8185_9209.addArgs(&.{
        "--candidates",
        "zig-out/vort-br-static-dictionary-candidates-upstream2048.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-upstream2048-8185-9209.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-upstream2048-8185-9209.md",
        "--start-index",
        "8185",
        "--limit",
        "1024",
        "--require-vort-ok",
        "--require-no-size-winners",
    });
    br_static_dictionary_node_probe_upstream2048_8185_9209.step.dependOn(br_static_dictionary_candidate_report_upstream2048_step);
    const br_static_dictionary_node_probe_upstream2048_8185_9209_step = b.step("run-br-static-dictionary-node-probe-upstream2048-8185-9209", "Probe upstream2048 Brotli candidates [8185, 9209) against Node and Vort");
    br_static_dictionary_node_probe_upstream2048_8185_9209_step.dependOn(&br_static_dictionary_node_probe_upstream2048_8185_9209.step);

    const br_static_dictionary_node_probe_upstream2048_9209_10233 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_upstream2048_9209_10233.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_upstream2048_9209_10233.addArgs(&.{
        "--candidates",
        "zig-out/vort-br-static-dictionary-candidates-upstream2048.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-upstream2048-9209-10233.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-upstream2048-9209-10233.md",
        "--start-index",
        "9209",
        "--limit",
        "1024",
        "--require-vort-ok",
        "--require-no-size-winners",
    });
    br_static_dictionary_node_probe_upstream2048_9209_10233.step.dependOn(br_static_dictionary_candidate_report_upstream2048_step);
    const br_static_dictionary_node_probe_upstream2048_9209_10233_step = b.step("run-br-static-dictionary-node-probe-upstream2048-9209-10233", "Probe upstream2048 Brotli candidates [9209, 10233) against Node and Vort");
    br_static_dictionary_node_probe_upstream2048_9209_10233_step.dependOn(&br_static_dictionary_node_probe_upstream2048_9209_10233.step);

    const br_static_dictionary_node_probe_upstream2048_10233_11257 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_upstream2048_10233_11257.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_upstream2048_10233_11257.addArgs(&.{
        "--candidates",
        "zig-out/vort-br-static-dictionary-candidates-upstream2048.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-upstream2048-10233-11257.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-upstream2048-10233-11257.md",
        "--start-index",
        "10233",
        "--limit",
        "1024",
        "--require-vort-ok",
        "--require-no-size-winners",
    });
    br_static_dictionary_node_probe_upstream2048_10233_11257.step.dependOn(br_static_dictionary_candidate_report_upstream2048_step);
    const br_static_dictionary_node_probe_upstream2048_10233_11257_step = b.step("run-br-static-dictionary-node-probe-upstream2048-10233-11257", "Probe upstream2048 Brotli candidates [10233, 11257) against Node and Vort");
    br_static_dictionary_node_probe_upstream2048_10233_11257_step.dependOn(&br_static_dictionary_node_probe_upstream2048_10233_11257.step);

    const br_static_dictionary_node_probe_upstream2048_11257_12281 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_upstream2048_11257_12281.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_upstream2048_11257_12281.addArgs(&.{
        "--candidates",
        "zig-out/vort-br-static-dictionary-candidates-upstream2048.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-upstream2048-11257-12281.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-upstream2048-11257-12281.md",
        "--start-index",
        "11257",
        "--limit",
        "1024",
        "--require-vort-ok",
        "--require-no-size-winners",
    });
    br_static_dictionary_node_probe_upstream2048_11257_12281.step.dependOn(br_static_dictionary_candidate_report_upstream2048_step);
    const br_static_dictionary_node_probe_upstream2048_11257_12281_step = b.step("run-br-static-dictionary-node-probe-upstream2048-11257-12281", "Probe upstream2048 Brotli candidates [11257, 12281) against Node and Vort");
    br_static_dictionary_node_probe_upstream2048_11257_12281_step.dependOn(&br_static_dictionary_node_probe_upstream2048_11257_12281.step);

    const br_static_dictionary_node_probe_upstream2048_12281_tail = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_upstream2048_12281_tail.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_upstream2048_12281_tail.addArgs(&.{
        "--candidates",
        "zig-out/vort-br-static-dictionary-candidates-upstream2048.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-upstream2048-12281-tail.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-upstream2048-12281-tail.md",
        "--start-index",
        "12281",
        "--limit",
        "1024",
        "--require-vort-ok",
        "--require-no-size-winners",
    });
    br_static_dictionary_node_probe_upstream2048_12281_tail.step.dependOn(br_static_dictionary_candidate_report_upstream2048_step);
    const br_static_dictionary_node_probe_upstream2048_12281_tail_step = b.step("run-br-static-dictionary-node-probe-upstream2048-12281-tail", "Probe upstream2048 Brotli candidates [12281, end) against Node and Vort");
    br_static_dictionary_node_probe_upstream2048_12281_tail_step.dependOn(&br_static_dictionary_node_probe_upstream2048_12281_tail.step);

    const br_static_dictionary_candidate_report_upstream4096 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_candidate_report.py",
        "--json",
        "zig-out/vort-br-static-dictionary-candidates-upstream4096.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-candidates-upstream4096.md",
        "--source-limit",
        "4096",
    });
    if (b.args) |args| br_static_dictionary_candidate_report_upstream4096.addArgs(args);
    const br_static_dictionary_candidate_report_upstream4096_step = b.step("run-br-static-dictionary-candidate-report-upstream4096", "Report Brotli candidates from a local upstream source-limit 4096 slice (pass -- --brotli-common-dir <path>)");
    br_static_dictionary_candidate_report_upstream4096_step.dependOn(&br_static_dictionary_candidate_report_upstream4096.step);

    const br_static_dictionary_node_probe_upstream4096_12223_13247 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_upstream4096_12223_13247.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_upstream4096_12223_13247.addArgs(&.{
        "--candidates",
        "zig-out/vort-br-static-dictionary-candidates-upstream4096.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-upstream4096-12223-13247.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-upstream4096-12223-13247.md",
        "--start-index",
        "12223",
        "--limit",
        "1024",
        "--require-vort-ok",
        "--require-no-size-winners",
    });
    br_static_dictionary_node_probe_upstream4096_12223_13247.step.dependOn(br_static_dictionary_candidate_report_upstream4096_step);
    const br_static_dictionary_node_probe_upstream4096_12223_13247_step = b.step("run-br-static-dictionary-node-probe-upstream4096-12223-13247", "Probe upstream4096 Brotli candidates [12223, 13247) against Node and Vort");
    br_static_dictionary_node_probe_upstream4096_12223_13247_step.dependOn(&br_static_dictionary_node_probe_upstream4096_12223_13247.step);

    const br_static_dictionary_node_probe_upstream4096_13247_14271 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_upstream4096_13247_14271.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_upstream4096_13247_14271.addArgs(&.{
        "--candidates",
        "zig-out/vort-br-static-dictionary-candidates-upstream4096.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-upstream4096-13247-14271.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-upstream4096-13247-14271.md",
        "--start-index",
        "13247",
        "--limit",
        "1024",
        "--require-vort-ok",
        "--require-no-size-winners",
    });
    br_static_dictionary_node_probe_upstream4096_13247_14271.step.dependOn(br_static_dictionary_candidate_report_upstream4096_step);
    const br_static_dictionary_node_probe_upstream4096_13247_14271_step = b.step("run-br-static-dictionary-node-probe-upstream4096-13247-14271", "Probe upstream4096 Brotli candidates [13247, 14271) against Node and Vort");
    br_static_dictionary_node_probe_upstream4096_13247_14271_step.dependOn(&br_static_dictionary_node_probe_upstream4096_13247_14271.step);

    const br_static_dictionary_node_probe_upstream4096_14271_15295 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_upstream4096_14271_15295.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_upstream4096_14271_15295.addArgs(&.{
        "--candidates",
        "zig-out/vort-br-static-dictionary-candidates-upstream4096.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-upstream4096-14271-15295.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-upstream4096-14271-15295.md",
        "--start-index",
        "14271",
        "--limit",
        "1024",
        "--require-vort-ok",
        "--require-no-size-winners",
    });
    br_static_dictionary_node_probe_upstream4096_14271_15295.step.dependOn(br_static_dictionary_candidate_report_upstream4096_step);
    const br_static_dictionary_node_probe_upstream4096_14271_15295_step = b.step("run-br-static-dictionary-node-probe-upstream4096-14271-15295", "Probe upstream4096 Brotli candidates [14271, 15295) against Node and Vort");
    br_static_dictionary_node_probe_upstream4096_14271_15295_step.dependOn(&br_static_dictionary_node_probe_upstream4096_14271_15295.step);

    const br_static_dictionary_node_probe_upstream4096_15295_16319 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_upstream4096_15295_16319.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_upstream4096_15295_16319.addArgs(&.{
        "--candidates",
        "zig-out/vort-br-static-dictionary-candidates-upstream4096.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-upstream4096-15295-16319.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-upstream4096-15295-16319.md",
        "--start-index",
        "15295",
        "--limit",
        "1024",
        "--require-vort-ok",
        "--require-no-size-winners",
    });
    br_static_dictionary_node_probe_upstream4096_15295_16319.step.dependOn(br_static_dictionary_candidate_report_upstream4096_step);
    const br_static_dictionary_node_probe_upstream4096_15295_16319_step = b.step("run-br-static-dictionary-node-probe-upstream4096-15295-16319", "Probe upstream4096 Brotli candidates [15295, 16319) against Node and Vort");
    br_static_dictionary_node_probe_upstream4096_15295_16319_step.dependOn(&br_static_dictionary_node_probe_upstream4096_15295_16319.step);

    const br_static_dictionary_node_probe_upstream4096_16319_17343 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_upstream4096_16319_17343.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_upstream4096_16319_17343.addArgs(&.{
        "--candidates",
        "zig-out/vort-br-static-dictionary-candidates-upstream4096.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-upstream4096-16319-17343.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-upstream4096-16319-17343.md",
        "--start-index",
        "16319",
        "--limit",
        "1024",
        "--require-vort-ok",
        "--require-no-size-winners",
    });
    br_static_dictionary_node_probe_upstream4096_16319_17343.step.dependOn(br_static_dictionary_candidate_report_upstream4096_step);
    const br_static_dictionary_node_probe_upstream4096_16319_17343_step = b.step("run-br-static-dictionary-node-probe-upstream4096-16319-17343", "Probe upstream4096 Brotli candidates [16319, 17343) against Node and Vort");
    br_static_dictionary_node_probe_upstream4096_16319_17343_step.dependOn(&br_static_dictionary_node_probe_upstream4096_16319_17343.step);

    const br_static_dictionary_node_probe_upstream4096_17343_18367 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_upstream4096_17343_18367.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_upstream4096_17343_18367.addArgs(&.{
        "--candidates",
        "zig-out/vort-br-static-dictionary-candidates-upstream4096.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-upstream4096-17343-18367.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-upstream4096-17343-18367.md",
        "--start-index",
        "17343",
        "--limit",
        "1024",
        "--require-vort-ok",
        "--require-no-size-winners",
    });
    br_static_dictionary_node_probe_upstream4096_17343_18367.step.dependOn(br_static_dictionary_candidate_report_upstream4096_step);
    const br_static_dictionary_node_probe_upstream4096_17343_18367_step = b.step("run-br-static-dictionary-node-probe-upstream4096-17343-18367", "Probe upstream4096 Brotli candidates [17343, 18367) against Node and Vort");
    br_static_dictionary_node_probe_upstream4096_17343_18367_step.dependOn(&br_static_dictionary_node_probe_upstream4096_17343_18367.step);

    const br_static_dictionary_node_probe_upstream4096_18367_19391 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_upstream4096_18367_19391.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_upstream4096_18367_19391.addArgs(&.{
        "--candidates",
        "zig-out/vort-br-static-dictionary-candidates-upstream4096.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-upstream4096-18367-19391.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-upstream4096-18367-19391.md",
        "--start-index",
        "18367",
        "--limit",
        "1024",
        "--require-vort-ok",
        "--require-no-size-winners",
    });
    br_static_dictionary_node_probe_upstream4096_18367_19391.step.dependOn(br_static_dictionary_candidate_report_upstream4096_step);
    const br_static_dictionary_node_probe_upstream4096_18367_19391_step = b.step("run-br-static-dictionary-node-probe-upstream4096-18367-19391", "Probe upstream4096 Brotli candidates [18367, 19391) against Node and Vort");
    br_static_dictionary_node_probe_upstream4096_18367_19391_step.dependOn(&br_static_dictionary_node_probe_upstream4096_18367_19391.step);

    const br_static_dictionary_node_probe_upstream4096_19391_20415 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_upstream4096_19391_20415.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_upstream4096_19391_20415.addArgs(&.{
        "--candidates",
        "zig-out/vort-br-static-dictionary-candidates-upstream4096.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-upstream4096-19391-20415.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-upstream4096-19391-20415.md",
        "--start-index",
        "19391",
        "--limit",
        "1024",
        "--require-vort-ok",
        "--require-no-size-winners",
    });
    br_static_dictionary_node_probe_upstream4096_19391_20415.step.dependOn(br_static_dictionary_candidate_report_upstream4096_step);
    const br_static_dictionary_node_probe_upstream4096_19391_20415_step = b.step("run-br-static-dictionary-node-probe-upstream4096-19391-20415", "Probe upstream4096 Brotli candidates [19391, 20415) against Node and Vort");
    br_static_dictionary_node_probe_upstream4096_19391_20415_step.dependOn(&br_static_dictionary_node_probe_upstream4096_19391_20415.step);

    const br_static_dictionary_node_probe_upstream4096_20415_21439 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_upstream4096_20415_21439.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_upstream4096_20415_21439.addArgs(&.{
        "--candidates",
        "zig-out/vort-br-static-dictionary-candidates-upstream4096.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-upstream4096-20415-21439.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-upstream4096-20415-21439.md",
        "--start-index",
        "20415",
        "--limit",
        "1024",
        "--require-vort-ok",
        "--require-no-size-winners",
    });
    br_static_dictionary_node_probe_upstream4096_20415_21439.step.dependOn(br_static_dictionary_candidate_report_upstream4096_step);
    const br_static_dictionary_node_probe_upstream4096_20415_21439_step = b.step("run-br-static-dictionary-node-probe-upstream4096-20415-21439", "Probe upstream4096 Brotli candidates [20415, 21439) against Node and Vort");
    br_static_dictionary_node_probe_upstream4096_20415_21439_step.dependOn(&br_static_dictionary_node_probe_upstream4096_20415_21439.step);

    const br_static_dictionary_node_probe_upstream4096_21439_22463 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_upstream4096_21439_22463.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_upstream4096_21439_22463.addArgs(&.{
        "--candidates",
        "zig-out/vort-br-static-dictionary-candidates-upstream4096.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-upstream4096-21439-22463.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-upstream4096-21439-22463.md",
        "--start-index",
        "21439",
        "--limit",
        "1024",
        "--require-vort-ok",
        "--require-no-size-winners",
    });
    br_static_dictionary_node_probe_upstream4096_21439_22463.step.dependOn(br_static_dictionary_candidate_report_upstream4096_step);
    const br_static_dictionary_node_probe_upstream4096_21439_22463_step = b.step("run-br-static-dictionary-node-probe-upstream4096-21439-22463", "Probe upstream4096 Brotli candidates [21439, 22463) against Node and Vort");
    br_static_dictionary_node_probe_upstream4096_21439_22463_step.dependOn(&br_static_dictionary_node_probe_upstream4096_21439_22463.step);

    const br_static_dictionary_node_probe_upstream4096_22463_23487 = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_upstream4096_22463_23487.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_upstream4096_22463_23487.addArgs(&.{
        "--candidates",
        "zig-out/vort-br-static-dictionary-candidates-upstream4096.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-upstream4096-22463-23487.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-upstream4096-22463-23487.md",
        "--start-index",
        "22463",
        "--limit",
        "1024",
        "--require-vort-ok",
        "--require-no-size-winners",
    });
    br_static_dictionary_node_probe_upstream4096_22463_23487.step.dependOn(br_static_dictionary_candidate_report_upstream4096_step);
    const br_static_dictionary_node_probe_upstream4096_22463_23487_step = b.step("run-br-static-dictionary-node-probe-upstream4096-22463-23487", "Probe upstream4096 Brotli candidates [22463, 23487) against Node and Vort");
    br_static_dictionary_node_probe_upstream4096_22463_23487_step.dependOn(&br_static_dictionary_node_probe_upstream4096_22463_23487.step);

    const br_static_dictionary_node_probe_upstream4096_23487_tail = b.addSystemCommand(&.{
        "python3",
        "tools/br_static_dictionary_node_probe.py",
    });
    br_static_dictionary_node_probe_upstream4096_23487_tail.addArtifactArg(cli_exe);
    br_static_dictionary_node_probe_upstream4096_23487_tail.addArgs(&.{
        "--candidates",
        "zig-out/vort-br-static-dictionary-candidates-upstream4096.json",
        "--json",
        "zig-out/vort-br-static-dictionary-node-probe-upstream4096-23487-tail.json",
        "--markdown",
        "zig-out/vort-br-static-dictionary-node-probe-upstream4096-23487-tail.md",
        "--start-index",
        "23487",
        "--limit",
        "1024",
        "--require-vort-ok",
        "--require-no-size-winners",
    });
    br_static_dictionary_node_probe_upstream4096_23487_tail.step.dependOn(br_static_dictionary_candidate_report_upstream4096_step);
    const br_static_dictionary_node_probe_upstream4096_23487_tail_step = b.step("run-br-static-dictionary-node-probe-upstream4096-23487-tail", "Probe upstream4096 Brotli candidates [23487, end) against Node and Vort");
    br_static_dictionary_node_probe_upstream4096_23487_tail_step.dependOn(&br_static_dictionary_node_probe_upstream4096_23487_tail.step);

    const snappy_block_cli_probe = b.addSystemCommand(&.{ "python3", "tools/snappy_block_cli_probe.py" });
    snappy_block_cli_probe.addArtifactArg(cli_exe);
    const snappy_block_cli_probe_step = b.step("run-snappy-block-cli-probe", "Run black-box smoke for dependency-free Snappy raw blocks and framed streams");
    snappy_block_cli_probe_step.dependOn(&snappy_block_cli_probe.step);

    const snappy_interop_probe_exe = b.addExecutable(.{
        .name = "snappy-interop-probe",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/snappy_interop_probe.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_snappy_interop_probe = b.addRunArtifact(snappy_interop_probe_exe);
    const snappy_interop_probe_step = b.step(
        "run-snappy-interop-probe",
        "Run bidirectional raw-block and framed-stream interoperability against libsnappy",
    );
    snappy_interop_probe_step.dependOn(&run_snappy_interop_probe.step);

    const zstd_native_cli_diff = b.addSystemCommand(&.{ "python3", "tools/zstd_native_cli_diff.py" });
    zstd_native_cli_diff.addArtifactArg(cli_exe);
    const zstd_native_cli_diff_step = b.step("run-zstd-native-cli-diff", "Run black-box smoke for native-subset zstd frames against system zstd CLI");
    zstd_native_cli_diff_step.dependOn(&zstd_native_cli_diff.step);

    const zstd_native_summary_cli_probe = b.addSystemCommand(&.{ "python3", "tools/zstd_native_summary_cli_probe.py" });
    zstd_native_summary_cli_probe.addArtifactArg(cli_exe);
    const zstd_native_summary_cli_probe_step = b.step("run-zstd-native-summary-cli-probe", "Run black-box smoke for native-subset zstd stream summary CLI");
    zstd_native_summary_cli_probe_step.dependOn(&zstd_native_summary_cli_probe.step);

    const lz4_native_summary_cli_probe = b.addSystemCommand(&.{ "python3", "tools/lz4_native_summary_cli_probe.py" });
    lz4_native_summary_cli_probe.addArtifactArg(cli_exe);
    const lz4_native_summary_cli_probe_step = b.step("run-lz4-native-summary-cli-probe", "Run black-box smoke for native LZ4 stream summary CLI");
    lz4_native_summary_cli_probe_step.dependOn(&lz4_native_summary_cli_probe.step);

    const lz4_native_summary_dashboard = b.addSystemCommand(&.{ "python3", "tools/lz4_native_summary_dashboard.py" });
    lz4_native_summary_dashboard.addArtifactArg(cli_exe);
    lz4_native_summary_dashboard.addArgs(&.{ "--json", "zig-out/vort-lz4-native-stream-summary.json" });
    const lz4_native_summary_dashboard_step = b.step("run-lz4-native-summary-dashboard", "Write native LZ4 stream summary JSON artifact");
    lz4_native_summary_dashboard_step.dependOn(&lz4_native_summary_dashboard.step);

    const zstd_native_summary_dashboard = b.addSystemCommand(&.{ "python3", "tools/zstd_native_summary_dashboard.py" });
    zstd_native_summary_dashboard.addArtifactArg(cli_exe);
    zstd_native_summary_dashboard.addArgs(&.{ "--json", "zig-out/vort-zstd-native-stream-summary.json" });
    const zstd_native_summary_dashboard_step = b.step("run-zstd-native-summary-dashboard", "Write native-subset zstd stream summary JSON artifact");
    zstd_native_summary_dashboard_step.dependOn(&zstd_native_summary_dashboard.step);

    const native_summary_error_dashboard = b.addSystemCommand(&.{ "python3", "tools/native_summary_error_dashboard.py" });
    native_summary_error_dashboard.addArtifactArg(cli_exe);
    native_summary_error_dashboard.addArgs(&.{ "--json", "zig-out/vort-native-summary-error-dashboard.json" });
    const native_summary_error_dashboard_step = b.step("run-native-summary-error-dashboard", "Write native summary structured error JSON artifact");
    native_summary_error_dashboard_step.dependOn(&native_summary_error_dashboard.step);

    const native_summary_error_negative_smoke = b.addSystemCommand(&.{ "python3", "tools/native_summary_error_negative_smoke.py", "--summary", "zig-out/vort-native-summary-error-negative-smoke.json" });
    const native_summary_error_negative_smoke_step = b.step("run-native-summary-error-negative-smoke", "Validate native summary error dashboard negative drift cases");
    native_summary_error_negative_smoke_step.dependOn(&native_summary_error_negative_smoke.step);

    const zstd_native_probe = b.addSystemCommand(&.{ "python3", "tools/zstd_native_probe.py" });
    zstd_native_probe.addArtifactArg(cli_exe);
    if (b.args) |args| zstd_native_probe.addArgs(args);
    const zstd_native_probe_step = b.step("run-zstd-native-probe", "Run bounded generated-corpus probe for native-subset zstd frames");
    zstd_native_probe_step.dependOn(&zstd_native_probe.step);

    const zstd_native_dictionary_probe_exe = b.addExecutable(.{
        .name = "zstd-native-dictionary-probe",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/zstd_native_dictionary_probe.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_zstd_native_dictionary_probe = b.addRunArtifact(zstd_native_dictionary_probe_exe);
    if (b.args) |args| run_zstd_native_dictionary_probe.addArgs(args);
    const zstd_native_dictionary_probe_step = b.step("run-zstd-native-dictionary-probe", "Run library probe for native Zstd dictionary APIs");
    zstd_native_dictionary_probe_step.dependOn(&run_zstd_native_dictionary_probe.step);

    const zstd_native_frame_probe_exe = b.addExecutable(.{
        .name = "zstd-native-frame-probe",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/zstd_native_frame_probe.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_zstd_native_frame_probe = b.addRunArtifact(zstd_native_frame_probe_exe);
    if (b.args) |args| run_zstd_native_frame_probe.addArgs(args);
    const zstd_native_frame_probe_step = b.step("run-zstd-native-frame-probe", "Run library probe for native Zstd frame APIs");
    zstd_native_frame_probe_step.dependOn(&run_zstd_native_frame_probe.step);

    const run_zstd_native_frame_lib_generated_probe = b.addRunArtifact(zstd_native_frame_probe_exe);
    run_zstd_native_frame_lib_generated_probe.addArgs(&.{ "--only", "lib-generated" });
    const zstd_native_frame_lib_generated_probe_step = b.step(
        "run-zstd-native-frame-lib-generated-probe",
        "Run libzstd-generated differential probe for native Zstd frame APIs",
    );
    zstd_native_frame_lib_generated_probe_step.dependOn(&run_zstd_native_frame_lib_generated_probe.step);

    const run_zstd_native_frame_handcrafted_probe = b.addRunArtifact(zstd_native_frame_probe_exe);
    run_zstd_native_frame_handcrafted_probe.addArgs(&.{ "--only", "handcrafted" });
    const zstd_native_frame_handcrafted_probe_step = b.step(
        "run-zstd-native-frame-handcrafted-probe",
        "Run handwritten fixture probe for native Zstd frame APIs",
    );
    zstd_native_frame_handcrafted_probe_step.dependOn(&run_zstd_native_frame_handcrafted_probe.step);

    const lz4_native_probe_exe = b.addExecutable(.{
        .name = "lz4-native-probe",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/lz4_native_probe.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_lz4_native_probe = b.addRunArtifact(lz4_native_probe_exe);
    if (b.args) |args| run_lz4_native_probe.addArgs(args);
    const lz4_native_probe_step = b.step("run-lz4-native-probe", "Run bounded generated-corpus probe for native LZ4 frames and blocks");
    lz4_native_probe_step.dependOn(&run_lz4_native_probe.step);

    const lz4_native_dictionary_probe_exe = b.addExecutable(.{
        .name = "lz4-native-dictionary-probe",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/lz4_native_dictionary_probe.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_lz4_native_dictionary_probe = b.addRunArtifact(lz4_native_dictionary_probe_exe);
    if (b.args) |args| run_lz4_native_dictionary_probe.addArgs(args);
    const lz4_native_dictionary_probe_step = b.step("run-lz4-native-dictionary-probe", "Run library probe for native LZ4 dictionary APIs");
    lz4_native_dictionary_probe_step.dependOn(&run_lz4_native_dictionary_probe.step);

    const native_codec_probes_step = b.step("run-native-codec-probes", "Run library probes for native LZ4 and Zstd APIs");
    native_codec_probes_step.dependOn(&run_lz4_native_probe.step);
    native_codec_probes_step.dependOn(&run_lz4_native_dictionary_probe.step);
    native_codec_probes_step.dependOn(&run_zstd_native_frame_probe.step);
    native_codec_probes_step.dependOn(&run_zstd_native_dictionary_probe.step);

    const native_codec_probes_dashboard = b.addSystemCommand(&.{ "python3", "tools/native_codec_probes_dashboard.py" });
    native_codec_probes_dashboard.addArgs(&.{
        "--json",
        "zig-out/vort-native-codec-probes.json",
        "--markdown",
        "zig-out/vort-native-codec-probes.md",
    });
    native_codec_probes_dashboard.addArtifactArg(lz4_native_probe_exe);
    native_codec_probes_dashboard.addArtifactArg(lz4_native_dictionary_probe_exe);
    native_codec_probes_dashboard.addArtifactArg(zstd_native_frame_probe_exe);
    native_codec_probes_dashboard.addArtifactArg(zstd_native_dictionary_probe_exe);
    const native_codec_probes_dashboard_step = b.step("run-native-codec-probes-dashboard", "Run native codec probes and retain JSON/Markdown artifacts");
    native_codec_probes_dashboard_step.dependOn(&native_codec_probes_dashboard.step);

    const native_codec_probes_dashboard_timeout_smoke = b.addSystemCommand(&.{ "python3", "tools/native_codec_probes_dashboard_timeout_smoke.py" });
    const native_codec_probes_dashboard_timeout_smoke_step = b.step("run-native-codec-probes-dashboard-timeout-smoke", "Validate native codec probe dashboard timeout handling");
    native_codec_probes_dashboard_timeout_smoke_step.dependOn(&native_codec_probes_dashboard_timeout_smoke.step);

    const header_inspect_smoke = b.addSystemCommand(&.{ "python3", "tools/header_inspect_smoke.py" });
    header_inspect_smoke.addArtifactArg(cli_exe);
    const header_inspect_smoke_step = b.step("run-header-inspect-smoke", "Run raw/zlib/gzip header inspection CLI smoke");
    header_inspect_smoke_step.dependOn(&header_inspect_smoke.step);

    const header_inspect_dashboard = b.addSystemCommand(&.{ "python3", "tools/header_inspect_smoke.py" });
    header_inspect_dashboard.addArtifactArg(cli_exe);
    header_inspect_dashboard.addArgs(&.{
        "--summary",
        "zig-out/vort-header-inspect-smoke.json",
        "--markdown",
        "zig-out/vort-header-inspect-smoke.md",
    });
    const header_inspect_dashboard_step = b.step("run-header-inspect-dashboard", "Write raw/zlib/gzip header inspection smoke summary artifacts to zig-out");
    header_inspect_dashboard_step.dependOn(&header_inspect_dashboard.step);

    const zlib_family_diff = b.addSystemCommand(&.{ "python3", "tools/zlib_family_diff.py" });
    zlib_family_diff.addArtifactArg(cli_exe);
    const zlib_family_diff_step = b.step("run-zlib-family-diff", "Run optional zlib-ng/zlib-rs differential harness when binaries are available");
    zlib_family_diff_step.dependOn(&zlib_family_diff.step);

    const rust_deflate_diff = b.addSystemCommand(&.{ "python3", "tools/rust_deflate_diff.py" });
    rust_deflate_diff.addArtifactArg(cli_exe);
    const rust_deflate_diff_step = b.step("run-rust-deflate-diff", "Run fdeflate/miniz_oxide differential smoke when local checkouts are available");
    rust_deflate_diff_step.dependOn(&rust_deflate_diff.step);

    const rust_deflate_bench = b.addSystemCommand(&.{ "python3", "tools/rust_deflate_bench.py" });
    rust_deflate_bench.addArtifactArg(zlib_decode_bench_exe);
    const rust_deflate_bench_step = b.step("run-rust-deflate-bench", "Run fdeflate/miniz_oxide decode throughput smoke benchmark");
    rust_deflate_bench_step.dependOn(&rust_deflate_bench.step);

    const rust_deflate_bench_csv = b.addSystemCommand(&.{ "python3", "tools/rust_deflate_bench.py" });
    rust_deflate_bench_csv.addArtifactArg(zlib_decode_bench_exe);
    rust_deflate_bench_csv.addArgs(&.{ "--csv", "zig-out/vort-rust-deflate-decode-bench.csv" });
    const rust_deflate_bench_csv_step = b.step("run-rust-deflate-bench-csv", "Write Vort/fdeflate/miniz_oxide decode benchmark CSV to zig-out");
    rust_deflate_bench_csv_step.dependOn(&rust_deflate_bench_csv.step);

    const rust_deflate_bench_csv_repeat3 = b.addSystemCommand(&.{ "python3", "tools/rust_deflate_bench.py" });
    rust_deflate_bench_csv_repeat3.addArtifactArg(zlib_decode_bench_exe);
    rust_deflate_bench_csv_repeat3.addArgs(&.{ "--repeat", "3", "--csv", "zig-out/vort-rust-deflate-decode-bench-repeat3.csv" });
    const rust_deflate_bench_csv_repeat3_step = b.step("run-rust-deflate-bench-csv-repeat3", "Write median-of-3 Vort/Rust decode benchmark CSV to zig-out");
    rust_deflate_bench_csv_repeat3_step.dependOn(&rust_deflate_bench_csv_repeat3.step);
    const rust_deflate_bench_gate = b.addSystemCommand(&.{
        "python3",           "tools/rust_deflate_bench_gate.py",
        "--kind",            "decode",
        "--csv",             "zig-out/vort-rust-deflate-decode-bench-repeat3.csv",
        "--repeat",          "3",
        "--vort-executable",
    });
    rust_deflate_bench_gate.addArtifactArg(zlib_decode_bench_exe);
    rust_deflate_bench_gate.step.dependOn(&rust_deflate_bench_csv_repeat3.step);
    const rust_deflate_bench_gate_step = b.step("run-rust-deflate-bench-gate", "Validate median-of-3 Vort/Rust decode benchmark provenance and CSV");
    rust_deflate_bench_gate_step.dependOn(&rust_deflate_bench_gate.step);

    const rust_deflate_encode_bench = b.addSystemCommand(&.{ "python3", "tools/rust_deflate_encode_bench.py" });
    rust_deflate_encode_bench.addArtifactArg(zlib_encode_bench_exe);
    const rust_deflate_encode_bench_step = b.step("run-rust-deflate-encode-bench", "Run Vort/fdeflate/miniz_oxide encode throughput and size smoke benchmark");
    rust_deflate_encode_bench_step.dependOn(&rust_deflate_encode_bench.step);

    const rust_deflate_encode_bench_csv = b.addSystemCommand(&.{ "python3", "tools/rust_deflate_encode_bench.py" });
    rust_deflate_encode_bench_csv.addArtifactArg(zlib_encode_bench_exe);
    rust_deflate_encode_bench_csv.addArgs(&.{ "--csv", "zig-out/vort-rust-deflate-encode-bench.csv" });
    const rust_deflate_encode_bench_csv_step = b.step("run-rust-deflate-encode-bench-csv", "Write Vort/fdeflate/miniz_oxide encode benchmark CSV to zig-out");
    rust_deflate_encode_bench_csv_step.dependOn(&rust_deflate_encode_bench_csv.step);

    const rust_deflate_encode_bench_csv_repeat3 = b.addSystemCommand(&.{ "python3", "tools/rust_deflate_encode_bench.py" });
    rust_deflate_encode_bench_csv_repeat3.addArtifactArg(zlib_encode_bench_exe);
    rust_deflate_encode_bench_csv_repeat3.addArgs(&.{ "--repeat", "3", "--csv", "zig-out/vort-rust-deflate-encode-bench-repeat3.csv" });
    const rust_deflate_encode_bench_csv_repeat3_step = b.step("run-rust-deflate-encode-bench-csv-repeat3", "Write median-of-3 Vort/Rust encode benchmark CSV to zig-out");
    rust_deflate_encode_bench_csv_repeat3_step.dependOn(&rust_deflate_encode_bench_csv_repeat3.step);
    const rust_deflate_encode_bench_gate = b.addSystemCommand(&.{
        "python3",           "tools/rust_deflate_bench_gate.py",
        "--kind",            "encode",
        "--csv",             "zig-out/vort-rust-deflate-encode-bench-repeat3.csv",
        "--repeat",          "3",
        "--vort-executable",
    });
    rust_deflate_encode_bench_gate.addArtifactArg(zlib_encode_bench_exe);
    rust_deflate_encode_bench_gate.step.dependOn(&rust_deflate_encode_bench_csv_repeat3.step);
    const rust_deflate_encode_bench_gate_step = b.step("run-rust-deflate-encode-bench-gate", "Validate median-of-3 Vort/Rust encode benchmark provenance and CSV");
    rust_deflate_encode_bench_gate_step.dependOn(&rust_deflate_encode_bench_gate.step);
    const rust_deflate_bench_gate_smoke = b.addSystemCommand(&.{ "python3", "tools/rust_deflate_bench_gate_smoke.py" });
    const rust_deflate_bench_gate_smoke_step = b.step("run-rust-deflate-bench-gate-smoke", "Validate Deflate benchmark matrix positive and negative paths");
    rust_deflate_bench_gate_smoke_step.dependOn(&rust_deflate_bench_gate_smoke.step);

    const external_probe = b.addSystemCommand(&.{ "python3", "tools/external_probe.py" });
    const external_probe_step = b.step("run-external-probe", "Report available local compression competitors/tools");
    external_probe_step.dependOn(&external_probe.step);

    const cpu_features_exe = b.addExecutable(.{
        .name = "vort-cpu-features",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/cpu_features.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_cpu_features = b.addRunArtifact(cpu_features_exe);
    const cpu_features_step = b.step("run-cpu-features", "Report CPU target and Vort dispatch choices");
    cpu_features_step.dependOn(&run_cpu_features.step);

    const zstd_compare = b.addSystemCommand(&.{ "python3", "tools/zstd_compare.py" });
    zstd_compare.addArtifactArg(cli_exe);
    zstd_compare.addArgs(&.{ "--csv", "zig-out/vort-zstd-compare.csv", "--markdown", "zig-out/vort-zstd-compare.md", "--optimize", @tagName(optimize) });
    const zstd_compare_step = b.step("run-zstd-compare", "Report zstd CLI and Vort fixed compressed sizes for sample files");
    zstd_compare_step.dependOn(&zstd_compare.step);

    const zstd_compare_gate = b.addSystemCommand(&.{
        "python3",
        "tools/zstd_compare_gate.py",
        "--expect-source-mode",
        "default-samples",
        "--expect-size-mode",
        "full",
        "--expect-optimize",
        @tagName(optimize),
        "--expect-case-limit",
        "none",
        "--summary",
        "zig-out/vort-zstd-compare-gate.json",
    });
    zstd_compare_gate.step.dependOn(zstd_compare_step);
    const zstd_compare_gate_step = b.step("run-zstd-compare-gate", "Validate zstd comparison artifacts");
    zstd_compare_gate_step.dependOn(&zstd_compare_gate.step);

    const zstd_compare_block_sweep = b.addSystemCommand(&.{ "python3", "tools/zstd_compare_block_sweep.py" });
    zstd_compare_block_sweep.addArtifactArg(cli_exe);
    zstd_compare_block_sweep.addArgs(&.{
        "--standard-suite",
        "--limit",
        "3",
        "--block-lens",
        "4096,8192,16384,32768,65536",
        "--csv",
        "zig-out/vort-zstd-compare-block-sweep.csv",
        "--markdown",
        "zig-out/vort-zstd-compare-block-sweep.md",
        "--optimize",
        @tagName(optimize),
    });
    if (b.args) |args| zstd_compare_block_sweep.addArgs(args);
    const zstd_compare_block_sweep_step = b.step("run-zstd-compare-block-sweep", "Sweep native block lengths in zstd/Vort smoke rows");
    zstd_compare_block_sweep_step.dependOn(&zstd_compare_block_sweep.step);

    const zstd_compare_block_sweep_gate = b.addSystemCommand(&.{
        "python3",
        "tools/zstd_compare_block_sweep_gate.py",
        "--csv",
        "zig-out/vort-zstd-compare-block-sweep.csv",
        "--markdown",
        "zig-out/vort-zstd-compare-block-sweep.md",
        "--expect-source-mode",
        "standard-suite",
        "--expect-size-mode",
        "bounded-128KiB",
        "--expect-optimize",
        @tagName(optimize),
        "--expect-case-limit",
        "3",
        "--expect-block-lens",
        "4096,8192,16384,32768,65536",
        "--summary",
        "zig-out/vort-zstd-compare-block-sweep-gate.json",
    });
    zstd_compare_block_sweep_gate.step.dependOn(zstd_compare_block_sweep_step);
    const zstd_compare_block_sweep_gate_step = b.step("run-zstd-compare-block-sweep-gate", "Validate native block-length sweep artifacts");
    zstd_compare_block_sweep_gate_step.dependOn(&zstd_compare_block_sweep_gate.step);

    const zstd_compare_block_sweep_releasefast = b.addSystemCommand(&.{ "python3", "tools/zstd_compare_block_sweep.py" });
    zstd_compare_block_sweep_releasefast.addArtifactArg(cli_releasefast_exe);
    zstd_compare_block_sweep_releasefast.addArgs(&.{
        "--standard-suite",
        "--limit",
        "3",
        "--block-lens",
        "4096,8192,16384,32768,65536",
        "--csv",
        "zig-out/vort-zstd-compare-block-sweep-releasefast.csv",
        "--markdown",
        "zig-out/vort-zstd-compare-block-sweep-releasefast.md",
        "--optimize",
        "ReleaseFast",
    });
    if (b.args) |args| zstd_compare_block_sweep_releasefast.addArgs(args);
    const zstd_compare_block_sweep_releasefast_step = b.step("run-zstd-compare-block-sweep-releasefast", "Sweep native block lengths with a ReleaseFast Vort CLI");
    zstd_compare_block_sweep_releasefast_step.dependOn(&zstd_compare_block_sweep_releasefast.step);

    const zstd_compare_block_sweep_releasefast_gate = b.addSystemCommand(&.{
        "python3",
        "tools/zstd_compare_block_sweep_gate.py",
        "--csv",
        "zig-out/vort-zstd-compare-block-sweep-releasefast.csv",
        "--markdown",
        "zig-out/vort-zstd-compare-block-sweep-releasefast.md",
        "--expect-source-mode",
        "standard-suite",
        "--expect-size-mode",
        "bounded-128KiB",
        "--expect-optimize",
        "ReleaseFast",
        "--expect-case-limit",
        "3",
        "--expect-block-lens",
        "4096,8192,16384,32768,65536",
        "--summary",
        "zig-out/vort-zstd-compare-block-sweep-releasefast-gate.json",
    });
    zstd_compare_block_sweep_releasefast_gate.step.dependOn(zstd_compare_block_sweep_releasefast_step);
    const zstd_compare_block_sweep_releasefast_gate_step = b.step("run-zstd-compare-block-sweep-releasefast-gate", "Validate ReleaseFast native block-length sweep artifacts");
    zstd_compare_block_sweep_releasefast_gate_step.dependOn(&zstd_compare_block_sweep_releasefast_gate.step);

    const zstd_compare_standard = b.addSystemCommand(&.{ "python3", "tools/zstd_compare.py" });
    zstd_compare_standard.addArtifactArg(cli_exe);
    zstd_compare_standard.addArgs(&.{
        "--standard-suite",
        "--limit",
        "3",
        "--csv",
        "zig-out/vort-zstd-compare-standard.csv",
        "--markdown",
        "zig-out/vort-zstd-compare-standard.md",
        "--optimize",
        @tagName(optimize),
    });
    if (b.args) |args| zstd_compare_standard.addArgs(args);
    const zstd_compare_standard_step = b.step("run-zstd-compare-standard", "Discover standard corpora and compare zstd/Vort smoke rows");
    zstd_compare_standard_step.dependOn(&zstd_compare_standard.step);

    const zstd_compare_standard_gate = b.addSystemCommand(&.{
        "python3",
        "tools/zstd_compare_gate.py",
        "--csv",
        "zig-out/vort-zstd-compare-standard.csv",
        "--markdown",
        "zig-out/vort-zstd-compare-standard.md",
        "--expect-source-mode",
        "standard-suite",
        "--expect-size-mode",
        "bounded-128KiB",
        "--expect-optimize",
        @tagName(optimize),
        "--expect-case-limit",
        "3",
        "--summary",
        "zig-out/vort-zstd-compare-standard-gate.json",
    });
    zstd_compare_standard_gate.step.dependOn(zstd_compare_standard_step);
    const zstd_compare_standard_gate_step = b.step("run-zstd-compare-standard-gate", "Validate standard-corpus zstd comparison artifacts");
    zstd_compare_standard_gate_step.dependOn(&zstd_compare_standard_gate.step);

    const zstd_compare_standard_releasefast = b.addSystemCommand(&.{ "python3", "tools/zstd_compare.py" });
    zstd_compare_standard_releasefast.addArtifactArg(cli_releasefast_exe);
    zstd_compare_standard_releasefast.addArgs(&.{
        "--standard-suite",
        "--limit",
        "12",
        "--csv",
        "zig-out/vort-zstd-compare-standard-releasefast.csv",
        "--markdown",
        "zig-out/vort-zstd-compare-standard-releasefast.md",
        "--optimize",
        "ReleaseFast",
    });
    if (b.args) |args| zstd_compare_standard_releasefast.addArgs(args);
    const zstd_compare_standard_releasefast_step = b.step("run-zstd-compare-standard-releasefast", "Discover standard corpora and compare zstd/Vort ReleaseFast smoke rows");
    zstd_compare_standard_releasefast_step.dependOn(&zstd_compare_standard_releasefast.step);

    const zstd_compare_standard_releasefast_gate = b.addSystemCommand(&.{
        "python3",
        "tools/zstd_compare_gate.py",
        "--csv",
        "zig-out/vort-zstd-compare-standard-releasefast.csv",
        "--markdown",
        "zig-out/vort-zstd-compare-standard-releasefast.md",
        "--expect-source-mode",
        "standard-suite",
        "--expect-size-mode",
        "bounded-128KiB",
        "--expect-optimize",
        "ReleaseFast",
        "--expect-case-limit",
        "12",
        "--summary",
        "zig-out/vort-zstd-compare-standard-releasefast-gate.json",
    });
    zstd_compare_standard_releasefast_gate.step.dependOn(zstd_compare_standard_releasefast_step);
    const zstd_compare_standard_releasefast_gate_step = b.step("run-zstd-compare-standard-releasefast-gate", "Validate ReleaseFast standard-corpus zstd comparison artifacts");
    zstd_compare_standard_releasefast_gate_step.dependOn(&zstd_compare_standard_releasefast_gate.step);

    const compression_report_exe = b.addExecutable(.{
        .name = "vort-compression-report",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/compression_report.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_compression_report = b.addRunArtifact(compression_report_exe);
    const compression_report_step = b.step("run-compression-report", "Report fixed-encoder compression sizes on small built-in corpus");
    compression_report_step.dependOn(&run_compression_report.step);

    const dictionary_report_exe = b.addExecutable(.{
        .name = "vort-dictionary-report",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/dictionary_report.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_dictionary_report = b.addRunArtifact(dictionary_report_exe);
    if (b.args) |args| run_dictionary_report.addArgs(args);
    const dictionary_report_step = b.step("run-dictionary-report", "Report deterministic dictionary training metadata");
    dictionary_report_step.dependOn(&run_dictionary_report.step);

    const native_dictionary_report_exe = b.addExecutable(.{
        .name = "vort-native-dictionary-report",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/native_dictionary_report.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_native_dictionary_report = b.addRunArtifact(native_dictionary_report_exe);
    if (b.args) |args| run_native_dictionary_report.addArgs(args);
    const native_dictionary_report_step = b.step("run-native-dictionary-report", "Report native LZ4/Zstd dictionary encoding savings");
    native_dictionary_report_step.dependOn(&run_native_dictionary_report.step);

    const native_library_bench_exe = b.addExecutable(.{
        .name = "vort-native-library-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/native_library_bench.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_native_library_bench = b.addRunArtifact(native_library_bench_exe);
    if (b.args) |args| run_native_library_bench.addArgs(args);
    const native_library_bench_step = b.step("run-native-library-bench", "Benchmark native LZ4/Zstd public library APIs");
    native_library_bench_step.dependOn(&run_native_library_bench.step);

    const run_native_library_bench_csv = b.addRunArtifact(native_library_bench_exe);
    run_native_library_bench_csv.addArgs(&.{ "--iterations", "25", "--csv", "zig-out/vort-native-library-bench.csv" });
    const native_library_bench_csv_step = b.step("run-native-library-bench-csv", "Write native LZ4/Zstd public library benchmark CSV");
    native_library_bench_csv_step.dependOn(&run_native_library_bench_csv.step);

    const native_library_bench_gate = b.addSystemCommand(&.{
        "python3",
        "tools/native_library_bench_gate.py",
        "--csv",
        "zig-out/vort-native-library-bench.csv",
    });
    native_library_bench_gate.step.dependOn(native_library_bench_csv_step);
    const native_library_bench_gate_step = b.step("run-native-library-bench-gate", "Validate native LZ4/Zstd public library benchmark CSV");
    native_library_bench_gate_step.dependOn(&native_library_bench_gate.step);

    const snappy_report_exe = b.addExecutable(.{
        .name = "vort-snappy-report",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/snappy_report.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_snappy_report = b.addRunArtifact(snappy_report_exe);
    if (b.args) |args| run_snappy_report.addArgs(args);
    const snappy_report_step = b.step("run-snappy-report", "Report dependency-free Snappy raw/framed ratio and throughput");
    snappy_report_step.dependOn(&run_snappy_report.step);

    const run_snappy_report_csv = b.addRunArtifact(snappy_report_exe);
    run_snappy_report_csv.addArgs(&.{ "--iterations", "25", "--csv", "zig-out/vort-snappy-report.csv" });
    const snappy_report_csv_step = b.step("run-snappy-report-csv", "Write dependency-free Snappy raw/framed report CSV");
    snappy_report_csv_step.dependOn(&run_snappy_report_csv.step);

    const snappy_report_gate = b.addSystemCommand(&.{
        "python3",
        "tools/snappy_report_gate.py",
        "--csv",
        "zig-out/vort-snappy-report.csv",
    });
    if (optimize == .ReleaseFast) {
        snappy_report_gate.addArg("--enforce-throughput");
    }
    snappy_report_gate.step.dependOn(snappy_report_csv_step);
    const snappy_report_gate_step = b.step("run-snappy-report-gate", "Validate dependency-free Snappy raw/framed report CSV");
    snappy_report_gate_step.dependOn(&snappy_report_gate.step);

    const snappy_reference_bench_exe = b.addExecutable(.{
        .name = "vort-snappy-reference-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/snappy/reference_bench.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod_releasefast },
                .{ .name = "benchmark_provenance", .module = benchmark_provenance_mod },
            },
        }),
    });
    const run_snappy_reference_bench =
        b.addRunArtifact(snappy_reference_bench_exe);
    if (b.args) |args| run_snappy_reference_bench.addArgs(args);
    const snappy_reference_bench_step = b.step(
        "run-snappy-reference-bench",
        "Compare caller-owned Snappy decode against runtime libsnappy",
    );
    snappy_reference_bench_step.dependOn(
        &run_snappy_reference_bench.step,
    );

    const run_snappy_reference_bench_gate_csv =
        b.addRunArtifact(snappy_reference_bench_exe);
    run_snappy_reference_bench_gate_csv.addArgs(&.{
        "--iterations",
        "5000",
        "--csv",
        "zig-out/vort-snappy-reference-bench.csv",
    });
    const snappy_reference_bench_gate = b.addSystemCommand(&.{
        "python3",
        "tools/snappy/reference_bench_gate.py",
        "--csv",
        "zig-out/vort-snappy-reference-bench.csv",
    });
    snappy_reference_bench_gate.addArg("--executable");
    snappy_reference_bench_gate.addArtifactArg(snappy_reference_bench_exe);
    snappy_reference_bench_gate.step.dependOn(
        &run_snappy_reference_bench_gate_csv.step,
    );
    const snappy_reference_bench_gate_step = b.step(
        "run-snappy-reference-bench-gate",
        "Validate optional Vort/libsnappy caller-owned decode comparison",
    );
    snappy_reference_bench_gate_step.dependOn(
        &snappy_reference_bench_gate.step,
    );

    const lz4_reference_bench_exe = b.addExecutable(.{
        .name = "vort-lz4-reference-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/lz4/reference_bench.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod_releasefast },
                .{ .name = "benchmark_provenance", .module = benchmark_provenance_mod },
            },
        }),
    });
    const run_lz4_reference_bench =
        b.addRunArtifact(lz4_reference_bench_exe);
    if (b.args) |args| run_lz4_reference_bench.addArgs(args);
    const lz4_reference_bench_step = b.step(
        "run-lz4-reference-bench",
        "Compare caller-owned LZ4 block decode against runtime liblz4",
    );
    lz4_reference_bench_step.dependOn(&run_lz4_reference_bench.step);

    const run_lz4_reference_bench_gate_csv =
        b.addRunArtifact(lz4_reference_bench_exe);
    run_lz4_reference_bench_gate_csv.addArgs(&.{
        "--iterations",
        "5000",
        "--csv",
        "zig-out/vort-lz4-reference-bench.csv",
    });
    const lz4_reference_bench_gate = b.addSystemCommand(&.{
        "python3",
        "tools/lz4/reference_bench_gate.py",
        "--csv",
        "zig-out/vort-lz4-reference-bench.csv",
    });
    lz4_reference_bench_gate.addArg("--executable");
    lz4_reference_bench_gate.addArtifactArg(lz4_reference_bench_exe);
    lz4_reference_bench_gate.step.dependOn(
        &run_lz4_reference_bench_gate_csv.step,
    );
    const lz4_reference_bench_gate_step = b.step(
        "run-lz4-reference-bench-gate",
        "Validate optional Vort/liblz4 caller-owned decode comparison",
    );
    lz4_reference_bench_gate_step.dependOn(
        &lz4_reference_bench_gate.step,
    );

    const lz4_decode_profile_exe = b.addExecutable(.{
        .name = "vort-lz4-decode-profile",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/lz4/decode_profile.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_lz4_decode_profile = b.addRunArtifact(lz4_decode_profile_exe);
    if (b.args) |args| run_lz4_decode_profile.addArgs(args);
    const lz4_decode_profile_step = b.step(
        "run-lz4-decode-profile",
        "Profile pure-Vort caller-owned LZ4 block decode hot cases",
    );
    lz4_decode_profile_step.dependOn(&run_lz4_decode_profile.step);

    const run_lz4_decode_profile_gate_csv = b.addRunArtifact(lz4_decode_profile_exe);
    run_lz4_decode_profile_gate_csv.addArgs(&.{
        "--iterations", "1000",
        "--csv",        "zig-out/vort-lz4-decode-profile.csv",
    });
    const lz4_decode_profile_gate = b.addSystemCommand(&.{
        "python3", "tools/lz4/decode_profile_gate.py",
        "--csv",   "zig-out/vort-lz4-decode-profile.csv",
    });
    lz4_decode_profile_gate.step.dependOn(&run_lz4_decode_profile_gate_csv.step);
    const lz4_decode_profile_gate_step = b.step(
        "run-lz4-decode-profile-gate",
        "Validate pure-Vort LZ4 decode profile coverage",
    );
    lz4_decode_profile_gate_step.dependOn(&lz4_decode_profile_gate.step);

    const br_reference_bench_exe = b.addExecutable(.{
        .name = "vort-br-reference-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/br/reference_bench.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod_releasefast },
                .{ .name = "benchmark_provenance", .module = benchmark_provenance_mod },
            },
        }),
    });
    const run_br_reference_bench = b.addRunArtifact(br_reference_bench_exe);
    if (b.args) |args| run_br_reference_bench.addArgs(args);
    const br_reference_bench_step = b.step(
        "run-br-reference-bench",
        "Compare caller-owned Brotli decode against runtime libbrotli",
    );
    br_reference_bench_step.dependOn(&run_br_reference_bench.step);

    const run_br_reference_bench_gate_csv = b.addRunArtifact(br_reference_bench_exe);
    run_br_reference_bench_gate_csv.addArgs(&.{
        "--iterations", "500",
        "--csv",        "zig-out/vort-br-reference-bench.csv",
    });
    const br_reference_bench_gate = b.addSystemCommand(&.{
        "python3", "tools/br/reference_bench_gate.py",
        "--csv",   "zig-out/vort-br-reference-bench.csv",
    });
    br_reference_bench_gate.addArgs(&.{ "--enforce-throughput", "--executable" });
    br_reference_bench_gate.addArtifactArg(br_reference_bench_exe);
    br_reference_bench_gate.step.dependOn(&run_br_reference_bench_gate_csv.step);
    const br_reference_bench_gate_step = b.step(
        "run-br-reference-bench-gate",
        "Validate optional Vort/libbrotli caller-owned decode comparison",
    );
    br_reference_bench_gate_step.dependOn(&br_reference_bench_gate.step);
    const br_reference_bench_path_smoke = b.addSystemCommand(&.{
        "python3", "tools/br/reference_bench_path_smoke.py",
    });
    br_reference_bench_path_smoke.addArtifactArg(br_reference_bench_exe);
    const br_reference_bench_path_smoke_step = b.step(
        "run-br-reference-bench-path-smoke",
        "Validate raw and pre-encoded file inputs for the Brotli benchmark",
    );
    br_reference_bench_path_smoke_step.dependOn(
        &br_reference_bench_path_smoke.step,
    );

    const br_compressed_header_profile_exe = b.addExecutable(.{
        .name = "vort-br-compressed-header-profile",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/br/compressed_header_profile.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_br_compressed_header_profile = b.addRunArtifact(br_compressed_header_profile_exe);
    if (b.args) |args| run_br_compressed_header_profile.addArgs(args);
    const br_compressed_header_profile_step = b.step(
        "run-br-compressed-header-profile",
        "Profile Brotli compressed-header parsing and table construction",
    );
    br_compressed_header_profile_step.dependOn(&run_br_compressed_header_profile.step);

    const run_br_compressed_header_profile_gate_csv = b.addRunArtifact(br_compressed_header_profile_exe);
    run_br_compressed_header_profile_gate_csv.addArgs(&.{
        "--iterations", "100",
        "--csv",        "zig-out/vort-br-compressed-header-profile.csv",
    });
    const br_compressed_header_profile_gate = b.addSystemCommand(&.{
        "python3", "tools/br/compressed_header_profile_gate.py",
        "--csv",   "zig-out/vort-br-compressed-header-profile.csv",
    });
    br_compressed_header_profile_gate.step.dependOn(&run_br_compressed_header_profile_gate_csv.step);
    const br_compressed_header_profile_gate_step = b.step(
        "run-br-compressed-header-profile-gate",
        "Validate Brotli compressed-header stage profile CSV",
    );
    br_compressed_header_profile_gate_step.dependOn(&br_compressed_header_profile_gate.step);

    const br_upstream_multiblock_diff_exe = b.addExecutable(.{
        .name = "vort-br-upstream-multiblock-diff",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/br/upstream_multiblock_diff.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_br_upstream_multiblock_diff = b.addRunArtifact(br_upstream_multiblock_diff_exe);
    if (b.args) |args| run_br_upstream_multiblock_diff.addArgs(args);
    const br_upstream_multiblock_diff_step = b.step(
        "run-br-upstream-multiblock-diff",
        "Decode streamed multi-meta-block libbrotli operation schedules byte progressively",
    );
    br_upstream_multiblock_diff_step.dependOn(&run_br_upstream_multiblock_diff.step);

    const br_real_corpus_diff_smoke = b.addSystemCommand(&.{
        "python3", "tools/br/real_corpus_diff_smoke.py",
    });
    const br_real_corpus_diff_smoke_step = b.step(
        "run-br-real-corpus-diff-smoke",
        "Validate the Brotli real-corpus manifest and gate driver",
    );
    br_real_corpus_diff_smoke_step.dependOn(&br_real_corpus_diff_smoke.step);

    const br_real_corpus_diff = b.addSystemCommand(&.{
        "python3", "tools/br/real_corpus_diff.py",
    });
    br_real_corpus_diff.addArtifactArg(br_upstream_multiblock_diff_exe);
    if (b.args) |args| br_real_corpus_diff.addArgs(args);
    br_real_corpus_diff.step.dependOn(&br_real_corpus_diff_smoke.step);
    const br_real_corpus_diff_step = b.step(
        "run-br-real-corpus-diff",
        "Require one-shot and progressive Brotli decoding across real repository corpora",
    );
    br_real_corpus_diff_step.dependOn(&br_real_corpus_diff.step);

    const br_progressive_copy_bench_exe = b.addExecutable(.{
        .name = "vort-br-progressive-copy-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/br/progressive_copy_bench.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_br_progressive_copy_bench = b.addRunArtifact(br_progressive_copy_bench_exe);
    if (b.args) |args| run_br_progressive_copy_bench.addArgs(args);
    const br_progressive_copy_bench_step = b.step(
        "run-br-progressive-copy-bench",
        "Measure caller-owned byte-progressive Brotli copy decoding",
    );
    br_progressive_copy_bench_step.dependOn(&run_br_progressive_copy_bench.step);
    const run_br_progressive_copy_bench_csv = b.addRunArtifact(br_progressive_copy_bench_exe);
    run_br_progressive_copy_bench_csv.addArg("100");
    const br_progressive_copy_bench_gate = b.addSystemCommand(&.{
        "python3", "tools/br/progressive_copy_bench_gate.py", "--csv",
    });
    br_progressive_copy_bench_gate.addFileArg(run_br_progressive_copy_bench_csv.captureStdOut(.{}));
    const br_progressive_copy_bench_gate_step = b.step(
        "run-br-progressive-copy-bench-gate",
        "Validate caller-owned byte-progressive Brotli copy throughput",
    );
    br_progressive_copy_bench_gate_step.dependOn(&br_progressive_copy_bench_gate.step);

    const br_progressive_huffman_bench_exe = b.addExecutable(.{
        .name = "vort-br-progressive-huffman-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/br/progressive_huffman_bench.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_br_progressive_huffman_bench = b.addRunArtifact(br_progressive_huffman_bench_exe);
    if (b.args) |args| run_br_progressive_huffman_bench.addArgs(args);
    const br_progressive_huffman_bench_step = b.step(
        "run-br-progressive-huffman-bench",
        "Measure progressive Brotli command and distance decode workloads",
    );
    br_progressive_huffman_bench_step.dependOn(&run_br_progressive_huffman_bench.step);
    const run_br_progressive_huffman_bench_csv = b.addRunArtifact(br_progressive_huffman_bench_exe);
    run_br_progressive_huffman_bench_csv.addArgs(&.{ "--iterations", "20" });
    const br_progressive_huffman_bench_gate = b.addSystemCommand(&.{
        "python3", "tools/br/progressive_huffman_bench_gate.py", "--csv",
    });
    br_progressive_huffman_bench_gate.addFileArg(run_br_progressive_huffman_bench_csv.captureStdOut(.{}));
    const br_progressive_huffman_bench_gate_step = b.step(
        "run-br-progressive-huffman-bench-gate",
        "Validate progressive Brotli command/distance benchmark coverage",
    );
    br_progressive_huffman_bench_gate_step.dependOn(&br_progressive_huffman_bench_gate.step);

    const br_incremental_planned_bench_exe = b.addExecutable(.{
        .name = "vort-br-incremental-planned-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/br/incremental_planned_bench.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{.{ .name = "vort", .module = vort_mod_releasefast }},
        }),
    });
    const run_br_incremental_planned_bench = b.addRunArtifact(br_incremental_planned_bench_exe);
    if (b.args) |args| run_br_incremental_planned_bench.addArgs(args);
    const br_incremental_planned_bench_step = b.step("run-br-incremental-planned-bench", "Compare warmed incremental and one-shot Brotli planning");
    br_incremental_planned_bench_step.dependOn(&run_br_incremental_planned_bench.step);
    const run_br_incremental_planned_bench_csv = b.addRunArtifact(br_incremental_planned_bench_exe);
    run_br_incremental_planned_bench_csv.addArg("200");
    const br_incremental_planned_bench_gate = b.addSystemCommand(&.{ "python3", "tools/br/incremental_planned_bench_gate.py", "--csv" });
    br_incremental_planned_bench_gate.addFileArg(run_br_incremental_planned_bench_csv.captureStdOut(.{}));
    const br_incremental_planned_bench_gate_step = b.step("run-br-incremental-planned-bench-gate", "Validate warmed incremental Brotli planner reuse");
    br_incremental_planned_bench_gate_step.dependOn(&br_incremental_planned_bench_gate.step);

    const zstd_reference_bench_exe = b.addExecutable(.{
        .name = "vort-zstd-reference-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/zstd/reference_bench.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod_releasefast },
                .{ .name = "benchmark_provenance", .module = benchmark_provenance_mod },
            },
        }),
    });
    const benchmark_provenance_tests = b.addTest(.{
        .name = "vort-benchmark-provenance-tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/benchmark_provenance.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });
    const run_benchmark_provenance_tests = b.addRunArtifact(benchmark_provenance_tests);
    const benchmark_provenance_test_step = b.step("test-benchmark-provenance", "Test shared benchmark provenance capture");
    benchmark_provenance_test_step.dependOn(&run_benchmark_provenance_tests.step);
    const benchmark_provenance_gate_smoke = b.addSystemCommand(&.{ "python3", "tools/benchmark_provenance_gate_smoke.py" });
    const benchmark_provenance_gate_smoke_step = b.step("run-benchmark-provenance-gate-smoke", "Validate shared benchmark provenance gate positive and negative paths");
    benchmark_provenance_gate_smoke_step.dependOn(&benchmark_provenance_gate_smoke.step);
    const run_zstd_reference_bench =
        b.addRunArtifact(zstd_reference_bench_exe);
    if (b.args) |args| run_zstd_reference_bench.addArgs(args);
    const zstd_reference_bench_step = b.step(
        "run-zstd-reference-bench",
        "Compare caller-owned Zstd decode against runtime libzstd",
    );
    zstd_reference_bench_step.dependOn(&run_zstd_reference_bench.step);

    const run_zstd_reference_bench_gate_csv =
        b.addRunArtifact(zstd_reference_bench_exe);
    run_zstd_reference_bench_gate_csv.addArgs(&.{
        "--iterations", "5000",
        "--csv",        "zig-out/vort-zstd-reference-bench.csv",
    });
    const zstd_reference_bench_gate = b.addSystemCommand(&.{
        "python3",      "tools/zstd/reference_bench_gate.py",
        "--csv",        "zig-out/vort-zstd-reference-bench.csv",
        "--executable",
    });
    zstd_reference_bench_gate.addArtifactArg(zstd_reference_bench_exe);
    zstd_reference_bench_gate.step.dependOn(
        &run_zstd_reference_bench_gate_csv.step,
    );
    const zstd_reference_bench_gate_step = b.step(
        "run-zstd-reference-bench-gate",
        "Validate optional Vort/libzstd caller-owned decode comparison",
    );
    zstd_reference_bench_gate_step.dependOn(
        &zstd_reference_bench_gate.step,
    );
    const run_zstd_reusable_reference_csv = b.addRunArtifact(zstd_reference_bench_exe);
    run_zstd_reusable_reference_csv.addArgs(&.{
        "--reusable", "--iterations",                                   "5000",
        "--csv",      "zig-out/vort-zstd-reusable-reference-bench.csv",
    });
    const zstd_reusable_reference_gate = b.addSystemCommand(&.{
        "python3",      "tools/zstd/reference_bench_gate.py",
        "--api-mode",   "reusable",
        "--csv",        "zig-out/vort-zstd-reusable-reference-bench.csv",
        "--executable",
    });
    zstd_reusable_reference_gate.addArtifactArg(zstd_reference_bench_exe);
    zstd_reusable_reference_gate.step.dependOn(&run_zstd_reusable_reference_csv.step);
    const zstd_reusable_reference_gate_step = b.step(
        "run-zstd-reusable-reference-bench-gate",
        "Compare warmed Vort and libzstd decoder contexts with explicit API validation",
    );
    zstd_reusable_reference_gate_step.dependOn(&zstd_reusable_reference_gate.step);
    const zstd_reference_bench_path_smoke = b.addSystemCommand(&.{
        "python3", "tools/zstd/reference_bench_path_smoke.py",
    });
    zstd_reference_bench_path_smoke.addArtifactArg(zstd_reference_bench_exe);
    const zstd_reference_bench_path_smoke_step = b.step(
        "run-zstd-reference-bench-path-smoke",
        "Validate file-backed Zstd decode benchmark inputs",
    );
    zstd_reference_bench_path_smoke_step.dependOn(
        &zstd_reference_bench_path_smoke.step,
    );

    const zstd_decode_profile_exe = b.addExecutable(.{
        .name = "vort-zstd-decode-profile",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/zstd/decode_profile.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod_releasefast },
                .{ .name = "benchmark_provenance", .module = benchmark_provenance_mod },
            },
        }),
    });
    const run_zstd_decode_profile = b.addRunArtifact(zstd_decode_profile_exe);
    if (b.args) |args| run_zstd_decode_profile.addArgs(args);
    const zstd_decode_profile_step = b.step(
        "run-zstd-decode-profile",
        "Profile pure-Vort caller-owned Zstd decode hot cases",
    );
    zstd_decode_profile_step.dependOn(&run_zstd_decode_profile.step);

    const run_zstd_decode_profile_gate_csv = b.addRunArtifact(zstd_decode_profile_exe);
    run_zstd_decode_profile_gate_csv.addArgs(&.{
        "--iterations", "100",
        "--csv",        "zig-out/vort-zstd-decode-profile.csv",
    });
    const zstd_decode_profile_gate = b.addSystemCommand(&.{
        "python3",      "tools/zstd/decode_profile_gate.py",
        "--csv",        "zig-out/vort-zstd-decode-profile.csv",
        "--executable",
    });
    zstd_decode_profile_gate.addArtifactArg(zstd_decode_profile_exe);
    zstd_decode_profile_gate.step.dependOn(&run_zstd_decode_profile_gate_csv.step);
    const zstd_decode_profile_gate_step = b.step(
        "run-zstd-decode-profile-gate",
        "Validate pure-Vort Zstd decode profile coverage",
    );
    zstd_decode_profile_gate_step.dependOn(&zstd_decode_profile_gate.step);
    const zstd_decode_profile_path_smoke = b.addSystemCommand(&.{
        "python3", "tools/zstd/decode_profile_path_smoke.py",
    });
    zstd_decode_profile_path_smoke.addArtifactArg(zstd_decode_profile_exe);
    const zstd_decode_profile_path_smoke_step = b.step(
        "run-zstd-decode-profile-path-smoke",
        "Validate file-backed Zstd decode profile inputs",
    );
    zstd_decode_profile_path_smoke_step.dependOn(
        &zstd_decode_profile_path_smoke.step,
    );

    const zstd_sequence_decode_stage_bench_exe = b.addExecutable(.{
        .name = "vort-zstd-sequence-decode-stage-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/zstd/sequence_decode_stage_bench.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod_releasefast },
                .{ .name = "benchmark_provenance", .module = benchmark_provenance_mod },
            },
        }),
    });
    const run_zstd_sequence_decode_stage_bench = b.addRunArtifact(zstd_sequence_decode_stage_bench_exe);
    if (b.args) |args| run_zstd_sequence_decode_stage_bench.addArgs(args);
    const zstd_sequence_decode_stage_bench_step = b.step(
        "run-zstd-sequence-decode-stage-bench",
        "Benchmark prepared Zstd sequence bit/FSE decode without literal or match copies",
    );
    zstd_sequence_decode_stage_bench_step.dependOn(&run_zstd_sequence_decode_stage_bench.step);

    const zstd_interleaved_block_bench_exe = b.addExecutable(.{
        .name = "vort-zstd-interleaved-block-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/zstd/interleaved_block_bench.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod_releasefast },
                .{ .name = "benchmark_provenance", .module = benchmark_provenance_mod },
            },
        }),
    });
    const run_zstd_interleaved_block_bench = b.addRunArtifact(zstd_interleaved_block_bench_exe);
    if (b.args) |args| run_zstd_interleaved_block_bench.addArgs(args);
    const zstd_interleaved_block_bench_step = b.step(
        "run-zstd-interleaved-block-bench",
        "Benchmark prepared medium all-FSE/Huffman blocks with real match copies",
    );
    zstd_interleaved_block_bench_step.dependOn(&run_zstd_interleaved_block_bench.step);

    const zstd_encode_bench_exe = b.addExecutable(.{
        .name = "vort-zstd-encode-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/zstd/encode_bench.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod_releasefast },
                .{ .name = "benchmark_provenance", .module = benchmark_provenance_mod },
            },
        }),
    });
    const run_zstd_encode_bench = b.addRunArtifact(zstd_encode_bench_exe);
    if (b.args) |args| run_zstd_encode_bench.addArgs(args);
    const zstd_encode_bench_step = b.step("run-zstd-encode-bench", "Compare Zstd encoding with runtime libzstd");
    zstd_encode_bench_step.dependOn(&run_zstd_encode_bench.step);
    const run_zstd_encode_bench_csv = b.addRunArtifact(zstd_encode_bench_exe);
    run_zstd_encode_bench_csv.addArgs(&.{ "--iterations", "3", "--rounds", "3", "--csv", "zig-out/vort-zstd-encode-bench.csv" });
    const zstd_encode_bench_gate = b.addSystemCommand(&.{ "python3", "tools/zstd/encode_bench_gate.py", "--csv", "zig-out/vort-zstd-encode-bench.csv", "--executable" });
    zstd_encode_bench_gate.addArtifactArg(zstd_encode_bench_exe);
    zstd_encode_bench_gate.step.dependOn(&run_zstd_encode_bench_csv.step);
    const zstd_encode_bench_gate_step = b.step("run-zstd-encode-bench-gate", "Validate Zstd encode comparison CSV");
    zstd_encode_bench_gate_step.dependOn(&zstd_encode_bench_gate.step);
    const zstd_encode_bench_path_smoke = b.addSystemCommand(&.{ "python3", "tools/zstd/encode_bench_path_smoke.py" });
    zstd_encode_bench_path_smoke.addArtifactArg(zstd_encode_bench_exe);
    const zstd_encode_bench_path_smoke_step = b.step("run-zstd-encode-bench-path-smoke", "Validate file-backed Zstd encode benchmark inputs");
    zstd_encode_bench_path_smoke_step.dependOn(&zstd_encode_bench_path_smoke.step);
    const run_zstd_fast_compressed_bench = b.addRunArtifact(zstd_encode_bench_exe);
    run_zstd_fast_compressed_bench.addArgs(&.{
        "--native-selection", "fast_compressed",
        "--level",            "1",
        "--iterations",       "100",
        "--rounds",           "5",
        "--csv",              "zig-out/vort-zstd-fast-compressed-bench.csv",
    });
    if (b.args) |args| run_zstd_fast_compressed_bench.addArgs(args);
    const zstd_fast_compressed_bench_step = b.step(
        "run-zstd-fast-compressed-bench",
        "Retain the explicit fast-compressed Zstd Pareto benchmark",
    );
    zstd_fast_compressed_bench_step.dependOn(&run_zstd_fast_compressed_bench.step);
    const zstd_fast_compressed_bench_gate = b.addSystemCommand(&.{
        "python3",      "tools/zstd/fast_compressed_bench_gate.py",
        "--csv",        "zig-out/vort-zstd-fast-compressed-bench.csv",
        "--executable",
    });
    zstd_fast_compressed_bench_gate.addArtifactArg(zstd_encode_bench_exe);
    zstd_fast_compressed_bench_gate.step.dependOn(&run_zstd_fast_compressed_bench.step);
    const zstd_fast_compressed_bench_gate_step = b.step(
        "run-zstd-fast-compressed-bench-gate",
        "Validate the explicit fast-compressed Zstd Pareto benchmark",
    );
    zstd_fast_compressed_bench_gate_step.dependOn(&zstd_fast_compressed_bench_gate.step);

    const zstd_level_schedule_bench_exe = b.addExecutable(.{
        .name = "vort-zstd-level-schedule-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/zstd/level_schedule_bench.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod_releasefast },
                .{ .name = "benchmark_provenance", .module = benchmark_provenance_mod },
            },
        }),
    });
    const run_zstd_level_schedule_bench = b.addRunArtifact(zstd_level_schedule_bench_exe);
    if (b.args) |args| run_zstd_level_schedule_bench.addArgs(args);
    const zstd_level_schedule_bench_step = b.step("run-zstd-level-schedule-bench", "Compare parallel and serial Zstd level scheduling");
    zstd_level_schedule_bench_step.dependOn(&run_zstd_level_schedule_bench.step);
    const run_zstd_level_schedule_bench_csv = b.addRunArtifact(zstd_level_schedule_bench_exe);
    run_zstd_level_schedule_bench_csv.addArgs(&.{ "--iterations", "1", "--rounds", "5", "--csv", "zig-out/vort-zstd-level-schedule-bench.csv" });
    const zstd_level_schedule_bench_gate = b.addSystemCommand(&.{ "python3", "tools/zstd/level_schedule_bench_gate.py", "--csv", "zig-out/vort-zstd-level-schedule-bench.csv", "--executable" });
    zstd_level_schedule_bench_gate.addArtifactArg(zstd_level_schedule_bench_exe);
    zstd_level_schedule_bench_gate.step.dependOn(&run_zstd_level_schedule_bench_csv.step);
    const zstd_level_schedule_bench_gate_step = b.step("run-zstd-level-schedule-bench-gate", "Validate Zstd level scheduling benchmark");
    zstd_level_schedule_bench_gate_step.dependOn(&zstd_level_schedule_bench_gate.step);

    const zstd_seekable_parallel_bench_exe = b.addExecutable(.{
        .name = "vort-zstd-seekable-parallel-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/zstd/seekable_parallel_bench.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod_releasefast },
                .{ .name = "benchmark_provenance", .module = benchmark_provenance_mod },
            },
        }),
    });
    const run_zstd_seekable_parallel_bench = b.addRunArtifact(zstd_seekable_parallel_bench_exe);
    if (b.args) |args| run_zstd_seekable_parallel_bench.addArgs(args);
    const zstd_seekable_parallel_bench_step = b.step(
        "run-zstd-seekable-parallel-bench",
        "Benchmark deterministic parallel native Zstd seekable encoding",
    );
    zstd_seekable_parallel_bench_step.dependOn(&run_zstd_seekable_parallel_bench.step);
    const run_zstd_seekable_parallel_bench_csv = b.addRunArtifact(zstd_seekable_parallel_bench_exe);
    run_zstd_seekable_parallel_bench_csv.addArgs(&.{
        "--iterations", "2",
        "--rounds",     "5",
        "--csv",        "zig-out/vort-zstd-seekable-parallel-bench.csv",
    });
    const zstd_seekable_parallel_bench_gate = b.addSystemCommand(&.{
        "python3",      "tools/zstd/seekable_parallel_bench_gate.py",
        "--csv",        "zig-out/vort-zstd-seekable-parallel-bench.csv",
        "--executable",
    });
    zstd_seekable_parallel_bench_gate.addArtifactArg(zstd_seekable_parallel_bench_exe);
    zstd_seekable_parallel_bench_gate.step.dependOn(&run_zstd_seekable_parallel_bench_csv.step);
    const zstd_seekable_parallel_bench_gate_step = b.step(
        "run-zstd-seekable-parallel-bench-gate",
        "Validate parallel native Zstd seekable benchmark evidence",
    );
    zstd_seekable_parallel_bench_gate_step.dependOn(&zstd_seekable_parallel_bench_gate.step);

    const zstd_native_encode_stage_bench_exe = b.addExecutable(.{
        .name = "vort-zstd-native-encode-stage-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/zstd/native_encode_stage_bench.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod_releasefast },
                .{ .name = "benchmark_provenance", .module = benchmark_provenance_mod },
            },
        }),
    });
    const run_zstd_native_encode_stage_bench = b.addRunArtifact(zstd_native_encode_stage_bench_exe);
    if (b.args) |args| run_zstd_native_encode_stage_bench.addArgs(args);
    const zstd_native_encode_stage_bench_step = b.step("run-zstd-native-encode-stage-bench", "Measure native Zstd candidate-family stages");
    zstd_native_encode_stage_bench_step.dependOn(&run_zstd_native_encode_stage_bench.step);
    const run_zstd_native_encode_stage_bench_csv = b.addRunArtifact(zstd_native_encode_stage_bench_exe);
    run_zstd_native_encode_stage_bench_csv.addArgs(&.{ "--level", "9", "--iterations", "1", "--rounds", "1", "--warmup", "1", "--csv", "zig-out/vort-zstd-native-encode-stage-bench.csv" });
    const zstd_native_encode_stage_bench_gate = b.addSystemCommand(&.{ "python3", "tools/zstd/native_encode_stage_bench_gate.py", "--csv", "zig-out/vort-zstd-native-encode-stage-bench.csv", "--executable" });
    zstd_native_encode_stage_bench_gate.addArtifactArg(zstd_native_encode_stage_bench_exe);
    zstd_native_encode_stage_bench_gate.step.dependOn(&run_zstd_native_encode_stage_bench_csv.step);
    const zstd_native_encode_stage_bench_gate_step = b.step("run-zstd-native-encode-stage-bench-gate", "Validate native Zstd stage benchmark coverage");
    zstd_native_encode_stage_bench_gate_step.dependOn(&zstd_native_encode_stage_bench_gate.step);
    const zstd_native_encode_stage_bench_path_smoke = b.addSystemCommand(&.{ "python3", "tools/zstd/native_encode_stage_bench_path_smoke.py" });
    zstd_native_encode_stage_bench_path_smoke.addArtifactArg(zstd_native_encode_stage_bench_exe);
    const zstd_native_encode_stage_bench_path_smoke_step = b.step("run-zstd-native-encode-stage-bench-path-smoke", "Validate file-backed native Zstd stage benchmark inputs");
    zstd_native_encode_stage_bench_path_smoke_step.dependOn(&zstd_native_encode_stage_bench_path_smoke.step);

    const zstd_large_sequence_probe_exe = b.addExecutable(.{
        .name = "vort-zstd-large-sequence-probe",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/zstd/large_sequence_probe.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .link_libc = true,
            .imports = &.{.{ .name = "vort", .module = vort_mod_releasefast }},
        }),
    });
    const run_zstd_large_sequence_probe = b.addRunArtifact(zstd_large_sequence_probe_exe);
    const zstd_large_sequence_probe_step = b.step("run-zstd-large-sequence-probe", "Validate wide-block Zstd sequence encoding with runtime libzstd");
    zstd_large_sequence_probe_step.dependOn(&run_zstd_large_sequence_probe.step);

    const zstd_dictionary_probe_exe = b.addExecutable(.{
        .name = "vort-zstd-dictionary-probe",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/zstd/dictionary_probe.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{.{ .name = "vort", .module = vort_mod_releasefast }},
        }),
    });
    const zstd_dictionary_probe_step = b.step("build-zstd-dictionary-probe", "Build standard Zstd dictionary inspector");
    zstd_dictionary_probe_step.dependOn(&zstd_dictionary_probe_exe.step);
    const zstd_full_dictionary_diff_exe = b.addExecutable(.{
        .name = "vort-zstd-full-dictionary-diff",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/zstd/full_dictionary_diff.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .link_libc = true,
            .imports = &.{.{ .name = "vort", .module = vort_mod_releasefast }},
        }),
    });
    const zstd_full_dictionary_diff = b.addSystemCommand(&.{ "python3", "tools/zstd/full_dictionary_diff.py" });
    zstd_full_dictionary_diff.addArtifactArg(zstd_full_dictionary_diff_exe);
    const zstd_full_dictionary_diff_step = b.step("run-zstd-full-dictionary-diff", "Train, generate, and validate standard Zstd full dictionaries");
    zstd_full_dictionary_diff_step.dependOn(&zstd_full_dictionary_diff.step);

    const zstd_dictionary_trainer_compare_exe = b.addExecutable(.{
        .name = "vort-zstd-dictionary-trainer-compare",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/zstd/dictionary_trainer_compare.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .link_libc = true,
            .imports = &.{.{ .name = "vort", .module = vort_mod_releasefast }},
        }),
    });
    const zstd_dictionary_trainer_compare = b.addSystemCommand(&.{ "python3", "tools/zstd/dictionary_trainer_compare.py" });
    zstd_dictionary_trainer_compare.addArtifactArg(zstd_dictionary_trainer_compare_exe);
    const zstd_dictionary_trainer_compare_step = b.step("run-zstd-dictionary-trainer-compare", "Compare Vort and zstd dictionary trainers on held-out corpora");
    zstd_dictionary_trainer_compare_step.dependOn(&zstd_dictionary_trainer_compare.step);

    const dictionary_train_bench_exe = b.addExecutable(.{
        .name = "vort-dictionary-train-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/dictionary_train_bench.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{.{ .name = "vort", .module = vort_mod_releasefast }},
        }),
    });
    const run_dictionary_train_bench_csv = b.addRunArtifact(dictionary_train_bench_exe);
    run_dictionary_train_bench_csv.addArgs(&.{ "--iterations", "20", "--rounds", "3", "--csv", "zig-out/vort-dictionary-train-bench.csv" });
    const dictionary_train_bench_gate = b.addSystemCommand(&.{ "python3", "tools/dictionary_train_bench_gate.py", "--csv", "zig-out/vort-dictionary-train-bench.csv" });
    if (optimize == .ReleaseFast) dictionary_train_bench_gate.addArg("--enforce-throughput");
    dictionary_train_bench_gate.step.dependOn(&run_dictionary_train_bench_csv.step);
    const dictionary_train_bench_gate_step = b.step("run-dictionary-train-bench-gate", "Validate deterministic dictionary training throughput");
    dictionary_train_bench_gate_step.dependOn(&dictionary_train_bench_gate.step);

    const zstd_compat_probe_exe = b.addExecutable(.{
        .name = "vort-zstd-compat-probe",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/zstd/compat_probe.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod_releasefast },
            },
        }),
    });
    const run_zstd_compat_probe = b.addRunArtifact(zstd_compat_probe_exe);
    if (b.args) |args| run_zstd_compat_probe.addArgs(args);
    const zstd_compat_probe_step = b.step(
        "run-zstd-compat-probe",
        "Decode a broad system-libzstd frame matrix through Vort",
    );
    zstd_compat_probe_step.dependOn(&run_zstd_compat_probe.step);

    const zstd_decodecorpus_gate = b.addSystemCommand(&.{ "python3", "tools/zstd/decodecorpus_gate.py" });
    zstd_decodecorpus_gate.addArtifactArg(zstd_compat_probe_exe);
    if (b.args) |args| zstd_decodecorpus_gate.addArgs(args);
    const zstd_decodecorpus_gate_step = b.step(
        "run-zstd-decodecorpus-gate",
        "Generate and decode the deterministic upstream Zstd corpus suite",
    );
    zstd_decodecorpus_gate_step.dependOn(&zstd_decodecorpus_gate.step);

    const zstd_decodecorpus_gate_smoke = b.addSystemCommand(&.{ "python3", "tools/zstd/decodecorpus_gate_smoke.py" });
    const zstd_decodecorpus_gate_smoke_step = b.step(
        "run-zstd-decodecorpus-gate-smoke",
        "Validate Zstd decodecorpus gate orchestration and cleanup",
    );
    zstd_decodecorpus_gate_smoke_step.dependOn(&zstd_decodecorpus_gate_smoke.step);

    const run_native_library_bench_path_csv = b.addRunArtifact(native_library_bench_exe);
    run_native_library_bench_path_csv.addArgs(&.{
        "--iterations",
        "1",
        "--path",
        "corpus/native-library-bench-small.txt",
        "--limit",
        "4096",
        "--csv",
        "zig-out/vort-native-library-bench-path.csv",
    });
    const native_library_bench_path_csv_step = b.step("run-native-library-bench-path-csv", "Write native library benchmark CSV with a file payload");
    native_library_bench_path_csv_step.dependOn(&run_native_library_bench_path_csv.step);

    const native_library_bench_path_gate = b.addSystemCommand(&.{
        "python3",
        "tools/native_library_bench_gate.py",
        "--csv",
        "zig-out/vort-native-library-bench-path.csv",
        "--allow-extra-cases",
    });
    native_library_bench_path_gate.step.dependOn(native_library_bench_path_csv_step);
    const native_library_bench_path_gate_step = b.step("run-native-library-bench-path-gate", "Validate native library benchmark CSV with a file payload");
    native_library_bench_path_gate_step.dependOn(&native_library_bench_path_gate.step);

    const native_library_bench_releasefast_exe = b.addExecutable(.{
        .name = "vort-native-library-bench-releasefast",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/native_library_bench.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod_releasefast },
            },
        }),
    });
    const run_native_library_bench_releasefast_csv = b.addRunArtifact(native_library_bench_releasefast_exe);
    run_native_library_bench_releasefast_csv.addArgs(&.{ "--iterations", "25", "--csv", "zig-out/vort-native-library-bench-releasefast.csv" });
    const native_library_bench_releasefast_csv_step = b.step("run-native-library-bench-releasefast-csv", "Write ReleaseFast native LZ4/Zstd public library benchmark CSV");
    native_library_bench_releasefast_csv_step.dependOn(&run_native_library_bench_releasefast_csv.step);

    const native_library_bench_releasefast_gate = b.addSystemCommand(&.{
        "python3",
        "tools/native_library_bench_gate.py",
        "--csv",
        "zig-out/vort-native-library-bench-releasefast.csv",
    });
    native_library_bench_releasefast_gate.step.dependOn(native_library_bench_releasefast_csv_step);
    const native_library_bench_releasefast_gate_step = b.step("run-native-library-bench-releasefast-gate", "Validate ReleaseFast native LZ4/Zstd public library benchmark CSV");
    native_library_bench_releasefast_gate_step.dependOn(&native_library_bench_releasefast_gate.step);

    const run_native_library_bench_releasefast_path_csv = b.addRunArtifact(native_library_bench_releasefast_exe);
    run_native_library_bench_releasefast_path_csv.addArgs(&.{
        "--iterations",
        "1",
        "--path",
        "corpus/native-library-bench-small.txt",
        "--limit",
        "4096",
        "--csv",
        "zig-out/vort-native-library-bench-releasefast-path.csv",
    });
    const native_library_bench_releasefast_path_csv_step = b.step("run-native-library-bench-releasefast-path-csv", "Write ReleaseFast native library benchmark CSV with a file payload");
    native_library_bench_releasefast_path_csv_step.dependOn(&run_native_library_bench_releasefast_path_csv.step);

    const native_library_bench_releasefast_path_gate = b.addSystemCommand(&.{
        "python3",
        "tools/native_library_bench_gate.py",
        "--csv",
        "zig-out/vort-native-library-bench-releasefast-path.csv",
        "--allow-extra-cases",
    });
    native_library_bench_releasefast_path_gate.step.dependOn(native_library_bench_releasefast_path_csv_step);
    const native_library_bench_releasefast_path_gate_step = b.step("run-native-library-bench-releasefast-path-gate", "Validate ReleaseFast native library benchmark CSV with a file payload");
    native_library_bench_releasefast_path_gate_step.dependOn(&native_library_bench_releasefast_path_gate.step);

    const dictionary_decode_bench_exe = b.addExecutable(.{
        .name = "vort-dictionary-decode-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/dictionary_decode_bench.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_dictionary_decode_bench_csv = b.addRunArtifact(dictionary_decode_bench_exe);
    run_dictionary_decode_bench_csv.addArgs(&.{ "--repeat", "3", "--csv", "zig-out/vort-dictionary-decode-bench.csv" });
    const dictionary_decode_bench_csv_step = b.step("run-dictionary-decode-bench-csv", "Write preset-dictionary decode throughput CSV");
    dictionary_decode_bench_csv_step.dependOn(&run_dictionary_decode_bench_csv.step);

    const dictionary_decode_bench_gate = b.addSystemCommand(&.{
        "python3",
        "tools/dictionary_decode_bench_gate.py",
        "--csv",
        "zig-out/vort-dictionary-decode-bench.csv",
    });
    if (optimize == .ReleaseFast) dictionary_decode_bench_gate.addArg("--enforce-throughput");
    dictionary_decode_bench_gate.step.dependOn(dictionary_decode_bench_csv_step);
    const dictionary_decode_bench_gate_step = b.step("run-dictionary-decode-bench-gate", "Validate preset-dictionary decode benchmark CSV");
    dictionary_decode_bench_gate_step.dependOn(&dictionary_decode_bench_gate.step);

    const dictionary_deflate_report_exe = b.addExecutable(.{
        .name = "vort-dictionary-deflate-report",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/dictionary_deflate_report.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_dictionary_deflate_report = b.addRunArtifact(dictionary_deflate_report_exe);
    if (b.args) |args| run_dictionary_deflate_report.addArgs(args);
    const dictionary_deflate_report_step = b.step("run-dictionary-deflate-report", "Report raw/zlib preset-dictionary deflate encode savings");
    dictionary_deflate_report_step.dependOn(&run_dictionary_deflate_report.step);

    const run_dictionary_deflate_report_csv = b.addRunArtifact(dictionary_deflate_report_exe);
    run_dictionary_deflate_report_csv.addArgs(&.{ "--csv", "zig-out/vort-dictionary-deflate-report.csv" });
    const dictionary_deflate_report_csv_step = b.step("run-dictionary-deflate-report-csv", "Write raw/zlib preset-dictionary deflate savings CSV to zig-out");
    dictionary_deflate_report_csv_step.dependOn(&run_dictionary_deflate_report_csv.step);

    const run_dictionary_deflate_report_dashboard = b.addRunArtifact(dictionary_deflate_report_exe);
    run_dictionary_deflate_report_dashboard.addArgs(&.{ "--csv", "zig-out/vort-dictionary-deflate-report.csv", "--markdown", "zig-out/vort-dictionary-deflate-report.md" });
    const dictionary_deflate_report_dashboard_step = b.step("run-dictionary-deflate-report-dashboard", "Write raw/zlib preset-dictionary deflate savings dashboard to zig-out");
    dictionary_deflate_report_dashboard_step.dependOn(&run_dictionary_deflate_report_dashboard.step);

    const dictionary_corpus_report = b.addSystemCommand(&.{ "python3", "tools/dictionary_corpus_report.py" });
    dictionary_corpus_report.addArtifactArg(dictionary_report_exe);
    if (b.args) |args| dictionary_corpus_report.addArgs(args);
    const dictionary_corpus_report_step = b.step("run-dictionary-corpus-report", "Report dictionary training over bounded Silesia files");
    dictionary_corpus_report_step.dependOn(&dictionary_corpus_report.step);

    const dictionary_corpus_dashboard = b.addSystemCommand(&.{ "python3", "tools/dictionary_corpus_report.py" });
    dictionary_corpus_dashboard.addArtifactArg(dictionary_report_exe);
    dictionary_corpus_dashboard.addArgs(&.{ "--per-file", "--markdown", "zig-out/vort-dictionary-corpus-dashboard.md" });
    if (b.args) |args| dictionary_corpus_dashboard.addArgs(args);
    const dictionary_corpus_dashboard_step = b.step("run-dictionary-corpus-dashboard", "Write dictionary corpus Markdown dashboard to zig-out");
    dictionary_corpus_dashboard_step.dependOn(&dictionary_corpus_dashboard.step);

    const level_report_exe = b.addExecutable(.{
        .name = "vort-level-report",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/level_report.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_level_report = b.addRunArtifact(level_report_exe);
    if (b.args) |args| run_level_report.addArgs(args);
    const level_report_step = b.step("run-level-report", "Report compression level parser and cost-model behavior");
    level_report_step.dependOn(&run_level_report.step);

    const run_level_report_csv = b.addRunArtifact(level_report_exe);
    run_level_report_csv.addArgs(&.{ "--csv", "zig-out/vort-level-report.csv" });
    const level_report_csv_step = b.step("run-level-report-csv", "Write compression level parser and token diagnostics CSV to zig-out");
    level_report_csv_step.dependOn(&run_level_report_csv.step);

    const run_level_report_dashboard = b.addRunArtifact(level_report_exe);
    run_level_report_dashboard.addArgs(&.{ "--csv", "zig-out/vort-level-report.csv", "--markdown", "zig-out/vort-level-report.md" });
    const level_report_dashboard_step = b.step("run-level-report-dashboard", "Write compression level parser diagnostics dashboard to zig-out");
    level_report_dashboard_step.dependOn(&run_level_report_dashboard.step);

    const huffman_length_report_exe = b.addExecutable(.{
        .name = "vort-huffman-length-report",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/huffman_length_report.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_huffman_length_report = b.addRunArtifact(huffman_length_report_exe);
    if (b.args) |args| run_huffman_length_report.addArgs(args);
    const huffman_length_report_step = b.step("run-huffman-length-report", "Report length-limited Huffman costs against small optimal oracles");
    huffman_length_report_step.dependOn(&run_huffman_length_report.step);

    const run_huffman_length_report_dashboard = b.addRunArtifact(huffman_length_report_exe);
    run_huffman_length_report_dashboard.addArgs(&.{ "--csv", "zig-out/vort-huffman-length-report.csv", "--markdown", "zig-out/vort-huffman-length-report.md" });
    if (b.args) |args| run_huffman_length_report_dashboard.addArgs(args);
    const huffman_length_report_dashboard_step = b.step("run-huffman-length-report-dashboard", "Write length-limited Huffman oracle dashboard to zig-out");
    huffman_length_report_dashboard_step.dependOn(&run_huffman_length_report_dashboard.step);

    const dynamic_plan_report_exe = b.addExecutable(.{
        .name = "vort-dynamic-plan-report",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/dynamic_plan_report.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_dynamic_plan_report = b.addRunArtifact(dynamic_plan_report_exe);
    if (b.args) |args| run_dynamic_plan_report.addArgs(args);
    const dynamic_plan_report_step = b.step("run-dynamic-plan-report", "Report dynamic Huffman/LZ77 plan stats for files");
    dynamic_plan_report_step.dependOn(&run_dynamic_plan_report.step);

    const run_dynamic_plan_report_csv = b.addRunArtifact(dynamic_plan_report_exe);
    run_dynamic_plan_report_csv.addArgs(&.{ "--csv", "zig-out/vort-dynamic-plan-report.csv" });
    const dynamic_plan_report_csv_step = b.step("run-dynamic-plan-report-csv", "Write dynamic Huffman/LZ77 plan stats CSV to zig-out");
    dynamic_plan_report_csv_step.dependOn(&run_dynamic_plan_report_csv.step);

    const run_dynamic_plan_report_builtins_csv = b.addRunArtifact(dynamic_plan_report_exe);
    run_dynamic_plan_report_builtins_csv.addArgs(&.{ "--builtins", "--csv", "zig-out/vort-dynamic-plan-builtins-report.csv" });
    const dynamic_plan_report_builtins_csv_step = b.step("run-dynamic-plan-builtins-report-csv", "Write dynamic Huffman/LZ77 plan stats for built-in Rust benchmark samples to zig-out");
    dynamic_plan_report_builtins_csv_step.dependOn(&run_dynamic_plan_report_builtins_csv.step);

    const rust_deflate_benchmark_summary = b.addSystemCommand(&.{ "python3", "tools/rust_deflate_benchmark_summary.py" });
    rust_deflate_benchmark_summary.addArgs(&.{
        "--decode-csv",
        "zig-out/vort-rust-deflate-decode-bench.csv",
        "--encode-csv",
        "zig-out/vort-rust-deflate-encode-bench.csv",
        "--dynamic-plan-csv",
        "zig-out/vort-dynamic-plan-report.csv",
        "--huffman-length-csv",
        "zig-out/vort-huffman-length-report.csv",
        "--dictionary-deflate-csv",
        "zig-out/vort-dictionary-deflate-report.csv",
        "--decode-stage-csv",
        "zig-out/vort-deflate-decode-stage-report.csv",
        "--output",
        "zig-out/vort-rust-deflate-benchmark-summary.md",
    });
    rust_deflate_benchmark_summary.step.dependOn(rust_deflate_bench_csv_step);
    rust_deflate_benchmark_summary.step.dependOn(rust_deflate_encode_bench_csv_step);
    rust_deflate_benchmark_summary.step.dependOn(dynamic_plan_report_csv_step);
    rust_deflate_benchmark_summary.step.dependOn(huffman_length_report_dashboard_step);
    rust_deflate_benchmark_summary.step.dependOn(dictionary_deflate_report_csv_step);
    rust_deflate_benchmark_summary.step.dependOn(deflate_decode_stage_report_csv_step);
    const rust_deflate_benchmark_summary_step = b.step("run-rust-deflate-benchmark-summary", "Write Vort/fdeflate/miniz_oxide benchmark Markdown summary to zig-out");
    rust_deflate_benchmark_summary_step.dependOn(&rust_deflate_benchmark_summary.step);

    const rust_deflate_benchmark_summary_repeat3 = b.addSystemCommand(&.{ "python3", "tools/rust_deflate_benchmark_summary.py" });
    rust_deflate_benchmark_summary_repeat3.addArgs(&.{
        "--decode-csv",
        "zig-out/vort-rust-deflate-decode-bench-repeat3.csv",
        "--encode-csv",
        "zig-out/vort-rust-deflate-encode-bench-repeat3.csv",
        "--dynamic-plan-csv",
        "zig-out/vort-dynamic-plan-report.csv",
        "--huffman-length-csv",
        "zig-out/vort-huffman-length-report.csv",
        "--dictionary-deflate-csv",
        "zig-out/vort-dictionary-deflate-report.csv",
        "--decode-stage-csv",
        "zig-out/vort-deflate-decode-stage-report-repeat3.csv",
        "--output",
        "zig-out/vort-rust-deflate-benchmark-summary-repeat3.md",
    });
    rust_deflate_benchmark_summary_repeat3.step.dependOn(rust_deflate_bench_gate_step);
    rust_deflate_benchmark_summary_repeat3.step.dependOn(rust_deflate_encode_bench_gate_step);
    rust_deflate_benchmark_summary_repeat3.step.dependOn(dynamic_plan_report_csv_step);
    rust_deflate_benchmark_summary_repeat3.step.dependOn(huffman_length_report_dashboard_step);
    rust_deflate_benchmark_summary_repeat3.step.dependOn(dictionary_deflate_report_csv_step);
    rust_deflate_benchmark_summary_repeat3.step.dependOn(deflate_decode_stage_report_csv_repeat3_step);
    const rust_deflate_benchmark_summary_repeat3_step = b.step("run-rust-deflate-benchmark-summary-repeat3", "Write median-of-3 Vort/Rust benchmark Markdown summary to zig-out");
    rust_deflate_benchmark_summary_repeat3_step.dependOn(&rust_deflate_benchmark_summary_repeat3.step);

    const split_policy_report_exe = b.addExecutable(.{
        .name = "vort-split-policy-report",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/split_policy_report.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_split_policy_report = b.addRunArtifact(split_policy_report_exe);
    if (b.args) |args| run_split_policy_report.addArgs(args);
    const split_policy_report_step = b.step("run-split-policy-report", "Report adaptive split policy size deltas by level");
    split_policy_report_step.dependOn(&run_split_policy_report.step);

    const split_policy_corpus_report = b.addSystemCommand(&.{ "python3", "tools/split_policy_corpus_report.py" });
    split_policy_corpus_report.addArtifactArg(split_policy_report_exe);
    if (b.args) |args| split_policy_corpus_report.addArgs(args);
    const split_policy_corpus_report_step = b.step("run-split-policy-corpus-report", "Report adaptive split policy deltas across Silesia files");
    split_policy_corpus_report_step.dependOn(&split_policy_corpus_report.step);

    const native_range_report_exe = b.addExecutable(.{
        .name = "vort-native-range-report",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/native_range_report.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_native_range_report = b.addRunArtifact(native_range_report_exe);
    if (b.args) |args| run_native_range_report.addArgs(args);
    const native_range_report_step = b.step("run-native-range-report", "Report indexed range decode across native modes");
    native_range_report_step.dependOn(&run_native_range_report.step);

    const native_tier_range_bench_exe = b.addExecutable(.{
        .name = "vort-native-tier-range-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/native_tier_range_bench.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_native_tier_range_bench_csv = b.addRunArtifact(native_tier_range_bench_exe);
    run_native_tier_range_bench_csv.addArgs(&.{ "--repeat", "3", "--csv", "zig-out/vort-native-tier-range-bench.csv" });
    const native_tier_range_bench_csv_step = b.step("run-native-tier-range-bench-csv", "Write native seekability tier range benchmark CSV");
    native_tier_range_bench_csv_step.dependOn(&run_native_tier_range_bench_csv.step);

    const native_tier_range_bench_gate = b.addSystemCommand(&.{
        "python3",
        "tools/native_tier_range_bench_gate.py",
        "--csv",
        "zig-out/vort-native-tier-range-bench.csv",
        "--source",
        "built_in",
        "--summary",
        "zig-out/vort-native-tier-range-bench-gate.json",
    });
    if (optimize == .ReleaseFast) native_tier_range_bench_gate.addArg("--enforce-throughput");
    native_tier_range_bench_gate.step.dependOn(native_tier_range_bench_csv_step);
    const native_tier_range_bench_gate_step = b.step("run-native-tier-range-bench-gate", "Validate native seekability tier range benchmark CSV");
    native_tier_range_bench_gate_step.dependOn(&native_tier_range_bench_gate.step);

    const run_native_tier_range_files_bench_csv = b.addRunArtifact(native_tier_range_bench_exe);
    run_native_tier_range_files_bench_csv.addArgs(&.{
        "--repeat",
        "3",
        "--csv",
        "zig-out/vort-native-tier-range-files-bench.csv",
        "--paths",
        "README.md",
        "docs/roadmap.md",
    });
    const native_tier_range_files_bench_csv_step = b.step("run-native-tier-range-files-bench-csv", "Write native seekability tier range benchmark CSV for README/roadmap");
    native_tier_range_files_bench_csv_step.dependOn(&run_native_tier_range_files_bench_csv.step);

    const native_tier_range_files_bench_gate = b.addSystemCommand(&.{
        "python3",
        "tools/native_tier_range_bench_gate.py",
        "--csv",
        "zig-out/vort-native-tier-range-files-bench.csv",
        "--expect-fixtures",
        "README.md,roadmap.md",
        "--source",
        "project_files",
        "--summary",
        "zig-out/vort-native-tier-range-files-bench-gate.json",
    });
    if (optimize == .ReleaseFast) native_tier_range_files_bench_gate.addArg("--enforce-throughput");
    native_tier_range_files_bench_gate.step.dependOn(native_tier_range_files_bench_csv_step);
    const native_tier_range_files_bench_gate_step = b.step("run-native-tier-range-files-bench-gate", "Validate native seekability tier range benchmark CSV for README/roadmap");
    native_tier_range_files_bench_gate_step.dependOn(&native_tier_range_files_bench_gate.step);

    const native_tier_range_corpus_bench = b.addSystemCommand(&.{ "python3", "tools/native_tier_range_corpus_report.py" });
    native_tier_range_corpus_bench.addArtifactArg(native_tier_range_bench_exe);
    native_tier_range_corpus_bench.addArgs(&.{
        "--limit",
        "3",
        "--csv",
        "zig-out/vort-native-tier-range-corpus-bench.csv",
        "--summary",
        "zig-out/vort-native-tier-range-corpus-discovery.json",
    });
    if (b.args) |args| native_tier_range_corpus_bench.addArgs(args);
    const native_tier_range_corpus_bench_csv_step = b.step("run-native-tier-range-corpus-bench-csv", "Write native seekability tier range benchmark CSV for standard corpus rows");
    native_tier_range_corpus_bench_csv_step.dependOn(&native_tier_range_corpus_bench.step);

    const native_tier_range_corpus_bench_gate = b.addSystemCommand(&.{
        "python3",
        "tools/native_tier_range_bench_gate.py",
        "--csv",
        "zig-out/vort-native-tier-range-corpus-bench.csv",
        "--allow-any-fixtures",
        "--source",
        "standard_corpus",
        "--summary",
        "zig-out/vort-native-tier-range-corpus-bench-gate.json",
    });
    if (optimize == .ReleaseFast) native_tier_range_corpus_bench_gate.addArg("--enforce-throughput");
    native_tier_range_corpus_bench_gate.step.dependOn(native_tier_range_corpus_bench_csv_step);
    const native_tier_range_corpus_bench_gate_step = b.step("run-native-tier-range-corpus-bench-gate", "Validate native seekability tier range benchmark CSV for standard corpus rows");
    native_tier_range_corpus_bench_gate_step.dependOn(&native_tier_range_corpus_bench_gate.step);

    const native_tier_range_corpus_report_smoke = b.addSystemCommand(&.{ "python3", "tools/native_tier_range_corpus_report_smoke.py" });
    const native_tier_range_corpus_report_smoke_step = b.step("run-native-tier-range-corpus-report-smoke", "Validate native tier range corpus report wrapper behavior");
    native_tier_range_corpus_report_smoke_step.dependOn(&native_tier_range_corpus_report_smoke.step);

    const native_tier_range_bench_gate_negative_smoke = b.addSystemCommand(&.{ "python3", "tools/native_tier_range_bench_gate_negative_smoke.py" });
    const native_tier_range_bench_gate_negative_smoke_step = b.step("run-native-tier-range-bench-gate-negative-smoke", "Validate native tier range benchmark gate negative cases");
    native_tier_range_bench_gate_negative_smoke_step.dependOn(&native_tier_range_bench_gate_negative_smoke.step);

    const native_allocation_report_exe = b.addExecutable(.{
        .name = "vort-native-allocation-report",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/native_allocation_report.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_native_allocation_report = b.addRunArtifact(native_allocation_report_exe);
    const native_allocation_report_step = b.step("run-native-allocation-report", "Report allocation counts for native decode paths");
    native_allocation_report_step.dependOn(&run_native_allocation_report.step);

    const png_scratch_report_exe = b.addExecutable(.{
        .name = "vort-png-scratch-report",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/png_scratch_report.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_png_scratch_report = b.addRunArtifact(png_scratch_report_exe);
    const png_scratch_report_step = b.step("run-png-scratch-report", "Report PNG zlib/Adam7 caller-owned scratch footprints");
    png_scratch_report_step.dependOn(&run_png_scratch_report.step);

    const run_png_scratch_report_dashboard = b.addRunArtifact(png_scratch_report_exe);
    run_png_scratch_report_dashboard.addArgs(&.{
        "--json",
        "zig-out/vort-png-scratch-report.json",
        "--markdown",
        "zig-out/vort-png-scratch-report.md",
    });
    const png_scratch_report_dashboard_step = b.step("run-png-scratch-report-dashboard", "Write PNG scratch footprint report artifacts");
    png_scratch_report_dashboard_step.dependOn(&run_png_scratch_report_dashboard.step);

    const run_native_allocation_dashboard = b.addRunArtifact(native_allocation_report_exe);
    run_native_allocation_dashboard.addArgs(&.{
        "--json",
        "zig-out/vort-native-allocation-report.json",
        "--markdown",
        "zig-out/vort-native-allocation-report.md",
    });
    const native_allocation_dashboard_step = b.step("run-native-allocation-report-dashboard", "Write native allocation report artifacts");
    native_allocation_dashboard_step.dependOn(&run_native_allocation_dashboard.step);

    const native_allocation_smoke = b.addSystemCommand(&.{
        "python3",
        "tools/native_allocation_smoke.py",
        "--summary",
        "zig-out/vort-native-allocation-smoke.json",
    });
    native_allocation_smoke.step.dependOn(native_allocation_dashboard_step);
    const native_allocation_smoke_step = b.step("run-native-allocation-smoke", "Validate native zero-allocation decode paths");
    native_allocation_smoke_step.dependOn(&native_allocation_smoke.step);

    const native_allocation_negative_smoke = b.addSystemCommand(&.{
        "python3",
        "tools/native_allocation_negative_smoke.py",
        "--summary",
        "zig-out/vort-native-allocation-negative-smoke.json",
    });
    native_allocation_negative_smoke.step.dependOn(native_allocation_dashboard_step);
    const native_allocation_negative_smoke_step = b.step("run-native-allocation-negative-smoke", "Validate native allocation smoke rejects regressions");
    native_allocation_negative_smoke_step.dependOn(&native_allocation_negative_smoke.step);

    const sidecar_verify_report_exe = b.addExecutable(.{
        .name = "vort-sidecar-verify-report",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/sidecar_verify_report.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_sidecar_verify_report = b.addRunArtifact(sidecar_verify_report_exe);
    if (b.args) |args| run_sidecar_verify_report.addArgs(args);
    const sidecar_verify_report_step = b.step("run-sidecar-verify-report", "Verify native sidecar index files against streams");
    sidecar_verify_report_step.dependOn(&run_sidecar_verify_report.step);

    const run_sidecar_corrupt_smoke = b.addRunArtifact(sidecar_verify_report_exe);
    run_sidecar_corrupt_smoke.addArg("--self-test-corrupt");
    const sidecar_corrupt_smoke_step = b.step("run-sidecar-corrupt-smoke", "Verify sidecar metadata/full validation behavior on a corrupted payload");
    sidecar_corrupt_smoke_step.dependOn(&run_sidecar_corrupt_smoke.step);

    const run_sidecar_corrupt_dashboard = b.addRunArtifact(sidecar_verify_report_exe);
    run_sidecar_corrupt_dashboard.addArgs(&.{
        "--self-test-corrupt",
        "--markdown",
        "zig-out/vort-sidecar-corrupt-smoke.md",
        "--json",
        "zig-out/vort-sidecar-corrupt-smoke.json",
    });
    const sidecar_corrupt_dashboard_step = b.step("run-sidecar-corrupt-dashboard", "Write sidecar corrupt-payload smoke Markdown/JSON artifacts to zig-out");
    sidecar_corrupt_dashboard_step.dependOn(&run_sidecar_corrupt_dashboard.step);

    const validation_json_smoke = b.addSystemCommand(&.{ "python3", "tools/validation_json_smoke.py" });
    validation_json_smoke.addArtifactArg(cli_exe);
    validation_json_smoke.addArtifactArg(sidecar_verify_report_exe);
    validation_json_smoke.step.dependOn(deflate_wrapper_fuzz_corpus_dashboard_step);
    validation_json_smoke.step.dependOn(fuzz_corpus_coverage_smoke_step);
    validation_json_smoke.step.dependOn(deflate_decode_stage_report_dashboard_step);
    validation_json_smoke.step.dependOn(checksum_bench_gate_step);
    validation_json_smoke.step.dependOn(chunk_cursor_bench_gate_step);
    validation_json_smoke.step.dependOn(deflate_match_copy_bench_gate_step);
    validation_json_smoke.step.dependOn(deflate_huffman_build_bench_gate_step);
    validation_json_smoke.step.dependOn(deflate_huffman_lookup_bench_gate_step);
    validation_json_smoke.step.dependOn(deflate_chunked_huffman_bench_gate_step);
    validation_json_smoke.step.dependOn(deflate_extra_bits_bench_gate_step);
    validation_json_smoke.step.dependOn(dictionary_decode_bench_gate_step);
    validation_json_smoke.step.dependOn(png_scanline_bench_gate_step);
    validation_json_smoke.step.dependOn(chunked_zlib_bench_report_gate_step);
    validation_json_smoke.step.dependOn(png_streaming_zlib_bench_report_gate_step);
    validation_json_smoke.step.dependOn(deflate_dynamic_decode_profile_gate_step);
    validation_json_smoke.step.dependOn(native_library_bench_gate_step);
    validation_json_smoke.step.dependOn(python_zlib_diff_dashboard_step);
    validation_json_smoke.step.dependOn(zlib_relaxed_report_step);
    validation_json_smoke.step.dependOn(snappy_report_gate_step);
    validation_json_smoke.step.dependOn(native_allocation_dashboard_step);
    validation_json_smoke.step.dependOn(native_allocation_smoke_step);
    validation_json_smoke.step.dependOn(native_allocation_negative_smoke_step);
    validation_json_smoke.step.dependOn(native_codec_probes_dashboard_step);
    validation_json_smoke.step.dependOn(lz4_native_summary_dashboard_step);
    validation_json_smoke.step.dependOn(zstd_native_summary_dashboard_step);
    validation_json_smoke.step.dependOn(zstd_compare_gate_step);
    validation_json_smoke.step.dependOn(zstd_compare_standard_gate_step);
    validation_json_smoke.step.dependOn(zstd_compare_block_sweep_gate_step);
    validation_json_smoke.step.dependOn(native_summary_error_dashboard_step);
    validation_json_smoke.step.dependOn(native_summary_error_negative_smoke_step);
    validation_json_smoke.step.dependOn(native_tier_range_bench_gate_step);
    validation_json_smoke.step.dependOn(native_tier_range_files_bench_gate_step);
    validation_json_smoke.step.dependOn(native_tier_range_corpus_bench_gate_step);
    validation_json_smoke.step.dependOn(png_scratch_report_dashboard_step);
    validation_json_smoke.step.dependOn(br_static_dictionary_source_audit_step);
    validation_json_smoke.step.dependOn(br_static_dictionary_source_audit_negative_smoke_step);
    validation_json_smoke.step.dependOn(br_static_dictionary_candidate_report_smoke_step);
    validation_json_smoke.step.dependOn(br_static_dictionary_candidate_upstream_smoke_step);
    validation_json_smoke.step.dependOn(br_static_dictionary_node_probe_step);
    validation_json_smoke.step.dependOn(br_static_dictionary_report_smoke_step);
    validation_json_smoke.step.dependOn(br_static_dictionary_report_negative_smoke_step);
    validation_json_smoke.step.dependOn(level_report_dashboard_step);
    validation_json_smoke.step.dependOn(dynamic_plan_report_csv_step);
    validation_json_smoke.step.dependOn(dynamic_plan_report_builtins_csv_step);
    const validation_json_smoke_step = b.step("run-validation-json-smoke", "Validate CLI and report JSON schema outputs");
    validation_json_smoke_step.dependOn(&validation_json_smoke.step);

    const validation_json_dashboard = b.addSystemCommand(&.{ "python3", "tools/validation_json_smoke.py" });
    validation_json_dashboard.addArtifactArg(cli_exe);
    validation_json_dashboard.addArtifactArg(sidecar_verify_report_exe);
    validation_json_dashboard.addArgs(&.{ "--summary", "zig-out/vort-validation-json-smoke.json" });
    validation_json_dashboard.step.dependOn(deflate_wrapper_fuzz_corpus_dashboard_step);
    validation_json_dashboard.step.dependOn(fuzz_corpus_coverage_smoke_step);
    validation_json_dashboard.step.dependOn(deflate_decode_stage_report_dashboard_step);
    validation_json_dashboard.step.dependOn(checksum_bench_gate_step);
    validation_json_dashboard.step.dependOn(chunk_cursor_bench_gate_step);
    validation_json_dashboard.step.dependOn(deflate_match_copy_bench_gate_step);
    validation_json_dashboard.step.dependOn(deflate_huffman_build_bench_gate_step);
    validation_json_dashboard.step.dependOn(deflate_huffman_lookup_bench_gate_step);
    validation_json_dashboard.step.dependOn(deflate_chunked_huffman_bench_gate_step);
    validation_json_dashboard.step.dependOn(deflate_extra_bits_bench_gate_step);
    validation_json_dashboard.step.dependOn(dictionary_decode_bench_gate_step);
    validation_json_dashboard.step.dependOn(png_scanline_bench_gate_step);
    validation_json_dashboard.step.dependOn(chunked_zlib_bench_report_gate_step);
    validation_json_dashboard.step.dependOn(png_streaming_zlib_bench_report_gate_step);
    validation_json_dashboard.step.dependOn(deflate_dynamic_decode_profile_gate_step);
    validation_json_dashboard.step.dependOn(native_library_bench_gate_step);
    validation_json_dashboard.step.dependOn(python_zlib_diff_dashboard_step);
    validation_json_dashboard.step.dependOn(zlib_relaxed_report_step);
    validation_json_dashboard.step.dependOn(snappy_report_gate_step);
    validation_json_dashboard.step.dependOn(native_allocation_dashboard_step);
    validation_json_dashboard.step.dependOn(native_allocation_smoke_step);
    validation_json_dashboard.step.dependOn(native_allocation_negative_smoke_step);
    validation_json_dashboard.step.dependOn(native_codec_probes_dashboard_step);
    validation_json_dashboard.step.dependOn(lz4_native_summary_dashboard_step);
    validation_json_dashboard.step.dependOn(zstd_native_summary_dashboard_step);
    validation_json_dashboard.step.dependOn(zstd_compare_gate_step);
    validation_json_dashboard.step.dependOn(zstd_compare_standard_gate_step);
    validation_json_dashboard.step.dependOn(zstd_compare_block_sweep_gate_step);
    validation_json_dashboard.step.dependOn(native_tier_range_bench_gate_step);
    validation_json_dashboard.step.dependOn(native_tier_range_files_bench_gate_step);
    validation_json_dashboard.step.dependOn(native_tier_range_corpus_bench_gate_step);
    validation_json_dashboard.step.dependOn(png_scratch_report_dashboard_step);
    validation_json_dashboard.step.dependOn(br_static_dictionary_source_audit_step);
    validation_json_dashboard.step.dependOn(br_static_dictionary_source_audit_negative_smoke_step);
    validation_json_dashboard.step.dependOn(br_static_dictionary_candidate_report_smoke_step);
    validation_json_dashboard.step.dependOn(br_static_dictionary_candidate_upstream_smoke_step);
    validation_json_dashboard.step.dependOn(br_static_dictionary_node_probe_step);
    validation_json_dashboard.step.dependOn(br_static_dictionary_report_smoke_step);
    validation_json_dashboard.step.dependOn(br_static_dictionary_report_negative_smoke_step);
    validation_json_dashboard.step.dependOn(level_report_dashboard_step);
    validation_json_dashboard.step.dependOn(dynamic_plan_report_csv_step);
    validation_json_dashboard.step.dependOn(dynamic_plan_report_builtins_csv_step);
    const validation_json_dashboard_step = b.step("run-validation-json-dashboard", "Write validation JSON schema smoke summary to zig-out");
    validation_json_dashboard_step.dependOn(&validation_json_dashboard.step);

    const validation_json_docs_check = b.addSystemCommand(&.{ "python3", "tools/validation_json_docs_check.py" });
    const validation_json_docs_check_step = b.step("run-validation-json-docs-check", "Validate JSON examples in docs/validation-json.md");
    validation_json_docs_check_step.dependOn(&validation_json_docs_check.step);

    const validation_json_docs_negative_smoke = b.addSystemCommand(&.{ "python3", "tools/validation_json_docs_negative_smoke.py", "--summary", "zig-out/vort-validation-json-docs-negative-smoke.json" });
    const validation_json_docs_negative_smoke_step = b.step("run-validation-json-docs-negative-smoke", "Validate validation JSON docs checker negative drift cases");
    validation_json_docs_negative_smoke_step.dependOn(&validation_json_docs_negative_smoke.step);

    const dashboard_config_index_smoke = b.addSystemCommand(&.{ "python3", "tools/dashboard_config_index_smoke.py", "--summary", "zig-out/vort-dashboard-config-index-smoke.json" });
    const dashboard_config_index_smoke_step = b.step("run-dashboard-config-index-smoke", "Validate dashboard external configuration index");
    dashboard_config_index_smoke_step.dependOn(&dashboard_config_index_smoke.step);

    const dashboard_config_index_negative_smoke = b.addSystemCommand(&.{ "python3", "tools/dashboard_config_index_negative_smoke.py", "--summary", "zig-out/vort-dashboard-config-index-negative-smoke.json" });
    const dashboard_config_index_negative_smoke_step = b.step("run-dashboard-config-index-negative-smoke", "Validate dashboard config-index negative drift cases");
    dashboard_config_index_negative_smoke_step.dependOn(&dashboard_config_index_negative_smoke.step);

    const dashboard_producers_negative_smoke = b.addSystemCommand(&.{ "python3", "tools/dashboard_producers_negative_smoke.py", "--summary", "zig-out/vort-dashboard-producers-negative-smoke.json" });
    const dashboard_producers_negative_smoke_step = b.step("run-dashboard-producers-negative-smoke", "Validate dashboard producer-map negative drift cases");
    dashboard_producers_negative_smoke_step.dependOn(&dashboard_producers_negative_smoke.step);

    const dashboard_producers_required_smoke = b.addSystemCommand(&.{ "python3", "tools/dashboard_producers_required_smoke.py", "--summary", "zig-out/vort-dashboard-producers-required-smoke.json" });
    const dashboard_producers_required_smoke_step = b.step("run-dashboard-producers-required-smoke", "Validate dashboard producer-map required artifact coverage");
    dashboard_producers_required_smoke_step.dependOn(&dashboard_producers_required_smoke.step);

    const dashboard_category_negative_smoke = b.addSystemCommand(&.{ "python3", "tools/dashboard_category_negative_smoke.py", "--summary", "zig-out/vort-dashboard-category-negative-smoke.json" });
    const dashboard_category_negative_smoke_step = b.step("run-dashboard-category-negative-smoke", "Validate dashboard category negative drift cases");
    dashboard_category_negative_smoke_step.dependOn(&dashboard_category_negative_smoke.step);

    const dashboard_strict_smoke = b.addSystemCommand(&.{ "python3", "tools/dashboard_strict_smoke.py" });
    const dashboard_strict_smoke_step = b.step("run-dashboard-strict-smoke", "Validate dashboard strict-mode positive and negative paths");
    dashboard_strict_smoke_step.dependOn(&dashboard_strict_smoke.step);

    const dashboard_strict_dashboard = b.addSystemCommand(&.{ "python3", "tools/dashboard_strict_smoke.py", "--summary", "zig-out/vort-dashboard-strict-smoke.json", "--markdown", "zig-out/vort-dashboard-strict-smoke.md" });
    const dashboard_strict_dashboard_step = b.step("run-dashboard-strict-dashboard", "Write dashboard strict-mode smoke summary to zig-out");
    dashboard_strict_dashboard_step.dependOn(&dashboard_strict_dashboard.step);

    const dashboard_index = b.addSystemCommand(&.{ "python3", "tools/dashboard_index.py", "--strict-producers", "--strict-smoke-gates", "--strict-header-inspect", "--strict-validation-health" });
    dashboard_index.step.dependOn(checksum_bench_gate_step);
    dashboard_index.step.dependOn(sidecar_corrupt_dashboard_step);
    dashboard_index.step.dependOn(python_zlib_diff_dashboard_step);
    dashboard_index.step.dependOn(zlib_relaxed_report_gate_step);
    dashboard_index.step.dependOn(snappy_report_gate_step);
    dashboard_index.step.dependOn(validation_json_dashboard_step);
    dashboard_index.step.dependOn(validation_json_docs_negative_smoke_step);
    dashboard_index.step.dependOn(dashboard_config_index_smoke_step);
    dashboard_index.step.dependOn(dashboard_config_index_negative_smoke_step);
    dashboard_index.step.dependOn(dashboard_producers_negative_smoke_step);
    dashboard_index.step.dependOn(dashboard_producers_required_smoke_step);
    dashboard_index.step.dependOn(dashboard_category_negative_smoke_step);
    dashboard_index.step.dependOn(lz4_native_summary_dashboard_step);
    dashboard_index.step.dependOn(zstd_native_summary_dashboard_step);
    dashboard_index.step.dependOn(header_inspect_dashboard_step);
    dashboard_index.step.dependOn(dashboard_strict_dashboard_step);
    dashboard_index.step.dependOn(br_static_dictionary_report_dashboard_step);
    dashboard_index.step.dependOn(br_static_dictionary_report_negative_smoke_step);
    dashboard_index.step.dependOn(br_static_dictionary_source_audit_step);
    dashboard_index.step.dependOn(br_static_dictionary_source_audit_negative_smoke_step);
    dashboard_index.step.dependOn(br_static_dictionary_candidate_report_smoke_step);
    dashboard_index.step.dependOn(br_static_dictionary_candidate_upstream_smoke_step);
    dashboard_index.step.dependOn(br_static_dictionary_node_probe_step);
    dashboard_index.step.dependOn(deflate_decode_stage_report_dashboard_step);
    dashboard_index.step.dependOn(deflate_extra_bits_bench_gate_step);
    dashboard_index.step.dependOn(deflate_huffman_build_bench_gate_step);
    dashboard_index.step.dependOn(deflate_huffman_lookup_bench_gate_step);
    dashboard_index.step.dependOn(deflate_chunked_huffman_bench_gate_step);
    dashboard_index.step.dependOn(deflate_match_copy_bench_gate_step);
    dashboard_index.step.dependOn(dictionary_decode_bench_gate_step);
    dashboard_index.step.dependOn(chunk_cursor_bench_gate_step);
    dashboard_index.step.dependOn(chunked_zlib_bench_report_gate_step);
    dashboard_index.step.dependOn(png_streaming_zlib_bench_report_gate_step);
    dashboard_index.step.dependOn(deflate_dynamic_decode_profile_gate_step);
    dashboard_index.step.dependOn(native_library_bench_gate_step);
    dashboard_index.step.dependOn(png_scanline_bench_gate_step);
    dashboard_index.step.dependOn(level_report_dashboard_step);
    dashboard_index.step.dependOn(dynamic_plan_report_csv_step);
    dashboard_index.step.dependOn(dynamic_plan_report_builtins_csv_step);
    dashboard_index.step.dependOn(huffman_length_report_dashboard_step);
    dashboard_index.step.dependOn(native_tier_range_bench_gate_step);
    dashboard_index.step.dependOn(native_tier_range_files_bench_gate_step);
    dashboard_index.step.dependOn(native_tier_range_corpus_bench_gate_step);
    dashboard_index.step.dependOn(deflate_wrapper_fuzz_corpus_dashboard_step);
    dashboard_index.step.dependOn(fuzz_corpus_coverage_smoke_step);
    dashboard_index.step.dependOn(native_fuzz_corpus_coverage_smoke_step);
    dashboard_index.step.dependOn(native_codec_probes_dashboard_step);
    dashboard_index.step.dependOn(zstd_compare_gate_step);
    dashboard_index.step.dependOn(zstd_compare_block_sweep_gate_step);
    dashboard_index.step.dependOn(zstd_compare_standard_gate_step);
    const dashboard_index_step = b.step("run-dashboard-index", "Write a Markdown index for zig-out dashboard artifacts");
    dashboard_index_step.dependOn(&dashboard_index.step);

    const dashboard_category_smoke = b.addSystemCommand(&.{ "python3", "tools/dashboard_category_smoke.py", "zig-out/vort-dashboard-index.json" });
    dashboard_category_smoke.step.dependOn(dashboard_index_step);
    const dashboard_category_smoke_step = b.step("run-dashboard-category-smoke", "Validate dashboard artifact category assignments");
    dashboard_category_smoke_step.dependOn(&dashboard_category_smoke.step);

    const file_corpus_report_exe = b.addExecutable(.{
        .name = "vort-file-corpus-report",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/file_corpus_report.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
            },
        }),
    });
    const run_file_corpus_report = b.addRunArtifact(file_corpus_report_exe);
    if (b.args) |args| run_file_corpus_report.addArgs(args);
    const file_corpus_report_step = b.step("run-file-corpus-report", "Report fixed-encoder compression sizes for provided file paths");
    file_corpus_report_step.dependOn(&run_file_corpus_report.step);

    const run_file_corpus_dashboard = b.addRunArtifact(file_corpus_report_exe);
    run_file_corpus_dashboard.addArgs(&.{ "--markdown", "zig-out/vort-file-corpus-dashboard.md" });
    if (b.args) |args| run_file_corpus_dashboard.addArgs(args);
    const file_corpus_dashboard_step = b.step("run-file-corpus-dashboard", "Write file corpus compression dashboard to zig-out");
    file_corpus_dashboard_step.dependOn(&run_file_corpus_dashboard.step);

    const run_file_corpus_standard_dashboard = b.addRunArtifact(file_corpus_report_exe);
    run_file_corpus_standard_dashboard.addArgs(&.{ "--markdown", "zig-out/vort-file-corpus-standard-dashboard.md", "--standard-suite" });
    if (b.args) |args| run_file_corpus_standard_dashboard.addArgs(args);
    const file_corpus_standard_dashboard_step = b.step("run-file-corpus-standard-dashboard", "Discover standard corpora and write file corpus dashboard to zig-out");
    file_corpus_standard_dashboard_step.dependOn(&run_file_corpus_standard_dashboard.step);

    const run_file_corpus_standard_full_dashboard = b.addRunArtifact(file_corpus_report_exe);
    run_file_corpus_standard_full_dashboard.addArgs(&.{ "--full", "--markdown", "zig-out/vort-file-corpus-standard-full-dashboard.md", "--standard-suite" });
    if (b.args) |args| run_file_corpus_standard_full_dashboard.addArgs(args);
    const file_corpus_standard_full_dashboard_step = b.step("run-file-corpus-standard-full-dashboard", "Discover standard corpora and write full file corpus dashboard to zig-out");
    file_corpus_standard_full_dashboard_step.dependOn(&run_file_corpus_standard_full_dashboard.step);

    const compat_benchmark = b.addSystemCommand(&.{ "python3", "tools/compat_benchmark.py" });
    compat_benchmark.addArtifactArg(cli_exe);
    const compat_benchmark_step = b.step("run-compat-benchmark", "Run smoke benchmark comparing Vort, gzip, and zstd on sample files");
    compat_benchmark_step.dependOn(&compat_benchmark.step);

    const standard_corpus_report = b.addSystemCommand(&.{ "python3", "tools/standard_corpus_report.py" });
    standard_corpus_report.addArtifactArg(cli_exe);
    if (b.args) |args| standard_corpus_report.addArgs(args);
    const standard_corpus_report_step = b.step("run-standard-corpus-report", "Run Silesia-sample Vort/gzip/zstd benchmark smoke");
    standard_corpus_report_step.dependOn(&standard_corpus_report.step);

    const standard_corpus_suite = b.addSystemCommand(&.{ "python3", "tools/standard_corpus_report.py" });
    standard_corpus_suite.addArtifactArg(cli_exe);
    standard_corpus_suite.addArg("--suite");
    const standard_corpus_suite_step = b.step("run-standard-corpus-suite", "Run per-file Silesia Vort/gzip/zlib-ng/zlib-rs/zstd benchmark suite");
    standard_corpus_suite_step.dependOn(&standard_corpus_suite.step);

    const standard_corpus_dashboard = b.addSystemCommand(&.{ "python3", "tools/standard_corpus_report.py" });
    standard_corpus_dashboard.addArtifactArg(cli_exe);
    standard_corpus_dashboard.addArgs(&.{ "--suite", "--markdown", "zig-out/vort-standard-corpus-dashboard.md" });
    if (b.args) |args| standard_corpus_dashboard.addArgs(args);
    const standard_corpus_dashboard_step = b.step("run-standard-corpus-dashboard", "Write a Markdown Silesia benchmark dashboard to zig-out");
    standard_corpus_dashboard_step.dependOn(&standard_corpus_dashboard.step);

    const standard_corpus_full_dashboard = b.addSystemCommand(&.{ "python3", "tools/standard_corpus_report.py" });
    standard_corpus_full_dashboard.addArtifactArg(cli_exe);
    standard_corpus_full_dashboard.addArgs(&.{ "--suite", "--full", "--markdown", "zig-out/vort-standard-corpus-full-dashboard.md" });
    if (b.args) |args| standard_corpus_full_dashboard.addArgs(args);
    const standard_corpus_full_dashboard_step = b.step("run-standard-corpus-full-dashboard", "Write a full-size Markdown Silesia benchmark dashboard to zig-out");
    standard_corpus_full_dashboard_step.dependOn(&standard_corpus_full_dashboard.step);

    const standard_multi_corpus_suite = b.addSystemCommand(&.{ "python3", "tools/standard_corpus_report.py" });
    standard_multi_corpus_suite.addArtifactArg(cli_exe);
    standard_multi_corpus_suite.addArg("--standard-suite");
    if (b.args) |args| standard_multi_corpus_suite.addArgs(args);
    const standard_multi_corpus_suite_step = b.step("run-standard-multi-corpus-suite", "Discover standard corpora and run Vort/gzip/zlib-ng/zlib-rs/zstd benchmark suite");
    standard_multi_corpus_suite_step.dependOn(&standard_multi_corpus_suite.step);

    const standard_multi_corpus_dashboard = b.addSystemCommand(&.{ "python3", "tools/standard_corpus_report.py" });
    standard_multi_corpus_dashboard.addArtifactArg(cli_exe);
    standard_multi_corpus_dashboard.addArgs(&.{ "--standard-suite", "--markdown", "zig-out/vort-standard-multi-corpus-dashboard.md" });
    if (b.args) |args| standard_multi_corpus_dashboard.addArgs(args);
    const standard_multi_corpus_dashboard_step = b.step("run-standard-multi-corpus-dashboard", "Discover standard corpora and write a Markdown benchmark dashboard to zig-out");
    standard_multi_corpus_dashboard_step.dependOn(&standard_multi_corpus_dashboard.step);

    const standard_multi_corpus_full_suite = b.addSystemCommand(&.{ "python3", "tools/standard_corpus_report.py" });
    standard_multi_corpus_full_suite.addArtifactArg(cli_exe);
    standard_multi_corpus_full_suite.addArgs(&.{ "--standard-suite", "--full" });
    if (b.args) |args| standard_multi_corpus_full_suite.addArgs(args);
    const standard_multi_corpus_full_suite_step = b.step("run-standard-multi-corpus-full-suite", "Discover standard corpora and run a full-mode Vort/gzip/zlib-ng/zlib-rs/zstd benchmark suite");
    standard_multi_corpus_full_suite_step.dependOn(&standard_multi_corpus_full_suite.step);

    const standard_multi_corpus_full_dashboard = b.addSystemCommand(&.{ "python3", "tools/standard_corpus_report.py" });
    standard_multi_corpus_full_dashboard.addArtifactArg(cli_exe);
    standard_multi_corpus_full_dashboard.addArgs(&.{ "--standard-suite", "--full", "--markdown", "zig-out/vort-standard-multi-corpus-full-dashboard.md" });
    if (b.args) |args| standard_multi_corpus_full_dashboard.addArgs(args);
    const standard_multi_corpus_full_dashboard_step = b.step("run-standard-multi-corpus-full-dashboard", "Discover standard corpora and write a full-mode Markdown benchmark dashboard to zig-out");
    standard_multi_corpus_full_dashboard_step.dependOn(&standard_multi_corpus_full_dashboard.step);

    const full_compat_benchmark_suite_step = b.step("run-full-compat-benchmark-suite", "Run full compatibility benchmark suite across multiple standard corpora");
    full_compat_benchmark_suite_step.dependOn(standard_multi_corpus_dashboard_step);
    full_compat_benchmark_suite_step.dependOn(standard_multi_corpus_full_dashboard_step);

    const competitor_gap_report = b.addSystemCommand(&.{ "python3", "tools/competitor_gap_report.py", "--strict", "--require-provenance" });
    competitor_gap_report.step.dependOn(rust_deflate_encode_bench_gate_step);
    competitor_gap_report.step.dependOn(rust_deflate_bench_gate_step);
    competitor_gap_report.step.dependOn(zstd_encode_bench_gate_step);
    competitor_gap_report.step.dependOn(zstd_reference_bench_gate_step);
    competitor_gap_report.step.dependOn(lz4_reference_bench_gate_step);
    competitor_gap_report.step.dependOn(snappy_reference_bench_gate_step);
    competitor_gap_report.step.dependOn(br_planned_encode_bench_gate_step);
    competitor_gap_report.step.dependOn(br_reference_bench_gate_step);
    if (b.args) |args| competitor_gap_report.addArgs(args);
    const competitor_gap_report_step = b.step("run-competitor-gap-report", "Aggregate available competitor benchmark CSVs into Markdown and JSON gap reports");
    competitor_gap_report_step.dependOn(&competitor_gap_report.step);

    const competitor_gap_report_smoke = b.addSystemCommand(&.{ "python3", "tools/competitor_gap_report_smoke.py" });
    const competitor_gap_report_smoke_step = b.step("run-competitor-gap-report-smoke", "Validate competitor gap report positive and negative paths");
    competitor_gap_report_smoke_step.dependOn(&competitor_gap_report_smoke.step);

    const check_step = b.step("check", "Compile library tests, CLI, benchmark, fuzz-smoke, and differential entrypoints");
    check_step.dependOn(&tests.step);
    check_step.dependOn(&br_record_classifier_tests.step);
    check_step.dependOn(&br_record_optimal_object_tests.step);
    check_step.dependOn(&cli_exe.step);
    check_step.dependOn(&bench_exe.step);
    check_step.dependOn(&deflate_bench_exe.step);
    check_step.dependOn(&corpus_decode_bench_exe.step);
    check_step.dependOn(&zlib_decode_bench_exe.step);
    check_step.dependOn(&zlib_relaxed_report_exe.step);
    check_step.dependOn(&deflate_decode_stage_report_exe.step);
    check_step.dependOn(&deflate_dynamic_decode_profile_exe.step);
    check_step.dependOn(&deflate_huffman_build_bench_exe.step);
    check_step.dependOn(&huffman_length_bench_exe.step);
    check_step.dependOn(&deflate_code_length_rle_bench_exe.step);
    check_step.dependOn(&deflate_huffman_lookup_bench_exe.step);
    check_step.dependOn(&deflate_chunked_huffman_bench_exe.step);
    check_step.dependOn(&deflate_match_copy_bench_exe.step);
    check_step.dependOn(&deflate_extra_bits_bench_exe.step);
    check_step.dependOn(&chunk_cursor_bench_exe.step);
    check_step.dependOn(&png_streaming_zlib_bench_report_exe.step);
    check_step.dependOn(&png_scanline_bench_exe.step);
    check_step.dependOn(&zlib_encode_bench_exe.step);
    check_step.dependOn(&deflate_encode_bench_exe.step);
    check_step.dependOn(&deflate_incremental_encode_bench_exe.step);
    check_step.dependOn(&deflate_incremental_decode_bench_exe.step);
    check_step.dependOn(&native_parallel_bench_exe.step);
    check_step.dependOn(&fuzz_smoke_exe.step);
    check_step.dependOn(&fuzz_corpus_exe.step);
    check_step.dependOn(&fuzz_target_exe.step);
    check_step.dependOn(wasm_check_step);
    check_step.dependOn(&libfuzzer_smoke_exe.step);
    check_step.dependOn(&afl_smoke_exe.step);
    check_step.dependOn(&checksum_diff_exe.step);
    check_step.dependOn(&zlib_diff_exe.step);
    check_step.dependOn(&gzip_diff_exe.step);
    check_step.dependOn(&br_rle_probe_exe.step);
    check_step.dependOn(&br_planned_corpus_exe.step);
    check_step.dependOn(&br_planned_probe_exe.step);
    check_step.dependOn(&br_planned_encode_bench_exe.step);
    check_step.dependOn(&br_planned_chunks_bench_exe.step);
    check_step.dependOn(&br_planned_stage_profile_exe.step);
    check_step.dependOn(&br_ratio_stage_profile_exe.step);
    check_step.dependOn(&br_record_optimal_audit_exe.step);
    check_step.dependOn(&br_record_optimal_shape_exe.step);
    check_step.dependOn(&br_planned_stage_bench_exe.step);
    check_step.dependOn(&br_lazy_sweep_exe.step);
    check_step.dependOn(&br_command_lut_bench_exe.step);
    check_step.dependOn(&compression_report_exe.step);
    check_step.dependOn(&dictionary_report_exe.step);
    check_step.dependOn(&native_dictionary_report_exe.step);
    check_step.dependOn(&native_library_bench_exe.step);
    check_step.dependOn(&snappy_report_exe.step);
    check_step.dependOn(&snappy_reference_bench_exe.step);
    check_step.dependOn(&snappy_interop_probe_exe.step);
    check_step.dependOn(&lz4_reference_bench_exe.step);
    check_step.dependOn(&lz4_decode_profile_exe.step);
    check_step.dependOn(&br_compressed_header_profile_exe.step);
    check_step.dependOn(&zstd_reference_bench_exe.step);
    check_step.dependOn(&benchmark_provenance_tests.step);
    check_step.dependOn(&zstd_decode_profile_exe.step);
    check_step.dependOn(&zstd_encode_bench_exe.step);
    check_step.dependOn(&zstd_seekable_parallel_bench_exe.step);
    check_step.dependOn(&zstd_level_schedule_bench_exe.step);
    check_step.dependOn(&zstd_native_encode_stage_bench_exe.step);
    check_step.dependOn(&zstd_large_sequence_probe_exe.step);
    check_step.dependOn(&zstd_dictionary_probe_exe.step);
    check_step.dependOn(&zstd_full_dictionary_diff_exe.step);
    check_step.dependOn(&zstd_dictionary_trainer_compare_exe.step);
    check_step.dependOn(&dictionary_train_bench_exe.step);
    check_step.dependOn(&dictionary_deflate_report_exe.step);
    check_step.dependOn(&dictionary_decode_bench_exe.step);
    check_step.dependOn(&level_report_exe.step);
    check_step.dependOn(&huffman_length_report_exe.step);
    check_step.dependOn(&dynamic_plan_report_exe.step);
    check_step.dependOn(&split_policy_report_exe.step);
    check_step.dependOn(&native_range_report_exe.step);
    check_step.dependOn(&native_tier_range_bench_exe.step);
    check_step.dependOn(&native_allocation_report_exe.step);
    check_step.dependOn(&sidecar_verify_report_exe.step);
    check_step.dependOn(&file_corpus_report_exe.step);
    check_step.dependOn(&cpu_features_exe.step);
    check_step.dependOn(&br_stored_corpus_exe.step);
    check_step.dependOn(&br_static_dictionary_report_exe.step);
    check_step.dependOn(&br_upstream_multiblock_diff_exe.step);
    check_step.dependOn(&br_progressive_copy_bench_exe.step);
    check_step.dependOn(&br_progressive_huffman_bench_exe.step);
    check_step.dependOn(&br_incremental_planned_bench_exe.step);
    check_step.dependOn(&zstd_native_frame_probe_exe.step);
    check_step.dependOn(&zstd_native_dictionary_probe_exe.step);
    check_step.dependOn(&lz4_native_dictionary_probe_exe.step);

    const ci_smoke_step = b.step("ci-smoke", "Run local CI smoke validation across tests, fuzz, differential, and benchmark reports");
    ci_smoke_step.dependOn(test_step);
    ci_smoke_step.dependOn(check_step);
    ci_smoke_step.dependOn(fuzz_smoke_step);
    ci_smoke_step.dependOn(fuzz_corpus_step);
    ci_smoke_step.dependOn(deflate_wrapper_fuzz_corpus_step);
    ci_smoke_step.dependOn(native_fuzz_corpus_step);
    ci_smoke_step.dependOn(native_fuzz_corpus_dashboard_step);
    ci_smoke_step.dependOn(native_fuzz_corpus_coverage_smoke_step);
    ci_smoke_step.dependOn(deflate_wrapper_fuzz_corpus_dashboard_step);
    ci_smoke_step.dependOn(fuzz_corpus_coverage_smoke_step);
    ci_smoke_step.dependOn(fuzz_target_step);
    ci_smoke_step.dependOn(libfuzzer_smoke_step);
    ci_smoke_step.dependOn(afl_smoke_step);
    ci_smoke_step.dependOn(checksum_bench_gate_step);
    ci_smoke_step.dependOn(checksum_diff_step);
    ci_smoke_step.dependOn(checksum_zlib_diff_step);
    ci_smoke_step.dependOn(zlib_diff_step);
    ci_smoke_step.dependOn(gzip_diff_step);
    ci_smoke_step.dependOn(python_zlib_diff_step);
    ci_smoke_step.dependOn(zlib_relaxed_report_gate_step);
    ci_smoke_step.dependOn(gzip_cli_diff_step);
    ci_smoke_step.dependOn(bgzf_diff_step);
    ci_smoke_step.dependOn(snappy_framing_diff_step);
    ci_smoke_step.dependOn(hadoop_lz4_diff_step);
    ci_smoke_step.dependOn(lz4_legacy_diff_step);
    ci_smoke_step.dependOn(lznt1_diff_step);
    ci_smoke_step.dependOn(xpress_diff_step);
    ci_smoke_step.dependOn(lzfse_diff_step);
    ci_smoke_step.dependOn(zchunk_diff_step);
    ci_smoke_step.dependOn(squashfs_diff_step);
    ci_smoke_step.dependOn(erofs_diff_step);
    ci_smoke_step.dependOn(hadoop_lzo_index_diff_step);
    ci_smoke_step.dependOn(zip_diff_step);
    ci_smoke_step.dependOn(bzip2_diff_step);
    ci_smoke_step.dependOn(xz_diff_step);
    ci_smoke_step.dependOn(lzma_diff_step);
    ci_smoke_step.dependOn(compress_z_diff_step);
    ci_smoke_step.dependOn(lzip_diff_step);
    ci_smoke_step.dependOn(lzf_diff_step);
    ci_smoke_step.dependOn(lha_diff_step);
    ci_smoke_step.dependOn(ar_diff_step);
    ci_smoke_step.dependOn(deb_diff_step);
    ci_smoke_step.dependOn(rpm_diff_step);
    ci_smoke_step.dependOn(arj_diff_step);
    ci_smoke_step.dependOn(arc_diff_step);
    ci_smoke_step.dependOn(cpio_diff_step);
    ci_smoke_step.dependOn(rar_diff_step);
    ci_smoke_step.dependOn(lzop_diff_step);
    ci_smoke_step.dependOn(seven_zip_diff_step);
    ci_smoke_step.dependOn(tar_diff_step);
    ci_smoke_step.dependOn(cab_diff_step);
    ci_smoke_step.dependOn(br_stored_cli_diff_step);
    ci_smoke_step.dependOn(br_literal_cli_diff_step);
    ci_smoke_step.dependOn(br_stored_corpus_step);
    ci_smoke_step.dependOn(br_planned_corpus_step);
    ci_smoke_step.dependOn(br_planned_node_diff_step);
    ci_smoke_step.dependOn(br_ratio_stage_profile_gate_step);
    ci_smoke_step.dependOn(br_record_optimal_audit_step);
    ci_smoke_step.dependOn(br_record_optimal_shape_gate_step);
    ci_smoke_step.dependOn(br_planned_chunks_bench_gate_step);
    ci_smoke_step.dependOn(br_upstream_multiblock_diff_step);
    ci_smoke_step.dependOn(br_real_corpus_diff_step);
    ci_smoke_step.dependOn(br_progressive_copy_bench_gate_step);
    ci_smoke_step.dependOn(br_progressive_huffman_bench_gate_step);
    ci_smoke_step.dependOn(br_static_dictionary_report_step);
    ci_smoke_step.dependOn(br_static_dictionary_report_dashboard_step);
    ci_smoke_step.dependOn(br_static_dictionary_report_smoke_step);
    ci_smoke_step.dependOn(br_static_dictionary_report_negative_smoke_step);
    ci_smoke_step.dependOn(br_static_dictionary_source_audit_step);
    ci_smoke_step.dependOn(br_static_dictionary_source_audit_negative_smoke_step);
    ci_smoke_step.dependOn(br_static_dictionary_candidate_report_step);
    ci_smoke_step.dependOn(br_static_dictionary_candidate_report_smoke_step);
    ci_smoke_step.dependOn(br_static_dictionary_candidate_upstream_smoke_step);
    ci_smoke_step.dependOn(br_static_dictionary_node_probe_step);
    ci_smoke_step.dependOn(snappy_block_cli_probe_step);
    ci_smoke_step.dependOn(snappy_interop_probe_step);
    ci_smoke_step.dependOn(zstd_native_cli_diff_step);
    ci_smoke_step.dependOn(lz4_native_summary_cli_probe_step);
    ci_smoke_step.dependOn(lz4_native_summary_dashboard_step);
    ci_smoke_step.dependOn(zstd_native_summary_cli_probe_step);
    ci_smoke_step.dependOn(native_summary_error_dashboard_step);
    ci_smoke_step.dependOn(native_summary_error_negative_smoke_step);
    ci_smoke_step.dependOn(zstd_native_summary_dashboard_step);
    ci_smoke_step.dependOn(zstd_native_probe_step);
    ci_smoke_step.dependOn(zstd_seekable_parallel_bench_gate_step);
    ci_smoke_step.dependOn(zstd_encode_bench_path_smoke_step);
    ci_smoke_step.dependOn(zstd_reference_bench_path_smoke_step);
    ci_smoke_step.dependOn(zstd_decode_profile_path_smoke_step);
    ci_smoke_step.dependOn(zstd_native_encode_stage_bench_path_smoke_step);
    ci_smoke_step.dependOn(benchmark_provenance_test_step);
    ci_smoke_step.dependOn(benchmark_provenance_gate_smoke_step);
    ci_smoke_step.dependOn(rust_deflate_bench_gate_smoke_step);
    ci_smoke_step.dependOn(zstd_decodecorpus_gate_smoke_step);
    ci_smoke_step.dependOn(native_codec_probes_dashboard_step);
    ci_smoke_step.dependOn(native_codec_probes_dashboard_timeout_smoke_step);
    ci_smoke_step.dependOn(snappy_report_gate_step);
    ci_smoke_step.dependOn(header_inspect_smoke_step);
    ci_smoke_step.dependOn(header_inspect_dashboard_step);
    ci_smoke_step.dependOn(zlib_family_diff_step);
    ci_smoke_step.dependOn(rust_deflate_diff_step);
    ci_smoke_step.dependOn(external_probe_step);
    ci_smoke_step.dependOn(cpu_features_step);
    ci_smoke_step.dependOn(zstd_compare_gate_step);
    ci_smoke_step.dependOn(zstd_compare_block_sweep_gate_step);
    ci_smoke_step.dependOn(zstd_compare_standard_gate_step);
    ci_smoke_step.dependOn(compression_report_step);
    ci_smoke_step.dependOn(deflate_decode_stage_report_step);
    ci_smoke_step.dependOn(deflate_decode_stage_report_dashboard_step);
    ci_smoke_step.dependOn(deflate_dynamic_decode_profile_gate_step);
    ci_smoke_step.dependOn(deflate_huffman_build_bench_gate_step);
    ci_smoke_step.dependOn(huffman_length_bench_gate_step);
    ci_smoke_step.dependOn(deflate_code_length_rle_bench_gate_step);
    ci_smoke_step.dependOn(deflate_huffman_lookup_bench_gate_step);
    ci_smoke_step.dependOn(deflate_chunked_huffman_bench_gate_step);
    ci_smoke_step.dependOn(deflate_match_copy_bench_gate_step);
    ci_smoke_step.dependOn(deflate_extra_bits_bench_gate_step);
    ci_smoke_step.dependOn(deflate_incremental_decode_gate_step);
    ci_smoke_step.dependOn(chunk_cursor_bench_gate_step);
    ci_smoke_step.dependOn(chunked_zlib_bench_report_gate_step);
    ci_smoke_step.dependOn(png_streaming_zlib_bench_report_gate_step);
    ci_smoke_step.dependOn(png_scanline_bench_gate_step);
    ci_smoke_step.dependOn(dictionary_report_step);
    ci_smoke_step.dependOn(dictionary_decode_bench_gate_step);
    ci_smoke_step.dependOn(dictionary_deflate_report_step);
    ci_smoke_step.dependOn(dictionary_deflate_report_dashboard_step);
    ci_smoke_step.dependOn(level_report_step);
    ci_smoke_step.dependOn(level_report_csv_step);
    ci_smoke_step.dependOn(level_report_dashboard_step);
    ci_smoke_step.dependOn(huffman_length_report_step);
    ci_smoke_step.dependOn(huffman_length_report_dashboard_step);
    ci_smoke_step.dependOn(dynamic_plan_report_step);
    ci_smoke_step.dependOn(split_policy_report_step);
    ci_smoke_step.dependOn(native_range_report_step);
    ci_smoke_step.dependOn(native_library_bench_gate_step);
    ci_smoke_step.dependOn(native_tier_range_bench_gate_step);
    ci_smoke_step.dependOn(native_tier_range_files_bench_gate_step);
    ci_smoke_step.dependOn(native_tier_range_corpus_bench_gate_step);
    ci_smoke_step.dependOn(native_tier_range_corpus_report_smoke_step);
    ci_smoke_step.dependOn(native_tier_range_bench_gate_negative_smoke_step);
    ci_smoke_step.dependOn(native_allocation_report_step);
    ci_smoke_step.dependOn(native_allocation_dashboard_step);
    ci_smoke_step.dependOn(native_allocation_smoke_step);
    ci_smoke_step.dependOn(native_allocation_negative_smoke_step);
    ci_smoke_step.dependOn(sidecar_corrupt_smoke_step);
    ci_smoke_step.dependOn(sidecar_corrupt_dashboard_step);
    ci_smoke_step.dependOn(validation_json_smoke_step);
    ci_smoke_step.dependOn(validation_json_dashboard_step);
    ci_smoke_step.dependOn(validation_json_docs_check_step);
    ci_smoke_step.dependOn(validation_json_docs_negative_smoke_step);
    ci_smoke_step.dependOn(dashboard_config_index_smoke_step);
    ci_smoke_step.dependOn(dashboard_config_index_negative_smoke_step);
    ci_smoke_step.dependOn(dashboard_producers_negative_smoke_step);
    ci_smoke_step.dependOn(dashboard_producers_required_smoke_step);
    ci_smoke_step.dependOn(dashboard_category_negative_smoke_step);
    ci_smoke_step.dependOn(dashboard_index_step);
    ci_smoke_step.dependOn(dashboard_category_smoke_step);
    ci_smoke_step.dependOn(dashboard_strict_smoke_step);
    ci_smoke_step.dependOn(dashboard_strict_dashboard_step);
    ci_smoke_step.dependOn(compat_benchmark_step);
    ci_smoke_step.dependOn(competitor_gap_report_smoke_step);
    ci_smoke_step.dependOn(standard_corpus_report_step);
    ci_smoke_step.dependOn(standard_multi_corpus_dashboard_step);
    ci_smoke_step.dependOn(standard_multi_corpus_full_dashboard_step);
}
