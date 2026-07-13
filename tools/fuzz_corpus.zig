const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var mode: Mode = .store;
    var saw_store = false;
    var saw_deflate = false;
    var cases: usize = 0;
    var accepted: usize = 0;
    var rejected: usize = 0;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--store")) {
            mode = .store;
            continue;
        }
        if (std.mem.eql(u8, arg, "--deflate")) {
            mode = .deflate;
            continue;
        }

        const bytes = try hexToOwnedBytes(init.gpa, arg);
        defer init.gpa.free(bytes);
        cases += 1;
        switch (mode) {
            .store => {
                saw_store = true;
                if (vort.store.parseHeader(bytes)) |_| {
                    accepted += 1;
                } else |err| switch (err) {
                    error.TruncatedFrame,
                    error.InvalidMagic,
                    error.UnsupportedVersion,
                    error.CorruptFrame,
                    => rejected += 1,
                    else => return err,
                }
            },
            .deflate => {
                saw_deflate = true;
                if (vort.decodeRawDeflateAlloc(init.gpa, bytes)) |decoded| {
                    defer init.gpa.free(decoded);
                    accepted += 1;
                } else |err| switch (err) {
                    error.TruncatedFrame,
                    error.InvalidDeflateBlockType,
                    error.StoredLengthMismatch,
                    error.InvalidDynamicBlockHeader,
                    error.InvalidHuffmanCode,
                    error.InvalidMatch,
                    error.CorruptFrame,
                    error.TrailingData,
                    => rejected += 1,
                    else => return err,
                }
            },
        }
    }

    if (cases == 0) {
        const store_stats = try vort.fuzz.runStoreSmokeCorpus(init.gpa);
        const deflate_stats = try vort.fuzz.runDeflateSmokeCorpus(init.gpa);
        var stdout_buffer: [512]u8 = undefined;
        var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
        const stdout = &stdout_writer.interface;
        try stdout.print("fuzz corpus: store_cases={d} store_accepted={d} store_rejected={d} deflate_cases={d} deflate_accepted={d} deflate_rejected={d}\n", .{
            store_stats.cases,
            store_stats.valid_frames,
            store_stats.expected_errors,
            deflate_stats.cases,
            deflate_stats.valid_frames,
            deflate_stats.expected_errors,
        });
        try stdout.flush();
        return;
    }

    var stdout_buffer: [512]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    const mode_label = if (saw_store and saw_deflate) "mixed" else if (saw_deflate) "deflate" else "store";
    try stdout.print("fuzz corpus: mode={s} cases={d} accepted={d} rejected={d}\n", .{ mode_label, cases, accepted, rejected });
    try stdout.flush();
}

const Mode = enum { store, deflate };

fn hexToOwnedBytes(allocator: std.mem.Allocator, hex: []const u8) ![]u8 {
    if ((hex.len & 1) != 0) return error.InvalidHexInput;
    const bytes = try allocator.alloc(u8, hex.len / 2);
    errdefer allocator.free(bytes);
    var i: usize = 0;
    while (i < bytes.len) : (i += 1) {
        bytes[i] = try std.fmt.parseInt(u8, hex[i * 2 .. i * 2 + 2], 16);
    }
    return bytes;
}
