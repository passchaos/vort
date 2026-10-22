const writer_codec = @import("codec.zig");
const writer_inode = @import("inode.zig");
const Xattr = @import("tree.zig").Xattr;

pub const Compression = writer_codec.Compression;
pub const TailPacking = enum { none, fragments, compressed_inline };
pub const InodeVersion = writer_inode.Version;

pub const Options = struct {
    compression: Compression = .stored,
    /// Maximum decoded bytes per compressed extent (4 KiB...1 MiB).
    compression_extent_size: usize = 4096,
    volume_name: []const u8 = "vort",
    epoch: u64 = 0,
    fixed_nsec: u32 = 0,
    build_time: u32 = 0,
    root_xattrs: []const Xattr = &.{},
    root_mode: u16 = 0o755,
    root_uid: u32 = 0,
    root_gid: u32 = 0,
    /// Seconds relative to epoch.
    root_modification_time: u64 = 0,
    root_modification_nsec: ?u32 = null,
    xattr_prefixes: []const []const u8 = &.{},
    tail_packing: TailPacking = .none,
    chunk_size: ?usize = null,
    force_48bit: bool = false,
    /// Store visible inode metadata in a standard MZi metabox inode.
    metabox: bool = false,
    /// Deduplicate repeated name/value pairs into the shared-xattr region.
    shared_xattrs: bool = false,
    /// Store nontrivial directory streams as whole fragments in the packed inode.
    compress_directories: bool = false,
    inode_version: InodeVersion = .compact,
};
