//! Atomic public destinations around the shared parallel frame pipeline.
const std = @import("std");
const memory = @import("../../io/threaded_working_memory.zig");
const types = @import("types.zig");
const pipeline = @import("pipeline.zig");

pub fn Public(comptime Codec: type) type {
    return struct {
        pub const Error = Codec.Error || std.Thread.SpawnError;

        const Destination = union(enum) {
            allocate: *[]u8,
            append: *std.ArrayList(u8),
            into: []u8,
        };

        pub fn bound(input_len: usize, options: Codec.Options, parallel: types.Options) Error!usize {
            return boundFor(input_len, options, null, parallel);
        }

        pub fn boundWithDictionary(input_len: usize, options: Codec.Options, dictionary: Codec.Dictionary, parallel: types.Options) Error!usize {
            return boundFor(input_len, options, dictionary, parallel);
        }

        pub fn boundWithDictionarySet(input_len: usize, options: Codec.Options, dictionary_set: Codec.DictionarySet, dictionary_id: u32, parallel: types.Options) Error!usize {
            return boundWithDictionary(input_len, options, try dictionaryFromSet(dictionary_set, dictionary_id), parallel);
        }

        pub fn encodeAlloc(allocator: std.mem.Allocator, input: []const u8, options: Codec.Options, parallel: types.Options) Error![]u8 {
            return allocate(allocator, input, options, null, parallel);
        }

        pub fn encodeWithDictionaryAlloc(allocator: std.mem.Allocator, input: []const u8, options: Codec.Options, dictionary: Codec.Dictionary, parallel: types.Options) Error![]u8 {
            return allocate(allocator, input, options, dictionary, parallel);
        }

        pub fn encodeWithDictionarySetAlloc(allocator: std.mem.Allocator, input: []const u8, options: Codec.Options, dictionary_set: Codec.DictionarySet, dictionary_id: u32, parallel: types.Options) Error![]u8 {
            return encodeWithDictionaryAlloc(allocator, input, options, try dictionaryFromSet(dictionary_set, dictionary_id), parallel);
        }

        pub fn append(allocator: std.mem.Allocator, out: *std.ArrayList(u8), input: []const u8, options: Codec.Options, parallel: types.Options) Error!usize {
            return encode(allocator, .{ .append = out }, input, options, null, parallel);
        }

        pub fn appendWithDictionary(allocator: std.mem.Allocator, out: *std.ArrayList(u8), input: []const u8, options: Codec.Options, dictionary: Codec.Dictionary, parallel: types.Options) Error!usize {
            return encode(allocator, .{ .append = out }, input, options, dictionary, parallel);
        }

        pub fn appendWithDictionarySet(allocator: std.mem.Allocator, out: *std.ArrayList(u8), input: []const u8, options: Codec.Options, dictionary_set: Codec.DictionarySet, dictionary_id: u32, parallel: types.Options) Error!usize {
            return appendWithDictionary(allocator, out, input, options, try dictionaryFromSet(dictionary_set, dictionary_id), parallel);
        }

        pub fn into(allocator: std.mem.Allocator, input: []const u8, options: Codec.Options, output: []u8, parallel: types.Options) Error!usize {
            return encode(allocator, .{ .into = output }, input, options, null, parallel);
        }

        pub fn intoWithDictionary(allocator: std.mem.Allocator, input: []const u8, options: Codec.Options, dictionary: Codec.Dictionary, output: []u8, parallel: types.Options) Error!usize {
            return encode(allocator, .{ .into = output }, input, options, dictionary, parallel);
        }

        pub fn intoWithDictionarySet(allocator: std.mem.Allocator, input: []const u8, options: Codec.Options, dictionary_set: Codec.DictionarySet, dictionary_id: u32, output: []u8, parallel: types.Options) Error!usize {
            return intoWithDictionary(allocator, input, options, try dictionaryFromSet(dictionary_set, dictionary_id), output, parallel);
        }

        fn dictionaryFromSet(dictionary_set: Codec.DictionarySet, dictionary_id: u32) Error!Codec.Dictionary {
            if (dictionary_id == 0) return error.NeedDictionary;
            return dictionary_set.find(dictionary_id) orelse error.NeedDictionary;
        }

        fn boundFor(input_len: usize, options: Codec.Options, dictionary: ?Codec.Dictionary, parallel: types.Options) Error!usize {
            const inner = try Codec.prepareOptions(options, dictionary);
            _ = try types.Geometry.init(input_len, try Codec.blockSize(inner), parallel);
            return Codec.bound(input_len, inner);
        }

        fn allocate(allocator: std.mem.Allocator, input: []const u8, options: Codec.Options, dictionary: ?Codec.Dictionary, parallel: types.Options) Error![]u8 {
            var frame: []u8 = undefined;
            _ = try encode(allocator, .{ .allocate = &frame }, input, options, dictionary, parallel);
            return frame;
        }

        fn encode(
            caller_allocator: std.mem.Allocator,
            destination: Destination,
            input: []const u8,
            options: Codec.Options,
            dictionary: ?Codec.Dictionary,
            parallel: types.Options,
        ) Error!usize {
            // Scalar and admission validation must not publish caller profiles.
            const inner = try Codec.prepareOptions(options, dictionary);
            const geometry = try types.Geometry.init(input.len, try Codec.blockSize(inner), parallel);
            _ = try Codec.bound(input.len, inner);
            const limit = @min(parallel.max_working_memory, options.max_total_working_memory orelse std.math.maxInt(usize));
            var work: Codec.Profile = .{};
            Codec.profileOptions(inner, &work);
            var profile: types.Profile = .{
                .available = true,
                .serial_fallback = geometry.worker_count == 0,
                .configured_workers = parallel.worker_count,
                .effective_workers = if (geometry.worker_count == 0) 1 else geometry.worker_count,
                .effective_job_size = geometry.job_size,
                .job_count = geometry.job_count,
            };
            var published = false;
            defer {
                if (options.control_profile) |caller_profile| {
                    caller_profile.mergeWork(work);
                    if (published) caller_profile.mergeEmitted(work.emitted());
                }
                if (options.memory_profile) |caller_profile| {
                    caller_profile.record(profile.peak_requested_bytes, limit);
                    caller_profile.record(profile.live_requested_bytes, limit);
                }
                if (parallel.profile) |caller_profile| caller_profile.* = profile;
            }

            const control = try memory.Control.create(caller_allocator, limit, 0);
            defer {
                // Staged storage is already freed or disowned at this point.
                profile.peak_requested_bytes = control.snapshot().peak_requested_bytes;
                control.destroy();
                profile.live_requested_bytes = 0;
            }
            const allocator = control.allocator();
            var staged: std.ArrayList(u8) = .empty;
            defer staged.deinit(allocator);
            var inner_parallel = parallel;
            inner_parallel.profile = null;
            try pipeline.Pipeline(Codec).append(control, &staged, input, inner, inner_parallel, dictionary, &work, &profile);

            // Input and dictionary aliases have been fully consumed, and all
            // threads joined, before the caller's destination can change.
            const frame_len = staged.items.len;
            control.coordinator.clearFailure();
            switch (destination) {
                .allocate => |frame| {
                    const wire = staged.toOwnedSlice(allocator) catch |err| return control.coordinator.mapError(err);
                    control.budget.releaseExisting(wire.len);
                    frame.* = wire;
                },
                .append => |out| try appendFrame(caller_allocator, control, out, staged.items),
                .into => |output| {
                    if (output.len < frame_len) return error.OutputTooSmall;
                    @memcpy(output[0..frame_len], staged.items);
                },
            }
            published = true;
            return frame_len;
        }

        fn appendFrame(caller_allocator: std.mem.Allocator, control: *memory.Control, out: *std.ArrayList(u8), frame: []const u8) Error!void {
            const end = std.math.add(usize, out.items.len, frame.len) catch return error.IntegerOverflow;
            if (end <= out.capacity) {
                @memcpy(out.items.ptr[out.items.len..end], frame);
                out.items.len = end;
                return;
            }
            // Retain the caller's old allocation until the exact replacement
            // is fully populated. Only the replacement is charged here.
            const replacement = control.allocator().alloc(u8, end) catch |err| return control.coordinator.mapError(err);
            @memcpy(replacement[0..out.items.len], out.items);
            @memcpy(replacement[out.items.len..], frame);
            control.budget.releaseExisting(replacement.len);
            out.deinit(caller_allocator);
            out.* = .{ .items = replacement, .capacity = replacement.len };
        }
    };
}
