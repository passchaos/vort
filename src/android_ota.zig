const format = @import("android_ota/format.zig");
const protobuf = @import("android_ota/protobuf.zig");
const manifest = @import("android_ota/manifest.zig");
const archive = @import("android_ota/archive.zig");
const decoder = @import("android_ota/decoder.zig");
const bsdiff = @import("android_ota/bsdiff.zig");
const puffin_codec = @import("android_ota/puffin_codec.zig");
const puffin = @import("android_ota/puffin.zig");
const writer = @import("android_ota/writer.zig");

pub const Error = format.Error || protobuf.Error || manifest.Error ||
    archive.Error || writer.Error;
pub const OperationType = format.OperationType;
pub const Header = format.Header;
pub const Manifest = format.Manifest;
pub const PartitionInfo = format.PartitionInfo;
pub const Extent = format.Extent;
pub const Operation = format.Operation;
pub const Partition = format.Partition;
pub const Archive = archive.Archive;
pub const OpenOptions = archive.OpenOptions;
pub const DecodeOptions = archive.DecodeOptions;
pub const BsdiffApplyOptions = bsdiff.ApplyOptions;
pub const PuffinApplyOptions = puffin.ApplyOptions;
pub const PuffResult = puffin_codec.PuffResult;
pub const Compression = writer.Compression;
pub const EncodePartition = writer.EncodePartition;
pub const EncodeOptions = writer.EncodeOptions;
pub const parseAlloc = archive.Archive.initAlloc;
pub const encodeAlloc = writer.encodeAlloc;
pub const applyBsdiffAlloc = bsdiff.applyAlloc;
pub const applyPuffinAlloc = puffin.applyAlloc;
pub const puffinDecodedSizeAlloc = puffin.decodedSizeAlloc;
pub const puffDeflateAlloc = puffin_codec.puffDeflateAlloc;
pub const puffDeflatePaddedAlloc = puffin_codec.puffDeflatePaddedAlloc;
pub const huffDeflateAlloc = puffin_codec.huffDeflateAlloc;

test {
    _ = format;
    _ = protobuf;
    _ = manifest;
    _ = archive;
    _ = decoder;
    _ = bsdiff;
    _ = puffin_codec;
    _ = puffin;
    _ = writer;
    _ = @import("android_ota/test.zig");
}
