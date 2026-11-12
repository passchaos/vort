const std = @import("std");

pub fn register(b: *std.Build, target: std.Build.ResolvedTarget, vort: *std.Build.Module, provenance: *std.Build.Module) *std.Build.Step {
    const zstd_runtime = b.createModule(.{ .root_source_file = b.path("tools/zstd/libzstd_runtime.zig"), .target = target, .optimize = .ReleaseFast });
    const brotli_runtime = b.createModule(.{ .root_source_file = b.path("tools/br/libbrotli_runtime.zig"), .target = target, .optimize = .ReleaseFast });
    const probe = b.addExecutable(.{
        .name = "vort-decode-compare",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/decode/compare.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vort", .module = vort },
                .{ .name = "benchmark_provenance", .module = provenance },
                .{ .name = "libzstd_runtime", .module = zstd_runtime },
                .{ .name = "libbrotli_runtime", .module = brotli_runtime },
            },
        }),
    });
    const install = b.addInstallArtifact(probe, .{});
    b.step("build-decode-compare", "Build frozen-fixture raw paired decoder comparison probe").dependOn(&install.step);
    const run = b.addRunArtifact(probe);
    if (b.args) |args| run.addArgs(args);
    b.step("run-decode-compare", "Compare caller-buffer decoding with explicit reference lifecycles").dependOn(&run.step);
    const tests = b.addTest(.{
        .name = "vort-decode-sampling-tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/decode/sampling_tests.zig"),
            .target = target,
            .optimize = .ReleaseSafe,
        }),
    });
    b.step("test-decode-sampling", "Test balanced paired sampling and retained warmups").dependOn(&b.addRunArtifact(tests).step);
    const perf_tests = b.addTest(.{
        .name = "vort-decode-perf-group-tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/decode/perf_group_tests.zig"),
            .target = target,
            .optimize = .ReleaseSafe,
        }),
    });
    b.step("test-decode-perf-group", "Test raw PMU group reads without requiring hardware counters").dependOn(&b.addRunArtifact(perf_tests).step);
    const evidence_tests = b.addSystemCommand(&.{ "python3", "tools/decode/evidence_test.py" });
    b.step("test-decode-evidence", "Validate raw decoder matrix evidence and statistical accounting").dependOn(&evidence_tests.step);
    return &probe.step;
}
