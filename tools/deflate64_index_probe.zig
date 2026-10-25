//! Requested codec-allocation measurements through common public Deflate64 APIs.
//! Input generation, wire collection, decoding and JSON use the plain allocator.
//! No clocks run unless --iterations N is explicitly supplied; timings use no tracker.
const std = @import("std");
const codec = @import("codec");
const provenance = @import("benchmark_provenance");

const names = [_][]const u8{ "empty", "tiny16", "pattern12079", "random4097", "random16387", "repeat65539", "distant131072" };
const stream_block_len = 4096;
const stream_input_len = 4 * 1024 * 1024;

const Allocation = struct { bytes: usize, succeeded: bool };
const Memory = struct {
    current_requested_bytes: usize,
    peak_requested_bytes: usize,
    live_allocations: usize,
    allocation_attempts: usize,
    successful_allocations: usize,
    successful_allocation_requested_bytes: usize,
    resize_attempts: usize,
    successful_resizes: usize,
    remap_attempts: usize,
    successful_remaps: usize,
    free_calls: usize,
    growth_requested_bytes: usize,
    released_requested_bytes: usize,
    maximum_single_request: usize,
};

/// Fixed bookkeeping storage never calls the tracked allocator. Accounting
/// changes only after the backing operation succeeds, including a moving remap.
const Tracker = struct {
    backing: std.mem.Allocator,
    current: usize = 0,
    peak: usize = 0,
    live_allocations: usize = 0,
    allocation_attempts: usize = 0,
    successful_allocations: usize = 0,
    allocation_bytes: usize = 0,
    resize_attempts: usize = 0,
    successful_resizes: usize = 0,
    remap_attempts: usize = 0,
    successful_remaps: usize = 0,
    free_calls: usize = 0,
    growth_bytes: usize = 0,
    released_bytes: usize = 0,
    maximum_request: usize = 0,
    fail_allocation: ?usize = null,
    induced_failure: bool = false,
    slots: [128]Slot = @splat(.{}),
    allocations: [256]Allocation = undefined,
    allocation_records: usize = 0,
    allocation_records_truncated: bool = false,

    const Slot = struct { pointer: ?[*]u8 = null, bytes: usize = 0 };
    fn allocator(self: *Tracker) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn memory(self: *const Tracker) Memory {
        return .{
            .current_requested_bytes = self.current,
            .peak_requested_bytes = self.peak,
            .live_allocations = self.live_allocations,
            .allocation_attempts = self.allocation_attempts,
            .successful_allocations = self.successful_allocations,
            .successful_allocation_requested_bytes = self.allocation_bytes,
            .resize_attempts = self.resize_attempts,
            .successful_resizes = self.successful_resizes,
            .remap_attempts = self.remap_attempts,
            .successful_remaps = self.successful_remaps,
            .free_calls = self.free_calls,
            .growth_requested_bytes = self.growth_bytes,
            .released_requested_bytes = self.released_bytes,
            .maximum_single_request = self.maximum_request,
        };
    }
    fn slot(self: *Tracker, bytes: []u8) *Slot {
        for (&self.slots) |*record| if (record.pointer == bytes.ptr) {
            if (record.bytes != bytes.len) @panic("tracked allocation size mismatch");
            return record;
        };
        @panic("unknown tracked allocation");
    }
    fn change(self: *Tracker, old: usize, new: usize) void {
        if (old > self.current) @panic("requested allocation accounting underflow");
        self.current = self.current - old + new;
        if (new > old) self.growth_bytes += new - old else self.released_bytes += old - new;
        self.peak = @max(self.peak, self.current);
    }
    fn recordAllocation(self: *Tracker, bytes: usize, succeeded: bool) void {
        if (self.allocation_records == self.allocations.len) {
            self.allocation_records_truncated = true;
            return;
        }
        self.allocations[self.allocation_records] = .{ .bytes = bytes, .succeeded = succeeded };
        self.allocation_records += 1;
    }
    fn alloc(raw: *anyopaque, bytes: usize, alignment: std.mem.Alignment, address: usize) ?[*]u8 {
        const self: *Tracker = @ptrCast(@alignCast(raw));
        const attempt = self.allocation_attempts;
        self.allocation_attempts += 1;
        self.maximum_request = @max(self.maximum_request, bytes);
        if (self.fail_allocation == attempt) {
            self.induced_failure = true;
            self.recordAllocation(bytes, false);
            return null;
        }
        const pointer = self.backing.rawAlloc(bytes, alignment, address) orelse {
            self.recordAllocation(bytes, false);
            return null;
        };
        for (&self.slots) |*record| if (record.pointer == null) {
            record.* = .{ .pointer = pointer, .bytes = bytes };
            self.successful_allocations += 1;
            self.allocation_bytes += bytes;
            self.live_allocations += 1;
            self.change(0, bytes);
            self.recordAllocation(bytes, true);
            return pointer;
        };
        self.backing.rawFree(pointer[0..bytes], alignment, address);
        self.recordAllocation(bytes, false);
        return null;
    }
    fn resize(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, new: usize, address: usize) bool {
        const self: *Tracker = @ptrCast(@alignCast(raw));
        self.resize_attempts += 1;
        self.maximum_request = @max(self.maximum_request, new);
        const record = self.slot(bytes);
        if (!self.backing.rawResize(bytes, alignment, new, address)) return false;
        self.successful_resizes += 1;
        self.change(bytes.len, new);
        record.bytes = new;
        return true;
    }
    fn remap(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, new: usize, address: usize) ?[*]u8 {
        const self: *Tracker = @ptrCast(@alignCast(raw));
        self.remap_attempts += 1;
        self.maximum_request = @max(self.maximum_request, new);
        const record = self.slot(bytes);
        const pointer = self.backing.rawRemap(bytes, alignment, new, address) orelse return null;
        self.successful_remaps += 1;
        self.change(bytes.len, new);
        record.* = .{ .pointer = pointer, .bytes = new };
        return pointer;
    }
    fn free(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, address: usize) void {
        const self: *Tracker = @ptrCast(@alignCast(raw));
        const record = self.slot(bytes);
        self.backing.rawFree(bytes, alignment, address);
        record.* = .{};
        self.free_calls += 1;
        self.live_allocations -= 1;
        self.change(bytes.len, 0);
    }
    fn clean(self: *const Tracker) !void {
        if (self.current != 0 or self.live_allocations != 0 or self.growth_bytes != self.released_bytes) return error.CodecAllocationLeak;
        for (self.slots) |record| if (record.pointer != null) return error.CodecAllocationLeak;
    }
};

const Timing = struct {
    iterations: usize,
    rounds_ns: [5]u64,
    minimum_ns: u64,
    median_ns: u64,
    mix: usize,
};
const OneShot = struct {
    name: []const u8,
    input_bytes: usize,
    input_sha256: [64]u8,
    wire_bytes: usize,
    wire_sha256: [64]u8,
    encoded_bound: usize,
    memory_at_return: Memory,
    memory_after_free: Memory,
    codec_allocations: []Allocation,
    roundtrip_verified: bool,
    cleanup_failure_checks: usize,
    timing: ?Timing,
};
const Checkpoint = struct {
    input_read: usize,
    wire_bytes: usize,
    heads_entries: usize,
    previous_entries: usize,
    memory: Memory,
};
const Streaming = struct {
    input_bytes: usize,
    input_sha256: [64]u8,
    reused_input_block_bytes: usize,
    block_len: usize,
    wire_bytes: usize,
    wire_sha256: [64]u8,
    init_memory: Memory,
    memory_before_deinit: Memory,
    memory_after_deinit: Memory,
    maximum_heads_entries: usize,
    maximum_previous_entries: usize,
    checkpoints: []Checkpoint,
    codec_allocations: []Allocation,
    first_output_input_offset: ?usize,
    steps: usize,
    roundtrip_verified: bool,
    cleanup_failure_checks: usize,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var iterations: ?usize = null;
    while (args.next()) |argument| {
        if (!std.mem.eql(u8, argument, "--iterations") or iterations != null) return error.InvalidArguments;
        iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingIterations, 10);
        if (iterations.? == 0 or iterations.? > 1000) return error.InvalidIterations;
    }
    const info = try provenance.capture(init.io, init.gpa, init.minimal.args, "single");
    defer info.deinit(init.gpa);
    var rows: std.ArrayList(OneShot) = .empty;
    defer {
        for (rows.items) |row| init.gpa.free(row.codec_allocations);
        rows.deinit(init.gpa);
    }
    for (names) |name| {
        const input = try makeInput(init.gpa, name);
        defer init.gpa.free(input);
        const row = try measureOneShot(init, name, input, iterations);
        rows.append(init.gpa, row) catch |err| {
            init.gpa.free(row.codec_allocations);
            return err;
        };
    }
    const stream = try measureStream(init);
    defer init.gpa.free(stream.checkpoints);
    defer init.gpa.free(stream.codec_allocations);
    const json = try std.json.Stringify.valueAlloc(init.gpa, .{
        .schema = "vort.deflate64.index-resources.v1",
        .provenance = info,
        .codec_options = .{ .max_chain = 128, .nice_length = 128 },
        .scope = "successful codec allocator requests only, including returned raw output; input generation, collectors, decoder and metadata excluded",
        .memory_metric = "current and peak requested live allocation bytes; not RSS, total process heap, stack or cumulative requests",
        .remap_metric_limit = "successful rawRemap replaces one logical owned request; backing allocator's private transient physical allocation is unobservable and excluded",
        .index_observation = "tool reads common encoder.matcher heads/previous lengths; diagnostic capacity, not a new public snapshot guarantee",
        .timing_scope = "only when --iterations is supplied: five rounds of noinline one-shot encodeAlloc, complete output wrapping checksum and free through plain allocator; no tracker, input generation, decoding or SHA hashing inside timer; stream resource pass is not timed",
        .one_shot = rows.items,
        .streaming = stream,
    }, .{ .whitespace = .indent_2 });
    defer init.gpa.free(json);
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    try stdout.interface.writeAll(json);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}

fn makeInput(allocator: std.mem.Allocator, name: []const u8) ![]u8 {
    if (std.mem.eql(u8, name, "empty")) return allocator.dupe(u8, "");
    if (std.mem.eql(u8, name, "tiny16")) return allocator.dupe(u8, "D64 tiny16 data\n");
    const len: usize = if (std.mem.eql(u8, name, "pattern12079")) 12_079 else if (std.mem.eql(u8, name, "random4097")) 4097 else if (std.mem.eql(u8, name, "random16387")) 16_387 else if (std.mem.eql(u8, name, "repeat65539")) 65_539 else if (std.mem.eql(u8, name, "distant131072")) 131_072 else return error.UnknownFixture;
    const input = try allocator.alloc(u8, len);
    if (std.mem.eql(u8, name, "pattern12079")) {
        const text = "Deflate64 bounded index capacity pattern.\n";
        for (input, 0..) |*byte, index| byte.* = text[index % text.len];
    } else if (std.mem.eql(u8, name, "repeat65539")) {
        @memset(input, 'Q');
    } else {
        const count = if (len == 131_072) 65_536 else len;
        var state: u32 = if (len == 131_072) 0x6536_2026 else 0xd640_2026;
        for (input[0..count]) |*byte| {
            state = state *% 1_664_525 +% 1_013_904_223;
            byte.* = @truncate(state >> 24);
        }
        if (count != len) @memcpy(input[count..], input[0..count]);
    }
    return input;
}

fn measureOneShot(init: std.process.Init, name: []const u8, input: []const u8, iterations: ?usize) !OneShot {
    var tracker: Tracker = .{ .backing = init.gpa };
    const wire = codec.encodeAlloc(tracker.allocator(), input, .{}) catch |err| {
        try tracker.clean();
        return err;
    };
    var wire_owned = true;
    errdefer if (wire_owned) {
        tracker.allocator().free(wire);
        tracker.clean() catch @panic("codec error cleanup leaked requested bytes");
    };
    const before = tracker.memory();
    const wire_bytes = wire.len;
    const wire_sha = provenance.sha256Hex(wire);
    const bound = try codec.encodedBound(input.len);
    if (wire.len > bound) return error.EncodedBoundExceeded;
    const decoded = codec.decodeAllocLimited(init.gpa, wire, input.len) catch |err| {
        tracker.allocator().free(wire);
        wire_owned = false;
        try tracker.clean();
        return err;
    };
    defer init.gpa.free(decoded);
    const equal = std.mem.eql(u8, decoded, input);
    tracker.allocator().free(wire);
    wire_owned = false;
    try tracker.clean();
    if (!equal) return error.RoundTripMismatch;
    if (tracker.allocation_records_truncated) return error.AllocationRecordsTruncated;
    const allocations = try init.gpa.dupe(Allocation, tracker.allocations[0..tracker.allocation_records]);
    errdefer init.gpa.free(allocations);
    const failures = try oneShotCleanupChecks(init.gpa, input, tracker.allocation_attempts);
    const timing = if (iterations) |count| try timeOneShot(init, input, count) else null;
    return .{
        .name = name,
        .input_bytes = input.len,
        .input_sha256 = provenance.sha256Hex(input),
        .wire_bytes = wire_bytes,
        .wire_sha256 = wire_sha,
        .encoded_bound = bound,
        .memory_at_return = before,
        .memory_after_free = tracker.memory(),
        .codec_allocations = allocations,
        .roundtrip_verified = true,
        .cleanup_failure_checks = failures,
        .timing = timing,
    };
}

fn oneShotCleanupChecks(backing: std.mem.Allocator, input: []const u8, attempts: usize) !usize {
    var checks: usize = 0;
    for (0..@min(attempts, 3)) |index| {
        var tracker: Tracker = .{ .backing = backing, .fail_allocation = index };
        if (codec.encodeAlloc(tracker.allocator(), input, .{})) |wire| {
            tracker.allocator().free(wire);
            try tracker.clean();
            return error.AllocationFailureIgnored;
        } else |err| {
            try tracker.clean();
            if (err != error.OutOfMemory) return err;
        }
        try tracker.clean();
        if (!tracker.induced_failure) return error.FailureNotExercised;
        checks += 1;
    }
    return checks;
}

fn timeOneShot(init: std.process.Init, input: []const u8, iterations: usize) !Timing {
    _ = try encodePass(init.gpa, input);
    var ns: [5]u64 = undefined;
    var mix: usize = 0;
    for (&ns) |*round| {
        const start = std.Io.Clock.awake.now(init.io);
        for (0..iterations) |_| {
            mix +%= try encodePass(init.gpa, input);
        }
        const elapsed = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
        round.* = @intCast(@max(0, elapsed));
    }
    std.mem.doNotOptimizeAway(mix);
    var sorted = ns;
    std.mem.sort(u64, &sorted, {}, std.sort.asc(u64));
    return .{ .iterations = iterations, .rounds_ns = ns, .minimum_ns = sorted[0], .median_ns = sorted[2], .mix = mix };
}

/// Every output byte contributes to the timer's observable result. This adds a
/// complete output checksum to the measured scope; it is not codec-only time.
noinline fn encodePass(allocator: std.mem.Allocator, input: []const u8) !usize {
    const wire = try codec.encodeAlloc(allocator, input, .{});
    defer allocator.free(wire);
    var mix = wire.len;
    for (wire, 0..) |byte, index| mix +%= @as(usize, byte) *% (index + 1);
    return mix;
}

fn measureStream(init: std.process.Init) !Streaming {
    var input: [stream_block_len]u8 = undefined;
    const text = "Deflate64 reused input block for 4MiB bounded streaming.\n";
    for (&input, 0..) |*byte, index| byte.* = text[index % text.len];
    var input_hasher = std.crypto.hash.sha2.Sha256.init(.{});
    for (0..stream_input_len / input.len) |_| input_hasher.update(&input);
    var input_digest: [32]u8 = undefined;
    input_hasher.final(&input_digest);
    var tracker: Tracker = .{ .backing = init.gpa };
    var encoder = codec.IncrementalEncoder.initWithOptions(tracker.allocator(), .{ .block_len = stream_block_len });
    const initial = tracker.memory();
    const collected = driveStream(init.gpa, &encoder, &tracker, &input) catch |err| {
        encoder.deinit();
        try tracker.clean();
        return err;
    };
    defer init.gpa.free(collected.wire);
    const before = tracker.memory();
    encoder.deinit();
    try tracker.clean();
    for (&input, 0..) |byte, index| if (byte != text[index % text.len]) return error.StreamInputModified;
    const decoded = try codec.decodeAllocLimited(init.gpa, collected.wire, stream_input_len);
    defer init.gpa.free(decoded);
    if (decoded.len != stream_input_len) return error.StreamRoundTripMismatch;
    for (decoded, 0..) |byte, index| if (byte != input[index % input.len]) return error.StreamRoundTripMismatch;
    if (tracker.allocation_records_truncated) return error.AllocationRecordsTruncated;
    const allocations = try init.gpa.dupe(Allocation, tracker.allocations[0..tracker.allocation_records]);
    errdefer init.gpa.free(allocations);
    const checkpoints = try init.gpa.dupe(Checkpoint, collected.checkpoints[0..collected.checkpoint_count]);
    errdefer init.gpa.free(checkpoints);
    const failures = try streamCleanupChecks(init.gpa, &input);
    return .{
        .input_bytes = stream_input_len,
        .input_sha256 = std.fmt.bytesToHex(input_digest, .lower),
        .reused_input_block_bytes = input.len,
        .block_len = stream_block_len,
        .wire_bytes = collected.wire.len,
        .wire_sha256 = provenance.sha256Hex(collected.wire),
        .init_memory = initial,
        .memory_before_deinit = before,
        .memory_after_deinit = tracker.memory(),
        .maximum_heads_entries = collected.maximum_heads,
        .maximum_previous_entries = collected.maximum_previous,
        .checkpoints = checkpoints,
        .codec_allocations = allocations,
        .first_output_input_offset = collected.first_output,
        .steps = collected.steps,
        .roundtrip_verified = true,
        .cleanup_failure_checks = failures,
    };
}

const StreamResult = struct {
    wire: []u8,
    checkpoints: [16]Checkpoint = undefined,
    checkpoint_count: usize = 0,
    maximum_heads: usize = 0,
    maximum_previous: usize = 0,
    first_output: ?usize = null,
    steps: usize = 0,
};

fn driveStream(collector: std.mem.Allocator, encoder: *codec.IncrementalEncoder, tracker: *Tracker, input: *const [stream_block_len]u8) !StreamResult {
    var result: StreamResult = .{ .wire = &.{} };
    var wire: std.ArrayList(u8) = .empty;
    errdefer wire.deinit(collector);
    var consumed: usize = 0;
    var finishing = false;
    var output: [257]u8 = undefined;
    while (result.steps < stream_input_len * 4) {
        if (consumed == stream_input_len and !finishing) {
            encoder.finish();
            finishing = true;
        }
        const offset = consumed % input.len;
        const offer = @min(stream_input_len - consumed, input.len - offset);
        const step = try encoder.step(input[offset..][0..offer], &output);
        if (step.progress.input_read > offer or step.progress.output_written > output.len) return error.InvalidStreamProgress;
        consumed += step.progress.input_read;
        try wire.appendSlice(collector, output[0..step.progress.output_written]);
        result.steps += 1;
        const heads = encoder.matcher.heads.len;
        const previous = encoder.matcher.previous.len;
        if (heads != result.maximum_heads or previous != result.maximum_previous) {
            if (result.checkpoint_count == result.checkpoints.len) return error.IndexCheckpointLimit;
            result.checkpoints[result.checkpoint_count] = .{ .input_read = consumed, .wire_bytes = wire.items.len, .heads_entries = heads, .previous_entries = previous, .memory = tracker.memory() };
            result.checkpoint_count += 1;
        }
        result.maximum_heads = @max(result.maximum_heads, heads);
        result.maximum_previous = @max(result.maximum_previous, previous);
        if (step.progress.output_written != 0 and result.first_output == null) result.first_output = consumed;
        if (step.status == .done) {
            if (!finishing or consumed != stream_input_len) return error.StreamEarlyDone;
            result.wire = try wire.toOwnedSlice(collector);
            return result;
        }
        if (step.progress.input_read == 0 and step.progress.output_written == 0) return error.StreamMadeNoProgress;
    }
    return error.StreamStepLimit;
}

fn streamCleanupChecks(backing: std.mem.Allocator, input: *const [stream_block_len]u8) !usize {
    var checks: usize = 0;
    for (0..3) |index| {
        var tracker: Tracker = .{ .backing = backing, .fail_allocation = index };
        var encoder = codec.IncrementalEncoder.initWithOptions(tracker.allocator(), .{ .block_len = stream_block_len });
        var output: [257]u8 = undefined;
        var offset: usize = 0;
        var failed = false;
        var finishing = false;
        for (0..4096) |_| {
            if (offset == input.len and !finishing) {
                encoder.finish();
                finishing = true;
            }
            const step = encoder.step(input[offset..], &output) catch |err| {
                encoder.deinit();
                try tracker.clean();
                if (err != error.OutOfMemory or !tracker.induced_failure) return error.UnexpectedStreamCleanupError;
                failed = true;
                break;
            };
            offset += step.progress.input_read;
            if (step.status == .done) break;
        }
        if (!failed) {
            encoder.deinit();
            try tracker.clean();
            return error.StreamFailureNotExercised;
        }
        checks += 1;
    }
    return checks;
}
