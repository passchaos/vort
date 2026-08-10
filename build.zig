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

    const tests = b.addTest(.{
        .name = "vort-tests",
        .root_module = tests_mod,
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

    const br_stored_cli_diff = b.addSystemCommand(&.{ "python3", "tools/br_stored_cli_diff.py" });
    br_stored_cli_diff.addArtifactArg(cli_exe);
    const br_stored_cli_diff_step = b.step("run-br-stored-cli-diff", "Run black-box smoke for dependency-free Brotli stored streams against Node Brotli");
    br_stored_cli_diff_step.dependOn(&br_stored_cli_diff.step);

    const br_literal_cli_diff = b.addSystemCommand(&.{ "python3", "tools/br_literal_cli_diff.py" });
    br_literal_cli_diff.addArtifactArg(cli_exe);
    const br_literal_cli_diff_step = b.step("run-br-literal-cli-diff", "Run black-box smoke for minimal dependency-free Brotli literal blocks against Node Brotli");
    br_literal_cli_diff_step.dependOn(&br_literal_cli_diff.step);

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
    snappy_report_gate.step.dependOn(snappy_report_csv_step);
    const snappy_report_gate_step = b.step("run-snappy-report-gate", "Validate dependency-free Snappy raw/framed report CSV");
    snappy_report_gate_step.dependOn(&snappy_report_gate.step);

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
    validation_json_smoke.step.dependOn(native_summary_error_dashboard_step);
    validation_json_smoke.step.dependOn(native_summary_error_negative_smoke_step);
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
    check_step.dependOn(&native_dictionary_report_exe.step);
    check_step.dependOn(&native_library_bench_exe.step);
    check_step.dependOn(&snappy_report_exe.step);
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
    ci_smoke_step.dependOn(br_stored_cli_diff_step);
    ci_smoke_step.dependOn(br_literal_cli_diff_step);
    ci_smoke_step.dependOn(br_stored_corpus_step);
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
    ci_smoke_step.dependOn(zstd_native_cli_diff_step);
    ci_smoke_step.dependOn(lz4_native_summary_cli_probe_step);
    ci_smoke_step.dependOn(lz4_native_summary_dashboard_step);
    ci_smoke_step.dependOn(zstd_native_summary_cli_probe_step);
    ci_smoke_step.dependOn(native_summary_error_dashboard_step);
    ci_smoke_step.dependOn(native_summary_error_negative_smoke_step);
    ci_smoke_step.dependOn(zstd_native_summary_dashboard_step);
    ci_smoke_step.dependOn(zstd_native_probe_step);
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
    ci_smoke_step.dependOn(standard_corpus_report_step);
    ci_smoke_step.dependOn(standard_multi_corpus_dashboard_step);
    ci_smoke_step.dependOn(standard_multi_corpus_full_dashboard_step);
}
