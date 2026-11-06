//! A literal probability policy, independent of dictionary and distance
//! contexts. Canonical options also keep prepared caches and profiles honest.

pub fn disabled(options: anytype) bool {
    const T = @TypeOf(options);
    var result = if (@hasField(T, "disable_literal_context_modeling")) options.disable_literal_context_modeling else false;
    if (@hasField(T, "hq")) {
        if (options.hq) |hq| {
            if (@hasField(@TypeOf(hq), "disable_literal_context_modeling"))
                result = result or hq.disable_literal_context_modeling;
        }
    }
    return result;
}

/// Public/nested HQ controls are monotonic: either caller may disable the
/// literal context model. No parser or dictionary context mode is changed.
pub fn planned(options: anytype) @TypeOf(options) {
    if (!disabled(options)) return options;
    var result = options;
    if (@hasField(@TypeOf(result), "disable_literal_context_modeling"))
        result.disable_literal_context_modeling = true;
    if (@hasField(@TypeOf(result), "hq")) {
        if (result.hq) |*hq| {
            if (@hasField(@TypeOf(hq.*), "disable_literal_context_modeling"))
                hq.disable_literal_context_modeling = true;
        }
    }
    return result;
}

pub fn allowed(options: anytype, requested: bool) bool {
    return requested and !disabled(options);
}

pub fn lazy(options: anytype) @TypeOf(options) {
    if (!disabled(options)) return options;
    var result = options;
    if (@hasField(@TypeOf(result), "try_literal_contexts")) result.try_literal_contexts = false;
    if (@hasField(@TypeOf(result), "try_clustered_literal_contexts")) result.try_clustered_literal_contexts = false;
    if (@hasField(@TypeOf(result), "try_joint_literal_contexts")) result.try_joint_literal_contexts = false;
    return result;
}

/// Project a joint block/context proposal onto its temporal literal blocks.
/// Each block type then receives its ordinary context-independent tree; the
/// distance maps, literal mode and static dictionary choices remain intact.
pub fn command(options: anytype) @TypeOf(options) {
    if (!disabled(options)) return options;
    var result = options;
    if (@hasField(@TypeOf(result), "literal_context_candidate")) result.literal_context_candidate = null;
    if (@hasField(@TypeOf(result), "use_utf8_text_contexts")) result.use_utf8_text_contexts = false;
    if (@hasField(@TypeOf(result), "literal_entropy_plan")) {
        if (result.literal_entropy_plan) |joint| {
            if (comptime canProjectBlockPlan(@TypeOf(result))) {
                result.adaptive_literal_split = &joint.block_plan;
                if (@hasField(@TypeOf(result), "literal_split")) result.literal_split = null;
            }
            result.literal_entropy_plan = null;
        }
    }
    return result;
}

/// Some generic capture/profile callers use scalar option markers. Only a
/// compatible optional pointer can borrow the joint plan's temporal blocks.
fn canProjectBlockPlan(comptime Options: type) bool {
    if (!@hasField(Options, "adaptive_literal_split")) return false;
    const source_info = @typeInfo(@FieldType(Options, "literal_entropy_plan"));
    if (source_info != .optional) return false;
    const pointer_info = @typeInfo(source_info.optional.child);
    if (pointer_info != .pointer or pointer_info.pointer.size != .one) return false;
    const Joint = pointer_info.pointer.child;
    const joint_info = @typeInfo(Joint);
    if (joint_info != .@"struct" and joint_info != .@"union") return false;
    if (!@hasField(Joint, "block_plan")) return false;
    const Block = @FieldType(Joint, "block_plan");
    // Restrict this borrow to ordinary naturally aligned fields. Synthetic
    // markers, packed fields and qualified address spaces are not this model.
    if (joint_info == .@"struct" and joint_info.@"struct".layout == .@"packed") return false;
    if (joint_info == .@"union" and joint_info.@"union".layout == .@"packed") return false;
    const source_alignment = pointer_info.pointer.alignment orelse @alignOf(Joint);
    if (source_alignment < @alignOf(Block) or
        pointer_info.pointer.is_allowzero or pointer_info.pointer.is_volatile or
        pointer_info.pointer.address_space != .generic)
        return false;
    const Destination = @FieldType(Options, "adaptive_literal_split");
    return Destination == ?*const Block or
        (!pointer_info.pointer.is_const and Destination == ?*Block);
}

pub fn contextFlags(flags: anytype, disable: bool) @TypeOf(flags) {
    if (!disable) return flags;
    var result = flags;
    result.literal_contexts = false;
    result.cluster_contexts = false;
    result.joint_block_contexts = false;
    return result;
}

test {
    _ = @import("literal_context_policy_tests.zig");
}
