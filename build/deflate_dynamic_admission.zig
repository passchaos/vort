const std = @import("std");
const codecModule = @import("incremental_encode_borrows.zig").codecModule;

pub fn register(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step {
    const all = b.step("check-deflate-dynamic-admission", "Execute dynamic Huffman validity contracts on native, x86 and WASI");
    const compile_wasm = b.step("check-deflate-dynamic-admission-wasm", "Compile dynamic Huffman validity contracts for WASI");
    const x86 = b.resolveTargetQuery(.{ .cpu_arch = .x86, .os_tag = .linux, .abi = .musl });
    const wasi = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .wasi });
    for ([_]struct { suffix: []const u8, target: std.Build.ResolvedTarget }{
        .{ .suffix = "", .target = target },
        .{ .suffix = "-x86", .target = x86 },
        .{ .suffix = "-wasm", .target = wasi },
    }, 0..) |variant, index| {
        const gate = b.step(b.fmt("test-deflate-dynamic-admission{s}", .{variant.suffix}), "Validate Deflate and Deflate64 dynamic code trees before output");
        const tests = b.addTest(.{
            .name = b.fmt("vort-deflate-dynamic-admission{s}-tests", .{variant.suffix}),
            .root_module = codecModule(b, "deflate", variant.target, optimize),
            .filters = &.{"Deflate dynamic tree admission contracts"},
        });
        if (index == 2) {
            tests.stack_size = 8 * 1024 * 1024;
            compile_wasm.dependOn(&tests.step);
            const run = b.addSystemCommand(&.{ "node", "tools/wasi_test_gate.js", "deflate", "Deflate dynamic tree admission contracts" });
            run.addArtifactArg(tests);
            gate.dependOn(&b.addInstallFile(run.captureStdOut(.{}), "deflate-dynamic-admission-wasm.json").step);
        } else gate.dependOn(&b.addRunArtifact(tests).step);
        all.dependOn(gate);
    }
    return compile_wasm;
}
