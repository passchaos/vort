const std = @import("std");

pub fn register(b: *std.Build, target: std.Build.ResolvedTarget, codec: *std.Build.Module, provenance: *std.Build.Module) *std.Build.Step.Compile {
    const executable = b.addExecutable(.{
        .name = "vort-br-quality-stage-profile",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/br/quality_stage_profile.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vort_br", .module = codec },
                .{ .name = "benchmark_provenance", .module = provenance },
            },
        }),
    });
    b.step("build-br-quality-stage-profile", "Build the fixed-window q8 candidate diagnostic").dependOn(&b.addInstallArtifact(executable, .{}).step);
    const run = b.addRunArtifact(executable);
    if (b.args) |args| run.addArgs(args);
    b.step("run-br-quality-stage-profile", "Record actual native q8 candidate stages and wires").dependOn(&run.step);
    const tests = b.addTest(.{
        .name = "vort-br-quality-profile-binding-tests",
        .root_module = executable.root_module,
        .filters = &.{"q8 diagnostic"},
    });
    b.step("test-br-quality-profile-binding", "Test fixed-window q8 diagnostic policy and wire identity").dependOn(&b.addRunArtifact(tests).step);
    const evidence = b.step("test-br-quality-profile-evidence", "Test q8 event topology and physical wire accounting");
    evidence.dependOn(&b.addSystemCommand(&.{ "python3", "tools/br/quality_profile_gate_smoke.py" }).step);
    evidence.dependOn(&b.addSystemCommand(&.{ "python3", "tools/br/quality_profile_wire_counts_tests.py" }).step);
    return executable;
}
