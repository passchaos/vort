const std = @import("std");
const vort = @import("vort");

const CountingAllocator = struct {
    backing: std.mem.Allocator,
    allocations: usize = 0,
    resizes: usize = 0,
    remaps: usize = 0,
    allocated_bytes: usize = 0,
    freed_bytes: usize = 0,
    live_bytes: usize = 0,
    peak_bytes: usize = 0,

    fn allocator(self: *@This()) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{
            .alloc = alloc,
            .resize = resize,
            .remap = remap,
            .free = free,
        } };
    }

    fn change(self: *@This(), old_len: usize, new_len: usize) void {
        if (new_len >= old_len) {
            self.allocated_bytes += new_len - old_len;
        } else {
            self.freed_bytes += old_len - new_len;
        }
        self.live_bytes = self.live_bytes - old_len + new_len;
        self.peak_bytes = @max(self.peak_bytes, self.live_bytes);
    }

    fn alloc(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
        const self: *@This() = @ptrCast(@alignCast(raw));
        const memory = self.backing.rawAlloc(len, alignment, ret) orelse return null;
        self.allocations += 1;
        self.change(0, len);
        return memory;
    }

    fn resize(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) bool {
        const self: *@This() = @ptrCast(@alignCast(raw));
        self.resizes += 1;
        if (!self.backing.rawResize(memory, alignment, len, ret)) return false;
        self.change(memory.len, len);
        return true;
    }

    fn remap(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) ?[*]u8 {
        const self: *@This() = @ptrCast(@alignCast(raw));
        self.remaps += 1;
        const result = self.backing.rawRemap(memory, alignment, len, ret) orelse return null;
        self.change(memory.len, len);
        return result;
    }

    fn free(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret: usize) void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        self.backing.rawFree(memory, alignment, ret);
        self.change(memory.len, 0);
    }
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const input_path = args.next() orelse return error.MissingPath;
    const level = try std.fmt.parseInt(u4, args.next() orelse "9", 10);
    const input = try std.Io.Dir.cwd().readFileAlloc(
        init.io,
        input_path,
        init.gpa,
        .limited(128 * 1024 * 1024),
    );
    defer init.gpa.free(input);

    var counter = CountingAllocator{ .backing = init.gpa };
    const allocator = counter.allocator();
    const encoded = try vort.encodeRawLevelAlloc(allocator, input, level);
    const wire_bytes = encoded.len;
    const live_with_result = counter.live_bytes;
    allocator.free(encoded);
    if (counter.live_bytes != 0 or counter.allocated_bytes != counter.freed_bytes)
        return error.AllocationAccountingMismatch;

    var buffer: [512]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try stdout_writer.interface.print(
        "input_bytes={d} wire_bytes={d} allocations={d} resizes={d} remaps={d} allocated_bytes={d} peak_bytes={d} live_with_result={d}\n",
        .{
            input.len,
            wire_bytes,
            counter.allocations,
            counter.resizes,
            counter.remaps,
            counter.allocated_bytes,
            counter.peak_bytes,
            live_with_result,
        },
    );
    try stdout_writer.interface.flush();
}
