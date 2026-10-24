const archive = @import("arj/archive.zig");
const method4 = @import("arj/method4.zig");
const writer = @import("arj/writer.zig");
const volume_set = @import("arj/volume_set.zig");

pub const Error = archive.Error || writer.Error || volume_set.Error;
pub const Method = archive.Method;
pub const Encryption = archive.Encryption;
pub const DecodeOptions = archive.DecodeOptions;
pub const Name = archive.Name;
pub const Entry = archive.Entry;
pub const Archive = archive.Archive;
pub const Iterator = archive.Iterator;
pub const EncodeEntry = writer.EncodeEntry;
pub const EntryKind = writer.EntryKind;
pub const EncodeEncryptionOptions = writer.EncryptionOptions;
pub const EncodedVolumes = writer.EncodedVolumes;
pub const VolumeSet = volume_set.VolumeSet;
pub const VolumeEntry = volume_set.Entry;
pub const VolumeIterator = volume_set.Iterator;
pub const parse = archive.parse;
pub const encodeAlloc = writer.encodeAlloc;
pub const encodeAppend = writer.encodeAppend;
pub const encodeInto = writer.encodeInto;
pub const encodeVolumesAlloc = writer.encodeVolumesAlloc;
pub const parseVolumeSetAlloc = volume_set.VolumeSet.parseAlloc;

pub const decodeMethod4Into = method4.decodeInto;
pub const decodeMethod4Alloc = method4.decodeAlloc;
pub const decodeMethod4AllocLimited = method4.decodeAllocLimited;
pub const encodeMethod4Alloc = method4.encodeAlloc;
pub const encodeMethod4Append = method4.encodeAppend;
pub const encodeMethod4Into = method4.encodeInto;

test {
    _ = archive;
    _ = method4;
    _ = writer;
    _ = volume_set;
    _ = @import("arj/encryption_tests.zig");
    _ = @import("arj/volume_tests.zig");
}
