const std = @import("std");
const codec = @import("codec");
pub const zip = codec.zip;
pub const chunk_len = 65536;
pub const repeated = [_]u8{'R'} ** chunk_len;
const Crc = @FieldType(zip.IncrementalEntryDecoder, "crc");

pub fn require(ok: bool) !void {
    if (!ok) return error.ZipWideReadOracleMismatch;
}
pub const Receipt = struct {
    input_read: u64 = 0,
    output_written: u64 = 0,
    calls: u64 = 0,
    crc32: u32 = 0,
    completed: bool = false,
    counter_bits: usize = 0,
    progress_bits: usize = 0,
    entry_headers: u64 = 0,
    entry_done: u64 = 0,
};
pub const OutputCheck = struct {
    expected: u64,
    crc: Crc = Crc.init(),
    receipt: Receipt = .{},
    output: [chunk_len]u8 = undefined,
    pub fn step(self: *OutputCheck, decoder: anytype, input: []const u8) !usize {
        const before = decoder.snapshot();
        const count: usize = @intCast(@min(self.expected - self.receipt.output_written, self.output.len));
        const result = try decoder.step(input, self.output[0..count]);
        try require(result.progress.input_read <= input.len and result.progress.output_written <= count);
        const output = self.output[0..result.progress.output_written];
        try require(std.mem.eql(u8, output, repeated[0..output.len]));
        self.crc.update(output);
        self.receipt.input_read = try std.math.add(u64, self.receipt.input_read, @intCast(result.progress.input_read));
        self.receipt.output_written = try std.math.add(u64, self.receipt.output_written, @intCast(output.len));
        self.receipt.calls += 1;
        self.receipt.completed = result.status == .done;
        const after = decoder.snapshot();
        self.receipt.counter_bits = @bitSizeOf(@TypeOf(after.output_written));
        self.receipt.progress_bits = @bitSizeOf(@TypeOf(result.progress.input_read));
        try require(self.receipt.counter_bits == 64);
        try require(after.input_read == before.input_read + result.progress.input_read and after.output_written == before.output_written + output.len);
        try require(after.input_read == self.receipt.input_read and after.output_written == self.receipt.output_written);
        if (@hasField(@TypeOf(after), "last_step_progress")) try require(std.meta.eql(after.last_step_progress, result.progress));
        if (@TypeOf(result.status) == zip.IncrementalReaderStepResult.Status) {
            if (result.status == .entry_header) self.receipt.entry_headers += 1;
            if (result.status == .entry_done) self.receipt.entry_done += 1;
            if (result.status == .entry_header or result.status == .entry_done) return result.progress.input_read;
        }
        if (!self.receipt.completed and result.progress.input_read == 0 and output.len == 0) return error.NoProgress;
        return result.progress.input_read;
    }
    pub fn finish(self: *OutputCheck, decoder: anytype, expected_input: u64, expected_crc: u32) !Receipt {
        try decoder.finish();
        try require(self.receipt.completed and self.receipt.input_read == expected_input and self.receipt.output_written == self.expected);
        self.receipt.crc32 = self.crc.digest();
        try require(self.receipt.crc32 == expected_crc);
        return self.receipt;
    }
};

pub const DeniedAllocator = struct {
    attempts: usize = 0,
    pub fn allocator(self: *DeniedAllocator) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn alloc(raw: *anyopaque, _: usize, _: std.mem.Alignment, _: usize) ?[*]u8 {
        const self: *DeniedAllocator = @ptrCast(@alignCast(raw));
        self.attempts += 1;
        return null;
    }
    fn resize(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) bool {
        return false;
    }
    fn remap(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) ?[*]u8 {
        return null;
    }
    fn free(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize) void {
        unreachable;
    }
};
