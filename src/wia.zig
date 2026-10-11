const format = @import("wia/format.zig");
const archive = @import("wia/archive.zig");
const writer = @import("wia/writer.zig");
const wii_disc = @import("wia/wii_disc.zig");

pub const Error = format.Error || archive.Error || writer.Error || wii_disc.Error;
pub const Container = format.Container;
pub const Compression = format.Compression;
pub const Header1 = format.Header1;
pub const Header2 = format.Header2;
pub const PartitionDataEntry = format.PartitionDataEntry;
pub const PartitionEntry = format.PartitionEntry;
pub const RawEntry = format.RawEntry;
pub const GroupEntry = format.GroupEntry;
pub const Archive = archive.Archive;
pub const OpenOptions = archive.OpenOptions;
pub const EncodeOptions = writer.EncodeOptions;
pub const EncodePartitionData = writer.PartitionData;
pub const EncodePartition = writer.Partition;
pub const WiiCommonKey = wii_disc.CommonKey;
pub const WiiDiscPartition = wii_disc.Partition;
pub const WiiDiscLayout = wii_disc.Layout;
pub const WiiDiscDiscoverOptions = wii_disc.DiscoverOptions;
pub const parseHeader1 = format.parseHeader1;
pub const parseAlloc = archive.Archive.initAlloc;
pub const discoverWiiDiscAlloc = wii_disc.discoverAlloc;
pub const encodeAlloc = writer.encodeAlloc;
pub const encodeWithPartitionsAlloc = writer.encodeWithPartitionsAlloc;
pub const encodeDiscAlloc = writer.encodeDiscAlloc;

test {
    _ = format;
    _ = @import("wia/codec.zig");
    _ = @import("wia/group_writer.zig");
    _ = @import("wia/partition_writer.zig");
    _ = @import("wia/rvz_pack.zig");
    _ = wii_disc;
    _ = @import("wia/wii_partition.zig");
    _ = archive;
    _ = writer;
    _ = @import("wia/test.zig");
}
