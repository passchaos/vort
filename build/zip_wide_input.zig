const std = @import("std");

fn module(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const dependency = b.dependency("vail_archive_crypto", .{ .target = target, .optimize = optimize });
    const codec = b.createModule(.{
        .root_source_file = b.path("src/zip.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "vail_archive_crypto", .module = dependency.module("vail_archive_crypto") }},
    });
    const object = b.addObject(.{
        .name = b.fmt("vort-zip-wide-input-zstd-object-{s}", .{@tagName(target.result.cpu.arch)}),
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/zstd_huffman_x2_object.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    codec.addObject(object);
    return codec;
}

pub fn register(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const x86 = b.resolveTargetQuery(.{ .cpu_arch = .x86, .os_tag = .linux });
    var probes: [2]*std.Build.Step.Compile = undefined;
    for ([_]std.Build.ResolvedTarget{ target, x86 }, 0..) |variant, index| {
        const tests = b.addTest(.{
            .name = if (index == 0) "vort-zip-wide-input-tests" else "vort-zip-wide-input-x86-tests",
            .root_module = module(b, variant, optimize),
            .filters = &.{"ZIP incremental writer wide input"},
        });
        b.step(if (index == 0) "test-zip-wide-codec-input" else "test-zip-wide-codec-input-x86", "Validate wide codec pledges, caps and ZIP64 entry metadata")
            .dependOn(&b.addRunArtifact(tests).step);
        probes[index] = b.addExecutable(.{
            .name = if (index == 0) "vort-zip-wide-input-probe" else "vort-zip-wide-input-probe-x86",
            .root_module = b.createModule(.{
                .root_source_file = b.path("tools/zip/wide_input/probe.zig"),
                .target = variant,
                .optimize = .ReleaseFast,
                .imports = &.{.{ .name = "codec", .module = module(b, variant, .ReleaseFast) }},
            }),
        });
    }
    for ([_]bool{ false, true }) |long| {
        const run = b.addSystemCommand(&.{ "python3", "tools/zip/wide_input/driver.py", "--probe-native" });
        run.addArtifactArg(probes[0]);
        run.addArg("--probe-x86");
        run.addArtifactArg(probes[1]);
        run.addArgs(&.{ "--output-dir", if (long) "zig-out/zip-wide-input-long" else "zig-out/zip-wide-input-smoke" });
        if (long) run.addArg("--long");
        if (b.args) |args| run.addArgs(args);
        b.step(if (long) "run-zip-wide-codec-input-long-diff" else "run-zip-wide-codec-input-diff", "Write native/x86 ZIP streams and verify metadata and every decoded byte with reference libraries")
            .dependOn(&run.step);
    }
}
