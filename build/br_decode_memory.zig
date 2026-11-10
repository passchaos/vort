const std = @import("std");
const public_build = @import("wide_sizes.zig");

const filters: []const []const u8 = &.{
    "Brotli decode total memory",
    "Brotli incremental decode policy",
};

fn codecModule(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const module = b.createModule(.{
        .root_source_file = b.path("src/br.zig"),
        .target = target,
        .optimize = optimize,
        .single_threaded = target.result.cpu.arch == .wasm32,
    });
    module.addObject(b.addObject(.{
        .name = b.fmt("vort-br-decode-memory-object-{s}", .{@tagName(target.result.cpu.arch)}),
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/br/encoder/record_optimal_object.zig"),
            .target = target,
            .optimize = optimize,
            .single_threaded = target.result.cpu.arch == .wasm32,
        }),
    }));
    return module;
}

pub fn register(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const native_tests = b.addTest(.{
        .name = "vort-br-decode-memory-tests",
        .root_module = codecModule(b, target, optimize),
        .filters = filters,
    });
    b.step("test-br-decode-memory", "Run Brotli decode total heap and incremental policy contracts")
        .dependOn(&b.addRunArtifact(native_tests).step);

    const wasi = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .wasi });
    const wasm_tests = b.addTest(.{
        .name = "vort-br-decode-memory-wasm-tests",
        .root_module = codecModule(b, wasi, optimize),
        .filters = filters,
    });
    wasm_tests.stack_size = 8 * 1024 * 1024;
    const run = b.addSystemCommand(&.{ "node", "tools/br/decode_memory/wasm_gate.js" });
    run.addArtifactArg(wasm_tests);
    b.step("test-br-decode-memory-wasm", "Execute Brotli decode total heap and incremental policy contracts in WASI")
        .dependOn(&b.addInstallFile(run.captureStdOut(.{}), "br-decode-memory-wasm.json").step);

    const x86 = b.resolveTargetQuery(.{ .cpu_arch = .x86, .os_tag = .linux, .abi = .musl });
    var probes: [2]*std.Build.Step.Compile = undefined;
    for ([_]std.Build.ResolvedTarget{ target, x86 }, 0..) |variant, index| {
        probes[index] = b.addExecutable(.{
            .name = if (index == 0) "vort-br-decode-memory-probe" else "vort-br-decode-memory-probe-x86",
            .root_module = b.createModule(.{
                .root_source_file = b.path("tools/br/decode_memory/probe.zig"),
                .target = variant,
                .optimize = .ReleaseFast,
                .imports = &.{.{ .name = "codec", .module = public_build.publicModule(b, variant) }},
            }),
        });
    }
    const reference = b.addSystemCommand(&.{ "python3", "tools/br/decode_memory/driver.py", "--probe-native" });
    reference.addArtifactArg(probes[0]);
    reference.addArg("--probe-x86");
    reference.addArtifactArg(probes[1]);
    reference.addArgs(&.{ "--output-dir", "zig-out/br-decode-memory-reference" });
    if (b.option([]const u8, "br-decode-reference-libbrotli-dir", "Pinned local libbrotli shared-library directory for decode reference verification")) |directory| {
        reference.addArgs(&.{ "--libbrotli-dir", directory });
    }
    b.step("run-br-decode-memory-reference", "Compare native and 32-bit Brotli decode budgets with libbrotli and Python Brotli")
        .dependOn(&reference.step);
}
