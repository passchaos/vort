//! Public one-frame wire contracts, specialized by the codec facade hook.
const std = @import("std");
const h = @import("helpers.zig");
const a = h.a;

pub fn run(comptime Z: type) type {
    return struct {
        test "Zstd parallel frame empty tiny structured random and repeated inputs keep one envelope" {
            const structured = h.structured();
            var random: [513]u8 = undefined;
            h.noise(&random, 0x73951);
            const inputs = [_][]const u8{ "", "a", "abc", &structured, &random, "r" ** 513 };
            for (inputs) |input| for (0..4) |variant| {
                var options = h.native(Z);
                options.selection = .raw_or_rle;
                options.format = if (variant & 1 == 0) .standard else .magicless;
                options.include_content_size = variant < 2;
                options.content_checksum = variant != 1;
                var profile: Z.ParallelProfile = .{};
                const limits = h.parallel(Z, &profile, 2);
                const frame = try Z.encodeNativeParallelFrameAlloc(a, input, options, limits);
                defer a.free(frame);
                const summary = try h.verify(Z, frame, input, options, null);
                try std.testing.expect(summary.compressed == 0);
                try h.complete(Z, profile, input.len, options, limits, summary.blocks);
                try std.testing.expect(frame.len <= try Z.encodedNativeParallelFrameBound(input.len, options, limits));
            };
        }

        test "Zstd parallel frame all native selections preserve ordered same geometry fallback wire" {
            const input = h.structured();
            for ([_]Z.NativeFrameSelection{ .auto, .raw_or_rle, .literal_only, .fast_compressed }) |selection| {
                var options = h.native(Z);
                options.selection = selection;
                var serial_profile: Z.ParallelProfile = .{};
                var serial = h.parallel(Z, &serial_profile, 1);
                serial.io = .failing;
                const expected = try Z.encodeNativeParallelFrameAlloc(a, &input, options, serial);
                defer a.free(expected);
                var profile: Z.ParallelProfile = .{};
                const limits = h.parallel(Z, &profile, 2);
                const actual = try Z.encodeNativeParallelFrameAlloc(a, &input, options, limits);
                defer a.free(actual);
                try std.testing.expectEqualSlices(u8, expected, actual);
                const summary = try h.verify(Z, actual, &input, options, null);
                try h.complete(Z, profile, input.len, options, limits, summary.blocks);
                try h.complete(Z, serial_profile, input.len, options, serial, summary.blocks);
            }
        }

        test "Zstd parallel frame all controlled strategies and legacy beam keep candidates and work" {
            const input = "abcdefghabcdefghXbcdefghYabcdefgh" ** 16;
            const strategies = [_]Z.Strategy{ .fast, .double_fast, .greedy, .lazy, .optimal, .lazy2, .btlazy2, .btopt, .btultra, .btultra2 };
            for (strategies) |strategy| {
                var work: Z.EncoderControlProfile = .{};
                var options = h.native(Z);
                options.strategy = strategy;
                options.control_profile = &work;
                if (strategy == .lazy2 or strategy == .btlazy2 or strategy == .btopt or strategy == .btultra or strategy == .btultra2)
                    options.hq = .{ .search_depth = 8, .nice_len = 32 };
                var profile: Z.ParallelProfile = .{};
                const limits = h.parallel(Z, &profile, 2);
                const actual = try Z.encodeNativeParallelFrameAlloc(a, input, options, limits);
                defer a.free(actual);
                const summary = try h.verify(Z, actual, input, options, null);
                try std.testing.expect(work.available and work.controls_used and work.parser_matches > 0);
                try std.testing.expectEqual(strategy, work.resolved_strategy);
                try std.testing.expect(summary.compressed > 0);
                try h.complete(Z, profile, input.len, options, limits, summary.blocks);
                var serial = limits;
                serial.worker_count = 1;
                serial.profile = null;
                options.control_profile = null;
                const expected = try Z.encodeNativeParallelFrameAlloc(a, input, options, serial);
                defer a.free(expected);
                try std.testing.expectEqualSlices(u8, expected, actual);
            }
            var options = h.native(Z);
            options.selection = .fast_compressed;
            options.rep_beam_search = true;
            var profile: Z.ParallelProfile = .{};
            const limits = h.parallel(Z, &profile, 2);
            const legacy = try Z.encodeNativeParallelFrameAlloc(a, input, options, limits);
            defer a.free(legacy);
            const summary = try h.verify(Z, legacy, input, options, null);
            try h.complete(Z, profile, input.len, options, limits, summary.blocks);
        }

        test "Zstd parallel frame cross job history remains real and entropy state is independently decodable" {
            var input: [1024]u8 = undefined;
            h.noise(input[0..256], 0x8a972);
            for (1..4) |job| @memcpy(input[job * 256 ..][0..256], input[0..256]);
            var options = h.native(Z);
            options.strategy = .btultra2;
            options.hq = .{ .search_depth = 8, .nice_len = 32 };
            var work: Z.EncoderControlProfile = .{};
            options.control_profile = &work;
            var profile: Z.ParallelProfile = .{};
            const limits = h.parallel(Z, &profile, 2);
            const actual = try Z.encodeNativeParallelFrameAlloc(a, &input, options, limits);
            defer a.free(actual);
            const summary = try h.verify(Z, actual, &input, options, null);
            try std.testing.expect(work.history_seed_positions > 0 and work.history_sequences > 0);
            try std.testing.expect(summary.raw > 0 and summary.compressed > 0);
            try h.complete(Z, profile, input.len, options, limits, summary.blocks);
            var serial = limits;
            serial.worker_count = 1;
            serial.profile = null;
            options.control_profile = null;
            const expected = try Z.encodeNativeParallelFrameAlloc(a, &input, options, serial);
            defer a.free(expected);
            try std.testing.expectEqualSlices(u8, expected, actual);
        }

        test "Zstd parallel frame raw and RLE blocks between Huffman only blocks retain valid tables" {
            var input: [640]u8 = undefined;
            h.noise(&input, 0x4a391);
            for (input[0..128]) |*byte| byte.* &= 3;
            @memset(input[256..384], 'x');
            for (input[384..]) |*byte| byte.* &= 3;
            var options = h.native(Z);
            options.selection = .auto;
            var profile: Z.ParallelProfile = .{};
            var limits = h.parallel(Z, &profile, 2);
            // Auto selects a mode for each whole job. Isolate the RLE block
            // from its Huffman neighbor so the shortest job mode is wire RLE.
            limits.job_size = options.block_size_max;
            const frame = try Z.encodeNativeParallelFrameAlloc(a, &input, options, limits);
            defer a.free(frame);
            const summary = try h.verify(Z, frame, &input, options, null);
            const kinds = summary.kinds[0..summary.blocks];
            try std.testing.expect(kinds[0] == 2 and kinds[kinds.len - 1] == 2);
            var saw_raw = false;
            var saw_rle_after_raw = false;
            for (kinds[1 .. kinds.len - 1]) |kind| {
                if (kind == 0) saw_raw = true;
                if (kind == 1 and saw_raw) saw_rle_after_raw = true;
            }
            try std.testing.expect(saw_rle_after_raw);
            try std.testing.expectEqual(summary.compressed, summary.literal_only_compressed);
            try h.complete(Z, profile, input.len, options, limits, summary.blocks);
        }

        test "Zstd parallel frame raw and full dictionaries preserve IDs matches and catalog variants" {
            var dictionary_bytes: [256]u8 = undefined;
            h.noise(&dictionary_bytes, 0x75216);
            var input: [513]u8 = undefined;
            @memcpy(input[0..256], &dictionary_bytes);
            @memcpy(input[256..512], &dictionary_bytes);
            input[512] = 'z';
            const full_bytes = try h.full_dictionary(a);
            defer a.free(full_bytes);
            const dictionaries = [_]Z.NativeDictionary{ Z.NativeDictionary.init(0x1234, &dictionary_bytes), (try Z.NativeDictionary.initFromStandardDictionary(full_bytes)).dictionary };
            const inputs = [_][]const u8{ &input, ("b" ++ "a" ** 64 ++ "c" ++ "a" ** 64) ** 4 };
            for (dictionaries, inputs) |dictionary, plain| {
                var options = h.native(Z);
                options.strategy = .btultra2;
                options.hq = .{ .search_depth = 8, .nice_len = 32 };
                var work: Z.EncoderControlProfile = .{};
                options.control_profile = &work;
                var profile: Z.ParallelProfile = .{};
                const limits = h.parallel(Z, &profile, 2);
                const frame = try Z.encodeNativeParallelFrameWithDictionaryAlloc(a, plain, options, dictionary, limits);
                defer a.free(frame);
                const summary = try h.verify(Z, frame, plain, options, dictionary);
                try std.testing.expect(work.dictionary_sequences > 0);
                try h.complete(Z, profile, plain.len, options, limits, summary.blocks);
                const set = Z.NativeDictionarySet.init(&.{dictionary});
                const selected = try Z.encodeNativeParallelFrameWithDictionarySetAlloc(a, plain, options, set, dictionary.id, limits);
                defer a.free(selected);
                try std.testing.expectEqualSlices(u8, frame, selected);
                try std.testing.expect(frame.len <= try Z.encodedNativeParallelFrameBoundWithDictionary(plain.len, options, dictionary, limits));
                try std.testing.expectEqual(try Z.encodedNativeParallelFrameBoundWithDictionary(plain.len, options, dictionary, limits), try Z.encodedNativeParallelFrameBoundWithDictionarySet(plain.len, options, set, dictionary.id, limits));
            }
        }
    };
}
