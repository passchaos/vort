const std = @import("std");
const h = @import("common.zig");
const zip = h.zip;
pub const Metadata = struct { method: zip.CompressionMethod, compressed_size: u64, uncompressed_size: u64, crc32: u32, metadata_count_bits: usize, zip64: bool, canonical_parse: bool };
pub const Result = struct { receipt: h.Receipt, metadata: Metadata, limit_refusals: usize, physical_extract_refusals: usize = 0, central_offset: ?u64 = null };

pub fn entry(init: std.process.Init, path: []const u8, count: u64, owned: bool) !Result {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
    defer init.gpa.free(bytes);
    const archive = try zip.parse(bytes);
    const canonical = try archive.entryAt(0);
    try h.require(archive.entry_count == 1 and canonical.uncompressed_size == count and std.mem.eql(u8, canonical.name, "wide.bin"));
    const data = try archive.rawEntryData(canonical);
    var history: [zip.IncrementalEntryDecoder.required_history_len]u8 = undefined;
    const settings: zip.IncrementalEntryDecoderOptions = .{ .max_output_len = count };
    var lower = settings;
    lower.max_output_len = count - 1;
    if (owned) {
        if (zip.OwnedIncrementalEntryDecoder.initWithOptions(init.gpa, canonical, lower)) |unexpected| {
            var cleanup = unexpected;
            cleanup.deinit();
            return error.ExpectedEntryLimit;
        } else |err| try h.require(err == error.OutputLimitExceeded);
    } else {
        if (zip.IncrementalEntryDecoder.initWithOptions(canonical, &history, lower)) |_| return error.ExpectedEntryLimit else |err| try h.require(err == error.OutputLimitExceeded);
    }
    var physical_refusals: usize = 0;
    if (@bitSizeOf(usize) == 32 and count > std.math.maxInt(usize)) {
        var denied: h.DeniedAllocator = .{};
        if (archive.extractAlloc(denied.allocator(), canonical)) |_| return error.ExpectedPhysicalExtractLimit else |err| try h.require(err == error.IntegerOverflow);
        try h.require(denied.attempts == 0);
        physical_refusals = 1;
    }
    var receipt: h.Receipt = undefined;
    if (owned) {
        var decoder = try zip.OwnedIncrementalEntryDecoder.initWithOptions(init.gpa, canonical, settings);
        defer decoder.deinit();
        receipt = try member(&decoder, data, count, canonical.crc32);
    } else {
        var decoder = try zip.IncrementalEntryDecoder.initWithOptions(canonical, &history, settings);
        receipt = try member(&decoder, data, count, canonical.crc32);
    }
    return .{ .receipt = receipt, .metadata = .{ .method = canonical.method, .compressed_size = @intCast(canonical.compressed_size), .uncompressed_size = canonical.uncompressed_size, .crc32 = canonical.crc32, .metadata_count_bits = @bitSizeOf(@TypeOf(canonical.uncompressed_size)), .zip64 = canonical.zip64, .canonical_parse = true }, .limit_refusals = 1, .physical_extract_refusals = physical_refusals };
}

fn member(decoder: anytype, data: []const u8, count: u64, crc: u32) !h.Receipt {
    var check: h.OutputCheck = .{ .expected = count };
    var offset: usize = 0;
    while (!check.receipt.completed) {
        const end = offset + @min(h.chunk_len, data.len - offset);
        offset += try check.step(decoder, data[offset..end]);
    }
    return check.finish(decoder, @intCast(data.len), crc);
}

pub fn archiveSource(init: std.process.Init, path: []const u8, count: u64, crc: u32) !Result {
    var decoder = try zip.IncrementalReader.initWithOptions(init.gpa, .{ .max_entry_output_len = count, .max_total_output_len = count });
    defer decoder.deinit();
    const file = try std.Io.Dir.cwd().openFile(init.io, path, .{});
    defer file.close(init.io);
    const length = try file.length(init.io);
    var source_buffer: [h.chunk_len]u8 = undefined;
    var source = file.readerStreaming(init.io, &source_buffer);
    var input: [h.chunk_len]u8 = undefined;
    var check: h.OutputCheck = .{ .expected = count };
    while (true) {
        const len = try source.interface.readSliceShort(&input);
        if (len == 0) break;
        var offset: usize = 0;
        while (offset < len) {
            try h.require(!check.receipt.completed);
            offset += try check.step(&decoder, input[offset..len]);
        }
    }
    while (!check.receipt.completed) _ = try check.step(&decoder, &.{});
    const receipt = try check.finish(&decoder, length, crc);
    const metadata = decoder.entryAt(0) orelse return error.MissingReaderEntry;
    try h.require(metadata.uncompressed_size == count and metadata.crc32 == crc and std.mem.eql(u8, metadata.name, "wide.bin"));
    try h.require(receipt.entry_headers == 1 and receipt.entry_done == 1 and decoder.snapshot().completed_entries == 1);
    return .{ .receipt = receipt, .metadata = .{ .method = metadata.method, .compressed_size = metadata.compressed_size.?, .uncompressed_size = metadata.uncompressed_size.?, .crc32 = metadata.crc32.?, .metadata_count_bits = @bitSizeOf(@typeInfo(@TypeOf(metadata.uncompressed_size)).optional.child), .zip64 = metadata.zip64_local, .canonical_parse = false }, .limit_refusals = 0, .central_offset = decoder.snapshot().central_offset };
}
