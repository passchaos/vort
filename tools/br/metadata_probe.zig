//! Public Brotli metadata QA probe. Files carry payloads; stdout carries JSON.
//! No compiler or reference library is launched by this executable.
const std = @import("std");
const builtin = @import("builtin");
const br = @import("br");

const Codec = enum { stored, planned };
const Api = enum { one_shot, chunks, reusable, incremental_options, incremental_prefix, incremental_mid };
const Config = struct { codec: Codec, api: Api, quality: u4, window_bits: u5, large_window: bool };
const Progress = struct {
    steps: usize = 0,
    input_read: usize = 0,
    output_written: usize = 0,
    zero_input_offers: usize = 0,
    zero_output_offers: usize = 0,
    need_input: usize = 0,
    need_output: usize = 0,
    metadata_acknowledged: bool = false,
    caller_guards_verified: bool = true,
    reusable_repeated: bool = false,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const action = args.next() orelse return error.MissingAction;
    if (std.mem.eql(u8, action, "decode")) {
        const large = try largeOption(args.next() orelse return error.MissingWindowMode);
        const path = args.next() orelse return error.MissingInput;
        const output_path = args.next() orelse return error.MissingOutput;
        if (args.next() != null) return error.TooManyArguments;
        const wire = try read(init, path);
        defer init.gpa.free(wire);
        var failure: ?[]const u8 = null;
        const output: ?[]u8 = br.decodeStreamAllocLimitedWithOptions(init.gpa, wire, 1024 * 1024, .{ .allow_large_window = large }) catch |err| blk: {
            failure = @errorName(err);
            break :blk null;
        };
        defer if (output) |bytes| init.gpa.free(bytes);
        if (output) |bytes| try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = bytes });
        try print(init, .{ .action = action, .@"error" = failure, .input_bytes = wire.len, .input_sha256 = try digest(init.gpa, wire), .output_bytes = if (output) |bytes| bytes.len else 0, .output_sha256 = if (output) |bytes| try digest(init.gpa, bytes) else null, .allow_large_window = large, .target = @tagName(builtin.cpu.arch), .target_cpu_model = builtin.cpu.model.name, .build_mode = @tagName(builtin.mode), .zig_version = builtin.zig_version_string });
        return;
    }
    if (!std.mem.eql(u8, action, "encode") and !std.mem.eql(u8, action, "reject")) return error.InvalidAction;
    const codec = std.meta.stringToEnum(Codec, args.next() orelse return error.MissingCodec) orelse return error.InvalidCodec;
    const api = std.meta.stringToEnum(Api, args.next() orelse return error.MissingApi) orelse return error.InvalidApi;
    const quality = try std.fmt.parseInt(u4, args.next() orelse return error.MissingQuality, 10);
    const window = try std.fmt.parseInt(u5, args.next() orelse return error.MissingWindow, 10);
    const large = try largeOption(args.next() orelse return error.MissingWindowMode);
    const input_path = args.next() orelse return error.MissingInput;
    const metadata_path = args.next() orelse return error.MissingMetadata;
    const output_path = args.next() orelse return error.MissingOutput;
    if (args.next() != null) return error.TooManyArguments;
    const config = Config{ .codec = codec, .api = api, .quality = quality, .window_bits = window, .large_window = large };
    const input = try read(init, input_path);
    defer init.gpa.free(input);
    const metadata = try read(init, metadata_path);
    defer init.gpa.free(metadata);
    const input_sha = try digest(init.gpa, input);
    const metadata_sha = try digest(init.gpa, metadata);
    var progress: Progress = .{};
    var failure: ?[]const u8 = null;
    var bound: ?usize = null;
    var summary: ?br.StreamSummary = null;
    var before_allocation = false;
    const wire: ?[]u8 = if (std.mem.eql(u8, action, "reject")) blk: {
        before_allocation = try rejectBeforeAllocation(init.gpa, input, metadata, config);
        failure = "InvalidBlockPlan";
        break :blk null;
    } else encode(init.gpa, input, metadata, config, &progress, &bound) catch |err| blk: {
        failure = @errorName(err);
        break :blk null;
    };
    defer if (wire) |bytes| init.gpa.free(bytes);
    var self_decode_verified = false;
    if (wire) |bytes| {
        const options: br.DecodeOptions = .{ .allow_large_window = large };
        const decoded = try br.decodeStreamAllocLimitedWithOptions(init.gpa, bytes, input.len, options);
        defer init.gpa.free(decoded);
        if (!std.mem.eql(u8, decoded, input)) return error.RoundTripMismatch;
        self_decode_verified = true;
        summary = try br.summarizeStreamAllocLimitedWithOptions(init.gpa, bytes, input.len, options);
        if (bytes.len > bound.?) return error.EncodedBoundExceeded;
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = bytes });
    }
    if (!std.mem.eql(u8, input_sha, try digest(init.gpa, input)) or !std.mem.eql(u8, metadata_sha, try digest(init.gpa, metadata))) return error.BorrowedInputChanged;
    try print(init, .{ .schema = "vort.br.metadata-probe.v1", .action = action, .config = config, .@"error" = failure, .input_bytes = input.len, .input_sha256 = input_sha, .metadata_bytes = metadata.len, .metadata_sha256 = metadata_sha, .wire_bytes = if (wire) |bytes| bytes.len else 0, .wire_sha256 = if (wire) |bytes| try digest(init.gpa, bytes) else null, .encoded_bound = bound, .bound_scope = if (isIncremental(api)) "public stored bound plus 16-byte conservative split/explicit-empty allowance" else "public matching one-shot/chunks bound", .max_metadata_meta_block_len = br.max_metadata_meta_block_len, .self_decode_verified = self_decode_verified, .borrowed_input_guards_verified = true, .rejected_before_allocation = before_allocation, .progress = progress, .summary = summary, .target = @tagName(builtin.cpu.arch), .target_cpu_model = builtin.cpu.model.name, .build_mode = @tagName(builtin.mode), .zig_version = builtin.zig_version_string });
}

fn stored(c: Config, metadata: []const u8) br.StoredStreamOptions {
    return .{ .window_bits = c.window_bits, .large_window = c.large_window, .metadata = metadata };
}
fn planned(c: Config, metadata: []const u8) br.PlannedEncodeOptions {
    return .{ .quality = c.quality, .window_bits = c.window_bits, .large_window = c.large_window, .metadata = metadata };
}
fn chunked(c: Config, metadata: []const u8) br.PlannedStreamChunksOptions {
    return .{ .quality = c.quality, .window_bits = c.window_bits, .large_window = c.large_window, .metadata = metadata };
}
fn isIncremental(api: Api) bool {
    return api == .incremental_options or api == .incremental_prefix or api == .incremental_mid;
}
fn pieces(input: []const u8) [4][]const u8 {
    return .{ input[0 .. input.len / 3], "", input[input.len / 3 .. input.len * 2 / 3], input[input.len * 2 / 3 ..] };
}
fn encode(allocator: std.mem.Allocator, input: []const u8, metadata: []const u8, c: Config, p: *Progress, bound: *?usize) ![]u8 {
    const chunks = pieces(input);
    if (isIncremental(c.api)) {
        bound.* = try std.math.add(usize, try br.encodedStoredStreamBoundWithOptions(input.len, stored(c, metadata)), 16);
        const prefix = if (c.api == .incremental_options) metadata else "";
        if (c.codec == .stored) {
            var encoder = br.IncrementalStoredStreamEncoder.initWithOptions(allocator, .{ .stream = stored(c, prefix), .block_len = 256, .max_input_len = input.len });
            defer encoder.deinit();
            return pump(allocator, input, metadata, c.api, &encoder, p);
        }
        var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(allocator, .{ .stream = chunked(c, prefix), .block_len = 256, .max_input_len = input.len });
        defer encoder.deinit();
        return pump(allocator, input, metadata, c.api, &encoder, p);
    }
    if (c.codec == .stored) {
        bound.* = if (c.api == .chunks) try br.encodedStoredStreamChunksBoundWithOptions(&chunks, stored(c, metadata)) else try br.encodedStoredStreamBoundWithOptions(input.len, stored(c, metadata));
        if (c.api == .one_shot) return br.encodeStoredStreamWithOptionsAlloc(allocator, input, stored(c, metadata));
        if (c.api == .chunks) return br.encodeStoredStreamChunksWithOptionsAlloc(allocator, &chunks, stored(c, metadata));
        var encoder = br.StoredStreamEncoder.init(allocator);
        defer encoder.deinit();
        const first = try encoder.encodeWithOptionsAlloc(input, stored(c, metadata));
        errdefer allocator.free(first);
        const second = try encoder.encodeWithOptionsAlloc(input, stored(c, metadata));
        defer allocator.free(second);
        if (!std.mem.eql(u8, first, second)) return error.ReusableWireChanged;
        p.reusable_repeated = true;
        return first;
    }
    bound.* = if (c.api == .chunks) try br.encodedPlannedStreamChunksBoundWithOptions(&chunks, chunked(c, metadata)) else try br.encodedPlannedStreamBoundWithOptions(input.len, planned(c, metadata));
    if (c.api == .one_shot) return br.encodePlannedStreamWithOptionsAlloc(allocator, input, planned(c, metadata));
    if (c.api == .chunks) return br.encodePlannedStreamChunksWithOptionsAlloc(allocator, &chunks, chunked(c, metadata));
    var encoder = br.PlannedStreamEncoder.init(allocator);
    defer encoder.deinit();
    const first = try encoder.encodeWithOptionsAlloc(allocator, input, planned(c, metadata));
    errdefer allocator.free(first);
    const second = try encoder.encodeWithOptionsAlloc(allocator, input, planned(c, metadata));
    defer allocator.free(second);
    if (!std.mem.eql(u8, first, second)) return error.ReusableWireChanged;
    p.reusable_repeated = true;
    return first;
}

fn pump(allocator: std.mem.Allocator, input: []const u8, metadata: []const u8, api: Api, encoder: anytype, p: *Progress) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    const insertion = if (api == .incremental_mid) input.len / 2 else 0;
    var inserted = api == .incremental_options;
    var inserting = false;
    var finishing = false;
    var offset: usize = 0;
    const input_sizes = [_]usize{ 0, 1, 17, 0, 127, 31 };
    const output_sizes = [_]usize{ 0, 1, 0, 7, 8192, 65536 };
    var guarded: [65552]u8 = undefined;
    const limit = input.len * 8 + metadata.len * 2 + 8192;
    while (p.steps < limit) : (p.steps += 1) {
        if (!inserted and !inserting and offset == insertion) {
            try encoder.writeMetadata(metadata);
            inserting = true;
        }
        if (offset == input.len and !finishing and !inserting) {
            try encoder.finish();
            finishing = true;
        }
        var end = offset + @min(input.len - offset, input_sizes[p.steps % input_sizes.len]);
        if (!inserted) end = @min(end, insertion);
        const offered = if (inserting or finishing) input[offset..offset] else input[offset..end];
        const capacity = output_sizes[p.steps % output_sizes.len];
        @memset(&guarded, 0xa5);
        if (offered.len == 0) p.zero_input_offers += 1;
        if (capacity == 0) p.zero_output_offers += 1;
        const result = try encoder.step(offered, guarded[8..][0..capacity]);
        const read_count = result.progress.input_read;
        const write_count = result.progress.output_written;
        if (read_count > offered.len or write_count > capacity) return error.InvalidProgress;
        for (guarded[0..8]) |byte| if (byte != 0xa5) return error.OutputGuardChanged;
        for (guarded[8 + write_count ..]) |byte| if (byte != 0xa5) return error.OutputGuardChanged;
        offset += read_count;
        p.input_read += read_count;
        p.output_written += write_count;
        try output.appendSlice(allocator, guarded[8..][0..write_count]);
        switch (result.status) {
            .need_output => p.need_output += 1,
            .need_input => {
                p.need_input += 1;
                if (inserting) {
                    inserting = false;
                    inserted = true;
                    p.metadata_acknowledged = true;
                }
            },
            .done => {
                const snapshot = encoder.snapshot();
                if (offset != input.len or snapshot.input_read != input.len or snapshot.output_written != output.items.len or snapshot.metadata_pending) return error.FinalProgressMismatch;
                p.steps += 1;
                return output.toOwnedSlice(allocator);
            },
        }
    }
    return error.IncrementalDidNotFinish;
}

fn rejectBeforeAllocation(backing: std.mem.Allocator, input: []const u8, metadata: []const u8, c: Config) !bool {
    if (metadata.len != br.max_metadata_meta_block_len + 1) return error.InvalidRejectFixture;
    var failing = std.testing.FailingAllocator.init(backing, .{ .fail_index = 0 });
    const allocator = failing.allocator();
    const result = rejectOperation(allocator, input, metadata, c);
    if (result) |_| return error.OversizeMetadataAccepted else |err| if (err != error.InvalidBlockPlan) return error.UnexpectedRejectError;
    if (failing.has_induced_failure or failing.allocations != 0) return error.MetadataValidatedAfterAllocation;
    return true;
}
fn rejectOperation(allocator: std.mem.Allocator, input: []const u8, metadata: []const u8, c: Config) !void {
    const chunks = pieces(input);
    if (isIncremental(c.api)) {
        if (c.codec == .stored) {
            var encoder = br.IncrementalStoredStreamEncoder.initWithOptions(allocator, .{ .stream = stored(c, if (c.api == .incremental_options) metadata else "") });
            defer encoder.deinit();
            if (c.api == .incremental_options) _ = try encoder.step("", &.{}) else try encoder.writeMetadata(metadata);
        } else {
            var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(allocator, .{ .stream = chunked(c, if (c.api == .incremental_options) metadata else "") });
            defer encoder.deinit();
            if (c.api == .incremental_options) _ = try encoder.step("", &.{}) else try encoder.writeMetadata(metadata);
        }
        return;
    }
    const bytes = if (c.codec == .stored) blk: {
        if (c.api == .one_shot) break :blk try br.encodeStoredStreamWithOptionsAlloc(allocator, input, stored(c, metadata));
        if (c.api == .chunks) break :blk try br.encodeStoredStreamChunksWithOptionsAlloc(allocator, &chunks, stored(c, metadata));
        var encoder = br.StoredStreamEncoder.init(allocator);
        defer encoder.deinit();
        break :blk try encoder.encodeWithOptionsAlloc(input, stored(c, metadata));
    } else blk: {
        if (c.api == .one_shot) break :blk try br.encodePlannedStreamWithOptionsAlloc(allocator, input, planned(c, metadata));
        if (c.api == .chunks) break :blk try br.encodePlannedStreamChunksWithOptionsAlloc(allocator, &chunks, chunked(c, metadata));
        var encoder = br.PlannedStreamEncoder.init(allocator);
        defer encoder.deinit();
        break :blk try encoder.encodeWithOptionsAlloc(allocator, input, planned(c, metadata));
    };
    allocator.free(bytes);
}
fn largeOption(value: []const u8) !bool {
    if (std.mem.eql(u8, value, "standard")) return false;
    if (std.mem.eql(u8, value, "large")) return true;
    return error.InvalidWindowMode;
}
fn read(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(32 * 1024 * 1024));
}
fn digest(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(data, &hash, .{});
    const hex = std.fmt.bytesToHex(hash, .lower);
    return allocator.dupe(u8, &hex);
}
fn print(init: std.process.Init, value: anytype) !void {
    const json = try std.json.Stringify.valueAlloc(init.gpa, value, .{});
    defer init.gpa.free(json);
    try std.Io.File.stdout().writeStreamingAll(init.io, json);
    try std.Io.File.stdout().writeStreamingAll(init.io, "\n");
}
