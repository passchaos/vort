const std = @import("std");
const codec = @import("codec");
const common = @import("common.zig");
const Workspace = codec.RawDeflateIncrementalFixedLiteralDecoder.SemanticWorkspace;

pub fn run(init: std.process.Init, config: common.Config, prefix: []const u8, tail_a: []const u8, tail_b: []const u8, dictionary: []const u8) !common.Receipt {
    return switch (config.family) {
        .raw => try fork(codec.RawDeflateIncrementalFixedLiteralDecoder, init, config, prefix, tail_a, tail_b, dictionary),
        .zlib => try fork(codec.ZlibIncrementalDecoder, init, config, prefix, tail_a, tail_b, dictionary),
        .gzip => try fork(codec.GzipIncrementalDecoder, init, config, prefix, tail_a, tail_b, dictionary),
        else => error.InvalidConfig,
    };
}

fn Owned(comptime Decoder: type) type {
    return struct {
        ptr: *Decoder,
        history: []u8,
        workspace: ?*Workspace,
        fn free(self: @This(), allocator: std.mem.Allocator) void {
            @memset(self.history, 0xd7);
            allocator.free(self.history);
            if (self.workspace) |workspace| {
                @memset(std.mem.asBytes(workspace), 0xd7);
                allocator.destroy(workspace);
            }
            @memset(std.mem.asBytes(self.ptr), 0xd7);
            allocator.destroy(self.ptr);
        }
    };
}

fn allocate(comptime Decoder: type, allocator: std.mem.Allocator, history_len: usize, semantic: bool) !Owned(Decoder) {
    const ptr = try allocator.create(Decoder);
    errdefer allocator.destroy(ptr);
    const history = try allocator.alloc(u8, history_len);
    errdefer allocator.free(history);
    @memset(history, 0);
    const workspace = if (semantic) try allocator.create(Workspace) else null;
    if (workspace) |value| @memset(std.mem.asBytes(value), 0);
    return .{ .ptr = ptr, .history = history, .workspace = workspace };
}

fn raw(decoder: anytype) if (@hasField(@TypeOf(decoder.*), "raw")) @TypeOf(&decoder.raw) else @TypeOf(decoder) {
    return if (@hasField(@TypeOf(decoder.*), "raw")) &decoder.raw else decoder;
}

fn initialize(comptime Decoder: type, owned: Owned(Decoder), dictionary: []const u8) !void {
    if (comptime Decoder == codec.RawDeflateIncrementalFixedLiteralDecoder) {
        owned.ptr.* = if (owned.history.len == 0)
            Decoder.init()
        else
            try Decoder.initWithDictionary(.{}, owned.history, dictionary);
    } else if (comptime Decoder == codec.ZlibIncrementalDecoder) {
        owned.ptr.* = try Decoder.initWithDictionary(.{}, owned.history, dictionary);
    } else {
        if (dictionary.len != 0) return error.InvalidConfig;
        owned.ptr.* = try Decoder.init(.{}, owned.history);
    }
    if (owned.workspace) |workspace| try raw(owned.ptr).attachSemanticWorkspace(workspace);
}

fn clone(comptime Decoder: type, allocator: std.mem.Allocator, source: Owned(Decoder)) !Owned(Decoder) {
    const destination = try allocate(Decoder, allocator, source.ptr.cloneHistoryLen(), source.workspace != null);
    errdefer destination.free(allocator);
    try source.ptr.cloneInto(destination.ptr, .{ .history = destination.history, .semantic_workspace = destination.workspace });
    if (!std.meta.eql(state(source.ptr), state(destination.ptr))) return error.CloneSnapshotMismatch;
    return destination;
}

fn state(decoder: anytype) common.Fork {
    const inner = raw(decoder);
    return .{
        .input_read = decoder.total_input,
        .output_written = decoder.total_output,
        .phase = @tagName(decoder.phase),
        .raw_phase = @tagName(inner.phase),
        .match_remaining = inner.match_remaining,
        .semantic_active = inner.phase == .fast_dynamic_block,
        .semantic_generated = inner.semantic_generated_end,
        .semantic_delivered = inner.semantic_delivered,
        .history_len = decoder.cloneHistoryLen(),
    };
}

fn fork(comptime Decoder: type, init: std.process.Init, config: common.Config, prefix: []const u8, tail_a: []const u8, tail_b: []const u8, dictionary: []const u8) !common.Receipt {
    if ((config.history_len != 0 and config.history_len != 32768 and config.history_len != 65536) or (config.semantic and config.history_len != 65536)) return error.InvalidConfig;
    const wire_a = try common.load(init, config.wire_a_path);
    defer init.gpa.free(wire_a);
    const wire_b = try common.load(init, config.wire_b_path);
    defer init.gpa.free(wire_b);
    if (config.fork_input > wire_a.len or config.fork_input > wire_b.len or
        !std.mem.eql(u8, wire_a[0..config.fork_input], wire_b[0..config.fork_input])) return error.InvalidForkPrefix;
    var ledger: common.Ledger = .{ .backing = init.gpa };
    const allocator = ledger.allocator();
    const source = try allocate(Decoder, allocator, config.history_len, config.semantic);
    var source_live = true;
    defer if (source_live) source.free(allocator);
    try initialize(Decoder, source, dictionary);
    var common_plain: std.ArrayList(u8) = .empty;
    defer common_plain.deinit(init.gpa);
    var consumed: usize = 0;
    var calls: usize = 0;
    while (consumed < config.fork_input and common_plain.items.len < config.fork_output_limit) {
        const capacity = @min(@as(usize, 65536), config.fork_output_limit - common_plain.items.len);
        const result = try step(source.ptr, wire_a[consumed..config.fork_input], capacity, init.gpa, &common_plain, &calls);
        consumed += result.progress.input_read;
        if (result.status == .need_output or result.status == .done) break;
    }
    const at_fork = state(source.ptr);
    if (at_fork.input_read != consumed or at_fork.output_written != common_plain.items.len) return error.InexactSourceProgress;
    const a = try clone(Decoder, allocator, source);
    var a_live = true;
    defer if (a_live) a.free(allocator);
    const b = try clone(Decoder, allocator, source);
    var b_live = true;
    defer if (b_live) b.free(allocator);
    source.free(allocator);
    source_live = false;
    const branch_a = try branch(a.ptr, init, config, wire_a, prefix, tail_a, consumed, common_plain.items, config.reset_path, &calls);
    a.ptr.reset();
    if (comptime Decoder == codec.RawDeflateIncrementalFixedLiteralDecoder) a.ptr.seedDictionary(dictionary);
    const reset_path = try std.fmt.allocPrint(init.gpa, "{s}.reset", .{config.reset_path});
    defer init.gpa.free(reset_path);
    _ = try branch(a.ptr, init, config, wire_a, prefix, tail_a, 0, &.{}, reset_path, &calls);
    a.free(allocator);
    a_live = false;
    const branch_b_path = try std.fmt.allocPrint(init.gpa, "{s}.b", .{config.reset_path});
    defer init.gpa.free(branch_b_path);
    const branch_b = try branch(b.ptr, init, config, wire_b, prefix, tail_b, consumed, common_plain.items, branch_b_path, &calls);
    b.free(allocator);
    b_live = false;
    if (ledger.live != 0) return error.CloneAllocationLeak;
    return .{ .fork = at_fork, .branches = .{ branch_a, branch_b }, .heap_live_after_free = ledger.live, .heap_peak = ledger.peak, .dictionary_ownership = if (dictionary.len == 0) "none" else if (Decoder == codec.RawDeflateIncrementalFixedLiteralDecoder) "dictionary bytes seeded into independent caller history; reset harness retains immutable dictionary" else "immutable configured dictionary shared by both clones until resets finish" };
}

fn step(decoder: anytype, input: []const u8, capacity: usize, allocator: std.mem.Allocator, plain: *std.ArrayList(u8), calls: *usize) !codec.StepResult {
    var guard: [65544]u8 = @splat(0xa5);
    const before = state(decoder);
    const result = try decoder.step(input, guard[4..][0..capacity]);
    calls.* += 1;
    if (calls.* > 100000 or result.progress.input_read > input.len or result.progress.output_written > capacity) return error.InvalidProgress;
    for (guard[0..4]) |byte| if (byte != 0xa5) return error.OutputGuard;
    for (guard[4 + capacity ..]) |byte| if (byte != 0xa5) return error.OutputGuard;
    const after = state(decoder);
    if (after.input_read != before.input_read + result.progress.input_read or after.output_written != before.output_written + result.progress.output_written) return error.InexactProgress;
    if (result.progress.input_read == 0 and result.progress.output_written == 0 and result.status != .done) return error.NoProgress;
    try common.append(allocator, plain, guard[4..][0..result.progress.output_written]);
    return result;
}

fn branch(decoder: anytype, init: std.process.Init, config: common.Config, wire: []const u8, prefix: []const u8, tail: []const u8, consumed: usize, shared: []const u8, path: []const u8, calls: *usize) !common.Branch {
    var plain: std.ArrayList(u8) = .empty;
    defer plain.deinit(init.gpa);
    try common.append(init.gpa, &plain, shared);
    var offset = consumed;
    while (decoder.phase != .done) {
        const result = try step(decoder, wire[offset..], if (config.semantic) 32768 else 113, init.gpa, &plain, calls);
        offset += result.progress.input_read;
    }
    try decoder.finish();
    if (offset != wire.len or decoder.total_input != wire.len or decoder.total_output != plain.items.len or
        plain.items.len != prefix.len + tail.len or !std.mem.eql(u8, plain.items[0..prefix.len], prefix) or
        !std.mem.eql(u8, plain.items[prefix.len..], tail)) return error.InexactDecodedBranch;
    try common.save(init, path, plain.items);
    return .{ .input_read = decoder.total_input, .output_written = decoder.total_output, .actual_input = wire.len, .actual_output = plain.items.len, .crc32 = std.hash.Crc32.hash(plain.items), .calls = calls.*, .eof = true };
}
