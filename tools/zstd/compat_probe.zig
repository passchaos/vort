const std = @import("std");
const vort = @import("vort");
const libzstd = @import("libzstd_runtime.zig");

const levels = [_]c_int{ 1, 3, 9, 19 };
const sizes = [_]usize{ 0, 1, 15, 64, 255, 1024, 8192, 65536, 131073, 524288 };

const Shape = enum { text, structured, binary, random };

pub fn main(init: std.process.Init) !void {
    var runtime = try libzstd.Runtime.open();
    defer runtime.deinit();
    var checked: usize = 0;
    var unsupported: usize = 0;
    for (std.meta.tags(Shape)) |shape| {
        for (sizes) |size| {
            const payload = try init.gpa.alloc(u8, size);
            defer init.gpa.free(payload);
            fill(shape, payload);
            for (levels) |level| {
                const encoded = try runtime.encodeAlloc(init.gpa, payload, level);
                defer init.gpa.free(encoded);
                const decoded = vort.zstdDecodeFrameAlloc(init.gpa, encoded) catch |err| {
                    unsupported += 1;
                    std.debug.print(
                        "zstd_compat_unsupported shape={s} size={d} level={d} encoded={d} error={s}\n",
                        .{ @tagName(shape), size, level, encoded.len, @errorName(err) },
                    );
                    continue;
                };
                defer init.gpa.free(decoded);
                if (!std.mem.eql(u8, payload, decoded)) return error.SizeMismatch;
                checked += 1;
            }
        }
    }
    if (unsupported != 0) return error.UnsupportedZstdFeature;
    std.debug.print(
        "zstd_compat_probe checked={d} unsupported={d} version={s}\n",
        .{ checked, unsupported, runtime.version() },
    );
}

fn fill(shape: Shape, payload: []u8) void {
    switch (shape) {
        .text => {
            const unit = "Zstandard compatibility corpus with repeated words and punctuation.\n";
            for (payload, 0..) |*byte, index| byte.* = unit[index % unit.len];
        },
        .structured => {
            const unit = "{\"service\":\"vort\",\"value\":12345,\"ok\":true}\n";
            for (payload, 0..) |*byte, index| byte.* = unit[index % unit.len];
        },
        .binary => for (payload, 0..) |*byte, index| {
            byte.* = if (index % 64 < 48) @truncate(index * 17) else @truncate(index * 73 + index / 31);
        },
        .random => {
            var state: u32 = 0x7a57_1b5d;
            for (payload) |*byte| {
                state = state *% 1_664_525 +% 1_013_904_223;
                byte.* = @truncate(state >> 16);
            }
        },
    }
}
