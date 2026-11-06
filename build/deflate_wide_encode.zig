const std = @import("std");

fn codecModule(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    return b.createModule(.{
        .root_source_file = b.path("src/deflate.zig"),
        .target = target,
        .optimize = optimize,
        .single_threaded = target.result.cpu.arch == .wasm32,
    });
}

/// Keep the three execution targets and two bounded oracle campaigns together.
pub fn register(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const x86 = b.resolveTargetQuery(.{ .cpu_arch = .x86, .os_tag = .linux });
    const wasi = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .wasi });
    for ([_]struct { suffix: []const u8, target: std.Build.ResolvedTarget }{
        .{ .suffix = "", .target = target },
        .{ .suffix = "-x86", .target = x86 },
        .{ .suffix = "-wasm", .target = wasi },
    }) |variant| {
        const tests = b.addTest(.{
            .name = b.fmt("vort-deflate-wide-encode{s}-tests", .{variant.suffix}),
            .root_module = codecModule(b, variant.target, optimize),
            .filters = &.{"Deflate wide encode"},
        });
        const gate = b.step(b.fmt("test-deflate-wide-encode{s}", .{variant.suffix}), "Execute wide encoder, matcher, PNG run and overflow contracts");
        if (variant.target.result.cpu.arch == .wasm32) {
            tests.stack_size = 8 * 1024 * 1024;
            const run = b.addSystemCommand(&.{ "node", "tools/deflate/wide_encode/wasm_gate.js" });
            run.addArtifactArg(tests);
            gate.dependOn(&run.step);
        } else {
            gate.dependOn(&b.addRunArtifact(tests).step);
        }
    }
    var probes: [2]*std.Build.Step.Compile = undefined;
    for ([_]std.Build.ResolvedTarget{ target, x86 }, 0..) |probe_target, index| {
        probes[index] = b.addExecutable(.{
            .name = if (index == 0) "vort-deflate-wide-encode-probe" else "vort-deflate-wide-encode-probe-x86",
            .root_module = b.createModule(.{
                .root_source_file = b.path("tools/deflate/wide_encode/probe.zig"),
                .target = probe_target,
                .optimize = .ReleaseFast,
                .imports = &.{.{ .name = "codec", .module = codecModule(b, probe_target, .ReleaseFast) }},
            }),
        });
    }
    for ([_]bool{ false, true }) |long| {
        const run = b.addSystemCommand(&.{ "python3", "tools/deflate/wide_encode/driver.py", "--probe-native" });
        run.addArtifactArg(probes[0]);
        run.addArg("--probe-x86");
        run.addArtifactArg(probes[1]);
        run.addArgs(&.{ "--output-dir", if (long) "zig-out/deflate-wide-encode-long" else "zig-out/deflate-wide-encode-smoke" });
        if (long) run.addArg("--long");
        b.step(if (long) "run-deflate-wide-encode-long-diff" else "run-deflate-wide-encode-diff", "Encode bounded native and 32-bit streams and validate every decoded byte against libz")
            .dependOn(&run.step);
    }
}
