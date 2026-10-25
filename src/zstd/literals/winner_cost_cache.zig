//! Private winner-aware pricing. Shadow mode retains every exact query and
//! models the certificate refresh decisions that real pruning would make.
const std = @import("std");
const exact = @import("single_cost_cache.zig");
const weighted = @import("weighted_bound.zig");

pub const Mode = enum { shadow, prune };
pub const Winner = struct { payload_len: usize, match_len: usize };
pub const Work = struct {
    queries: u64 = 0,
    no_certificate: u64 = 0,
    raw_or_small: u64 = 0,
    support_mismatch: u64 = 0,
    bound_checks: u64 = 0,
    bound_errors: u64 = 0,
    would_reject: u64 = 0,
    rejected: u64 = 0,
    bound_violations: u64 = 0,
    false_rejections: u64 = 0,
    certificate_refreshes: u64 = 0,
    invalid_certificates: u64 = 0,
    equality_longer_retained: u64 = 0,
    negative_delta_total: u64 = 0,
    max_negative_delta: u64 = 0,
    max_certificate_age: u64 = 0,
    negative_delta_histogram: [18]u64 = @splat(0),
    certificate_age_histogram: [16]u64 = @splat(0),
};

pub fn canUpdate(cost: usize, candidate_len: usize, incumbent: Winner) bool {
    return cost < incumbent.payload_len or (cost == incumbent.payload_len and candidate_len > incumbent.match_len);
}

fn bucket(value: u64, comptime count: usize) usize {
    return if (value == 0) 0 else @min(count - 1, 1 + @as(usize, std.math.log2_int(u64, value)));
}

pub fn Cache(comptime Codec: type, comptime mode: Mode) type {
    return CacheWithAccounting(Codec, mode, true);
}

/// Accounting is independent of pruning and certificate semantics. The
/// untracked instance has no Work or age storage; its checked histogram state
/// and any Codec reference callbacks retain their original behavior.
pub fn CacheWithAccounting(comptime Codec: type, comptime mode: Mode, comptime track_work: bool) type {
    comptime {
        if (Codec.optimal_huffman_bits != 11) @compileError("winner costs require the verified 11-bit optimum contract");
    }
    const Certificate = weighted.Certificate(256, 11);
    return struct {
        inner: exact.CacheWithAccounting(Codec, track_work),
        certificate: ?Certificate = null,
        certificate_age: if (track_work) u64 else void = if (track_work) 0 else {},
        bound_work: if (track_work) Work else void = if (track_work) .{} else {},

        const Self = @This();
        pub fn init(block: []const u8) Codec.Error!Self {
            return .{ .inner = try exact.CacheWithAccounting(Codec, track_work).init(block) };
        }

        pub fn payloadForWinner(self: *Self, prefix_len: usize, offset: usize, match_len: usize, tail_start: usize, incumbent: ?Winner) Codec.Error!?usize {
            if (comptime track_work) {
                self.bound_work.queries +|= 1;
                if (self.certificate != null) self.certificate_age +|= 1;
            }
            const prepared = self.inner.prepareLiterals(prefix_len, tail_start) catch |err| {
                // Preserve the original error/reference callback and account
                // once, including header failures after histogram admission.
                return (try self.inner.failedPreparation(prefix_len, offset, match_len, tail_start, err)).len;
            };
            const lower = if (incumbent != null)
                self.payloadLowerBound(&prepared, prefix_len, offset, match_len)
            else
                null;
            const would_reject = if (lower) |value| !canUpdate(value, match_len, incumbent.?) else false;
            if (comptime track_work) {
                if (lower) |value| {
                    if (value == incumbent.?.payload_len and match_len > incumbent.?.match_len)
                        self.bound_work.equality_longer_retained +|= 1;
                }
            }
            if (would_reject) {
                if (comptime track_work) self.bound_work.would_reject +|= 1;
                if (mode == .prune) {
                    if (comptime track_work) {
                        self.inner.work.cost_queries +|= 1;
                        self.bound_work.rejected +|= 1;
                    }
                    self.verifyRejected(prefix_len, offset, match_len, tail_start, lower.?, incumbent.?);
                    return null;
                }
            }
            const actual = try self.inner.payloadCostPrepared(prefix_len, offset, match_len, tail_start, &prepared);
            if (comptime track_work) {
                if (lower) |value| {
                    self.bound_work.bound_violations +|= @intFromBool(value > actual.len);
                    if (would_reject and canUpdate(actual.len, match_len, incumbent.?))
                        self.bound_work.false_rejections +|= 1;
                }
            }
            // Shadow must not gain a newer witness from a query that pruning
            // would skip. This keeps its certificate ages/refusals realistic.
            if (!would_reject) if (actual.weighted_bits) |bits| {
                const replacement = Certificate.init(&prepared.frequencies, bits) catch {
                    if (comptime track_work) self.bound_work.invalid_certificates +|= 1;
                    return actual.len;
                };
                self.certificate = replacement;
                if (comptime track_work) {
                    self.certificate_age = 0;
                    self.bound_work.certificate_refreshes +|= 1;
                }
            };
            return actual.len;
        }

        fn payloadLowerBound(self: *Self, prepared: *const exact.PreparedLiterals, prefix_len: usize, offset: usize, match_len: usize) ?usize {
            if (prepared.unique < 2 or prepared.regenerated < 64) {
                if (comptime track_work) self.bound_work.raw_or_small +|= 1;
                return null;
            }
            const witness = if (self.certificate) |*value| value else {
                if (comptime track_work) self.bound_work.no_certificate +|= 1;
                return null;
            };
            const analysis = witness.analyze(&prepared.frequencies) catch {
                if (comptime track_work) self.bound_work.bound_errors +|= 1;
                return null;
            };
            if (!analysis.same_support) {
                if (comptime track_work) self.bound_work.support_mismatch +|= 1;
                return null;
            }
            const bits = analysis.bit_lower_bound orelse return null;
            if (comptime track_work) {
                self.bound_work.bound_checks +|= 1;
                self.bound_work.negative_delta_total +|= analysis.negative_delta;
                self.bound_work.max_negative_delta = @max(self.bound_work.max_negative_delta, analysis.negative_delta);
                self.bound_work.max_certificate_age = @max(self.bound_work.max_certificate_age, self.certificate_age);
                self.bound_work.negative_delta_histogram[bucket(analysis.negative_delta, 18)] +|= 1;
                self.bound_work.certificate_age_histogram[bucket(self.certificate_age, 16)] +|= 1;
            }

            const streams: u64 = if (prepared.regenerated <= 1023) 1 else 4;
            const rounded_bits = std.math.add(u64, bits, streams + 7) catch return null;
            const stream_bytes = rounded_bits / 8 + @as(u64, if (streams == 4) 6 else 0);
            // compressed_size=0 is invalid; one byte gives the minimum header.
            const header = Codec.huffmanHeaderLen(prepared.regenerated, 1) catch return null;
            const metadata = std.math.add(usize, header, Codec.minimum_tree_bytes) catch return null;
            const huffman = std.math.add(u64, stream_bytes, metadata) catch return null;
            const literal = @min(prepared.raw_cost, std.math.cast(usize, huffman) orelse return null);
            const sequence = sequenceBase(prefix_len, offset, match_len) orelse return null;
            return std.math.add(usize, sequence, literal) catch null;
        }

        fn sequenceBase(prefix_len: usize, offset: usize, match_len: usize) ?usize {
            if (@hasDecl(Codec, "singleSequenceBaseLen"))
                return Codec.singleSequenceBaseLen(prefix_len, offset, match_len) catch null;
            var best: ?usize = null;
            if (Codec.rlePayloadLen(prefix_len, offset, match_len, 0)) |value| {
                best = value;
            } else |err| switch (err) {
                error.CorruptFrame => {},
                else => return null,
            }
            if (Codec.predefinedPayloadLen(prefix_len, offset, match_len, 0)) |value| {
                if (best == null or value < best.?) best = value;
            } else |err| switch (err) {
                error.CorruptFrame => {},
                else => return null,
            }
            return best;
        }

        fn verifyRejected(self: *Self, prefix_len: usize, offset: usize, match_len: usize, tail_start: usize, lower: usize, incumbent: Winner) void {
            if (@hasDecl(Codec, "referenceCost")) {
                if (comptime track_work) self.inner.work.reference_checks +|= 1;
                const reference = Codec.referenceCost(self.inner.block, prefix_len, offset, match_len, tail_start);
                if (comptime track_work) {
                    if (reference) |cost| {
                        const invalid = lower > cost or canUpdate(cost, match_len, incumbent);
                        self.inner.work.reference_mismatches +|= @intFromBool(invalid);
                        self.bound_work.bound_violations +|= @intFromBool(lower > cost);
                        self.bound_work.false_rejections +|= @intFromBool(canUpdate(cost, match_len, incumbent));
                    } else |_| {
                        // The bounded finder discards exact-cost errors. They can
                        // never update its winner, so the pruning verdict remains
                        // valid without inventing an exact successful cost.
                    }
                } else {
                    // Reference callbacks can have observer side effects even
                    // when the cache retains no statistical feedback.
                    if (reference) |_| {} else |_| {}
                }
            }
        }
    };
}
