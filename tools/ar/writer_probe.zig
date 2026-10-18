const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const output_path = args.next() orelse return error.MissingOutputPath;
    const mode = args.next() orelse "regular";
    const bsd_modes = [_][]const u8{
        "bsd-symbols",
        "bsd-symbols-sorted",
        "bsd-symbols64",
        "bsd-symbols64-sorted",
    };
    var bsd_mode: ?vort.ArBsdSymbolIndexFormat = null;
    for (bsd_modes, [_]vort.ArBsdSymbolIndexFormat{
        .bsd32,
        .bsd32_sorted,
        .bsd64,
        .bsd64_sorted,
    }) |name, format| {
        if (std.mem.eql(u8, mode, name)) bsd_mode = format;
    }
    if (bsd_mode) |symbol_index_format| {
        const names = [_][]const u8{
            "bsd-first.o",
            "bsd/very-long-symbol-member.o",
        };
        const first_symbols = [_][]const u8{ "zeta", "alpha", "shared_a" };
        const second_symbols = [_][]const u8{ "beta", "shared_b", "calls_alpha" };
        const parent = std.fs.path.dirname(output_path) orelse ".";
        var payloads: [names.len][]u8 = undefined;
        var payload_count: usize = 0;
        defer for (payloads[0..payload_count]) |payload| init.gpa.free(payload);
        for (names, &payloads) |name, *payload| {
            const path = try std.fs.path.join(init.gpa, &.{ parent, name });
            defer init.gpa.free(path);
            payload.* = try std.Io.Dir.cwd().readFileAlloc(
                init.io,
                path,
                init.gpa,
                .limited(16 * 1024 * 1024),
            );
            payload_count += 1;
        }
        const entries = [_]vort.ArEncodeEntry{
            .{
                .name = names[0],
                .data = payloads[0],
                .symbols = &first_symbols,
                .mode = 0o100600,
            },
            .{
                .name = names[1],
                .data = payloads[1],
                .symbols = &second_symbols,
            },
        };
        const encoded = try vort.encodeArAllocWithOptions(init.gpa, &entries, .{
            .symbol_index_format = symbol_index_format,
        });
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        return;
    }
    if (std.mem.eql(u8, mode, "thin-symbols") or
        std.mem.eql(u8, mode, "thin-symbols64"))
    {
        const names = [_][]const u8{
            "thin-first.o",
            "thin/very-long-symbol-member.o",
        };
        const first_symbols = [_][]const u8{ "alpha", "shared_a" };
        const second_symbols = [_][]const u8{ "beta", "shared_b", "calls_alpha" };
        const parent = std.fs.path.dirname(output_path) orelse ".";
        var sizes: [names.len]usize = undefined;
        for (names, &sizes) |name, *size| {
            const path = try std.fs.path.join(init.gpa, &.{ parent, name });
            defer init.gpa.free(path);
            const stat = try std.Io.Dir.cwd().statFile(init.io, path, .{});
            size.* = std.math.cast(usize, stat.size) orelse return error.FileTooBig;
        }
        const entries = [_]vort.ArThinEncodeEntry{
            .{
                .name = names[0],
                .size = sizes[0],
                .symbols = &first_symbols,
                .mode = 0o100600,
            },
            .{
                .name = names[1],
                .size = sizes[1],
                .symbols = &second_symbols,
            },
        };
        const encoded = try vort.encodeThinArAllocWithOptions(init.gpa, &entries, .{
            .symbol_index_format = if (std.mem.eql(u8, mode, "thin-symbols64"))
                .gnu64
            else
                .gnu32,
        });
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        return;
    }
    if (std.mem.eql(u8, mode, "thin")) {
        const payloads = [_][]const u8{ "thin short payload\n", "thin long payload\n" };
        const names = [_][]const u8{
            "thin-short.txt",
            "thin/very-long-member-name-for-vort.txt",
        };
        const parent = std.fs.path.dirname(output_path) orelse ".";
        const subdir = try std.fs.path.join(init.gpa, &.{ parent, "thin" });
        defer init.gpa.free(subdir);
        std.Io.Dir.cwd().createDir(init.io, subdir, .default_dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
        for (names, payloads) |name, payload| {
            const path = try std.fs.path.join(init.gpa, &.{ parent, name });
            defer init.gpa.free(path);
            try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = payload });
        }
        const entries = [_]vort.ArThinEncodeEntry{
            .{ .name = names[0], .size = payloads[0].len, .mode = 0o100600 },
            .{ .name = names[1], .size = payloads[1].len },
        };
        const encoded = try vort.encodeThinArAlloc(init.gpa, &entries);
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        return;
    }
    if (!std.mem.eql(u8, mode, "regular")) return error.UnsupportedArFeature;
    const entries = [_]vort.ArEncodeEntry{
        .{ .name = "short.txt", .data = "short ar payload\n", .mode = 0o100600 },
        .{ .name = "very-long-member-name-for-vort.txt", .data = "long ar payload\n" },
        .{ .name = "odd.bin", .data = &.{ 0, 1, 2, 3, 4 } },
    };
    const encoded = try vort.encodeArAlloc(init.gpa, &entries);
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
}
