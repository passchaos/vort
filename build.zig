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

    const gzip_cli_diff = b.addSystemCommand(&.{ "python3", "tools/gzip_cli_diff.py" });
    gzip_cli_diff.addArtifactArg(cli_exe);
    const gzip_cli_diff_step = b.step("run-gzip-cli-diff", "Run black-box differential smoke against system gzip CLI");
    gzip_cli_diff_step.dependOn(&gzip_cli_diff.step);

    const zlib_family_diff = b.addSystemCommand(&.{ "python3", "tools/zlib_family_diff.py" });
    zlib_family_diff.addArtifactArg(cli_exe);
    const zlib_family_diff_step = b.step("run-zlib-family-diff", "Run optional zlib-ng/zlib-rs differential harness when binaries are available");
    zlib_family_diff_step.dependOn(&zlib_family_diff.step);

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
    const dictionary_report_step = b.step("run-dictionary-report", "Report deterministic dictionary training metadata");
    dictionary_report_step.dependOn(&run_dictionary_report.step);

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
    const level_report_step = b.step("run-level-report", "Report compression level parser and cost-model behavior");
    level_report_step.dependOn(&run_level_report.step);

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

    const check_step = b.step("check", "Compile library tests, CLI, benchmark, fuzz-smoke, and differential entrypoints");
    check_step.dependOn(&tests.step);
    check_step.dependOn(&cli_exe.step);
    check_step.dependOn(&bench_exe.step);
    check_step.dependOn(&deflate_bench_exe.step);
    check_step.dependOn(&corpus_decode_bench_exe.step);
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
    check_step.dependOn(&level_report_exe.step);
    check_step.dependOn(&file_corpus_report_exe.step);
    check_step.dependOn(&cpu_features_exe.step);

    const ci_smoke_step = b.step("ci-smoke", "Run local CI smoke validation across tests, fuzz, differential, and benchmark reports");
    ci_smoke_step.dependOn(test_step);
    ci_smoke_step.dependOn(check_step);
    ci_smoke_step.dependOn(fuzz_smoke_step);
    ci_smoke_step.dependOn(fuzz_corpus_step);
    ci_smoke_step.dependOn(fuzz_target_step);
    ci_smoke_step.dependOn(libfuzzer_smoke_step);
    ci_smoke_step.dependOn(afl_smoke_step);
    ci_smoke_step.dependOn(checksum_diff_step);
    ci_smoke_step.dependOn(checksum_zlib_diff_step);
    ci_smoke_step.dependOn(zlib_diff_step);
    ci_smoke_step.dependOn(gzip_diff_step);
    ci_smoke_step.dependOn(python_zlib_diff_step);
    ci_smoke_step.dependOn(gzip_cli_diff_step);
    ci_smoke_step.dependOn(zlib_family_diff_step);
    ci_smoke_step.dependOn(external_probe_step);
    ci_smoke_step.dependOn(cpu_features_step);
    ci_smoke_step.dependOn(zstd_compare_step);
    ci_smoke_step.dependOn(compression_report_step);
    ci_smoke_step.dependOn(dictionary_report_step);
    ci_smoke_step.dependOn(level_report_step);
    ci_smoke_step.dependOn(compat_benchmark_step);
    ci_smoke_step.dependOn(standard_corpus_report_step);
}
