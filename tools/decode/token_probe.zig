//! One-off token-distribution probe for the semantic Deflate hot loop.
//! Decodes a frozen raw wire and reports literal vs match token counts and
//! match length/distance histograms so the next register-lifetime experiment
//! targets the actual payload shape rather than a guessed layout.
const std = @import("std");
const vort = @import("vort");

const Histogram = struct {
    counts: [259]u64 = [_]u64{0} ** 259,

    fn add(self: *Histogram, value: usize) void {
        if (value < self.counts.len) self.counts[value] += 1;
    }
};

pub fn main(init: std.process.Init) !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const a = gpa.allocator();

    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const wire_path = args.next() orelse return error.MissingWire;
    const plain_path = args.next() orelse return error.MissingPlain;

    const wire = try std.Io.Dir.cwd().readFileAlloc(init.io, wire_path, a, .limited(1 << 30));
    defer a.free(wire);
    const plain = try std.Io.Dir.cwd().readFileAlloc(init.io, plain_path, a, .limited(1 << 30));
    defer a.free(plain);

    const decoded = try vort.decodeRawDeflateAlloc(a, wire);
    defer a.free(decoded);
    if (!std.mem.eql(u8, decoded, plain)) return error.OutputMismatch;

    // Re-walk the wire with a counting parser layered on the public bit
    // reader. This stays read-only and mirrors the block header grammar the
    // semantic decoder consumes, without touching production code.
    var reader = vort.bitstream.BufferedBitReader.init(wire);
    var total_literals: u64 = 0;
    var total_matches: u64 = 0;
    var length_hist = Histogram{};
    var distance_hist = Histogram{};
    var final_block = false;
    while (!final_block) {
        final_block = try reader.readBits(u1, 1) != 0;
        const block_type = try reader.readBits(u2, 2);
        if (block_type != 2) return error.UnsupportedBlockType;
        const hlit = try reader.readBits(u16, 5);
        const hdist = try reader.readBits(u16, 5);
        const hclen = try reader.readBits(u16, 4);
        const literal_count = @as(usize, hlit) + 257;
        const distance_count = @as(usize, hdist) + 1;
        const code_length_count = @as(usize, hclen) + 4;
        const cl_order = [_]usize{ 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 };
        var cl_lengths: [19]u8 = @splat(0);
        for (cl_order[0..code_length_count]) |index| {
            cl_lengths[index] = try reader.readBits(u8, 3);
        }
        const cl_table = try vort.huffman.HuffmanTable(19).init(@ptrCast(&cl_lengths));

        var all_lengths = try a.alloc(u8, literal_count + distance_count);
        defer a.free(all_lengths);
        @memset(all_lengths, 0);
        var index: usize = 0;
        while (index < all_lengths.len) {
            const symbol = try cl_table.decodeValue(&reader);
            switch (symbol) {
                0...15 => {
                    all_lengths[index] = @intCast(symbol);
                    index += 1;
                },
                16 => {
                    const repeat = 3 + try reader.readBits(u16, 2);
                    if (index == 0) return error.InvalidRepeat;
                    const previous = all_lengths[index - 1];
                    for (0..repeat) |_| {
                        all_lengths[index] = previous;
                        index += 1;
                    }
                },
                17 => {
                    const repeat = 3 + try reader.readBits(u16, 3);
                    index += repeat;
                },
                18 => {
                    const repeat = 11 + try reader.readBits(u16, 7);
                    index += repeat;
                },
                else => return error.InvalidCodeLengthSymbol,
            }
        }

        const lit_table = try vort.huffman.HuffmanTable(286).init(@ptrCast(all_lengths[0..literal_count]));
        const dist_table = try vort.huffman.HuffmanTable(30).init(@ptrCast(all_lengths[literal_count..]));

        while (true) {
            const symbol = try lit_table.decodeValue(&reader);
            if (symbol < 256) {
                total_literals += 1;
                continue;
            }
            if (symbol == 256) break;
            const length = blk: {
                const meta = lengthMetadata(symbol);
                break :blk meta.base + try reader.readBits(usize, meta.extra_bits);
            };
            const distance_symbol = try dist_table.decodeValue(&reader);
            const distance = blk: {
                const meta = distanceMetadata(distance_symbol);
                break :blk meta.base + try reader.readBits(usize, meta.extra_bits);
            };
            total_matches += 1;
            length_hist.add(length);
            distance_hist.add(distance);
        }
    }

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("tokens literals={d} matches={d} literal_share={d:.4}\n", .{
        total_literals,
        total_matches,
        @as(f64, @floatFromInt(total_literals)) / @as(f64, @floatFromInt(total_literals + total_matches)),
    });
    printTop(stdout, "length", &length_hist, 10) catch {};
    printTop(stdout, "distance", &distance_hist, 10) catch {};
    try stdout.flush();
}

const LengthMeta = struct { base: usize, extra_bits: u6 };

fn lengthMetadata(symbol: u16) LengthMeta {
    const table = [_]LengthMeta{
        .{ .base = 3, .extra_bits = 0 },   .{ .base = 4, .extra_bits = 0 },
        .{ .base = 5, .extra_bits = 0 },   .{ .base = 6, .extra_bits = 0 },
        .{ .base = 7, .extra_bits = 0 },   .{ .base = 8, .extra_bits = 0 },
        .{ .base = 9, .extra_bits = 0 },   .{ .base = 10, .extra_bits = 0 },
        .{ .base = 11, .extra_bits = 1 },  .{ .base = 13, .extra_bits = 1 },
        .{ .base = 15, .extra_bits = 1 },  .{ .base = 17, .extra_bits = 1 },
        .{ .base = 19, .extra_bits = 2 },  .{ .base = 23, .extra_bits = 2 },
        .{ .base = 27, .extra_bits = 2 },  .{ .base = 31, .extra_bits = 2 },
        .{ .base = 35, .extra_bits = 3 },  .{ .base = 43, .extra_bits = 3 },
        .{ .base = 51, .extra_bits = 3 },  .{ .base = 59, .extra_bits = 3 },
        .{ .base = 67, .extra_bits = 4 },  .{ .base = 83, .extra_bits = 4 },
        .{ .base = 99, .extra_bits = 4 },  .{ .base = 115, .extra_bits = 4 },
        .{ .base = 131, .extra_bits = 5 }, .{ .base = 163, .extra_bits = 5 },
        .{ .base = 195, .extra_bits = 5 }, .{ .base = 227, .extra_bits = 5 },
        .{ .base = 258, .extra_bits = 0 },
    };
    return table[symbol - 257];
}

fn distanceMetadata(symbol: u16) LengthMeta {
    const table = [_]LengthMeta{
        .{ .base = 1, .extra_bits = 0 },      .{ .base = 2, .extra_bits = 0 },
        .{ .base = 3, .extra_bits = 0 },      .{ .base = 4, .extra_bits = 0 },
        .{ .base = 5, .extra_bits = 1 },      .{ .base = 7, .extra_bits = 1 },
        .{ .base = 9, .extra_bits = 2 },      .{ .base = 13, .extra_bits = 2 },
        .{ .base = 17, .extra_bits = 3 },     .{ .base = 25, .extra_bits = 3 },
        .{ .base = 33, .extra_bits = 4 },     .{ .base = 49, .extra_bits = 4 },
        .{ .base = 65, .extra_bits = 5 },     .{ .base = 97, .extra_bits = 5 },
        .{ .base = 129, .extra_bits = 6 },    .{ .base = 193, .extra_bits = 6 },
        .{ .base = 257, .extra_bits = 7 },    .{ .base = 385, .extra_bits = 7 },
        .{ .base = 513, .extra_bits = 8 },    .{ .base = 769, .extra_bits = 8 },
        .{ .base = 1025, .extra_bits = 9 },   .{ .base = 1537, .extra_bits = 9 },
        .{ .base = 2049, .extra_bits = 10 },  .{ .base = 3073, .extra_bits = 10 },
        .{ .base = 4097, .extra_bits = 11 },  .{ .base = 6145, .extra_bits = 11 },
        .{ .base = 8193, .extra_bits = 12 },  .{ .base = 12289, .extra_bits = 12 },
        .{ .base = 16385, .extra_bits = 13 }, .{ .base = 24577, .extra_bits = 13 },
    };
    return table[symbol];
}

fn printTop(writer: anytype, label: []const u8, hist: *const Histogram, limit: usize) !void {
    var entries: [259]struct { value: usize, count: u64 } = undefined;
    for (&entries, 0..) |*entry, index| entry.* = .{ .value = index, .count = hist.counts[index] };
    std.mem.sort(@TypeOf(entries[0]), &entries, {}, struct {
        fn lessThan(_: void, lhs: @TypeOf(entries[0]), rhs: @TypeOf(entries[0])) bool {
            return lhs.count > rhs.count;
        }
    }.lessThan);
    try writer.print("{s} top:", .{label});
    for (entries[0..limit]) |entry| {
        if (entry.count == 0) break;
        try writer.print(" {d}={d}", .{ entry.value, entry.count });
    }
    try writer.writeByte('\n');
}
