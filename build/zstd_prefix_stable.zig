const std = @import("std");
const public_build = @import("wide_sizes.zig");

const Feature = struct {
    name: []const u8,
    filter: []const u8,
    root_filter: []const u8,
    tools: []const u8,
};

const features = [_]Feature{
    .{ .name = "zstd-prefix-lifecycle", .filter = "Zstd prefix lifecycle", .root_filter = "root Zstd prefix lifecycle", .tools = "tools/zstd/prefix_lifecycle" },
    .{ .name = "zstd-stable-output", .filter = "Zstd stable output", .root_filter = "root Zstd stable output", .tools = "tools/zstd/stable_output" },
};

pub const Gates = struct {
    compile_all: *std.Build.Step,
    compile_wasm: *std.Build.Step,
};

fn codecModule(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const module = b.createModule(.{
        .root_source_file = b.path("src/zstd.zig"),
        .target = target,
        .optimize = optimize,
        .single_threaded = target.result.cpu.arch == .wasm32,
    });
    module.addObject(b.addObject(.{
        .name = b.fmt("vort-zstd-prefix-stable-huffman-x2-{s}", .{@tagName(target.result.cpu.arch)}),
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
    const compile_all = b.step("check-zstd-prefix-stable", "Compile every Zstd prefix and stable-output consumer and probe");
    const compile_wasm = b.step("check-zstd-prefix-stable-wasm", "Compile Zstd prefix and stable-output WASI consumers");
    compile_all.dependOn(compile_wasm);
    const public_smoke = b.step("test-zstd-prefix-stable-public", "Verify native public Zstd prefix and stable output consumers");

    for (features) |feature| {
        for ([_]std.Build.ResolvedTarget{ target, x86, wasi }, [_]*std.Build.Module{ public_native, public_x86, public_wasi }, 0..) |variant, public, index| {
            const suffix = ([_][]const u8{ "", "-x86", "-wasm" })[index];
            const gate = b.step(b.fmt("test-{s}{s}", .{ feature.name, suffix }), "Verify Zstd prefix or stable output lifecycle through codec and public APIs");
            const codec_tests = b.addTest(.{
                .name = b.fmt("vort-{s}{s}-tests", .{ feature.name, suffix }),
                .root_module = codecModule(b, variant, optimize),
                .filters = &.{feature.filter},
            });
            const public_tests = b.addTest(.{
                .name = b.fmt("vort-{s}{s}-public-tests", .{ feature.name, suffix }),
                .root_module = public,
                .filters = &.{feature.root_filter},
            });
            if (index == 2) {
                compile_wasm.dependOn(&codec_tests.step);
                compile_wasm.dependOn(&public_tests.step);
            } else {
                compile_all.dependOn(&codec_tests.step);
                compile_all.dependOn(&public_tests.step);
            }
            if (index == 2) {
                codec_tests.stack_size = 8 * 1024 * 1024;
                public_tests.stack_size = 8 * 1024 * 1024;
                const run = b.addSystemCommand(&.{ "node", b.fmt("{s}/wasm_gate.js", .{feature.tools}) });
                run.addArtifactArg(codec_tests);
                run.addArtifactArg(public_tests);
                gate.dependOn(&b.addInstallFile(run.captureStdOut(.{}), b.fmt("{s}-wasm.json", .{feature.name})).step);
            } else {
                gate.dependOn(&b.addRunArtifact(codec_tests).step);
                const public_run = b.addRunArtifact(public_tests);
                gate.dependOn(&public_run.step);
                if (index == 0) public_smoke.dependOn(&public_run.step);
            }
        }

        var probes: [2]*std.Build.Step.Compile = undefined;
        for ([_]std.Build.ResolvedTarget{ target, x86 }, [_]*std.Build.Module{ public_native, public_x86 }, 0..) |variant, public, index| {
            probes[index] = b.addExecutable(.{
                .name = b.fmt("vort-{s}-probe{s}", .{ feature.name, if (index == 0) @as([]const u8, "") else "-x86" }),
                .root_module = b.createModule(.{
                    .root_source_file = b.path(b.fmt("{s}/probe.zig", .{feature.tools})),
                    .target = variant,
                    .optimize = .ReleaseFast,
                    .imports = &.{.{ .name = "codec", .module = public }},
                }),
            });
            compile_all.dependOn(&probes[index].step);
        }
        for ([_]bool{ true, false }) |preflight| {
            const run = b.addSystemCommand(&.{ "python3", b.fmt("{s}/driver.py", .{feature.tools}), "--probe-native" });
            run.addArtifactArg(probes[0]);
            run.addArg("--probe-x86");
            run.addArtifactArg(probes[1]);
            run.addArgs(&.{ "--output-dir", b.fmt("zig-out/{s}{s}", .{ feature.name, if (preflight) @as([]const u8, "-preflight") else "" }) });
            if (preflight) run.addArg("--preflight");
            if (b.args) |args| run.addArgs(args);
            b.step(b.fmt("run-{s}{s}-diff", .{ feature.name, if (preflight) @as([]const u8, "-preflight") else "" }), "Compare public Zstd prefix or stable output behavior with libzstd")
                .dependOn(&run.step);
        }
    }
    return .{ .compile_all = compile_all, .compile_wasm = compile_wasm };
}
