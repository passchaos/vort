//! One-shot prefix lifetime around reusable encoding candidates/publication.
const binding = @import("binding.zig");

pub fn begin(slot: anytype, usage: binding.Usage, explicit: @TypeOf(slot.dictionary)) error{InvalidStreamState}!@TypeOf(slot.dictionary) {
    if (slot.state.busy) return error.InvalidStreamState;
    if (usage == .prefix) {
        if (explicit orelse slot.dictionary) |dictionary| slot.setPrefix(dictionary) else slot.clear();
    } else if (explicit != null and slot.state.phase == .pending) {
        slot.clear();
    }
    const selected = if (explicit != null) explicit else slot.dictionary;
    _ = slot.state.activate(.call);
    slot.state.busy = true;
    return selected;
}

pub fn setPrefix(slot: anytype, dictionary: anytype) error{InvalidStreamState}!void {
    if (slot.state.busy) return error.InvalidStreamState;
    slot.setPrefix(dictionary);
}

pub fn setDictionary(slot: anytype, dictionary: anytype) error{InvalidStreamState}!void {
    if (slot.state.busy) return error.InvalidStreamState;
    slot.setDictionary(dictionary);
}

pub fn clear(slot: anytype) error{InvalidStreamState}!void {
    if (slot.state.busy) return error.InvalidStreamState;
    slot.clear();
}
