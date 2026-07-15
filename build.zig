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

    const run_deflate_decode_stage_report_dashboard = b.addRunArtifact(deflate_decode_stage_report_exe);
    run_deflate_decode_stage_report_dashboard.addArgs(&.{ "--csv", "zig-out/vort-deflate-decode-stage-report.csv", "--markdown", "zig-out/vort-deflate-decode-stage-report.md" });
    const deflate_decode_stage_report_dashboard_step = b.step("run-deflate-decode-stage-report-dashboard", "Write raw inflate vs zlib wrapper/checksum stage dashboard to zig-out");
    deflate_decode_stage_report_dashboard_step.dependOn(&run_deflate_decode_stage_report_dashboard.step);

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

    const rust_deflate_encode_bench = b.addSystemCommand(&.{ "python3", "tools/rust_deflate_encode_bench.py" });
    rust_deflate_encode_bench.addArtifactArg(zlib_encode_bench_exe);
    const rust_deflate_encode_bench_step = b.step("run-rust-deflate-encode-bench", "Run Vort/fdeflate/miniz_oxide encode throughput and size smoke benchmark");
    rust_deflate_encode_bench_step.dependOn(&rust_deflate_encode_bench.step);

    const rust_deflate_encode_bench_csv = b.addSystemCommand(&.{ "python3", "tools/rust_deflate_encode_bench.py" });
    rust_deflate_encode_bench_csv.addArtifactArg(zlib_encode_bench_exe);
    rust_deflate_encode_bench_csv.addArgs(&.{ "--csv", "zig-out/vort-rust-deflate-encode-bench.csv" });
    const rust_deflate_encode_bench_csv_step = b.step("run-rust-deflate-encode-bench-csv", "Write Vort/fdeflate/miniz_oxide encode benchmark CSV to zig-out");
    rust_deflate_encode_bench_csv_step.dependOn(&rust_deflate_encode_bench_csv.step);

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

    const rust_deflate_benchmark_summary = b.addSystemCommand(&.{ "python3", "tools/rust_deflate_benchmark_summary.py" });
    rust_deflate_benchmark_summary.addArgs(&.{
        "--decode-csv",
        "zig-out/vort-rust-deflate-decode-bench.csv",
        "--encode-csv",
        "zig-out/vort-rust-deflate-encode-bench.csv",
        "--dynamic-plan-csv",
        "zig-out/vort-dynamic-plan-report.csv",
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
    rust_deflate_benchmark_summary.step.dependOn(dictionary_deflate_report_csv_step);
    rust_deflate_benchmark_summary.step.dependOn(deflate_decode_stage_report_csv_step);
    const rust_deflate_benchmark_summary_step = b.step("run-rust-deflate-benchmark-summary", "Write Vort/fdeflate/miniz_oxide benchmark Markdown summary to zig-out");
    rust_deflate_benchmark_summary_step.dependOn(&rust_deflate_benchmark_summary.step);

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
    const validation_json_smoke_step = b.step("run-validation-json-smoke", "Validate CLI and report JSON schema outputs");
    validation_json_smoke_step.dependOn(&validation_json_smoke.step);

    const validation_json_dashboard = b.addSystemCommand(&.{ "python3", "tools/validation_json_smoke.py" });
    validation_json_dashboard.addArtifactArg(cli_exe);
    validation_json_dashboard.addArtifactArg(sidecar_verify_report_exe);
    validation_json_dashboard.addArgs(&.{ "--summary", "zig-out/vort-validation-json-smoke.json" });
    const validation_json_dashboard_step = b.step("run-validation-json-dashboard", "Write validation JSON schema smoke summary to zig-out");
    validation_json_dashboard_step.dependOn(&validation_json_dashboard.step);

    const validation_json_docs_check = b.addSystemCommand(&.{ "python3", "tools/validation_json_docs_check.py" });
    const validation_json_docs_check_step = b.step("run-validation-json-docs-check", "Validate JSON examples in docs/validation-json.md");
    validation_json_docs_check_step.dependOn(&validation_json_docs_check.step);

    const dashboard_index = b.addSystemCommand(&.{ "python3", "tools/dashboard_index.py", "--strict-producers", "--strict-smoke-gates", "--strict-header-inspect" });
    const dashboard_index_step = b.step("run-dashboard-index", "Write a Markdown index for zig-out dashboard artifacts");
    dashboard_index_step.dependOn(&dashboard_index.step);
    dashboard_index_step.dependOn(sidecar_corrupt_dashboard_step);
    dashboard_index_step.dependOn(validation_json_dashboard_step);
    dashboard_index_step.dependOn(header_inspect_dashboard_step);

    const dashboard_category_smoke = b.addSystemCommand(&.{ "python3", "tools/dashboard_category_smoke.py", "zig-out/vort-dashboard-index.json" });
    const dashboard_category_smoke_step = b.step("run-dashboard-category-smoke", "Validate dashboard artifact category assignments");
    dashboard_category_smoke_step.dependOn(&dashboard_category_smoke.step);
    dashboard_category_smoke_step.dependOn(dashboard_index_step);

    const dashboard_strict_smoke = b.addSystemCommand(&.{ "python3", "tools/dashboard_strict_smoke.py" });
    const dashboard_strict_smoke_step = b.step("run-dashboard-strict-smoke", "Validate dashboard strict-mode positive and negative paths");
    dashboard_strict_smoke_step.dependOn(&dashboard_strict_smoke.step);

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
    check_step.dependOn(&deflate_decode_stage_report_exe.step);
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
    check_step.dependOn(&level_report_exe.step);
    check_step.dependOn(&dynamic_plan_report_exe.step);
    check_step.dependOn(&split_policy_report_exe.step);
    check_step.dependOn(&native_range_report_exe.step);
    check_step.dependOn(&sidecar_verify_report_exe.step);
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
    ci_smoke_step.dependOn(dictionary_report_step);
    ci_smoke_step.dependOn(dictionary_deflate_report_step);
    ci_smoke_step.dependOn(dictionary_deflate_report_dashboard_step);
    ci_smoke_step.dependOn(level_report_step);
    ci_smoke_step.dependOn(dynamic_plan_report_step);
    ci_smoke_step.dependOn(split_policy_report_step);
    ci_smoke_step.dependOn(native_range_report_step);
    ci_smoke_step.dependOn(sidecar_corrupt_smoke_step);
    ci_smoke_step.dependOn(sidecar_corrupt_dashboard_step);
    ci_smoke_step.dependOn(validation_json_smoke_step);
    ci_smoke_step.dependOn(validation_json_dashboard_step);
    ci_smoke_step.dependOn(validation_json_docs_check_step);
    ci_smoke_step.dependOn(dashboard_index_step);
    ci_smoke_step.dependOn(dashboard_category_smoke_step);
    ci_smoke_step.dependOn(dashboard_strict_smoke_step);
    ci_smoke_step.dependOn(compat_benchmark_step);
    ci_smoke_step.dependOn(standard_corpus_report_step);
    ci_smoke_step.dependOn(standard_multi_corpus_dashboard_step);
    ci_smoke_step.dependOn(standard_multi_corpus_full_dashboard_step);
}
