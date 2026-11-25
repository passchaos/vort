const std = @import("std");

pub fn register(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    vort: *std.Build.Module,
    provenance: *std.Build.Module,
) void {
    // Translate declarations without requesting linker resolution in this
    // step; the executable owns the foreign library paths and linkage.
    const zlib_header = b.addTranslateC(.{
        .root_source_file = b.path("bench/deflate/zlib_compat.h"),
        .target = target,
        .optimize = .ReleaseFast,
    });
    if (b.option([]const u8, "deflate-zlib-include", "Directory containing the matching zlib.h")) |directory|
        zlib_header.addIncludePath(.{ .cwd_relative = directory });
    const zlib = zlib_header.createModule();
    const executable = b.addExecutable(.{
        .name = "vort-deflate-encode-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/deflate/encode_bench.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vort", .module = vort },
                .{ .name = "zlib", .module = zlib },
                .{ .name = "benchmark_provenance", .module = provenance },
            },
        }),
    });
    if (b.option([]const u8, "deflate-reference-dir", "Directory containing the pinned libdeflate shared library")) |directory| {
        executable.root_module.addLibraryPath(.{ .cwd_relative = directory });
        executable.root_module.addRPath(.{ .cwd_relative = directory });
    }
    if (b.option([]const u8, "deflate-reference-include", "Directory containing the matching libdeflate.h")) |directory|
        executable.root_module.addIncludePath(.{ .cwd_relative = directory });
    if (b.option([]const u8, "deflate-zlib-dir", "Directory containing the zlib shared library")) |directory|
        executable.root_module.addLibraryPath(.{ .cwd_relative = directory });
    executable.root_module.linkSystemLibrary("deflate", .{});
    executable.root_module.linkSystemLibrary("z", .{});
    const install = b.addInstallArtifact(executable, .{});
    b.step("build-deflate-encode-bench", "Build the allocating Deflate encoder comparison").dependOn(&install.step);
    const run = b.addRunArtifact(executable);
    if (b.args) |args| run.addArgs(args);
    b.step("run-deflate-encode-bench", "Compare allocating Deflate encoders with retained raw rounds").dependOn(&run.step);

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/deflate/encode_samples_tests.zig"),
            .target = target,
            .optimize = .ReleaseSafe,
        }),
    });
    b.step("test-deflate-encode-evidence", "Validate Deflate sampling order, medians and warmup accounting").dependOn(&b.addRunArtifact(tests).step);
}
