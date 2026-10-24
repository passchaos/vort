const std = @import("std");
const lzma = @import("lzma");

const Config = struct {
    format: []const u8 = "alone",
    api: []const u8 = "workspace",
    operation: []const u8 = "into",
    dictionary: u32 = 4096,
    end_marker: bool = true,
    expected_size: ?usize = null,
    output_capacity: ?usize = null,
    max_output_len: usize = std.math.maxInt(usize),
    max_dictionary_size: usize = std.math.maxInt(usize),
    max_working_memory: usize = std.math.maxInt(usize),
    allow_partial: bool = false,
    alias_offset: ?usize = null,
    check_count: bool = false,
    warm: bool = false,
    lifecycle: bool = false,
    oom: bool = false,
};
const Report = struct {
    build_mode: []const u8 = @tagName(@import("builtin").mode),
    @"error": ?[]const u8 = null,
    count: ?usize = null,
    output_written: usize = 0,
    unchanged_on_error: bool = true,
    allocation_after_output: bool = false,
    allocation_attempts: usize = 0,
    max_allocation_request: usize = 0,
    peak_live_bytes: usize = 0,
    peak_working_bytes: usize = 0,
    retained_probability_capacity: usize = 0,
    retained_dictionary_capacity: usize = 0,
    retained_input_copy_capacity: usize = 0,
    retained_decoded_capacity: usize = 0,
    live_after_deinit: usize = 0,
    warm_calls: usize = 0,
    warm_allocation_attempts: usize = 0,
    lifecycle_checks: usize = 0,
    oom_failure_cases: usize = 0,
    snapshot: ?std.json.Value = null,
};

// Independent allocation observer. Only codec allocations use this wrapper;
// file I/O, reference output, caller buffers and JSON use the process allocator.
const Tracker = struct {
    backing: std.mem.Allocator,
    live: usize = 0,
    peak: usize = 0,
    max_request: usize = 0,
    attempts: usize = 0,
    successes: usize = 0,
    fail_after: usize = std.math.maxInt(usize),
    deny_resize: bool = false,
    deny_alloc: bool = false,
    induced: bool = false,
    after_output: bool = false,
    observed: []const u8 = &.{},
    original: []const u8 = &.{},

    fn allocator(self: *Tracker) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn attach(self: *Tracker, output: []const u8, original: []const u8) void {
        self.observed = output;
        self.original = original;
    }
    fn observe(self: *Tracker, size: usize) void {
        self.max_request = @max(self.max_request, size);
        self.after_output = self.after_output or !std.mem.eql(u8, self.observed, self.original);
    }
    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *Tracker = @ptrCast(@alignCast(ctx));
        self.observe(len);
        self.attempts += 1;
        if (self.deny_alloc or self.successes == self.fail_after) {
            self.induced = true;
            return null;
        }
        const ptr = self.backing.rawAlloc(len, alignment, ra) orelse return null;
        self.successes += 1;
        self.live += len;
        self.peak = @max(self.peak, self.live);
        return ptr;
    }
    fn resize(ctx: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ra: usize) bool {
        const self: *Tracker = @ptrCast(@alignCast(ctx));
        if (len > bytes.len) self.observe(len);
        if (self.deny_resize or !self.backing.rawResize(bytes, alignment, len, ra)) return false;
        self.live = self.live - bytes.len + len;
        self.peak = @max(self.peak, self.live);
        return true;
    }
    fn remap(ctx: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ra: usize) ?[*]u8 {
        const self: *Tracker = @ptrCast(@alignCast(ctx));
        if (len > bytes.len) self.observe(len);
        if (self.deny_resize) return null;
        const ptr = self.backing.rawRemap(bytes, alignment, len, ra) orelse return null;
        self.live = self.live - bytes.len + len;
        self.peak = @max(self.peak, self.live);
        return ptr;
    }
    fn free(ctx: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, ra: usize) void {
        const self: *Tracker = @ptrCast(@alignCast(ctx));
        self.backing.rawFree(bytes, alignment, ra);
        self.live -= bytes.len;
    }
};

const Buffers = struct {
    allocator: std.mem.Allocator,
    storage: []u8,
    original: []u8,
    input: []const u8,
    output: []u8,
    encoded: []const u8,
    config: Config,

    fn init(a: std.mem.Allocator, encoded: []const u8, expected: []const u8, c: Config) !Buffers {
        const capacity = c.output_capacity orelse expected.len;
        const extent = if (c.alias_offset) |offset| @max(capacity, offset + encoded.len) else capacity;
        const storage = try a.alloc(u8, extent + 16);
        errdefer a.free(storage);
        const original = try a.alloc(u8, storage.len);
        var self = Buffers{ .allocator = a, .storage = storage, .original = original, .input = encoded, .output = storage[8 .. 8 + capacity], .encoded = encoded, .config = c };
        self.refresh();
        return self;
    }
    fn refresh(self: *Buffers) void {
        @memset(self.storage, 0xa5);
        if (self.config.alias_offset) |offset| {
            const target = self.storage[8 + offset ..][0..self.encoded.len];
            @memcpy(target, self.encoded);
            self.input = target;
        } else self.input = self.encoded;
        @memcpy(self.original, self.storage);
    }
    fn attach(self: *Buffers, tracker: *Tracker) void {
        tracker.attach(self.output, self.original[8 .. 8 + self.output.len]);
    }
    fn check(self: *const Buffers, failed: bool) !void {
        if (failed and !std.mem.eql(u8, self.storage, self.original)) return error.CallerChangedOnError;
        if (!std.mem.eql(u8, self.storage[0..8], self.original[0..8]) or !std.mem.eql(u8, self.storage[8 + self.output.len ..], self.original[8 + self.output.len ..])) return error.CallerGuardChanged;
    }
    fn deinit(self: *Buffers) void {
        self.allocator.free(self.storage);
        self.allocator.free(self.original);
    }
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const input_path = args.next() orelse return error.MissingInput;
    const expected_path = args.next() orelse return error.MissingExpected;
    const output_path = args.next() orelse return error.MissingOutput;
    const config_path = args.next() orelse return error.MissingConfig;
    if (args.next() != null) return error.TooManyArguments;
    const encoded = try read(init, input_path);
    defer init.gpa.free(encoded);
    const expected = try read(init, expected_path);
    defer init.gpa.free(expected);
    const config_data = try read(init, config_path);
    defer init.gpa.free(config_data);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, config_data, .{});
    defer parsed.deinit();
    const c = parsed.value;
    var buffers = try Buffers.init(init.gpa, encoded, expected, c);
    defer buffers.deinit();
    var tracker = Tracker{ .backing = init.gpa };
    buffers.attach(&tracker);
    var report = Report{};
    if (std.mem.eql(u8, c.api, "workspace")) {
        var workspace = try lzma.DecodeWorkspace.initWithOptions(tracker.allocator(), options(c));
        const initial = try workspaceCall(&workspace, &buffers, expected, c, &report);
        report.output_written = if (isCount(c)) 0 else initial orelse 0;
        try update(&report, &workspace, &tracker);
        if (report.@"error" == null and c.warm) {
            const attempts = tracker.attempts;
            tracker.deny_alloc = true;
            tracker.deny_resize = true;
            for (0..2) |_| {
                buffers.refresh();
                buffers.attach(&tracker);
                var warm = Report{};
                _ = try workspaceCall(&workspace, &buffers, expected, c, &warm);
                if (warm.@"error" != null) return error.WarmDecodeFailed;
                report.warm_calls += 1;
            }
            report.warm_allocation_attempts = tracker.attempts - attempts;
            if (report.warm_allocation_attempts != 0 or tracker.induced) return error.WarmAllocated;
            tracker.deny_alloc = false;
            tracker.deny_resize = false;
        }
        if (report.@"error" == null and c.lifecycle) {
            workspace.reset();
            try resetCheck(&workspace, &buffers, expected, c, &tracker);
            workspace.resetRetaining();
            try resetCheck(&workspace, &buffers, expected, c, &tracker);
            var moved = workspace;
            workspace = undefined;
            buffers.refresh();
            buffers.attach(&tracker);
            var replay = Report{};
            _ = try workspaceCall(&moved, &buffers, expected, c, &replay);
            if (replay.@"error" != null) return error.MovedWorkspaceFailed;
            workspace = moved;
            try workspace.resetWithOptions(options(c));
            if (workspace.workingMemoryBytes() != 0) return error.ReconfigureRetainedHeap;
            try resetCheck(&workspace, &buffers, expected, c, &tracker);
            report.lifecycle_checks = 4;
        }
        try update(&report, &workspace, &tracker);
        const text = try std.json.Stringify.valueAlloc(init.gpa, workspace.snapshot(), .{});
        defer init.gpa.free(text);
        const snapshot = try std.json.parseFromSlice(std.json.Value, init.gpa, text, .{});
        defer snapshot.deinit();
        report.snapshot = snapshot.value;
        workspace.deinit();
        report.live_after_deinit = tracker.live;
        if (report.live_after_deinit != 0) return error.WorkspaceLeak;
        if (c.oom) report.oom_failure_cases = try checkOom(init.gpa, encoded, expected, c);
        try write(init, report, &buffers, output_path);
    } else {
        const value = callLegacy(tracker.allocator(), buffers.input, buffers.output, expected.len, c) catch |err| blk: {
            report.@"error" = @errorName(err);
            break :blk 0;
        };
        try buffers.check(report.@"error" != null);
        if (report.@"error" == null) {
            if (isCount(c)) report.count = value else report.output_written = value;
            try verify(buffers.output, expected, value, c);
        }
        report.live_after_deinit = tracker.live;
        if (tracker.live != 0) return error.LegacyAllocationLeak;
        if (c.oom) report.oom_failure_cases = try checkOom(init.gpa, encoded, expected, c);
        finishReport(&report, tracker);
        try write(init, report, &buffers, output_path);
    }
}
fn read(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(64 * 1024 * 1024));
}
fn options(c: Config) lzma.DecodeWorkspaceOptions {
    return .{ .max_output_len = c.max_output_len, .max_dictionary_size = c.max_dictionary_size, .max_working_memory = c.max_working_memory };
}
fn isCount(c: Config) bool {
    return std.mem.eql(u8, c.operation, "count");
}
fn workspaceCall(w: *lzma.DecodeWorkspace, b: *Buffers, expected: []const u8, c: Config, r: *Report) !?usize {
    if (c.check_count and std.mem.eql(u8, c.format, "alone")) {
        r.count = w.decodedSize(b.input) catch |err| {
            r.@"error" = @errorName(err);
            try b.check(true);
            return null;
        };
    }
    const n = callWorkspace(w, b.input, b.output, expected.len, c) catch |err| {
        r.@"error" = @errorName(err);
        try b.check(true);
        return null;
    };
    try b.check(false);
    try verify(b.output, expected, n, c);
    if (isCount(c)) r.count = n;
    return n;
}
fn callWorkspace(w: *lzma.DecodeWorkspace, input: []const u8, output: []u8, expected: usize, c: Config) !usize {
    if (std.mem.eql(u8, c.format, "alone")) {
        if (isCount(c)) return w.decodedSizeLimited(input, c.max_output_len);
        return w.decodeInto(input, output);
    }
    if (std.mem.eql(u8, c.format, "micro")) {
        try w.decodeMicroIntoWithOptions(input, output, .{ .dictionary_size = c.dictionary, .max_output_len = c.max_output_len, .allow_partial = c.allow_partial });
        return output.len;
    }
    if (std.mem.eql(u8, c.format, "zip")) return w.decodeZipPayloadInto(input, c.expected_size orelse expected, output, c.max_dictionary_size, c.end_marker);
    return error.UnsupportedFormat;
}
fn callLegacy(a: std.mem.Allocator, input: []const u8, output: []u8, expected: usize, c: Config) !usize {
    if (std.mem.eql(u8, c.api, "alloc")) {
        const decoded = try lzma.decodeAllocWithOptions(a, input, options(c));
        defer a.free(decoded);
        if (decoded.len > output.len) return error.ProbeBufferTooSmall;
        @memcpy(output[0..decoded.len], decoded);
        return decoded.len;
    }
    if (std.mem.eql(u8, c.format, "alone")) {
        if (std.mem.eql(u8, c.api, "with_options")) {
            if (isCount(c)) return lzma.decodedSizeWithOptions(a, input, options(c));
            return lzma.decodeIntoWithOptions(a, input, output, options(c));
        }
        if (isCount(c)) return lzma.decodedSizeLimited(a, input, c.max_output_len);
        return lzma.decodeInto(a, input, output);
    }
    if (std.mem.eql(u8, c.format, "micro")) {
        try lzma.decodeMicroInto(a, input, output, c.dictionary);
        return output.len;
    }
    if (std.mem.eql(u8, c.format, "zip")) return lzma.decodeZipPayloadInto(a, input, c.expected_size orelse expected, output, c.max_dictionary_size, c.end_marker);
    return error.UnsupportedFormat;
}
fn verify(output: []const u8, expected: []const u8, n: usize, c: Config) !void {
    if (n != expected.len or (!isCount(c) and !std.mem.eql(u8, output[0..n], expected))) return error.DecodedMismatch;
}
fn update(r: *Report, w: *const lzma.DecodeWorkspace, tracker: *Tracker) !void {
    const s = w.snapshot();
    if (s.working_bytes != tracker.live or s.working_bytes != w.workingMemoryBytes() or s.retained_decoded_capacity != 0) return error.WorkspaceAccountingMismatch;
    r.peak_working_bytes = @max(r.peak_working_bytes, s.peak_working_bytes);
    r.retained_probability_capacity = @max(r.retained_probability_capacity, s.probability_capacity);
    r.retained_dictionary_capacity = @max(r.retained_dictionary_capacity, s.dictionary_capacity);
    r.retained_input_copy_capacity = @max(r.retained_input_copy_capacity, s.input_copy_capacity);
    r.retained_decoded_capacity = @max(r.retained_decoded_capacity, s.retained_decoded_capacity);
    finishReport(r, tracker.*);
}
fn finishReport(r: *Report, tracker: Tracker) void {
    r.allocation_after_output = tracker.after_output;
    r.allocation_attempts = tracker.attempts;
    r.max_allocation_request = tracker.max_request;
    r.peak_live_bytes = tracker.peak;
}
fn resetCheck(w: *lzma.DecodeWorkspace, b: *Buffers, expected: []const u8, c: Config, tracker: *Tracker) !void {
    const s = w.snapshot();
    if (s.last_decoded_len != 0 or s.last_input_read != 0 or s.peak_working_bytes < s.working_bytes) return error.ResetAccountingMismatch;
    b.refresh();
    b.attach(tracker);
    var r = Report{};
    _ = try workspaceCall(w, b, expected, c, &r);
    if (r.@"error" != null) return error.ResetDecodeFailed;
}
fn checkOom(a: std.mem.Allocator, input: []const u8, expected: []const u8, c: Config) !usize {
    var failures: usize = 0;
    inline for (.{ false, true }) |deny_resize| {
        for (0..128) |index| {
            var b = try Buffers.init(a, input, expected, c);
            defer b.deinit();
            var tracker = Tracker{ .backing = a, .fail_after = index, .deny_resize = deny_resize };
            b.attach(&tracker);
            var r = Report{};
            if (std.mem.eql(u8, c.api, "workspace")) {
                var w = try lzma.DecodeWorkspace.initWithOptions(tracker.allocator(), options(c));
                _ = try workspaceCall(&w, &b, expected, c, &r);
                if (r.@"error") |name| {
                    if (!std.mem.eql(u8, name, "OutOfMemory")) return error.UnexpectedOomError;
                    failures += 1;
                    tracker.fail_after = std.math.maxInt(usize);
                    w.resetRetaining();
                    try resetCheck(&w, &b, expected, c, &tracker);
                    try w.resetWithOptions(options(c));
                    try resetCheck(&w, &b, expected, c, &tracker);
                }
                w.deinit();
            } else {
                const value = callLegacy(tracker.allocator(), b.input, b.output, expected.len, c) catch |err| blk: {
                    if (err != error.OutOfMemory) return error.UnexpectedOomError;
                    try b.check(true);
                    r.@"error" = @errorName(err);
                    failures += 1;
                    break :blk 0;
                };
                if (r.@"error" == null) {
                    try verify(b.output, expected, value, c);
                    try b.check(false);
                }
            }
            if (tracker.live != 0 or tracker.after_output) return error.OomCallerOrHeapChanged;
            if (!tracker.induced) break;
            if (index == 127) return error.OomWalkLimit;
        }
    }
    return failures;
}
fn write(init: std.process.Init, r: Report, b: *const Buffers, path: []const u8) !void {
    if (r.allocation_after_output) return error.AllocationAfterCallerPublication;
    const text = try std.json.Stringify.valueAlloc(init.gpa, r, .{});
    defer init.gpa.free(text);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = b.output[0..r.output_written] });
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    try stdout.interface.writeAll(text);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}
