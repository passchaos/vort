//! One-shot public decoding of source-backed Zstandard frames and streams.
//!
//! The caller owns the random-access source, the destination and every
//! workspace slice. `inspect*` walks only element and block headers to report
//! exact boundaries and, where the wire carries them, decoded sizes.
//! `decode*` executes data frames through the transactional frame executor and
//! advances skippable frames without reading their payloads.
//!
//! A failed decode may leave a committed prefix in the destination because the
//! executor publishes each complete block. Callers that need all-or-nothing
//! output should decode into their own staging buffer and publish after
//! success. Fixed destinations must be large enough for the whole stream; a
//! full destination returns `OutputTooSmall` without discarding committed
//! blocks. The append forms keep committed output on error.
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

        pub const StreamOptions = struct {
            format: stream_cursor.FrameFormat = .standard,
            /// Used for ID-less data frames and as a fallback for a declared ID.
            dictionary: ?Support.DecodeDictionary = null,
            /// Resolves declared nonzero dictionary IDs before the fallback.
            dictionary_set: ?Support.DecodeDictionarySet = null,
            frame_decoded_max: Count = std.math.maxInt(Count),
            total_decoded_max: Count = std.math.maxInt(Count),
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

        pub const StreamInfo = struct {
            /// Null when any compressed frame omits its declared content size.
            total_decoded: ?Count,
            stream_end_offset: u64,
            data_frames: usize,
            skippable_frames: usize,
        };

        pub const StreamResult = struct {
            decoded_len: Count,
            stream_end_offset: u64,
            data_frames: usize,
            skippable_frames: usize,
        };

        const Parsed = struct {
            frame: source_frame.DataFrameLayout,
            dictionary: ?Support.DecodeDictionary,
            dictionary_id: u32,
            dictionary_content: []const u8,
        };

        fn resolveDictionary(
            header_id: u32,
            dictionary: ?Support.DecodeDictionary,
        ) Error!?Support.DecodeDictionary {
            if (header_id == 0) return dictionary;
            const resolved = dictionary orelse return error.NeedDictionary;
            if (resolved.id != header_id) return error.DictionaryMismatch;
            return resolved;
        }

        fn fromLayout(
            frame: source_frame.DataFrameLayout,
            dictionary: ?Support.DecodeDictionary,
        ) Error!Parsed {
            const resolved = try resolveDictionary(
                frame.header.dictionary_id,
                dictionary,
            );
            return .{
                .frame = frame,
                .dictionary = resolved,
                .dictionary_id = frame.header.dictionary_id,
                .dictionary_content = if (resolved) |value| value.content else &.{},
            };
        }

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
            return fromLayout(frame, options.dictionary);
        }

        fn inspectFrameLayout(
            parsed: Parsed,
            options: Options,
        ) Error!FrameInfo {
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
                const end = try parsed.frame.available.end();
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

        /// Walk block headers without reading payloads or decoding entropy.
        /// The checksum footer is range-checked but its value is not compared.
        /// Compressed blocks do not carry their regenerated size in the block
        /// header, so their total is only known from a declared content size.
        pub fn inspect(
            source: byte_source.Source,
            options: Options,
        ) Error!FrameInfo {
            return inspectFrameLayout(try parse(source, options), options);
        }

        pub fn decodedSize(
            source: byte_source.Source,
            options: Options,
        ) Error!?Count {
            return (try inspect(source, options)).decoded_size;
        }

        fn openFrame(
            parsed: Parsed,
            workspace: Workspace,
            options: Options,
            history: *history_workspace.Binding,
            state: *Support.State,
        ) Error!frame_executor.Executor(
            Support.HuffmanCodec,
            Support.SequenceCodec,
        ) {
            const required_history = try history_workspace.requiredLen(
                parsed.frame.header.window_size,
                parsed.dictionary_content.len,
            );
            if (workspace.history.len < required_history)
                return error.OutputTooSmall;
            history.* = try history_workspace.Binding.init(workspace.history);
            try history.beginFrame(
                parsed.frame.header.window_size,
                parsed.dictionary_content.len,
            );
            state.* = try Support.initialState(parsed.dictionary);
            return frame_executor.Executor(
                Support.HuffmanCodec,
                Support.SequenceCodec,
            ).init(
                parsed.frame,
                state,
                history,
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
        }

        fn decodeFrameInto(
            parsed: Parsed,
            destination: []u8,
            workspace: Workspace,
            options: Options,
        ) Error!Result {
            var history: history_workspace.Binding = undefined;
            var state: Support.State = undefined;
            var executor = try openFrame(
                parsed,
                workspace,
                options,
                &history,
                &state,
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

        fn decodeFrameAppend(
            parsed: Parsed,
            allocator: std.mem.Allocator,
            out: *std.ArrayList(u8),
            workspace: Workspace,
            options: Options,
        ) Error!Result {
            var history: history_workspace.Binding = undefined;
            var state: Support.State = undefined;
            var executor = try openFrame(
                parsed,
                workspace,
                options,
                &history,
                &state,
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

        /// Decode one complete data frame into caller-owned destination.
        pub fn decodeInto(
            source: byte_source.Source,
            destination: []u8,
            workspace: Workspace,
            options: Options,
        ) Error!Result {
            return decodeFrameInto(
                try parse(source, options),
                destination,
                workspace,
                options,
            );
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
            return decodeFrameAppend(
                try parse(source, options),
                allocator,
                out,
                workspace,
                options,
            );
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

        fn resolveStreamDictionary(
            header_id: u32,
            options: StreamOptions,
        ) Error!?Support.DecodeDictionary {
            if (header_id == 0) return options.dictionary;
            if (options.dictionary_set) |set|
                if (set.find(header_id)) |dictionary| return dictionary;
            const fallback = options.dictionary orelse return error.NeedDictionary;
            if (fallback.id != header_id) return error.DictionaryMismatch;
            return fallback;
        }

        fn streamRange(source: byte_source.Source) Error!source_input.Range {
            return source_input.Range.init(source, 0, source.len);
        }

        fn frameOptions(
            options: StreamOptions,
            frame_decoded_max: Count,
        ) Options {
            return .{
                .format = options.format,
                .frame_decoded_max = frame_decoded_max,
                .ignore_checksum = options.ignore_checksum,
            };
        }

        /// Walk every element header and every data-frame block header without
        /// reading payloads or decoding entropy.
        pub fn inspectStream(
            source: byte_source.Source,
            options: StreamOptions,
        ) Error!StreamInfo {
            const range = try streamRange(source);
            var cursor = stream_cursor.Cursor.init(range, options.format);
            var total: ?Count = 0;
            var data_frames: usize = 0;
            var skippable_frames: usize = 0;
            while (try cursor.next()) |element| {
                switch (element) {
                    .skippable => skippable_frames += 1,
                    .data => |frame| {
                        const dictionary = try resolveStreamDictionary(
                            frame.header.dictionary_id,
                            options,
                        );
                        const parsed = try fromLayout(frame, dictionary);
                        const info = try inspectFrameLayout(
                            parsed,
                            frameOptions(options, options.frame_decoded_max),
                        );
                        if (total) |value| {
                            if (info.decoded_size) |size| {
                                const next = try count.add(value, size);
                                if (next > options.total_decoded_max)
                                    return error.OutputLimitExceeded;
                                total = next;
                            } else {
                                total = null;
                            }
                        }
                        data_frames += 1;
                        try cursor.finishData(info.frame_end_offset);
                    },
                }
            }
            return .{
                .total_decoded = total,
                .stream_end_offset = cursor.offset(),
                .data_frames = data_frames,
                .skippable_frames = skippable_frames,
            };
        }

        fn remainingCap(total: Count, maximum: Count) Error!Count {
            if (total > maximum) return error.OutputLimitExceeded;
            return maximum - total;
        }

        /// Decode every data frame into caller-owned destination while
        /// advancing skippable frames without reading their payloads.
        pub fn decodeStreamInto(
            source: byte_source.Source,
            destination: []u8,
            workspace: Workspace,
            options: StreamOptions,
        ) Error!StreamResult {
            const range = try streamRange(source);
            var cursor = stream_cursor.Cursor.init(range, options.format);
            var total: Count = 0;
            var written: usize = 0;
            var data_frames: usize = 0;
            var skippable_frames: usize = 0;
            while (try cursor.next()) |element| {
                switch (element) {
                    .skippable => skippable_frames += 1,
                    .data => |frame| {
                        const dictionary = try resolveStreamDictionary(
                            frame.header.dictionary_id,
                            options,
                        );
                        const parsed = try fromLayout(frame, dictionary);
                        const cap = try remainingCap(
                            total,
                            options.total_decoded_max,
                        );
                        const result = try decodeFrameInto(
                            parsed,
                            destination[written..],
                            workspace,
                            frameOptions(
                                options,
                                @min(options.frame_decoded_max, cap),
                            ),
                        );
                        written += try count.toLocal(result.decoded_len);
                        total = try count.add(total, result.decoded_len);
                        data_frames += 1;
                        try cursor.finishData(result.frame_end_offset);
                    },
                }
            }
            return .{
                .decoded_len = total,
                .stream_end_offset = cursor.offset(),
                .data_frames = data_frames,
                .skippable_frames = skippable_frames,
            };
        }

        pub fn decodeStreamAppend(
            allocator: std.mem.Allocator,
            source: byte_source.Source,
            workspace: Workspace,
            out: *std.ArrayList(u8),
            options: StreamOptions,
        ) Error!StreamResult {
            const range = try streamRange(source);
            var cursor = stream_cursor.Cursor.init(range, options.format);
            var total: Count = 0;
            var data_frames: usize = 0;
            var skippable_frames: usize = 0;
            while (try cursor.next()) |element| {
                switch (element) {
                    .skippable => skippable_frames += 1,
                    .data => |frame| {
                        const dictionary = try resolveStreamDictionary(
                            frame.header.dictionary_id,
                            options,
                        );
                        const parsed = try fromLayout(frame, dictionary);
                        const cap = try remainingCap(
                            total,
                            options.total_decoded_max,
                        );
                        const result = try decodeFrameAppend(
                            parsed,
                            allocator,
                            out,
                            workspace,
                            frameOptions(
                                options,
                                @min(options.frame_decoded_max, cap),
                            ),
                        );
                        total = try count.add(total, result.decoded_len);
                        data_frames += 1;
                        try cursor.finishData(result.frame_end_offset);
                    },
                }
            }
            return .{
                .decoded_len = total,
                .stream_end_offset = cursor.offset(),
                .data_frames = data_frames,
                .skippable_frames = skippable_frames,
            };
        }

        pub fn decodeStreamAlloc(
            allocator: std.mem.Allocator,
            source: byte_source.Source,
            workspace: Workspace,
            options: StreamOptions,
        ) Error![]u8 {
            var output: std.ArrayList(u8) = .empty;
            errdefer output.deinit(allocator);
            _ = try decodeStreamAppend(
                allocator,
                source,
                workspace,
                &output,
                options,
            );
            return output.toOwnedSlice(allocator);
        }
    };
}
