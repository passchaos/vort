//! Single-pass, verified source publication contracts on the long-copy fixture.
const std = @import("std");
const h = @import("helpers.zig");
const t = std.testing;
const guard = 0xa5;

const Sequential = struct {
    const base: u64 = (1 << 32) + 37;
    const max_request = 31;

    bytes: []const u8,
    limit: usize = 0,
    next: usize = 0,
    calls: usize = 0,
    fault_at: ?usize = null,
    short_read: bool = false,
    invalid_request: bool = false,

    fn reset(self: *Sequential, limit: usize) void {
        self.* = .{ .bytes = self.bytes, .limit = limit };
    }

    fn readAt(raw: *anyopaque, offset: u64, dest: []u8) error{SourceReadFailed}!usize {
        const self: *Sequential = @ptrCast(@alignCast(raw));
        self.calls += 1;
        const start = self.next;
        // Refuse all noncontiguous requests, including any attempt to replay.
        if (offset != base + start or start >= self.limit or dest.len == 0 or
            dest.len > max_request or dest.len > self.limit - start)
        {
            self.invalid_request = true;
            return error.SourceReadFailed;
        }
        const fault = self.fault_at orelse self.limit;
        if (start >= fault) return error.SourceReadFailed;
        const len = @min(dest.len, 11, fault - start);
        self.short_read = self.short_read or len < dest.len;
        @memcpy(dest[0..len], self.bytes[start..][0..len]);
        self.next += len;
        return len;
    }
};

pub fn contracts(comptime B: type, wire: []u8, plain: []const u8, history: []u8) !void {
    const W = B.DirectChunkPreflightWorkspace;
    const workspace = try h.a.create(W);
    defer h.a.destroy(workspace);
    const joined = try std.mem.concat(h.a, u8, &.{ wire, "tail" });
    defer h.a.free(joined);
    var input: Sequential = .{ .bytes = joined };
    const tailed: W.SourceRange = .{ .offset = Sequential.base, .source = .{
        .context = &input,
        .len = Sequential.base + joined.len,
        .read_at = Sequential.readAt,
        .max_read_size = Sequential.max_request,
    } };
    var exact = tailed;
    exact.length = wire.len;

    const n = plain.len;
    const backing = try h.a.alloc(u8, 2 * n + 2);
    defer h.a.free(backing);
    const output = backing[1 .. n + 2];
    const stage = backing[n + 2 ..]; // Adjacent, but disjoint from output.
    var page_storage: [263]u8 = undefined;
    var page_len: usize = page_storage.len;
    while (wire.len % page_len == 0) page_len -= 1;
    const page = page_storage[0..page_len];
    const header = try h.a.alloc(u8, B.default_incremental_compressed_header_bytes + 1);
    defer h.a.free(header);
    var profile: B.DecodeMemoryProfile = .{};
    const opts: W.Options = .{ .compressed_header_scratch = header, .preflight = .{
        .history = history,
        .max_output_len = n,
        .expected_output_len = n,
        .decode = .{ .max_total_working_memory = 0, .memory_profile = &profile },
    } };

    const workspace_bytes = std.mem.asBytes(workspace);
    const protected = [_][]u8{ page, history, workspace_bytes, header };
    const guarded = protected ++ [_][]u8{backing};
    for (guarded) |bytes| @memset(bytes, guard);
    for (protected ++ [_][]u8{std.mem.asBytes(&profile)}) |span| {
        try t.expectError(error.InvalidBlockPlan, workspace.decodeVerifiedSourceInto(exact, output, page, span, opts));
        try t.expectError(error.InvalidBlockPlan, workspace.decodeVerifiedSourcePrefixInto(exact, span, page, stage, opts));
    }
    // Even an overlap with only the unused destination byte is invalid.
    try t.expectError(error.InvalidBlockPlan, workspace.decodeVerifiedSourceInto(exact, output, page, output[n..], opts));
    for ([_][]u8{ output, stage }) |span| {
        const raw = [_][]const u8{span[0..1]};
        var refused = opts;
        refused.preflight.decode.shared_dictionary.raw_prefixes = &raw;
        try t.expectError(error.InvalidBlockPlan, workspace.decodeVerifiedSourceInto(exact, output, page, stage, refused));
    }
    var truncated = exact;
    truncated.length = joined.len + 1;
    try t.expectError(error.RangeOutOfBounds, workspace.decodeVerifiedSourceInto(truncated, output, page, stage, opts));
    try t.expectEqual(@as(usize, 0), input.calls);
    for (guarded) |bytes| try t.expect(std.mem.allEqual(u8, bytes, guard));
    try t.expectEqual(B.DecodeMemoryProfile{}, profile);

    input.reset(wire.len);
    input.fault_at = wire.len - 1;
    try t.expectError(error.SourceReadFailed, workspace.decodeVerifiedSourceInto(exact, output, page, stage, opts));
    try t.expectEqual(wire.len - 1, input.next);
    try t.expect(input.short_read and !input.invalid_request);
    try t.expect(std.mem.allEqual(u8, output, guard));

    truncated.length = wire.len - 1;
    input.reset(wire.len - 1);
    try t.expectError(error.TruncatedFrame, workspace.decodeVerifiedSourceInto(truncated, output, page, stage, opts));
    input.reset(joined.len);
    try t.expectError(error.TrailingData, workspace.decodeVerifiedSourceInto(tailed, output, page, stage, opts));
    var refused = opts;
    refused.preflight.expected_output_len = n - 1;
    input.reset(joined.len);
    try t.expectError(error.SizeMismatch, workspace.decodeVerifiedSourcePrefixInto(tailed, output, page, stage, refused));
    refused.preflight.expected_output_len = null;
    for ([_]bool{ false, true }) |short_stage| {
        input.reset(wire.len);
        const dest = if (short_stage) output else output[0 .. n - 1];
        const scratch = if (short_stage) stage[0 .. n - 1] else stage;
        try t.expectError(error.OutputTooSmall, workspace.decodeVerifiedSourceInto(exact, dest, page, scratch, refused));
    }
    refused.preflight.max_output_len = n - 1;
    input.reset(wire.len);
    try t.expectError(error.OutputLimitExceeded, workspace.decodeVerifiedSourceInto(exact, output, page, stage, refused));
    // The fixture's final meta-block uses 183 bits; its high padding bit must be zero.
    input.reset(wire.len);
    joined[wire.len - 1] = wire[wire.len - 1] | 0x80;
    try t.expectError(error.CorruptFrame, workspace.decodeVerifiedSourceInto(exact, output, page, stage, opts));
    joined[wire.len - 1] = wire[wire.len - 1];
    try t.expect(std.mem.allEqual(u8, backing[0 .. n + 2], guard));

    input.reset(joined.len);
    profile.reset();
    const prefix = try workspace.decodeVerifiedSourcePrefixInto(tailed, output, page, stage, opts);
    try t.expectEqual(@as(u64, wire.len), prefix.input_read);
    try t.expectEqual(n, prefix.output_written);
    try t.expect(input.next >= wire.len and input.short_read and !input.invalid_request);
    try t.expectEqualSlices(u8, plain, output[0..n]);
    try t.expectEqual(@as(u8, guard), output[n]);
    try h.zeroProfile(profile, 0);

    input.reset(wire.len);
    profile.reset();
    @memset(output, guard);
    try t.expectEqual(n, try workspace.decodeVerifiedSourceInto(exact, output[0..n], page, stage, opts));
    try t.expectEqual(wire.len, input.next);
    try t.expect(input.short_read and !input.invalid_request);
    try t.expectEqualSlices(u8, plain, output[0..n]);
    try t.expectEqual(@as(u8, guard), backing[0]);
    try t.expectEqual(@as(u8, guard), output[n]);
    try h.zeroProfile(profile, 0);
}
