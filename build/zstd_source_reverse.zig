const std = @import("std");

pub const Gates = struct {
    all: *std.Build.Step,
    compile_wasm: *std.Build.Step,
};

fn codecModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    const module = b.createModule(.{
        .root_source_file = b.path("src/zstd.zig"),
        .target = target,
        .optimize = optimize,
        .single_threaded = target.result.cpu.arch == .wasm32,
    });
    module.addObject(b.addObject(.{
        .name = b.fmt("vort-zstd-source-reverse-huffman-x2-{s}", .{@tagName(target.result.cpu.arch)}),
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/zstd_huffman_x2_object.zig"),
            .target = target,
            .optimize = optimize,
        }),
    }));
    return module;
}

pub fn register(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) Gates {
    const x86 = b.resolveTargetQuery(.{ .cpu_arch = .x86, .os_tag = .linux });
    const wasi = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .wasi });
    const check = b.step(
        "check-zstd-source-reverse",
        "Execute source-backed Zstd layout, literal-stream, compressed-block, frame-execution, stream-cursor, public frame/stream decode and entropy primitive contracts on native, x86 and WASI",
    );
    const compile_wasm = b.step(
        "check-zstd-source-reverse-wasm",
        "Compile source-backed Zstd layout, literal-stream, compressed-block, frame-execution, stream-cursor, public frame-decode and entropy primitive WASI contracts",
    );

    for ([_]std.Build.ResolvedTarget{ target, x86, wasi }, 0..) |variant, index| {
        const suffix = ([_][]const u8{ "", "-x86", "-wasm" })[index];
        const gate = b.step(
            b.fmt("test-zstd-source-reverse{s}", .{suffix}),
            "Execute source-backed Zstd frame/block layout, unified literal streams, Huffman/sequence primitives, compressed-block, frame-execution, stream-cursor and public frame-decode contracts",
        );
        const implementation_tests = b.addTest(.{
            .name = b.fmt("vort-zstd-source-reverse{s}-tests", .{suffix}),
            .root_module = codecModule(b, variant, optimize),
            .filters = &.{"Zstd source"},
        });
        if (index == 2) {
            implementation_tests.stack_size = 8 * 1024 * 1024;
            compile_wasm.dependOn(&implementation_tests.step);
            const run = b.addSystemCommand(&.{ "node", "tools/zstd/source_reverse_wasm_gate.js" });
            run.addArtifactArg(implementation_tests);
            gate.dependOn(&b.addInstallFile(
                run.captureStdOut(.{}),
                "zstd-source-reverse-wasm.json",
            ).step);
        } else {
            gate.dependOn(&b.addRunArtifact(implementation_tests).step);
        }
        check.dependOn(gate);
    }
    return .{ .all = check, .compile_wasm = compile_wasm };
}
