//! Frozen full-doubling BWT from the pre-extraction encoder.
//! Keep all rounds even when every cyclic rotation already has a unique class.
const std = @import("std");
pub const Block = struct {
    bytes: []u8,
    original_pointer: u32,

    pub fn deinit(self: Block, allocator: std.mem.Allocator) void {
        allocator.free(self.bytes);
    }
};

pub fn transformAlloc(allocator: std.mem.Allocator, input: []const u8) !Block {
    if (input.len == 0 or input.len > 900_000) return error.InvalidBzip2Stream;
    const order_a = try allocator.alloc(u32, input.len);
    defer allocator.free(order_a);
    const order_b = try allocator.alloc(u32, input.len);
    defer allocator.free(order_b);
    const classes_a = try allocator.alloc(u32, input.len);
    defer allocator.free(classes_a);
    const classes_b = try allocator.alloc(u32, input.len);
    defer allocator.free(classes_b);
    const counts = try allocator.alloc(usize, @max(input.len, 256));
    defer allocator.free(counts);

    @memset(counts[0..256], 0);
    for (input) |byte| counts[byte] += 1;
    var total: usize = 0;
    for (counts[0..256]) |*count| {
        const frequency = count.*;
        count.* = total;
        total += frequency;
    }
    for (input, 0..) |byte, index| {
        order_a[counts[byte]] = @intCast(index);
        counts[byte] += 1;
    }

    var class_count: usize = 1;
    classes_a[order_a[0]] = 0;
    for (1..input.len) |index| {
        if (input[order_a[index]] != input[order_a[index - 1]]) class_count += 1;
        classes_a[order_a[index]] = @intCast(class_count - 1);
    }

    const order = order_a;
    const next_order = order_b;
    var classes = classes_a;
    var next_classes = classes_b;
    var shift: usize = 1;
    while (shift < input.len) : (shift *= 2) {
        for (order, next_order) |position_u32, *shifted| {
            const position: usize = position_u32;
            shifted.* = @intCast(if (position >= shift) position - shift else position + input.len - shift);
        }

        @memset(counts[0..class_count], 0);
        for (next_order) |position| counts[classes[position]] += 1;
        total = 0;
        for (counts[0..class_count]) |*count| {
            const frequency = count.*;
            count.* = total;
            total += frequency;
        }
        for (next_order) |position| {
            const class = classes[position];
            order[counts[class]] = position;
            counts[class] += 1;
        }

        var next_class_count: usize = 1;
        next_classes[order[0]] = 0;
        for (1..input.len) |index| {
            const current: usize = order[index];
            const previous: usize = order[index - 1];
            const current_pair = .{ classes[current], classes[(current + shift) % input.len] };
            const previous_pair = .{ classes[previous], classes[(previous + shift) % input.len] };
            if (current_pair[0] != previous_pair[0] or current_pair[1] != previous_pair[1])
                next_class_count += 1;
            next_classes[current] = @intCast(next_class_count - 1);
        }
        class_count = next_class_count;
        std.mem.swap([]u32, &classes, &next_classes);
    }

    const transformed = try allocator.alloc(u8, input.len);
    errdefer allocator.free(transformed);
    var original_pointer: ?u32 = null;
    for (order, 0..) |start_u32, row| {
        const start: usize = start_u32;
        transformed[row] = input[if (start == 0) input.len - 1 else start - 1];
        if (start == 0) original_pointer = @intCast(row);
    }
    return .{
        .bytes = transformed,
        .original_pointer = original_pointer orelse return error.InvalidBzip2Stream,
    };
}
