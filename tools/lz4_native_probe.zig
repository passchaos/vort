const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [256]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const options = try parseOptions(init.gpa, &args);
    defer options.deinit(init.gpa);

    var cases = std.ArrayList(Case).empty;
    defer {
        for (cases.items) |case| {
            init.gpa.free(case.name);
            init.gpa.free(case.payload);
        }
        cases.deinit(init.gpa);
    }
    try addGeneratedCases(init.gpa, &cases);
    try addFileCases(init.io, init.gpa, &cases, options);

    var checked: usize = 0;
    for (cases.items) |case| {
        try checkFrameRoundTrips(init.gpa, case);
        try checkBlockRoundTrip(init.gpa, case);
        checked += 1;
    }
    try checkPrefixPreflight(init.gpa);
    checked += 1;
    try checkPrefixEncoder(init.gpa);
    checked += 1;
    try checkDictionaryFrame(init.gpa);
    checked += 1;

    try stdout.print("lz4_native_probe_ok cases={d}\n", .{checked});
    try stdout.flush();
}

const Case = struct {
    name: []const u8,
    payload: []u8,
};

const Options = struct {
    paths: std.ArrayList([]const u8) = .empty,
    dirs: std.ArrayList([]const u8) = .empty,
    limit: usize = 24 * 1024,
    max_files: usize = 8,

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
        for (self.paths.items) |path| allocator.free(path);
        for (self.dirs.items) |dir| allocator.free(dir);
        var paths = self.paths;
        paths.deinit(allocator);
        var dirs = self.dirs;
        dirs.deinit(allocator);
    }
};

fn parseOptions(allocator: std.mem.Allocator, args: *std.process.Args.Iterator) !Options {
    var options: Options = .{};
    errdefer options.deinit(allocator);
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--path")) {
            const path = args.next() orelse return error.MissingPath;
            try options.paths.append(allocator, try allocator.dupe(u8, path));
        } else if (std.mem.eql(u8, arg, "--dir")) {
            const dir = args.next() orelse return error.MissingPath;
            try options.dirs.append(allocator, try allocator.dupe(u8, dir));
        } else if (std.mem.eql(u8, arg, "--limit")) {
            const text = args.next() orelse return error.MissingLimit;
            options.limit = try std.fmt.parseInt(usize, text, 10);
        } else if (std.mem.eql(u8, arg, "--max-files")) {
            const text = args.next() orelse return error.MissingLimit;
            options.max_files = try std.fmt.parseInt(usize, text, 10);
        } else {
            return error.UnknownArgument;
        }
    }
    return options;
}

fn addGeneratedCases(allocator: std.mem.Allocator, cases: *std.ArrayList(Case)) !void {
    try addGeneratedCase(allocator, cases, "empty", "");
    try addGeneratedCase(allocator, cases, "tiny", "hello");
    try addGeneratedCase(allocator, cases, "repeated", "abcd" ** 256);
    try addGeneratedCase(allocator, cases, "json", "{\"key\":\"value\",\"array\":[1,2,3],\"text\":\"abcdefg\"}\n" ** 128);

    var rng = std.Random.DefaultPrng.init(0x4c5a34);
    try cases.append(allocator, .{ .name = try allocator.dupe(u8, "printable"), .payload = try randomFromAlphabet(allocator, &rng, 4096, printable_alphabet) });
    try cases.append(allocator, .{ .name = try allocator.dupe(u8, "dna"), .payload = try randomFromAlphabet(allocator, &rng, 8192, "ACGTN") });
    try cases.append(allocator, .{ .name = try allocator.dupe(u8, "linked-tail-copy"), .payload = try linkedTailCopyPayload(allocator, &rng) });
}

fn addGeneratedCase(allocator: std.mem.Allocator, cases: *std.ArrayList(Case), name: []const u8, payload: []const u8) !void {
    try cases.append(allocator, .{ .name = try allocator.dupe(u8, name), .payload = try allocator.dupe(u8, payload) });
}

fn addFileCases(io: std.Io, allocator: std.mem.Allocator, cases: *std.ArrayList(Case), options: Options) !void {
    for (options.paths.items) |path| {
        try addFileCase(io, allocator, cases, path, options.limit);
    }

    var discovered: usize = 0;
    for (options.dirs.items) |dir_path| {
        var dir = try std.Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true });
        defer dir.close(io);
        var iter = dir.iterate();
        while (try iter.next(io)) |entry| {
            if (entry.kind != .file) continue;
            if (options.max_files != 0 and discovered >= options.max_files) return;
            const path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir_path, entry.name });
            defer allocator.free(path);
            try addFileCase(io, allocator, cases, path, options.limit);
            discovered += 1;
        }
    }
}

fn addFileCase(io: std.Io, allocator: std.mem.Allocator, cases: *std.ArrayList(Case), path: []const u8, limit: usize) !void {
    const full_payload = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(128 * 1024 * 1024));
    const payload = if (limit != 0 and full_payload.len > limit) blk: {
        const truncated = try allocator.dupe(u8, full_payload[0..limit]);
        allocator.free(full_payload);
        break :blk truncated;
    } else full_payload;
    errdefer allocator.free(payload);
    try cases.append(allocator, .{ .name = try allocator.dupe(u8, path), .payload = payload });
}

const printable_alphabet =
    " !\"#$%&'()*+,-./0123456789:;<=>?@" ++
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~";

fn randomFromAlphabet(
    allocator: std.mem.Allocator,
    rng: *std.Random.DefaultPrng,
    len: usize,
    alphabet: []const u8,
) ![]u8 {
    const out = try allocator.alloc(u8, len);
    for (out) |*byte| byte.* = alphabet[rng.random().uintLessThan(usize, alphabet.len)];
    return out;
}

fn linkedTailCopyPayload(allocator: std.mem.Allocator, rng: *std.Random.DefaultPrng) ![]u8 {
    const first_block_len = 64 * 1024;
    const second_block_len = 4 * 1024;
    const out = try allocator.alloc(u8, first_block_len + second_block_len);
    rng.random().bytes(out[0..first_block_len]);
    @memcpy(out[first_block_len..], out[first_block_len - second_block_len .. first_block_len]);
    return out;
}

fn checkFrameRoundTrips(allocator: std.mem.Allocator, case: Case) !void {
    const lib_frame = try vort.lz4EncodeFrameAlloc(allocator, case.payload);
    defer allocator.free(lib_frame);
    const native_decoded = try vort.lz4DecodeNativeFrameAlloc(allocator, lib_frame);
    defer allocator.free(native_decoded);
    try expectPayload(case, native_decoded);

    const native_frame = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, case.payload, .{
        .content_checksum = true,
        .include_content_size = true,
        .block_checksum = true,
    });
    defer allocator.free(native_frame);
    const lib_decoded = try vort.lz4DecodeFrameAlloc(allocator, native_frame);
    defer allocator.free(lib_decoded);
    try expectPayload(case, lib_decoded);

    if (case.payload.len > 64 * 1024) {
        const linked_native_frame = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, case.payload, .{
            .content_checksum = true,
            .include_content_size = true,
            .block_checksum = true,
            .block_size_id = .max64kb,
            .block_mode = .linked,
        });
        defer allocator.free(linked_native_frame);
        const decoded_len = try vort.lz4DecodedFrameSize(linked_native_frame);
        if (decoded_len != case.payload.len) return error.Lz4ProbeSizeMismatch;
        const linked_decoded = try vort.lz4DecodeNativeFrameAlloc(allocator, linked_native_frame);
        defer allocator.free(linked_decoded);
        try expectPayload(case, linked_decoded);
    }
}

fn checkBlockRoundTrip(allocator: std.mem.Allocator, case: Case) !void {
    const block = try vort.lz4EncodeBlockAlloc(allocator, case.payload);
    defer allocator.free(block);
    const decoded_len = try vort.lz4DecodedBlockSize(block);
    if (decoded_len != case.payload.len) return error.Lz4ProbeSizeMismatch;
    const decoded = try vort.lz4DecodeBlockAlloc(allocator, block, case.payload.len);
    defer allocator.free(decoded);
    try expectPayload(case, decoded);
}

fn checkPrefixPreflight(allocator: std.mem.Allocator) !void {
    const prefix = "abcdefghijklmnop";
    const prefix_match = [_]u8{ 0x04, 4, 0 };
    if (vort.lz4DecodedBlockSize(&prefix_match)) |_| {
        return error.Lz4ProbeExpectedInvalidMatch;
    } else |err| switch (err) {
        error.InvalidMatch => {},
        else => return err,
    }
    if (try vort.lz4DecodedBlockSizeWithPrefix(&prefix_match, prefix) != 8) {
        return error.Lz4ProbeSizeMismatch;
    }
    if (try vort.lz4DecodedBlockSizeWithPrefixLimited(&prefix_match, prefix, 8) != 8) {
        return error.Lz4ProbeSizeMismatch;
    }
    if (vort.lz4DecodedBlockSizeWithPrefixLimited(&prefix_match, prefix, 7)) |_| {
        return error.Lz4ProbeExpectedOutputLimit;
    } else |err| switch (err) {
        error.OutputLimitExceeded => {},
        else => return err,
    }

    const decoded = try vort.lz4DecodeBlockWithPrefixAlloc(allocator, &prefix_match, 8, prefix);
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, "mnopmnop", decoded)) return error.Lz4ProbeMismatch;

    var into_buffer: [8]u8 = undefined;
    const written = try vort.lz4DecodeBlockWithPrefixIntoSlice(allocator, &prefix_match, &into_buffer, 8, prefix);
    if (written != into_buffer.len) return error.Lz4ProbeSizeMismatch;
    if (!std.mem.eql(u8, "mnopmnop", &into_buffer)) return error.Lz4ProbeMismatch;
    if (vort.lz4DecodeBlockWithPrefixIntoSlice(allocator, &prefix_match, into_buffer[0..7], 8, prefix)) |_| {
        return error.Lz4ProbeExpectedOutputLimit;
    } else |err| switch (err) {
        error.OutputTooSmall => {},
        else => return err,
    }
}

fn checkPrefixEncoder(allocator: std.mem.Allocator) !void {
    const prefix_len = 64 * 1024;
    const block_len = 4 * 1024;
    const prefix = try allocator.alloc(u8, prefix_len);
    defer allocator.free(prefix);
    const payload = try allocator.alloc(u8, block_len);
    defer allocator.free(payload);

    var state: u32 = 0x51ed_1234;
    for (prefix) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(payload, prefix[prefix.len - payload.len ..]);

    const encoded = try vort.lz4EncodeBlockWithPrefixAlloc(allocator, payload, prefix);
    defer allocator.free(encoded);
    if (encoded.len >= payload.len) return error.Lz4ProbeSizeMismatch;
    if (try vort.lz4DecodedBlockSizeWithPrefix(encoded, prefix) != payload.len) {
        return error.Lz4ProbeSizeMismatch;
    }

    const decoded = try vort.lz4DecodeBlockWithPrefixAlloc(allocator, encoded, payload.len, prefix);
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, payload, decoded)) return error.Lz4ProbeMismatch;

    const block_bound = try vort.lz4EncodedBlockBound(payload.len);
    const encoded_into = try allocator.alloc(u8, block_bound);
    defer allocator.free(encoded_into);
    const written = try vort.lz4EncodeBlockWithPrefixIntoSlice(allocator, payload, prefix, encoded_into);
    if (!std.mem.eql(u8, encoded, encoded_into[0..written])) return error.Lz4ProbeMismatch;
    if (vort.lz4EncodeBlockWithPrefixIntoSlice(allocator, payload, prefix, encoded_into[0 .. written - 1])) |_| {
        return error.Lz4ProbeExpectedOutputLimit;
    } else |err| switch (err) {
        error.OutputTooSmall => {},
        else => return err,
    }
}

fn checkDictionaryFrame(allocator: std.mem.Allocator) !void {
    const dict = vort.Lz4NativeDictionary.init(0x1234_abcd, "abcdefghijklmnop");
    const payload = "abcdefghijklmnop-tail";
    const encoded = try vort.lz4EncodeNativeFrameWithDictionaryAlloc(allocator, payload, .{
        .content_checksum = false,
        .block_checksum = true,
    }, dict);
    defer allocator.free(encoded);

    const header = try vort.lz4InspectNativeFrameHeader(encoded);
    if (header.dictionary_id != dict.id) return error.Lz4ProbeMismatch;
    if (vort.lz4DecodeNativeFrameAlloc(allocator, encoded)) |decoded_without_dict| {
        allocator.free(decoded_without_dict);
        return error.Lz4ProbeExpectedInvalidMatch;
    } else |err| switch (err) {
        error.InvalidMatch => {},
        else => return err,
    }

    const decoded = try vort.lz4DecodeNativeFrameAllocWithDictionary(allocator, encoded, dict);
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, payload, decoded)) return error.Lz4ProbeMismatch;
    if (try vort.lz4DecodedNativeFrameSizeWithDictionary(encoded, dict) != payload.len) return error.Lz4ProbeSizeMismatch;

    const second_payload = "abcdefghijklmnop-second";
    const second = try vort.lz4EncodeNativeFrameWithDictionaryAlloc(allocator, second_payload, .{
        .content_checksum = false,
        .block_checksum = true,
    }, dict);
    defer allocator.free(second);
    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(allocator);
    try stream.appendSlice(allocator, encoded);
    try stream.appendSlice(allocator, second);

    const concatenated = try vort.lz4DecodeNativeConcatenatedFrameAllocWithDictionary(allocator, stream.items, dict);
    defer allocator.free(concatenated);
    if (!std.mem.eql(u8, payload ++ second_payload, concatenated)) return error.Lz4ProbeMismatch;
    if (try vort.lz4DecodedNativeConcatenatedFrameSizeWithDictionary(stream.items, dict) != concatenated.len) {
        return error.Lz4ProbeSizeMismatch;
    }

    const first_block = try allocator.alloc(u8, 64 * 1024);
    defer allocator.free(first_block);
    @memset(first_block, 'x');
    const tail = "abcdefghijklmnop-tail-block";
    const multi_payload = try allocator.alloc(u8, first_block.len + tail.len);
    defer allocator.free(multi_payload);
    @memcpy(multi_payload[0..first_block.len], first_block);
    @memcpy(multi_payload[first_block.len..], tail);
    const multi = try vort.lz4EncodeNativeFrameWithDictionaryAlloc(allocator, multi_payload, .{
        .content_checksum = false,
        .block_checksum = true,
        .block_size_id = .max64kb,
        .block_mode = .independent,
    }, dict);
    defer allocator.free(multi);
    const multi_decoded = try vort.lz4DecodeNativeFrameAllocWithDictionary(allocator, multi, dict);
    defer allocator.free(multi_decoded);
    if (!std.mem.eql(u8, multi_payload, multi_decoded)) return error.Lz4ProbeMismatch;
}

fn expectPayload(case: Case, decoded: []const u8) !void {
    if (!std.mem.eql(u8, case.payload, decoded)) {
        std.debug.print(
            "lz4 probe mismatch case={s} expected_len={d} got_len={d} expected_crc={d} got_crc={d}\n",
            .{ case.name, case.payload.len, decoded.len, std.hash.Crc32.hash(case.payload), std.hash.Crc32.hash(decoded) },
        );
        return error.Lz4ProbeMismatch;
    }
}
