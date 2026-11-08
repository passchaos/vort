//! One-shot public decoding of a source-backed Zstandard data frame.
//!
//! The caller owns the random-access source, the destination and every
//! workspace slice. `inspect` walks only block headers to report the exact
//! decoded size and frame end; `decodeInto` executes the frame through the
//! transactional frame executor. Neither function allocates.
//!
//! A failed decode may leave a committed prefix in the destination because the
//! executor publishes each complete block. Callers that need all-or-nothing
//! output should decode into their own staging buffer and publish after
//! success. The destination must be large enough for the whole frame; a full
//! destination returns `OutputTooSmall` without discarding committed blocks.
const std = @import("std");
const core = @import("../../core.zig");
const byte_source = @import("../../io/source.zig");
const history_workspace = @import("../decode/history_workspace.zig");
const frame_executor = @import("frame_executor.zig");
const source_frame = @import("frame.zig");
const source_input = @import("input.zig");
const stream_cursor = @import("stream_cursor.zig");

const Count = core.StreamCount;
const count = core.stream_count;

pub const Error = core.Error || byte_source.Error || std.mem.Allocator.Error ||
    error{WorkingMemoryLimitExceeded};

pub fn Facade(comptime Support: type) type {
    return struct {
        pub const Workspace = struct {
            /// At least `requiredLen(window, dictionary.len)` bytes.
            history: []u8,
            /// At least the frame's `Block_Maximum_Size` bytes.
            staging: []u8,
            /// At least the reverse-reader minimum page length.
            literal_page: []u8,
            /// At least the reverse-reader minimum page length.
            sequence_page: []u8,
        };

        pub const Options = struct {
            format: stream_cursor.FrameFormat = .standard,
            dictionary: ?Support.DecodeDictionary = null,
            frame_decoded_max: Count = std.math.maxInt(Count),
            ignore_checksum: bool = false,
        };

        pub const FrameInfo = struct {
            content_size: ?u64,
            has_checksum: bool,
            single_segment: bool,
            window_size: u64,
            block_size_max: usize,
            dictionary_id: u32,
            /// Exact for all-Raw/RLE frames; otherwise the declared content
            /// size when present. Null when a compressed frame omits it.
            decoded_size: ?Count,
            frame_end_offset: u64,
        };

        pub const Result = struct {
            decoded_len: Count,
            frame_end_offset: u64,
        };

        const Parsed = struct {
            available: source_input.Range,
            frame: source_frame.DataFrameLayout,
            dictionary_id: u32,
            dictionary_content: []const u8,
        };

        fn parse(source: byte_source.Source, options: Options) Error!Parsed {
            const available = try source_input.Range.init(
                source,
                0,
                source.len,
            );
            const frame = try source_frame.parseDataFrameHeader(
                available,
                options.format,
            );
            const dictionary_id = if (options.dictionary) |dictionary|
                dictionary.id
            else
                0;
            if (frame.header.dictionary_id != dictionary_id) {
                if (dictionary_id == 0) return error.NeedDictionary;
                return error.DictionaryMismatch;
            }
            return .{
                .available = available,
                .frame = frame,
                .dictionary_id = dictionary_id,
                .dictionary_content = if (options.dictionary) |dictionary|
                    dictionary.content
                else
                    &.{},
            };
        }

        /// Walk block headers without reading payloads or decoding entropy.
        /// The checksum footer is range-checked but its value is not compared.
        /// Compressed blocks do not carry their regenerated size in the block
        /// header, so their total is only known from a declared content size.
        pub fn inspect(
            source: byte_source.Source,
            options: Options,
        ) Error!FrameInfo {
            const parsed = try parse(source, options);
            var total: Count = 0;
            var all_uncompressed = true;
            var offset = parsed.frame.first_block_offset;
            while (true) {
                const block = try source_frame.parseBlock(parsed.frame, offset);
                if (block.header.kind == .compressed) {
                    all_uncompressed = false;
                } else {
                    total = try count.addLocal(
                        total,
                        block.header.declared_len,
                    );
                }
                offset = block.next_header_offset;
                if (block.header.last) break;
            }
            if (all_uncompressed) {
                if (parsed.frame.header.content_size) |expected|
                    if (total != expected) return error.SizeMismatch;
                if (total > options.frame_decoded_max)
                    return error.OutputLimitExceeded;
            }
            const decoded_size: ?Count = if (all_uncompressed)
                total
            else
                parsed.frame.header.content_size;
            if (decoded_size) |known|
                if (known > options.frame_decoded_max)
                    return error.OutputLimitExceeded;
            if (parsed.frame.header.has_checksum) {
                const end = try parsed.available.end();
                if (offset > end or end - offset < 4)
                    return error.TruncatedFrame;
                offset += 4;
            }
            return .{
                .content_size = parsed.frame.header.content_size,
                .has_checksum = parsed.frame.header.has_checksum,
                .single_segment = parsed.frame.header.single_segment,
                .window_size = parsed.frame.header.window_size,
                .block_size_max = parsed.frame.header.block_size_max,
                .dictionary_id = parsed.frame.header.dictionary_id,
                .decoded_size = decoded_size,
                .frame_end_offset = offset,
            };
        }

        pub fn decodedSize(
            source: byte_source.Source,
            options: Options,
        ) Error!?Count {
            return (try inspect(source, options)).decoded_size;
        }

        /// Decode one complete data frame into caller-owned destination.
        pub fn decodeInto(
            source: byte_source.Source,
            destination: []u8,
            workspace: Workspace,
            options: Options,
        ) Error!Result {
            const parsed = try parse(source, options);
            const required_history = try history_workspace.requiredLen(
                parsed.frame.header.window_size,
                parsed.dictionary_content.len,
            );
            if (workspace.history.len < required_history)
                return error.OutputTooSmall;
            var history = try history_workspace.Binding.init(workspace.history);
            try history.beginFrame(
                parsed.frame.header.window_size,
                parsed.dictionary_content.len,
            );

            var state = try Support.initialState(options.dictionary);
            var executor = try frame_executor.Executor(
                Support.HuffmanCodec,
                Support.SequenceCodec,
            ).init(
                parsed.frame,
                &state,
                &history,
                parsed.dictionary_content,
                parsed.dictionary_id,
                workspace.staging,
                workspace.literal_page,
                workspace.sequence_page,
                .{
                    .frame_decoded_max = options.frame_decoded_max,
                    .ignore_checksum = options.ignore_checksum,
                },
            );

            var written: usize = 0;
            while (executor.snapshot().phase != .done) {
                switch (executor.snapshot().phase) {
                    .drain => {
                        const result = try executor.drain(destination[written..]);
                        written += result.written;
                        if (result.status == .need_output)
                            return error.OutputTooSmall;
                    },
                    else => try executor.execute(),
                }
            }
            return .{
                .decoded_len = state.frame_decoded,
                .frame_end_offset = try executor.frameEndOffset(),
            };
        }

        /// Append one decoded frame to a growable caller list. Output is
        /// published block by block; the list keeps the committed prefix on
        /// error, so callers that need all-or-nothing output must truncate it.
        pub fn decodeAppend(
            allocator: std.mem.Allocator,
            source: byte_source.Source,
            workspace: Workspace,
            out: *std.ArrayList(u8),
            options: Options,
        ) Error!Result {
            const parsed = try parse(source, options);
            const required_history = try history_workspace.requiredLen(
                parsed.frame.header.window_size,
                parsed.dictionary_content.len,
            );
            if (workspace.history.len < required_history)
                return error.OutputTooSmall;
            var history = try history_workspace.Binding.init(workspace.history);
            try history.beginFrame(
                parsed.frame.header.window_size,
                parsed.dictionary_content.len,
            );

            var state = try Support.initialState(options.dictionary);
            var executor = try frame_executor.Executor(
                Support.HuffmanCodec,
                Support.SequenceCodec,
            ).init(
                parsed.frame,
                &state,
                &history,
                parsed.dictionary_content,
                parsed.dictionary_id,
                workspace.staging,
                workspace.literal_page,
                workspace.sequence_page,
                .{
                    .frame_decoded_max = options.frame_decoded_max,
                    .ignore_checksum = options.ignore_checksum,
                },
            );

            var buffer: [4096]u8 = undefined;
            while (executor.snapshot().phase != .done) {
                switch (executor.snapshot().phase) {
                    .drain => {
                        const result = try executor.drain(&buffer);
                        try out.appendSlice(allocator, buffer[0..result.written]);
                    },
                    else => try executor.execute(),
                }
            }
            return .{
                .decoded_len = state.frame_decoded,
                .frame_end_offset = try executor.frameEndOffset(),
            };
        }

        /// Decode into a newly allocated buffer.
        pub fn decodeAlloc(
            allocator: std.mem.Allocator,
            source: byte_source.Source,
            workspace: Workspace,
            options: Options,
        ) Error![]u8 {
            var output: std.ArrayList(u8) = .empty;
            errdefer output.deinit(allocator);
            _ = try decodeAppend(allocator, source, workspace, &output, options);
            return output.toOwnedSlice(allocator);
        }
    };
}
