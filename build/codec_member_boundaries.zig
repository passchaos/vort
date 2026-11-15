const std = @import("std");

fn codecModule(b: *std.Build, family: []const u8, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const module = b.createModule(.{
        .root_source_file = b.path(b.fmt("src/{s}.zig", .{family})),
        .target = target,
        .optimize = optimize,
        .single_threaded = target.result.cpu.arch == .wasm32,
    });
    module.addObject(b.addObject(.{
        .name = b.fmt("vort-member-boundaries-{s}-{s}", .{ family, @tagName(target.result.cpu.arch) }),
        .root_module = b.createModule(.{
            .root_source_file = b.path(if (std.mem.eql(u8, family, "br")) "src/br/encoder/record_optimal_object.zig" else "src/zstd_huffman_x2_object.zig"),
            .target = target,
            .optimize = optimize,
            .single_threaded = target.result.cpu.arch == .wasm32,
        }),
    }));
    return module;
}

pub fn register(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, br_native: *std.Build.Module, zstd_native: *std.Build.Module) void {
    const x86 = b.resolveTargetQuery(.{ .cpu_arch = .x86, .os_tag = .linux, .abi = .musl });
    const wasi = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .wasi });
    for ([_]struct { suffix: []const u8, target: std.Build.ResolvedTarget }{
        .{ .suffix = "", .target = target },
        .{ .suffix = "-x86", .target = x86 },
        .{ .suffix = "-wasm", .target = wasi },
    }, 0..) |variant, index| {
        const gate = b.step(b.fmt("test-codec-member-boundaries{s}", .{variant.suffix}), "Validate Zstd empty members and Brotli final metadata across input splits");
        const wasm_run = if (index == 2) b.addSystemCommand(&.{ "node", "tools/wasi_test_gate.js" }) else null;
        for ([_][]const u8{ "br", "zstd" }) |family| {
            const is_br = std.mem.eql(u8, family, "br");
            const module = if (index == 0) (if (is_br) br_native else zstd_native) else codecModule(b, family, variant.target, optimize);
            const tests = b.addTest(.{
                .name = b.fmt("vort-{s}-member-boundaries{s}-tests", .{ family, variant.suffix }),
                .root_module = module,
                .filters = if (is_br) &.{"Brotli final metadata"} else &.{"Zstd empty member"},
            });
            if (wasm_run) |run| {
                tests.stack_size = 8 * 1024 * 1024;
                run.addArgs(&.{ family, if (is_br) "Brotli final metadata" else "Zstd empty member" });
                run.addArtifactArg(tests);
            } else {
                gate.dependOn(&b.addRunArtifact(tests).step);
            }
        }
        if (wasm_run) |run| gate.dependOn(&run.step);
    }
}
