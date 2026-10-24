const std = @import("std");
const working = @import("../../io/working_allocator.zig");
const history = @import("../history.zig");
const history_sink = @import("history_sink.zig");

/// A single-owner, reusable LZMA decoder. Models borrow the owned probability
/// allocation; allocator callbacks are bound only inside synchronous methods.
pub fn Workspace(comptime Codec: type) type {
    return struct {
        allocator: std.mem.Allocator,
        options: Options,
        budget: working.WorkingAllocator,
        model: ?std.compress.lzma.Decode = null,
        literal_storage: []u16 = &.{},
        dictionary: history.CircularBuffer = history.CircularBuffer.init(4096, std.math.maxInt(usize)),
        input_copy: std.ArrayList(u8) = .empty,
        last_decoded_len: usize = 0,
        last_input_read: usize = 0,

        const Self = @This();
        pub const Options = Codec.Options;
        pub const Error = Codec.Error || std.mem.Allocator.Error || error{WorkingMemoryLimitExceeded};
        pub const Snapshot = struct {
            probability_capacity: usize,
            active_probability_bytes: usize,
            dictionary_capacity: usize,
            input_copy_capacity: usize,
            retained_decoded_capacity: usize,
            working_bytes: usize,
            peak_working_bytes: usize,
            last_decoded_len: usize,
            last_input_read: usize,
        };
        const Request = struct {
            payload: []const u8,
            properties: std.compress.lzma.Decode.Properties,
            dictionary_size: usize,
            output_limit: usize,
            declared_size: ?usize,
            micro: bool = false,
            allow_partial: bool = false,
            reject_end_marker: bool = false,
            require_end_marker: bool = false,
            require_full_input: bool = false,
            require_range_end: bool = false,
        };
        const Summary = struct { decoded_len: usize, input_read: usize };

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator, .options = .{}, .budget = working.WorkingAllocator.init(allocator, std.math.maxInt(usize)) };
        }
        pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Error!Self {
            try options.validate();
            return .{ .allocator = allocator, .options = options, .budget = working.WorkingAllocator.init(allocator, options.max_working_memory) };
        }
        pub fn deinit(self: *Self) void {
            // std.Decode's Vec2d is a non-owning view. Free the full retained
            // allocation here rather than an active property-dependent slice.
            self.model = null;
            self.budget.allocator().free(self.literal_storage);
            self.dictionary.deinit(self.budget.allocator());
            self.input_copy.deinit(self.budget.allocator());
            std.debug.assert(self.budget.live == 0);
            self.* = undefined;
        }
        pub fn reset(self: *Self) void {
            self.resetRetaining();
        }
        pub fn resetRetaining(self: *Self) void {
            self.dictionary.bytes.clearRetainingCapacity();
            self.dictionary.cursor = 0;
            self.dictionary.len = 0;
            self.dictionary.allow_partial = false;
            self.input_copy.clearRetainingCapacity();
            if (self.model) |*model| self.resetModel(model.properties);
            self.budget.peak = self.budget.live;
            self.budget.hit_limit = false;
            self.budget.last_failure_was_limit = false;
            self.last_decoded_len = 0;
            self.last_input_read = 0;
        }
        pub fn resetWithOptions(self: *Self, options: Options) Error!void {
            try options.validate();
            const allocator = self.allocator;
            self.deinit();
            self.* = try initWithOptions(allocator, options);
        }
        pub fn workingMemoryBytes(self: *const Self) usize {
            return self.budget.live;
        }
        pub fn peakWorkingMemoryBytes(self: *const Self) usize {
            return self.budget.peak;
        }
        pub fn snapshot(self: *const Self) Snapshot {
            return .{
                .probability_capacity = self.literal_storage.len * @sizeOf(u16),
                .active_probability_bytes = if (self.model) |model| @as(usize, 1536) << (model.properties.lc + model.properties.lp) else 0,
                .dictionary_capacity = self.dictionary.bytes.capacity,
                .input_copy_capacity = self.input_copy.capacity,
                .retained_decoded_capacity = 0,
                .working_bytes = self.budget.live,
                .peak_working_bytes = self.budget.peak,
                .last_decoded_len = self.last_decoded_len,
                .last_input_read = self.last_input_read,
            };
        }

        pub fn decodeInto(self: *Self, input: []const u8, output: []u8) Error!usize {
            const header = try Codec.parseHeader(input);
            try self.checkDictionary(header.dictionary_size);
            const request = self.aloneRequest(input[13..], header, @min(output.len, self.options.max_output_len)) catch |err|
                return self.intoError(err, output.len);
            const summary = self.prevalidate(request) catch |err| return self.intoError(err, output.len);
            try self.replay(request, summary, output);
            self.note(summary);
            return summary.decoded_len;
        }
        pub fn decodedSize(self: *Self, input: []const u8) Error!usize {
            return self.decodedSizeLimited(input, std.math.maxInt(usize));
        }
        pub fn decodedSizeLimited(self: *Self, input: []const u8, max_output_len: usize) Error!usize {
            const header = try Codec.parseHeader(input);
            try self.checkDictionary(header.dictionary_size);
            const request = try self.aloneRequest(input[13..], header, @min(max_output_len, self.options.max_output_len));
            const summary = try self.prevalidate(request);
            self.note(summary);
            return summary.decoded_len;
        }
        pub fn decodeMicroInto(self: *Self, input: []const u8, output: []u8, dictionary_size: u32) Error!void {
            try self.decodeMicroIntoWithOptions(input, output, .{ .dictionary_size = dictionary_size, .max_output_len = output.len });
        }
        pub fn decodeMicroIntoWithOptions(self: *Self, input: []const u8, output: []u8, options: Codec.MicroOptions) Error!void {
            if (output.len > options.max_output_len or output.len > self.options.max_output_len) return error.OutputLimitExceeded;
            if (options.dictionary_size < 4096 or options.dictionary_size > (1 << 30) + (1 << 29)) return error.OutputLimitExceeded;
            try self.checkDictionary(options.dictionary_size);
            if (input.len < 5) return error.TruncatedFrame;
            const request = Request{
                .payload = input,
                .properties = try Codec.parseProperties(~input[0]),
                .dictionary_size = options.dictionary_size,
                .output_limit = output.len,
                .declared_size = output.len,
                .micro = true,
                .allow_partial = options.allow_partial,
                .reject_end_marker = true,
                .require_full_input = !options.allow_partial,
                .require_range_end = !options.allow_partial,
            };
            const summary = try self.prevalidate(request);
            try self.replay(request, summary, output);
            self.note(summary);
        }
        pub fn decodeZipPayloadInto(self: *Self, payload: []const u8, expected_size: usize, output: []u8, max_dictionary_size: usize, end_marker: bool) Error!usize {
            if (output.len < expected_size) return error.OutputTooSmall;
            if (payload.len < 9) return error.TruncatedFrame;
            if (std.mem.readInt(u16, payload[2..4], .little) != 5) return error.InvalidLzmaHeader;
            const properties = try Codec.parseProperties(payload[4]);
            const dictionary_size = @max(@as(u32, 4096), std.mem.readInt(u32, payload[5..9], .little));
            if (dictionary_size > max_dictionary_size) return error.OutputLimitExceeded;
            try self.checkDictionary(dictionary_size);
            const limit = @min(expected_size, self.options.max_output_len);
            const request = Request{
                .payload = payload[9..],
                .properties = properties,
                .dictionary_size = dictionary_size,
                .output_limit = limit,
                .declared_size = if (end_marker) null else expected_size,
                .require_end_marker = end_marker,
                .require_full_input = end_marker,
            };
            if (request.declared_size) |size| if (size > limit) return error.OutputLimitExceeded;
            const summary = try self.prevalidate(request);
            try self.replay(request, summary, output);
            self.note(summary);
            return summary.decoded_len;
        }
        fn checkDictionary(self: *const Self, dictionary_size: u32) Error!void {
            if (dictionary_size > self.options.max_dictionary_size) return error.OutputLimitExceeded;
        }
        fn aloneRequest(self: *const Self, payload: []const u8, header: anytype, limit: usize) Error!Request {
            _ = self;
            const declared: ?usize = if (header.uncompressed_size) |size| std.math.cast(usize, size) orelse return error.OutputLimitExceeded else null;
            if (declared) |size| if (size > limit) return error.OutputLimitExceeded;
            return .{
                .payload = payload,
                .properties = .{ .lc = header.lc, .lp = header.lp, .pb = header.pb },
                .dictionary_size = header.dictionary_size,
                .output_limit = declared orelse limit,
                .declared_size = declared,
                .require_end_marker = declared == null,
                .require_full_input = declared == null,
            };
        }
        fn intoError(self: *const Self, err: Error, capacity: usize) Error {
            if (err == error.OutputLimitExceeded and capacity <= self.options.max_output_len) return error.OutputTooSmall;
            return err;
        }
        fn note(self: *Self, summary: Summary) void {
            self.last_decoded_len = summary.decoded_len;
            self.last_input_read = summary.input_read;
        }

        fn prepareModel(self: *Self, properties: std.compress.lzma.Decode.Properties) Error!void {
            if (self.model == null) {
                const model = std.compress.lzma.Decode.init(self.budget.allocator(), properties) catch |err| return mapInitError(err);
                self.literal_storage = model.literal_probs.data;
                self.model = model;
                return;
            }
            const required = @as(usize, 768) << (properties.lc + properties.lp);
            if (required > self.literal_storage.len) {
                const replacement = try self.budget.allocator().alloc(u16, required);
                const old = self.literal_storage;
                self.literal_storage = replacement;
                self.model.?.literal_probs.data = replacement;
                self.budget.allocator().free(old);
            }
            self.resetModel(properties);
        }
        fn resetModel(self: *Self, properties: std.compress.lzma.Decode.Properties) void {
            const model = &self.model.?;
            model.literal_probs = .{ .data = self.literal_storage, .cols = 0x300 };
            // Binding the retained superset and selecting the new properties
            // before reset forces std's no-allocation branch. It resets every
            // fixed probability tree, rep offset and state as well as literals.
            model.properties = properties;
            model.resetState(self.budget.allocator(), properties) catch unreachable;
        }
        fn prepareHistory(self: *Self, request: Request) void {
            self.dictionary.bytes.clearRetainingCapacity();
            self.dictionary.dictionary_size = request.dictionary_size;
            self.dictionary.output_limit = request.output_limit;
            self.dictionary.cursor = 0;
            self.dictionary.len = 0;
            self.dictionary.allow_partial = request.allow_partial;
        }
        fn prevalidate(self: *Self, request: Request) Error!Summary {
            self.budget.limit = self.options.max_working_memory;
            if (self.budget.live > self.budget.limit) return error.WorkingMemoryLimitExceeded;
            self.budget.last_failure_was_limit = false;
            return self.run(request, null, true) catch |err| return self.mapBudgetError(err);
        }
        fn run(self: *Self, request: Request, destination: ?[]u8, prepare: bool) Error!Summary {
            if (request.declared_size) |size| if (size > request.output_limit) return error.OutputLimitExceeded;
            var input: std.Io.Reader = .fixed(request.payload);
            var range_decoder = if (request.micro) blk: {
                if (request.payload.len < 5) return error.TruncatedFrame;
                input.seek = 5;
                break :blk std.compress.lzma.RangeDecoder{ .range = std.math.maxInt(u32), .code = std.mem.readInt(u32, request.payload[1..5], .big) };
            } else std.compress.lzma.RangeDecoder.init(&input) catch |err| return mapInitError(err);
            if (prepare) try self.prepareModel(request.properties);
            self.prepareHistory(request);
            var scratch: [273]u8 = undefined;
            var output: std.Io.Writer.Allocating = .{ .allocator = self.budget.allocator(), .writer = .fixed(destination orelse &scratch), .alignment = .of(u8) };
            var saw_end_marker = false;
            while (true) {
                if (request.declared_size) |size| if (self.dictionary.len == size) break;
                if (destination == null) output.writer.end = 0;
                var bytes_read: u64 = 0;
                var sink = history_sink.Sink.init(&self.dictionary);
                const status = self.model.?.process(&input, &output, &sink, &range_decoder, &bytes_read) catch |err| switch (err) {
                    error.OutputLimitExceeded => return if (request.declared_size != null) error.SizeMismatch else error.OutputLimitExceeded,
                    else => return mapProcessError(err),
                };
                if (status == .finished) {
                    if (request.reject_end_marker) return error.InvalidLzmaStream;
                    saw_end_marker = true;
                    break;
                }
            }
            const count = self.dictionary.len;
            if (count > request.output_limit) return error.OutputLimitExceeded;
            if (request.declared_size) |size| if (count != size) return error.SizeMismatch;
            if (request.require_end_marker and !saw_end_marker) return error.InvalidLzmaStream;
            if (request.require_range_end and !range_decoder.isFinished()) return error.InvalidLzmaStream;
            if (request.require_full_input and input.seek != request.payload.len) return error.TrailingData;
            return .{ .decoded_len = count, .input_read = input.seek };
        }
        fn replay(self: *Self, original: Request, summary: Summary, output: []u8) Error!void {
            if (summary.decoded_len > output.len) return error.OutputTooSmall;
            var request = original;
            // Legacy Into permits compressed input and plaintext output to
            // overlap. Protect only bytes the validated replay will consume.
            if (overlaps(original.payload[0..summary.input_read], output[0..summary.decoded_len])) {
                self.budget.last_failure_was_limit = false;
                self.input_copy.clearRetainingCapacity();
                self.input_copy.ensureTotalCapacityPrecise(self.budget.allocator(), summary.input_read) catch |err| return self.mapBudgetError(err);
                self.input_copy.appendSliceAssumeCapacity(original.payload[0..summary.input_read]);
                request.payload = self.input_copy.items;
            }
            // All history prefixes are no longer than the final validated
            // output, and the active literal shape was warmed by pre-scan.
            // These bounds make every replay reserve a capacity-only no-op.
            std.debug.assert(self.dictionary.bytes.capacity >= @min(request.dictionary_size, summary.decoded_len));
            std.debug.assert(self.literal_storage.len >= (@as(usize, 768) << (request.properties.lc + request.properties.lp)));
            self.resetModel(request.properties);
            // The validated byte sequence, limits and state are identical.
            // Pre-scan already grew every history allocation that replay can
            // need, and the output is exactly large enough for all symbols.
            const repeated = self.run(request, output[0..summary.decoded_len], false) catch unreachable;
            std.debug.assert(repeated.decoded_len == summary.decoded_len and repeated.input_read == summary.input_read);
        }
        fn mapBudgetError(self: *const Self, err: Error) Error {
            return if (err == error.OutOfMemory and self.budget.last_failure_was_limit) error.WorkingMemoryLimitExceeded else err;
        }
        fn mapInitError(err: anyerror) Error {
            return switch (err) {
                error.OutOfMemory => error.OutOfMemory,
                error.EndOfStream => error.TruncatedFrame,
                error.Overflow => error.IntegerOverflow,
                else => error.InvalidLzmaStream,
            };
        }
        fn mapProcessError(err: anyerror) Error {
            return switch (err) {
                error.OutOfMemory, error.WriteFailed => error.OutOfMemory,
                error.EndOfStream => error.TruncatedFrame,
                error.Overflow => error.IntegerOverflow,
                error.OutputLimitExceeded => error.OutputLimitExceeded,
                else => error.InvalidLzmaStream,
            };
        }
    };
}

fn overlaps(input: []const u8, output: []const u8) bool {
    if (input.len == 0 or output.len == 0) return false;
    const a = @intFromPtr(input.ptr);
    const b = @intFromPtr(output.ptr);
    return if (a <= b) b - a < input.len else a - b < output.len;
}
