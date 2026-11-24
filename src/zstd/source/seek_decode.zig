//! Verified plaintext range reads over the terminal Zstd seek table.
const std = @import("std");
const history_workspace = @import("../decode/history_workspace.zig");
const seekable = @import("../seekable.zig");
const frame = @import("frame.zig");
const Range = @import("input.zig").Range;
const output_alias = @import("output_alias.zig");
const minimum_page_len = @import("reverse_bit_reader.zig").minimum_page_len;
const seek_table = @import("seek_table.zig");

const Selection = struct {
    entry: seekable.Entry,
    /// Offsets within the entry's decoded data.
    start: u64,
    end: u64,

    fn len(self: Selection) usize {
        // An intersection is bounded by the caller's usize range length.
        return @intCast(self.end - self.start);
    }

    fn frameLayout(self: Selection, table: seek_table.Table) frame.Error!frame.DataFrameLayout {
        const entry = self.entry;
        if (entry.compressed_offset > table.frame_offset or
            entry.compressed_size > table.frame_offset - entry.compressed_offset)
            return error.CorruptFrame;
        const input = try Range.init(table.source, entry.compressed_offset, entry.compressed_size);
        return frame.parseDataFrameHeader(input, .standard);
    }
};

const Selections = struct {
    entries: []const seekable.Entry,
    position: u64,
    end: u64,

    fn init(index: seek_table.Index, offset: u64, length: usize) seek_table.Error!Selections {
        if (offset > index.decompressed_size or length > index.decompressed_size - offset)
            return error.RangeOutOfBounds;
        if (length == 0) return .{ .entries = &.{}, .position = offset, .end = offset };
        const first = try index.frameIndexForDecompressedOffset(offset);
        if (first >= index.entries.len) return error.CorruptFrame;
        return .{ .entries = index.entries[first..], .position = offset, .end = offset + length };
    }

    fn next(self: *Selections) seekable.Error!?Selection {
        if (self.position == self.end) return null;
        while (self.entries.len != 0) {
            const entry = self.entries[0];
            self.entries = self.entries[1..];
            if (entry.decompressed_size == 0) continue;
            const frame_end = std.math.add(u64, entry.decompressed_offset, entry.decompressed_size) catch
                return error.IntegerOverflow;
            if (self.position < entry.decompressed_offset or self.position >= frame_end)
                return error.CorruptFrame;
            const end = @min(self.end, frame_end);
            const selected: Selection = .{
                .entry = entry,
                .start = self.position - entry.decompressed_offset,
                .end = end - entry.decompressed_offset,
            };
            self.position = end;
            return selected;
        }
        return error.CorruptFrame;
    }

    fn scratchLen(self: Selections, max_frame_size: u64) seekable.Error!usize {
        var selected = self;
        var len: usize = 0;
        while (try selected.next()) |part| {
            if (part.entry.decompressed_size > max_frame_size) return error.OutputLimitExceeded;
            len = @max(len, part.len());
        }
        return len;
    }
};

pub const Requirements = struct {
    history: usize = 0,
    staging: usize = 0,
    literal_page: usize = 0,
    sequence_page: usize = 0,
    /// Largest selected intersection, not the largest full decoded frame.
    range_scratch: usize = 0,
};

pub fn Facade(comptime Decode: type) type {
    return struct {
        const Error = @import("decode_api.zig").Error;

        pub const Options = struct {
            /// ID-less binding or fallback when the catalog does not contain a declared ID.
            dictionary: @FieldType(Decode.Options, "dictionary") = null,
            dictionary_set: @FieldType(Decode.Options, "dictionary_set") = null,
            /// Caps each complete selected frame, even for a one-byte range.
            frame_decoded_max: u64 = std.math.maxInt(u64),
            /// Reject each selected frame whose advertised window exceeds this limit.
            max_window_size: u64 = std.math.maxInt(u64),
        };

        /// Read only selected data-frame headers to size a reusable decode workspace.
        pub fn requirements(index: seek_table.Index, offset: u64, length: usize, options: Options) Error!Requirements {
            var selections = try Selections.init(index, offset, length);
            const scratch_len = try selections.scratchLen(options.frame_decoded_max);
            if (length == 0) return .{};
            var needed: Requirements = .{
                .literal_page = minimum_page_len,
                .sequence_page = minimum_page_len,
                .range_scratch = scratch_len,
            };
            while (try selections.next()) |part| {
                const parsed = try prepare(index.table, part, frameOptions(part, options));
                needed.staging = @max(needed.staging, parsed.frame.header.block_size_max);
                needed.history = @max(needed.history, try history_workspace.requiredLen(
                    parsed.frame.header.window_size,
                    parsed.dictionary_content.len,
                ));
            }
            return needed;
        }

        /// Decode exactly output.len plaintext bytes. Each intersecting frame
        /// is verified in full; only its requested slice is staged for publication.
        pub fn decodeInto(
            index: seek_table.Index,
            offset: u64,
            output: []u8,
            workspace: Decode.Workspace,
            range_scratch: []u8,
            options: Options,
        ) Error!usize {
            var selections = try Selections.init(index, offset, output.len);
            if (output.len == 0) return 0;
            const scratch_len = try selections.scratchLen(options.frame_decoded_max);
            if (range_scratch.len < scratch_len) return error.OutputTooSmall;
            try validateBuffers(index, output, workspace, range_scratch, options);

            var written: usize = 0;
            while (try selections.next()) |part| {
                const scratch = range_scratch[0..part.len()];
                try decodeSelection(index.table, part, workspace, scratch, frameOptions(part, options));
                @memcpy(output[written..][0..scratch.len], scratch);
                written += scratch.len;
            }
            return written;
        }

        fn validateBuffers(
            index: seek_table.Index,
            output: []u8,
            workspace: Decode.Workspace,
            scratch: []u8,
            options: Options,
        ) Error!void {
            const entries = std.mem.sliceAsBytes(index.entries);
            try output_alias.validateRegions(entries, &.{ output, scratch });
            try output_alias.validateWorkspace(entries, workspace);
            try output_alias.validateOperation(output, workspace, options);
            try output_alias.validateRegions(output, &.{scratch});
            try output_alias.validateWorkspace(scratch, workspace);
            try output_alias.validateOptions(scratch, options);
        }

        fn frameOptions(part: Selection, options: Options) Decode.Options {
            return .{
                .dictionary = options.dictionary,
                .dictionary_set = options.dictionary_set,
                .frame_decoded_max = part.entry.decompressed_size,
                .max_window_size = options.max_window_size,
            };
        }

        fn prepare(table: seek_table.Table, part: Selection, options: Decode.Options) Error!Decode.Parsed {
            const layout = try part.frameLayout(table);
            if (layout.header.window_size > options.max_window_size) return error.OutputLimitExceeded;
            if (layout.header.content_size) |size| {
                if (size != part.entry.decompressed_size) return error.SizeMismatch;
            }
            return Decode.admitFrame(layout, options);
        }

        fn decodeSelection(
            table: seek_table.Table,
            part: Selection,
            workspace: Decode.Workspace,
            scratch: []u8,
            options: Decode.Options,
        ) Error!void {
            const parsed = try prepare(table, part, options);
            var history: history_workspace.Binding = undefined;
            var state: Decode.FrameState = undefined;
            var executor = try Decode.openFrame(parsed, workspace, options, &history, &state);
            var copied: usize = 0;
            while (true) {
                const snapshot = executor.snapshot();
                switch (snapshot.phase) {
                    .done => break,
                    .drain => {
                        const bytes = try executor.committedBytes();
                        const block_start = snapshot.frame_decoded - bytes.len;
                        const start = @max(part.start, block_start);
                        const end = @min(part.end, snapshot.frame_decoded);
                        if (end > start) {
                            const block_offset: usize = @intCast(start - block_start);
                            const len: usize = @intCast(end - start);
                            @memcpy(scratch[copied..][0..len], bytes[block_offset..][0..len]);
                            copied += len;
                        }
                        try executor.discardCommittedBlock();
                    },
                    else => executor.execute() catch |err| switch (err) {
                        // The caller policy was checked against the table. A frame
                        // that decodes beyond its own entry is a wire size mismatch.
                        error.OutputLimitExceeded => return error.SizeMismatch,
                        else => return err,
                    },
                }
            }
            if (state.frame_decoded != part.entry.decompressed_size or copied != scratch.len or
                try executor.frameEndOffset() != try parsed.frame.available.end())
                return error.SizeMismatch;
            if (part.entry.checksum) |expected| {
                if (try executor.frameContentChecksum() != expected) return error.ChecksumMismatch;
            }
        }
    };
}
