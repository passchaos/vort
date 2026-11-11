const std = @import("std");

pub fn register(b: *std.Build, target: std.Build.ResolvedTarget, br: *std.Build.Module) void {
    const sampling = b.createModule(.{
        .root_source_file = b.path("tools/decode/sampling.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });
    const probe = b.addExecutable(.{
        .name = "vort-br-header-profile",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/br/decode_mozilla/header_profile.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "br", .module = br },
                .{ .name = "sampling", .module = sampling },
            },
        }),
    });
    b.step("build-br-header-profile", "Build aggregate multi-block Brotli header diagnostics")
        .dependOn(&b.addInstallArtifact(probe, .{}).step);
    const run = b.addRunArtifact(probe);
    if (b.args) |args| run.addArgs(args);
    b.step("run-br-header-profile", "Profile existing Brotli headers outside whole-codec timing")
        .dependOn(&run.step);

    const safe_br = b.createModule(.{
        .root_source_file = b.path("src/br.zig"),
        .target = target,
        .optimize = .ReleaseSafe,
    });
    const safe_sampling = b.createModule(.{
        .root_source_file = b.path("tools/decode/sampling.zig"),
        .target = target,
        .optimize = .ReleaseSafe,
    });
    const tests = b.addTest(.{
        .name = "vort-br-header-profile-tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/br/decode_mozilla/header_profile.zig"),
            .target = target,
            .optimize = .ReleaseSafe,
            .imports = &.{
                .{ .name = "br", .module = safe_br },
                .{ .name = "sampling", .module = safe_sampling },
            },
        }),
        .filters = &.{"Mozilla header diagnostic"},
    });
    b.step("test-br-header-profile", "Test diagnostic options and work limits")
        .dependOn(&b.addRunArtifact(tests).step);

    const counts = b.addExecutable(.{
        .name = "vort-br-payload-counts",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/br/decode_mozilla/payload_counts.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "br", .module = br },
                .{ .name = "sampling", .module = sampling },
            },
        }),
    });
    b.step("build-br-payload-counts", "Build whole-stream Brotli payload counter diagnostics")
        .dependOn(&b.addInstallArtifact(counts, .{}).step);
    const counts_run = b.addRunArtifact(counts);
    if (b.args) |args| counts_run.addArgs(args);
    b.step("run-br-payload-counts", "Inspect existing Brotli commands without timing")
        .dependOn(&counts_run.step);
    const counts_tests = b.addTest(.{
        .name = "vort-br-payload-counts-tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/br/decode_mozilla/payload_counts.zig"),
            .target = target,
            .optimize = .ReleaseSafe,
            .imports = &.{
                .{ .name = "br", .module = safe_br },
                .{ .name = "sampling", .module = safe_sampling },
            },
        }),
        .filters = &.{"Mozilla payload counts"},
    });
    b.step("test-br-payload-counts", "Test payload diagnostic paths and output sizes")
        .dependOn(&b.addRunArtifact(counts_tests).step);
}
