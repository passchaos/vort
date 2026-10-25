//! Queue-owned Block storage. Only a completed front Job is handed to the
//! coordinator; its bytes stay owned until the final output byte is delivered.
const std = @import("std");
const writer = @import("../writer.zig");
const settings = @import("../../lzma/encode_options.zig");
const types = @import("types.zig");

pub const State = enum { free, filling, queued, active, complete, delivering };
pub const Job = struct {
    state: State = .free,
    ordinal: usize = 0,
    plain: std.ArrayList(u8) = .empty,
    output: std.ArrayList(u8) = .empty,
    record: writer.BlockRecord = undefined,
    work: settings.EncodeWorkProfile = .{},
    first_error: ?types.Error = null,
    merged: bool = false,
    indexed: bool = false,
    output_offset: usize = 0,

    pub fn clear(self: *Job) void {
        self.plain.clearRetainingCapacity();
        self.output.clearRetainingCapacity();
        self.state = .free;
        self.ordinal = 0;
        self.work = .{};
        self.first_error = null;
        self.merged = false;
        self.indexed = false;
        self.output_offset = 0;
    }

    pub fn deinit(self: *Job, allocator: std.mem.Allocator) void {
        self.plain.deinit(allocator);
        self.output.deinit(allocator);
        self.* = .{};
    }
};

pub fn mergeWork(destination: ?*settings.EncodeWorkProfile, work: settings.EncodeWorkProfile) void {
    const output = destination orelse return;
    inline for (@typeInfo(settings.EncodeWorkProfile).@"struct".fields) |field| {
        if (comptime std.mem.eql(u8, field.name, "finder") or
            std.mem.startsWith(u8, field.name, "effective_"))
        {
            @field(output, field.name) = @field(work, field.name);
        } else if (comptime std.mem.indexOf(u8, field.name, "peak_working_memory") != null) {
            @field(output, field.name) = @max(@field(output, field.name), @field(work, field.name));
        } else {
            @field(output, field.name) +|= @field(work, field.name);
        }
    }
}
