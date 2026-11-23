const std = @import("std");

pub fn register(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step {
    const check = b.step("check-gzip-header-events", "Execute incremental gzip header observation contracts on native, x86 and WASI");
    const compile_wasm = b.step("check-gzip-header-events-wasm", "Compile incremental gzip header observation contracts for WASI");
    const x86 = b.resolveTargetQuery(.{ .cpu_arch = .x86, .os_tag = .linux, .abi = .musl });
    const wasi = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .wasi });
    const filter = "gzip incremental header event contracts";
    for ([_]struct { suffix: []const u8, target: std.Build.ResolvedTarget }{
        .{ .suffix = "", .target = target },
        .{ .suffix = "-x86", .target = x86 },
        .{ .suffix = "-wasm", .target = wasi },
    }, 0..) |variant, index| {
        const gate = b.step(b.fmt("test-gzip-header-events{s}", .{variant.suffix}), "Run incremental gzip header observation contracts");
        const tests = b.addTest(.{
            .name = b.fmt("vort-gzip-header-events{s}-tests", .{variant.suffix}),
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/deflate.zig"),
                .target = variant.target,
                .optimize = optimize,
                .single_threaded = index == 2,
            }),
            .filters = &.{filter},
        });
        if (index == 2) {
            tests.stack_size = 8 * 1024 * 1024;
            compile_wasm.dependOn(&tests.step);
            const run = b.addSystemCommand(&.{ "node", "tools/wasi_test_gate.js", "gzip", filter });
            run.addArtifactArg(tests);
            gate.dependOn(&b.addInstallFile(run.captureStdOut(.{}), "gzip-header-events-wasm.json").step);
        } else gate.dependOn(&b.addRunArtifact(tests).step);
        check.dependOn(gate);
    }
    return compile_wasm;
}
