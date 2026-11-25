const std = @import("std");

pub fn register(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    br_tests_mod: *std.Build.Module,
) void {
    if (target.result.cpu.arch == .wasm32) br_tests_mod.single_threaded = true;
    const code_tests = b.addTest(.{
        .name = "vort-br-fixed-length-codes-tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/fixed_split_length_gate.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .filters = &.{ "fixed length", "fixed distance", "fixed split length format" },
    });
    b.step("test-br-fixed-length-codes", "Run focused fixed-split block-length code and RFC format contracts")
        .dependOn(&b.addRunArtifact(code_tests).step);

    const wire_tests = b.addTest(.{
        .name = "vort-br-fixed-length-wires-tests",
        .root_module = br_tests_mod,
        .filters = &.{"br fixed split complex block lengths"},
    });
    if (target.result.cpu.arch == .wasm32) wire_tests.stack_size = 8 * 1024 * 1024;
    b.step("test-br-fixed-length-wires", "Run complete Brotli wires with complex fixed-split block-length trees")
        .dependOn(&b.addRunArtifact(wire_tests).step);
    b.step("build-br-fixed-length-wires", "Build fixed-split wire tests for an external executor")
        .dependOn(&b.addInstallArtifact(wire_tests, .{}).step);
}
