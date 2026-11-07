const std = @import("std");
const public_build = @import("wide_sizes.zig");

pub const Gates = struct { compile_all: *std.Build.Step, compile_wasm: *std.Build.Step };

fn codecModule(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const module = b.createModule(.{
        .root_source_file = b.path("src/zstd.zig"),
        .target = target,
        .optimize = optimize,
        .single_threaded = target.result.cpu.arch == .wasm32,
    });
    module.addObject(b.addObject(.{
        .name = b.fmt("vort-zstd-history-workspace-huffman-x2-{s}", .{@tagName(target.result.cpu.arch)}),
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/zstd_huffman_x2_object.zig"),
            .target = target,
            .optimize = optimize,
        }),
    }));
    return module;
}

pub fn register(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, public_native: *std.Build.Module) Gates {
    const x86 = b.resolveTargetQuery(.{ .cpu_arch = .x86, .os_tag = .linux });
    const wasi = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .wasi });
    const public_x86 = public_build.publicModule(b, x86);
    const public_wasi = public_build.publicModule(b, wasi);
    public_wasi.single_threaded = true;
    const compile_all = b.step("check-zstd-history-workspace", "Compile every Zstd history-workspace consumer");
    const compile_wasm = b.step("check-zstd-history-workspace-wasm", "Compile Zstd history-workspace WASI consumers");
    compile_all.dependOn(compile_wasm);

    for ([_]std.Build.ResolvedTarget{ target, x86, wasi }, [_]*std.Build.Module{ public_native, public_x86, public_wasi }, 0..) |variant, public, index| {
        const suffix = ([_][]const u8{ "", "-x86", "-wasm" })[index];
        const gate = b.step(b.fmt("test-zstd-history-workspace{s}", .{suffix}), "Run Zstd caller-owned history workspace contracts");
        const codec_tests = b.addTest(.{
            .name = b.fmt("vort-zstd-history-workspace{s}-tests", .{suffix}),
            .root_module = codecModule(b, variant, optimize),
            .filters = &.{"Zstd history workspace"},
        });
        const public_tests = b.addTest(.{
            .name = b.fmt("vort-zstd-history-workspace{s}-public-tests", .{suffix}),
            .root_module = public,
            .filters = &.{"root Zstd history workspace consumers"},
        });
        if (index == 2) {
            codec_tests.stack_size = 8 * 1024 * 1024;
            public_tests.stack_size = 8 * 1024 * 1024;
            compile_wasm.dependOn(&codec_tests.step);
            compile_wasm.dependOn(&public_tests.step);
            const run = b.addSystemCommand(&.{ "node", "tools/zstd/history_workspace_wasm_gate.js" });
            run.addArtifactArg(codec_tests);
            run.addArtifactArg(public_tests);
            gate.dependOn(&b.addInstallFile(run.captureStdOut(.{}), "zstd-history-workspace-wasm.json").step);
        } else {
            compile_all.dependOn(&codec_tests.step);
            compile_all.dependOn(&public_tests.step);
            gate.dependOn(&b.addRunArtifact(codec_tests).step);
            gate.dependOn(&b.addRunArtifact(public_tests).step);
        }
    }
    return .{ .compile_all = compile_all, .compile_wasm = compile_wasm };
}
