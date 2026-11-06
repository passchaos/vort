const std = @import("std");
const public_build = @import("wide_sizes.zig");

const Feature = struct {
    name: []const u8,
    family: []const u8,
    filter: []const u8,
    root_filter: []const u8,
    tools: []const u8,
};
const features = [_]Feature{
    .{ .name = "deflate-clone", .family = "deflate", .filter = "Deflate clone", .root_filter = "root Deflate clone", .tools = "tools/deflate/clone" },
    .{ .name = "br-literal-context-control", .family = "br", .filter = "literal context control", .root_filter = "root Brotli literal context control", .tools = "tools/br/literal_context_control" },
    .{ .name = "zstd-dictionary-id-control", .family = "zstd", .filter = "dictionary ID control", .root_filter = "root Zstd dictionary ID control", .tools = "tools/zstd/dictionary_id_control" },
};

fn familyModule(b: *std.Build, family: []const u8, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const module = b.createModule(.{
        .root_source_file = b.path(b.fmt("src/{s}.zig", .{family})),
        .target = target,
        .optimize = optimize,
        .single_threaded = target.result.cpu.arch == .wasm32,
    });
    if (!std.mem.eql(u8, family, "deflate")) module.addObject(b.addObject(.{
        .name = b.fmt("vort-state-controls-{s}-object-{s}", .{ family, @tagName(target.result.cpu.arch) }),
        .root_module = b.createModule(.{
            .root_source_file = b.path(if (std.mem.eql(u8, family, "br")) "src/br/encoder/record_optimal_object.zig" else "src/zstd_huffman_x2_object.zig"),
            .target = target,
            .optimize = optimize,
        }),
    }));
    return module;
}

pub fn register(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, public_native: *std.Build.Module) void {
    const x86 = b.resolveTargetQuery(.{ .cpu_arch = .x86, .os_tag = .linux });
    const wasi = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .wasi });
    const public_x86 = public_build.publicModule(b, x86);
    const public_wasi = public_build.publicModule(b, wasi);
    public_wasi.single_threaded = true;
    for (features) |feature| {
        for ([_]std.Build.ResolvedTarget{ target, x86, wasi }, [_]*std.Build.Module{ public_native, public_x86, public_wasi }, 0..) |variant, public, index| {
            const suffix = ([_][]const u8{ "", "-x86", "-wasm" })[index];
            const gate = b.step(b.fmt("test-{s}{s}", .{ feature.name, suffix }), "Verify codec controls, ownership and public consumer contracts");
            const codec_tests = b.addTest(.{
                .name = b.fmt("vort-{s}{s}-tests", .{ feature.name, suffix }),
                .root_module = familyModule(b, feature.family, variant, optimize),
                .filters = &.{feature.filter},
            });
            const root_tests = b.addTest(.{
                .name = b.fmt("vort-{s}{s}-public-tests", .{ feature.name, suffix }),
                .root_module = public,
                .filters = &.{feature.root_filter},
            });
            if (index == 2) {
                codec_tests.stack_size = 8 * 1024 * 1024;
                root_tests.stack_size = 8 * 1024 * 1024;
                const run = b.addSystemCommand(&.{ "node", b.fmt("{s}/wasm_gate.js", .{feature.tools}) });
                run.addArtifactArg(codec_tests);
                run.addArtifactArg(root_tests);
                gate.dependOn(&b.addInstallFile(run.captureStdOut(.{}), b.fmt("{s}-wasm.json", .{feature.name})).step);
            } else {
                gate.dependOn(&b.addRunArtifact(codec_tests).step);
                gate.dependOn(&b.addRunArtifact(root_tests).step);
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
        }
        for ([_]bool{ true, false }) |preflight| {
            const run = b.addSystemCommand(&.{ "python3", b.fmt("{s}/driver.py", .{feature.tools}), "--probe-native" });
            run.addArtifactArg(probes[0]);
            run.addArg("--probe-x86");
            run.addArtifactArg(probes[1]);
            run.addArgs(&.{ "--output-dir", b.fmt("zig-out/{s}{s}", .{ feature.name, if (preflight) @as([]const u8, "-preflight") else "" }) });
            if (preflight) run.addArg("--preflight");
            if (b.args) |args| run.addArgs(args);
            b.step(b.fmt("run-{s}{s}-diff", .{ feature.name, if (preflight) @as([]const u8, "-preflight") else "" }), "Compare public codec controls and state transitions with independent references")
                .dependOn(&run.step);
        }
    }
}
