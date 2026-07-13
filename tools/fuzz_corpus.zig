const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var state = State{};

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--file")) {
            const path = args.next() orelse return error.MissingCorpusPath;
            const contents = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(16 * 1024 * 1024));
            defer init.gpa.free(contents);
            try processFileTokens(init.gpa, &state, contents);
            continue;
        }
        try processToken(init.gpa, &state, arg);
    }

    if (state.cases == 0) {
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
    try stdout.print("fuzz corpus: mode={s} cases={d} accepted={d} rejected={d}\n", .{ state.modeLabel(), state.cases, state.accepted, state.rejected });
    try stdout.flush();
}

const Mode = enum { store, deflate, zlib, gzip };

const State = struct {
    mode: Mode = .store,
    saw_store: bool = false,
    saw_deflate: bool = false,
    saw_zlib: bool = false,
    saw_gzip: bool = false,
    cases: usize = 0,
    accepted: usize = 0,
    rejected: usize = 0,

    fn modeLabel(self: State) []const u8 {
        const mode_count = @as(usize, @intFromBool(self.saw_store)) +
            @as(usize, @intFromBool(self.saw_deflate)) +
            @as(usize, @intFromBool(self.saw_zlib)) +
            @as(usize, @intFromBool(self.saw_gzip));
        return if (mode_count > 1) "mixed" else if (self.saw_gzip) "gzip" else if (self.saw_zlib) "zlib" else if (self.saw_deflate) "deflate" else "store";
    }
};

fn processFileTokens(allocator: std.mem.Allocator, state: *State, contents: []const u8) !void {
    var lines = std.mem.splitScalar(u8, contents, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;
        var tokens = std.mem.tokenizeAny(u8, trimmed, " \t\r");
        while (tokens.next()) |token| try processToken(allocator, state, token);
    }
}

fn processToken(allocator: std.mem.Allocator, state: *State, arg: []const u8) !void {
    if (std.mem.eql(u8, arg, "--store")) {
        state.mode = .store;
        return;
    }
    if (std.mem.eql(u8, arg, "--deflate")) {
        state.mode = .deflate;
        return;
    }
    if (std.mem.eql(u8, arg, "--zlib")) {
        state.mode = .zlib;
        return;
    }
    if (std.mem.eql(u8, arg, "--gzip")) {
        state.mode = .gzip;
        return;
    }

    const bytes = try hexToOwnedBytes(allocator, arg);
    defer allocator.free(bytes);
    state.cases += 1;
    switch (state.mode) {
        .store => {
            state.saw_store = true;
            if (vort.store.parseHeader(bytes)) |_| {
                state.accepted += 1;
            } else |err| switch (err) {
                error.TruncatedFrame,
                error.InvalidMagic,
                error.UnsupportedVersion,
                error.CorruptFrame,
                => state.rejected += 1,
                else => return err,
            }
        },
        .deflate => {
            state.saw_deflate = true;
            if (vort.decodeRawDeflateAlloc(allocator, bytes)) |decoded| {
                defer allocator.free(decoded);
                state.accepted += 1;
            } else |err| switch (err) {
                error.TruncatedFrame,
                error.InvalidDeflateBlockType,
                error.StoredLengthMismatch,
                error.InvalidDynamicBlockHeader,
                error.InvalidHuffmanCode,
                error.InvalidMatch,
                error.CorruptFrame,
                error.TrailingData,
                => state.rejected += 1,
                else => return err,
            }
        },
        .zlib => {
            state.saw_zlib = true;
            if (vort.decodeZlibAlloc(allocator, bytes)) |decoded| {
                defer allocator.free(decoded);
                state.accepted += 1;
            } else |err| switch (err) {
                error.TruncatedFrame,
                error.InvalidDeflateBlockType,
                error.StoredLengthMismatch,
                error.InvalidDynamicBlockHeader,
                error.InvalidHuffmanCode,
                error.InvalidMatch,
                error.CorruptFrame,
                error.TrailingData,
                error.BadZlibHeader,
                error.ChecksumMismatch,
                error.SizeMismatch,
                => state.rejected += 1,
                else => return err,
            }
        },
        .gzip => {
            state.saw_gzip = true;
            if (vort.decodeGzipAlloc(allocator, bytes)) |decoded| {
                defer allocator.free(decoded);
                state.accepted += 1;
            } else |err| switch (err) {
                error.TruncatedFrame,
                error.InvalidDeflateBlockType,
                error.StoredLengthMismatch,
                error.InvalidDynamicBlockHeader,
                error.InvalidHuffmanCode,
                error.InvalidMatch,
                error.CorruptFrame,
                error.TrailingData,
                error.BadGzipHeader,
                error.ChecksumMismatch,
                error.SizeMismatch,
                => state.rejected += 1,
                else => return err,
            }
        },
    }
}

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
