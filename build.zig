const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const vort_mod = b.addModule("vort", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .name = "vort",
        .root_module = vort_mod,
    });
    b.installArtifact(lib);

    const tests = b.addTest(.{
        .name = "vort-tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run vort unit tests");
    test_step.dependOn(&run_tests.step);

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
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
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

    const chunked_zlib_bench_report_gate = b.addSystemCommand(&.{
        "python3",
        "tools/chunked_zlib_bench_gate.py",
        "--csv",
        "zig-out/vort-chunked-zlib-bench-report-repeat3.csv",
    });
    chunked_zlib_bench_report_gate.step.dependOn(chunked_zlib_bench_report_csv_repeat3_step);
    const chunked_zlib_bench_report_gate_step = b.step("run-chunked-zlib-bench-report-gate", "Validate repeat3 contiguous vs chunked zlib decode throughput CSV");
    chunked_zlib_bench_report_gate_step.dependOn(&chunked_zlib_bench_report_gate.step);

    const run_chunked_zlib_bench_report_dashboard = b.addRunArtifact(chunked_zlib_bench_report_exe);
    run_chunked_zlib_bench_report_dashboard.addArgs(&.{ "--csv", "zig-out/vort-chunked-zlib-bench-report.csv", "--markdown", "zig-out/vort-chunked-zlib-bench-report.md" });
    const chunked_zlib_bench_report_dashboard_step = b.step("run-chunked-zlib-bench-report-dashboard", "Write contiguous vs chunked zlib decode throughput dashboard artifacts");
    chunked_zlib_bench_report_dashboard_step.dependOn(&run_chunked_zlib_bench_report_dashboard.step);

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
    const png_scanline_bench_csv_step = b.step("run-png-scanline-bench-csv", "Write focused PNG scanline reconstruction benchmark CSV");
    png_scanline_bench_csv_step.dependOn(&run_png_scanline_bench_csv.step);

    const png_scanline_bench_gate = b.addSystemCommand(&.{
        "python3",
        "tools/png_scanline_bench_gate.py",
        "--csv",
        "zig-out/vort-png-scanline-bench.csv",
    });
    if (optimize == .ReleaseFast) png_scanline_bench_gate.addArg("--enforce-throughput");
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
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vort", .module = vort_mod },
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
    const zstd_compare_step = b.step("run-zstd-compare", "Report zstd CLI and Vort fixed compressed sizes for sample files");
    zstd_compare_step.dependOn(&zstd_compare.step);

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
    rust_deflate_benchmark_summary_repeat3.step.dependOn(rust_deflate_bench_csv_repeat3_step);
    rust_deflate_benchmark_summary_repeat3.step.dependOn(rust_deflate_encode_bench_csv_repeat3_step);
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
    validation_json_smoke.step.dependOn(python_zlib_diff_dashboard_step);
    validation_json_smoke.step.dependOn(zlib_relaxed_report_step);
    validation_json_smoke.step.dependOn(native_allocation_dashboard_step);
    validation_json_smoke.step.dependOn(native_allocation_smoke_step);
    validation_json_smoke.step.dependOn(native_allocation_negative_smoke_step);
    validation_json_smoke.step.dependOn(png_scratch_report_dashboard_step);
    const validation_json_smoke_step = b.step("run-validation-json-smoke", "Validate CLI and report JSON schema outputs");
    validation_json_smoke_step.dependOn(&validation_json_smoke.step);

    const validation_json_dashboard = b.addSystemCommand(&.{ "python3", "tools/validation_json_smoke.py" });
    validation_json_dashboard.addArtifactArg(cli_exe);
    validation_json_dashboard.addArtifactArg(sidecar_verify_report_exe);
    validation_json_dashboard.addArgs(&.{ "--summary", "zig-out/vort-validation-json-smoke.json" });
    validation_json_dashboard.step.dependOn(deflate_wrapper_fuzz_corpus_dashboard_step);
    validation_json_dashboard.step.dependOn(fuzz_corpus_coverage_smoke_step);
    validation_json_dashboard.step.dependOn(deflate_decode_stage_report_dashboard_step);
    validation_json_dashboard.step.dependOn(python_zlib_diff_dashboard_step);
    validation_json_dashboard.step.dependOn(zlib_relaxed_report_step);
    validation_json_dashboard.step.dependOn(native_allocation_dashboard_step);
    validation_json_dashboard.step.dependOn(native_allocation_smoke_step);
    validation_json_dashboard.step.dependOn(native_allocation_negative_smoke_step);
    validation_json_dashboard.step.dependOn(png_scratch_report_dashboard_step);
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
    dashboard_index.step.dependOn(validation_json_dashboard_step);
    dashboard_index.step.dependOn(validation_json_docs_negative_smoke_step);
    dashboard_index.step.dependOn(dashboard_config_index_smoke_step);
    dashboard_index.step.dependOn(dashboard_config_index_negative_smoke_step);
    dashboard_index.step.dependOn(dashboard_producers_negative_smoke_step);
    dashboard_index.step.dependOn(dashboard_producers_required_smoke_step);
    dashboard_index.step.dependOn(dashboard_category_negative_smoke_step);
    dashboard_index.step.dependOn(header_inspect_dashboard_step);
    dashboard_index.step.dependOn(dashboard_strict_dashboard_step);
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
    dashboard_index.step.dependOn(png_scanline_bench_gate_step);
    dashboard_index.step.dependOn(level_report_dashboard_step);
    dashboard_index.step.dependOn(huffman_length_report_dashboard_step);
    dashboard_index.step.dependOn(deflate_wrapper_fuzz_corpus_dashboard_step);
    dashboard_index.step.dependOn(fuzz_corpus_coverage_smoke_step);
    dashboard_index.step.dependOn(native_fuzz_corpus_coverage_smoke_step);
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

    const check_step = b.step("check", "Compile library tests, CLI, benchmark, fuzz-smoke, and differential entrypoints");
    check_step.dependOn(&tests.step);
    check_step.dependOn(&cli_exe.step);
    check_step.dependOn(&bench_exe.step);
    check_step.dependOn(&deflate_bench_exe.step);
    check_step.dependOn(&corpus_decode_bench_exe.step);
    check_step.dependOn(&zlib_decode_bench_exe.step);
    check_step.dependOn(&zlib_relaxed_report_exe.step);
    check_step.dependOn(&deflate_decode_stage_report_exe.step);
    check_step.dependOn(&deflate_dynamic_decode_profile_exe.step);
    check_step.dependOn(&deflate_huffman_build_bench_exe.step);
    check_step.dependOn(&deflate_huffman_lookup_bench_exe.step);
    check_step.dependOn(&deflate_chunked_huffman_bench_exe.step);
    check_step.dependOn(&deflate_match_copy_bench_exe.step);
    check_step.dependOn(&deflate_extra_bits_bench_exe.step);
    check_step.dependOn(&chunk_cursor_bench_exe.step);
    check_step.dependOn(&png_streaming_zlib_bench_report_exe.step);
    check_step.dependOn(&png_scanline_bench_exe.step);
    check_step.dependOn(&zlib_encode_bench_exe.step);
    check_step.dependOn(&deflate_encode_bench_exe.step);
    check_step.dependOn(&native_parallel_bench_exe.step);
    check_step.dependOn(&fuzz_smoke_exe.step);
    check_step.dependOn(&fuzz_corpus_exe.step);
    check_step.dependOn(&fuzz_target_exe.step);
    check_step.dependOn(&libfuzzer_smoke_exe.step);
    check_step.dependOn(&afl_smoke_exe.step);
    check_step.dependOn(&checksum_diff_exe.step);
    check_step.dependOn(&zlib_diff_exe.step);
    check_step.dependOn(&gzip_diff_exe.step);
    check_step.dependOn(&compression_report_exe.step);
    check_step.dependOn(&dictionary_report_exe.step);
    check_step.dependOn(&dictionary_deflate_report_exe.step);
    check_step.dependOn(&dictionary_decode_bench_exe.step);
    check_step.dependOn(&level_report_exe.step);
    check_step.dependOn(&huffman_length_report_exe.step);
    check_step.dependOn(&dynamic_plan_report_exe.step);
    check_step.dependOn(&split_policy_report_exe.step);
    check_step.dependOn(&native_range_report_exe.step);
    check_step.dependOn(&native_allocation_report_exe.step);
    check_step.dependOn(&sidecar_verify_report_exe.step);
    check_step.dependOn(&file_corpus_report_exe.step);
    check_step.dependOn(&cpu_features_exe.step);

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
    ci_smoke_step.dependOn(header_inspect_smoke_step);
    ci_smoke_step.dependOn(header_inspect_dashboard_step);
    ci_smoke_step.dependOn(zlib_family_diff_step);
    ci_smoke_step.dependOn(rust_deflate_diff_step);
    ci_smoke_step.dependOn(external_probe_step);
    ci_smoke_step.dependOn(cpu_features_step);
    ci_smoke_step.dependOn(zstd_compare_step);
    ci_smoke_step.dependOn(compression_report_step);
    ci_smoke_step.dependOn(deflate_decode_stage_report_step);
    ci_smoke_step.dependOn(deflate_decode_stage_report_dashboard_step);
    ci_smoke_step.dependOn(deflate_dynamic_decode_profile_gate_step);
    ci_smoke_step.dependOn(deflate_huffman_build_bench_gate_step);
    ci_smoke_step.dependOn(deflate_huffman_lookup_bench_gate_step);
    ci_smoke_step.dependOn(deflate_chunked_huffman_bench_gate_step);
    ci_smoke_step.dependOn(deflate_match_copy_bench_gate_step);
    ci_smoke_step.dependOn(deflate_extra_bits_bench_gate_step);
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
    ci_smoke_step.dependOn(standard_corpus_report_step);
    ci_smoke_step.dependOn(standard_multi_corpus_dashboard_step);
    ci_smoke_step.dependOn(standard_multi_corpus_full_dashboard_step);
}
