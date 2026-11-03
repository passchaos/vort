//! Independent test oracle: linear 64 KiB bytes and a byte-at-a-time LZ walk.
//! No production ring mapping or copy kernel is used here.
const capacity: usize = 65536;
const lookback: usize = 32768;

pub fn physical(base: usize, logical: usize) usize {
    const sum = base + logical;
    return if (sum >= capacity) sum - capacity else sum;
}

pub const Linear = struct {
    bytes: [capacity]u8,
    prefix_len: usize,
    output_limit: usize,

    pub fn init(prefix_len: usize, output_limit: usize) Linear {
        var self: Linear = undefined;
        self.prefix_len = prefix_len;
        self.output_limit = output_limit;
        for (&self.bytes, 0..) |*byte, logical| {
            byte.* = @truncate((logical *% 73) ^ (logical >> 7) ^ (logical >> 11) ^ 0x9b);
        }
        return self;
    }

    pub fn putLiteral(self: *Linear, position: usize, value: u8) void {
        self.bytes[position] = value;
    }

    pub fn putPair(self: *Linear, position: usize, first: u8, second: u8) void {
        self.bytes[position] = first;
        self.bytes[position + 1] = second;
    }

    pub fn copyMatch(self: *Linear, position: usize, length: usize, distance: usize) error{ InvalidMatch, OutputTooSmall }!void {
        if (distance == 0) return error.InvalidMatch;
        if (distance > lookback) return error.InvalidMatch;
        if (distance > position) return error.InvalidMatch;
        if (position < self.prefix_len) return error.OutputTooSmall;
        if (position > self.output_limit) return error.OutputTooSmall;
        if (length > self.output_limit - position) return error.OutputTooSmall;
        var cursor = position;
        const end = position + length;
        while (cursor != end) : (cursor += 1) {
            self.bytes[cursor] = self.bytes[cursor - distance];
        }
    }

    pub fn scatter(self: *const Linear, storage: []u8, base: usize) void {
        for (self.bytes, 0..) |byte, logical| {
            storage[physical(base, logical)] = byte;
        }
    }
};
