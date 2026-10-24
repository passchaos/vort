const std = @import("std");
const br = @import("vort").br;
const Ledger = @import("stored_memory_ledger.zig").Ledger;

const Config = struct {
    api: []const u8 = "alloc",
    scenario: []const u8 = "normal",
    window_bits: u5 = 16,
    large_window: bool = false,
    metadata: []const u8 = "",
    stream_metadata: []const u8 = "",
    flush_at: ?usize = null,
    max_total_working_memory: ?usize = null,
    profile_enabled: bool = true,
    input_chunk: usize = 11,
    output_chunk: usize = 17,
    block_len: usize = 64,
    caller_capacity: ?usize = null,
    failure_after: ?usize = null,
    cycle: []const u8 = "none",
};
const Report = struct {
    @"error": ?[]const u8 = null,
    input_bytes: usize = 0,
    output_bytes: usize = 0,
    total_profile: br.EncodeMemoryProfile = .{},
    profile_after_operation: br.EncodeMemoryProfile = .{},
    independent_peak_requested_bytes: usize = 0,
    independent_live_after_deinit: usize = 0,
    allocation_calls: usize = 0,
    caller_setup_allocation_calls: usize = 0,
    encoder_allocation_calls: usize = 0,
    resize_calls: usize = 0,
    remap_calls: usize = 0,
    free_calls: usize = 0,
    forced_failures: usize = 0,
    caller_state_preserved_on_error: bool = false,
    guards_verified: bool = false,
    cycle_verified: bool = false,
    retry_verified: bool = false,
    retry_error: ?[]const u8 = null,
    steps: usize = 0,
    metadata_calls: usize = 0,
    flush_calls: usize = 0,
    reset_calls: usize = 0,
    next_stream_calls: usize = 0,
    retained_capacity: usize = 0,
    logical_retained_bytes: usize = 0,
    public_owner_live_before_deinit: usize = 0,
    profile_lifetime: []const u8 = "call_scoped",
    ownership_handoff_verified: bool = false,
    nested_call_verified: bool = false,
    output_preserved_on_error: bool = false,
    build_mode: []const u8 = @tagName(@import("builtin").mode),
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const input_path = args.next() orelse return error.MissingInput;
    const output_path = args.next() orelse return error.MissingOutput;
    const config_path = args.next() orelse return error.MissingConfig;
    if (args.next() != null) return error.TooManyArguments;
    const input = try read(init, input_path);
    defer init.gpa.free(input);
    const json = try read(init, config_path);
    defer init.gpa.free(json);
    var report: Report = .{ .input_bytes = input.len };
    const parsed = std.json.parseFromSlice(Config, init.gpa, json, .{}) catch |err| {
        report.@"error" = @errorName(err);
        report.output_preserved_on_error = true;
        try print(init, report);
        return;
    };
    defer parsed.deinit();
    var ledger: Ledger = .{ .backing = init.gpa };
    var profile: br.EncodeMemoryProfile = .{};
    const wire: ?[]u8 = operate(init.gpa, &ledger, input, parsed.value, &profile, &report) catch |err| blk: {
        report.@"error" = @errorName(err);
        report.output_preserved_on_error = true;
        break :blk null;
    };
    defer if (wire) |bytes| init.gpa.free(bytes);
    if (wire) |bytes| {
        report.output_bytes = bytes.len;
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = bytes });
    }
    report.total_profile = profile;
    report.independent_peak_requested_bytes = ledger.owned_peak;
    report.independent_live_after_deinit = ledger.live;
    report.allocation_calls = ledger.allocation_calls;
    report.encoder_allocation_calls = ledger.allocation_calls - report.caller_setup_allocation_calls;
    report.resize_calls = ledger.resize_calls;
    report.remap_calls = ledger.remap_calls;
    report.free_calls = ledger.free_calls;
    report.forced_failures = ledger.forced_failures;
    try print(init, report);
}
fn options(c: Config, profile: *br.EncodeMemoryProfile) !br.StoredStreamOptions {
    var o: br.StoredStreamOptions = .{ .window_bits = c.window_bits, .large_window = c.large_window, .metadata = c.metadata };
    if (@hasField(br.StoredStreamOptions, "max_total_working_memory")) {
        o.max_total_working_memory = c.max_total_working_memory;
        o.memory_profile = if (c.profile_enabled) profile else null;
    } else if (c.max_total_working_memory != null) return error.UnsupportedStoredMemoryControl;
    return o;
}
fn equal(a: []const u8, b: []const u8) !void {
    if (!std.mem.eql(u8, a, b)) return error.ProbeWireMismatch;
}
fn guarded(storage: []const u8, capacity: usize) !void {
    for (storage[0..8]) |byte| if (byte != 0xa5) return error.CallerPrefixModified;
    for (storage[8 + capacity ..]) |byte| if (byte != 0xa5) return error.CallerSuffixModified;
}
fn operate(a: std.mem.Allocator, ledger: *Ledger, source: []const u8, c: Config, profile: *br.EncodeMemoryProfile, r: *Report) ![]u8 {
    const o = try options(c, profile);
    var pieces: std.ArrayList([]const u8) = .empty;
    defer pieces.deinit(a);
    var offset: usize = 0;
    if (c.input_chunk == 0 or c.output_chunk == 0) return error.InvalidProbeChunk;
    while (offset < source.len) {
        const end = offset + @min(c.input_chunk, source.len - offset);
        try pieces.append(a, source[offset..end]);
        offset = end;
    }
    if (std.mem.startsWith(u8, c.scenario, "nested_")) return nested(a, ledger, source, c, o, profile, r);
    if (std.mem.eql(u8, c.api, "incremental")) return incremental(a, ledger, source, c, o, profile, r);
    var encoder = br.StoredStreamEncoder.init(ledger.allocator());
    defer encoder.deinit();
    if (std.mem.eql(u8, c.api, "scratch") or std.mem.eql(u8, c.api, "chunks_scratch")) {
        const chunks = std.mem.eql(u8, c.api, "chunks_scratch");
        if (std.mem.eql(u8, c.scenario, "retained")) {
            const warm = try a.alloc(u8, source.len * 4 + 64);
            defer a.free(warm);
            @memset(warm, 'W');
            _ = try encoder.encodeScratchWithOptions(warm, .{});
            ledger.begin();
        }
        failAtOperation(ledger, c);
        const old_pointer = encoder.scratch.items.ptr;
        const old_capacity = encoder.scratch.capacity;
        const old_wire = try a.dupe(u8, encoder.scratch.items);
        defer a.free(old_wire);
        const attempt = if (chunks) encoder.encodeChunksScratchWithOptions(pieces.items, o) else encoder.encodeScratchWithOptions(source, o);
        const result = attempt catch |err| {
            if (encoder.scratch.items.ptr != old_pointer or encoder.scratch.capacity != old_capacity) return error.CallerStateModifiedOnError;
            try equal(old_wire, encoder.scratch.items);
            r.caller_state_preserved_on_error = true;
            return err;
        };
        r.profile_after_operation = profile.*;
        r.retained_capacity = if (@hasDecl(@TypeOf(encoder), "retainedCapacity")) encoder.retainedCapacity() else encoder.scratch.capacity;
        if (@hasDecl(@TypeOf(encoder), "memorySnapshot")) r.public_owner_live_before_deinit = encoder.memorySnapshot().live_requested_bytes;
        r.logical_retained_bytes = encoder.scratch.items.len;
        const copy = try a.dupe(u8, result);
        errdefer a.free(copy);
        if (!std.mem.eql(u8, c.cycle, "none")) {
            const again = if (chunks) try encoder.encodeChunksScratchWithOptions(pieces.items, o) else try encoder.encodeScratchWithOptions(source, o);
            try equal(copy, again);
            r.cycle_verified = true;
        }
        if (std.mem.eql(u8, c.scenario, "owner_handoff")) {
            encoder.allocator = a;
            r.ownership_handoff_verified = true;
        }
        return copy;
    }
    if (std.mem.eql(u8, c.api, "alloc") or std.mem.eql(u8, c.api, "chunks_alloc") or std.mem.eql(u8, c.api, "reuse_alloc") or std.mem.eql(u8, c.api, "reuse_chunks_alloc")) {
        failAtOperation(ledger, c);
        const wire = if (std.mem.eql(u8, c.api, "alloc")) try br.encodeStoredStreamWithOptionsAlloc(ledger.allocator(), source, o) else if (std.mem.eql(u8, c.api, "chunks_alloc")) try br.encodeStoredStreamChunksWithOptionsAlloc(ledger.allocator(), pieces.items, o) else if (std.mem.eql(u8, c.api, "reuse_alloc")) try encoder.encodeWithOptionsAlloc(source, o) else try encoder.encodeChunksWithOptionsAlloc(pieces.items, o);
        defer ledger.allocator().free(wire);
        r.profile_after_operation = profile.*;
        recordOwner(&encoder, r);
        return a.dupe(u8, wire);
    }
    if (std.mem.indexOf(u8, c.api, "append") != null) {
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(ledger.allocator());
        try output.ensureTotalCapacityPrecise(ledger.allocator(), c.caller_capacity orelse 0);
        @memset(output.allocatedSlice(), 0xa5);
        if (output.capacity != 0) ledger.excludeCaller(output.allocatedSlice());
        try output.appendSlice(ledger.allocator(), "prefix|");
        // Caller setup is outside the measured encoder operation.
        ledger.excludeCaller(output.allocatedSlice());
        r.caller_setup_allocation_calls = ledger.allocation_calls;
        var active_input = source;
        var active_options = o;
        var active_chunks = pieces.items;
        if (std.mem.eql(u8, c.scenario, "alias_source")) {
            if (output.capacity < 8 + source.len) return error.InvalidProbeAlias;
            @memcpy(output.allocatedSlice()[8..][0..source.len], source);
            active_input = output.allocatedSlice()[8..][0..source.len];
        } else if (std.mem.eql(u8, c.scenario, "alias_metadata")) {
            if (output.capacity < 8 + o.metadata.len) return error.InvalidProbeAlias;
            @memcpy(output.allocatedSlice()[8..][0..o.metadata.len], o.metadata);
            active_options.metadata = output.allocatedSlice()[8..][0..o.metadata.len];
        } else if (std.mem.eql(u8, c.scenario, "alias_chunks")) {
            const table_bytes = pieces.items.len * @sizeOf([]const u8);
            if (output.capacity < 8 + table_bytes) return error.InvalidProbeAlias;
            const table: [*][]const u8 = @ptrCast(@alignCast(output.allocatedSlice()[8..].ptr));
            @memcpy(table[0..pieces.items.len], pieces.items);
            active_chunks = table[0..pieces.items.len];
        }
        failAtOperation(ledger, c);
        const pointer = output.items.ptr;
        const capacity = output.capacity;
        const before = try a.dupe(u8, output.allocatedSlice());
        defer a.free(before);
        const result = if (std.mem.eql(u8, c.api, "append")) br.encodeStoredStreamWithOptionsAppend(ledger.allocator(), &output, active_input, active_options) else if (std.mem.eql(u8, c.api, "chunks_append")) br.encodeStoredStreamChunksWithOptionsAppend(ledger.allocator(), &output, active_chunks, active_options) else if (std.mem.eql(u8, c.api, "reuse_append")) encoder.encodeWithOptionsAppend(&output, active_input, active_options) else if (std.mem.eql(u8, c.api, "reuse_chunks_append")) encoder.encodeChunksWithOptionsAppend(&output, active_chunks, active_options) else return error.InvalidProbeApi;
        result catch |err| {
            if (output.items.ptr != pointer or output.capacity != capacity or output.items.len != 7) return error.CallerStateModifiedOnError;
            try equal(before, output.allocatedSlice());
            r.caller_state_preserved_on_error = true;
            return err;
        };
        try equal("prefix|", output.items[0..7]);
        r.profile_after_operation = profile.*;
        recordOwner(&encoder, r);
        return a.dupe(u8, output.items[7..]);
    }
    if (std.mem.indexOf(u8, c.api, "into") != null) return into(a, ledger, &encoder, source, pieces.items, c, o, profile, r);
    return error.InvalidProbeApi;
}
fn into(a: std.mem.Allocator, ledger: *Ledger, encoder: *br.StoredStreamEncoder, source: []const u8, pieces: []const []const u8, c: Config, initial: br.StoredStreamOptions, profile: *br.EncodeMemoryProfile, r: *Report) ![]u8 {
    const chunks = std.mem.indexOf(u8, c.api, "chunks") != null;
    const needed = if (chunks) try br.encodedStoredStreamChunksBoundWithOptions(pieces, initial) else try br.encodedStoredStreamBoundWithOptions(source.len, initial);
    const capacity = c.caller_capacity orelse needed;
    const storage = try a.alignedAlloc(u8, .of([]const u8), capacity + 16);
    defer a.free(storage);
    @memset(storage, 0xa5);
    const output = storage[8 .. 8 + capacity];
    var input = source;
    var active_pieces = pieces;
    var o = initial;
    if (std.mem.eql(u8, c.scenario, "alias_source")) {
        if (source.len > output.len) return error.InvalidProbeAlias;
        @memcpy(output[0..source.len], source);
        input = output[0..source.len];
    } else if (std.mem.eql(u8, c.scenario, "alias_metadata")) {
        if (o.metadata.len > output.len) return error.InvalidProbeAlias;
        @memcpy(output[0..o.metadata.len], o.metadata);
        o.metadata = output[0..o.metadata.len];
    } else if (std.mem.eql(u8, c.scenario, "alias_chunks")) {
        const table_bytes = pieces.len * @sizeOf([]const u8);
        if (table_bytes > output.len) return error.InvalidProbeAlias;
        const table: [*][]const u8 = @ptrCast(@alignCast(output.ptr));
        @memcpy(table[0..pieces.len], pieces);
        active_pieces = table[0..pieces.len];
    }
    const before = try a.dupe(u8, storage);
    defer a.free(before);
    failAtOperation(ledger, c);
    const result = if (std.mem.eql(u8, c.api, "into")) br.encodeStoredStreamWithOptionsInto(input, output, o) else if (std.mem.eql(u8, c.api, "chunks_into")) br.encodeStoredStreamChunksWithOptionsInto(active_pieces, output, o) else if (std.mem.eql(u8, c.api, "reuse_into")) encoder.encodeWithOptionsIntoSlice(input, o, output) else if (std.mem.eql(u8, c.api, "reuse_chunks_into")) encoder.encodeChunksWithOptionsIntoSlice(active_pieces, o, output) else return error.InvalidProbeApi;
    const written = result catch |err| {
        try equal(before, storage);
        r.caller_state_preserved_on_error = true;
        return err;
    };
    try guarded(storage, capacity);
    r.guards_verified = true;
    r.profile_after_operation = profile.*;
    recordOwner(encoder, r);
    return a.dupe(u8, output[0..written]);
}
fn failAtOperation(ledger: *Ledger, c: Config) void {
    if (c.failure_after) |count| ledger.fail_after = ledger.allocation_calls + ledger.resize_calls + ledger.remap_calls + count;
}
fn recordOwner(encoder: *br.StoredStreamEncoder, r: *Report) void {
    if (@hasDecl(br.StoredStreamEncoder, "retainedCapacity")) r.retained_capacity = encoder.retainedCapacity();
    if (@hasDecl(br.StoredStreamEncoder, "memorySnapshot")) r.public_owner_live_before_deinit = encoder.memorySnapshot().live_requested_bytes;
    r.logical_retained_bytes = encoder.scratch.items.len;
}
fn incremental(a: std.mem.Allocator, ledger: *Ledger, source: []const u8, c: Config, o: br.StoredStreamOptions, profile: *br.EncodeMemoryProfile, r: *Report) ![]u8 {
    r.profile_lifetime = "persistent_incremental";
    var encoder = br.IncrementalStoredStreamEncoder.initWithOptions(ledger.allocator(), .{ .stream = o, .block_len = c.block_len, .max_input_len = source.len });
    defer encoder.deinit();
    failAtOperation(ledger, c);
    const result = try stream(a, ledger, &encoder, source, c, r);
    errdefer a.free(result);
    r.profile_after_operation = profile.*;
    if (@hasDecl(@TypeOf(encoder), "retainedCapacity")) r.retained_capacity = encoder.retainedCapacity();
    if (@hasDecl(@TypeOf(encoder), "memorySnapshot")) r.public_owner_live_before_deinit = encoder.memorySnapshot().live_requested_bytes;
    r.logical_retained_bytes = encoder.plain.items.len + encoder.pending.items.len;
    if (!std.mem.eql(u8, c.cycle, "none")) {
        if (std.mem.eql(u8, c.cycle, "reset")) {
            encoder.reset();
            r.reset_calls += 1;
        } else {
            try encoder.nextStream(.{ .stream = o, .block_len = c.block_len, .max_input_len = source.len });
            r.next_stream_calls += 1;
        }
        const again = try stream(a, ledger, &encoder, source, c, r);
        defer a.free(again);
        try equal(result, again);
        r.cycle_verified = true;
    }
    return result;
}
fn stream(a: std.mem.Allocator, ledger: *Ledger, encoder: *br.IncrementalStoredStreamEncoder, source: []const u8, c: Config, r: *Report) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(a);
    const storage = try a.alloc(u8, c.output_chunk + 16);
    defer a.free(storage);
    var consumed: usize = 0;
    var finishing = false;
    var metadata = false;
    var flushing = false;
    var steps: usize = 0;
    var retry_armed = false;
    var retried = false;
    while (steps < source.len * 8 + 10000) : (steps += 1) {
        const flush_at = c.flush_at orelse source.len + 1;
        if (consumed == flush_at and !metadata) {
            if (c.stream_metadata.len != 0) {
                try encoder.writeMetadata(c.stream_metadata);
                r.metadata_calls += 1;
            } else {
                encoder.flush();
                r.flush_calls += 1;
            }
            metadata = true;
            flushing = true;
        }
        if (consumed == source.len and !finishing and !flushing) {
            if (!retry_armed and std.mem.startsWith(u8, c.scenario, "retry_")) {
                if (std.mem.eql(u8, c.scenario, "retry_oom")) {
                    ledger.fail_after = ledger.allocation_calls + ledger.resize_calls + ledger.remap_calls;
                } else if (std.mem.eql(u8, c.scenario, "retry_cap")) {
                    if (@hasField(br.StoredStreamOptions, "max_total_working_memory")) encoder.options.stream.max_total_working_memory = ledger.ownedLive();
                }
                retry_armed = true;
            }
            try encoder.finish();
            finishing = true;
        }
        const end = if (finishing or flushing) consumed else consumed + @min(c.input_chunk, @min(source.len - consumed, if (!metadata and flush_at > consumed) flush_at - consumed else source.len - consumed));
        @memset(storage, 0xa5);
        const output = storage[8 .. 8 + c.output_chunk];
        r.steps += 1;
        const before = encoder.snapshot();
        const step = encoder.step(source[consumed..end], output) catch |err| {
            if (!retry_armed or retried) return err;
            const expected = if (std.mem.eql(u8, c.scenario, "retry_oom")) error.OutOfMemory else error.WorkingMemoryLimitExceeded;
            if (err != expected) return error.ProbeRetryErrorMismatch;
            const after = encoder.snapshot();
            const input_progress: usize = @intCast(after.stream_input - before.stream_input);
            const output_progress: usize = @intCast(after.stream_output - before.stream_output);
            if (input_progress > end - consumed or output_progress > output.len) return error.InvalidProbeProgress;
            consumed += input_progress;
            try result.appendSlice(a, output[0..output_progress]);
            try guarded(storage, c.output_chunk);
            ledger.fail_after = null;
            if (@hasField(br.StoredStreamOptions, "max_total_working_memory")) encoder.options.stream.max_total_working_memory = c.max_total_working_memory;
            r.retry_error = @errorName(err);
            r.retry_verified = true;
            retried = true;
            continue;
        };
        if (step.progress.input_read > end - consumed or step.progress.output_written > output.len) return error.InvalidProbeProgress;
        const after = encoder.snapshot();
        if (after.stream_input - before.stream_input != step.progress.input_read or after.stream_output - before.stream_output != step.progress.output_written) return error.InvalidProbeProgress;
        if (@hasDecl(br.IncrementalStoredStreamEncoder, "memorySnapshot")) {
            const memory = encoder.memorySnapshot();
            if (memory.available and memory.live_requested_bytes != ledger.ownedLive()) return error.ProbeLiveHeapMismatch;
        }
        consumed += step.progress.input_read;
        try result.appendSlice(a, output[0..step.progress.output_written]);
        try guarded(storage, c.output_chunk);
        if (flushing and step.status == .need_input) flushing = false;
        if (step.status == .done) {
            if (consumed != source.len) return error.InvalidProbeProgress;
            r.guards_verified = true;
            return result.toOwnedSlice(a);
        }
    }
    return error.ProbeStepLimitExceeded;
}
fn nested(a: std.mem.Allocator, ledger: *Ledger, source: []const u8, c: Config, o: br.StoredStreamOptions, profile: *br.EncodeMemoryProfile, r: *Report) ![]u8 {
    _ = a;
    // The public Generic composition surface exposes a shared-lease initializer.
    // Its owning public state supplies the actual already-counted allocator;
    // this probe imports no internal budget implementation or error translator.
    var outer = br.IncrementalStoredStreamEncoder.initWithOptions(ledger.allocator(), .{ .stream = o, .block_len = c.block_len });
    defer outer.deinit();
    _ = try outer.step("", &.{});
    const lease = outer.memory_binding.lease orelse return error.ProbeMissingPublicLease;
    var inner = o;
    var other: br.EncodeMemoryProfile = .{};
    if (std.mem.eql(u8, c.scenario, "nested_profile")) inner.memory_profile = &other else if (std.mem.eql(u8, c.scenario, "nested_cap")) inner.max_total_working_memory = 1 else if (std.mem.eql(u8, c.scenario, "nested_invalid")) inner.window_bits = 9;
    const before = ledger.allocation_calls;
    const wire = br.encodeStoredStreamWithOptionsAlloc(lease.allocator(), source, inner) catch |err| {
        if (ledger.allocation_calls != before) return error.ProbeNestedAllocatedBeforeValidation;
        r.nested_call_verified = true;
        r.profile_after_operation = profile.*;
        return err;
    };
    lease.allocator().free(wire);
    return error.ProbeNestedInvalidCallSucceeded;
}
fn read(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(65536));
}
fn print(init: std.process.Init, value: anytype) !void {
    const report = try std.json.Stringify.valueAlloc(init.gpa, value, .{});
    defer init.gpa.free(report);
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    try stdout.interface.writeAll(report);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}
