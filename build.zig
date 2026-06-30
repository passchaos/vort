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

    const check_step = b.step("check", "Compile library tests, CLI, benchmark, fuzz-smoke, and differential entrypoints");
    check_step.dependOn(&tests.step);
    check_step.dependOn(&cli_exe.step);
    check_step.dependOn(&bench_exe.step);
    check_step.dependOn(&deflate_bench_exe.step);
    check_step.dependOn(&deflate_encode_bench_exe.step);
    check_step.dependOn(&fuzz_smoke_exe.step);
    check_step.dependOn(&fuzz_corpus_exe.step);
    check_step.dependOn(&checksum_diff_exe.step);
    check_step.dependOn(&zlib_diff_exe.step);
    check_step.dependOn(&gzip_diff_exe.step);
    check_step.dependOn(&compression_report_exe.step);
}
