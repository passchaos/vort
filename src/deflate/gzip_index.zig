//! Caller-owned random-access index for validated concatenated gzip members.
const model = @import("gzip_index/types.zig");
const builder = @import("gzip_index/builder.zig");
const range = @import("gzip_index/range.zig");

pub const Entry = model.Entry;
pub const Options = model.Options;
pub const Workspace = model.Workspace;
pub const Outcome = model.Outcome;
pub const Progress = model.Progress;

pub fn Index(comptime Codec: type) type {
    return struct {
        source: model.Source,
        entries: []const Entry,
        checkpoint_history: []const u8,
        decoded_size: model.Count,
        members_verified: model.Count,
        max_header_metadata_len: usize,

        const Self = @This();

        /// Validate the entire source before returning an index. The source,
        /// written entries and saved history must remain stable while in use.
        pub fn build(source: model.Source, entries: []Entry, checkpoint_history: []u8, workspace: Workspace, options: Options) model.Error!Self {
            return builder.build(Codec, Self, source, entries, checkpoint_history, workspace, options);
        }

        /// The latest boundary at or before a requested plaintext byte.
        pub fn entryForOffset(self: Self, offset: model.Count) model.Error!Entry {
            if (offset >= self.decoded_size) return error.RangeOutOfBounds;
            var lo: usize = 0;
            var hi = self.entries.len;
            while (lo < hi) {
                const mid = lo + (hi - lo) / 2;
                if (self.entries[mid].decodedOffset() <= offset) lo = mid + 1 else hi = mid;
            }
            if (lo == 0) return error.InvalidBlockPlan;
            const entry = self.entries[lo - 1];
            if (offset >= entry.decoded_end or entry.decoded_end > self.decoded_size)
                return error.InvalidBlockPlan;
            return entry;
        }

        /// Read a range from the stable indexed source. This does not perform a
        /// fresh validation of every intersecting member's footer.
        pub fn decodeRangeInto(self: Self, offset: model.Count, output: []u8, workspace: Workspace) Outcome {
            return range.decode(Codec, self, offset, output, workspace);
        }
    };
}
