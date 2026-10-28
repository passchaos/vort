const std = @import("std");
const Codec = @import("vort_zstd");
const Runtime = @import("libzstd_runtime.zig").Runtime;
const tests = @import("reference_parameters_tests.zig");

/// Run bounded parameter and wire checks against explicit library paths.
pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var count: usize = 0;
    var buffer: [1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    while (args.next()) |path| {
        var runtime = try Runtime.openPath(path);
        defer runtime.deinit();
        const report = try tests.contracts(Codec, init.gpa, runtime);
        try stdout.interface.print("library={s} version={s} parameter_cases={d} legacy_cases={d} dictionary_cases={d} status=ok\n", .{
            path, runtime.version(), report.parameter_cases, report.legacy_cases, report.dictionary_cases,
        });
        count += 1;
    }
    if (count == 0) return error.MissingReferenceLibrary;
    try stdout.interface.flush();
}
