const std = @import("std");

fn familyModule(b: *std.Build, family: []const u8, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const module = b.createModule(.{
        .root_source_file = b.path(b.fmt("src/{s}.zig", .{family})),
        .target = target,
        .optimize = optimize,
        .single_threaded = target.result.cpu.arch == .wasm32,
    });
    const object = b.addObject(.{
        .name = b.fmt("vort-wide-size-{s}-object-{s}", .{ family, @tagName(target.result.cpu.arch) }),
        .root_module = b.createModule(.{
            .root_source_file = b.path(if (std.mem.eql(u8, family, "br")) "src/br/encoder/record_optimal_object.zig" else "src/zstd_huffman_x2_object.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    module.addObject(object);
    return module;
}

pub fn publicModule(b: *std.Build, target: std.Build.ResolvedTarget) *std.Build.Module {
    const dependency = b.dependency("vail_archive_crypto", .{ .target = target, .optimize = .ReleaseFast });
    const module = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = .ReleaseFast,
        .imports = &.{.{ .name = "vail_archive_crypto", .module = dependency.module("vail_archive_crypto") }},
    });
    for ([_][]const u8{ "br", "zstd" }) |family| {
        const object = b.addObject(.{
            .name = b.fmt("vort-wide-size-public-{s}-object-{s}", .{ family, @tagName(target.result.cpu.arch) }),
            .root_module = b.createModule(.{
                .root_source_file = b.path(if (std.mem.eql(u8, family, "br")) "src/br/encoder/record_optimal_object.zig" else "src/zstd_huffman_x2_object.zig"),
                .target = target,
                .optimize = .ReleaseFast,
            }),
        });
        module.addObject(object);
    }
    return module;
}

pub fn register(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, public_native: *std.Build.Module, br_native: *std.Build.Module, zstd_native: *std.Build.Module) void {
    const x86 = b.resolveTargetQuery(.{ .cpu_arch = .x86, .os_tag = .linux });
    const wasi = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .wasi });
    for ([_]struct { suffix: []const u8, target: std.Build.ResolvedTarget }{
        .{ .suffix = "", .target = target },
        .{ .suffix = "-x86", .target = x86 },
        .{ .suffix = "-wasm", .target = wasi },
    }, 0..) |variant, index| {
        const gate = b.step(b.fmt("test-br-zstd-wide-size-counts{s}", .{variant.suffix}), "Execute wide decoded sizes, summary statistics, dictionary and physical-boundary contracts");
        const wasm_run = if (index == 2) b.addSystemCommand(&.{ "node", "tools/wide_sizes/wasm_gate.js" }) else null;
        for ([_][]const u8{ "br", "zstd" }) |family| {
            const is_br = std.mem.eql(u8, family, "br");
            const module = if (index == 0) (if (is_br) br_native else zstd_native) else familyModule(b, family, variant.target, optimize);
            const tests = b.addTest(.{
                .name = b.fmt("vort-{s}-wide-size{s}-tests", .{ family, variant.suffix }),
                .root_module = module,
                .filters = if (is_br) &.{ "Brotli wide count-only summary", "static dictionary chunk wide admission" } else &.{"Zstd decoded counts"},
            });
            if (wasm_run) |run| {
                tests.stack_size = 8 * 1024 * 1024;
                run.addArtifactArg(tests);
            } else {
                gate.dependOn(&b.addRunArtifact(tests).step);
            }
        }
        if (wasm_run) |run| gate.dependOn(&run.step);
    }
    const public_x86 = publicModule(b, x86);
    var probes: [2]*std.Build.Step.Compile = undefined;
    for ([_]*std.Build.Module{ public_native, public_x86 }, [_]std.Build.ResolvedTarget{ target, x86 }, 0..) |module, probe_target, index| {
        probes[index] = b.addExecutable(.{
            .name = if (index == 0) "vort-wide-size-probe" else "vort-wide-size-probe-x86",
            .root_module = b.createModule(.{
                .root_source_file = b.path("tools/wide_sizes/probe.zig"),
                .target = probe_target,
                .optimize = .ReleaseFast,
                .imports = &.{.{ .name = "codec", .module = module }},
            }),
        });
    }
    for ([_]bool{ false, true }) |long| {
        const run = b.addSystemCommand(&.{ "python3", "tools/wide_sizes/driver.py", "--probe-native" });
        run.addArtifactArg(probes[0]);
        run.addArg("--probe-x86");
        run.addArtifactArg(probes[1]);
        run.addArgs(&.{ "--output-dir", if (long) "zig-out/br-zstd-wide-size-long" else "zig-out/br-zstd-wide-size-smoke" });
        if (long) run.addArg("--long");
        if (b.args) |args| run.addArgs(args);
        b.step(if (long) "run-br-zstd-wide-size-long-diff" else "run-br-zstd-wide-size-diff", "Validate actual large decoded sizes and chunk encoding against independent Brotli/Zstd streams")
            .dependOn(&run.step);
    }
}
