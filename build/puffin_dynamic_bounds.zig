const std = @import("std");

pub fn register(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step {
    const all = b.step("check-android-puffin-bounds", "Execute Puffin structural conversion and resource contracts on native, x86 and WASI");
    const compile_wasm = b.step("check-android-puffin-bounds-wasm", "Compile Puffin structural conversion contracts for WASI");
    const x86 = b.resolveTargetQuery(.{ .cpu_arch = .x86, .os_tag = .linux, .abi = .musl });
    const wasi = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .wasi });
    for ([_]struct { suffix: []const u8, target: std.Build.ResolvedTarget }{
        .{ .suffix = "", .target = target },
        .{ .suffix = "-x86", .target = x86 },
        .{ .suffix = "-wasm", .target = wasi },
    }, 0..) |variant, index| {
        const gate = b.step(b.fmt("test-android-puffin-bounds{s}", .{variant.suffix}), "Validate Puffin metadata, exact bits, caps and checked arithmetic");
        const tests = b.addTest(.{
            .name = b.fmt("vort-android-puffin-bounds{s}-tests", .{variant.suffix}),
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/android_ota.zig"),
                .target = variant.target,
                .optimize = optimize,
                .single_threaded = index == 2,
            }),
            .filters = &.{"Android OTA Puffin"},
        });
        if (index == 2) {
            tests.stack_size = 8 * 1024 * 1024;
            compile_wasm.dependOn(&tests.step);
            const run = b.addSystemCommand(&.{ "node", "tools/wasi_test_gate.js", "android-puffin", "Android OTA Puffin" });
            run.addArtifactArg(tests);
            gate.dependOn(&b.addInstallFile(run.captureStdOut(.{}), "android-puffin-bounds-wasm.json").step);
        } else gate.dependOn(&b.addRunArtifact(tests).step);
        all.dependOn(gate);
    }
    return compile_wasm;
}
