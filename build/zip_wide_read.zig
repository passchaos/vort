const std = @import("std");
const zip_build = @import("zip_wide_input.zig");
const size_build = @import("wide_sizes.zig");

pub fn register(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, public_native: *std.Build.Module) void {
    const x86 = b.resolveTargetQuery(.{ .cpu_arch = .x86, .os_tag = .linux });
    const wasi = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .wasi });
    for ([_]std.Build.ResolvedTarget{ target, x86, wasi }, 0..) |variant, index| {
        const suffix = ([_][]const u8{ "", "-x86", "-wasm" })[index];
        const gate = b.step(b.fmt("test-zip-wide-read-counts{s}", .{suffix}), "Verify logical ZIP64 metadata, reader counts and Deflate64 encoder boundaries");
        const tests = b.addTest(.{
            .name = b.fmt("vort-zip-wide-read{s}-tests", .{suffix}),
            .root_module = zip_build.module(b, variant, optimize),
            .filters = &.{
                "ZIP64 logical metadata queries",
                "ZIP wide incremental reader and entry decoder counts",
                "ZIP incremental reader test suite",
                "ZIP incremental entry decoder test suite",
                "ZIP split",
            },
        });
        const deflate64_tests = b.addTest(.{
            .name = b.fmt("vort-deflate64-wide-encode{s}-tests", .{suffix}),
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/deflate64.zig"),
                .target = variant,
                .optimize = optimize,
                .single_threaded = index == 2,
            }),
            .filters = &.{"Deflate64 incremental wide encoder"},
        });
        if (index == 2) {
            tests.stack_size = 8 * 1024 * 1024;
            deflate64_tests.stack_size = 8 * 1024 * 1024;
            const run = b.addSystemCommand(&.{ "node", "tools/zip/wide_read/wasm_gate.js" });
            run.addArtifactArg(tests);
            run.addArtifactArg(deflate64_tests);
            gate.dependOn(&run.step);
        } else {
            gate.dependOn(&b.addRunArtifact(tests).step);
            gate.dependOn(&b.addRunArtifact(deflate64_tests).step);
        }
    }
    const public_x86 = size_build.publicModule(b, x86);
    var probes: [2]*std.Build.Step.Compile = undefined;
    for ([_]*std.Build.Module{ public_native, public_x86 }, [_]std.Build.ResolvedTarget{ target, x86 }, 0..) |module, variant, index| {
        probes[index] = b.addExecutable(.{
            .name = if (index == 0) "vort-zip-wide-read-probe" else "vort-zip-wide-read-probe-x86",
            .root_module = b.createModule(.{
                .root_source_file = b.path("tools/zip/wide_read/probe.zig"),
                .target = variant,
                .optimize = .ReleaseFast,
                .imports = &.{.{ .name = "codec", .module = module }},
            }),
        });
    }
    for ([_]bool{ false, true }) |long| {
        const run = b.addSystemCommand(&.{ "python3", "tools/zip/wide_read/driver.py", "--probe-native" });
        run.addArtifactArg(probes[0]);
        run.addArg("--probe-x86");
        run.addArtifactArg(probes[1]);
        run.addArgs(&.{ "--output-dir", if (long) "zig-out/zip-wide-read-long" else "zig-out/zip-wide-read-smoke" });
        if (long) run.addArg("--long");
        if (b.args) |args| run.addArgs(args);
        b.step(if (long) "run-zip-wide-read-long-diff" else "run-zip-wide-read-diff", "Decode actual native/x86 large ZIP64 payloads and compare all bytes with reference tools")
            .dependOn(&run.step);
    }
}
