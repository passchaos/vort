const std = @import("std");
const fuzz_target = @import("fuzz_target.zig");

export fn LLVMFuzzerTestOneInput(data: [*]const u8, len: usize) c_int {
    var gpa_state = std.heap.DebugAllocator(.{}){};
    defer _ = gpa_state.deinit();
    const allocator = gpa_state.allocator();
    fuzz_target.fuzzOne(allocator, data[0..len]) catch return 1;
    return 0;
}

pub fn main() !void {
    const sample = [_]u8{ 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00 };
    if (LLVMFuzzerTestOneInput(&sample, sample.len) != 0) return error.FuzzSmokeFailed;
    std.debug.print("libfuzzer entry smoke: ok\n", .{});
}
