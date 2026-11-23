//! Standalone, non-timed public Brotli facade and requested-memory evidence.
const std = @import("std");
const builtin = @import("builtin");
const br = @import("vort_br");
const prefix = "probe-prefix\x00";
const marker: u8 = 0xa5;
const Api = enum { alloc, into, singleton_chunks_append, chunks_alloc, chunks_into, chunks_append };
const Kind = enum { empty, tiny, small, random, periodic, text, raw, dickens };
const Case = struct { name: []const u8, kind: Kind, len: usize };
const cases = [_]Case{
    .{ .name = "empty", .kind = .empty, .len = 0 },
    .{ .name = "tiny-1", .kind = .tiny, .len = 1 },
    .{ .name = "tiny-3", .kind = .tiny, .len = 3 },
    .{ .name = "small-255", .kind = .small, .len = 255 },
    .{ .name = "random-1024", .kind = .random, .len = 1024 },
    .{ .name = "random-8192", .kind = .random, .len = 8192 },
    .{ .name = "periodic-1024", .kind = .periodic, .len = 1024 },
    .{ .name = "periodic-8192", .kind = .periodic, .len = 8192 },
    .{ .name = "text-1024", .kind = .text, .len = 1024 },
    .{ .name = "text-8192", .kind = .text, .len = 8192 },
    .{ .name = "raw-255", .kind = .raw, .len = 255 },
    .{ .name = "raw-4096", .kind = .raw, .len = 4096 },
    .{ .name = "dickens-8192", .kind = .dickens, .len = 8192 },
};

// Independent requested-byte accounting. Declining resize/remap makes every
// growth overlap visible and reproducible, like the repository memory helper.
const Tracker = struct {
    live: usize = 0,
    peak: usize = 0,
    excluded: ?[*]u8 = null,
    fn allocator(self: *Tracker) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn alloc(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, address: usize) ?[*]u8 {
        const self: *Tracker = @ptrCast(@alignCast(raw));
        const result = std.heap.page_allocator.rawAlloc(len, alignment, address) orelse return null;
        self.live += len;
        self.peak = @max(self.peak, self.live);
        return result;
    }
    fn resize(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) bool {
        return false;
    }
    fn remap(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) ?[*]u8 {
        return null;
    }
    fn free(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, address: usize) void {
        const self: *Tracker = @ptrCast(@alignCast(raw));
        if (self.excluded == bytes.ptr) self.excluded = null else self.live -= bytes.len;
        std.heap.page_allocator.rawFree(bytes, alignment, address);
    }
};

const Run = struct {
    error_name: ?[]const u8 = null,
    wire: ?[]u8 = null,
    decoded_sha256: ?[64]u8 = null,
    roundtrip: bool = true,
    preservation: bool = true,
    profile: br.EncodeMemoryProfile = .{},
    backing_peak: ?usize = null,
    backing_final_live: ?usize = null,
    fn deinit(self: Run, allocator: std.mem.Allocator) void {
        if (self.wire) |bytes| allocator.free(bytes);
    }
};

fn sha(bytes: []const u8) [64]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return std.fmt.bytesToHex(digest, .lower);
}

fn untouched(bytes: []const u8) bool {
    for (bytes) |byte| if (byte != marker) return false;
    return true;
}

fn generate(output: []u8, kind: Kind, dictionary: []const u8) void {
    if (kind == .dickens) {
        @memcpy(output, @embedFile("dickens-8k.bin"));
        return;
    }
    const text = "Brotli recent match evidence preserves deterministic public wire and memory contracts.\n";
    const period = "abacabadabacaba0123456789";
    var random: u32 = 0x9e3779b9;
    for (output, 0..) |*byte, i| {
        random ^= random << 13;
        random ^= random >> 17;
        random ^= random << 5;
        byte.* = switch (kind) {
            .dickens => unreachable,
            .empty, .tiny, .small => @truncate(i *% 73 +% 17),
            .random => @truncate(random >> 16),
            .periodic => period[i % period.len],
            .text => text[i % text.len],
            .raw => dictionary[(i + 509) % dictionary.len],
        };
    }
}

fn observe(result: *Run, allocator: std.mem.Allocator, encoded: []const u8) !void {
    result.wire = try allocator.dupe(u8, encoded);
}

fn run(collector: std.mem.Allocator, input: []const u8, dictionary: br.SharedDictionary, quality: u4, api: Api, profiled: bool, cap: ?usize) !Run {
    var result: Run = .{};
    errdefer result.deinit(collector);
    var tracker: Tracker = .{};
    const a = tracker.allocator();
    const one: br.PlannedEncodeOptions = .{
        .quality = quality,
        .window_bits = 16,
        .command_state_max_input_kib = 8,
        .shared_dictionary = dictionary,
        .max_total_working_memory = cap,
        .memory_profile = if (profiled) &result.profile else null,
    };
    const chunks_options: br.PlannedStreamChunksOptions = .{
        .quality = quality,
        .window_bits = 16,
        .command_state_max_input_kib = 8,
        .shared_dictionary = dictionary,
        .max_total_working_memory = cap,
        .memory_profile = if (profiled) &result.profile else null,
    };
    const singleton = [_][]const u8{input};
    const cut = input.len / 3;
    const split = [_][]const u8{ "", input[0..cut], input[cut .. 2 * cut], "", input[2 * cut ..] };
    const chunks: []const []const u8 = if (api == .singleton_chunks_append) &singleton else &split;
    switch (api) {
        .alloc, .chunks_alloc => {
            const encoded = (if (api == .alloc)
                br.encodePlannedStreamWithOptionsAlloc(a, input, one)
            else
                br.encodePlannedStreamChunksWithOptionsAlloc(a, chunks, chunks_options)) catch |err| {
                result.error_name = @errorName(err);
                return finish(result, tracker, api);
            };
            defer a.free(encoded);
            try observe(&result, collector, encoded);
        },
        .into, .chunks_into => {
            const bound = if (api == .into)
                try br.encodedPlannedStreamBoundWithOptions(input.len, one)
            else
                try br.encodedPlannedStreamChunksBoundWithOptions(chunks, chunks_options);
            const storage = try collector.alloc(u8, bound + 2);
            defer collector.free(storage);
            @memset(storage, marker);
            const destination = storage[1 .. storage.len - 1];
            const written = (if (api == .into)
                br.encodePlannedStreamWithOptionsInto(input, destination, one)
            else
                br.encodePlannedStreamChunksWithOptionsInto(chunks, destination, chunks_options)) catch |err| {
                result.error_name = @errorName(err);
                result.preservation = untouched(storage);
                return finish(result, tracker, api);
            };
            result.preservation = storage[0] == marker and untouched(storage[written + 1 ..]);
            try observe(&result, collector, destination[0..written]);
        },
        .singleton_chunks_append, .chunks_append => {
            var output = std.ArrayList(u8).fromOwnedSlice(try a.dupe(u8, prefix));
            // A pre-existing caller allocation is outside the operation's cap.
            tracker.excluded = output.items.ptr;
            tracker.live = 0;
            tracker.peak = 0;
            const old_pointer = output.items.ptr;
            const appended = br.encodePlannedStreamChunksWithOptionsAppend(a, &output, chunks, chunks_options);
            result.preservation = output.items.len >= prefix.len and std.mem.eql(u8, prefix, output.items[0..prefix.len]);
            if (appended) |_| {
                try observe(&result, collector, output.items[prefix.len..]);
            } else |err| {
                result.error_name = @errorName(err);
                result.preservation = result.preservation and output.items.len == prefix.len and output.capacity == prefix.len and output.items.ptr == old_pointer;
            }
            output.deinit(a);
        },
    }
    result = finish(result, tracker, api);
    if (result.wire) |encoded| {
        const decoded = br.decodeStreamAllocExactSizeWithOptions(collector, encoded, input.len, .{ .shared_dictionary = dictionary }) catch |err| {
            result.error_name = @errorName(err);
            result.roundtrip = false;
            return result;
        };
        defer collector.free(decoded);
        result.decoded_sha256 = sha(decoded);
        result.roundtrip = std.mem.eql(u8, input, decoded);
    }
    return result;
}

fn finish(result: Run, tracker: Tracker, api: Api) Run {
    var observed = result;
    if (api != .into and api != .chunks_into) {
        observed.backing_peak = tracker.peak;
        observed.backing_final_live = tracker.live;
    }
    return observed;
}

fn equal(left: Run, right: Run) bool {
    if (left.wire) |first| if (right.wire) |second| return std.mem.eql(u8, first, second);
    return false;
}

fn valid(result: Run, profiled: bool, cap: ?usize, rejection: bool) bool {
    const status = if (rejection)
        if (result.error_name) |name| std.mem.eql(u8, name, "WorkingMemoryLimitExceeded") else false
    else
        result.error_name == null and result.wire != null and result.roundtrip;
    const ledger = if (result.backing_peak) |peak| (!profiled or peak == result.profile.peak_requested_bytes) and result.backing_final_live.? == 0 else true;
    return status and ledger and result.preservation and (!profiled or (result.profile.available and result.profile.live_requested_bytes == 0)) and (cap == null or result.profile.peak_requested_bytes <= cap.?);
}

fn writeRun(writer: *std.Io.Writer, result: Run, expected: Run) !void {
    const wire_sha = if (result.wire) |bytes| sha(bytes) else @as([64]u8, undefined);
    const decoded_sha = result.decoded_sha256;
    try std.json.Stringify.value(.{
        .error_name = result.error_name,
        .wire_bytes = if (result.wire) |bytes| @as(?usize, bytes.len) else null,
        .wire_sha256 = if (result.wire != null) @as(?[]const u8, &wire_sha) else null,
        .decoded_sha256 = if (decoded_sha) |*digest| @as(?[]const u8, digest) else null,
        .wire_equal_to_same_api_ordinary = equal(result, expected),
        .roundtrip = result.roundtrip,
        .sentinel_or_append_prefix_preserved = result.preservation,
        .profile = result.profile,
        .independent_backing_peak = result.backing_peak,
        .independent_backing_final_live = result.backing_final_live,
    }, .{}, writer);
}

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var label: []const u8 = "unspecified";
    var quick = false;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--label")) label = args.next() orelse return error.MissingLabel else if (std.mem.eql(u8, arg, "--quick")) quick = true else return error.UnknownArgument;
    }
    var dictionary_bytes: [2048]u8 = undefined;
    generate(&dictionary_bytes, .random, "");
    const raw_prefixes = [_][]const u8{ dictionary_bytes[0..701], "", dictionary_bytes[701..] };
    var json = std.Io.Writer.Allocating.init(init.gpa);
    defer json.deinit();
    try json.writer.writeAll("{\"schema\":\"vort.brotli.full-api-evidence.v1\",\"measurement\":\"non_timed_requested_heap\",\"label\":");
    try std.json.Stringify.value(label, .{}, &json.writer);
    try json.writer.print(",\"zig_version\":\"{s}\",\"optimize\":\"{s}\",\"window_bits\":16,\"command_state_max_input_kib\":8,\"mode\":\"generic\",\"hq\":null,\"force_moving_growth\":true,\"append_api\":\"encodePlannedStreamChunksWithOptionsAppend\",\"cross_facade_identity\":\"observed_only; chunk segmentation may affect wire\",\"into_backing_peak\":null,\"raw_dictionary_sha256\":\"{s}\",\"rows\":[", .{ builtin.zig_version_string, @tagName(builtin.mode), sha(&dictionary_bytes) });
    var row_count: usize = 0;
    var failures: usize = 0;
    for ([_]u4{ 10, 11 }) |quality| for (cases) |case| {
        if (quick and case.len > 255) continue;
        const input = try init.gpa.alloc(u8, case.len);
        defer init.gpa.free(input);
        generate(input, case.kind, &dictionary_bytes);
        const dictionary: br.SharedDictionary = if (case.kind == .raw) .{ .raw_prefixes = &raw_prefixes } else .{};
        const reference = try run(init.gpa, input, dictionary, quality, .alloc, false, null);
        defer reference.deinit(init.gpa);
        if (row_count != 0) try json.writer.writeByte(',');
        row_count += 1;
        try json.writer.print("{{\"case\":\"{s}\",\"quality\":{d},\"input_bytes\":{d},\"input_sha256\":\"{s}\",\"raw_dictionary_bytes\":{d},\"apis\":[", .{ case.name, quality, input.len, sha(input), try dictionary.totalSize() });
        for (std.enums.values(Api), 0..) |api, api_index| {
            errdefer std.debug.print("probe failed case={s} quality={d} api={s}\n", .{ case.name, quality, @tagName(api) });
            const ordinary = try run(init.gpa, input, dictionary, quality, api, false, null);
            defer ordinary.deinit(init.gpa);
            const measured = try run(init.gpa, input, dictionary, quality, api, true, null);
            defer measured.deinit(init.gpa);
            const peak = measured.profile.peak_requested_bytes;
            if (peak == 0) return error.MissingMemoryPeak;
            const exact = try run(init.gpa, input, dictionary, quality, api, true, peak);
            defer exact.deinit(init.gpa);
            const below = try run(init.gpa, input, dictionary, quality, api, true, peak - 1);
            defer below.deinit(init.gpa);
            const ok = valid(ordinary, false, null, false) and valid(measured, true, null, false) and valid(exact, true, peak, false) and valid(below, true, peak - 1, true) and equal(ordinary, measured) and equal(ordinary, exact);
            failures += @intFromBool(!ok);
            if (api_index != 0) try json.writer.writeByte(',');
            try json.writer.print("{{\"api\":\"{s}\",\"observed_equal_to_complete_alloc\":{s},\"contract_ok\":{s},\"ordinary\":", .{ @tagName(api), if (equal(ordinary, reference)) "true" else "false", if (ok) "true" else "false" });
            try writeRun(&json.writer, ordinary, ordinary);
            try json.writer.writeAll(",\"profiled\":");
            try writeRun(&json.writer, measured, ordinary);
            try json.writer.writeAll(",\"exact_cap\":");
            try writeRun(&json.writer, exact, ordinary);
            try json.writer.writeAll(",\"cap_minus_one\":");
            try writeRun(&json.writer, below, ordinary);
            try json.writer.writeByte('}');
        }
        try json.writer.writeAll("]}");
    };
    try json.writer.print("],\"row_count\":{d},\"contract_failures\":{d}}}\n", .{ row_count, failures });
    try std.Io.File.stdout().writeStreamingAll(init.io, json.written());
    if (failures != 0) return error.ProbeContractFailure;
}
