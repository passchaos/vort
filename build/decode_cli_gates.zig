const std = @import("std");

pub fn register(
    b: *std.Build,
    native_cli: *std.Build.Step.Compile,
    wasm_target: std.Build.ResolvedTarget,
    wasm_mod: *std.Build.Module,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step {
    const probe = b.addExecutable(.{
        .name = "vort-decode-cli-wasm",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/decode_cli_probe.zig"),
            .target = wasm_target,
            .optimize = optimize,
            .single_threaded = true,
            .imports = &.{.{ .name = "vort", .module = wasm_mod }},
        }),
    });
    probe.stack_size = 8 * 1024 * 1024;
    const runner = b.path("tools/zstd/decode_window_cli_wasi.js");
    registerGate(b, native_cli, probe, runner, "test-zstd-decode-window-cli", "Run Zstd window limit CLI contracts on native and actual WASI", &.{ "python3", "tools/zstd/decode_window_cli_gate.py", "--cli" });
    registerGate(b, native_cli, probe, runner, "test-zstd-stdio-cli", "Run Zstd binary streaming and atomic output contracts on native and WASI", &.{ "python3", "tools/zstd/stdio_cli_gate.py" });
    registerGate(b, native_cli, probe, runner, "test-br-stdio-cli", "Run Brotli binary streaming and atomic output contracts on native and WASI", &.{ "python3", "tools/br/stdio_cli_gate.py" });
    return &probe.step;
}

fn registerGate(
    b: *std.Build,
    native_cli: *std.Build.Step.Compile,
    probe: *std.Build.Step.Compile,
    runner: std.Build.LazyPath,
    name: []const u8,
    description: []const u8,
    command: []const []const u8,
) void {
    const gate = b.step(name, description);
    const native = b.addSystemCommand(command);
    native.addArtifactArg(native_cli);
    gate.dependOn(&native.step);
    const wasm = b.addSystemCommand(command);
    wasm.addArtifactArg(probe);
    wasm.addArg("--wasi-runner");
    wasm.addFileArg(runner);
    gate.dependOn(&wasm.step);
}
