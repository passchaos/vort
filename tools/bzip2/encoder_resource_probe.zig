//! Requested encoder-owned heap accounting, without throughput measurement.
const std = @import("std");
const builtin = @import("builtin");
const bzip2 = @import("bzip2");
const provenance = @import("benchmark_provenance");

const input_limit: usize = 64 * 1024 * 1024;
const Kind = enum { oneshot, incremental };
const Options = struct {
    input: ?[]const u8 = null,
    output: ?[]const u8 = null,
    kind: Kind = .oneshot,
    strategy: bzip2.EncodeStrategy = .balanced,
    block_size: u4 = 9,
    input_step: usize = 65536,
    output_step: usize = 65536,
};

const Metrics = struct {
    allocations: usize = 0,
    resizes: usize = 0,
    remaps: usize = 0,
    largest_request: usize = 0,
    peak: usize = 0,
};

const Tracker = struct {
    backing: std.mem.Allocator,
    metrics: Metrics = .{},
    live: usize = 0,

    fn allocator(self: *Tracker) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }

    fn changed(self: *Tracker, previous: usize, current: usize) void {
        std.debug.assert(self.live >= previous);
        self.live = self.live - previous + current;
        self.metrics.peak = @max(self.metrics.peak, self.live);
        self.metrics.largest_request = @max(self.metrics.largest_request, current);
    }

    fn alloc(raw: *anyopaque, length: usize, alignment: std.mem.Alignment, address: usize) ?[*]u8 {
        const self: *Tracker = @ptrCast(@alignCast(raw));
        const memory = self.backing.rawAlloc(length, alignment, address) orelse return null;
        self.metrics.allocations += 1;
        self.changed(0, length);
        return memory;
    }

    fn resize(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, length: usize, address: usize) bool {
        const self: *Tracker = @ptrCast(@alignCast(raw));
        if (!self.backing.rawResize(memory, alignment, length, address)) return false;
        self.metrics.resizes += 1;
        self.changed(memory.len, length);
        return true;
    }

    fn remap(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, length: usize, address: usize) ?[*]u8 {
        const self: *Tracker = @ptrCast(@alignCast(raw));
        const updated = self.backing.rawRemap(memory, alignment, length, address) orelse return null;
        self.metrics.remaps += 1;
        self.changed(memory.len, length);
        return updated;
    }

    fn free(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, address: usize) void {
        const self: *Tracker = @ptrCast(@alignCast(raw));
        self.backing.rawFree(memory, alignment, address);
        std.debug.assert(self.live >= memory.len);
        self.live -= memory.len;
    }
};

const Result = struct {
    encoded_bytes: usize,
    output_sha256: [64]u8,
    metrics: Metrics,
    live_output: ?usize = null,
    live_before_deinit: ?usize = null,
    final_live: usize,
    caller_output_capacity: usize = 0,
    feed_calls: usize = 0,
    drain_calls: usize = 0,
    snapshot: ?bzip2.IncrementalEncoder.Snapshot = null,
};

pub fn main(init: std.process.Init) !void {
    const options = try parse(init);
    defer init.gpa.free(options.input.?);
    defer init.gpa.free(options.output.?);
    const output_path = options.output orelse return error.MissingArgument;
    // One extra byte permits observing EOF for a file exactly at the bound.
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, options.input orelse return error.MissingArgument, init.gpa, .limited(input_limit + 1));
    defer init.gpa.free(input);
    if (input.len > input_limit) return error.InputTooLarge;
    const info = try provenance.capture(init.io, init.gpa, init.minimal.args, "single");
    defer info.deinit(init.gpa);
    const source_hash = provenance.sha256Hex(input);
    const result = switch (options.kind) {
        .oneshot => try oneShot(init, options, input, output_path),
        .incremental => try incremental(init, options, input, output_path),
    };
    const snapshot = result.snapshot;
    // JSON storage, provenance strings, caller input and the incremental
    // caller output buffer all use the untracked outer allocator.
    const json = try std.json.Stringify.valueAlloc(init.gpa, .{
        .schema = "vort.bzip2_encoder_resource.v1",
        .kind = @tagName(options.kind),
        .strategy = @tagName(options.strategy),
        .block_size = options.block_size,
        .input_step = options.input_step,
        .output_step = options.output_step,
        .input_bytes = input.len,
        .source_sha256 = source_hash[0..],
        .encoded_bytes = result.encoded_bytes,
        .output_sha256 = result.output_sha256[0..],
        .allocations = result.metrics.allocations,
        .resizes = result.metrics.resizes,
        .remaps = result.metrics.remaps,
        .largest_request = result.metrics.largest_request,
        .peak = result.metrics.peak,
        .live_output = result.live_output,
        .live_before_deinit = result.live_before_deinit,
        .final_live = result.final_live,
        .caller_output_capacity = result.caller_output_capacity,
        .feed_calls = result.feed_calls,
        .drain_calls = result.drain_calls,
        .retained_rle_capacity = if (snapshot) |s| @as(?usize, s.retained_rle_capacity) else null,
        .retained_output_capacity = if (snapshot) |s| @as(?usize, s.retained_output_capacity) else null,
        .block_count = if (snapshot) |s| @as(?usize, s.block_count) else null,
        .snapshot = snapshot,
        .resource_scope = "encoder-owned requested heap only; includes all simultaneous RLE, pending, BWT, Huffman and owned output allocations; excludes caller input/output, metadata, stack, allocator bookkeeping and backend remap internal transients",
        .counter_scope = "successful allocator operations only; failed alloc/resize/remap leave counters and live bytes unchanged; largest_request includes successful alloc/resize/remap target sizes",
        .measurement = "allocation instrumentation; no elapsed time or throughput result",
        .provenance = .{
            .provenance_version = info.provenance_version,
            // Root mode remains truthful even if the shared metadata module
            // was built with a different optimize setting.
            .optimize = @tagName(builtin.mode),
            .zig_version = builtin.zig_version_string,
            .target_arch = info.target_arch,
            .target_os = info.target_os,
            .target_abi = info.target_abi,
            .target_cpu = info.target_cpu,
            .cpu_model = info.cpu_model,
            .cpu_affinity = info.cpu_affinity,
            .affinity_cpu_count = info.affinity_cpu_count,
            .benchmark_threads = info.benchmark_threads,
            .codec_thread_policy = info.codec_thread_policy,
            .executable_sha256 = info.executable_sha256,
            .command = info.command,
        },
    }, .{});
    defer init.gpa.free(json);
    var stdout_buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    try stdout.interface.writeAll(json);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}

fn parse(init: std.process.Init) !Options {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var options: Options = .{};
    while (args.next()) |arg| {
        const value = args.next() orelse return error.MissingArgument;
        if (std.mem.eql(u8, arg, "--input")) {
            options.input = value;
        } else if (std.mem.eql(u8, arg, "--output")) {
            options.output = value;
        } else if (std.mem.eql(u8, arg, "--kind")) {
            options.kind = std.meta.stringToEnum(Kind, value) orelse return error.InvalidArgument;
        } else if (std.mem.eql(u8, arg, "--strategy")) {
            options.strategy = std.meta.stringToEnum(bzip2.EncodeStrategy, value) orelse return error.InvalidArgument;
        } else if (std.mem.eql(u8, arg, "--block-size")) {
            options.block_size = try std.fmt.parseInt(u4, value, 10);
        } else if (std.mem.eql(u8, arg, "--input-step")) {
            options.input_step = try std.fmt.parseInt(usize, value, 10);
        } else if (std.mem.eql(u8, arg, "--output-step")) {
            options.output_step = try std.fmt.parseInt(usize, value, 10);
        } else return error.InvalidArgument;
    }
    if (options.block_size < 1 or options.block_size > 9 or options.input_step == 0 or options.output_step == 0)
        return error.InvalidArgument;
    // Parsed strings point into the process's argument storage on this host.
    // Copying them avoids relying on the iterator allocation's lifetime.
    options.input = try init.gpa.dupe(u8, options.input orelse return error.MissingArgument);
    errdefer init.gpa.free(options.input.?);
    options.output = try init.gpa.dupe(u8, options.output orelse return error.MissingArgument);
    return options;
}

fn oneShot(init: std.process.Init, options: Options, input: []const u8, output_path: []const u8) !Result {
    var tracker: Tracker = .{ .backing = init.gpa };
    const allocator = tracker.allocator();
    var result: Result = undefined;
    {
        const encoded = try bzip2.encodeAlloc(allocator, input, .{ .block_size_100k = options.block_size, .strategy = options.strategy });
        defer allocator.free(encoded);
        result = .{
            .encoded_bytes = encoded.len,
            .output_sha256 = provenance.sha256Hex(encoded),
            .metrics = tracker.metrics,
            .live_output = tracker.live,
            .final_live = 0,
        };
        if (tracker.live != encoded.len) return error.UnexpectedLiveOutput;
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    }
    result.final_live = tracker.live;
    if (tracker.live != 0) return error.EncoderAllocationLeak;
    return result;
}

fn outputWindow(output: []u8, written: usize, step: usize) ![]u8 {
    if (written >= output.len) return error.OutputTooSmall;
    return output[written..][0..@min(step, output.len - written)];
}

fn incremental(init: std.process.Init, options: Options, input: []const u8, output_path: []const u8) !Result {
    const doubled = std.math.mul(usize, input.len, 2) catch return error.InputTooLarge;
    const output_capacity = std.math.add(usize, doubled, 4096) catch return error.InputTooLarge;
    const output = try init.gpa.alloc(u8, output_capacity);
    defer init.gpa.free(output);
    var tracker: Tracker = .{ .backing = init.gpa };
    var result: Result = undefined;
    {
        var encoder = try bzip2.IncrementalEncoder.initExactSize(tracker.allocator(), .{
            .block_size_100k = options.block_size,
            .strategy = options.strategy,
        }, input.len);
        defer encoder.deinit();
        var read: usize = 0;
        var written: usize = 0;
        var feed_calls: usize = 0;
        var drain_calls: usize = 0;
        while (read < input.len) {
            const part = input[read..][0..@min(options.input_step, input.len - read)];
            const target = try outputWindow(output, written, options.output_step);
            const step = try encoder.step(part, target);
            feed_calls += 1;
            if (step.progress.input_read > part.len or step.progress.output_written > target.len) return error.InvalidProgress;
            if (step.progress.input_read == 0 and step.progress.output_written == 0) return error.NoProgress;
            read += step.progress.input_read;
            written += step.progress.output_written;
            if (step.status == .done and read != input.len) return error.InvalidProgress;
        }
        encoder.finish();
        while (true) {
            const target = try outputWindow(output, written, options.output_step);
            const step = try encoder.step("", target);
            drain_calls += 1;
            if (step.progress.input_read != 0 or step.progress.output_written > target.len) return error.InvalidProgress;
            written += step.progress.output_written;
            if (step.status == .done) break;
            if (step.progress.output_written == 0) return error.NoProgress;
        }
        const snapshot = encoder.snapshot();
        if (!snapshot.done or snapshot.input_read != input.len or snapshot.output_written != written) return error.InvalidProgress;
        result = .{
            .encoded_bytes = written,
            .output_sha256 = provenance.sha256Hex(output[0..written]),
            .metrics = tracker.metrics,
            .live_before_deinit = tracker.live,
            .final_live = 0,
            .caller_output_capacity = output_capacity,
            .feed_calls = feed_calls,
            .drain_calls = drain_calls,
            .snapshot = snapshot,
        };
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = output[0..written] });
    }
    result.final_live = tracker.live;
    if (tracker.live != 0) return error.EncoderAllocationLeak;
    return result;
}

test "Bzip2 encoder resource Tracker accounts successful operations and preserves failed metrics" {
    var storage: [128]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    var tracker: Tracker = .{ .backing = fixed.allocator() };
    const allocator = tracker.allocator();
    var memory = try allocator.alloc(u8, 16);
    try std.testing.expect(allocator.resize(memory, 24));
    memory = memory.ptr[0..24];
    memory = allocator.remap(memory, 32) orelse return error.UnexpectedRemapFailure;
    try std.testing.expectEqual(@as(usize, 1), tracker.metrics.allocations);
    try std.testing.expectEqual(@as(usize, 1), tracker.metrics.resizes);
    try std.testing.expectEqual(@as(usize, 1), tracker.metrics.remaps);
    try std.testing.expectEqual(@as(usize, 32), tracker.live);
    try std.testing.expectEqual(@as(usize, 32), tracker.metrics.peak);
    try std.testing.expectEqual(@as(usize, 32), tracker.metrics.largest_request);
    const before = tracker.metrics;
    try std.testing.expect(!allocator.resize(memory, 1024));
    try std.testing.expect(allocator.remap(memory, 1024) == null);
    try std.testing.expectError(error.OutOfMemory, allocator.alloc(u8, 1024));
    try std.testing.expectEqualDeep(before, tracker.metrics);
    try std.testing.expectEqual(@as(usize, 32), tracker.live);
    allocator.free(memory);
    try std.testing.expectEqual(@as(usize, 0), tracker.live);
}
