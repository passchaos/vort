//! Bounded incremental lzip v1 encoder built on the LZMA stream core.

const std = @import("std");
const checksum = @import("../checksum.zig");
const core = @import("../core.zig");
const dictionary = @import("dictionary.zig");
const lzma = @import("../lzma.zig");
const writer = @import("writer.zig");

pub const Encoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    inner: lzma.IncrementalEncoder,
    pending: std.ArrayList(u8) = .empty,
    pending_offset: usize = 0,
    crc: checksum.Crc32Best = checksum.Crc32Best.init(),
    alone_header_remaining: usize = alone_header_size,
    raw_payload_size: usize = 0,
    member_input: usize = 0,
    total_input: usize = 0,
    total_output: usize = 0,
    member_count: usize = 0,
    finishing: bool = false,
    trailer_written: bool = false,
    done: bool = false,

    const alone_header_size: usize = 13;
    const lzip_header_size: usize = 6;
    const trailer_size: usize = 20;

    pub const Error = writer.Error || lzma.Error || std.mem.Allocator.Error;
    pub const Options = struct {
        dictionary_size: u32 = 32 * 1024,
        mode: lzma.EncodeMode = .greedy,
        input_buffer_len: usize = 64 * 1024,
        max_input_len: usize = std.math.maxInt(usize),
        max_pending_output_len: usize = 1024 * 1024,
    };
    pub const Snapshot = struct {
        input_read: usize,
        output_written: usize,
        member_input: usize,
        member_output: usize,
        pending_output: usize,
        member_count: usize,
        member_index: usize,
        finishing: bool,
        trailer_written: bool,
        done: bool,
        retained_output_capacity: usize,
        lzma: lzma.IncrementalEncoder.Snapshot,
    };

    pub fn init(allocator: std.mem.Allocator) Error!Encoder {
        return initWithOptions(allocator, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Error!Encoder {
        const plan = try dictionaryPlan(options);
        var encoder = Encoder{
            .allocator = allocator,
            .options = options,
            .inner = try lzma.IncrementalEncoder.initWithOptions(
                allocator,
                innerOptions(options, plan.match_window),
            ),
        };
        errdefer encoder.inner.deinit();
        try encoder.appendHeader(plan.code);
        return encoder;
    }

    pub fn deinit(self: *Encoder) void {
        self.inner.deinit();
        self.pending.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn reset(self: *Encoder) void {
        self.total_input = 0;
        self.total_output = 0;
        self.member_count = 0;
        self.resetMember(self.options) catch unreachable;
    }

    pub fn nextMember(self: *Encoder, options: Options) Error!void {
        if (!self.done or self.pending_offset != self.pending.items.len)
            return error.InvalidBlockPlan;
        if (self.member_input == 0) return error.InvalidLzipOptions;
        try self.resetMember(options);
    }

    pub fn snapshot(self: *const Encoder) Snapshot {
        return .{
            .input_read = self.total_input,
            .output_written = self.total_output,
            .member_input = self.member_input,
            .member_output = lzip_header_size + self.raw_payload_size +
                @intFromBool(self.trailer_written) * trailer_size,
            .pending_output = self.pending.items.len - self.pending_offset,
            .member_count = self.member_count,
            .member_index = if (self.done and self.member_count != 0)
                self.member_count - 1
            else
                self.member_count,
            .finishing = self.finishing,
            .trailer_written = self.trailer_written,
            .done = self.done,
            .retained_output_capacity = self.pending.capacity,
            .lzma = self.inner.snapshot(),
        };
    }

    pub fn finish(self: *Encoder) void {
        if (!self.done) {
            self.finishing = true;
            self.inner.finish();
        }
    }

    pub fn step(self: *Encoder, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.done) {
            if (input.len != 0) return error.TrailingData;
            return .{ .status = .done };
        }
        if (self.finishing and input.len != 0) return error.TrailingData;
        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) {
            if (self.pending_offset != self.pending.items.len) {
                const remaining = self.pending.items[self.pending_offset..];
                const take = @min(remaining.len, output.len - output_written);
                @memcpy(output[output_written..][0..take], remaining[0..take]);
                self.pending_offset += take;
                output_written += take;
                self.total_output = try checkedAdd(self.total_output, take);
                if (self.pending_offset != self.pending.items.len)
                    return result(input_read, output_written, .need_output);
                self.pending.clearRetainingCapacity();
                self.pending_offset = 0;
                if (output_written == output.len and output.len != 0)
                    return result(input_read, output_written, .need_output);
            }

            var scratch: [4096]u8 = undefined;
            const stepped = try self.inner.step(input[input_read..], &scratch);
            if (stepped.progress.input_read != 0) {
                const accepted = input[input_read..][0..stepped.progress.input_read];
                self.crc.update(accepted);
                input_read += accepted.len;
                self.member_input = try checkedAdd(self.member_input, accepted.len);
                self.total_input = try checkedAdd(self.total_input, accepted.len);
                if (self.total_input > self.options.max_input_len)
                    return error.OutputLimitExceeded;
            }
            try self.acceptInnerOutput(scratch[0..stepped.progress.output_written]);
            if (stepped.progress.output_written != 0) continue;
            if (stepped.status == .need_output) continue;
            if (stepped.status == .done and !self.trailer_written) {
                if (self.alone_header_remaining != 0) return error.InvalidLzmaStream;
                if (self.member_count != 0 and self.member_input == 0)
                    return error.InvalidLzipOptions;
                try self.appendTrailer();
                self.trailer_written = true;
                continue;
            }
            if (stepped.status == .done) {
                self.member_count = try checkedAdd(self.member_count, 1);
                self.done = true;
                return result(input_read, output_written, .done);
            }
            return result(input_read, output_written, .need_input);
        }
    }

    fn resetMember(self: *Encoder, options: Options) Error!void {
        const plan = try dictionaryPlan(options);
        var replacement = try lzma.IncrementalEncoder.initWithOptions(
            self.allocator,
            innerOptions(options, plan.match_window),
        );
        errdefer replacement.deinit();
        self.inner.deinit();
        self.inner = replacement;
        self.options = options;
        self.pending.clearRetainingCapacity();
        self.pending_offset = 0;
        self.crc = checksum.Crc32Best.init();
        self.alone_header_remaining = alone_header_size;
        self.raw_payload_size = 0;
        self.member_input = 0;
        self.finishing = false;
        self.trailer_written = false;
        self.done = false;
        try self.appendHeader(plan.code);
    }

    fn acceptInnerOutput(self: *Encoder, bytes: []const u8) Error!void {
        const skip = @min(self.alone_header_remaining, bytes.len);
        self.alone_header_remaining -= skip;
        const payload = bytes[skip..];
        if (payload.len == 0) return;
        try self.pending.appendSlice(self.allocator, payload);
        self.raw_payload_size = try checkedAdd(self.raw_payload_size, payload.len);
        try self.checkPendingLimit();
    }

    fn appendHeader(self: *Encoder, code: u8) Error!void {
        try self.pending.appendSlice(self.allocator, "LZIP\x01");
        try self.pending.append(self.allocator, code);
        try self.checkPendingLimit();
    }

    fn appendTrailer(self: *Encoder) Error!void {
        const member_size = std.math.add(
            usize,
            lzip_header_size + trailer_size,
            self.raw_payload_size,
        ) catch return error.IntegerOverflow;
        var trailer: [trailer_size]u8 = undefined;
        std.mem.writeInt(u32, trailer[0..4], self.crc.digest(), .little);
        std.mem.writeInt(u64, trailer[4..12], self.member_input, .little);
        std.mem.writeInt(u64, trailer[12..20], member_size, .little);
        try self.pending.appendSlice(self.allocator, &trailer);
        try self.checkPendingLimit();
    }

    fn checkPendingLimit(self: *const Encoder) Error!void {
        if (self.pending.items.len - self.pending_offset >
            self.options.max_pending_output_len)
            return error.OutputLimitExceeded;
    }

    const DictionaryPlan = struct { code: u8, match_window: u32 };

    fn dictionaryPlan(options: Options) Error!DictionaryPlan {
        const encoded = dictionary.encodeCeiling(options.dictionary_size) orelse
            return error.InvalidLzipOptions;
        if (options.mode == .lazy or options.input_buffer_len == 0 or
            options.max_pending_output_len < lzip_header_size)
            return error.InvalidLzipOptions;
        return .{
            .code = encoded.code,
            .match_window = @intCast(@min(
                @as(usize, encoded.size),
                std.math.maxInt(u16),
            )),
        };
    }

    fn innerOptions(options: Options, match_window: u32) lzma.IncrementalEncoder.Options {
        return .{
            .dictionary_size = match_window,
            .mode = options.mode,
            .size_mode = .end_marker,
            .input_buffer_len = options.input_buffer_len,
            .max_input_len = options.max_input_len,
            .max_pending_output_len = options.max_pending_output_len,
        };
    }

    fn checkedAdd(a: usize, b: usize) Error!usize {
        return std.math.add(usize, a, b) catch error.IntegerOverflow;
    }

    fn result(
        input_read: usize,
        output_written: usize,
        status: core.StepResult.Status,
    ) core.StepResult {
        return .{
            .progress = .{
                .input_read = input_read,
                .output_written = output_written,
            },
            .status = status,
        };
    }
};
