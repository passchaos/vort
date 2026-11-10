//! Policy dispatch stays at operation boundaries. The existing decoders receive
//! the ledger allocator and forwarded format options; symbol loops are unchanged.
const std = @import("std");
const budget = @import("budget.zig");
const alias = @import("alias.zig");

pub fn ownedPrefix(comptime Codec: type, caller: std.mem.Allocator, stream: []const u8, max_output_len: usize, options: Codec.DecodeOptions) Codec.Error!Codec.DecodedPrefix {
    noHeapForCaller(caller, options);
    const empty = try Codec.preflight(stream, options, max_output_len);
    if (empty and !budget.isTracked(caller)) {
        return Codec.decodeStreamPrefixAllocLimitedWithOptions(caller, stream, max_output_len, budget.forward(options));
    }
    var entry = try budget.Entry.init(caller, options);
    defer entry.deinit();
    const decoded = Codec.decodeStreamPrefixAllocLimitedWithOptions(entry.allocator(), stream, max_output_len, entry.forward(options)) catch |err|
        return @errorCast(entry.mapError(err));
    errdefer decoded.deinit(entry.allocator());
    try entry.releaseOwned(decoded.bytes.len);
    return decoded;
}

pub fn ownedExact(comptime Codec: type, comptime prefix: bool, caller: std.mem.Allocator, stream: []const u8, expected_output_len: usize, options: Codec.DecodeOptions) Codec.Error!if (prefix) Codec.DecodedPrefix else []u8 {
    noHeapForCaller(caller, options);
    _ = try Codec.preflight(stream, options, std.math.maxInt(Codec.Counter));
    if (expected_output_len == 0 and !budget.isTracked(caller)) {
        return if (prefix)
            Codec.decodeStreamPrefixAllocExactSizeWithOptions(caller, stream, expected_output_len, budget.forward(options))
        else
            Codec.decodeStreamAllocExactSizeWithOptions(caller, stream, expected_output_len, budget.forward(options));
    }
    var entry = try budget.Entry.init(caller, options);
    defer entry.deinit();
    const decoded = (if (prefix)
        Codec.decodeStreamPrefixAllocExactSizeWithOptions(entry.allocator(), stream, expected_output_len, entry.forward(options))
    else
        Codec.decodeStreamAllocExactSizeWithOptions(entry.allocator(), stream, expected_output_len, entry.forward(options))) catch |err|
        return @errorCast(entry.mapError(err));
    errdefer if (prefix) decoded.deinit(entry.allocator()) else entry.allocator().free(decoded);
    try entry.releaseOwned(if (prefix) decoded.bytes.len else decoded.len);
    return decoded;
}

/// Existing capacity is charged before control/staging. The original append
/// implementation owns publication and rollback; the scope transfers capacity
/// back on success and error, including moving-growth overlap in the ledger.
pub fn appendNeedsProtection(out: *const std.ArrayList(u8), stream: []const u8, options: anytype) bool {
    return alias.needed(out.allocatedSlice(), stream, options.shared_dictionary);
}

pub fn append(comptime Codec: type, comptime prefix: bool, comptime exact: bool, caller: std.mem.Allocator, out: *std.ArrayList(u8), stream: []const u8, output_len: usize, options: Codec.DecodeOptions) Codec.Error!if (prefix) Codec.DecodePrefixResult else usize {
    noHeapForCaller(caller, options);
    _ = try Codec.preflight(stream, options, if (exact) std.math.maxInt(Codec.Counter) else output_len);
    var diagnostics: Codec.StreamSummaryDiagnostics = .{};
    const preflighted = if (!prefix and !exact)
        try Codec.fixedSummary(stream, output_len, budget.forward(options), &diagnostics)
    else
        null;
    var entry = try budget.Entry.initExisting(caller, options, out.capacity);
    defer entry.deinit();
    var publication = try budget.AppendScope.initCharged(entry.lease, caller, out);
    defer publication.deinit();
    var inner = entry.forward(options);
    // Prefix append owns decoded staging before growth. Full append snapshots
    // overlapping input and dictionary backing before destination relocation.
    var protected: ?alias.Protected = if (!prefix)
        alias.protect(entry.allocator(), out.allocatedSlice(), stream, options.shared_dictionary) catch |err| return @errorCast(entry.mapError(err))
    else
        null;
    defer if (protected) |*snapshot| snapshot.deinit();
    const source = if (protected) |*snapshot| snapshot.source else stream;
    if (protected) |*snapshot| inner.shared_dictionary = snapshot.dictionary();
    if (preflighted) |checked| return Codec.appendPreflighted(entry.allocator(), out, source, checked.decoded_bytes, inner) catch |err|
        @errorCast(entry.mapError(err));
    return (if (prefix and exact)
        Codec.decodeStreamPrefixAppendExactSizeWithOptions(entry.allocator(), out, source, output_len, inner)
    else if (prefix)
        Codec.decodeStreamPrefixAppendLimitedWithOptions(entry.allocator(), out, source, output_len, inner)
    else if (exact)
        Codec.decodeStreamAppendExactSizeWithOptions(entry.allocator(), out, source, output_len, inner)
    else
        Codec.decodeStreamAppendLimitedWithOptions(entry.allocator(), out, source, output_len, inner)) catch |err|
        @errorCast(entry.mapError(err));
}

pub fn summary(comptime Codec: type, caller: std.mem.Allocator, stream: []const u8, max_output_len: Codec.Counter, options: Codec.DecodeOptions, diagnostics: *Codec.StreamSummaryDiagnostics) Codec.Error!Codec.StreamSummary {
    noHeapForCaller(caller, options);
    // Fixed history and all entropy tables use automatic storage. Admit the
    // real heap fallback only when context replay actually exhausts that ring;
    // a zero-heap summary accepts cap=0 without metadata allocation, and scalar
    // malformed errors retain the original diagnostics before heap admission.
    const fixed = try Codec.fixedSummary(stream, max_output_len, budget.forward(options), diagnostics);
    if (fixed) |result| {
        if (budget.isTracked(caller)) {
            var inherited = try budget.Entry.init(caller, options);
            defer inherited.deinit();
        }
        return result;
    }
    var entry = try budget.Entry.init(caller, options);
    defer entry.deinit();
    return Codec.summaryAfterFixed(entry.allocator(), stream, max_output_len, entry.forward(options), diagnostics) catch |err|
        @errorCast(entry.mapError(err));
}

fn noHeapForCaller(caller: std.mem.Allocator, options: anytype) void {
    // Inherited options/profile refer to the outer ledger. A zero-allocation
    // child must neither clear its live bytes nor rebind its observation.
    if (!budget.isTracked(caller)) budget.noHeap(options);
}
