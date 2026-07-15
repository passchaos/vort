const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var state = State{};
    defer state.deinit(init.gpa);

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

const Outcome = enum { accepted, rejected };

const Expected = enum {
    accept,
    reject,

    fn matches(self: Expected, outcome: Outcome) bool {
        return switch (self) {
            .accept => outcome == .accepted,
            .reject => outcome == .rejected,
        };
    }
};

const State = struct {
    mode: Mode = .store,
    // Expected outcomes are sticky on purpose: corpus files often group many
    // related samples under one directive, while inline comments can still set
    // the expectation next to the sample that first needs it.
    expected: ?Expected = null,
    dictionary: ?[]u8 = null,
    max_output_len: ?usize = null,
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

    fn recordOutcome(self: *State, outcome: Outcome) !void {
        self.cases += 1;
        switch (outcome) {
            .accepted => self.accepted += 1,
            .rejected => self.rejected += 1,
        }
        if (self.expected) |expected| {
            if (!expected.matches(outcome)) {
                return switch (outcome) {
                    .accepted => error.UnexpectedAccept,
                    .rejected => error.UnexpectedReject,
                };
            }
        }
    }

    fn setDictionary(self: *State, allocator: std.mem.Allocator, bytes: []const u8) !void {
        const owned = try allocator.dupe(u8, bytes);
        errdefer allocator.free(owned);
        self.clearDictionary(allocator);
        self.dictionary = owned;
    }

    fn clearDictionary(self: *State, allocator: std.mem.Allocator) void {
        if (self.dictionary) |dictionary| {
            allocator.free(dictionary);
            self.dictionary = null;
        }
    }

    fn deinit(self: *State, allocator: std.mem.Allocator) void {
        self.clearDictionary(allocator);
    }
};

fn processFileTokens(allocator: std.mem.Allocator, state: *State, contents: []const u8) !void {
    var lines = std.mem.splitScalar(u8, contents, '\n');
    while (lines.next()) |line| {
        // Treat '#' as an inline comment delimiter, but still scan the comment
        // for lightweight directives such as "# expect: reject". This keeps
        // corpus files friendly to reducers and code review: each sample stays
        // a plain hex token with optional human-readable expectations.
        const hash_index = std.mem.indexOfScalar(u8, line, '#');
        const sample_part = if (hash_index) |index| line[0..index] else line;
        if (hash_index) |index| try processCommentDirective(state, line[index + 1 ..]);

        const trimmed = std.mem.trim(u8, sample_part, " \t\r");
        if (trimmed.len == 0) continue;
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
    if (std.mem.eql(u8, arg, "--dict-clear")) {
        state.clearDictionary(allocator);
        return;
    }
    if (std.mem.eql(u8, arg, "--limit-clear")) {
        state.max_output_len = null;
        return;
    }
    const limit_prefix = "--limit=";
    if (std.mem.startsWith(u8, arg, limit_prefix)) {
        state.max_output_len = try std.fmt.parseInt(usize, arg[limit_prefix.len..], 10);
        return;
    }
    const dict_prefix = "--dict=";
    if (std.mem.startsWith(u8, arg, dict_prefix)) {
        try state.setDictionary(allocator, arg[dict_prefix.len..]);
        return;
    }
    const dict_hex_prefix = "--dict-hex=";
    if (std.mem.startsWith(u8, arg, dict_hex_prefix)) {
        const dictionary = try hexToOwnedBytes(allocator, arg[dict_hex_prefix.len..]);
        defer allocator.free(dictionary);
        try state.setDictionary(allocator, dictionary);
        return;
    }
    if (std.mem.eql(u8, arg, "--expect-accept")) {
        state.expected = .accept;
        return;
    }
    if (std.mem.eql(u8, arg, "--expect-reject")) {
        state.expected = .reject;
        return;
    }
    if (std.mem.eql(u8, arg, "--expect-any")) {
        state.expected = null;
        return;
    }
    const expect_prefix = "--expect=";
    if (std.mem.startsWith(u8, arg, expect_prefix)) {
        state.expected = try parseExpected(arg[expect_prefix.len..]);
        return;
    }

    const bytes = try hexToOwnedBytes(allocator, arg);
    defer allocator.free(bytes);
    switch (state.mode) {
        .store => {
            state.saw_store = true;
            const outcome: Outcome = if (vort.store.parseHeader(bytes)) |_| .accepted else |err| switch (err) {
                error.TruncatedFrame,
                error.InvalidMagic,
                error.UnsupportedVersion,
                error.CorruptFrame,
                => .rejected,
                else => return err,
            };
            try state.recordOutcome(outcome);
        },
        .deflate => {
            state.saw_deflate = true;
            const outcome: Outcome = if (decodeRawDeflateSample(allocator, state.dictionary, state.max_output_len, bytes)) |decoded| result: {
                defer allocator.free(decoded);
                break :result .accepted;
            } else |err| switch (err) {
                error.TruncatedFrame,
                error.InvalidDeflateBlockType,
                error.StoredLengthMismatch,
                error.InvalidDynamicBlockHeader,
                error.InvalidHuffmanCode,
                error.InvalidMatch,
                error.CorruptFrame,
                error.TrailingData,
                error.OutputLimitExceeded,
                => .rejected,
                else => return err,
            };
            try state.recordOutcome(outcome);
        },
        .zlib => {
            state.saw_zlib = true;
            const outcome: Outcome = if (decodeZlibSample(allocator, state.dictionary, state.max_output_len, bytes)) |decoded| result: {
                defer allocator.free(decoded);
                break :result .accepted;
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
                error.NeedDictionary,
                error.ChecksumMismatch,
                error.SizeMismatch,
                error.OutputLimitExceeded,
                => .rejected,
                else => return err,
            };
            try state.recordOutcome(outcome);
        },
        .gzip => {
            state.saw_gzip = true;
            const outcome: Outcome = if (decodeGzipSample(allocator, state.max_output_len, bytes)) |decoded| result: {
                defer allocator.free(decoded);
                break :result .accepted;
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
                error.OutputLimitExceeded,
                => .rejected,
                else => return err,
            };
            try state.recordOutcome(outcome);
        },
    }
}

fn decodeRawDeflateSample(allocator: std.mem.Allocator, dictionary: ?[]const u8, max_output_len: ?usize, bytes: []const u8) ![]u8 {
    if (dictionary) |dict| {
        if (max_output_len) |limit| return vort.decodeRawDeflateAllocWithDictionaryLimited(allocator, bytes, dict, limit);
        return vort.decodeRawDeflateAllocWithDictionary(allocator, bytes, dict);
    }
    if (max_output_len) |limit| return vort.decodeRawDeflateAllocLimited(allocator, bytes, limit);
    return vort.decodeRawDeflateAlloc(allocator, bytes);
}

fn decodeZlibSample(allocator: std.mem.Allocator, dictionary: ?[]const u8, max_output_len: ?usize, bytes: []const u8) ![]u8 {
    if (dictionary) |dict| {
        if (max_output_len) |limit| return vort.decodeZlibAllocWithDictionaryLimited(allocator, bytes, dict, limit);
        return vort.decodeZlibAllocWithDictionary(allocator, bytes, dict);
    }
    if (max_output_len) |limit| return vort.decodeZlibAllocLimited(allocator, bytes, limit);
    return vort.decodeZlibAlloc(allocator, bytes);
}

fn decodeGzipSample(allocator: std.mem.Allocator, max_output_len: ?usize, bytes: []const u8) ![]u8 {
    if (max_output_len) |limit| return vort.decodeGzipConcatenatedAllocLimited(allocator, bytes, limit);
    return vort.decodeGzipConcatenatedAlloc(allocator, bytes);
}

fn processCommentDirective(state: *State, comment: []const u8) !void {
    const trimmed = std.mem.trim(u8, comment, " \t\r");
    const expect_prefix = "expect:";
    if (std.mem.startsWith(u8, trimmed, expect_prefix)) {
        state.expected = try parseExpected(trimmed[expect_prefix.len..]);
    }
}

fn parseExpected(value: []const u8) !?Expected {
    const trimmed = std.mem.trim(u8, value, " \t\r");
    if (std.mem.eql(u8, trimmed, "accept") or std.mem.eql(u8, trimmed, "accepted")) return .accept;
    if (std.mem.eql(u8, trimmed, "reject") or std.mem.eql(u8, trimmed, "rejected")) return .reject;
    if (std.mem.eql(u8, trimmed, "any") or std.mem.eql(u8, trimmed, "none")) return null;
    return error.InvalidExpectedOutcome;
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
