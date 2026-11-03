//! A caller-owned 64 KiB logical ring for a DEFLATE decoding step.
//!
//! Logical bytes [0, prefix_len) are initialized immutable history; generated
//! output occupies [prefix_len, output_limit). Each range is at most 32 KiB,
//! so physical wrapping never aliases the history with the append region.
//! The controller owns cursor/history metadata and advances base between
//! steps. This helper neither allocates nor changes that metadata.

const std = @import("std");
const shortcopy = @import("../decoder/shortcopy.zig");

pub const capacity: usize = 65536;
pub const mask: usize = capacity - 1;
pub const window: usize = 32768;
pub const Error = error{ InvalidMatch, OutputTooSmall };

pub const Window = struct {
    /// At least capacity bytes. Any bytes after capacity remain untouched.
    storage: []u8,
    base: usize,
    prefix_len: usize,
    output_limit: usize,

    /// Check metadata without reading or changing caller storage.
    pub inline fn valid(self: *const Window) bool {
        return self.storage.len >= capacity and self.base <= mask and
            self.prefix_len <= window and self.output_limit >= self.prefix_len and
            self.output_limit <= capacity and
            self.output_limit - self.prefix_len <= window;
    }

    /// Logical positions may include the output cursor at output_limit.
    pub inline fn physical(self: *const Window, logical: usize) usize {
        std.debug.assert(self.valid());
        std.debug.assert(logical <= self.output_limit);
        return (self.base + logical) & mask;
    }

    /// The caller guarantees that this logical byte has been initialized.
    pub inline fn read(self: *const Window, logical: usize) u8 {
        std.debug.assert(logical < self.output_limit);
        return self.storage[self.physical(logical)];
    }

    /// Trusted writes: the semantic loop checks token capacity first.
    pub inline fn putLiteral(self: *const Window, out_pos: usize, value: u8) void {
        std.debug.assert(out_pos >= self.prefix_len and out_pos < self.output_limit);
        self.storage[self.physical(out_pos)] = value;
    }

    pub inline fn putPair(self: *const Window, out_pos: usize, first: u8, second: u8) void {
        std.debug.assert(out_pos >= self.prefix_len and out_pos <= self.output_limit);
        std.debug.assert(self.output_limit - out_pos >= 2);
        const destination = self.physical(out_pos);
        if (destination != mask) {
            self.storage[destination..][0..2].* = .{ first, second };
        } else {
            self.storage[mask] = first;
            self.storage[0] = second;
        }
    }

    /// Exact, generative LZ copying, including overlapping and wrapped spans.
    /// Invalid distance wins over output-capacity errors, as in the linear
    /// semantic decoder. Errors leave all storage unchanged. Length zero still
    /// validates the distance and the output position.
    pub fn copyMatch(self: *const Window, out_pos: usize, length: usize, distance: usize) Error!void {
        std.debug.assert(self.valid());
        if (distance == 0 or distance > @min(window, out_pos)) return error.InvalidMatch;
        if (out_pos < self.prefix_len or out_pos > self.output_limit or
            length > self.output_limit - out_pos) return error.OutputTooSmall;
        if (length == 0) return;

        if (distance == 1) {
            const value = self.read(out_pos - 1);
            const destination = self.physical(out_pos);
            const first = @min(length, capacity - destination);
            @memset(self.storage[destination..][0..first], value);
            @memset(self.storage[0 .. length - first], value);
            return;
        }

        var written: usize = 0;
        while (written < length) {
            const source = self.physical(out_pos - distance + written);
            const destination = self.physical(out_pos + written);
            const count = @min(length - written, @min(capacity - source, capacity - destination));
            copyContiguous(
                self.storage[destination..][0..count],
                self.storage[source..][0..count],
                distance,
            );
            written += count;
        }
    }

    /// Copy exactly output.len initialized logical bytes. The caller output
    /// must not alias storage; this method does not advance controller cursors.
    pub fn drain(self: *const Window, logical_start: usize, output: []u8) void {
        std.debug.assert(self.valid());
        std.debug.assert(logical_start <= self.output_limit);
        std.debug.assert(output.len <= self.output_limit - logical_start);
        if (output.len == 0) return;
        const source = self.physical(logical_start);
        const first = @min(output.len, capacity - source);
        @memcpy(output[0..first], self.storage[source..][0..first]);
        @memcpy(output[first..], self.storage[0 .. output.len - first]);
    }

    /// Move an initialized chronological tail into storage[0..len], len <=
    /// window. All other bytes remain unchanged. The controller must first
    /// release other logical ranges and then replace its own metadata.
    pub fn normalizeTail(self: *const Window, logical_start: usize, len: usize) void {
        std.debug.assert(self.valid());
        std.debug.assert(len <= window and logical_start <= self.output_limit);
        std.debug.assert(len <= self.output_limit - logical_start);
        if (len == 0) return;
        const source = self.physical(logical_start);
        if (source == 0) return;
        const first = @min(len, capacity - source);
        if (first == len) {
            @memmove(self.storage[0..len], self.storage[source..][0..len]);
        } else {
            // Wrapping requires source >= window. Preserve the low source
            // before its place becomes the destination of the high source.
            const second = len - first;
            @memmove(self.storage[first..len], self.storage[0..second]);
            @memcpy(self.storage[0..first], self.storage[source..][0..first]);
        }
    }
};

/// The first distance bytes are independent initialized source. Once seeded,
/// doubling copies already generated destination bytes with disjoint slices.
/// A source above destination can only occur across the physical wrap, where
/// the selected contiguous span is no longer than distance.
inline fn copyContiguous(destination: []u8, source: []const u8, distance: usize) void {
    if (destination.len <= distance) {
        copyExact(destination, source);
        return;
    }
    copyExact(destination[0..distance], source[0..distance]);
    var written = distance;
    while (written < destination.len) {
        const count = @min(written, destination.len - written);
        copyExact(destination[written..][0..count], destination[0..count]);
        written += count;
    }
}

inline fn copyExact(destination: []u8, source: []const u8) void {
    if (destination.len >= 3) {
        shortcopy.copy(destination, source, destination.len);
    } else {
        @memcpy(destination, source);
    }
}

test {
    _ = @import("rolling_window_tests.zig");
}
