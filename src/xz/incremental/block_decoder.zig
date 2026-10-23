const std = @import("std");
const core = @import("../../core.zig");
const container = @import("../container.zig");
const raw_mod = @import("../lzma2_incremental_decoder.zig");
const filters_mod = @import("../incremental_filters.zig");
const filters = @import("../filters.zig");
const checks = @import("checks.zig");
const working = @import("../../io/working_allocator.zig");

pub const Error = raw_mod.Decoder.Error || filters_mod.Error || container.Error;

/// The allocator points at the containing decoder's persistent budget. Raw
/// state creates its own allocator only after this object reaches its final
/// address in the outer decoder; filter allocators already point at the outer.
pub const Decoder = struct {
    allocator: std.mem.Allocator,
    staging_budget: working.WorkingAllocator,
    inverse_chain: [3]filters.Filter = undefined,
    raw: raw_mod.Decoder,
    inverse: ?filters_mod.Decoder = null,
    header: container.BlockHeader,
    check: container.Check,
    check_state: checks.State = .{},
    staged: std.ArrayList(u8) = .empty,
    staged_offset: usize = 0,
    staging_limit: usize,
    tail_bound: usize = 0,
    body_limit: usize,
    limit_from_pledge: bool,
    raw_finished: bool = false,
    filtered_finished: bool = false,
    input_read: usize = 0,
    output_written: usize = 0,
    temporary: [256]u8 = undefined,

    pub fn init(allocator: std.mem.Allocator, header: container.BlockHeader, check: container.Check, output_limit: usize, limit_from_pledge: bool, body_limit: usize, compressed_limit: usize, staging_limit: usize, dictionary_limit: usize) Error!Decoder {
        var property: u8 = 0;
        while (property <= 40) : (property += 1) {
            if (try raw_mod.dictionarySizeFromProperty(property) == header.dictionary_size) break;
        }
        if (property > 40) return error.InvalidXzHeader;
        if (header.packed_size) |declared|
            if (declared > body_limit) return error.OutputLimitExceeded;
        if (header.unpacked_size) |declared| {
            if (declared > output_limit) return if (limit_from_pledge) error.SizeMismatch else error.OutputLimitExceeded;
        }
        var reversed: [3]filters.Filter = undefined;
        var tail_bound: usize = 0;
        for (header.filters[0..header.filter_count], 0..) |filter, i| {
            reversed[header.filter_count - 1 - i] = filter;
            tail_bound += switch (filter.kind) {
                .delta => @as(usize, 0),
                .ia64 => 32,
                .riscv => 16,
                else => 8,
            };
        }
        const raw = try raw_mod.Decoder.init(allocator, .{
            .dictionary_property = property,
            .max_dictionary_size = dictionary_limit,
            .max_output_len = output_limit,
            .expected_output_len = if (header.unpacked_size) |size| std.math.cast(usize, size) orelse return error.OutputLimitExceeded else null,
            .max_compressed_buffer_len = @min(@as(usize, 64), compressed_limit),
            .stop_after_end_marker = true,
        });
        return .{
            .allocator = allocator,
            .raw = raw,
            .staging_budget = working.WorkingAllocator.init(allocator, staging_limit),
            .inverse_chain = reversed,
            .header = header,
            .check = check,
            .staging_limit = staging_limit,
            .tail_bound = tail_bound,
            .body_limit = body_limit,
            .limit_from_pledge = limit_from_pledge,
        };
    }

    pub fn deinit(self: *Decoder) void {
        self.raw.deinit();
        if (self.inverse) |*inverse| inverse.deinit();
        self.staged.deinit(self.staging_budget.allocator());
        std.debug.assert(self.staging_budget.live == 0);
        self.* = undefined;
    }

    pub fn stagingAllocator(self: *Decoder) std.mem.Allocator {
        return self.staging_budget.allocator();
    }

    /// Rebind allocator contexts after transferring the containing decoder by
    /// value. Buffer ownership and both live counters stay with this state.
    pub fn rebindAllocator(self: *Decoder, allocator: std.mem.Allocator) void {
        self.allocator = allocator;
        self.raw.allocator = allocator;
        self.raw.budget.backing = allocator;
        self.staging_budget.backing = allocator;
        if (self.inverse) |*inverse| inverse.allocator = self.staging_budget.allocator();
    }

    pub fn step(self: *Decoder, input: []const u8, output: []u8) Error!core.StepResult {
        self.staging_budget.last_failure_was_limit = false;
        return self.stepInternal(input, output) catch |err| {
            return if (err == error.OutOfMemory and self.staging_budget.last_failure_was_limit) error.OutputLimitExceeded else err;
        };
    }

    fn stepInternal(self: *Decoder, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.header.filter_count != 0 and self.inverse == null)
            self.inverse = try filters_mod.Decoder.init(self.staging_budget.allocator(), self.inverse_chain[0..self.header.filter_count]);
        var read: usize = 0;
        var written: usize = 0;
        while (true) {
            if (self.staged_offset != self.staged.items.len) {
                const n = @min(output.len - written, self.staged.items.len - self.staged_offset);
                const bytes = self.staged.items[self.staged_offset..][0..n];
                @memcpy(output[written..][0..n], bytes);
                self.check_state.update(self.check, bytes);
                self.staged_offset += n;
                self.output_written += n;
                written += n;
                if (self.staged_offset != self.staged.items.len) return result(read, written, .need_output);
                self.staged.clearRetainingCapacity();
                self.staged_offset = 0;
            }
            if (self.filtered_finished) {
                if (self.output_written != self.raw.snapshot().decoded_total) return error.SizeMismatch;
                return result(read, written, .done);
            }
            if (self.raw_finished) {
                if (self.inverse) |*inverse| {
                    try inverse.push("", true, &self.staged);
                    if (self.staged.items.len > self.staging_limit) return error.OutputLimitExceeded;
                }
                self.filtered_finished = true;
                continue;
            }
            const packed_limit = @min(self.body_limit, if (self.header.packed_size) |size| std.math.cast(usize, size) orelse self.body_limit else self.body_limit);
            if (self.input_read >= packed_limit) return if (self.header.packed_size != null and self.header.packed_size.? <= self.body_limit) error.SizeMismatch else error.OutputLimitExceeded;
            const source = input[read..][0..@min(input.len - read, packed_limit - self.input_read)];
            const target = if (self.inverse != null) self.temporary[0..@min(@as(usize, 256), self.staging_limit -| self.tail_bound)] else output[written..];
            const decoded = self.raw.step(source, target) catch |original| {
                const progress = self.raw.snapshot().last_step_progress;
                self.input_read += progress.input_read;
                if (self.inverse == null) {
                    self.output_written += progress.output_written;
                    self.check_state.update(self.check, target[0..progress.output_written]);
                }
                return if (original == error.OutputLimitExceeded and self.limit_from_pledge) error.SizeMismatch else original;
            };
            self.input_read += decoded.progress.input_read;
            read += decoded.progress.input_read;
            const bytes = target[0..decoded.progress.output_written];
            if (self.inverse) |*inverse| {
                if (bytes.len != 0) {
                    try self.reserveStage();
                    try inverse.push(bytes, false, &self.staged);
                    if (self.staged.items.len > self.staging_limit) return error.OutputLimitExceeded;
                }
            } else {
                self.check_state.update(self.check, bytes);
                self.output_written += bytes.len;
                written += bytes.len;
            }
            if (decoded.status == .done) {
                if (self.header.packed_size) |declared|
                    if (self.input_read != declared) return error.SizeMismatch;
                const padding = (4 - ((self.header.header_size % 4 + self.input_read % 4) % 4)) % 4;
                const padded = std.math.add(usize, self.input_read, padding) catch return error.IntegerOverflow;
                const total = std.math.add(usize, padded, try checks.size(self.check)) catch return error.IntegerOverflow;
                if (total > self.body_limit) return error.OutputLimitExceeded;
                self.raw_finished = true;
                continue;
            }
            if (decoded.status == .need_input and self.staged.items.len == 0) {
                if (self.input_read >= packed_limit) return if (self.header.packed_size != null and self.header.packed_size.? <= self.body_limit) error.SizeMismatch else error.OutputLimitExceeded;
                if (read != input.len) continue;
                return result(read, written, .need_input);
            }
            if (decoded.status == .need_output and bytes.len == 0) {
                if (self.inverse != null and target.len == 0) return error.OutputLimitExceeded;
                return result(read, written, .need_output);
            }
        }
    }

    fn reserveStage(self: *Decoder) Error!void {
        // Already emitted raw bytes comprise the new push and any filter tail.
        // This bounds the next plaintext append using actual progress.
        const needed = self.raw.snapshot().output_written - self.output_written;
        if (needed > self.staging_limit) return error.OutputLimitExceeded;
        try self.staged.ensureTotalCapacityPrecise(self.staging_budget.allocator(), needed);
    }

    fn result(read: usize, written: usize, status: core.StepResult.Status) core.StepResult {
        return .{ .progress = .{ .input_read = read, .output_written = written }, .status = status };
    }
};
