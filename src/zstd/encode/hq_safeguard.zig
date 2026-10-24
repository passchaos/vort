//! Wire safeguards for expanded HQ search. Both searches remain mandatory;
//! search failures propagate before either candidate can be published.
const std = @import("std");
const controls = @import("controls.zig");

pub fn expanded(options: anytype) bool {
    return if (options.hq) |hq| hq.hasExpandedSearch() else false;
}

pub fn needsTransactionalPublication(options: anytype) bool {
    return if (options.hq) |hq| hq.hasSearchControls() else false;
}

/// Preserve every existing effort, memory, price, format and dictionary option.
/// Only the two expanded search-space controls define the baseline difference.
pub fn baselineOptions(options: anytype) @TypeOf(options) {
    var result = options;
    var hq = result.hq.?;
    hq.parse_mode = .bounded;
    hq.match_lengths = .sampled;
    result.hq = hq;
    return result;
}

/// Each pass has independent frame state. Shared temporary scratch remains
/// charged to the outer allocator, as do both complete wire candidates and
/// publication overlap. No per-block guard is applied inside these passes.
pub fn appendFrame(comptime Codec: type, comptime encodeSingle: anytype, allocator: std.mem.Allocator, out: *std.ArrayList(u8), input: []const u8, options: Codec.Options, dictionary: ?Codec.Dictionary, records: anytype, scratch: *Codec.SequenceScratch, block_scratch: *Codec.BlockScratch) Codec.Error!void {
    try options.validate();
    const emission = controls.EmissionTransaction.init(options.control_profile);
    errdefer emission.rollback();
    const start = out.items.len;
    errdefer out.items.len = start;
    defer if (options.control_profile) |profile| profile.recordEffectiveHq(options.hq);
    if (options.control_profile) |profile| profile.add("guarded_frames", 1);
    var requested: std.ArrayList(u8) = .empty;
    defer requested.deinit(allocator);
    var baseline: std.ArrayList(u8) = .empty;
    defer baseline.deinit(allocator);

    try encodeSingle(false, allocator, &requested, input, options, dictionary, records, scratch, block_scratch);
    const requested_emitted = if (options.control_profile) |profile| profile.emitted() else controls.Profile.Emitted{};
    if (options.control_profile) |profile| profile.restoreEmitted(emission.previous);
    try encodeSingle(true, allocator, &baseline, input, baselineOptions(options), dictionary, records, scratch, block_scratch);
    const baseline_emitted = if (options.control_profile) |profile| profile.emitted() else controls.Profile.Emitted{};
    const choose_baseline = baseline.items.len <= requested.items.len;
    const selected = if (choose_baseline) &baseline else &requested;
    const discarded = if (choose_baseline) &requested else &baseline;
    discarded.deinit(allocator);
    discarded.* = .empty;
    try out.appendSlice(allocator, selected.items);
    if (options.control_profile) |profile| {
        profile.restoreEmitted(if (choose_baseline) baseline_emitted else requested_emitted);
        if (choose_baseline) profile.add("baseline_selected_frames", 1);
    }
}
