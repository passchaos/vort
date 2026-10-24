const std = @import("std");
const shared_dictionary = @import("../shared_dictionary.zig");

pub const hash_bucket_bits: usize = 15;
pub const hash_bucket_count: usize = @as(usize, 1) << hash_bucket_bits;
pub const bucket_ways: usize = 4;
const invalid_address = std.math.maxInt(usize);
const Bucket = [bucket_ways]usize;
const empty_bucket: Bucket = @splat(invalid_address);

/// Exact storage retained after the first non-empty dictionary is prepared.
pub const index_bytes: usize = hash_bucket_count * @sizeOf(Bucket);

pub const Match = struct {
    /// Zero-based address in the logical concatenation of RAW attachments.
    address: usize,
    length: usize,
};

/// Reusable fixed-memory index for Brotli compound-dictionary prefixes.
///
/// The attachment descriptors are copied into the matcher, but their byte
/// storage is borrowed and never flattened. Attachment bytes must remain alive
/// and unchanged until `reset`, `deinit`, or a successful `prepare` with a
/// different descriptor. Preparing descriptor-identical attachments (same
/// count, addresses, lengths, and order) reuses the existing index without
/// rescanning, so mutating borrowed bytes is unsupported even if `prepare` is
/// called again with the same descriptor.
pub const Matcher = struct {
    allocator: std.mem.Allocator,
    buckets: []Bucket = &.{},
    chunks: [shared_dictionary.max_raw_prefixes][]const u8 = undefined,
    chunk_count: usize = 0,
    total_size: usize = 0,
    prepared: bool = false,

    pub fn init(allocator: std.mem.Allocator) Matcher {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Matcher) void {
        if (self.buckets.len != 0) self.allocator.free(self.buckets);
        self.* = undefined;
    }

    /// Forget the borrowed dictionary while retaining the fixed hash table.
    pub fn reset(self: *Matcher) void {
        self.chunk_count = 0;
        self.total_size = 0;
        self.prepared = false;
    }

    pub fn retainedCapacity(self: *const Matcher) usize {
        return self.buckets.len * @sizeOf(Bucket);
    }

    pub fn dictionarySize(self: *const Matcher) usize {
        return if (self.prepared) self.total_size else 0;
    }

    /// Validate and index the ordered RAW attachments without copying bytes.
    /// Validation and allocation complete before the previous prepared state
    /// is changed, so either failure leaves that state usable.
    pub fn prepare(self: *Matcher, dictionary: shared_dictionary.Dictionary) !void {
        const total_size = try dictionary.totalSize();
        if (self.sameDescriptor(dictionary)) return;

        if (total_size >= 4 and self.buckets.len == 0) {
            const buckets = try self.allocator.alloc(Bucket, hash_bucket_count);
            @memset(buckets, empty_bucket);
            self.buckets = buckets;
        } else if (self.buckets.len != 0) {
            @memset(self.buckets, empty_bucket);
        }

        self.chunk_count = dictionary.compoundChunkCount();
        for (0..self.chunk_count) |index|
            self.chunks[index] = dictionary.compoundChunk(index).?;
        self.total_size = total_size;
        self.prepared = true;

        if (total_size >= 4) self.rebuild();
    }

    /// Find the best compound match at `position`.
    ///
    /// At most `probe_limit` of the four newest hash-colliding dictionary
    /// anchors are examined. Matches are clamped to both `max_len` and the
    /// remaining input. Equal lengths prefer the greater logical address,
    /// which has the smaller Brotli compound-dictionary wire distance.
    pub fn findLongest(
        self: *const Matcher,
        input: []const u8,
        position: usize,
        max_len: usize,
        probe_limit: usize,
    ) ?Match {
        if (!self.prepared or self.total_size < 4 or max_len < 4 or probe_limit == 0) return null;
        if (position > input.len) return null;
        const available = @min(max_len, input.len - position);
        if (available < 4) return null;

        const input_tail = input[position..][0..available];
        const bucket = self.buckets[hashAnchor(input_tail[0..4])];
        const probes = @min(probe_limit, bucket_ways);
        var best: ?Match = null;
        for (bucket[0..probes]) |address| {
            if (address == invalid_address) break;
            const length = self.matchLength(address, input_tail);
            if (length < 4) continue;
            if (best == null or length > best.?.length or
                (length == best.?.length and address > best.?.address))
            {
                best = .{ .address = address, .length = length };
            }
            // Candidates are newest first, so the first full-length match also
            // wins the distance tie against every remaining candidate.
            if (length == available) break;
        }
        return best;
    }

    /// Complete HQ address frontier, independent of the lossy four-way table.
    /// Each matching logical start is visited once, in ascending address order,
    /// with its longest proven prefix. A parser may use any shorter copy length
    /// from two through `Match.length`. `visitor.visit(Match) !bool` can stop or
    /// propagate a caller budget error; querying allocates no heap storage.
    pub fn visitMatches(self: *const Matcher, input: []const u8, position: usize, max_len: usize, visitor: anytype) !void {
        return self.visitMatchesAtLeast(input, position, max_len, 2, visitor);
    }

    pub fn visitMatchesAtLeast(self: *const Matcher, input: []const u8, position: usize, max_len: usize, minimum_length: usize, visitor: anytype) !void {
        const minimum = @max(2, minimum_length);
        if (!self.prepared or position > input.len or self.total_size < minimum) return;
        const available = @min(max_len, input.len - position);
        if (available < minimum) return;
        const input_tail = input[position..][0..available];
        for (0..self.total_size - minimum + 1) |address| {
            const length = self.matchLengthForVisitor(address, input_tail);
            if (length >= minimum and !try visitor.visit(Match{ .address = address, .length = length })) return;
        }
    }

    fn matchLengthForVisitor(self: *const Matcher, address: usize, input: []const u8) usize {
        const limit = @min(input.len, self.total_size - address);
        var chunk_index: usize = 0;
        var chunk_offset = address;
        while (chunk_index < self.chunk_count) : (chunk_index += 1) {
            const chunk = self.chunks[chunk_index];
            if (chunk_offset < chunk.len) break;
            chunk_offset -= chunk.len;
        }
        var matched: usize = 0;
        while (matched < limit) {
            while (chunk_index < self.chunk_count and chunk_offset == self.chunks[chunk_index].len) {
                chunk_index += 1;
                chunk_offset = 0;
            }
            if (chunk_index == self.chunk_count) break;
            const chunk = self.chunks[chunk_index];
            const count = @min(chunk.len - chunk_offset, limit - matched);
            var offset: usize = 0;
            while (offset < count and chunk[chunk_offset + offset] == input[matched + offset]) : (offset += 1) {}
            matched += offset;
            if (offset != count) break;
            chunk_offset += count;
        }
        return matched;
    }

    fn sameDescriptor(self: *const Matcher, dictionary: shared_dictionary.Dictionary) bool {
        if (!self.prepared or dictionary.compoundChunkCount() != self.chunk_count) return false;
        for (self.chunks[0..self.chunk_count], 0..) |cached, index| {
            const incoming = dictionary.compoundChunk(index).?;
            if (incoming.ptr != cached.ptr or incoming.len != cached.len) return false;
        }
        return true;
    }

    fn rebuild(self: *Matcher) void {
        std.debug.assert(self.prepared and self.total_size >= 4);
        std.debug.assert(self.buckets.len == hash_bucket_count);

        var window: [4]u8 = undefined;
        var window_len: usize = 0;
        var logical_address: usize = 0;
        for (self.chunks[0..self.chunk_count]) |chunk| {
            for (chunk) |byte| {
                if (window_len < window.len) {
                    window[window_len] = byte;
                    window_len += 1;
                } else {
                    window[0] = window[1];
                    window[1] = window[2];
                    window[2] = window[3];
                    window[3] = byte;
                }
                if (window_len == window.len) {
                    const anchor_address = logical_address - (window.len - 1);
                    insertAddress(&self.buckets[hashAnchor(&window)], anchor_address);
                }
                logical_address += 1;
            }
        }
        std.debug.assert(logical_address == self.total_size);
    }

    fn matchLength(self: *const Matcher, address: usize, input: []const u8) usize {
        std.debug.assert(address + 4 <= self.total_size);
        const limit = @min(input.len, self.total_size - address);
        var chunk_index: usize = 0;
        var chunk_offset = address;
        while (chunk_index < self.chunk_count) : (chunk_index += 1) {
            const chunk = self.chunks[chunk_index];
            if (chunk_offset < chunk.len) break;
            chunk_offset -= chunk.len;
        }
        std.debug.assert(chunk_index < self.chunk_count);

        var matched: usize = 0;
        while (matched < limit) {
            while (chunk_index < self.chunk_count and chunk_offset == self.chunks[chunk_index].len) {
                chunk_index += 1;
                chunk_offset = 0;
            }
            if (chunk_index == self.chunk_count) break;

            const chunk = self.chunks[chunk_index];
            const count = @min(chunk.len - chunk_offset, limit - matched);
            var offset: usize = 0;
            while (offset < count and chunk[chunk_offset + offset] == input[matched + offset]) : (offset += 1) {}
            matched += offset;
            if (offset != count) break;
            chunk_offset += count;
        }
        return matched;
    }
};

fn insertAddress(bucket: *Bucket, address: usize) void {
    bucket[3] = bucket[2];
    bucket[2] = bucket[1];
    bucket[1] = bucket[0];
    bucket[0] = address;
}

fn hashAnchor(bytes: *const [4]u8) usize {
    const word = std.mem.readInt(u32, bytes, .little);
    return @as(usize, (word *% 0x9e37_79b1) >> (32 - hash_bucket_bits));
}

test "compound matcher finds anchors and continuations across fifteen chunks" {
    var matcher = Matcher.init(std.testing.allocator);
    defer matcher.deinit();

    try matcher.prepare(.{});
    try std.testing.expectEqual(@as(usize, 0), matcher.retainedCapacity());
    try std.testing.expectEqual(@as(?Match, null), matcher.findLongest("abcd", 0, 4, 4));

    const chunks: [shared_dictionary.max_raw_prefixes][]const u8 = .{
        "", "a", "bc", "", "d", "efg", "", "h", "i", "", "j", "", "", "", "",
    };
    try matcher.prepare(.{ .raw_prefixes = &chunks });
    try std.testing.expectEqual(@as(usize, 10), matcher.dictionarySize());
    try std.testing.expectEqual(index_bytes, matcher.retainedCapacity());

    const whole = matcher.findLongest("!!abcdefghij??", 2, 100, 4) orelse
        return error.TestUnexpectedResult;
    try std.testing.expectEqual(Match{ .address = 0, .length = 10 }, whole);

    const middle = matcher.findLongest("cdefgh", 0, 6, 4) orelse
        return error.TestUnexpectedResult;
    try std.testing.expectEqual(Match{ .address = 2, .length = 6 }, middle);
}

test "compound matcher keeps four recent hash collisions and honors probe limit" {
    const Test = struct {
        fn collidingWords(output: *[5][4]u8) !usize {
            const target: usize = 1234;
            var found: usize = 0;
            var value: u32 = 1;
            while (value != 0 and found < output.len) : (value +%= 1) {
                var bytes: [4]u8 = undefined;
                std.mem.writeInt(u32, &bytes, value, .little);
                if (hashAnchor(&bytes) != target) continue;
                output[found] = bytes;
                found += 1;
            }
            if (found != output.len) return error.TestUnexpectedResult;
            return target;
        }

        fn buildDictionary(words: *const [5][4]u8, storage: *[25]u8, target: usize) !void {
            var separator: usize = 0;
            while (separator <= std.math.maxInt(u8)) : (separator += 1) {
                for (words, 0..) |word, index| {
                    @memcpy(storage[index * 5 ..][0..4], &word);
                    storage[index * 5 + 4] = @intCast(separator);
                }
                var only_intended_anchors = true;
                for (0..storage.len - 3) |position| {
                    if (position % 5 == 0) continue;
                    if (hashAnchor(storage[position..][0..4]) == target) {
                        only_intended_anchors = false;
                        break;
                    }
                }
                if (only_intended_anchors) return;
            }
            return error.TestUnexpectedResult;
        }
    };

    var words: [5][4]u8 = undefined;
    const target = try Test.collidingWords(&words);
    var storage: [25]u8 = undefined;
    try Test.buildDictionary(&words, &storage, target);

    var matcher = Matcher.init(std.testing.allocator);
    defer matcher.deinit();
    try matcher.prepare(.{ .raw_prefixes = &.{&storage} });
    try std.testing.expectEqualSlices(usize, &.{ 20, 15, 10, 5 }, &matcher.buckets[target]);

    try std.testing.expect(matcher.findLongest(&words[0], 0, 4, 4) == null);
    try std.testing.expect(matcher.findLongest(&words[1], 0, 4, 3) == null);
    const fourth_way = matcher.findLongest(&words[1], 0, 4, 4) orelse
        return error.TestUnexpectedResult;
    try std.testing.expectEqual(Match{ .address = 5, .length = 4 }, fourth_way);
    const newest = matcher.findLongest(&words[4], 0, 4, 1) orelse
        return error.TestUnexpectedResult;
    try std.testing.expectEqual(Match{ .address = 20, .length = 4 }, newest);
}

test "compound matcher bounds matches and resolves length then suffix-distance ties" {
    const chunks = [_][]const u8{ "abcdefghQ", "---", "abcdZ" };
    var matcher = Matcher.init(std.testing.allocator);
    defer matcher.deinit();
    try matcher.prepare(.{ .raw_prefixes = &chunks });

    const limited = matcher.findLongest("!!abcdefgh!", 2, 6, 4) orelse
        return error.TestUnexpectedResult;
    try std.testing.expectEqual(Match{ .address = 0, .length = 6 }, limited);

    const one_probe = matcher.findLongest("abcdefgh!", 0, 8, 1) orelse
        return error.TestUnexpectedResult;
    try std.testing.expectEqual(Match{ .address = 12, .length = 4 }, one_probe);
    const longer = matcher.findLongest("abcdefgh!", 0, 8, 2) orelse
        return error.TestUnexpectedResult;
    try std.testing.expectEqual(Match{ .address = 0, .length = 8 }, longer);

    const tied = matcher.findLongest("abcd!", 0, 4, 4) orelse
        return error.TestUnexpectedResult;
    try std.testing.expectEqual(Match{ .address = 12, .length = 4 }, tied);
    try std.testing.expect(matcher.findLongest("abcd", 5, 4, 4) == null);
    try std.testing.expect(matcher.findLongest("abcd", 0, 3, 4) == null);
    try std.testing.expect(matcher.findLongest("abcd", 0, 4, 0) == null);
}

test "compound matcher reset retains capacity and rebuilds for new attachments" {
    var matcher = Matcher.init(std.testing.allocator);
    defer matcher.deinit();

    const first = [_][]const u8{"first-dictionary"};
    try matcher.prepare(.{ .raw_prefixes = &first });
    const retained = matcher.retainedCapacity();
    try std.testing.expect(retained != 0);

    // A separate descriptor array with identical ordered slice identities takes
    // the no-rescan path. The attachment byte storage remains borrowed.
    const same_identity = first;
    try matcher.prepare(.{ .raw_prefixes = &same_identity });
    try std.testing.expectEqual(retained, matcher.retainedCapacity());

    matcher.reset();
    try std.testing.expectEqual(retained, matcher.retainedCapacity());
    try std.testing.expectEqual(@as(usize, 0), matcher.dictionarySize());
    try std.testing.expect(matcher.findLongest("first", 0, 5, 4) == null);

    const second = [_][]const u8{ "", "second", "", "-dictionary" };
    try matcher.prepare(.{ .raw_prefixes = &second });
    try std.testing.expectEqual(retained, matcher.retainedCapacity());
    const match = matcher.findLongest("second-dictionary", 0, 17, 4) orelse
        return error.TestUnexpectedResult;
    try std.testing.expectEqual(Match{ .address = 0, .length = 17 }, match);
}

test "compound matcher rejects huge fake dictionaries before indexing and keeps usize addresses" {
    comptime std.debug.assert(@sizeOf(@FieldType(Match, "address")) == @sizeOf(usize));

    var bucket = empty_bucket;
    if (@bitSizeOf(usize) > 32) {
        const large_address = @as(usize, std.math.maxInt(u32)) + 17;
        insertAddress(&bucket, large_address);
        try std.testing.expectEqual(large_address, bucket[0]);
    }

    var matcher = Matcher.init(std.testing.allocator);
    defer matcher.deinit();
    const sentinel: [*]const u8 = @ptrFromInt(1);
    const too_large = sentinel[0 .. shared_dictionary.max_raw_size + 1];
    try std.testing.expectError(
        error.RawDictionaryTooLarge,
        matcher.prepare(.{ .raw_prefixes = &.{too_large} }),
    );
    try std.testing.expectEqual(@as(usize, 0), matcher.retainedCapacity());

    const almost_address_space = sentinel[0..std.math.maxInt(usize)];
    try std.testing.expectError(
        error.IntegerOverflow,
        matcher.prepare(.{ .raw_prefixes = &.{ almost_address_space, "x" } }),
    );
    try std.testing.expectEqual(@as(usize, 0), matcher.retainedCapacity());
}

test "compound matcher allocation failure is clean and retryable" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    var matcher = Matcher.init(failing.allocator());
    const chunks = [_][]const u8{ "abc", "def" };

    try std.testing.expectError(error.OutOfMemory, matcher.prepare(.{ .raw_prefixes = &chunks }));
    try std.testing.expect(failing.has_induced_failure);
    try std.testing.expectEqual(@as(usize, 0), matcher.retainedCapacity());
    try std.testing.expectEqual(@as(usize, 0), matcher.dictionarySize());

    failing.fail_index = std.math.maxInt(usize);
    try matcher.prepare(.{ .raw_prefixes = &chunks });
    const match = matcher.findLongest("abcdef", 0, 6, 4) orelse
        return error.TestUnexpectedResult;
    try std.testing.expectEqual(Match{ .address = 0, .length = 6 }, match);
    matcher.deinit();
    try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
}
