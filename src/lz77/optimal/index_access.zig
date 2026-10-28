//! Shared absolute-coordinate access to full and bounded optimal indexes.
const std = @import("std");

pub fn isWindow(comptime T: type) bool {
    return @typeInfo(T) == .@"struct";
}

pub fn Value(comptime T: type) type {
    if (comptime isWindow(T)) return u32;
    const pointer = @typeInfo(T).pointer;
    return if (pointer.size == .slice) pointer.child else @typeInfo(pointer.child).array.child;
}

pub inline fn at(index: anytype, position: usize) Value(@TypeOf(index)) {
    return if (comptime isWindow(@TypeOf(index))) index.get(position) else index[position];
}

pub inline fn sample(index: anytype, position: usize) Value(@TypeOf(index)) {
    return if (comptime isWindow(@TypeOf(index))) index.sample(position) else index[position];
}

pub inline fn prepare(index: anytype, position: usize) void {
    if (comptime isWindow(@TypeOf(index))) index.prepare(position);
}
