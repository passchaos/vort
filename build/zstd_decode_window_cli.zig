const std = @import("std");

pub fn register(
    b: *std.Build,
    native_cli: *std.Build.Step.Compile,
    wasm_target: std.Build.ResolvedTarget,
    wasm_mod: *std.Build.Module,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step {
    const gate = b.step("test-zstd-decode-window-cli", "Run Zstd window limit CLI contracts on native and actual WASI");
    const native = b.addSystemCommand(&.{ "python3", "tools/zstd/decode_window_cli_gate.py", "--cli" });
    native.addArtifactArg(native_cli);
    gate.dependOn(&native.step);

    const probe = b.addExecutable(.{
        .name = "vort-zstd-decode-window-cli-wasm",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/zstd_decode_cli_probe.zig"),
            .target = wasm_target,
            .optimize = optimize,
            .single_threaded = true,
            .imports = &.{.{ .name = "vort", .module = wasm_mod }},
        }),
    });
    probe.stack_size = 8 * 1024 * 1024;
    const wasm = b.addSystemCommand(&.{ "python3", "tools/zstd/decode_window_cli_gate.py", "--cli" });
    wasm.addArtifactArg(probe);
    wasm.addArg("--wasi-runner");
    wasm.addFileArg(b.path("tools/zstd/decode_window_cli_wasi.js"));
    gate.dependOn(&wasm.step);
    return &probe.step;
}
