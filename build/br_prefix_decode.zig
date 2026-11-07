const std = @import("std");
const public_build = @import("wide_sizes.zig");

pub const Gates = struct {
    compile_all: *std.Build.Step,
    compile_wasm: *std.Build.Step,
};

fn codecModule(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const module = b.createModule(.{
        .root_source_file = b.path("src/br.zig"),
        .target = target,
        .optimize = optimize,
        .single_threaded = target.result.cpu.arch == .wasm32,
    });
    module.addObject(b.addObject(.{
        .name = b.fmt("vort-br-prefix-decode-object-{s}", .{@tagName(target.result.cpu.arch)}),
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/br/encoder/record_optimal_object.zig"),
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
    const compile_all = b.step("check-br-prefix-decode", "Compile every Brotli prefix-decode consumer and probe");
    const compile_wasm = b.step("check-br-prefix-decode-wasm", "Compile Brotli prefix-decode WASI consumers");
    compile_all.dependOn(compile_wasm);

    for ([_]std.Build.ResolvedTarget{ target, x86, wasi }, [_]*std.Build.Module{ public_native, public_x86, public_wasi }, 0..) |variant, public, index| {
        const suffix = ([_][]const u8{ "", "-x86", "-wasm" })[index];
        const gate = b.step(b.fmt("test-br-prefix-decode{s}", .{suffix}), "Run first-stream Brotli decode contracts through codec and package APIs");
        const codec_tests = b.addTest(.{
            .name = b.fmt("vort-br-prefix-decode{s}-tests", .{suffix}),
            .root_module = codecModule(b, variant, optimize),
            .filters = &.{"Brotli prefix decode contracts"},
        });
        const public_tests = b.addTest(.{
            .name = b.fmt("vort-br-prefix-decode{s}-public-tests", .{suffix}),
            .root_module = public,
            .filters = &.{"root Brotli prefix decode consumers"},
        });
        if (index == 2) {
            codec_tests.stack_size = 8 * 1024 * 1024;
            public_tests.stack_size = 8 * 1024 * 1024;
            compile_wasm.dependOn(&codec_tests.step);
            compile_wasm.dependOn(&public_tests.step);
            const run = b.addSystemCommand(&.{ "node", "tools/br/prefix_decode/wasm_gate.js" });
            run.addArtifactArg(codec_tests);
            run.addArtifactArg(public_tests);
            gate.dependOn(&b.addInstallFile(run.captureStdOut(.{}), "br-prefix-decode-wasm.json").step);
        } else {
            compile_all.dependOn(&codec_tests.step);
            compile_all.dependOn(&public_tests.step);
            gate.dependOn(&b.addRunArtifact(codec_tests).step);
            gate.dependOn(&b.addRunArtifact(public_tests).step);
        }
    }

    var probes: [2]*std.Build.Step.Compile = undefined;
    for ([_]std.Build.ResolvedTarget{ target, x86 }, [_]*std.Build.Module{ public_native, public_x86 }, 0..) |variant, public, index| {
        probes[index] = b.addExecutable(.{
            .name = if (index == 0) "vort-br-prefix-decode-probe" else "vort-br-prefix-decode-probe-x86",
            .root_module = b.createModule(.{
                .root_source_file = b.path("tools/br/prefix_decode/probe.zig"),
                .target = variant,
                .optimize = .ReleaseFast,
                .imports = &.{.{ .name = "codec", .module = public }},
            }),
        });
        compile_all.dependOn(&probes[index].step);
    }
    const differential = b.addSystemCommand(&.{ "python3", "tools/br/prefix_decode/driver.py", "--probe-native" });
    differential.addArtifactArg(probes[0]);
    differential.addArg("--probe-x86");
    differential.addArtifactArg(probes[1]);
    differential.addArgs(&.{ "--output-dir", "zig-out/br-prefix-decode" });
    b.step("run-br-prefix-decode-diff", "Compare Brotli prefix boundaries with libbrotli DecompressStream")
        .dependOn(&differential.step);
    return .{ .compile_all = compile_all, .compile_wasm = compile_wasm };
}
