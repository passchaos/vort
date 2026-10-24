const std = @import("std");
const br = @import("../../br.zig");
const total = @import("total_budget.zig");

test "Brotli stored memory scratch only protects borrows overlapping actual destination" {
    const plain = "initialized retained tail payload";
    const metadata = "tail-meta";
    for ([_]bool{ false, true }) |chunked| {
        var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{});
        {
            var encoder = br.StoredStreamEncoder.init(failing.allocator());
            defer encoder.deinit();
            try encoder.scratch.ensureTotalCapacity(encoder.allocator, 1024);
            const physical = encoder.scratch.allocatedSlice();
            // All borrowed tail bytes and descriptor storage are initialized
            // even though they lie outside the previous logical output.
            @memset(physical, 0xa5);
            encoder.scratch.items.len = 64;
            @memcpy(physical[256..][0..plain.len], plain);
            @memcpy(physical[384..][0..metadata.len], metadata);
            const descriptors: *[3][]const u8 = @ptrCast(@alignCast(physical[512..].ptr));
            descriptors.* = .{ physical[256..267], "", physical[267..][0 .. plain.len - 11] };
            const before = try std.testing.allocator.dupe(u8, physical);
            defer std.testing.allocator.free(before);
            const capacity = encoder.scratch.capacity;
            const retained = capacity + total.control_bytes;
            const attempts = failing.alloc_index;
            var profile: br.EncodeMemoryProfile = .{};
            const options: br.StoredStreamOptions = .{
                .max_total_working_memory = retained,
                .memory_profile = &profile,
                .metadata = physical[384..][0..metadata.len],
            };
            const needed = if (chunked)
                try br.encodedStoredStreamChunksBoundWithOptions(descriptors, options)
            else
                try br.encodedStoredStreamBoundWithOptions(plain.len, options);
            try std.testing.expect(needed < 256);
            const actual = if (chunked)
                try encoder.encodeChunksScratchWithOptions(descriptors, options)
            else
                try encoder.encodeScratchWithOptions(physical[256..][0..plain.len], options);
            try std.testing.expectEqual(needed, actual.len);
            const decoded = try br.decodeStreamAlloc(std.testing.allocator, actual);
            defer std.testing.allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, plain, decoded);
            try std.testing.expectEqualSlices(u8, before[needed..], physical[needed..]);
            try std.testing.expectEqual(attempts + 1, failing.alloc_index);
            try std.testing.expectEqual(retained, failing.allocated_bytes - failing.freed_bytes);
            try std.testing.expectEqual(capacity, encoder.scratch.capacity);
            try std.testing.expectEqual(retained, encoder.retainedCapacity());
            try std.testing.expectEqual(retained, profile.peak_requested_bytes);
            try std.testing.expectEqual(retained, profile.live_requested_bytes);

            // Moving the payload across the actual write region still needs a
            // charged snapshot and must fail before changing retained output.
            @memcpy(physical[8..][0..plain.len], plain);
            descriptors.* = .{ physical[8..19], "", physical[19..][0 .. plain.len - 11] };
            const before_overlap = try std.testing.allocator.dupe(u8, physical);
            defer std.testing.allocator.free(before_overlap);
            const old_length = encoder.scratch.items.len;
            profile.reset();
            if (chunked) {
                try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.encodeChunksScratchWithOptions(descriptors, options));
            } else {
                try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.encodeScratchWithOptions(physical[8..][0..plain.len], options));
            }
            try std.testing.expectEqualSlices(u8, before_overlap, physical);
            try std.testing.expectEqual(old_length, encoder.scratch.items.len);
            try std.testing.expectEqual(capacity, encoder.scratch.capacity);
            try std.testing.expectEqual(attempts + 1, failing.alloc_index);
            try std.testing.expectEqual(retained, failing.allocated_bytes - failing.freed_bytes);
        }
        try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
    }
}
