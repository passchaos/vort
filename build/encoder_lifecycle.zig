const std = @import("std");
const codecModule = @import("incremental_encode_borrows.zig").codecModule;

pub fn register(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step {
    const all = b.step("check-encoder-lifecycle", "Execute encoder lifecycle and transition contracts on native, x86 and WASI");
    const compile_wasm = b.step("check-encoder-lifecycle-wasm", "Compile encoder lifecycle and transition contracts for WASI");
    const x86 = b.resolveTargetQuery(.{ .cpu_arch = .x86, .os_tag = .linux, .abi = .musl });
    const wasi = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .wasi });
    for ([_]struct { suffix: []const u8, target: std.Build.ResolvedTarget }{
        .{ .suffix = "", .target = target },
        .{ .suffix = "-x86", .target = x86 },
        .{ .suffix = "-wasm", .target = wasi },
    }, 0..) |variant, index| {
        const gate = b.step(b.fmt("test-encoder-lifecycle{s}", .{variant.suffix}), "Validate encoder transition admission and accepted output lifetimes");
        const wasm_run = if (index == 2) b.addSystemCommand(&.{ "node", "tools/wasi_test_gate.js" }) else null;
        for ([_]struct { family: []const u8, filters: []const []const u8, label: []const u8 }{
            .{ .family = "deflate", .filters = &.{ "Deflate encoder transition borrow contracts", "Deflate wrapper transition options" }, .label = "Deflate encoder transition borrows and options" },
            .{ .family = "br", .filters = &.{ "Brotli encoder finish pending metadata", "Brotli lifecycle borrows", "Brotli flush", "Brotli streamed metadata" }, .label = "Brotli flush, metadata and lifecycle borrows" },
            .{ .family = "zstd", .filters = &.{ "Zstd incremental next-frame borrow", "Zstd incremental encoder setter borrows", "Zstd incremental encoder skippable borrows", "Zstd streamed skippable" }, .label = "Zstd next-frame, setter and skippable lifecycle" },
        }) |codec| {
            const tests = b.addTest(.{
                .name = b.fmt("vort-{s}-encoder-lifecycle{s}-tests", .{ codec.family, variant.suffix }),
                .root_module = codecModule(b, codec.family, variant.target, optimize),
                .filters = codec.filters,
            });
            if (wasm_run) |run| {
                tests.stack_size = 8 * 1024 * 1024;
                compile_wasm.dependOn(&tests.step);
                run.addArgs(&.{ codec.family, codec.label });
                run.addArtifactArg(tests);
            } else gate.dependOn(&b.addRunArtifact(tests).step);
        }
        if (wasm_run) |run|
            gate.dependOn(&b.addInstallFile(run.captureStdOut(.{}), "encoder-lifecycle-wasm.json").step);
        all.dependOn(gate);
    }
    return compile_wasm;
}
