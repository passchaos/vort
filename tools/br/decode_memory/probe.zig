const std = @import("std");
const codec = @import("codec");
const br = codec.br;
const Ledger = @import("ledger.zig").Ledger;

const Mode = enum {
    owned,
    owned_exact,
    prefix,
    prefix_exact,
    chunks,
    prefix_chunks,
    append,
    append_spare,
    prefix_append,
    prefix_append_spare,
    chunks_append,
    prefix_chunks_append,
    into,
    prefix_into,
    chunks_into,
    prefix_chunks_into,
    size,
    prefix_size,
    chunks_size,
    prefix_chunks_size,
};
const modes = std.enums.values(Mode);
const ModeReport = struct {
    name: []const u8,
    default_peak_requested_bytes: usize,
    profiled_peak_requested_bytes: usize,
    exact_cap_successes: usize,
    exact_minus_one_refusals: usize,
    zero_heap: bool,
};
const Sample = struct {
    frame: []const u8,
    joined: []const u8,
    plain: []const u8,
    output: []u8,
    scratch: []u8,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const frame_path = args.next() orelse return error.MissingFrame;
    const plain_path = args.next() orelse return error.MissingPlain;
    const joined_path = args.next() orelse return error.MissingJoined;
    if (args.next() != null) return error.UnexpectedArgument;
    const frame = try read(init, frame_path);
    defer init.gpa.free(frame);
    const plain = try read(init, plain_path);
    defer init.gpa.free(plain);
    const joined = try read(init, joined_path);
    defer init.gpa.free(joined);
    try require(frame.len != 0 and joined.len > frame.len and std.mem.startsWith(u8, joined, frame));
    const output = try init.gpa.alloc(u8, plain.len + 7);
    defer init.gpa.free(output);
    const scratch = try init.gpa.alloc(u8, joined.len + 7);
    defer init.gpa.free(scratch);
    const sample: Sample = .{ .frame = frame, .joined = joined, .plain = plain, .output = output, .scratch = scratch };
    var reports: [modes.len]ModeReport = undefined;
    inline for (modes, 0..) |mode, index| {
        errdefer std.debug.print("Brotli reference mode: {s}\n", .{@tagName(mode)});
        const default_peak = try invoke(init.gpa, mode, sample, null, false, false);
        const peak = try invoke(init.gpa, mode, sample, null, true, false);
        try require(peak == try invoke(init.gpa, mode, sample, peak, true, false));
        try require(peak == try invoke(init.gpa, mode, sample, peak, false, false));
        if (peak != 0) {
            _ = try invoke(init.gpa, mode, sample, peak - 1, true, true);
            _ = try invoke(init.gpa, mode, sample, peak - 1, false, true);
        }
        reports[index] = .{
            .name = @tagName(mode),
            .default_peak_requested_bytes = default_peak,
            .profiled_peak_requested_bytes = peak,
            .exact_cap_successes = 2,
            .exact_minus_one_refusals = if (peak != 0) 2 else 0,
            .zero_heap = peak == 0,
        };
    }
    var tail_cap: usize = 0;
    for (reports) |report| tail_cap = @max(tail_cap, report.profiled_peak_requested_bytes);
    try strictTail(init.gpa, sample, tail_cap);
    const stored = try codec.brEncodeStoredStreamAlloc(init.gpa, plain);
    defer init.gpa.free(stored);
    const stored_hex = try hex(init.gpa, stored);
    defer init.gpa.free(stored_hex);
    const rle = if (plain.len >= 5 and std.mem.allEqual(u8, plain, plain[0])) try codec.brEncodeRleStreamAlloc(init.gpa, plain) else null;
    defer if (rle) |bytes| init.gpa.free(bytes);
    const rle_hex = if (rle) |bytes| try hex(init.gpa, bytes) else null;
    defer if (rle_hex) |bytes| init.gpa.free(bytes);
    var stdout_buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    try std.json.Stringify.value(.{
        .schema = "vort-brotli-decode-memory-probe-v1",
        .status = "ok",
        .pointer_bits = @bitSizeOf(usize),
        .target_arch = @tagName(@import("builtin").cpu.arch),
        .target_abi = @tagName(@import("builtin").abi),
        .build_mode = @tagName(@import("builtin").mode),
        .input_bytes = frame.len,
        .joined_bytes = joined.len,
        .input_read = frame.len,
        .output_written = plain.len,
        .strict_tail_error = "TrailingData",
        .strict_tail_checks = 8,
        .strict_tail_budget = tail_cap,
        .allocation_scope = "simultaneously live requested heap including append entry capacity and moving growth overlap",
        .guards_verified = true,
        .caller_state_preserved_on_refusal = true,
        .live_after_deinit = 0,
        .modes = &reports,
        .stored_wire_hex = stored_hex,
        .rle_wire_hex = rle_hex,
    }, .{}, &stdout.interface);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}

fn isPrefix(comptime mode: Mode) bool {
    return switch (mode) {
        .prefix, .prefix_exact, .prefix_chunks, .prefix_append, .prefix_append_spare, .prefix_chunks_append, .prefix_into, .prefix_chunks_into, .prefix_size, .prefix_chunks_size => true,
        else => false,
    };
}

fn isAppend(comptime mode: Mode) bool {
    return switch (mode) {
        .append, .append_spare, .prefix_append, .prefix_append_spare, .chunks_append, .prefix_chunks_append => true,
        else => false,
    };
}

noinline fn invoke(backing: std.mem.Allocator, comptime mode: Mode, sample: Sample, cap: ?usize, profiled: bool, denied: bool) !usize {
    var ledger: Ledger = .{ .backing = backing };
    const heap = ledger.allocator();
    const initial = "saved:";
    var out: std.ArrayList(u8) = .empty;
    if (isAppend(mode)) {
        const capacity = initial.len + if (mode == .append_spare or mode == .prefix_append_spare) sample.plain.len + 31 else 0;
        out = std.ArrayList(u8).fromOwnedSlice(try heap.alloc(u8, capacity));
        out.items.len = initial.len;
        @memcpy(out.items, initial);
    }
    const original_ptr = out.items.ptr;
    const original_capacity = out.capacity;
    const stream = if (isPrefix(mode)) sample.joined else sample.frame;
    const middle = @max(1, stream.len / 2);
    const chunks = [_][]const u8{ "", stream[0..1], "", stream[1..middle], stream[middle..], "" };
    @memset(sample.output, 0xa5);
    @memset(sample.scratch, 0xa5);
    var profile: br.DecodeMemoryProfile = .{};
    const options: br.DecodeOptions = .{ .max_total_working_memory = cap, .memory_profile = if (profiled) &profile else null };
    ledger.begin();
    const result = operate(mode, heap, sample, stream, &chunks, &out, options);
    if (denied) {
        if (result) |_| return error.ExpectedWorkingMemoryLimitExceeded else |err| try require(err == error.WorkingMemoryLimitExceeded);
        if (isAppend(mode)) try require(out.items.ptr == original_ptr and out.capacity == original_capacity and std.mem.eql(u8, out.items, initial));
    } else {
        const decoded = try result;
        try require(decoded.input_read == sample.frame.len and decoded.output_written == sample.plain.len);
    }
    if (profiled) {
        try require(profile.available and profile.limit == cap and profile.peak_requested_bytes == ledger.peak and profile.live_requested_bytes == 0);
    } else try require(!profile.available);
    if (cap) |limit| try require(ledger.peak <= limit);
    try require(std.mem.allEqual(u8, sample.output[sample.plain.len..], 0xa5));
    try require(std.mem.allEqual(u8, sample.scratch[stream.len..], 0xa5));
    const peak = ledger.peak;
    out.deinit(heap);
    try require(ledger.live == 0);
    if (mode == .into or mode == .prefix_into or mode == .chunks_into or mode == .prefix_chunks_into or mode == .size or mode == .prefix_size or mode == .chunks_size or mode == .prefix_chunks_size) try require(ledger.allocations == 0 and peak == 0);
    return peak;
}

fn operate(comptime mode: Mode, heap: std.mem.Allocator, sample: Sample, stream: []const u8, chunks: []const []const u8, out: *std.ArrayList(u8), options: br.DecodeOptions) !br.DecodePrefixResult {
    const scratch = sample.scratch[0..stream.len];
    if (mode == .owned or mode == .owned_exact or mode == .chunks) {
        const bytes = try switch (mode) {
            .owned => codec.brDecodeStreamAllocWithOptions(heap, stream, options),
            .owned_exact => codec.brDecodeStreamAllocExactSizeWithOptions(heap, stream, sample.plain.len, options),
            .chunks => codec.brDecodeStreamChunksAllocWithOptions(heap, chunks, scratch, options),
            else => unreachable,
        };
        defer heap.free(bytes);
        try require(std.mem.eql(u8, bytes, sample.plain));
        return .{ .input_read = stream.len, .output_written = bytes.len };
    }
    if (mode == .prefix or mode == .prefix_exact or mode == .prefix_chunks) {
        const decoded = try switch (mode) {
            .prefix => codec.brDecodeStreamPrefixAllocWithOptions(heap, stream, options),
            .prefix_exact => codec.brDecodeStreamPrefixAllocExactSizeWithOptions(heap, stream, sample.plain.len, options),
            .prefix_chunks => codec.brDecodeStreamPrefixChunksAllocWithOptions(heap, chunks, scratch, options),
            else => unreachable,
        };
        defer decoded.deinit(heap);
        try require(std.mem.eql(u8, decoded.bytes, sample.plain));
        return .{ .input_read = decoded.input_read, .output_written = decoded.output_written };
    }
    if (isAppend(mode)) {
        const decoded: br.DecodePrefixResult = switch (mode) {
            .append, .append_spare => .{ .input_read = stream.len, .output_written = try codec.brDecodeStreamAppendWithOptions(heap, out, stream, options) },
            .prefix_append, .prefix_append_spare => try codec.brDecodeStreamPrefixAppendWithOptions(heap, out, stream, options),
            .chunks_append => .{ .input_read = stream.len, .output_written = try codec.brDecodeStreamChunksAppendWithOptions(heap, out, chunks, scratch, options) },
            .prefix_chunks_append => try codec.brDecodeStreamPrefixChunksAppendWithOptions(heap, out, chunks, scratch, options),
            else => unreachable,
        };
        try require(std.mem.eql(u8, out.items[0.."saved:".len], "saved:") and std.mem.eql(u8, out.items["saved:".len..], sample.plain));
        return decoded;
    }
    const output = sample.output[0..sample.plain.len];
    if (mode == .into or mode == .prefix_into or mode == .chunks_into or mode == .prefix_chunks_into) {
        const decoded: br.DecodePrefixResult = switch (mode) {
            .into => .{ .input_read = stream.len, .output_written = try codec.brDecodeStreamIntoWithOptions(stream, output, options) },
            .prefix_into => try codec.brDecodeStreamPrefixIntoWithOptions(stream, output, options),
            .chunks_into => .{ .input_read = stream.len, .output_written = try codec.brDecodeStreamChunksIntoWithOptions(chunks, scratch, output, options) },
            .prefix_chunks_into => try codec.brDecodeStreamPrefixChunksIntoWithOptions(chunks, scratch, output, options),
            else => unreachable,
        };
        try require(std.mem.eql(u8, output, sample.plain));
        return decoded;
    }
    return switch (mode) {
        .size => .{ .input_read = stream.len, .output_written = @intCast(try codec.brDecodedStreamSizeWithOptions(stream, options)) },
        .chunks_size => .{ .input_read = stream.len, .output_written = @intCast(try codec.brDecodedStreamChunksSizeWithOptions(chunks, scratch, options)) },
        .prefix_size, .prefix_chunks_size => blk: {
            const decoded = if (mode == .prefix_size) try codec.brDecodedStreamPrefixSizeWithOptions(stream, options) else try codec.brDecodedStreamPrefixChunksSizeWithOptions(chunks, scratch, options);
            break :blk .{ .input_read = decoded.input_read, .output_written = @intCast(decoded.decoded_bytes) };
        },
        else => unreachable,
    };
}

fn strictTail(heap: std.mem.Allocator, sample: Sample, cap: usize) !void {
    const chunks = [_][]const u8{ "", sample.joined[0..1], sample.joined[1..], "" };
    const scratch = sample.scratch[0..sample.joined.len];
    for ([_]?usize{ null, cap }) |limit| {
        errdefer std.debug.print("Brotli strict tail budget: {any}\n", .{limit});
        const options: br.DecodeOptions = .{ .max_total_working_memory = limit };
        const owned = codec.brDecodeStreamAllocWithOptions(heap, sample.joined, options);
        if (owned) |bytes| {
            heap.free(bytes);
            return error.ExpectedTrailingData;
        } else |err| try require(err == error.TrailingData);
        const chunked = codec.brDecodeStreamChunksAllocWithOptions(heap, &chunks, scratch, options);
        if (chunked) |bytes| {
            heap.free(bytes);
            return error.ExpectedTrailingData;
        } else |err| try require(err == error.TrailingData);
        if (codec.brDecodeStreamIntoWithOptions(sample.joined, sample.output, options)) |_| return error.ExpectedTrailingData else |err| try require(err == error.TrailingData);
        if (codec.brDecodedStreamSizeWithOptions(sample.joined, options)) |_| return error.ExpectedTrailingData else |err| try require(err == error.TrailingData);
    }
}

fn hex(heap: std.mem.Allocator, bytes: []const u8) ![]u8 {
    const result = try heap.alloc(u8, bytes.len * 2);
    const digits = "0123456789abcdef";
    for (bytes, 0..) |byte, index| {
        result[index * 2] = digits[byte >> 4];
        result[index * 2 + 1] = digits[byte & 15];
    }
    return result;
}

fn read(init: std.process.Init, name: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, name, init.gpa, .limited(64 * 1024));
}

fn require(ok: bool) !void {
    if (!ok) return error.BrotliDecodeMemoryReferenceMismatch;
}
