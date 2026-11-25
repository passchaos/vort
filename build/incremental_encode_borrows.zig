const std = @import("std");

pub fn codecModule(b: *std.Build, family: []const u8, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const module = b.createModule(.{
        .root_source_file = b.path(b.fmt("src/{s}.zig", .{family})),
        .target = target,
        .optimize = optimize,
        .single_threaded = target.result.cpu.arch == .wasm32,
    });
    if (!std.mem.eql(u8, family, "deflate") and !std.mem.eql(u8, family, "deflate64")) {
        module.addObject(b.addObject(.{
            .name = b.fmt("vort-encode-borrows-{s}-{s}", .{ family, @tagName(target.result.cpu.arch) }),
            .root_module = b.createModule(.{
                .root_source_file = b.path(if (std.mem.eql(u8, family, "br")) "src/br/encoder/record_optimal_object.zig" else "src/zstd_huffman_x2_object.zig"),
                .target = target,
                .optimize = optimize,
                .single_threaded = target.result.cpu.arch == .wasm32,
            }),
        }));
    }
    return module;
}

pub fn register(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step {
    const all = b.step("check-incremental-encode-borrows", "Execute incremental encoder storage contracts on native, x86 and WASI");
    const compile_wasm = b.step("check-incremental-encode-borrows-wasm", "Compile incremental encoder storage contracts for WASI");
    const x86 = b.resolveTargetQuery(.{ .cpu_arch = .x86, .os_tag = .linux, .abi = .musl });
    const wasi = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .wasi });
    for ([_]struct { suffix: []const u8, target: std.Build.ResolvedTarget }{
        .{ .suffix = "", .target = target },
        .{ .suffix = "-x86", .target = x86 },
        .{ .suffix = "-wasm", .target = wasi },
    }, 0..) |variant, index| {
        const gate = b.step(b.fmt("test-incremental-encode-borrows{s}", .{variant.suffix}), "Validate Deflate, Brotli and Zstd incremental encoder borrows");
        const wasm_run = if (index == 2) b.addSystemCommand(&.{ "node", "tools/wasi_test_gate.js" }) else null;
        for ([_]struct { family: []const u8, filter: []const u8 }{
            .{ .family = "deflate", .filter = "Deflate incremental encode borrow contracts" },
            .{ .family = "deflate64", .filter = "Deflate64 incremental stored encoder borrows" },
            .{ .family = "br", .filter = "Brotli encoder step borrows" },
            .{ .family = "zstd", .filter = "Zstd incremental encoder step borrows" },
        }) |codec| {
            const tests = b.addTest(.{
                .name = b.fmt("vort-{s}-encode-borrows{s}-tests", .{ codec.family, variant.suffix }),
                .root_module = codecModule(b, codec.family, variant.target, optimize),
                .filters = &.{codec.filter},
            });
            if (wasm_run) |run| {
                tests.stack_size = 8 * 1024 * 1024;
                compile_wasm.dependOn(&tests.step);
                run.addArgs(&.{ codec.family, codec.filter });
                run.addArtifactArg(tests);
            } else gate.dependOn(&b.addRunArtifact(tests).step);
        }
        if (wasm_run) |run| {
            gate.dependOn(&b.addInstallFile(run.captureStdOut(.{}), "incremental-encode-borrows-wasm.json").step);
        }
        all.dependOn(gate);
    }
    return compile_wasm;
}
