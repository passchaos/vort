//! Codec hooks for one standard or magicless frame from independent Jobs.
const std = @import("std");
const zstd = @import("../../zstd.zig");
const types = @import("types.zig");
const support = zstd.ParallelCodecSupport;
const adapter = @import("job_codec.zig").Adapter(support);
const job_encoder = @import("codec_job_encode.zig").Encoder(support);

pub const Codec = struct {
    pub const Error = zstd.ParallelError;
    pub const Options = zstd.NativeFrameOptions;
    pub const Dictionary = zstd.NativeDictionary;
    pub const DictionarySet = zstd.NativeDictionarySet;
    pub const Profile = zstd.EncoderControlProfile;
    pub const State = adapter.State;
    pub const blockSize = support.blockSize;
    pub const prepareOptions = support.prepareOptions;
    pub const profileOptions = support.profileOptions;
    pub const bound = support.rawBound;

    pub fn writeHeader(allocator: std.mem.Allocator, out: *std.ArrayList(u8), input: []const u8, options: Options) Error!void {
        try support.frameHeader(allocator, out, try support.checkedU64(input.len), options);
    }
    pub fn checksum(allocator: std.mem.Allocator, out: *std.ArrayList(u8), input: []const u8, options: Options) Error!void {
        try support.frameChecksum(allocator, out, input, options);
    }
    pub fn initialState(dictionary: ?Dictionary) Error!State {
        return adapter.init(dictionary);
    }
    pub fn deinitState(allocator: std.mem.Allocator, state: *State) void {
        adapter.deinit(allocator, state);
    }
    pub fn encodeJob(allocator: std.mem.Allocator, out: *std.ArrayList(u8), input: []const u8, start: usize, end: usize, options: Options, dictionary: ?Dictionary, work: *Profile) Error!void {
        try job_encoder.encode(allocator, out, input, start, end, options, dictionary, work);
    }
    pub fn appendJob(allocator: std.mem.Allocator, out: *std.ArrayList(u8), bytes: []const u8, input: []const u8, start: usize, end: usize, options: Options, dictionary: ?Dictionary, state: *State, work: *Profile, _: *types.Profile) Error!void {
        try adapter.append(allocator, out, bytes, input, start, end, options, dictionary, state, work);
    }

    /// Count actual physical Blocks, including raw/RLE fragments from the
    /// original selector. Semantic regeneration is checked by appendJob.
    pub fn blockCount(bytes: []const u8) Error!usize {
        var offset: usize = 0;
        var count: usize = 0;
        while (offset != bytes.len) {
            if (bytes.len - offset < 3) return error.TruncatedFrame;
            const header = std.mem.readInt(u24, bytes[offset..][0..3], .little);
            const kind: u2 = @truncate(header >> 1);
            const size: usize = @intCast(header >> 3);
            if (kind == 3 or size > std.compress.zstd.block_size_max) return error.CorruptFrame;
            const length = if (kind == 1) 1 else size;
            offset += 3;
            if (length > bytes.len - offset) return error.TruncatedFrame;
            offset += length;
            count = std.math.add(usize, count, 1) catch return error.IntegerOverflow;
            if ((header & 1) != 0 and offset != bytes.len) return error.CorruptFrame;
        }
        if (count == 0) return error.CorruptFrame;
        return count;
    }
};
