const std = @import("std");
const public_build = @import("wide_sizes.zig");

fn familyModule(b: *std.Build, family: []const u8, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const module = b.createModule(.{
        .root_source_file = b.path(b.fmt("src/{s}.zig", .{family})),
        .target = target,
        .optimize = optimize,
        .single_threaded = target.result.cpu.arch == .wasm32,
    });
    if (std.mem.eql(u8, family, "zstd")) {
        module.addObject(b.addObject(.{
            .name = b.fmt("vort-codec-controls-zstd-object-{s}", .{@tagName(target.result.cpu.arch)}),
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/zstd_huffman_x2_object.zig"),
                .target = target,
                .optimize = optimize,
            }),
        }));
    }
    return module;
}

/// Keep explicit format controls and their independent references together.
pub fn register(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, public_native: *std.Build.Module) void {
    const x86 = b.resolveTargetQuery(.{ .cpu_arch = .x86, .os_tag = .linux });
    const wasi = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .wasi });
    const public_x86 = public_build.publicModule(b, x86);
    const public_wasi = public_build.publicModule(b, wasi);
    for ([_]std.Build.ResolvedTarget{ target, x86, wasi }, [_]*std.Build.Module{ public_native, public_x86, public_wasi }, 0..) |variant, public, index| {
        const suffix = ([_][]const u8{ "", "-x86", "-wasm" })[index];
        const gate = b.step(b.fmt("test-codec-format-controls{s}", .{suffix}), "Verify zlib window and Zstd checksum controls through codec and package APIs");
        const wasm_run = if (index == 2) b.addSystemCommand(&.{ "node", "tools/codec_controls/wasm_gate.js" }) else null;
        for ([_][]const u8{ "deflate", "zstd" }) |family| {
            const tests = b.addTest(.{
                .name = b.fmt("vort-{s}-format-controls{s}-tests", .{ family, suffix }),
                .root_module = familyModule(b, family, variant, optimize),
                .filters = if (std.mem.eql(u8, family, "deflate")) &.{ "zlib explicit window", "incremental zlib encoder window", "zlib window headers", "zlib independent RFC" } else &.{"ignore content checksum"},
            });
            if (wasm_run) |run| {
                tests.stack_size = 8 * 1024 * 1024;
                run.addArtifactArg(tests);
            } else gate.dependOn(&b.addRunArtifact(tests).step);
        }
        const exports = b.addTest(.{
            .name = b.fmt("vort-public-format-controls{s}-tests", .{suffix}),
            .root_module = public,
            .filters = &.{"root codec format controls"},
        });
        if (wasm_run) |run| {
            exports.stack_size = 8 * 1024 * 1024;
            run.addArtifactArg(exports);
            gate.dependOn(&b.addInstallFile(run.captureStdOut(.{}), "codec-format-controls-wasm.json").step);
        } else gate.dependOn(&b.addRunArtifact(exports).step);
    }

    var probes: [2]*std.Build.Step.Compile = undefined;
    for ([_]*std.Build.Module{ public_native, public_x86 }, [_]std.Build.ResolvedTarget{ target, x86 }, 0..) |module, variant, index| {
        probes[index] = b.addExecutable(.{
            .name = if (index == 0) "vort-codec-format-controls-probe" else "vort-codec-format-controls-probe-x86",
            .root_module = b.createModule(.{
                .root_source_file = b.path("tools/codec_controls/probe.zig"),
                .target = variant,
                .optimize = .ReleaseFast,
                .imports = &.{.{ .name = "codec", .module = module }},
            }),
        });
    }
    const run = b.addSystemCommand(&.{ "python3", "tools/codec_controls/driver.py", "--probe-native" });
    run.addArtifactArg(probes[0]);
    run.addArg("--probe-x86");
    run.addArtifactArg(probes[1]);
    run.addArgs(&.{ "--output-dir", "zig-out/codec-format-controls" });
    if (b.args) |args| run.addArgs(args);
    b.step("run-codec-format-controls-diff", "Compare emitted zlib distances and Zstd checksum policies with independent references")
        .dependOn(&run.step);
}
