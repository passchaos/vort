const std = @import("std");
const vort = @import("vort");
const ar_cli = @import("cli/ar.zig");
const bgzf_cli = @import("cli/bgzf.zig");
const arj_cli = @import("cli/arj.zig");
const arc_cli = @import("cli/arc.zig");
const cpio_cli = @import("cli/cpio.zig");
const deb_cli = @import("cli/deb.zig");
const rar_cli = @import("cli/rar.zig");
const rpm_cli = @import("cli/rpm.zig");
const zoo_cli = @import("cli/zoo.zig");
const compress_z_cli = @import("cli/compress_z.zig");
const filters_cli = @import("cli/filters.zig");
const hadoop_lzo_cli = @import("cli/hadoop_lzo.zig");
const lz4_legacy_cli = @import("cli/lz4_legacy.zig");
const lznt1_cli = @import("cli/lznt1.zig");
const xpress_cli = @import("cli/xpress.zig");
const lzms_cli = @import("cli/lzms.zig");
const wof_cli = @import("cli/wof.zig");
const lzfse_cli = @import("cli/lzfse.zig");
const decmpfs_cli = @import("cli/decmpfs.zig");
const dmg_cli = @import("cli/dmg.zig");
const pbzx_cli = @import("cli/pbzx.zig");
const xar_cli = @import("cli/xar.zig");
const zfs_cli = @import("cli/zfs.zig");
const qcow2_cli = @import("cli/qcow2.zig");
const vmdk_cli = @import("cli/vmdk.zig");
const ewf_cli = @import("cli/ewf.zig");
const chd_cli = @import("cli/chd.zig");
const vhd_cli = @import("cli/vhd.zig");
const vhdx_cli = @import("cli/vhdx.zig");
const cso_cli = @import("cli/cso.zig");
const dax_cli = @import("cli/dax.zig");
const gcz_cli = @import("cli/gcz.zig");
const wia_cli = @import("cli/wia.zig");
const wbfs_cli = @import("cli/wbfs.zig");
const wdf_cli = @import("cli/wdf.zig");
const wux_cli = @import("cli/wux.zig");
const android_sparse_cli = @import("cli/android_sparse.zig");
const android_ota_cli = @import("cli/android_ota.zig");
const zchunk_cli = @import("cli/zchunk.zig");
const squashfs_cli = @import("cli/squashfs.zig");
const erofs_cli = @import("cli/erofs.zig");
const wim_cli = @import("cli/wim.zig");
const zip_cli = @import("cli/zip.zig");
const lzip_cli = @import("cli/lzip.zig");
const lzf_cli = @import("cli/lzf.zig");
const lha_cli = @import("cli/lha.zig");
const lzop_cli = @import("cli/lzop.zig");
const seven_zip_cli = @import("cli/seven_zip.zig");
const snappy_framing_cli = @import("cli/snappy_framing.zig");

pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [2048]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    const command = args.next() orelse {
        try printHelp(stdout);
        try stdout.flush();
        return;
    };

    if (std.mem.eql(u8, command, "--help") or std.mem.eql(u8, command, "help")) {
        try printHelp(stdout);
    } else if (std.mem.eql(u8, command, "checksum")) {
        const payload = args.next() orelse "";
        try stdout.print("input_bytes={d} adler32={d} crc32={d} crc32c={d}\n", .{
            payload.len,
            vort.adler32(payload),
            vort.crc32(payload),
            vort.crc32c(payload),
        });
    } else if (std.mem.eql(u8, command, "checksum-file")) {
        const path = args.next() orelse return error.MissingCorpusPath;
        const payload = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(payload);
        try stdout.print("input_bytes={d} adler32={d} crc32={d} crc32c={d}\n", .{
            payload.len,
            vort.adler32(payload),
            vort.crc32(payload),
            vort.crc32c(payload),
        });
    } else if (std.mem.eql(u8, command, "store-roundtrip")) {
        const payload = args.next() orelse "";
        const encoded = try vort.storeEncodeAlloc(init.gpa, payload);
        defer init.gpa.free(encoded);
        const decoded = try vort.storeDecodeAlloc(init.gpa, encoded);
        defer init.gpa.free(decoded);
        try stdout.print("input_bytes={d} encoded_bytes={d} decoded_ok={} crc32={d}\n", .{
            payload.len,
            encoded.len,
            std.mem.eql(u8, payload, decoded),
            vort.crc32(decoded),
        });
    } else if (std.mem.eql(u8, command, "zlib-store-roundtrip")) {
        const payload = args.next() orelse "";
        const encoded = try vort.encodeZlibStoredAlloc(init.gpa, payload);
        defer init.gpa.free(encoded);
        const decoded = try vort.decodeZlibStoredAlloc(init.gpa, encoded);
        defer init.gpa.free(decoded);
        try stdout.print("input_bytes={d} zlib_bytes={d} decoded_ok={} adler32={d}\n", .{
            payload.len,
            encoded.len,
            std.mem.eql(u8, payload, decoded),
            vort.adler32(decoded),
        });
    } else if (std.mem.eql(u8, command, "gzip-store-roundtrip")) {
        const payload = args.next() orelse "";
        const encoded = try vort.encodeGzipStoredAlloc(init.gpa, payload);
        defer init.gpa.free(encoded);
        const decoded = try vort.decodeGzipStoredAlloc(init.gpa, encoded);
        defer init.gpa.free(decoded);
        try stdout.print("input_bytes={d} gzip_bytes={d} decoded_ok={} crc32={d}\n", .{
            payload.len,
            encoded.len,
            std.mem.eql(u8, payload, decoded),
            vort.crc32(decoded),
        });
    } else if (std.mem.eql(u8, command, "encode-xerial-snappy-file")) {
        try snappy_framing_cli.encodeXerial(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-xerial-snappy-incremental-file")) {
        try snappy_framing_cli.encodeXerialIncremental(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-xerial-snappy-file")) {
        try snappy_framing_cli.decodeXerial(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-xerial-snappy-incremental-file")) {
        try snappy_framing_cli.decodeXerialIncremental(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-xerial-snappy-file")) {
        try snappy_framing_cli.inspectXerial(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-hadoop-snappy-file")) {
        try snappy_framing_cli.encodeHadoop(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-hadoop-snappy-incremental-file")) {
        try snappy_framing_cli.encodeHadoopIncremental(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-hadoop-snappy-file")) {
        try snappy_framing_cli.decodeHadoop(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-hadoop-snappy-incremental-file")) {
        try snappy_framing_cli.decodeHadoopIncremental(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-hadoop-snappy-file")) {
        try snappy_framing_cli.inspectHadoop(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-hadoop-lz4-file")) {
        try snappy_framing_cli.encodeHadoopLz4(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-hadoop-lz4-incremental-file")) {
        try snappy_framing_cli.encodeHadoopLz4Incremental(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-hadoop-lz4-file")) {
        try snappy_framing_cli.decodeHadoopLz4(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-hadoop-lz4-incremental-file")) {
        try snappy_framing_cli.decodeHadoopLz4Incremental(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-hadoop-lz4-file")) {
        try snappy_framing_cli.inspectHadoopLz4(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "create-hadoop-lzo-index")) {
        try hadoop_lzo_cli.createIndex(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-hadoop-lzo-index")) {
        try hadoop_lzo_cli.inspectIndex(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-hadoop-lzo-blocks")) {
        try hadoop_lzo_cli.extractBlocks(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-lz4-legacy-file")) {
        try lz4_legacy_cli.encode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-lz4-legacy-file")) {
        try lz4_legacy_cli.decode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-lz4-legacy-file")) {
        try lz4_legacy_cli.inspect(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-lznt1-file")) {
        try lznt1_cli.encode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-lznt1-file")) {
        try lznt1_cli.decode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-lznt1-file")) {
        try lznt1_cli.inspect(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-xpress-plain-file")) {
        try xpress_cli.encodePlain(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-xpress-plain-file")) {
        try xpress_cli.decodePlain(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-xpress-plain-file")) {
        try xpress_cli.inspectPlain(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-xpress-huffman-file")) {
        try xpress_cli.encodeHuffman(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-xpress-huffman-file")) {
        try xpress_cli.decodeHuffman(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-xpress-huffman-file")) {
        try xpress_cli.inspectHuffman(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-lzms-file")) {
        try lzms_cli.encode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-lzms-file")) {
        try lzms_cli.decode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-wof-file")) {
        try wof_cli.encode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-wof-file")) {
        try wof_cli.decode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-wof-range")) {
        try wof_cli.decodeRange(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-wof-file")) {
        try wof_cli.inspect(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-lzfse-file")) {
        try lzfse_cli.encode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-lzfse-file")) {
        try lzfse_cli.decode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-lzfse-file")) {
        try lzfse_cli.inspect(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-decmpfs")) {
        try decmpfs_cli.inspect(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-decmpfs")) {
        try decmpfs_cli.decode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-decmpfs-range")) {
        try decmpfs_cli.decodeRange(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-dmg")) {
        try dmg_cli.inspect(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-dmg-partition")) {
        try dmg_cli.decode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-dmg-range")) {
        try dmg_cli.decodeRange(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-dmg")) {
        try dmg_cli.encode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-pbzx")) {
        try pbzx_cli.inspect(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-pbzx")) {
        try pbzx_cli.decode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-pbzx-range")) {
        try pbzx_cli.decodeRange(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-pbzx")) {
        try pbzx_cli.encode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-xar")) {
        try xar_cli.inspect(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-xar-entry")) {
        try xar_cli.extract(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-xar-file")) {
        try xar_cli.encodeFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-zfs-block")) {
        try zfs_cli.inspect(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-zfs-block")) {
        try zfs_cli.decode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-zfs-block")) {
        try zfs_cli.encode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-qcow2")) {
        try qcow2_cli.inspect(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-qcow2")) {
        try qcow2_cli.decode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-qcow2-range")) {
        try qcow2_cli.decodeRange(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-qcow2")) {
        try qcow2_cli.encode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-vmdk")) {
        try vmdk_cli.inspect(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-vmdk")) {
        try vmdk_cli.decode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-vmdk-range")) {
        try vmdk_cli.decodeRange(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-vmdk")) {
        try vmdk_cli.encode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-ewf")) {
        try ewf_cli.inspect(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-ewf")) {
        try ewf_cli.decode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-ewf-range")) {
        try ewf_cli.decodeRange(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-ewf")) {
        try ewf_cli.encode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-chd")) {
        try chd_cli.inspect(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-chd")) {
        try chd_cli.decode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-chd-range")) {
        try chd_cli.decodeRange(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-chd")) {
        try chd_cli.encode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-vhd")) {
        try vhd_cli.inspect(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-vhd")) {
        try vhd_cli.decode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-vhd-range")) {
        try vhd_cli.decodeRange(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-vhd")) {
        try vhd_cli.encode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-vhdx")) {
        try vhdx_cli.inspect(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-vhdx")) {
        try vhdx_cli.decode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-vhdx-range")) {
        try vhdx_cli.decodeRange(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-vhdx")) {
        try vhdx_cli.encode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-cso")) {
        try cso_cli.inspect(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-cso")) {
        try cso_cli.decode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-cso-range")) {
        try cso_cli.decodeRange(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-cso")) {
        try cso_cli.encode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-dax")) {
        try dax_cli.inspect(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-dax")) {
        try dax_cli.decode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-dax-range")) {
        try dax_cli.decodeRange(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-dax")) {
        try dax_cli.encode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-gcz")) {
        try gcz_cli.inspect(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-gcz")) {
        try gcz_cli.decode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-gcz-range")) {
        try gcz_cli.decodeRange(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-gcz")) {
        try gcz_cli.encode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-wia") or
        std.mem.eql(u8, command, "inspect-rvz"))
    {
        try wia_cli.inspect(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-wia") or
        std.mem.eql(u8, command, "decode-rvz"))
    {
        try wia_cli.decode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-wia-range") or
        std.mem.eql(u8, command, "decode-rvz-range"))
    {
        try wia_cli.decodeRange(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-wia")) {
        try wia_cli.encodeWia(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-rvz")) {
        try wia_cli.encodeRvz(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-wia-partition")) {
        try wia_cli.encodeWiaPartition(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-rvz-partition")) {
        try wia_cli.encodeRvzPartition(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-wia-disc")) {
        try wia_cli.encodeWiaDisc(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-rvz-disc")) {
        try wia_cli.encodeRvzDisc(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-wbfs")) {
        try wbfs_cli.inspect(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-wbfs")) {
        try wbfs_cli.decode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-wbfs-range")) {
        try wbfs_cli.decodeRange(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-wbfs")) {
        try wbfs_cli.encode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-wdf")) {
        try wdf_cli.inspect(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-wdf")) {
        try wdf_cli.decode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-wdf-range")) {
        try wdf_cli.decodeRange(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-wdf")) {
        try wdf_cli.encode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-wux")) {
        try wux_cli.inspect(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-wux")) {
        try wux_cli.decode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-wux-range")) {
        try wux_cli.decodeRange(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-wux")) {
        try wux_cli.encode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-android-sparse")) {
        try android_sparse_cli.inspect(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-android-sparse")) {
        try android_sparse_cli.decode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-android-sparse-range")) {
        try android_sparse_cli.decodeRange(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-android-sparse")) {
        try android_sparse_cli.encode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-android-ota")) {
        try android_ota_cli.inspect(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-android-ota")) {
        try android_ota_cli.extract(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-android-ota-range")) {
        try android_ota_cli.extractRange(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-android-ota")) {
        try android_ota_cli.encode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "puff-android-deflate")) {
        try android_ota_cli.puffDeflate(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "huff-android-deflate")) {
        try android_ota_cli.huffDeflate(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-zchunk-file")) {
        try zchunk_cli.encode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-zchunk-file")) {
        try zchunk_cli.decode(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-zchunk-file")) {
        try zchunk_cli.inspect(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-zchunk-chunk")) {
        try zchunk_cli.extractChunk(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "list-squashfs-file")) {
        try squashfs_cli.list(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "create-squashfs-file")) {
        try squashfs_cli.create(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-squashfs-file")) {
        try squashfs_cli.extract(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "list-erofs-file")) {
        try erofs_cli.list(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "create-erofs-file")) {
        try erofs_cli.create(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-erofs-file")) {
        try erofs_cli.extract(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "list-wim-file")) {
        try wim_cli.list(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-wim-resource")) {
        try wim_cli.extractResource(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-wim-xml")) {
        try wim_cli.extractXml(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "list-wim-image")) {
        try wim_cli.listImage(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-wim-path")) {
        try wim_cli.extractPath(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-wim-stream")) {
        try wim_cli.extractNamedStream(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-wim-reparse")) {
        try wim_cli.extractReparseData(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-wim-encrypted-raw")) {
        try wim_cli.extractEncryptedRawData(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-wim-pipable-stream-path")) {
        try wim_cli.extractPipablePathIncremental(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-wim-encrypted-esd")) {
        try wim_cli.inspectEncryptedEsd(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decrypt-wim-encrypted-esd")) {
        try wim_cli.decryptEncryptedEsd(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decrypt-wim-encrypted-esd-key")) {
        try wim_cli.decryptEncryptedEsdWithKey(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "list-wim-parts-image")) {
        try wim_cli.listSetImage(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-wim-parts-path")) {
        try wim_cli.extractSetPath(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-bgzf-file")) {
        try bgzf_cli.encodeFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-bgzf-file")) {
        try bgzf_cli.decodeFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-bgzf-file")) {
        try bgzf_cli.inspectFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-bgzf-range")) {
        try bgzf_cli.decodeRange(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "zlib-fixed-roundtrip")) {
        const payload = args.next() orelse "";
        const encoded = try vort.encodeZlibFixedAlloc(init.gpa, payload);
        defer init.gpa.free(encoded);
        const decoded = try vort.decodeZlibAlloc(init.gpa, encoded);
        defer init.gpa.free(decoded);
        try stdout.print("input_bytes={d} zlib_fixed_bytes={d} decoded_ok={} adler32={d}\n", .{
            payload.len,
            encoded.len,
            std.mem.eql(u8, payload, decoded),
            vort.adler32(decoded),
        });
    } else if (std.mem.eql(u8, command, "gzip-fixed-roundtrip")) {
        const payload = args.next() orelse "";
        const encoded = try vort.encodeGzipFixedAlloc(init.gpa, payload);
        defer init.gpa.free(encoded);
        const decoded = try vort.decodeGzipAlloc(init.gpa, encoded);
        defer init.gpa.free(decoded);
        try stdout.print("input_bytes={d} gzip_fixed_bytes={d} decoded_ok={} crc32={d}\n", .{
            payload.len,
            encoded.len,
            std.mem.eql(u8, payload, decoded),
            vort.crc32(decoded),
        });
    } else if (std.mem.eql(u8, command, "encode-br-stored-hex")) {
        const payload = args.next() orelse "";
        const options = try parseBrotliStoredOptions(args.next(), args.next());
        const encoded = try vort.brEncodeStoredStreamWithOptionsAlloc(init.gpa, payload, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "decode-br-hex")) {
        const hex = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.brDecodeStreamAllocLimited(init.gpa, compressed, limit)
        else
            try vort.brDecodeStreamAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try printDecoded(stdout, "br", compressed.len, decoded);
    } else if (std.mem.eql(u8, command, "encode-br-stored-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const options = try parseBrotliStoredOptions(args.next(), args.next());
        const payload = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(payload);
        const encoded = try vort.brEncodeStoredStreamWithOptionsAlloc(init.gpa, payload, options);
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        try stdout.print("br_compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ encoded.len, payload.len, output_path });
    } else if (std.mem.eql(u8, command, "decode-br-file-to")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.brDecodeStreamAllocLimited(init.gpa, compressed, limit)
        else
            try vort.brDecodeStreamAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
        try stdout.print("br_compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ compressed.len, decoded.len, output_path });
    } else if (std.mem.eql(u8, command, "encode-bzip2-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const block_size_100k: u4 = if (args.next()) |value| try std.fmt.parseInt(u4, value, 10) else 9;
        const input = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(512 * 1024 * 1024));
        defer init.gpa.free(input);
        const encoded = try vort.encodeBzip2Alloc(init.gpa, input, .{ .block_size_100k = block_size_100k });
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        try stdout.print("bzip2_input_bytes={d} compressed_bytes={d} path={s}\n", .{ input.len, encoded.len, output_path });
    } else if (std.mem.eql(u8, command, "decode-bzip2-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(512 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.decodeBzip2AllocLimited(init.gpa, compressed, limit)
        else
            try vort.decodeBzip2Alloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
        try stdout.print("bzip2_compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ compressed.len, decoded.len, output_path });
    } else if (std.mem.eql(u8, command, "decode-bzip2-concat-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(512 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.decodeBzip2ConcatenatedAllocLimited(init.gpa, compressed, limit)
        else
            try vort.decodeBzip2ConcatenatedAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
        try stdout.print("bzip2_stream_bytes={d} decoded_bytes={d} path={s}\n", .{ compressed.len, decoded.len, output_path });
    } else if (std.mem.eql(u8, command, "size-bzip2-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(512 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const decoded_len = if (max_output_len) |limit|
            try vort.bzip2DecodedSizeLimited(init.gpa, compressed, limit)
        else
            try vort.bzip2DecodedSize(init.gpa, compressed);
        try stdout.print("bzip2_compressed_bytes={d} decoded_bytes={d}\n", .{ compressed.len, decoded_len });
    } else if (std.mem.eql(u8, command, "encode-compress-z-file")) {
        try compress_z_cli.encodeFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-compress-z-file")) {
        try compress_z_cli.decodeFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "size-compress-z-file")) {
        try compress_z_cli.sizeFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-lzip-file")) {
        try lzip_cli.encodeFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-lzip-file")) {
        try lzip_cli.decodeFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "size-lzip-file")) {
        try lzip_cli.sizeFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-lzip-file")) {
        try lzip_cli.inspectFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-lzf-file")) {
        try lzf_cli.encodeFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-lzf-file")) {
        try lzf_cli.decodeFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "size-lzf-file")) {
        try lzf_cli.sizeFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-lzf-file")) {
        try lzf_cli.inspectFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "create-lha-file")) {
        try lha_cli.createFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "list-lha-file")) {
        try lha_cli.listFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-lha-file")) {
        try lha_cli.extractFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "create-ar-file")) {
        try ar_cli.createFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "list-ar-file")) {
        try ar_cli.listFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-ar-file")) {
        try ar_cli.extractFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "create-deb-file")) {
        try deb_cli.createFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "list-deb-file")) {
        try deb_cli.listFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-deb-file")) {
        try deb_cli.extractFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "create-rpm-file")) {
        try rpm_cli.createFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "list-rpm-file")) {
        try rpm_cli.listFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-rpm-file")) {
        try rpm_cli.extractFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-rpm-payload")) {
        try rpm_cli.extractPayload(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "create-arj-file")) {
        try arj_cli.createFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "list-arj-file")) {
        try arj_cli.listFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-arj-file")) {
        try arj_cli.extractFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "create-arc-file")) {
        try arc_cli.createFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "list-arc-file")) {
        try arc_cli.listFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-arc-file")) {
        try arc_cli.extractFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "create-zoo-file")) {
        try zoo_cli.createFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "list-zoo-file")) {
        try zoo_cli.listFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-zoo-file")) {
        try zoo_cli.extractFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "create-cpio-file")) {
        try cpio_cli.createFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "list-cpio-file")) {
        try cpio_cli.listFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-cpio-file")) {
        try cpio_cli.extractFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "create-rar-file")) {
        try rar_cli.createFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "create-rar-volumes")) {
        try rar_cli.createVolumes(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "list-rar-file")) {
        try rar_cli.listFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-rar-file")) {
        try rar_cli.extractFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-rar-volumes")) {
        try rar_cli.extractVolumes(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-lzop-file")) {
        try lzop_cli.encodeFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-lzop-stored-file")) {
        try lzop_cli.encodeStoredFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "decode-lzop-file")) {
        try lzop_cli.decodeFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "size-lzop-file")) {
        try lzop_cli.sizeFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "inspect-lzop-file")) {
        try lzop_cli.inspectFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "create-7z-file")) {
        try seven_zip_cli.createFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "list-7z-file")) {
        try seven_zip_cli.listFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "list-7z-source-file")) {
        try seven_zip_cli.listSourceFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-7z-file")) {
        try seven_zip_cli.extractFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-7z-source-file")) {
        try seven_zip_cli.extractSourceFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-7z-source-stream-file")) {
        try seven_zip_cli.extractSourceStreamFile(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "list-7z-volumes")) {
        try seven_zip_cli.listVolumes(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-7z-volumes")) {
        try seven_zip_cli.extractVolumes(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "encode-lzma-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const size_mode = try parseLzmaSizeMode(args.next());
        const input = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(512 * 1024 * 1024));
        defer init.gpa.free(input);
        const encoded = try vort.encodeLzmaAlloc(init.gpa, input, .{ .size_mode = size_mode });
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        try stdout.print("lzma_size_mode={s} input_bytes={d} compressed_bytes={d} path={s}\n", .{
            @tagName(size_mode),
            input.len,
            encoded.len,
            output_path,
        });
    } else if (std.mem.eql(u8, command, "decode-lzma-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = (try parseOptionalLimit(args.next())) orelse std.math.maxInt(usize);
        const max_dictionary_size = (try parseOptionalLimit(args.next())) orelse std.math.maxInt(usize);
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(512 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const decoded = try vort.decodeLzmaAllocWithOptions(init.gpa, compressed, .{
            .max_output_len = max_output_len,
            .max_dictionary_size = max_dictionary_size,
        });
        defer init.gpa.free(decoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
        try stdout.print("lzma_compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ compressed.len, decoded.len, output_path });
    } else if (std.mem.eql(u8, command, "decode-microlzma-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const expected_size_text = args.next() orelse return error.MissingCorpusPath;
        const expected_size = try std.fmt.parseInt(usize, expected_size_text, 10);
        const dictionary_size = if (args.next()) |text|
            try std.fmt.parseInt(u32, text, 10)
        else
            8 * 1024 * 1024;
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(8 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const decoded = try vort.decodeMicroLzmaAllocLimited(
            init.gpa,
            compressed,
            expected_size,
            dictionary_size,
            12 * 1024 * 1024,
        );
        defer init.gpa.free(decoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
        try stdout.print("microlzma_compressed_bytes={d} decoded_bytes={d} dictionary={d} path={s}\n", .{
            compressed.len,
            decoded.len,
            dictionary_size,
            output_path,
        });
    } else if (std.mem.eql(u8, command, "size-lzma-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(512 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const decoded_len = if (max_output_len) |limit|
            try vort.lzmaDecodedSizeLimited(init.gpa, compressed, limit)
        else
            try vort.lzmaDecodedSize(init.gpa, compressed);
        try stdout.print("lzma_compressed_bytes={d} decoded_bytes={d}\n", .{ compressed.len, decoded_len });
    } else if (std.mem.eql(u8, command, "encode-xz-file")) {
        try encodeXzFile(init, &args, stdout, false);
    } else if (std.mem.eql(u8, command, "encode-xz-stored-file")) {
        try encodeXzFile(init, &args, stdout, true);
    } else if (std.mem.eql(u8, command, "decode-xz-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(512 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.decodeXzAllocLimited(init.gpa, compressed, limit)
        else
            try vort.decodeXzAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
        try stdout.print("xz_compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ compressed.len, decoded.len, output_path });
    } else if (std.mem.eql(u8, command, "decode-xz-concat-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(512 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.decodeXzConcatenatedAllocLimited(init.gpa, compressed, limit)
        else
            try vort.decodeXzConcatenatedAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
        try stdout.print("xz_stream_bytes={d} decoded_bytes={d} path={s}\n", .{ compressed.len, decoded.len, output_path });
    } else if (std.mem.eql(u8, command, "size-xz-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(512 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const decoded_len = if (max_output_len) |limit|
            try vort.xzDecodedSizeLimited(init.gpa, compressed, limit)
        else
            try vort.xzDecodedSize(init.gpa, compressed);
        try stdout.print("xz_compressed_bytes={d} decoded_bytes={d}\n", .{ compressed.len, decoded_len });
    } else if (std.mem.eql(u8, command, "inspect-xz-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(512 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const info = try vort.inspectXz(init.gpa, compressed);
        try stdout.print("xz_check={s} blocks={d} compressed_bytes={d} decoded_bytes={d} max_dictionary={d} delta_blocks={d} bcj_blocks={d} x86_blocks={d} powerpc_blocks={d} ia64_blocks={d} arm_blocks={d} arm_thumb_blocks={d} sparc_blocks={d} arm64_blocks={d} riscv_blocks={d}\n", .{
            @tagName(info.check),
            info.block_count,
            info.compressed_size,
            info.uncompressed_size,
            info.max_dictionary_size,
            info.delta_filter_blocks,
            info.bcj_filter_blocks,
            info.x86_filter_blocks,
            info.powerpc_filter_blocks,
            info.ia64_filter_blocks,
            info.arm_filter_blocks,
            info.arm_thumb_filter_blocks,
            info.sparc_filter_blocks,
            info.arm64_filter_blocks,
            info.riscv_filter_blocks,
        });
    } else if (std.mem.eql(u8, command, "create-tar-file")) {
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const entry_name = args.next() orelse return error.MissingCorpusPath;
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const compression = try parseTarCompression(args.next());
        const input = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(512 * 1024 * 1024));
        defer init.gpa.free(input);
        const entries = [_]vort.TarEncodeEntry{.{ .name = entry_name, .data = input }};
        const encoded = try vort.encodeCompressedTarAlloc(init.gpa, &entries, .{ .compression = compression });
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        try stdout.print("tar_compression={s} input_bytes={d} archive_bytes={d} path={s}\n", .{
            @tagName(compression),
            input.len,
            encoded.len,
            output_path,
        });
    } else if (std.mem.eql(u8, command, "list-tar-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const max_tar_size = (try parseOptionalLimit(args.next())) orelse 512 * 1024 * 1024;
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(512 * 1024 * 1024));
        defer init.gpa.free(bytes);
        const owned = try vort.decodeTarAutoAlloc(init.gpa, bytes, max_tar_size);
        defer owned.deinit(init.gpa);
        try stdout.print("tar_entries={d} compression={s}\n", .{ owned.archive.entry_count, @tagName(owned.compression) });
        var iterator_value = owned.archive.iterator();
        var index: usize = 0;
        while (try iterator_value.next()) |entry| : (index += 1) {
            const name = try entry.path.alloc(init.gpa);
            defer init.gpa.free(name);
            try stdout.print("index={d} kind={s} size={d} mode={o} safe={} name={s}", .{
                index,
                @tagName(entry.kind),
                entry.size,
                entry.mode,
                entry.path.isSafeRelative(),
                name,
            });
            if (entry.link_name.len != 0) try stdout.print(" link={s}", .{entry.link_name});
            if (entry.sparse) |sparse_info| try stdout.print(
                " sparse={s} extents={d} stored_size={d}",
                .{
                    @tagName(sparse_info.format),
                    sparse_info.extent_count,
                    sparse_info.data.len,
                },
            );
            try stdout.writeByte('\n');
        }
    } else if (std.mem.eql(u8, command, "extract-tar-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const entry_name = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const max_tar_size = (try parseOptionalLimit(args.next())) orelse 512 * 1024 * 1024;
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(512 * 1024 * 1024));
        defer init.gpa.free(bytes);
        const owned = try vort.decodeTarAutoAlloc(init.gpa, bytes, max_tar_size);
        defer owned.deinit(init.gpa);
        const decoded = try owned.archive.extractByNameAllocLimited(init.gpa, entry_name, max_tar_size);
        defer init.gpa.free(decoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
        try stdout.print("tar_bytes={d} decoded_bytes={d} entry={s} path={s}\n", .{
            owned.bytes.len,
            decoded.len,
            entry_name,
            output_path,
        });
    } else if (std.mem.eql(u8, command, "create-cab-file")) {
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const entry_name = args.next() orelse return error.MissingCorpusPath;
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const compression = try parseCabCompression(args.next());
        const block_size = try parseBlockLen(args.next(), 32 * 1024);
        const window_bits = try parseCabWindowBits(args.next(), compression);
        const quantum_level = try parseCabQuantumLevel(args.next());
        if (block_size > 32 * 1024) return error.InvalidCabinetOptions;
        const input = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(512 * 1024 * 1024));
        defer init.gpa.free(input);
        const entries = [_]vort.CabEncodeEntry{.{ .name = entry_name, .data = input }};
        const encoded = try vort.encodeCabAlloc(init.gpa, &entries, .{
            .compression = compression,
            .block_size = @intCast(block_size),
            .lzx_window_bits = window_bits,
            .quantum_window_bits = window_bits,
            .quantum_level = quantum_level,
        });
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        try stdout.print("cab_compression={s} input_bytes={d} cabinet_bytes={d} path={s}\n", .{
            @tagName(compression),
            input.len,
            encoded.len,
            output_path,
        });
    } else if (std.mem.eql(u8, command, "list-cab-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(512 * 1024 * 1024));
        defer init.gpa.free(bytes);
        const archive = try vort.parseCabArchive(bytes);
        try stdout.print("cab_files={d} folders={d} set_id={d} cabinet_index={d}\n", .{
            archive.file_count,
            archive.folder_count,
            archive.set_id,
            archive.cabinet_index,
        });
        var iterator_value = archive.iterator();
        var index: usize = 0;
        while (try iterator_value.next()) |entry| : (index += 1) {
            const compression = (try archive.folderAt(entry.folder_index)).compression;
            const compression_name: []const u8 = switch (compression) {
                .none => "stored",
                .mszip => "mszip",
                .quantum => "quantum",
                .lzx => "lzx",
                else => "unknown",
            };
            try stdout.print("index={d} folder={d} method={s} size={d} utf8={} safe={} name={s}\n", .{
                index,
                entry.folder_index,
                compression_name,
                entry.size,
                entry.isUtf8(),
                entry.isSafeRelative(),
                entry.name,
            });
        }
    } else if (std.mem.eql(u8, command, "create-cab-set")) {
        const output_dir = args.next() orelse return error.MissingCorpusPath;
        const entry_name = args.next() orelse return error.MissingCorpusPath;
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const max_cabinet_size = try parseBlockLen(args.next(), 64 * 1024 * 1024);
        const compression = try parseCabCompression(args.next());
        const window_bits = try parseCabWindowBits(args.next(), compression);
        const quantum_level = try parseCabQuantumLevel(args.next());
        const input = try std.Io.Dir.cwd().readFileAlloc(
            init.io,
            input_path,
            init.gpa,
            .limited(512 * 1024 * 1024),
        );
        defer init.gpa.free(input);
        const entries = [_]vort.CabEncodeEntry{.{ .name = entry_name, .data = input }};
        var encoded = try vort.encodeCabinetSetAlloc(init.gpa, &entries, .{
            .cabinet = .{
                .compression = compression,
                .lzx_window_bits = window_bits,
                .quantum_window_bits = window_bits,
                .quantum_level = quantum_level,
            },
            .max_cabinet_size = max_cabinet_size,
        });
        defer encoded.deinit(init.gpa);
        try std.Io.Dir.cwd().createDirPath(init.io, output_dir);
        var destination = try std.Io.Dir.cwd().openDir(init.io, output_dir, .{});
        defer destination.close(init.io);
        for (encoded.parts) |part|
            try destination.writeFile(init.io, .{ .sub_path = part.name, .data = part.bytes });
        try stdout.print("cabinet_count={d} input_bytes={d} compression={s} directory={s}\n", .{
            encoded.parts.len,
            input.len,
            @tagName(compression),
            output_dir,
        });
    } else if (std.mem.eql(u8, command, "extract-cab-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const entry_name = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const max_file_size = (try parseOptionalLimit(args.next())) orelse 512 * 1024 * 1024;
        const max_folder_size = (try parseOptionalLimit(args.next())) orelse 512 * 1024 * 1024;
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(512 * 1024 * 1024));
        defer init.gpa.free(bytes);
        const archive = try vort.parseCabArchive(bytes);
        const entry = (try archive.find(entry_name)) orelse return error.CabinetEntryNotFound;
        const decoded = try vort.cabExtractAllocWithOptions(init.gpa, archive, entry, .{
            .max_file_size = max_file_size,
            .max_folder_size = max_folder_size,
        });
        defer init.gpa.free(decoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
        try stdout.print("cab_bytes={d} decoded_bytes={d} entry={s} path={s}\n", .{
            bytes.len,
            decoded.len,
            entry_name,
            output_path,
        });
    } else if (std.mem.eql(u8, command, "extract-cab-set")) {
        const entry_name = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        var owned: std.ArrayList([]u8) = .empty;
        defer {
            for (owned.items) |bytes| init.gpa.free(bytes);
            owned.deinit(init.gpa);
        }
        var archives: std.ArrayList(vort.CabArchive) = .empty;
        defer archives.deinit(init.gpa);
        while (args.next()) |input_path| {
            const bytes = try std.Io.Dir.cwd().readFileAlloc(
                init.io,
                input_path,
                init.gpa,
                .limited(512 * 1024 * 1024),
            );
            const parsed = vort.parseCabArchive(bytes) catch |err| {
                init.gpa.free(bytes);
                return err;
            };
            owned.append(init.gpa, bytes) catch |err| {
                init.gpa.free(bytes);
                return err;
            };
            try archives.append(init.gpa, parsed);
        }
        if (archives.items.len == 0) return error.MissingCorpusPath;
        const set = try vort.initCabinetSet(archives.items);
        const decoded = try set.extractByNameAllocLimited(
            init.gpa,
            entry_name,
            512 * 1024 * 1024,
        );
        defer init.gpa.free(decoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
        try stdout.print("cabinet_count={d} decoded_bytes={d} entry={s} path={s}\n", .{
            archives.items.len,
            decoded.len,
            entry_name,
            output_path,
        });
    } else if (std.mem.eql(u8, command, "create-zip-split-file")) {
        try zip_cli.createSplit(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "create-zip-split-stream-file")) {
        try zip_cli.createSplitStream(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "list-zip-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(512 * 1024 * 1024));
        defer init.gpa.free(bytes);
        const archive = try vort.parseZipArchive(bytes);
        try stdout.print("zip_entries={d} zip64={} comment_bytes={d}\n", .{ archive.entry_count, archive.zip64, archive.comment.len });
        var it = archive.iterator();
        var index: usize = 0;
        while (try it.next()) |entry| : (index += 1) {
            const method_name: []const u8 = switch (entry.method) {
                .stored => "stored",
                .shrink => "shrink",
                .reduce_1 => "reduce1",
                .reduce_2 => "reduce2",
                .reduce_3 => "reduce3",
                .reduce_4 => "reduce4",
                .implode => "implode",
                .deflate => "deflate",
                .deflate64 => "deflate64",
                .dcl_implode => "dcl-implode",
                .bzip2 => "bzip2",
                .lzma => "lzma",
                .zstandard_legacy => "zstd-legacy",
                .zstandard => "zstd",
                .xz => "xz",
                .ppmd => "ppmd",
                else => "unsupported",
            };
            try stdout.print("index={d} method={s} compressed={d} uncompressed={d} crc32={d} directory={} name={s}\n", .{
                index,
                method_name,
                entry.compressed_size,
                entry.uncompressed_size,
                entry.crc32,
                entry.isDirectory(),
                entry.name,
            });
        }
    } else if (std.mem.eql(u8, command, "extract-zip-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const entry_name = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const max_dictionary_size = (try parseOptionalLimit(args.next())) orelse 64 * 1024 * 1024;
        const password_arg = args.next();
        const password = if (password_arg) |value|
            if (std.mem.eql(u8, value, "-")) null else value
        else
            null;
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(512 * 1024 * 1024));
        defer init.gpa.free(bytes);
        const decoded = try vort.zipExtractByNameAllocWithOptions(init.gpa, bytes, entry_name, .{
            .max_output_len = max_output_len orelse std.math.maxInt(usize),
            .max_dictionary_size = max_dictionary_size,
            .password = password,
        });
        defer init.gpa.free(decoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
        try stdout.print("zip_bytes={d} decoded_bytes={d} entry={s} path={s}\n", .{ bytes.len, decoded.len, entry_name, output_path });
    } else if (std.mem.eql(u8, command, "extract-zip-split-files")) {
        try zip_cli.extractSplitOwned(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-zip-split-stream-files")) {
        try zip_cli.extractSplitStream(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-zip-split-source-files")) {
        try zip_cli.extractSplitSource(init, &args, stdout);
    } else if (std.mem.eql(u8, command, "extract-zip-file-incremental")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const entry_name = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = (try parseOptionalLimit(args.next())) orelse std.math.maxInt(usize);
        const password_arg = args.next();
        const password = if (password_arg) |value|
            if (std.mem.eql(u8, value, "-")) null else value
        else
            null;
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(512 * 1024 * 1024));
        defer init.gpa.free(bytes);
        const archive = try vort.parseZipArchive(bytes);
        const entry = (try archive.find(entry_name)) orelse return error.ZipEntryNotFound;
        const compressed = if (entry.isEncrypted())
            try archive.rawEntryData(entry)
        else
            try archive.compressedData(entry);
        var decoder = try vort.ZipOwnedIncrementalEntryDecoder.initWithOptions(init.gpa, entry, .{
            .max_output_len = max_output_len,
            .password = password,
        });
        defer decoder.deinit();
        var decoded: std.ArrayList(u8) = .empty;
        defer decoded.deinit(init.gpa);
        try decoded.ensureTotalCapacity(init.gpa, entry.uncompressed_size);
        var input_offset: usize = 0;
        var calls: usize = 0;
        while (true) {
            const input_end = @min(compressed.len, input_offset + 3);
            var output: [5]u8 = undefined;
            const result = try decoder.step(compressed[input_offset..input_end], &output);
            input_offset += result.progress.input_read;
            try decoded.appendSlice(init.gpa, output[0..result.progress.output_written]);
            calls += 1;
            if (result.status == .done) break;
            if (result.progress.input_read == 0 and result.progress.output_written == 0)
                return error.InvalidBlockPlan;
        }
        if (input_offset != compressed.len or decoded.items.len != entry.uncompressed_size)
            return error.SizeMismatch;
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded.items });
        try stdout.print("zip_bytes={d} compressed_bytes={d} decoded_bytes={d} calls={d} entry={s} path={s}\n", .{
            bytes.len,
            compressed.len,
            decoded.items.len,
            calls,
            entry_name,
            output_path,
        });
    } else if (std.mem.eql(u8, command, "extract-zip-stream-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const entry_name = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = (try parseOptionalLimit(args.next())) orelse std.math.maxInt(usize);
        const password_arg = args.next();
        const password = if (password_arg) |value|
            if (std.mem.eql(u8, value, "-")) null else value
        else
            null;
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(512 * 1024 * 1024));
        defer init.gpa.free(bytes);
        const parsed_archive = try vort.parseZipArchive(bytes);
        const stream_offset = if (parsed_archive.entry_count == 0)
            parsed_archive.central_directory_offset
        else
            (try parsed_archive.entryAt(0)).local_header_offset;
        var reader = try vort.ZipIncrementalReader.initWithOptions(init.gpa, .{
            .initial_offset = stream_offset,
            .password = password,
        });
        defer reader.deinit();
        var decoded: std.ArrayList(u8) = .empty;
        defer decoded.deinit(init.gpa);
        var input_offset = stream_offset;
        var selected = false;
        var found = false;
        var calls: usize = 0;
        while (true) {
            const input_end = @min(bytes.len, input_offset + 3);
            var output: [5]u8 = undefined;
            const result = try reader.step(bytes[input_offset..input_end], &output);
            input_offset += result.progress.input_read;
            if (selected and result.progress.output_written != 0) {
                if (result.progress.output_written > max_output_len -| decoded.items.len)
                    return error.OutputLimitExceeded;
                try decoded.appendSlice(init.gpa, output[0..result.progress.output_written]);
            }
            calls += 1;
            switch (result.status) {
                .entry_header => {
                    const current = reader.currentEntry().?;
                    selected = !found and std.mem.eql(
                        u8,
                        current.preferredName(),
                        entry_name,
                    );
                },
                .entry_done => {
                    if (selected) found = true;
                    selected = false;
                },
                .done => break,
                .need_input, .need_output => {},
            }
            if (result.status != .done and
                result.progress.input_read == 0 and
                result.progress.output_written == 0 and
                result.status != .entry_header and
                result.status != .entry_done)
                return error.InvalidBlockPlan;
        }
        if (!found) return error.ZipEntryNotFound;
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded.items });
        try stdout.print("zip_bytes={d} entries={d} decoded_bytes={d} calls={d} entry={s} path={s}\n", .{
            bytes.len,
            reader.snapshot().completed_entries,
            decoded.items.len,
            calls,
            entry_name,
            output_path,
        });
    } else if (std.mem.eql(u8, command, "size-br-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const decoded_len = if (max_output_len) |limit|
            try vort.brDecodedStreamSizeLimited(compressed, limit)
        else
            try vort.brDecodedStreamSize(compressed);
        try stdout.print("br_compressed_bytes={d} decoded_bytes={d}\n", .{ compressed.len, decoded_len });
    } else if (std.mem.eql(u8, command, "encode-raw-fixed-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawFixedWithOptionsAlloc(init.gpa, payload, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-raw-dict-fixed-hex")) {
        const payload = args.next() orelse "";
        const dictionary = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawFixedWithDictionaryAlloc(init.gpa, payload, dictionary, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-zlib-fixed-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibFixedWithOptionsAlloc(init.gpa, payload, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-zlib-dict-stored-hex")) {
        const payload = args.next() orelse "";
        const dictionary = args.next() orelse "";
        const encoded = try vort.encodeZlibStoredWithDictionaryAlloc(init.gpa, payload, dictionary);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-zlib-dict-fixed-hex")) {
        const payload = args.next() orelse "";
        const dictionary = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibFixedWithDictionaryAlloc(init.gpa, payload, dictionary, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-gzip-fixed-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeGzipFixedWithOptionsAlloc(init.gpa, payload, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "vort-best-roundtrip")) {
        const payload = args.next() orelse "";
        const frame = try vort.storeEncodeBestAlloc(init.gpa, payload);
        defer init.gpa.free(frame);
        const decoded = try vort.storeDecodeAnyAlloc(init.gpa, frame);
        defer init.gpa.free(decoded);
        try stdout.print("input_bytes={d} frame_bytes={d} decoded_ok={} crc32={d}\n", .{
            payload.len,
            frame.len,
            std.mem.eql(u8, payload, decoded),
            vort.crc32(decoded),
        });
    } else if (std.mem.eql(u8, command, "vort-rle-roundtrip")) {
        const payload = args.next() orelse "";
        const frame = try vort.storeEncodeRleAlloc(init.gpa, payload);
        defer init.gpa.free(frame);
        const decoded = try vort.storeDecodeAnyAlloc(init.gpa, frame);
        defer init.gpa.free(decoded);
        try stdout.print("input_bytes={d} frame_bytes={d} decoded_ok={} crc32={d}\n", .{
            payload.len,
            frame.len,
            std.mem.eql(u8, payload, decoded),
            vort.crc32(decoded),
        });
    } else if (std.mem.eql(u8, command, "vort-deflate-roundtrip")) {
        const payload = args.next() orelse "";
        const frame = try vort.storeEncodeDeflateAlloc(init.gpa, payload);
        defer init.gpa.free(frame);
        const decoded = try vort.storeDecodeAnyAlloc(init.gpa, frame);
        defer init.gpa.free(decoded);
        try stdout.print("input_bytes={d} frame_bytes={d} decoded_ok={} crc32={d}\n", .{
            payload.len,
            frame.len,
            std.mem.eql(u8, payload, decoded),
            vort.crc32(decoded),
        });
    } else if (std.mem.eql(u8, command, "vort-workqueue-demo")) {
        const input = "abcdefghijklmnopqrstuvwxyz" ** 4;
        const stream = try vort.storeEncodeWorkStealingDeflateStreamAlloc(init.gpa, input, 13, 3);
        defer init.gpa.free(stream);
        const range = try vort.storeDecodeIndexedRangeAlloc(init.gpa, stream, 10, 20);
        defer init.gpa.free(range);
        try stdout.print("range={s} workqueue_stream_bytes={d}\n", .{ range, stream.len });
    } else if (std.mem.eql(u8, command, "vort-threadpool-demo")) {
        const input = "abcdefghijklmnopqrstuvwxyz" ** 4;
        const stream = try vort.storeEncodeThreadPoolDeflateStreamAlloc(init.gpa, input, 13, 3);
        defer init.gpa.free(stream);
        const range = try vort.storeDecodeIndexedRangeAlloc(init.gpa, stream, 10, 20);
        defer init.gpa.free(range);
        try stdout.print("range={s} threadpool_stream_bytes={d}\n", .{ range, stream.len });
    } else if (std.mem.eql(u8, command, "vort-parallel-demo")) {
        const input = "abcdefghijklmnopqrstuvwxyz" ** 4;
        const stream = try vort.storeEncodeParallelDeflateStreamAlloc(init.gpa, input, 13, 3);
        defer init.gpa.free(stream);
        const range = try vort.storeDecodeIndexedRangeAlloc(init.gpa, stream, 10, 20);
        defer init.gpa.free(range);
        try stdout.print("range={s} parallel_stream_bytes={d}\n", .{ range, stream.len });
    } else if (std.mem.eql(u8, command, "vort-blocked-range-demo")) {
        const input = "abcdefghijklmnopqrstuvwxyz";
        const stream = try vort.storeEncodeBlockedDeflateStreamAlloc(init.gpa, input, 7);
        defer init.gpa.free(stream);
        const range = try vort.storeDecodeIndexedRangeAlloc(init.gpa, stream, 5, 12);
        defer init.gpa.free(range);
        try stdout.print("range={s} blocked_stream_bytes={d}\n", .{ range, stream.len });
    } else if (std.mem.eql(u8, command, "vort-blocked-best-range-demo")) {
        const input = "abcdefghijklmnopqrstuvwxyz" ++ ("aaaaaaaaaaaaaaaa" ** 2) ++ ("abcabcabcabc" ** 2);
        const stream = try vort.storeEncodeBlockedBestStreamAlloc(init.gpa, input, 16);
        defer init.gpa.free(stream);
        const range = try vort.storeDecodeIndexedRangeAlloc(init.gpa, stream, 10, 32);
        defer init.gpa.free(range);
        const modes = try vort.storeSummarizeModes(stream);
        try stdout.print("range={s} blocked_best_stream_bytes={d} modes={d}/{d}/{d}\n", .{ range, stream.len, modes.store, modes.deflate, modes.rle });
    } else if (std.mem.eql(u8, command, "vort-dict-blocked-range-demo")) {
        const dict = "dictionary-only phrase with enough length to beat stored framing";
        const input = (dict ++ "!") ** 3;
        const stream = try vort.storeEncodeBlockedBestWithDictionaryStreamAlloc(init.gpa, dict, input, dict.len + 1, 8);
        defer init.gpa.free(stream);
        const range = try vort.storeDecodeIndexedRangeWithDictionaryAlloc(init.gpa, dict, stream, 5, 40);
        defer init.gpa.free(range);
        const modes = try vort.storeSummarizeModes(stream);
        try stdout.print("range={s} dict_blocked_stream_bytes={d} modes={d}/{d}/{d}/{d}\n", .{ range, stream.len, modes.store, modes.deflate, modes.rle, modes.dictionary_patch + modes.dictionary_deflate });
    } else if (std.mem.eql(u8, command, "vort-self-dict-range-demo")) {
        const phrase = "self-contained dictionary phrase for native streams";
        const input = (phrase ++ "!") ** 4;
        const stream = try vort.storeEncodeSelfContainedDictionaryStreamAlloc(init.gpa, input, phrase.len + 1, 256, 8);
        defer init.gpa.free(stream);
        const range = try vort.storeDecodeSelfContainedDictionaryRangeAlloc(init.gpa, stream, 7, 64);
        defer init.gpa.free(range);
        const dict = try vort.storeParseEmbeddedDictionaryAlloc(init.gpa, stream);
        defer init.gpa.free(dict);
        const modes = try vort.storeSummarizeModes(stream);
        try stdout.print("range={s} self_dict_stream_bytes={d} dict_bytes={d} modes={d}/{d}/{d}/{d}\n", .{ range, stream.len, dict.len, modes.store, modes.deflate, modes.rle, modes.dictionary_patch + modes.dictionary_deflate });
    } else if (std.mem.eql(u8, command, "vort-trained-dict-range-demo")) {
        const phrase = "self-contained dictionary phrase for native streams";
        const input = (phrase ++ "!") ** 4;
        const stream = try vort.storeEncodeBestTrainedDictionaryStreamAlloc(init.gpa, input, phrase.len + 1, 256, 8);
        defer init.gpa.free(stream);
        const range = try vort.storeDecodeIndexedRangeAutoAlloc(init.gpa, stream, 7, 64);
        defer init.gpa.free(range);
        const modes = try vort.storeSummarizeModes(stream);
        try stdout.print("range={s} trained_dict_stream_bytes={d} modes={d}/{d}/{d}/{d}\n", .{ range, stream.len, modes.store, modes.deflate, modes.rle, modes.dictionary_patch + modes.dictionary_deflate });
    } else if (std.mem.eql(u8, command, "vort-seekable-native-range-demo")) {
        const phrase = "seekable native trained dictionary phrase";
        const dict_input = (phrase ++ "!") ** 4;
        const dict_stream = try vort.storeEncodeSeekableNativeStreamAlloc(init.gpa, dict_input, .{
            .block_len = phrase.len + 1,
            .dictionary = .{ .enable = true, .target_size = 256, .min_match_len = 8 },
        });
        defer init.gpa.free(dict_stream);
        const dict_range = try vort.storeDecodeIndexedRangeAutoAlloc(init.gpa, dict_stream, 7, 48);
        defer init.gpa.free(dict_range);
        const dict_modes = try vort.storeSummarizeModes(dict_stream);

        const prefix = makeDemoLdmPrefix();
        const ldm_input = prefix ++ "----" ++ prefix[0..1024].*;
        const ldm_stream = try vort.storeEncodeSeekableNativeStreamAlloc(init.gpa, ldm_input, .{
            .block_len = ldm_input.len,
            .long_distance = .{ .enable = true, .options = .{ .min_distance = 32769, .min_length = 16 }, .align_blocks = false },
        });
        defer init.gpa.free(ldm_stream);
        const ldm_range = try vort.storeDecodeIndexedRangeAutoAlloc(init.gpa, ldm_stream, prefix.len + 4, 24);
        defer init.gpa.free(ldm_range);
        const ldm_modes = try vort.storeSummarizeModes(ldm_stream);
        const ldm_summary = try vort.storeParseEmbeddedLdmSummary(ldm_stream);
        try stdout.print("dict_crc32={d} dict_stream_bytes={d} dict_modes={d}/{d}/{d}/{d} ldm_crc32={d} ldm_stream_bytes={d} ldm_modes={d}/{d}/{d}/{d}/{d} ldm_candidates={d}\n", .{ vort.crc32(dict_range), dict_stream.len, dict_modes.store, dict_modes.deflate, dict_modes.rle, dict_modes.dictionary_patch + dict_modes.dictionary_deflate, vort.crc32(ldm_range), ldm_stream.len, ldm_modes.store, ldm_modes.deflate, ldm_modes.rle, ldm_modes.dictionary_patch + ldm_modes.dictionary_deflate, ldm_modes.ldm, ldm_summary.candidates });
    } else if (std.mem.eql(u8, command, "vort-ldm-summary-demo")) {
        const prefix = "abcd" ** 9000;
        const input = prefix ++ "----" ++ prefix[0..64].*;
        const stream = try vort.storeEncodeBlockedBestStreamWithLdmSummaryAlloc(init.gpa, input, 8192, .{}, .{ .min_distance = 32769, .min_length = 16 });
        defer init.gpa.free(stream);
        const summary = try vort.storeParseEmbeddedLdmSummary(stream);
        try stdout.print("ldm_stream_bytes={d} candidates={d} longest={d} max_distance={d}\n", .{ stream.len, summary.candidates, summary.longest, summary.max_distance });
    } else if (std.mem.eql(u8, command, "vort-ldm-blocked-range-demo")) {
        const prefix = makeDemoLdmPrefix();
        const input = prefix ++ "----" ++ prefix[0..1024].*;
        const stream = try vort.storeEncodeBlockedBestStreamWithLdmAlloc(init.gpa, input, input.len, .{}, .{ .min_distance = 32769, .min_length = 16 });
        defer init.gpa.free(stream);
        const range = try vort.storeDecodeIndexedRangeAlloc(init.gpa, stream, prefix.len + 4, 24);
        defer init.gpa.free(range);
        const modes = try vort.storeSummarizeModes(stream);
        try stdout.print("range_crc32={d} ldm_blocked_stream_bytes={d} modes={d}/{d}/{d}/{d}/{d}\n", .{ vort.crc32(range), stream.len, modes.store, modes.deflate, modes.rle, modes.dictionary_patch + modes.dictionary_deflate, modes.ldm });
    } else if (std.mem.eql(u8, command, "vort-sidecar-ldm-range-demo")) {
        const prefix = makeDemoLdmPrefix();
        const input = prefix ++ "----" ++ prefix[0..1024].*;
        const sidecar = try vort.storeEncodeSidecarBlockedBestStreamWithLdmAlloc(init.gpa, input, input.len, .{}, .{ .min_distance = 32769, .min_length = 16 });
        defer sidecar.deinit(init.gpa);
        const range = try vort.storeDecodeSidecarIndexedRangeAlloc(init.gpa, sidecar.stream, sidecar.sidecar_index, prefix.len + 4, 24);
        defer init.gpa.free(range);
        const modes = try vort.storeSummarizeModes(sidecar.stream);
        try stdout.print("range_crc32={d} sidecar_ldm_stream_bytes={d} sidecar_bytes={d} modes={d}/{d}/{d}/{d}/{d}\n", .{ vort.crc32(range), sidecar.stream.len, sidecar.sidecar_index.len, modes.store, modes.deflate, modes.rle, modes.dictionary_patch + modes.dictionary_deflate, modes.ldm });
    } else if (std.mem.eql(u8, command, "vort-ldm-indexed-range-demo")) {
        const prefix = makeDemoLdmPrefix();
        const payloads = [_][]const u8{
            prefix ++ "----" ++ prefix[0..1024].*,
            "tail",
        };
        const stream = try vort.storeEncodeIndexedLongDistanceStreamAlloc(init.gpa, &payloads, .{ .min_distance = 32769, .min_length = 16 });
        defer init.gpa.free(stream);
        const range = try vort.storeDecodeIndexedRangeAlloc(init.gpa, stream, prefix.len + 4, 24);
        defer init.gpa.free(range);
        const modes = try vort.storeSummarizeModes(stream);
        try stdout.print("range_crc32={d} ldm_indexed_stream_bytes={d} modes={d}/{d}/{d}/{d}/{d}\n", .{ vort.crc32(range), stream.len, modes.store, modes.deflate, modes.rle, modes.dictionary_patch + modes.dictionary_deflate, modes.ldm });
    } else if (std.mem.eql(u8, command, "store-range-demo")) {
        const payloads = [_][]const u8{ "alpha", "beta", "gamma" };
        const stream = try vort.storeEncodeIndexedStreamAlloc(init.gpa, &payloads);
        defer init.gpa.free(stream);
        const range = try vort.storeDecodeIndexedRangeAlloc(init.gpa, stream, 3, 8);
        defer init.gpa.free(range);
        const modes = try vort.storeSummarizeModes(stream);
        try stdout.print("range={s} indexed_stream_bytes={d} modes={d}/{d}/{d}\n", .{ range, stream.len, modes.store, modes.deflate, modes.rle });
    } else if (std.mem.eql(u8, command, "vort-sidecar-blocked-best-range-demo")) {
        const input = "abcdefghijklmnopqrstuvwxyz" ++ ("aaaaaaaaaaaaaaaa" ** 2) ++ ("abcabcabcabc" ** 2);
        const sidecar = try vort.storeEncodeSidecarBlockedBestStreamAlloc(init.gpa, input, 16);
        defer sidecar.deinit(init.gpa);
        const range = try vort.storeDecodeSidecarIndexedRangeAlloc(init.gpa, sidecar.stream, sidecar.sidecar_index, 10, 32);
        defer init.gpa.free(range);
        const modes = try vort.storeSummarizeModes(sidecar.stream);
        try stdout.print("range={s} stream_bytes={d} sidecar_bytes={d} modes={d}/{d}/{d}\n", .{ range, sidecar.stream.len, sidecar.sidecar_index.len, modes.store, modes.deflate, modes.rle });
    } else if (std.mem.eql(u8, command, "store-sidecar-range-demo")) {
        const first = try vort.storeEncodeAlloc(init.gpa, "alpha");
        defer init.gpa.free(first);
        const second = try vort.storeEncodeAlloc(init.gpa, "beta");
        defer init.gpa.free(second);
        var stream: std.ArrayList(u8) = .empty;
        defer stream.deinit(init.gpa);
        try stream.appendSlice(init.gpa, first);
        try stream.appendSlice(init.gpa, second);
        const index = try vort.storeBuildFrameIndexAlloc(init.gpa, stream.items);
        defer init.gpa.free(index);
        const sidecar = try vort.storeEncodeFrameIndexAlloc(init.gpa, index);
        defer init.gpa.free(sidecar);
        const range = try vort.storeDecodeSidecarIndexedRangeAlloc(init.gpa, stream.items, sidecar, 3, 5);
        defer init.gpa.free(range);
        try stdout.print("range={s} stream_bytes={d} sidecar_bytes={d}\n", .{ range, stream.items.len, sidecar.len });
    } else if (std.mem.eql(u8, command, "store-sidecar-dict-range-demo")) {
        const phrase = "self-contained dictionary phrase for native streams";
        const input = (phrase ++ "!") ** 3;
        const stream = try vort.storeEncodeSelfContainedDictionaryStreamAlloc(init.gpa, input, phrase.len + 1, 256, 8);
        defer init.gpa.free(stream);
        const embedded = try vort.store.parseEmbeddedIndexAlloc(init.gpa, stream);
        defer embedded.deinit(init.gpa);
        const sidecar = try vort.storeEncodeFrameIndexAlloc(init.gpa, embedded.entries);
        defer init.gpa.free(sidecar);
        const range = try vort.storeDecodeSidecarIndexedRangeAutoAlloc(init.gpa, stream, sidecar, 7, 64);
        defer init.gpa.free(range);
        try stdout.print("range={s} stream_bytes={d} sidecar_bytes={d}\n", .{ range, stream.len, sidecar.len });
    } else if (std.mem.eql(u8, command, "encode-raw-fixed-split-hex")) {
        const payload = args.next() orelse "";
        const encoded = try vort.encodeRawFixedSplitAlloc(init.gpa, payload, 7, vort.optionsForCompressionLevel(.fast));
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-raw-best-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawBestAlloc(init.gpa, payload, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-raw-dict-best-hex")) {
        const payload = args.next() orelse "";
        const dictionary = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawBestWithDictionaryAlloc(init.gpa, payload, dictionary, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-raw-dict-best-split-hex")) {
        const payload = args.next() orelse "";
        const dictionary = args.next() orelse "";
        const block_len = try parseBlockLen(args.next(), 7);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawBestSplitWithDictionaryAlloc(init.gpa, payload, dictionary, block_len, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-raw-dict-best-adaptive-hex")) {
        const payload = args.next() orelse "";
        const dictionary = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawBestAdaptiveSplitWithDictionaryAlloc(init.gpa, payload, dictionary, options, options.split_options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-raw-best-split-hex")) {
        const payload = args.next() orelse "";
        const block_len = try parseBlockLen(args.next(), 7);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawBestSplitAlloc(init.gpa, payload, block_len, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-raw-best-adaptive-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawBestAdaptiveSplitAlloc(init.gpa, payload, options, options.split_options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-zlib-best-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibBestAlloc(init.gpa, payload, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-zlib-dict-best-hex")) {
        const payload = args.next() orelse "";
        const dictionary = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibBestWithDictionaryAlloc(init.gpa, payload, dictionary, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-zlib-dict-best-split-hex")) {
        const payload = args.next() orelse "";
        const dictionary = args.next() orelse "";
        const block_len = try parseBlockLen(args.next(), 7);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibBestSplitWithDictionaryAlloc(init.gpa, payload, dictionary, block_len, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-zlib-dict-best-adaptive-hex")) {
        const payload = args.next() orelse "";
        const dictionary = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibBestAdaptiveSplitWithDictionaryAlloc(init.gpa, payload, dictionary, options, options.split_options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-zlib-best-split-hex")) {
        const payload = args.next() orelse "";
        const block_len = try parseBlockLen(args.next(), 7);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibBestSplitAlloc(init.gpa, payload, block_len, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-zlib-best-adaptive-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibBestAdaptiveSplitAlloc(init.gpa, payload, options, options.split_options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-gzip-best-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeGzipBestAlloc(init.gpa, payload, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-gzip-best-split-hex")) {
        const payload = args.next() orelse "";
        const block_len = try parseBlockLen(args.next(), 7);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeGzipBestSplitAlloc(init.gpa, payload, block_len, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-gzip-best-adaptive-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeGzipBestAdaptiveSplitAlloc(init.gpa, payload, options, options.split_options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-raw-dynamic-split-hex")) {
        const payload = args.next() orelse "";
        const encoded = try vort.encodeRawDynamicSplitAlloc(init.gpa, payload, 7, vort.optionsForCompressionLevel(.fast));
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-raw-dynamic-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawDynamicWithOptionsAlloc(init.gpa, payload, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-raw-dict-dynamic-hex")) {
        const payload = args.next() orelse "";
        const dictionary = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawDynamicWithDictionaryAlloc(init.gpa, payload, dictionary, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-zlib-dynamic-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibDynamicWithOptionsAlloc(init.gpa, payload, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-zlib-dict-dynamic-hex")) {
        const payload = args.next() orelse "";
        const dictionary = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibDynamicWithDictionaryAlloc(init.gpa, payload, dictionary, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-gzip-dynamic-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeGzipDynamicWithOptionsAlloc(init.gpa, payload, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-zstd-native-hex")) {
        const payload = args.next() orelse "";
        const selection = try parseZstdNativeSelection(args.next());
        const checksum = try parseOptionalBool(args.next(), true);
        const content_size = try parseOptionalBool(args.next(), true);
        const result = try vort.zstdEncodeNativeFrameWithOptionsAlloc(init.gpa, payload, .{
            .selection = selection,
            .content_checksum = checksum,
            .include_content_size = content_size,
        });
        defer init.gpa.free(result.frame);
        try printHex(stdout, result.frame);
    } else if (std.mem.eql(u8, command, "encode-zstd-native-bytes-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const payload = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(payload);
        const selection = try parseZstdNativeSelection(args.next());
        const checksum = try parseOptionalBool(args.next(), true);
        const content_size = try parseOptionalBool(args.next(), true);
        const result = try vort.zstdEncodeNativeFrameWithOptionsAlloc(init.gpa, payload, .{
            .selection = selection,
            .content_checksum = checksum,
            .include_content_size = content_size,
        });
        defer init.gpa.free(result.frame);
        try printHex(stdout, result.frame);
    } else if (std.mem.eql(u8, command, "encode-zstd-native-file-hex")) {
        const path = args.next() orelse return error.MissingCorpusPath;
        const payload = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(payload);
        const selection = try parseZstdNativeSelection(args.next());
        const checksum = try parseOptionalBool(args.next(), true);
        const content_size = try parseOptionalBool(args.next(), true);
        const result = try vort.zstdEncodeNativeFrameWithOptionsAlloc(init.gpa, payload, .{
            .selection = selection,
            .content_checksum = checksum,
            .include_content_size = content_size,
        });
        defer init.gpa.free(result.frame);
        try printHex(stdout, result.frame);
    } else if (std.mem.eql(u8, command, "encode-zstd-native-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const payload = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(payload);
        const selection = try parseZstdNativeSelection(args.next());
        const checksum = try parseOptionalBool(args.next(), true);
        const content_size = try parseOptionalBool(args.next(), true);
        const result = try vort.zstdEncodeNativeFrameWithOptionsAlloc(init.gpa, payload, .{
            .selection = selection,
            .content_checksum = checksum,
            .include_content_size = content_size,
        });
        defer init.gpa.free(result.frame);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = result.frame });
        try stdout.print("zstd_native_compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ result.frame.len, payload.len, output_path });
    } else if (std.mem.eql(u8, command, "decode-zstd-native-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.zstdDecodeNativeFrameAllocLimited(init.gpa, compressed, limit)
        else
            try vort.zstdDecodeNativeFrameAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try printDecoded(stdout, "zstd_native", compressed.len, decoded);
    } else if (std.mem.eql(u8, command, "decode-zstd-native-file")) {
        const path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.zstdDecodeNativeFrameAllocLimited(init.gpa, compressed, limit)
        else
            try vort.zstdDecodeNativeFrameAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try printDecoded(stdout, "zstd_native", compressed.len, decoded);
    } else if (std.mem.eql(u8, command, "decode-zstd-native-file-to")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.zstdDecodeNativeFrameAllocLimited(init.gpa, compressed, limit)
        else
            try vort.zstdDecodeNativeFrameAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
        try stdout.print("zstd_native_compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ compressed.len, decoded.len, output_path });
    } else if (std.mem.eql(u8, command, "size-zstd-native-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const decoded_len = if (max_output_len) |limit|
            try vort.zstdDecodedNativeFrameSizeLimited(compressed, limit)
        else
            try vort.zstdDecodedNativeFrameSize(compressed);
        try stdout.print("zstd_native_compressed_bytes={d} decoded_bytes={d}\n", .{ compressed.len, decoded_len });
    } else if (std.mem.eql(u8, command, "size-zstd-native-file")) {
        const path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const decoded_len = if (max_output_len) |limit|
            try vort.zstdDecodedNativeFrameSizeLimited(compressed, limit)
        else
            try vort.zstdDecodedNativeFrameSize(compressed);
        try stdout.print("zstd_native_compressed_bytes={d} decoded_bytes={d}\n", .{ compressed.len, decoded_len });
    } else if (std.mem.eql(u8, command, "summary-zstd-native-file")) {
        const path = args.next() orelse return error.MissingCorpusPath;
        const output_format = try parseHeaderInspectOutputFormat(args.next());
        const frame = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(frame);
        var diagnostics: vort.ZstdNativeStreamSummaryErrorDiagnostics = .{};
        const summary = vort.zstdSummarizeNativeStreamWithDiagnostics(frame, &diagnostics) catch |err| {
            if (output_format == .json) {
                try printNativeSummaryErrorJson(stdout, "vort.zstd_native_stream_summary_error", frame.len, err, .{ .phase = @tagName(diagnostics.phase), .offset = diagnostics.offset });
                try stdout.flush();
                std.process.exit(1);
            }
            return err;
        };
        try printZstdNativeSummary(stdout, frame.len, summary, output_format);
    } else if (std.mem.eql(u8, command, "encode-lz4-native-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const payload = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(payload);
        const frame = try vort.lz4EncodeNativeFrameAlloc(init.gpa, payload);
        defer init.gpa.free(frame);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = frame });
        try stdout.print("lz4_native_compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ frame.len, payload.len, output_path });
    } else if (std.mem.eql(u8, command, "size-lz4-native-file")) {
        const path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const frame = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(frame);
        const decoded_len = if (max_output_len) |limit|
            try vort.lz4DecodedFrameSizeLimited(frame, limit)
        else
            try vort.lz4DecodedFrameSize(frame);
        try stdout.print("lz4_native_compressed_bytes={d} decoded_bytes={d}\n", .{ frame.len, decoded_len });
    } else if (std.mem.eql(u8, command, "summary-lz4-native-file")) {
        const path = args.next() orelse return error.MissingCorpusPath;
        const output_format = try parseHeaderInspectOutputFormat(args.next());
        const frame = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(frame);
        var diagnostics: vort.Lz4NativeStreamSummaryErrorDiagnostics = .{};
        const summary = vort.lz4SummarizeNativeStreamWithDiagnostics(frame, &diagnostics) catch |err| {
            if (output_format == .json) {
                try printNativeSummaryErrorJson(stdout, "vort.lz4_native_stream_summary_error", frame.len, err, .{ .phase = @tagName(diagnostics.phase), .offset = diagnostics.offset });
                try stdout.flush();
                std.process.exit(1);
            }
            return err;
        };
        try printLz4NativeSummary(stdout, frame.len, summary, output_format);
    } else if (std.mem.eql(u8, command, "decode-lz4-native-file-to")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const frame = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(frame);
        const decoded = if (max_output_len) |limit|
            try vort.lz4DecodeNativeFrameAllocLimited(init.gpa, frame, limit)
        else
            try vort.lz4DecodeNativeFrameAlloc(init.gpa, frame);
        defer init.gpa.free(decoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
        try stdout.print("lz4_native_compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ frame.len, decoded.len, output_path });
    } else if (std.mem.eql(u8, command, "size-lz4-block-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const max_output_len = try parseOptionalLimit(args.next());
        const block = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(block);
        const decoded_len = if (max_output_len) |limit|
            try vort.lz4DecodedBlockSizeLimited(block, limit)
        else
            try vort.lz4DecodedBlockSize(block);
        try stdout.print("lz4_block_compressed_bytes={d} decoded_bytes={d}\n", .{ block.len, decoded_len });
    } else if (std.mem.eql(u8, command, "summary-lz4-block-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const block = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(block);
        const summary = try vort.lz4SummarizeBlock(block);
        try printLz4BlockSummary(stdout, block.len, summary);
    } else if (std.mem.eql(u8, command, "encode-lz4-block-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const payload = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(payload);
        const encoded = try vort.lz4EncodeBlockAlloc(init.gpa, payload);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "decode-lz4-block-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const max_output_len = try parseOptionalLimit(args.next());
        const block = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(block);
        const decoded_len = if (max_output_len) |limit|
            try vort.lz4DecodedBlockSizeLimited(block, limit)
        else
            try vort.lz4DecodedBlockSize(block);
        const decoded = try init.gpa.alloc(u8, decoded_len);
        defer init.gpa.free(decoded);
        const written = try vort.lz4DecodeBlockIntoSlice(block, decoded, decoded_len);
        if (written != decoded_len) return error.SizeMismatch;
        try printDecoded(stdout, "lz4_block", block.len, decoded);
    } else if (std.mem.eql(u8, command, "size-snappy-block-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const max_output_len = try parseOptionalLimit(args.next());
        const block = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(block);
        const decoded_len = if (max_output_len) |limit|
            try vort.snappyDecodedBlockSizeLimited(block, limit)
        else
            try vort.snappyDecodedBlockSize(block);
        try stdout.print("snappy_block_compressed_bytes={d} decoded_bytes={d}\n", .{ block.len, decoded_len });
    } else if (std.mem.eql(u8, command, "summary-snappy-block-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const block = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(block);
        const summary = try vort.snappySummarizeBlock(block);
        try printSnappyBlockSummary(stdout, block.len, summary);
    } else if (std.mem.eql(u8, command, "encode-snappy-block-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const payload = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(payload);
        const encoded = try vort.snappyEncodeBlockAlloc(init.gpa, payload);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "decode-snappy-block-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const max_output_len = try parseOptionalLimit(args.next());
        const block = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(block);
        const decoded_len = if (max_output_len) |limit|
            try vort.snappyDecodedBlockSizeLimited(block, limit)
        else
            try vort.snappyDecodedBlockSize(block);
        const decoded = try init.gpa.alloc(u8, decoded_len);
        defer init.gpa.free(decoded);
        const written = try vort.snappyDecodeBlockInto(block, decoded);
        if (written != decoded_len) return error.SizeMismatch;
        try printDecoded(stdout, "snappy_block", block.len, decoded);
    } else if (std.mem.eql(u8, command, "encode-snappy-block-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const payload = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(payload);
        const encoded = try vort.snappyEncodeBlockAlloc(init.gpa, payload);
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        try stdout.print("snappy_block_compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ encoded.len, payload.len, output_path });
    } else if (std.mem.eql(u8, command, "decode-snappy-block-file-to")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const block = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(block);
        const decoded = if (max_output_len) |limit|
            try vort.snappyDecodeBlockAllocLimited(init.gpa, block, limit)
        else
            try vort.snappyDecodeBlockAlloc(init.gpa, block);
        defer init.gpa.free(decoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
        try stdout.print("snappy_block_compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ block.len, decoded.len, output_path });
    } else if (std.mem.eql(u8, command, "size-snappy-block-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const block = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(block);
        const decoded_len = if (max_output_len) |limit|
            try vort.snappyDecodedBlockSizeLimited(block, limit)
        else
            try vort.snappyDecodedBlockSize(block);
        try stdout.print("snappy_block_compressed_bytes={d} decoded_bytes={d}\n", .{ block.len, decoded_len });
    } else if (std.mem.eql(u8, command, "summary-snappy-block-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const block = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(block);
        const summary = try vort.snappySummarizeBlock(block);
        try printSnappyBlockSummary(stdout, block.len, summary);
    } else if (std.mem.eql(u8, command, "size-snappy-frame-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const max_output_len = try parseOptionalLimit(args.next());
        const frame = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(frame);
        const decoded_len = if (max_output_len) |limit|
            try vort.snappyDecodedFrameSizeLimited(frame, limit)
        else
            try vort.snappyDecodedFrameSize(frame);
        try stdout.print("snappy_frame_compressed_bytes={d} decoded_bytes={d}\n", .{ frame.len, decoded_len });
    } else if (std.mem.eql(u8, command, "summary-snappy-frame-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const frame = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(frame);
        const summary = try vort.snappySummarizeFrame(frame);
        try printSnappyFrameSummary(stdout, frame.len, summary);
    } else if (std.mem.eql(u8, command, "encode-snappy-frame-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const payload = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(payload);
        const encoded = try vort.snappyEncodeFrameAlloc(init.gpa, payload);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "decode-snappy-frame-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const max_output_len = try parseOptionalLimit(args.next());
        const frame = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(frame);
        const decoded_len = if (max_output_len) |limit|
            try vort.snappyDecodedFrameSizeLimited(frame, limit)
        else
            try vort.snappyDecodedFrameSize(frame);
        const decoded = try init.gpa.alloc(u8, decoded_len);
        defer init.gpa.free(decoded);
        const written = try vort.snappyDecodeFrameInto(frame, decoded);
        if (written != decoded_len) return error.SizeMismatch;
        try printDecoded(stdout, "snappy_frame", frame.len, decoded);
    } else if (std.mem.eql(u8, command, "encode-snappy-frame-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const payload = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(payload);
        const encoded = try vort.snappyEncodeFrameAlloc(init.gpa, payload);
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        try stdout.print("snappy_frame_compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ encoded.len, payload.len, output_path });
    } else if (std.mem.eql(u8, command, "decode-snappy-frame-file-to")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const frame = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(frame);
        const decoded = if (max_output_len) |limit|
            try vort.snappyDecodeFrameAllocLimited(init.gpa, frame, limit)
        else
            try vort.snappyDecodeFrameAlloc(init.gpa, frame);
        defer init.gpa.free(decoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
        try stdout.print("snappy_frame_compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ frame.len, decoded.len, output_path });
    } else if (std.mem.eql(u8, command, "size-snappy-frame-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const frame = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(frame);
        const decoded_len = if (max_output_len) |limit|
            try vort.snappyDecodedFrameSizeLimited(frame, limit)
        else
            try vort.snappyDecodedFrameSize(frame);
        try stdout.print("snappy_frame_compressed_bytes={d} decoded_bytes={d}\n", .{ frame.len, decoded_len });
    } else if (std.mem.eql(u8, command, "summary-snappy-frame-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const frame = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(frame);
        const summary = try vort.snappySummarizeFrame(frame);
        try printSnappyFrameSummary(stdout, frame.len, summary);
    } else if (std.mem.eql(u8, command, "size-lz4-block-prefix-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const prefix_hex = args.next() orelse return error.MissingHexInput;
        const max_output_len = try parseOptionalLimit(args.next());
        const block = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(block);
        const prefix = try hexToOwnedBytes(init.gpa, prefix_hex);
        defer init.gpa.free(prefix);
        const decoded_len = if (max_output_len) |limit|
            try vort.lz4DecodedBlockSizeWithPrefixLimited(block, prefix, limit)
        else
            try vort.lz4DecodedBlockSizeWithPrefix(block, prefix);
        try stdout.print("lz4_block_prefix_compressed_bytes={d} prefix_bytes={d} decoded_bytes={d}\n", .{ block.len, prefix.len, decoded_len });
    } else if (std.mem.eql(u8, command, "summary-lz4-block-prefix-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const prefix_hex = args.next() orelse return error.MissingHexInput;
        const block = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(block);
        const prefix = try hexToOwnedBytes(init.gpa, prefix_hex);
        defer init.gpa.free(prefix);
        const summary = try vort.lz4SummarizeBlockWithPrefix(block, prefix);
        try printLz4BlockSummary(stdout, block.len, summary);
    } else if (std.mem.eql(u8, command, "encode-lz4-block-prefix-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const prefix_hex = args.next() orelse return error.MissingHexInput;
        const payload = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(payload);
        const prefix = try hexToOwnedBytes(init.gpa, prefix_hex);
        defer init.gpa.free(prefix);
        const encoded = try vort.lz4EncodeBlockWithPrefixAlloc(init.gpa, payload, prefix);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "decode-lz4-block-prefix-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const prefix_hex = args.next() orelse return error.MissingHexInput;
        const max_output_len = try parseOptionalLimit(args.next());
        const block = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(block);
        const prefix = try hexToOwnedBytes(init.gpa, prefix_hex);
        defer init.gpa.free(prefix);
        const decoded_len = if (max_output_len) |limit|
            try vort.lz4DecodedBlockSizeWithPrefixLimited(block, prefix, limit)
        else
            try vort.lz4DecodedBlockSizeWithPrefix(block, prefix);
        const decoded = try init.gpa.alloc(u8, decoded_len);
        defer init.gpa.free(decoded);
        const written = try vort.lz4DecodeBlockWithPrefixIntoSliceNoAlloc(block, decoded, decoded_len, prefix);
        if (written != decoded_len) return error.SizeMismatch;
        try printDecoded(stdout, "lz4_block_prefix", block.len, decoded);
    } else if (std.mem.eql(u8, command, "encode-raw-best-file-hex")) {
        const path = args.next() orelse return error.MissingCorpusPath;
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawBestAlloc(init.gpa, data, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-zlib-best-file-hex")) {
        const path = args.next() orelse return error.MissingCorpusPath;
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibBestAlloc(init.gpa, data, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-gzip-best-file-hex")) {
        const path = args.next() orelse return error.MissingCorpusPath;
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeGzipBestAlloc(init.gpa, data, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-vort-best-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const encoded = try vort.storeEncodeBestAlloc(init.gpa, data);
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        try stdout.print("input_bytes={d} output_bytes={d} path={s}\n", .{ data.len, encoded.len, output_path });
    } else if (std.mem.eql(u8, command, "encode-raw-fixed-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawFixedWithOptionsAlloc(init.gpa, data, options);
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        try stdout.print("input_bytes={d} output_bytes={d} path={s}\n", .{ data.len, encoded.len, output_path });
    } else if (std.mem.eql(u8, command, "encode-zlib-best-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibBestAlloc(init.gpa, data, options);
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        try stdout.print("input_bytes={d} output_bytes={d} path={s}\n", .{ data.len, encoded.len, output_path });
    } else if (std.mem.eql(u8, command, "encode-raw-best-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawBestAlloc(init.gpa, data, options);
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        try stdout.print("input_bytes={d} output_bytes={d} path={s}\n", .{ data.len, encoded.len, output_path });
    } else if (std.mem.eql(u8, command, "encode-gzip-best-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeGzipBestAlloc(init.gpa, data, options);
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        try stdout.print("input_bytes={d} output_bytes={d} path={s}\n", .{ data.len, encoded.len, output_path });
    } else if (std.mem.eql(u8, command, "encode-raw-dict-best-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const dictionary_path = args.next() orelse return error.MissingCorpusPath;
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const dictionary = try std.Io.Dir.cwd().readFileAlloc(init.io, dictionary_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(dictionary);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawBestWithDictionaryAlloc(init.gpa, data, dictionary, options);
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        try stdout.print("input_bytes={d} dictionary_bytes={d} output_bytes={d} path={s}\n", .{ data.len, dictionary.len, encoded.len, output_path });
    } else if (std.mem.eql(u8, command, "encode-raw-dict-best-split-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const dictionary_path = args.next() orelse return error.MissingCorpusPath;
        const block_len = try parseBlockLen(args.next(), 7);
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const dictionary = try std.Io.Dir.cwd().readFileAlloc(init.io, dictionary_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(dictionary);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawBestSplitWithDictionaryAlloc(init.gpa, data, dictionary, block_len, options);
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        try stdout.print("input_bytes={d} dictionary_bytes={d} block_len={d} output_bytes={d} path={s}\n", .{ data.len, dictionary.len, block_len, encoded.len, output_path });
    } else if (std.mem.eql(u8, command, "encode-raw-dict-best-adaptive-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const dictionary_path = args.next() orelse return error.MissingCorpusPath;
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const dictionary = try std.Io.Dir.cwd().readFileAlloc(init.io, dictionary_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(dictionary);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawBestAdaptiveSplitWithDictionaryAlloc(init.gpa, data, dictionary, options, options.split_options);
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        try stdout.print("input_bytes={d} dictionary_bytes={d} output_bytes={d} path={s}\n", .{ data.len, dictionary.len, encoded.len, output_path });
    } else if (std.mem.eql(u8, command, "encode-zlib-dict-best-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const dictionary_path = args.next() orelse return error.MissingCorpusPath;
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const dictionary = try std.Io.Dir.cwd().readFileAlloc(init.io, dictionary_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(dictionary);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibBestWithDictionaryAlloc(init.gpa, data, dictionary, options);
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        try stdout.print("input_bytes={d} dictionary_bytes={d} output_bytes={d} path={s}\n", .{ data.len, dictionary.len, encoded.len, output_path });
    } else if (std.mem.eql(u8, command, "encode-zlib-dict-best-split-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const dictionary_path = args.next() orelse return error.MissingCorpusPath;
        const block_len = try parseBlockLen(args.next(), 7);
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const dictionary = try std.Io.Dir.cwd().readFileAlloc(init.io, dictionary_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(dictionary);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibBestSplitWithDictionaryAlloc(init.gpa, data, dictionary, block_len, options);
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        try stdout.print("input_bytes={d} dictionary_bytes={d} block_len={d} output_bytes={d} path={s}\n", .{ data.len, dictionary.len, block_len, encoded.len, output_path });
    } else if (std.mem.eql(u8, command, "encode-zlib-dict-best-adaptive-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const dictionary_path = args.next() orelse return error.MissingCorpusPath;
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const dictionary = try std.Io.Dir.cwd().readFileAlloc(init.io, dictionary_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(dictionary);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibBestAdaptiveSplitWithDictionaryAlloc(init.gpa, data, dictionary, options, options.split_options);
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        try stdout.print("input_bytes={d} dictionary_bytes={d} output_bytes={d} path={s}\n", .{ data.len, dictionary.len, encoded.len, output_path });
    } else if (std.mem.eql(u8, command, "encode-vort-sidecar-best-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const stream_path = args.next() orelse return error.MissingCorpusPath;
        const sidecar_path = args.next() orelse return error.MissingCorpusPath;
        const block_len = try parseBlockLen(args.next(), 8192);
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const sidecar = try vort.storeEncodeSidecarBlockedBestStreamAlloc(init.gpa, data, block_len);
        defer sidecar.deinit(init.gpa);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = stream_path, .data = sidecar.stream });
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = sidecar_path, .data = sidecar.sidecar_index });
        try stdout.print("input_bytes={d} stream_bytes={d} sidecar_bytes={d} stream={s} sidecar={s}\n", .{ data.len, sidecar.stream.len, sidecar.sidecar_index.len, stream_path, sidecar_path });
    } else if (std.mem.eql(u8, command, "encode-vort-embedded-best-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const stream_path = args.next() orelse return error.MissingCorpusPath;
        const block_len = try parseBlockLen(args.next(), 8192);
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const stream = try vort.storeEncodeBlockedBestStreamAlloc(init.gpa, data, block_len);
        defer init.gpa.free(stream);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = stream_path, .data = stream });
        try stdout.print("input_bytes={d} stream_bytes={d} embedded_index=true stream={s}\n", .{ data.len, stream.len, stream_path });
    } else if (std.mem.eql(u8, command, "encode-vort-seekable-tier-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const stream_path = args.next() orelse return error.MissingCorpusPath;
        const tier = try parseSeekabilityTier(args.next());
        const options = vort.SeekableNativeOptions.withSeekabilityTier(tier);
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const stream = try vort.storeEncodeSeekableNativeStreamAlloc(init.gpa, data, options);
        defer init.gpa.free(stream);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = stream_path, .data = stream });
        try stdout.print("input_bytes={d} stream_bytes={d} embedded_index=true seekability_tier={s} block_len={d} stream={s}\n", .{ data.len, stream.len, @tagName(tier), options.block_len, stream_path });
    } else if (std.mem.eql(u8, command, "encode-vort-blocked-best-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const stream_path = args.next() orelse return error.MissingCorpusPath;
        const block_len = try parseBlockLen(args.next(), 8192);
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const sidecar = try vort.storeEncodeSidecarBlockedBestStreamAlloc(init.gpa, data, block_len);
        defer sidecar.deinit(init.gpa);
        // zstd_compare uses this command to isolate block-fragmentation bytes:
        // write only the concatenated data frames, not the sidecar index payload.
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = stream_path, .data = sidecar.stream });
        try stdout.print("input_bytes={d} stream_bytes={d} sidecar_bytes={d} embedded_index=false stream={s}\n", .{ data.len, sidecar.stream.len, sidecar.sidecar_index.len, stream_path });
    } else if (std.mem.eql(u8, command, "encode-vort-embedded-dict-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const stream_path = args.next() orelse return error.MissingCorpusPath;
        const block_len = try parseBlockLen(args.next(), 8192);
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const stream = try vort.storeEncodeSelfContainedDictionaryStreamAlloc(init.gpa, data, block_len, 256, 8);
        defer init.gpa.free(stream);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = stream_path, .data = stream });
        try stdout.print("input_bytes={d} stream_bytes={d} embedded_index=true embedded_dictionary=true stream={s}\n", .{ data.len, stream.len, stream_path });
    } else if (std.mem.eql(u8, command, "verify-vort-sidecar-index-file")) {
        const stream_path = args.next() orelse return error.MissingCorpusPath;
        const sidecar_path = args.next() orelse return error.MissingCorpusPath;
        const validation_mode = try parseSidecarValidationMode(args.next());
        const output_format = try parseValidationOutputFormat(args.next());
        const stream = try std.Io.Dir.cwd().readFileAlloc(init.io, stream_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(stream);
        const sidecar = try std.Io.Dir.cwd().readFileAlloc(init.io, sidecar_path, init.gpa, .limited(16 * 1024 * 1024));
        defer init.gpa.free(sidecar);
        const report = vort.storeValidateSidecarIndexReportAlloc(init.gpa, stream, sidecar, .{ .mode = validation_mode });
        if (!report.ok) {
            if (output_format == .json) {
                try printValidationJson(stdout, "sidecar", report, stream.len, sidecar.len);
            } else {
                try printValidationFailure(stdout, "sidecar", report);
            }
            try stdout.flush();
            return error.CorruptFrame;
        }
        if (output_format == .json) {
            try printValidationJson(stdout, "sidecar", report, stream.len, sidecar.len);
        } else {
            try stdout.print("sidecar_ok=true mode={s} stream_bytes={d} sidecar_bytes={d}\n", .{ @tagName(validation_mode), stream.len, sidecar.len });
        }
    } else if (std.mem.eql(u8, command, "verify-vort-embedded-index-file")) {
        const stream_path = args.next() orelse return error.MissingCorpusPath;
        const validation_mode = try parseSidecarValidationMode(args.next());
        const output_format = try parseValidationOutputFormat(args.next());
        const stream = try std.Io.Dir.cwd().readFileAlloc(init.io, stream_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(stream);
        const report = vort.storeValidateEmbeddedIndexReportAlloc(init.gpa, stream, .{ .mode = validation_mode });
        if (!report.ok) {
            if (output_format == .json) {
                try printValidationJson(stdout, "embedded", report, stream.len, null);
            } else {
                try printValidationFailure(stdout, "embedded", report);
            }
            try stdout.flush();
            return error.CorruptFrame;
        }
        if (output_format == .json) {
            try printValidationJson(stdout, "embedded", report, stream.len, null);
        } else {
            try stdout.print("embedded_index_ok=true mode={s} stream_bytes={d}\n", .{ @tagName(validation_mode), stream.len });
        }
    } else if (std.mem.eql(u8, command, "decode-vort-sidecar-range-file")) {
        const stream_path = args.next() orelse return error.MissingCorpusPath;
        const sidecar_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const offset = try std.fmt.parseInt(u64, args.next() orelse return error.MissingCorpusPath, 10);
        const length = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
        const stream = try std.Io.Dir.cwd().readFileAlloc(init.io, stream_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(stream);
        const sidecar = try std.Io.Dir.cwd().readFileAlloc(init.io, sidecar_path, init.gpa, .limited(16 * 1024 * 1024));
        defer init.gpa.free(sidecar);
        const range = try vort.storeDecodeSidecarIndexedRangeAlloc(init.gpa, stream, sidecar, offset, length);
        defer init.gpa.free(range);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = range });
        try stdout.print("range_bytes={d} crc32={d} path={s}\n", .{ range.len, vort.crc32(range), output_path });
    } else if (std.mem.eql(u8, command, "decode-vort-embedded-range-file")) {
        const stream_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const offset = try std.fmt.parseInt(u64, args.next() orelse return error.MissingCorpusPath, 10);
        const length = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
        const stream = try std.Io.Dir.cwd().readFileAlloc(init.io, stream_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(stream);
        const range = try vort.storeDecodeIndexedRangeAlloc(init.gpa, stream, offset, length);
        defer init.gpa.free(range);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = range });
        try stdout.print("range_bytes={d} crc32={d} path={s}\n", .{ range.len, vort.crc32(range), output_path });
    } else if (std.mem.eql(u8, command, "bench-decode-raw-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const expected_output_len = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
        const iterations = try parseIterations(args.next(), 3);
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const output = try init.gpa.alloc(u8, expected_output_len);
        defer init.gpa.free(output);
        const result = try benchDecodeRaw(compressed, output, iterations, init.io);
        try stdout.print("mode=raw compressed_bytes={d} decoded_bytes={d} iterations={d} elapsed_ns={d} checksum={d}\n", .{ compressed.len, result.decoded_bytes, iterations, result.elapsed_ns, result.checksum });
    } else if (std.mem.eql(u8, command, "bench-decode-vort-best-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const expected_output_len = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
        const iterations = try parseIterations(args.next(), 3);
        const frame = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(frame);
        const output = try init.gpa.alloc(u8, expected_output_len);
        defer init.gpa.free(output);
        const result = try benchDecodeVortBest(frame, output, iterations, init.io);
        try stdout.print("mode=vort_best compressed_bytes={d} decoded_bytes={d} iterations={d} elapsed_ns={d} checksum={d}\n", .{ frame.len, result.decoded_bytes, iterations, result.elapsed_ns, result.checksum });
    } else if (std.mem.eql(u8, command, "bench-decode-vort-embedded-range-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const length = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
        const iterations = try parseIterations(args.next(), 3);
        const stream = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(stream);
        const output = try init.gpa.alloc(u8, length);
        defer init.gpa.free(output);
        const result = try benchDecodeVortEmbeddedRange(init.gpa, stream, 0, output, iterations, init.io);
        try stdout.print("mode=vort_embedded compressed_bytes={d} decoded_bytes={d} iterations={d} elapsed_ns={d} checksum={d}\n", .{ stream.len, result.decoded_bytes, iterations, result.elapsed_ns, result.checksum });
    } else if (std.mem.eql(u8, command, "bench-decode-vort-embedded-offset-range-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const offset = try std.fmt.parseInt(u64, args.next() orelse return error.MissingCorpusPath, 10);
        const length = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
        const iterations = try parseIterations(args.next(), 3);
        const stream = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(stream);
        const output = try init.gpa.alloc(u8, length);
        defer init.gpa.free(output);
        const result = try benchDecodeVortEmbeddedRange(init.gpa, stream, offset, output, iterations, init.io);
        try stdout.print("mode=vort_embedded_range offset={d} compressed_bytes={d} decoded_bytes={d} iterations={d} elapsed_ns={d} checksum={d}\n", .{ offset, stream.len, result.decoded_bytes, iterations, result.elapsed_ns, result.checksum });
    } else if (std.mem.eql(u8, command, "decode-vort-embedded-auto-range-file")) {
        const stream_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const offset = try std.fmt.parseInt(u64, args.next() orelse return error.MissingCorpusPath, 10);
        const length = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
        const stream = try std.Io.Dir.cwd().readFileAlloc(init.io, stream_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(stream);
        const range = try vort.storeDecodeIndexedRangeAutoAlloc(init.gpa, stream, offset, length);
        defer init.gpa.free(range);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = range });
        try stdout.print("range_bytes={d} crc32={d} path={s}\n", .{ range.len, vort.crc32(range), output_path });
    } else if (std.mem.eql(u8, command, "encode-vort-sidecar-dict-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const stream_path = args.next() orelse return error.MissingCorpusPath;
        const sidecar_path = args.next() orelse return error.MissingCorpusPath;
        const block_len = try parseBlockLen(args.next(), 8192);
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const sidecar = try vort.storeEncodeSidecarSelfContainedDictionaryStreamAlloc(init.gpa, data, block_len, 256, 8);
        defer sidecar.deinit(init.gpa);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = stream_path, .data = sidecar.stream });
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = sidecar_path, .data = sidecar.sidecar_index });
        try stdout.print("input_bytes={d} stream_bytes={d} sidecar_bytes={d} stream={s} sidecar={s}\n", .{ data.len, sidecar.stream.len, sidecar.sidecar_index.len, stream_path, sidecar_path });
    } else if (std.mem.eql(u8, command, "decode-vort-sidecar-auto-range-file")) {
        const stream_path = args.next() orelse return error.MissingCorpusPath;
        const sidecar_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const offset = try std.fmt.parseInt(u64, args.next() orelse return error.MissingCorpusPath, 10);
        const length = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
        const stream = try std.Io.Dir.cwd().readFileAlloc(init.io, stream_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(stream);
        const sidecar = try std.Io.Dir.cwd().readFileAlloc(init.io, sidecar_path, init.gpa, .limited(16 * 1024 * 1024));
        defer init.gpa.free(sidecar);
        const range = try vort.storeDecodeSidecarIndexedRangeAutoAlloc(init.gpa, stream, sidecar, offset, length);
        defer init.gpa.free(range);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = range });
        try stdout.print("range_bytes={d} crc32={d} path={s}\n", .{ range.len, vort.crc32(range), output_path });
    } else if (std.mem.eql(u8, command, "encode-vort-sidecar-ldm-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const stream_path = args.next() orelse return error.MissingCorpusPath;
        const sidecar_path = args.next() orelse return error.MissingCorpusPath;
        const block_len = try parseBlockLen(args.next(), 8192);
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const sidecar = try vort.storeEncodeSidecarBlockedBestStreamWithLdmAlloc(init.gpa, data, block_len, .{}, .{ .min_distance = 32769, .min_length = 16 });
        defer sidecar.deinit(init.gpa);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = stream_path, .data = sidecar.stream });
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = sidecar_path, .data = sidecar.sidecar_index });
        try stdout.print("input_bytes={d} stream_bytes={d} sidecar_bytes={d} stream={s} sidecar={s}\n", .{ data.len, sidecar.stream.len, sidecar.sidecar_index.len, stream_path, sidecar_path });
    } else if (std.mem.eql(u8, command, "decode-raw-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.decodeRawDeflateAllocLimited(init.gpa, compressed, limit)
        else
            try vort.decodeRawDeflateAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try printDecoded(stdout, "raw", compressed.len, decoded);
    } else if (std.mem.eql(u8, command, "decode-raw-dict-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const dictionary = args.next() orelse "";
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.decodeRawDeflateAllocWithDictionaryLimited(init.gpa, compressed, dictionary, limit)
        else
            try vort.decodeRawDeflateAllocWithDictionary(init.gpa, compressed, dictionary);
        defer init.gpa.free(decoded);
        try printDecoded(stdout, "raw_dict", compressed.len, decoded);
    } else if (std.mem.eql(u8, command, "decode-raw-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.decodeRawDeflateAllocLimited(init.gpa, compressed, limit)
        else
            try vort.decodeRawDeflateAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
        try stdout.print("compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ compressed.len, decoded.len, output_path });
    } else if (std.mem.eql(u8, command, "decode-raw-dict-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const dictionary_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const dictionary = try std.Io.Dir.cwd().readFileAlloc(init.io, dictionary_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(dictionary);
        const decoded = if (max_output_len) |limit|
            try vort.decodeRawDeflateAllocWithDictionaryLimited(init.gpa, compressed, dictionary, limit)
        else
            try vort.decodeRawDeflateAllocWithDictionary(init.gpa, compressed, dictionary);
        defer init.gpa.free(decoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
        try stdout.print("compressed_bytes={d} dictionary_bytes={d} decoded_bytes={d} path={s}\n", .{ compressed.len, dictionary.len, decoded.len, output_path });
    } else if (std.mem.eql(u8, command, "inspect-raw-header-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_format = try parseHeaderInspectOutputFormat(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const info = try vort.parseRawDeflateHeaderInfo(compressed);
        try printRawHeaderInfo(stdout, compressed.len, info, output_format);
    } else if (std.mem.eql(u8, command, "decode-zlib-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.decodeZlibAllocLimited(init.gpa, compressed, limit)
        else
            try vort.decodeZlibAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
        try stdout.print("compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ compressed.len, decoded.len, output_path });
    } else if (std.mem.eql(u8, command, "decode-zlib-concat-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.decodeZlibConcatenatedAllocLimited(init.gpa, compressed, limit)
        else
            try vort.decodeZlibConcatenatedAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
        try stdout.print("compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ compressed.len, decoded.len, output_path });
    } else if (std.mem.eql(u8, command, "decode-zlib-dict-concat-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const dictionary_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const dictionary = try std.Io.Dir.cwd().readFileAlloc(init.io, dictionary_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(dictionary);
        const decoded = if (max_output_len) |limit|
            try vort.decodeZlibConcatenatedAllocWithDictionaryLimited(init.gpa, compressed, dictionary, limit)
        else
            try vort.decodeZlibConcatenatedAllocWithDictionary(init.gpa, compressed, dictionary);
        defer init.gpa.free(decoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
        try stdout.print("compressed_bytes={d} dictionary_bytes={d} decoded_bytes={d} path={s}\n", .{ compressed.len, dictionary.len, decoded.len, output_path });
    } else if (std.mem.eql(u8, command, "inspect-zlib-header-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_format = try parseHeaderInspectOutputFormat(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const info = try vort.parseZlibHeaderInfo(compressed);
        try printZlibHeaderInfo(stdout, compressed.len, info, output_format);
    } else if (std.mem.eql(u8, command, "inspect-zlib-deflate-header-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_format = try parseHeaderInspectOutputFormat(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const wrapper = try vort.parseZlibHeaderInfo(compressed);
        const info = try vort.parseRawDeflateHeaderInfo(compressed[wrapper.data_offset..]);
        if (output_format == .json) {
            const stream = try inspectZlibStreamForWrappedJson(init.gpa, compressed);
            try printWrappedDeflateHeaderJson(stdout, zlibWrappedDeflateContext(compressed.len, wrapper.data_offset, stream), info);
        } else {
            try printRawHeaderInfo(stdout, compressed.len - wrapper.data_offset, info, output_format);
        }
    } else if (std.mem.eql(u8, command, "inspect-zlib-dict-deflate-header-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const dictionary_path = args.next() orelse return error.MissingCorpusPath;
        const output_format = try parseHeaderInspectOutputFormat(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const dictionary = try std.Io.Dir.cwd().readFileAlloc(init.io, dictionary_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(dictionary);
        const wrapper = try vort.parseZlibHeaderInfo(compressed);
        const info = try vort.parseRawDeflateHeaderInfo(compressed[wrapper.data_offset..]);
        const stream = try vort.inspectZlibStreamAllocWithDictionary(init.gpa, compressed, dictionary);
        if (output_format == .json) {
            try printWrappedDeflateHeaderJson(stdout, zlibWrappedDeflateContext(compressed.len, wrapper.data_offset, stream), info);
        } else {
            try printRawHeaderInfo(stdout, compressed.len - wrapper.data_offset, info, output_format);
        }
    } else if (std.mem.eql(u8, command, "decode-zlib-dict-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const dictionary_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const dictionary = try std.Io.Dir.cwd().readFileAlloc(init.io, dictionary_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(dictionary);
        const decoded = if (max_output_len) |limit|
            try vort.decodeZlibAllocWithDictionaryLimited(init.gpa, compressed, dictionary, limit)
        else
            try vort.decodeZlibAllocWithDictionary(init.gpa, compressed, dictionary);
        defer init.gpa.free(decoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
        try stdout.print("compressed_bytes={d} dictionary_bytes={d} decoded_bytes={d} path={s}\n", .{ compressed.len, dictionary.len, decoded.len, output_path });
    } else if (std.mem.eql(u8, command, "decode-gzip-file") or std.mem.eql(u8, command, "decode-gzip-concat-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.decodeGzipConcatenatedAllocLimited(init.gpa, compressed, limit)
        else
            try vort.decodeGzipConcatenatedAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
        try stdout.print("compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ compressed.len, decoded.len, output_path });
    } else if (std.mem.eql(u8, command, "inspect-gzip-header-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_format = try parseHeaderInspectOutputFormat(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const info = try vort.parseGzipHeaderInfo(compressed);
        try printGzipHeaderInfo(stdout, compressed.len, info, output_format);
    } else if (std.mem.eql(u8, command, "inspect-gzip-deflate-header-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_format = try parseHeaderInspectOutputFormat(args.next());
        const member_index = try parseOptionalMemberIndex(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const member = try vort.inspectGzipMemberAlloc(init.gpa, compressed, member_index);
        const info = try vort.parseRawDeflateHeaderInfo(compressed[member.deflate_offset..]);
        if (output_format == .json)
            try printWrappedDeflateHeaderJson(stdout, gzipWrappedDeflateContext(compressed.len, member), info)
        else
            try printRawHeaderInfo(stdout, compressed.len - member.deflate_offset, info, output_format);
    } else if (std.mem.eql(u8, command, "decode-zlib-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.decodeZlibAllocLimited(init.gpa, compressed, limit)
        else
            try vort.decodeZlibAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try printDecoded(stdout, "zlib", compressed.len, decoded);
    } else if (std.mem.eql(u8, command, "decode-zlib-concat-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.decodeZlibConcatenatedAllocLimited(init.gpa, compressed, limit)
        else
            try vort.decodeZlibConcatenatedAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try printDecoded(stdout, "zlib_concat", compressed.len, decoded);
    } else if (std.mem.eql(u8, command, "decode-zlib-dict-concat-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const dictionary = args.next() orelse "";
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.decodeZlibConcatenatedAllocWithDictionaryLimited(init.gpa, compressed, dictionary, limit)
        else
            try vort.decodeZlibConcatenatedAllocWithDictionary(init.gpa, compressed, dictionary);
        defer init.gpa.free(decoded);
        try printDecoded(stdout, "zlib_dict_concat", compressed.len, decoded);
    } else if (std.mem.eql(u8, command, "inspect-raw-header-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const output_format = try parseHeaderInspectOutputFormat(args.next());
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const info = try vort.parseRawDeflateHeaderInfo(compressed);
        try printRawHeaderInfo(stdout, compressed.len, info, output_format);
    } else if (std.mem.eql(u8, command, "inspect-zlib-header-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const output_format = try parseHeaderInspectOutputFormat(args.next());
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const info = try vort.parseZlibHeaderInfo(compressed);
        try printZlibHeaderInfo(stdout, compressed.len, info, output_format);
    } else if (std.mem.eql(u8, command, "inspect-zlib-deflate-header-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const output_format = try parseHeaderInspectOutputFormat(args.next());
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const wrapper = try vort.parseZlibHeaderInfo(compressed);
        const info = try vort.parseRawDeflateHeaderInfo(compressed[wrapper.data_offset..]);
        if (output_format == .json) {
            const stream = try inspectZlibStreamForWrappedJson(init.gpa, compressed);
            try printWrappedDeflateHeaderJson(stdout, zlibWrappedDeflateContext(compressed.len, wrapper.data_offset, stream), info);
        } else {
            try printRawHeaderInfo(stdout, compressed.len - wrapper.data_offset, info, output_format);
        }
    } else if (std.mem.eql(u8, command, "inspect-zlib-dict-deflate-header-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const dictionary = args.next() orelse return error.MissingCorpusPath;
        const output_format = try parseHeaderInspectOutputFormat(args.next());
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const wrapper = try vort.parseZlibHeaderInfo(compressed);
        const info = try vort.parseRawDeflateHeaderInfo(compressed[wrapper.data_offset..]);
        const stream = try vort.inspectZlibStreamAllocWithDictionary(init.gpa, compressed, dictionary);
        if (output_format == .json) {
            try printWrappedDeflateHeaderJson(stdout, zlibWrappedDeflateContext(compressed.len, wrapper.data_offset, stream), info);
        } else {
            try printRawHeaderInfo(stdout, compressed.len - wrapper.data_offset, info, output_format);
        }
    } else if (std.mem.eql(u8, command, "decode-zlib-dict-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const dictionary = args.next() orelse "";
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.decodeZlibAllocWithDictionaryLimited(init.gpa, compressed, dictionary, limit)
        else
            try vort.decodeZlibAllocWithDictionary(init.gpa, compressed, dictionary);
        defer init.gpa.free(decoded);
        try printDecoded(stdout, "zlib_dict", compressed.len, decoded);
    } else if (std.mem.eql(u8, command, "decode-gzip-hex") or std.mem.eql(u8, command, "decode-gzip-concat-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.decodeGzipConcatenatedAllocLimited(init.gpa, compressed, limit)
        else
            try vort.decodeGzipConcatenatedAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try printDecoded(stdout, "gzip", compressed.len, decoded);
    } else if (std.mem.eql(u8, command, "inspect-gzip-header-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const output_format = try parseHeaderInspectOutputFormat(args.next());
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const info = try vort.parseGzipHeaderInfo(compressed);
        try printGzipHeaderInfo(stdout, compressed.len, info, output_format);
    } else if (std.mem.eql(u8, command, "inspect-gzip-deflate-header-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const output_format = try parseHeaderInspectOutputFormat(args.next());
        const member_index = try parseOptionalMemberIndex(args.next());
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const member = try vort.inspectGzipMemberAlloc(init.gpa, compressed, member_index);
        const info = try vort.parseRawDeflateHeaderInfo(compressed[member.deflate_offset..]);
        if (output_format == .json)
            try printWrappedDeflateHeaderJson(stdout, gzipWrappedDeflateContext(compressed.len, member), info)
        else
            try printRawHeaderInfo(stdout, compressed.len - member.deflate_offset, info, output_format);
    } else {
        try stdout.print("unknown command: {s}\n\n", .{command});
        try printHelp(stdout);
    }

    try stdout.flush();
}

fn printHelp(stdout: *std.Io.Writer) !void {
    try stdout.print(
        \\vort bootstrap CLI
        \\
        \\basics:
        \\  help | --help              Show this message
        \\  checksum [text]            Print Adler-32, CRC-32, and CRC-32C for text
        \\  checksum-file [path]       Print Adler-32, CRC-32, and CRC-32C for a file
        \\  store-roundtrip [text]     Encode/decode the native store frame
        \\
        \\compatibility formats:
        \\  zlib-store-roundtrip [text] Encode/decode zlib-wrapped stored deflate
        \\  gzip-store-roundtrip [text] Encode/decode gzip-wrapped stored deflate
        \\  encode-xerial-snappy-file <in> <out> [block_size]
        \\  encode-xerial-snappy-incremental-file <in> <out> [block_size] [input_step] [output_step]
        \\  decode-xerial-snappy-file <in> <out> [max_output]
        \\  decode-xerial-snappy-incremental-file <in> <out> <expected_output> [input_step] [output_step]
        \\  inspect-xerial-snappy-file <path>
        \\  encode-hadoop-snappy-file <in> <out> [block_size] [chunk_size]
        \\  encode-hadoop-snappy-incremental-file <in> <out> [block_size] [chunk_size] [input_step] [output_step]
        \\  decode-hadoop-snappy-file <in> <out> [max_output]
        \\  decode-hadoop-snappy-incremental-file <in> <out> <expected_output> [input_step] [output_step]
        \\  inspect-hadoop-snappy-file <path>
        \\  encode-hadoop-lz4-file <in> <out> [block_size] [chunk_size]
        \\  encode-hadoop-lz4-incremental-file <in> <out> [block_size] [chunk_size] [input_step] [output_step]
        \\  decode-hadoop-lz4-file <in> <out> [max_output]
        \\  decode-hadoop-lz4-incremental-file <in> <out> <expected_output> [input_step] [output_step]
        \\  inspect-hadoop-lz4-file <path>
        \\  create-hadoop-lzo-index <input.lzo> [output.lzo.index]
        \\  inspect-hadoop-lzo-index <input.lzo> <input.lzo.index>
        \\  extract-hadoop-lzo-blocks <input.lzo> <index> <out> <first> <count> [max_output]
        \\  encode-lz4-legacy-file <in> <out> [block_size]
        \\  decode-lz4-legacy-file <in> <out> [max_output]
        \\  inspect-lz4-legacy-file <path> [max_output]
        \\  encode-lznt1-file <in> <out> [marker|no-marker]
        \\  decode-lznt1-file <in> <out> [max_output]
        \\  inspect-lznt1-file <path> [max_output]
        \\  encode-xpress-plain-file <in> <out>
        \\  decode-xpress-plain-file <in> <out> [max_output]
        \\  inspect-xpress-plain-file <path> [max_output]
        \\  encode-xpress-huffman-file <in> <out>
        \\  decode-xpress-huffman-file <in> <out> <decoded_size>
        \\  inspect-xpress-huffman-file <path> <decoded_size>
        \\  encode-lzms-file <in> <out>
        \\  decode-lzms-file <in> <out> <decoded_size>
        \\  encode-wof-file <in> <out> <xpress4k|xpress8k|xpress16k|lzx>
        \\  decode-wof-file <in> <out> <algorithm> <decoded_size> [max_output]
        \\  decode-wof-range <in> <out> <algorithm> <decoded_size> <offset> <length>
        \\  inspect-wof-file <in> <algorithm> <decoded_size>
        \\  encode-lzfse-file <in> <out> [block_size] [lzvn|stored]
        \\  decode-lzfse-file <in> <out> [max_output]
        \\  inspect-lzfse-file <path> [max_output]
        \\  inspect-decmpfs <xattr> [resource|-]
        \\  decode-decmpfs <xattr> <resource|-> <out> [max_output]
        \\  decode-decmpfs-range <xattr> <resource|-> <out> <offset> <length>
        \\  inspect-dmg <path>
        \\  decode-dmg-partition <in> <out> <partition> [max_output]
        \\  decode-dmg-range <in> <out> <partition> <offset> <length>
        \\  encode-dmg <in> <out> <copy|adc|zlib|bzip2|lzfse|xz> [block_size] [fallback|always]
        \\  inspect-pbzx <path>
        \\  decode-pbzx <in> <out> [max_output]
        \\  decode-pbzx-range <in> <out> <offset> <length>
        \\  encode-pbzx <in> <out> <auto|xz|stored> [chunk_size]
        \\  inspect-xar <path>
        \\  extract-xar-entry <in> <out> <archive_path> [max_output]
        \\  encode-xar-file <in> <out> <archive_path> <auto|copy|zlib|bzip2|lzma|xz> [none|sha1|md5|sha256|sha512]
        \\  inspect-zfs-block <in> <algorithm>
        \\  decode-zfs-block <in> <out> <algorithm> <decoded_size>
        \\  encode-zfs-block <in> <out> <algorithm> [zstd_level]
        \\  inspect-qcow2 <path>
        \\  decode-qcow2 <in> <out> [max_output] [backing|-] [data_file|-]
        \\  decode-qcow2-range <in> <out> <offset> <length> [backing|-] [data_file|-]
        \\  encode-qcow2 <in> <out> <none|zlib|zstd> [cluster_bits] [version]
        \\  inspect-vmdk <path>
        \\  decode-vmdk <in> <out> [max_output] [logical_backing|-]
        \\  decode-vmdk-range <in> <out> <offset> <length> [logical_backing|-]
        \\  encode-vmdk <in> <out> <none|zlib> [grain_sectors]
        \\  inspect-ewf <segment> [additional_segments...]
        \\  decode-ewf <first_segment> <out> [max_output] [additional_segments...]
        \\  decode-ewf-range <first_segment> <out> <offset> <length> [additional_segments...]
        \\  encode-ewf <in> <out> <none|zlib|auto> [sectors_per_chunk]
        \\  inspect-chd <image.chd> [parent.chd]
        \\  decode-chd <image.chd> <out> [max_output] [parent.chd]
        \\  decode-chd-range <image.chd> <out> <offset> <length> [parent.chd]
        \\  encode-chd <in> <out> <none|zlib|lzma|huffman|zstd|auto> [hunk_bytes] [unit_bytes] [level] [parent.chd|-] [TAG=value...]
        \\  inspect-vhd <image.vhd> [parent.vhd]
        \\  decode-vhd <image.vhd> <out> [max_output] [parent.vhd]
        \\  decode-vhd-range <image.vhd> <out> <offset> <length> [parent.vhd]
        \\  encode-vhd <in> <out> <fixed|dynamic|differencing> [block_size] [parent.vhd]
        \\  inspect-vhdx <image.vhdx> [parent.vhdx]
        \\  decode-vhdx <image.vhdx> <out> [max_output] [parent.vhdx]
        \\  decode-vhdx-range <image.vhdx> <out> <offset> <length> [parent.vhdx]
        \\  encode-vhdx <in> <out> <dynamic|fixed|differencing> [block_size] [parent.vhdx]
        \\  inspect-cso <image.cso|image.zso>
        \\  decode-cso <in> <out> [max_output]
        \\  decode-cso-range <in> <out> <offset> <length>
        \\  encode-cso <in> <out> <cso1|cso2|zso> [auto|raw|deflate|lz4] [block_size] [level] [index_shift]
        \\  inspect-dax <image.dax>
        \\  decode-dax <in> <out> [max_output]
        \\  decode-dax-range <in> <out> <offset> <length>
        \\  encode-dax <in> <out> [auto|raw|zlib] [level]
        \\  inspect-gcz <image.gcz>
        \\  decode-gcz <in> <out> [max_output]
        \\  decode-gcz-range <in> <out> <offset> <length>
        \\  encode-gcz <in> <out> <auto|raw|zlib> [block_size] [level] [sub_type]
        \\  inspect-wia|inspect-rvz <image>
        \\  decode-wia|decode-rvz <in> <out> [max_output]
        \\  decode-wia-range|decode-rvz-range <in> <out> <offset> <length>
        \\  encode-wia <in> <out> <none|purge|bzip2|lzma|lzma2> [chunk_size] [level]
        \\  encode-rvz <in> <out> <none|bzip2|lzma|lzma2|zstd> [chunk_size] [level]
        \\  encode-wia-partition <in> <out> <codec> <offset> <size> <key_hex> [chunk_size] [level]
        \\  encode-rvz-partition <in> <out> <codec> <offset> <size> <key_hex> [chunk_size] [level]
        \\  encode-wia-disc <in> <out> <codec> <common_key_index> <common_key_hex> [chunk_size] [level]
        \\  encode-rvz-disc <in> <out> <codec> <common_key_index> <common_key_hex> [chunk_size] [level]
        \\  inspect-wbfs <image.wbfs>
        \\  decode-wbfs <in> <out> [max_output]
        \\  decode-wbfs-range <in> <out> <offset> <length>
        \\  encode-wbfs <in> <out> [sector_size] [sparse|full]
        \\  inspect-wdf <image.wdf>
        \\  decode-wdf <in> <out> [max_output]
        \\  decode-wdf-range <in> <out> <offset> <length>
        \\  encode-wdf <in> <out> [wdf1|wdf2] [sparse|full] [min_hole_size]
        \\  inspect-wux <image.wux>
        \\  decode-wux <in> <out> [max_output]
        \\  decode-wux-range <in> <out> <offset> <length>
        \\  encode-wux <in> <out> [sector_size] [deduplicate|store-all]
        \\  inspect-android-sparse <image.simg>
        \\  decode-android-sparse <in> <out> [max_output]
        \\  decode-android-sparse-range <in> <out> <offset> <length>
        \\  encode-android-sparse <in> <out> [block_size] [sparse|store-zero] [fill|raw-fill] [crc|no-crc] [checksum|no-checksum]
        \\  inspect-android-ota <payload.bin>
        \\  extract-android-ota <payload> <partition> <out> [max_output] [source|-]
        \\  extract-android-ota-range <payload> <partition> <out> <offset> <length> [source|-]
        \\  encode-android-ota <in> <out> <partition> [auto|raw|bzip2|xz] [block_size] [operation_size]
        \\  puff-android-deflate <in> <out> [bit_offset] [bit_length]
        \\  huff-android-deflate <in> <out> <bit_offset> <bit_length>
        \\  encode-zchunk-file <in> <out> [chunk_size] [zstd|none] [normal|source-hashes]
        \\  decode-zchunk-file <in> <out> [max_output]
        \\  inspect-zchunk-file <path>
        \\  extract-zchunk-chunk <in> <number> <out> [max_output]
        \\  list-squashfs-file <path>
        \\  create-squashfs-file <out> <entry> <in> [stored|gzip|lzma|lzo|xz|lz4|zstd] [block_size]
        \\  extract-squashfs-file <image> <entry> <out> [max_output]
        \\  list-erofs-file <path>
        \\  create-erofs-file <out> <entry> <in> [stored|lz4|deflate|zstd]
        \\  extract-erofs-file <image> <entry> <out> [max_output]
        \\  list-wim-file <path>
        \\  extract-wim-resource <image> <sha1> <out> [max_output]
        \\  extract-wim-xml <image> <out> [max_output]
        \\  list-wim-image <image> [image_index]
        \\  extract-wim-path <image> <image_index> <entry> <out> [max_output]
        \\  extract-wim-stream <image> <image_index> <entry> <stream> <out> [max_output]
        \\  extract-wim-reparse <image> <image_index> <entry> <out> [max_output]
        \\  extract-wim-encrypted-raw <image> <image_index> <entry> <out> [max_output]
        \\  extract-wim-pipable-stream-path <image> <image_index> <entry> <out> <max_output> [input_step] [output_step] [default|reparse|encrypted-raw|stream:name] [early-exit|verify-integrity]
        \\  inspect-wim-encrypted-esd <image> [max_xml] [max_ranges]
        \\  decrypt-wim-encrypted-esd <image> <private_key_blob> <out> <max_output>
        \\  decrypt-wim-encrypted-esd-key <image> <aes256_key_hex> <out> <max_output>
        \\  list-wim-parts-image <image_index> <part>...
        \\  extract-wim-parts-path <image_index> <entry> <out> <max_output> <part>...
        \\  encode-bgzf-file <in> <out> [block_size]
        \\                              Encode deterministic blocked gzip/BGZF
        \\  decode-bgzf-file <in> <out> [max_output]
        \\                              Decode and validate all BGZF blocks
        \\  inspect-bgzf-file <path>    List BGZF blocks and virtual offsets
        \\  decode-bgzf-range <in> <out> <start_virtual> <end_virtual> [max_output]
        \\                              Decode an indexed BGZF virtual range
        \\  encode-br-stored-hex [text] [window_bits] [metadata]
        \\                              Encode text as dependency-free Brotli stored-stream hex
        \\  decode-br-hex [hex] [max_output]
        \\                              Decode dependency-free Brotli stored-stream hex
        \\  encode-br-stored-file <in> <out> [window_bits] [metadata]
        \\                              Encode file bytes as dependency-free Brotli stored stream
        \\  decode-br-file-to <in> <out> [max_output]
        \\                              Decode dependency-free Brotli stored stream file
        \\  encode-bzip2-file <in> <out> [block_size_100k]
        \\                              Encode a deterministic Bzip2 stream
        \\  decode-bzip2-file <in> <out> [max_output]
        \\                              Decode one Bzip2 stream with CRC validation
        \\  decode-bzip2-concat-file <in> <out> [max_output]
        \\                              Decode concatenated Bzip2 streams
        \\  size-bzip2-file <path> [max_output]
        \\                              Preflight a Bzip2 stream's decoded size
        \\  encode-compress-z-file <in> <out> [max_bits] [block|nonblock]
        \\                              Encode a deterministic Unix compress (.Z) stream
        \\  decode-compress-z-file <in> <out> [max_output]
        \\                              Decode a Unix compress (.Z) stream
        \\  size-compress-z-file <path> [max_output]
        \\                              Preflight a Unix compress stream's decoded size
        \\  encode-lzip-file <in> <out> [dictionary_size]
        \\                              Encode a deterministic lzip v1 member
        \\  decode-lzip-file <in> <out> [max_output] [max_dictionary]
        \\                              Decode and verify a single- or multi-member lzip file
        \\  size-lzip-file <path> [max_output] [max_dictionary]
        \\                              Decode and report a verified lzip file's size
        \\  inspect-lzip-file <path>    Parse and print structural lzip member metadata
        \\  encode-lzf-file <in> <out> [block_size] [eof|no-eof]
        \\                              Encode a deterministic LZF ZV stream
        \\  decode-lzf-file <in> <out> [max_output]
        \\                              Decode an LZF ZV stream
        \\  size-lzf-file <path> [max_output]
        \\                              Validate and report an LZF stream's decoded size
        \\  inspect-lzf-file <path>     Parse and print LZF ZV block metadata
        \\  create-lha-file <out> <entry> <in> [stored|lh1|lh4|lh5|lh6|lh7|lz5|lzs]
        \\                              Create a deterministic level-0 LHA archive
        \\  list-lha-file <path>        List LHA level-0/1/2/3 and SFX entries
        \\  extract-lha-file <lha> <entry> <out> [max_output]
        \\                              Extract common stored/LH/LArc LHA data
        \\  create-ar-file <out> <entry> <in> [regular|thin]
        \\                              Create a deterministic Unix ar archive
        \\  list-ar-file <path>         List GNU/BSD Unix ar members
        \\  extract-ar-file <ar> <entry> <out> [max_output] [thin_source]
        \\                              Extract a bounded Unix ar member
        \\  create-deb-file <out> <package> <version> <entry> <in> [none|gzip|bzip2|lzma|xz|zstd]
        \\                              Create a deterministic Debian binary package
        \\  list-deb-file <path>        List Debian control/data archive metadata
        \\  extract-deb-file <deb> <entry> <out> [max_output]
        \\                              Extract a bounded Debian data member
        \\  create-rpm-file <out> <package> <version> <entry> <in> [none|gzip|bzip2|lzma|xz|zstd]
        \\                              Create a deterministic unsigned RPM package
        \\  list-rpm-file <path>        List RPM metadata and CPIO payload entries
        \\  extract-rpm-file <rpm> <entry> <out> [max_output]
        \\                              Extract a bounded RPM payload member
        \\  extract-rpm-payload <rpm> <out> [max_output]
        \\                              Decode the raw RPM CPIO payload
        \\  create-arj-file <out> <entry> <in> [stored|method1|method2|method3|method4]
        \\                              Create a deterministic ARJ archive
        \\  list-arj-file <path>        List ARJ entries and methods
        \\  extract-arj-file <arj> <entry> <out> [max_output]
        \\                              Extract ARJ methods 0 through 4
        \\  create-arc-file <out> <entry> <in> [stored|packed|squeezed|crunched|squashed|crushed|distilled]
        \\                              Create a deterministic ARC/PAK archive
        \\  list-arc-file <path>        List ARC/PAK entries and methods
        \\  extract-arc-file <arc> <entry> <out> [max_output]
        \\                              Extract ARC/PAK methods 1 through 11
        \\  create-zoo-file <out> <entry> <in> [stored|lzd|lh5]
        \\                              Create a deterministic ZOO archive
        \\  list-zoo-file <path>        List ZOO entries and methods
        \\  extract-zoo-file <zoo> <entry> <out> [max_output]
        \\                              Extract ZOO stored, LZD, or LH5 data
        \\  create-cpio-file <out> <entry> <in> [newc|crc|odc|bin|bin-be] [none|gzip|bzip2|brotli|compress-z|lzma|xz|lz4|lzip|lzf|zstd|lzop]
        \\                              Create a deterministic CPIO archive
        \\  list-cpio-file <path>       List newc/CRC/ODC/binary CPIO entries
        \\  extract-cpio-file <cpio> <entry> <out> [max_output]
        \\                              Extract a regular file or symlink target
        \\  create-rar-file <out> <entry> <in> [rar4|rar5] [method] [filter] [solid] [version-specific encryption args]
        \\                              Create a deterministic stored/compressed RAR archive
        \\  create-rar-volumes <prefix> <entry> <in> <payload_size> [stored|rar50] [filter] [solid]
        \\                              Create an ordered RAR5 volume set
        \\  list-rar-file <path> [password]
        \\                              List RAR4/RAR5 entries and methods
        \\  extract-rar-file <rar> <entry> <out> [max_output] [password]
        \\                              Extract a supported RAR entry
        \\  extract-rar-volumes <entry> <out> <max_output> [--password=...] <vol1> [vol2...]
        \\                              Extract across an ordered RAR5 volume set
        \\  encode-lzop-file <in> <out> [block_size] [adler32|crc32] [compressed-checksum]
        \\                              Encode compressed-or-stored LZOP blocks
        \\  encode-lzop-stored-file <in> <out> [block_size] [adler32|crc32]
        \\                              Encode a deterministic stored-block LZOP stream
        \\  decode-lzop-file <in> <out> [max_output] [max_block]
        \\                              Decode LZO1X and stored LZOP blocks
        \\  size-lzop-file <path> [max_output] [max_block]
        \\                              Decode and report a verified LZOP stream's size
        \\  inspect-lzop-file <path>    Parse and print structural LZOP metadata
        \\  create-7z-file <out> <entry> <in> [copy|deflate|bzip2|lzma|lzma2|lzma2-stored|ppmd7] [filters] [solid|non-solid] [header-codec|plain] [bcj2|classic] [start_ip] [external-CODEC|inline-names] [external-metadata-CODEC|inline-metadata] [ctime|-] [atime|-] [mtime|-] [attributes|-] [password|-] [iv_hex] [salt_hex|-] [cycles] [encrypted-header|plain-header] [start_position|-]
        \\                              Create a deterministic 7z archive; filters are comma-separated
        \\  list-7z-file <path> [password|-]
        \\  list-7z-source-file <path> [password|-]
        \\                              List entries in a supported 7z archive
        \\  extract-7z-file <7z> <entry> <out> [max_output] [max_dictionary] [max_folder] [password|-]
        \\  extract-7z-source-file <7z> <entry> <out> [max_output] [max_dictionary] [max_folder] [password|-]
        \\  extract-7z-source-stream-file <7z> <entry> <out> [max_output] [max_dictionary] [max_folder] [password|-]
        \\  list-7z-volumes <password|-> <ordered-part>...
        \\  extract-7z-volumes <entry> <out> [max_output] [max_dictionary] [max_folder] <password|-> <ordered-part>...
        \\                              Extract a common-codec, Delta, or BCJ-filtered 7z entry
        \\  encode-lzma-file <in> <out> [end-marker|known]
        \\                              Encode deterministic LZMA-Alone data
        \\  decode-lzma-file <in> <out> [max_output] [max_dictionary]
        \\                              Decode an LZMA-Alone stream with explicit limits
        \\  decode-microlzma-file <in> <out> <decoded_size> [dictionary]
        \\                              Decode an exact-size raw MicroLZMA stream
        \\  size-lzma-file <path> [max_output]
        \\                              Decode and report an LZMA-Alone stream's size
        \\  encode-xz-stored-file <in> <out> [none|crc32|crc64|sha256] [block_size] [filters] [dictionary_size] [greedy|lazy]
        \\                              Encode deterministic XZ with uncompressed LZMA2 chunks
        \\  encode-xz-file <in> <out> [none|crc32|crc64|sha256] [block_size] [filters] [dictionary_size] [greedy|lazy]
        \\                              Encode deterministic XZ with compressed-or-stored LZMA2 chunks
        \\  decode-xz-file <in> <out> [max_output]
        \\                              Decode one XZ/LZMA2 stream with check validation
        \\  decode-xz-concat-file <in> <out> [max_output]
        \\                              Decode concatenated XZ streams and stream padding
        \\  size-xz-file <path> [max_output]
        \\                              Preflight an XZ stream's decoded size
        \\  inspect-xz-file <path>      Validate and print XZ stream metadata
        \\  create-tar-file <out> <entry> <in> [none|gzip|bzip2|brotli|compress-z|lzma|xz|lz4|lzip|lzf|zstd|lzop]
        \\                              Create a deterministic one-entry tarball
        \\  list-tar-file <path> [max_tar_size]
        \\                              List common compressed tarball formats
        \\  extract-tar-file <tar> <entry> <out> [max_tar_size]
        \\                              Extract one named regular file without path traversal
        \\  create-cab-file <out> <entry> <in> [stored|mszip|quantum|lzx] [block_size] [window_bits] [quantum_level]
        \\                              Create a deterministic one-folder CAB archive
        \\  list-cab-file <path>        List single-cabinet Stored/MSZIP/LZX/Quantum metadata
        \\  create-cab-set <dir> <entry> <in> [max_cabinet] [stored|mszip|quantum|lzx] [window_bits] [quantum_level]
        \\                              Create a deterministic linked cabinet set
        \\  extract-cab-file <cab> <entry> <out> [max_file] [max_folder]
        \\                              Extract a Stored/MSZIP/LZX/Quantum CAB entry with explicit limits
        \\  extract-cab-set <entry> <out> <cab1> <cab2> [...]
        \\                              Extract an entry across an explicitly ordered cabinet set
        \\  create-zip-split-file <prefix> <entry> <in> <max_part> [stored|deflate] [auto|zip32|zip64] [descriptor|sizes]
        \\                              Create a standard atomic-record split ZIP set
        \\  create-zip-split-stream-file <prefix> <entry> <in> <max_part> [stored|deflate] [auto|zip32|zip64]
        \\                              Incrementally create split ZIP parts with bounded output memory
        \\  list-zip-file <path>        List ZIP32/ZIP64 central-directory entries
        \\  extract-zip-file <zip> <entry> <out> [max_output] [max_dictionary] [password|-]
        \\                              Extract a supported ZIP entry with CRC validation
        \\  extract-zip-split-files <entry> <out> <max_output> <password|-> <part1> <part2> [...]
        \\                              Extract from an owned normalized split/multi-disk ZIP view
        \\  extract-zip-split-stream-files <entry> <out> <max_output> <password|-> <part1> <part2> [...]
        \\                              Sequentially extract split ZIP without a joined archive copy
        \\  extract-zip-split-source-files <entry> <out> <max_output> <password|-> <part1> <part2> [...]
        \\                              Extract while retaining at most one physical part file
        \\  extract-zip-file-incremental <zip> <entry> <out> [max_output] [password|-]
        \\                              Incrementally extract one Stored/Deflate ZIP entry
        \\  extract-zip-stream-file <zip> <entry> <out> [max_output] [password|-]
        \\                              Sequentially parse and extract a supported ZIP entry
        \\  size-br-file <path> [max_output]
        \\                              Preflight dependency-free Brotli stored stream decoded size
        \\  encode-zstd-native-hex [text] [auto|raw_or_rle|literal_only|fast_compressed] [checksum] [content_size]
        \\                              Encode text as dependency-free native-subset Zstandard hex
        \\  encode-zstd-native-bytes-hex [hex] [auto|raw_or_rle|literal_only|fast_compressed] [checksum] [content_size]
        \\                              Encode bytes as dependency-free native-subset Zstandard hex
        \\  encode-zstd-native-file-hex [path] [auto|raw_or_rle|literal_only|fast_compressed] [checksum] [content_size]
        \\                              Encode file bytes as dependency-free native-subset Zstandard hex
        \\  encode-zstd-native-file <in> <out> [auto|raw_or_rle|literal_only|fast_compressed] [checksum] [content_size]
        \\                              Encode file bytes as dependency-free native-subset Zstandard file
        \\  decode-zstd-native-hex [hex] [max_output]
        \\                              Decode dependency-free native-subset Zstandard hex
        \\  decode-zstd-native-file [path] [max_output]
        \\                              Decode dependency-free native-subset Zstandard file
        \\  decode-zstd-native-file-to <in> <out> [max_output]
        \\                              Decode dependency-free native-subset Zstandard file to output
        \\  size-zstd-native-hex [hex] [max_output]
        \\                              Preflight dependency-free native-subset Zstandard decoded size
        \\  size-zstd-native-file [path] [max_output]
        \\                              Preflight dependency-free native-subset Zstandard file decoded size
        \\  summary-zstd-native-file [path] [text|json]
        \\                              Summarize dependency-free native-subset Zstandard frame/stream blocks
        \\  encode-lz4-native-file <in> <out>
        \\                              Encode file bytes as dependency-free native LZ4 frame
        \\  size-lz4-native-file [path] [max_output]
        \\                              Preflight dependency-free native LZ4 frame decoded size
        \\  summary-lz4-native-file [path] [text|json]
        \\                              Summarize dependency-free native LZ4 frame/stream blocks
        \\  decode-lz4-native-file-to <in> <out> [max_output]
        \\                              Decode dependency-free native LZ4 frame to output
        \\  size-lz4-block-hex [hex] [max_output]
        \\                              Preflight LZ4 block decoded size
        \\  summary-lz4-block-hex [hex]
        \\                              Summarize LZ4 block literal/match tokens
        \\  encode-lz4-block-hex [hex]
        \\                              Encode LZ4 block
        \\  decode-lz4-block-hex [hex] [max_output]
        \\                              Decode LZ4 block
        \\  size-snappy-block-hex [hex] [max_output]
        \\                              Preflight Snappy raw block decoded size
        \\  summary-snappy-block-hex [hex]
        \\                              Summarize Snappy raw block tokens and decoded bytes
        \\  encode-snappy-block-hex [hex]
        \\                              Encode Snappy raw block
        \\  decode-snappy-block-hex [hex] [max_output]
        \\                              Decode Snappy raw block
        \\  encode-snappy-block-file <in> <out>
        \\                              Encode file bytes as a Snappy raw block
        \\  decode-snappy-block-file-to <in> <out> [max_output]
        \\                              Decode Snappy raw block file to output
        \\  size-snappy-block-file [path] [max_output]
        \\                              Preflight Snappy raw block file decoded size
        \\  summary-snappy-block-file [path]
        \\                              Summarize Snappy raw block file tokens and decoded bytes
        \\  size-snappy-frame-hex [hex] [max_output]
        \\                              Preflight Snappy framed stream decoded size
        \\  summary-snappy-frame-hex [hex]
        \\                              Summarize Snappy framed stream chunks and decoded bytes
        \\  encode-snappy-frame-hex [hex]
        \\                              Encode Snappy framed stream
        \\  decode-snappy-frame-hex [hex] [max_output]
        \\                              Decode Snappy framed stream
        \\  encode-snappy-frame-file <in> <out>
        \\                              Encode file bytes as a Snappy framed stream
        \\  decode-snappy-frame-file-to <in> <out> [max_output]
        \\                              Decode Snappy framed stream file to output
        \\  size-snappy-frame-file [path] [max_output]
        \\                              Preflight Snappy framed stream file decoded size
        \\  summary-snappy-frame-file [path]
        \\                              Summarize Snappy framed stream file chunks and decoded bytes
        \\  size-lz4-block-prefix-hex [hex] [prefix_hex] [max_output]
        \\                              Preflight LZ4 block decoded size with prefix history
        \\  summary-lz4-block-prefix-hex [hex] [prefix_hex]
        \\                              Summarize LZ4 block tokens with prefix history
        \\  encode-lz4-block-prefix-hex [hex] [prefix_hex]
        \\                              Encode LZ4 block with prefix history
        \\  decode-lz4-block-prefix-hex [hex] [prefix_hex] [max_output]
        \\                              Decode LZ4 block with prefix history
        \\  decode-raw-hex [hex] [max_output]
        \\                              Decode raw deflate hex to text
        \\  decode-raw-dict-hex [hex] [dict] [max_output]
        \\                              Decode raw deflate hex with a preset dictionary
        \\  decode-raw-file <in> <out> [max_output]
        \\                              Decode raw deflate file bytes with an optional output limit
        \\  decode-raw-dict-file <in> <out> <dict> [max_output]
        \\                              Decode raw deflate file bytes with a preset dictionary file
        \\  inspect-raw-header-hex [hex] [text|json]
        \\                              Print parsed raw deflate first-block metadata for hex input
        \\  inspect-raw-header-file <in> [text|json]
        \\                              Print parsed raw deflate first-block metadata for a file
        \\  decode-zlib-hex [hex] [max_output]
        \\                              Decode zlib-wrapped deflate hex to text
        \\  decode-zlib-concat-hex [hex] [max_output]
        \\                              Decode concatenated zlib stream hex to text
        \\  decode-zlib-dict-concat-hex [hex] [dict] [max_output]
        \\                              Decode concatenated zlib FDICT stream hex with a preset dictionary
        \\  decode-zlib-dict-hex [hex] [dict] [max_output]
        \\                              Decode zlib-wrapped deflate hex with a preset dictionary
        \\  decode-zlib-file <in> <out> [max_output]
        \\                              Decode a zlib file with an optional output limit
        \\  decode-zlib-concat-file <in> <out> [max_output]
        \\                              Decode a concatenated zlib file with an optional output limit
        \\  decode-zlib-dict-concat-file <in> <out> <dict> [max_output]
        \\                              Decode a concatenated zlib FDICT file with a preset dictionary file
        \\  decode-zlib-dict-file <in> <out> <dict> [max_output]
        \\                              Decode a zlib file with a preset dictionary file
        \\  inspect-zlib-header-hex [hex] [text|json]
        \\                              Print parsed zlib header metadata for hex input
        \\  inspect-zlib-header-file <in> [text|json]
        \\                              Print parsed zlib header metadata for a file
        \\  inspect-zlib-deflate-header-hex [hex] [text|json]
        \\                              Inspect the raw deflate header inside a zlib stream
        \\  inspect-zlib-dict-deflate-header-hex [hex] [dict] [text|json]
        \\                              Inspect a zlib FDICT stream using a preset dictionary
        \\  inspect-zlib-deflate-header-file <in> [text|json]
        \\                              Inspect the raw deflate header inside a zlib file
        \\  inspect-zlib-dict-deflate-header-file <in> <dict> [text|json]
        \\                              Inspect a zlib FDICT file using a preset dictionary file
        \\  decode-gzip-hex [hex] [max_output]
        \\                              Decode gzip-wrapped deflate hex to text
        \\  decode-gzip-file <in> <out> [max_output]
        \\                              Decode a gzip file with an optional output limit
        \\  inspect-gzip-header-hex [hex] [text|json]
        \\                              Print parsed gzip header metadata for hex input
        \\  inspect-gzip-header-file <in> [text|json]
        \\                              Print parsed gzip header metadata for a file
        \\  inspect-gzip-deflate-header-hex [hex] [text|json] [member_index]
        \\                              Inspect the raw deflate header inside a gzip stream member
        \\  inspect-gzip-deflate-header-file <in> [text|json] [member_index]
        \\                              Inspect the raw deflate header inside a gzip file member
        \\  encode-raw-dict-best-hex [text] [dict] [level]
        \\                              Encode raw deflate that may reference preset dictionary history
        \\  encode-zlib-dict-best-hex [text] [dict] [level]
        \\                              Encode a zlib FDICT/DICTID frame requiring a preset dictionary
        \\  encode-raw-best-file-hex <in> [level]
        \\                              Encode raw deflate file bytes and print best-block hex
        \\  encode-zlib-best-file-hex <in> [level]
        \\                              Encode zlib-compatible file bytes and print best-block hex
        \\  encode-gzip-best-file-hex <in> [level]
        \\                              Encode gzip-compatible file bytes and print best-block hex
        \\  encode-vort-best-file <in> <out>
        \\                              Encode one native Vort best frame
        \\  encode-raw-fixed-file <in> <out> [level]
        \\                              Encode raw deflate file bytes with fixed Huffman blocks
        \\  encode-zlib-best-file <in> <out> [level]
        \\                              Encode a zlib-compatible file with best-block selection
        \\  encode-raw-best-file <in> <out> [level]
        \\                              Encode raw deflate file bytes with best-block selection
        \\  encode-gzip-best-file <in> <out> [level]
        \\                              Encode a gzip-compatible file with best-block selection
        \\  encode-raw-dict-best-file <in> <out> <dict> [level]
        \\                              Encode raw deflate file bytes using preset dictionary history
        \\  encode-raw-dict-best-split-file <in> <out> <dict> <block_len> [level]
        \\                              Encode split raw deflate file bytes using preset dictionary history
        \\  encode-raw-dict-best-adaptive-file <in> <out> <dict> [level]
        \\                              Encode adaptive-split raw deflate file bytes using preset dictionary history
        \\  encode-zlib-dict-best-file <in> <out> <dict> [level]
        \\                              Encode a zlib FDICT/DICTID file using preset dictionary history
        \\  encode-zlib-dict-best-split-file <in> <out> <dict> <block_len> [level]
        \\                              Encode split zlib FDICT/DICTID file using preset dictionary history
        \\  encode-zlib-dict-best-adaptive-file <in> <out> <dict> [level]
        \\                              Encode adaptive-split zlib FDICT/DICTID file using preset dictionary history
        \\
        \\native indexed file workflows:
        \\  encode-vort-sidecar-best-file <in> <stream> <sidecar> [block_len]
        \\                              Encode native Vort stream plus external sidecar index
        \\  verify-vort-sidecar-index-file <stream> <sidecar> [full|metadata] [text|json]
        \\                              Validate an external sidecar index against a stream
        \\  decode-vort-sidecar-range-file <stream> <sidecar> <out> <offset> <len>
        \\                              Decode an indexed range through an external sidecar
        \\  encode-vort-embedded-best-file <in> <stream> [block_len]
        \\                              Encode native Vort stream with embedded index
        \\  encode-vort-seekable-tier-file <in> <stream> <seek_fast|balanced|ratio>
        \\                              Encode native Vort stream using a seekability tier block size
        \\  encode-vort-blocked-best-file <in> <stream> [block_len]
        \\                              Encode native Vort blocked stream without embedded index
        \\  verify-vort-embedded-index-file <stream> [full|metadata] [text|json]
        \\                              Validate an embedded-index stream
        \\  decode-vort-embedded-range-file <stream> <out> <offset> <len>
        \\                              Decode an indexed range from an embedded-index stream
        \\  bench-decode-raw-file <in> <decoded_len> [iterations]
        \\                              Time raw deflate decode in one CLI process
        \\  bench-decode-vort-best-file <in> <decoded_len> [iterations]
        \\                              Time native Vort best-frame decode in one CLI process
        \\  bench-decode-vort-embedded-range-file <stream> <decoded_len> [iterations]
        \\                              Time embedded-index range decode in one CLI process
        \\  bench-decode-vort-embedded-offset-range-file <stream> <offset> <len> [iterations]
        \\                              Time embedded-index offset range decode in one CLI process
        \\  encode-vort-embedded-dict-file <in> <stream> [block_len]
        \\                              Encode self-contained dictionary stream with embedded index
        \\  decode-vort-embedded-auto-range-file <stream> <out> <offset> <len>
        \\                              Decode embedded-index range with dictionary auto-detection
        \\  encode-vort-sidecar-dict-file <in> <stream> <sidecar> [block_len]
        \\                              Encode self-contained dictionary stream plus sidecar index
        \\  decode-vort-sidecar-auto-range-file <stream> <sidecar> <out> <offset> <len>
        \\                              Decode sidecar range with embedded dictionary auto-detection
        \\  encode-vort-sidecar-ldm-file <in> <stream> <sidecar> [block_len]
        \\                              Encode LDM-aware native stream plus sidecar index
        \\
        \\This CLI is a smoke surface for the library-first Vort APIs.
        \\
    , .{});
}

fn hexToOwnedBytes(allocator: std.mem.Allocator, hex: []const u8) ![]u8 {
    if ((hex.len & 1) != 0) return error.InvalidHexInput;
    const bytes = try allocator.alloc(u8, hex.len / 2);
    errdefer allocator.free(bytes);
    var i: usize = 0;
    while (i < bytes.len) : (i += 1) {
        bytes[i] = try std.fmt.parseInt(u8, hex[i * 2 .. i * 2 + 2], 16);
    }
    return bytes;
}

fn printDecoded(stdout: *std.Io.Writer, label: []const u8, compressed_len: usize, decoded: []const u8) !void {
    try stdout.print("{s}_compressed_bytes={d} decoded_bytes={d} crc32={d} text={s}\n", .{
        label,
        compressed_len,
        decoded.len,
        vort.crc32(decoded),
        decoded,
    });
}

fn printSnappyBlockSummary(stdout: *std.Io.Writer, compressed_len: usize, summary: vort.SnappyBlockSummary) !void {
    try stdout.print(
        "snappy_block_compressed_bytes={d} decoded_bytes={d} literals={d} literal_bytes={d} copies={d} copy_bytes={d} copy1={d} copy2={d} copy4={d}\n",
        .{
            compressed_len,
            summary.decoded_bytes,
            summary.literal_count,
            summary.literal_bytes,
            summary.copy_count,
            summary.copy_bytes,
            summary.copy1_count,
            summary.copy2_count,
            summary.copy4_count,
        },
    );
}

fn printSnappyFrameSummary(stdout: *std.Io.Writer, compressed_len: usize, summary: vort.SnappyFrameSummary) !void {
    try stdout.print(
        "snappy_frame_compressed_bytes={d} decoded_bytes={d} stream_identifiers={d} compressed_chunks={d} uncompressed_chunks={d} skippable_chunks={d} skippable_payload_bytes={d} compressed_payload_bytes={d} uncompressed_payload_bytes={d}\n",
        .{
            compressed_len,
            summary.decoded_bytes,
            summary.stream_identifier_count,
            summary.compressed_chunk_count,
            summary.uncompressed_chunk_count,
            summary.skippable_chunk_count,
            summary.skippable_payload_bytes,
            summary.compressed_payload_bytes,
            summary.uncompressed_payload_bytes,
        },
    );
}

const NativeSummaryErrorContext = struct {
    phase: []const u8,
    offset: usize,
};

fn printNativeSummaryErrorJson(stdout: *std.Io.Writer, schema: []const u8, compressed_len: usize, err: anyerror, context: NativeSummaryErrorContext) !void {
    try stdout.print("{{\"schema\":\"{s}\",\"schema_version\":1,\"ok\":false,\"compressed_bytes\":{d},\"error\":", .{ schema, compressed_len });
    try std.json.Stringify.value(@errorName(err), .{}, stdout);
    try stdout.print(",\"phase\":", .{});
    try std.json.Stringify.value(context.phase, .{}, stdout);
    try stdout.print(",\"offset\":{d}}}\n", .{context.offset});
}

fn printLz4NativeSummary(stdout: *std.Io.Writer, compressed_len: usize, summary: vort.Lz4NativeStreamSummary, output_format: HeaderInspectOutputFormat) !void {
    if (output_format == .json) return printLz4NativeSummaryJson(stdout, compressed_len, summary);
    try stdout.print(
        "lz4_native_compressed_bytes={d} frames={d} skippable_frames={d} content_size_frames={d} checksum_frames={d} block_checksum_frames={d} dictionary_id_frames={d} declared_content_bytes={d} blocks={d} compressed_blocks={d} raw_blocks={d} payload_bytes={d} skippable_payload_bytes={d}\n",
        .{
            compressed_len,
            summary.frame_count,
            summary.skippable_frame_count,
            summary.content_size_frame_count,
            summary.checksum_frame_count,
            summary.block_checksum_frame_count,
            summary.dictionary_id_frame_count,
            summary.declared_content_bytes,
            summary.block_count,
            summary.compressed_block_count,
            summary.raw_block_count,
            summary.payload_bytes,
            summary.skippable_payload_bytes,
        },
    );
}

fn printLz4NativeSummaryJson(stdout: *std.Io.Writer, compressed_len: usize, summary: vort.Lz4NativeStreamSummary) !void {
    try stdout.print(
        "{{\"schema\":\"vort.lz4_native_stream_summary\",\"schema_version\":1,\"compressed_bytes\":{d},\"frame_count\":{d},\"skippable_frame_count\":{d},\"content_size_frame_count\":{d},\"checksum_frame_count\":{d},\"block_checksum_frame_count\":{d},\"dictionary_id_frame_count\":{d},\"declared_content_bytes\":{d},\"block_count\":{d},\"compressed_block_count\":{d},\"raw_block_count\":{d},\"payload_bytes\":{d},\"skippable_payload_bytes\":{d}}}\n",
        .{
            compressed_len,
            summary.frame_count,
            summary.skippable_frame_count,
            summary.content_size_frame_count,
            summary.checksum_frame_count,
            summary.block_checksum_frame_count,
            summary.dictionary_id_frame_count,
            summary.declared_content_bytes,
            summary.block_count,
            summary.compressed_block_count,
            summary.raw_block_count,
            summary.payload_bytes,
            summary.skippable_payload_bytes,
        },
    );
}

fn printZstdNativeSummary(stdout: *std.Io.Writer, compressed_len: usize, summary: vort.ZstdNativeStreamSummary, output_format: HeaderInspectOutputFormat) !void {
    if (output_format == .json) return printZstdNativeSummaryJson(stdout, compressed_len, summary);
    try stdout.print(
        "zstd_native_compressed_bytes={d} frames={d} skippable_frames={d} checksum_frames={d} dictionary_id_frames={d} content_size_frames={d} declared_content_bytes={d} blocks={d} compressed_blocks={d} rle_blocks={d} raw_blocks={d} payload_bytes={d} skippable_payload_bytes={d}\n",
        .{
            compressed_len,
            summary.frame_count,
            summary.skippable_frame_count,
            summary.checksum_frame_count,
            summary.dictionary_id_frame_count,
            summary.content_size_frame_count,
            summary.declared_content_bytes,
            summary.block_count,
            summary.compressed_block_count,
            summary.rle_block_count,
            summary.raw_block_count,
            summary.payload_bytes,
            summary.skippable_payload_bytes,
        },
    );
}

fn printZstdNativeSummaryJson(stdout: *std.Io.Writer, compressed_len: usize, summary: vort.ZstdNativeStreamSummary) !void {
    try stdout.print(
        "{{\"schema\":\"vort.zstd_native_stream_summary\",\"schema_version\":1,\"compressed_bytes\":{d},\"frame_count\":{d},\"skippable_frame_count\":{d},\"checksum_frame_count\":{d},\"dictionary_id_frame_count\":{d},\"content_size_frame_count\":{d},\"declared_content_bytes\":{d},\"block_count\":{d},\"compressed_block_count\":{d},\"rle_block_count\":{d},\"raw_block_count\":{d},\"payload_bytes\":{d},\"skippable_payload_bytes\":{d}}}\n",
        .{
            compressed_len,
            summary.frame_count,
            summary.skippable_frame_count,
            summary.checksum_frame_count,
            summary.dictionary_id_frame_count,
            summary.content_size_frame_count,
            summary.declared_content_bytes,
            summary.block_count,
            summary.compressed_block_count,
            summary.rle_block_count,
            summary.raw_block_count,
            summary.payload_bytes,
            summary.skippable_payload_bytes,
        },
    );
}

fn printLz4BlockSummary(stdout: *std.Io.Writer, compressed_len: usize, summary: vort.Lz4BlockSummary) !void {
    try stdout.print(
        "lz4_block_compressed_bytes={d} decoded_bytes={d} literals={d} literal_bytes={d} matches={d} match_bytes={d}\n",
        .{
            compressed_len,
            summary.decoded_bytes,
            summary.literal_count,
            summary.literal_bytes,
            summary.match_count,
            summary.match_bytes,
        },
    );
}

fn printHex(stdout: *std.Io.Writer, bytes: []const u8) !void {
    try printHexInline(stdout, bytes);
    try stdout.print("\n", .{});
}

fn printHexInline(stdout: *std.Io.Writer, bytes: []const u8) !void {
    for (bytes) |byte| try stdout.print("{x:0>2}", .{byte});
}

const DecodeBenchResult = struct {
    elapsed_ns: u64,
    decoded_bytes: usize,
    checksum: u32,
};

fn benchDecodeRaw(compressed: []const u8, output: []u8, iterations: usize, io: std.Io) !DecodeBenchResult {
    const start = std.Io.Clock.awake.now(io);
    var checksum: u32 = 0;
    var decoded_bytes: usize = 0;
    for (0..iterations) |_| {
        const result = try vort.decodeRawDeflate(compressed, output);
        decoded_bytes = result.output_written;
        checksum +%= vort.crc32(output[0..decoded_bytes]);
    }
    const elapsed_ns_signed = start.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds();
    if (elapsed_ns_signed < 0) return error.InvalidTimestamp;
    return .{
        .elapsed_ns = @intCast(elapsed_ns_signed),
        .decoded_bytes = decoded_bytes,
        .checksum = checksum,
    };
}

fn benchDecodeVortBest(frame: []const u8, output: []u8, iterations: usize, io: std.Io) !DecodeBenchResult {
    const start = std.Io.Clock.awake.now(io);
    var checksum: u32 = 0;
    var decoded_bytes: usize = 0;
    for (0..iterations) |_| {
        decoded_bytes = try vort.storeDecodeAnyInto(frame, output);
        checksum +%= vort.crc32(output[0..decoded_bytes]);
    }
    const elapsed_ns_signed = start.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds();
    if (elapsed_ns_signed < 0) return error.InvalidTimestamp;
    return .{
        .elapsed_ns = @intCast(elapsed_ns_signed),
        .decoded_bytes = decoded_bytes,
        .checksum = checksum,
    };
}

fn benchDecodeVortEmbeddedRange(allocator: std.mem.Allocator, stream: []const u8, offset: u64, output: []u8, iterations: usize, io: std.Io) !DecodeBenchResult {
    const embedded_index = try vort.storeViewEmbeddedIndex(stream);
    const index_len = embedded_index.entry_count;
    const index_buffer = try allocator.alloc(vort.StoreFrameIndexEntry, index_len);
    defer allocator.free(index_buffer);
    const start = std.Io.Clock.awake.now(io);
    var checksum: u32 = 0;
    var decoded_bytes: usize = 0;
    for (0..iterations) |_| {
        const result = try vort.storeDecodeIndexedRangeIntoWithIndexBuffer(allocator, stream, offset, output.len, output, index_buffer);
        decoded_bytes = result.output_written;
        checksum +%= result.crc32;
    }
    const elapsed_ns_signed = start.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds();
    if (elapsed_ns_signed < 0) return error.InvalidTimestamp;
    return .{
        .elapsed_ns = @intCast(elapsed_ns_signed),
        .decoded_bytes = decoded_bytes,
        .checksum = checksum,
    };
}

const HeaderInspectOutputFormat = enum { text, json };

const WrappedDeflateContext = struct {
    wrapper: []const u8,
    wrapper_bytes: usize,
    member_offset: usize,
    deflate_offset: usize,
    member_index: usize,
    exact_deflate_bytes: ?usize = null,
    stream_deflate_bytes: ?usize = null,
    stream_output_bytes: ?usize = null,
    stream_footer_offset: ?usize = null,
    stream_end_offset: ?usize = null,
    stream_footer_adler32: ?u32 = null,
    stream_adler32: ?u32 = null,
    stream_adler32_matches: ?bool = null,
    member_deflate_bytes: ?usize = null,
    member_output_bytes: ?usize = null,
    member_footer_offset: ?usize = null,
    member_end_offset: ?usize = null,
    member_footer_crc32: ?u32 = null,
    member_crc32: ?u32 = null,
    member_crc32_matches: ?bool = null,
    member_footer_isize: ?u32 = null,
    member_isize: ?u32 = null,
    member_isize_matches: ?bool = null,
};

fn printRawHeaderInfo(stdout: *std.Io.Writer, compressed_len: usize, info: vort.RawDeflateHeaderInfo, output_format: HeaderInspectOutputFormat) !void {
    if (output_format == .json) return printRawHeaderJson(stdout, compressed_len, info);

    try stdout.print(
        "raw_header compressed_bytes={d} final={} block_type={s} data_bit_offset={d} data_byte_offset={d} header_bits_consumed={d} header_bytes_consumed={d} stored_len=",
        .{
            compressed_len,
            info.final,
            @tagName(info.block_type),
            info.data_bit_offset,
            info.data_byte_offset,
            info.header_bits_consumed,
            info.header_bytes_consumed,
        },
    );
    try printOptionalJson(u16, stdout, info.stored_len);
    try stdout.print(" stored_nlen=", .{});
    try printOptionalJson(u16, stdout, info.stored_nlen);
    try stdout.print(" stored_payload_offset=", .{});
    try printOptionalJson(usize, stdout, info.stored_payload_offset);
    try stdout.print(" dynamic_hlit=", .{});
    try printOptionalJson(u16, stdout, info.dynamic_hlit);
    try stdout.print(" dynamic_hdist=", .{});
    try printOptionalJson(u16, stdout, info.dynamic_hdist);
    try stdout.print(" dynamic_hclen=", .{});
    try printOptionalJson(u8, stdout, info.dynamic_hclen);
    try stdout.print(" dynamic_code_length_count=", .{});
    try printOptionalJson(u8, stdout, info.dynamic_code_length_count);
    try stdout.print(" dynamic_code_length_lengths=", .{});
    try printCodeLengthArray(stdout, &info.dynamic_code_length_lengths);
    try stdout.print(" dynamic_code_length_repeat_prev=", .{});
    try printOptionalJson(u16, stdout, info.dynamic_code_length_repeat_prev);
    try stdout.print(" dynamic_code_length_repeat_zero_short=", .{});
    try printOptionalJson(u16, stdout, info.dynamic_code_length_repeat_zero_short);
    try stdout.print(" dynamic_code_length_repeat_zero_long=", .{});
    try printOptionalJson(u16, stdout, info.dynamic_code_length_repeat_zero_long);
    try stdout.print(" dynamic_literal_nonzero=", .{});
    try printOptionalJson(u16, stdout, info.dynamic_literal_nonzero);
    try stdout.print(" dynamic_literal_zero=", .{});
    try printOptionalJson(u16, stdout, info.dynamic_literal_zero);
    try stdout.print(" dynamic_literal_max_bits=", .{});
    try printOptionalJson(u8, stdout, info.dynamic_literal_max_bits);
    try stdout.print(" dynamic_literal_length_histogram=", .{});
    try printU16Array16(stdout, &info.dynamic_literal_length_histogram);
    try stdout.print(" dynamic_distance_nonzero=", .{});
    try printOptionalJson(u16, stdout, info.dynamic_distance_nonzero);
    try stdout.print(" dynamic_distance_zero=", .{});
    try printOptionalJson(u16, stdout, info.dynamic_distance_zero);
    try stdout.print(" dynamic_distance_max_bits=", .{});
    try printOptionalJson(u8, stdout, info.dynamic_distance_max_bits);
    try stdout.print(" dynamic_distance_length_histogram=", .{});
    try printU16Array16(stdout, &info.dynamic_distance_length_histogram);
    try stdout.print(" dynamic_has_eob=", .{});
    try printOptionalBoolJson(stdout, info.dynamic_has_eob);
    try stdout.print(" dynamic_lengths_bit_offset=", .{});
    try printOptionalJson(usize, stdout, info.dynamic_lengths_bit_offset);
    try stdout.print(" dynamic_lengths_byte_offset=", .{});
    try printOptionalJson(usize, stdout, info.dynamic_lengths_byte_offset);
    try stdout.print("\n", .{});
}

fn printZlibHeaderInfo(stdout: *std.Io.Writer, compressed_len: usize, info: vort.ZlibHeaderInfo, output_format: HeaderInspectOutputFormat) !void {
    if (output_format == .json) return printZlibHeaderJson(stdout, compressed_len, info);

    try stdout.print(
        "zlib_header compressed_bytes={d} data_offset={d} cmf=0x{x:0>2} flg=0x{x:0>2} method={d} window_bits={d} window_size={d} fcheck={d} fdict={} flevel={d} dictid=",
        .{
            compressed_len,
            info.data_offset,
            info.cmf,
            info.flg,
            info.compression_method,
            info.window_bits,
            info.window_size,
            info.fcheck,
            info.uses_dictionary,
            info.flevel,
        },
    );
    if (info.dictionary_id) |dictid| {
        try stdout.print("{d}\n", .{dictid});
    } else {
        try stdout.print("null\n", .{});
    }
}

fn printGzipHeaderInfo(stdout: *std.Io.Writer, compressed_len: usize, info: vort.GzipHeaderInfo, output_format: HeaderInspectOutputFormat) !void {
    if (output_format == .json) return printGzipHeaderJson(stdout, compressed_len, info);

    try stdout.print(
        "gzip_header compressed_bytes={d} data_offset={d} flags=0x{x:0>2} text={} mtime={d} xfl={d} os={d} extra_present={} extra_len={d} extra_hex=",
        .{
            compressed_len,
            info.data_offset,
            info.flags,
            info.text,
            info.mtime,
            info.xfl,
            info.os,
            info.extra != null,
            if (info.extra) |extra| extra.len else 0,
        },
    );
    if (info.extra) |extra| {
        try printHexInline(stdout, extra);
    } else {
        try stdout.print("null", .{});
    }
    try stdout.print(" filename=", .{});
    try printOptionalJsonBytes(stdout, info.filename);
    try stdout.print(" comment=", .{});
    try printOptionalJsonBytes(stdout, info.comment);
    if (info.header_crc) |crc| {
        try stdout.print(" header_crc={d}\n", .{crc});
    } else {
        try stdout.print(" header_crc=null\n", .{});
    }
}

fn printRawHeaderJson(stdout: *std.Io.Writer, compressed_len: usize, info: vort.RawDeflateHeaderInfo) !void {
    try printRawHeaderJsonObject(stdout, compressed_len, info);
    try stdout.print("\n", .{});
}

fn printRawHeaderJsonObject(stdout: *std.Io.Writer, compressed_len: usize, info: vort.RawDeflateHeaderInfo) !void {
    try stdout.print(
        "{{\"schema\":\"vort.raw_deflate_header_info\",\"schema_version\":1,\"compressed_bytes\":{d},\"final\":{},\"block_type\":\"{s}\",\"data_bit_offset\":{d},\"data_byte_offset\":{d},\"header_bits_consumed\":{d},\"header_bytes_consumed\":{d},\"stored_len\":",
        .{
            compressed_len,
            info.final,
            @tagName(info.block_type),
            info.data_bit_offset,
            info.data_byte_offset,
            info.header_bits_consumed,
            info.header_bytes_consumed,
        },
    );
    try printOptionalJson(u16, stdout, info.stored_len);
    try stdout.print(",\"stored_nlen\":", .{});
    try printOptionalJson(u16, stdout, info.stored_nlen);
    try stdout.print(",\"stored_payload_offset\":", .{});
    try printOptionalJson(usize, stdout, info.stored_payload_offset);
    try stdout.print(",\"dynamic_hlit\":", .{});
    try printOptionalJson(u16, stdout, info.dynamic_hlit);
    try stdout.print(",\"dynamic_hdist\":", .{});
    try printOptionalJson(u16, stdout, info.dynamic_hdist);
    try stdout.print(",\"dynamic_hclen\":", .{});
    try printOptionalJson(u8, stdout, info.dynamic_hclen);
    try stdout.print(",\"dynamic_code_length_count\":", .{});
    try printOptionalJson(u8, stdout, info.dynamic_code_length_count);
    try stdout.print(",\"dynamic_code_length_lengths\":", .{});
    try printCodeLengthArray(stdout, &info.dynamic_code_length_lengths);
    try stdout.print(",\"dynamic_code_length_repeat_prev\":", .{});
    try printOptionalJson(u16, stdout, info.dynamic_code_length_repeat_prev);
    try stdout.print(",\"dynamic_code_length_repeat_zero_short\":", .{});
    try printOptionalJson(u16, stdout, info.dynamic_code_length_repeat_zero_short);
    try stdout.print(",\"dynamic_code_length_repeat_zero_long\":", .{});
    try printOptionalJson(u16, stdout, info.dynamic_code_length_repeat_zero_long);
    try stdout.print(",\"dynamic_literal_nonzero\":", .{});
    try printOptionalJson(u16, stdout, info.dynamic_literal_nonzero);
    try stdout.print(",\"dynamic_literal_zero\":", .{});
    try printOptionalJson(u16, stdout, info.dynamic_literal_zero);
    try stdout.print(",\"dynamic_literal_max_bits\":", .{});
    try printOptionalJson(u8, stdout, info.dynamic_literal_max_bits);
    try stdout.print(",\"dynamic_literal_length_histogram\":", .{});
    try printU16Array16(stdout, &info.dynamic_literal_length_histogram);
    try stdout.print(",\"dynamic_distance_nonzero\":", .{});
    try printOptionalJson(u16, stdout, info.dynamic_distance_nonzero);
    try stdout.print(",\"dynamic_distance_zero\":", .{});
    try printOptionalJson(u16, stdout, info.dynamic_distance_zero);
    try stdout.print(",\"dynamic_distance_max_bits\":", .{});
    try printOptionalJson(u8, stdout, info.dynamic_distance_max_bits);
    try stdout.print(",\"dynamic_distance_length_histogram\":", .{});
    try printU16Array16(stdout, &info.dynamic_distance_length_histogram);
    try stdout.print(",\"dynamic_has_eob\":", .{});
    try printOptionalBoolJson(stdout, info.dynamic_has_eob);
    try stdout.print(",\"dynamic_lengths_bit_offset\":", .{});
    try printOptionalJson(usize, stdout, info.dynamic_lengths_bit_offset);
    try stdout.print(",\"dynamic_lengths_byte_offset\":", .{});
    try printOptionalJson(usize, stdout, info.dynamic_lengths_byte_offset);
    try stdout.print("}}", .{});
}

fn inspectZlibStreamForWrappedJson(allocator: std.mem.Allocator, compressed: []const u8) !?vort.ZlibStreamInfo {
    return vort.inspectZlibStreamAlloc(allocator, compressed) catch |err| switch (err) {
        // The header-level command has no dictionary argument. Preserve useful
        // raw-header inspection for FDICT streams while leaving checksum and
        // exact-length diagnostics null when the preset dictionary is required.
        error.NeedDictionary => null,
        else => return err,
    };
}

fn zlibWrappedDeflateContext(wrapper_bytes: usize, deflate_offset: usize, stream: ?vort.ZlibStreamInfo) WrappedDeflateContext {
    var context = WrappedDeflateContext{
        .wrapper = "zlib",
        .wrapper_bytes = wrapper_bytes,
        .member_offset = 0,
        .deflate_offset = deflate_offset,
        .member_index = 0,
    };
    if (stream) |info| {
        context.exact_deflate_bytes = info.deflate_bytes;
        context.stream_deflate_bytes = info.deflate_bytes;
        context.stream_output_bytes = info.output_bytes;
        context.stream_footer_offset = info.footer_offset;
        context.stream_end_offset = info.end_offset;
        context.stream_footer_adler32 = info.footer_adler32;
        context.stream_adler32 = info.adler32;
        context.stream_adler32_matches = info.adler32_matches;
    }
    return context;
}

fn gzipWrappedDeflateContext(wrapper_bytes: usize, member: vort.GzipMemberInfo) WrappedDeflateContext {
    return .{
        .wrapper = "gzip",
        .wrapper_bytes = wrapper_bytes,
        .member_offset = member.member_offset,
        .deflate_offset = member.deflate_offset,
        .member_index = member.member_index,
        .exact_deflate_bytes = member.deflate_bytes,
        .member_deflate_bytes = member.deflate_bytes,
        .member_output_bytes = member.output_bytes,
        .member_footer_offset = member.footer_offset,
        .member_end_offset = member.end_offset,
        .member_footer_crc32 = member.footer_crc32,
        .member_crc32 = member.crc32,
        .member_crc32_matches = member.crc32_matches,
        .member_footer_isize = member.footer_isize,
        .member_isize = member.isize,
        .member_isize_matches = member.isize_matches,
    };
}

fn printWrappedDeflateHeaderJson(stdout: *std.Io.Writer, context: WrappedDeflateContext, info: vort.RawDeflateHeaderInfo) !void {
    const scope = if (std.mem.eql(u8, context.wrapper, "gzip")) "gzip_member" else "zlib_stream";
    try stdout.print(
        "{{\"schema\":\"vort.wrapped_deflate_header_info\",\"schema_version\":1,\"wrapper\":\"{s}\",\"scope\":\"{s}\",\"member_index\":{d},\"member_offset\":{d},\"wrapper_bytes\":{d},\"deflate_offset\":{d},\"deflate_bytes\":{d},\"deflate_span_kind\":\"header_tail\",\"exact_deflate_bytes\":",
        .{
            context.wrapper,
            scope,
            context.member_index,
            context.member_offset,
            context.wrapper_bytes,
            context.deflate_offset,
            context.wrapper_bytes - context.deflate_offset,
        },
    );
    try printOptionalJson(usize, stdout, context.exact_deflate_bytes);
    try stdout.print(",\"stream_deflate_bytes\":", .{});
    try printOptionalJson(usize, stdout, context.stream_deflate_bytes);
    try stdout.print(",\"stream_output_bytes\":", .{});
    try printOptionalJson(usize, stdout, context.stream_output_bytes);
    try stdout.print(",\"stream_footer_offset\":", .{});
    try printOptionalJson(usize, stdout, context.stream_footer_offset);
    try stdout.print(",\"stream_end_offset\":", .{});
    try printOptionalJson(usize, stdout, context.stream_end_offset);
    try stdout.print(",\"stream_footer_adler32\":", .{});
    try printOptionalJson(u32, stdout, context.stream_footer_adler32);
    try stdout.print(",\"stream_adler32\":", .{});
    try printOptionalJson(u32, stdout, context.stream_adler32);
    try stdout.print(",\"stream_adler32_matches\":", .{});
    try printOptionalBoolJson(stdout, context.stream_adler32_matches);
    try stdout.print(",\"member_deflate_bytes\":", .{});
    try printOptionalJson(usize, stdout, context.member_deflate_bytes);
    try stdout.print(",\"member_output_bytes\":", .{});
    try printOptionalJson(usize, stdout, context.member_output_bytes);
    try stdout.print(",\"member_footer_offset\":", .{});
    try printOptionalJson(usize, stdout, context.member_footer_offset);
    try stdout.print(",\"member_end_offset\":", .{});
    try printOptionalJson(usize, stdout, context.member_end_offset);
    try stdout.print(",\"member_footer_crc32\":", .{});
    try printOptionalJson(u32, stdout, context.member_footer_crc32);
    try stdout.print(",\"member_crc32\":", .{});
    try printOptionalJson(u32, stdout, context.member_crc32);
    try stdout.print(",\"member_crc32_matches\":", .{});
    try printOptionalBoolJson(stdout, context.member_crc32_matches);
    try stdout.print(",\"member_footer_isize\":", .{});
    try printOptionalJson(u32, stdout, context.member_footer_isize);
    try stdout.print(",\"member_isize\":", .{});
    try printOptionalJson(u32, stdout, context.member_isize);
    try stdout.print(",\"member_isize_matches\":", .{});
    try printOptionalBoolJson(stdout, context.member_isize_matches);
    try stdout.print(",\"raw_header\":", .{});
    try printRawHeaderJsonObject(stdout, context.wrapper_bytes - context.deflate_offset, info);
    try stdout.print("}}\n", .{});
}

fn printCodeLengthArray(stdout: *std.Io.Writer, lengths: *const [19]u4) !void {
    try stdout.print("[", .{});
    for (lengths, 0..) |length, i| {
        if (i != 0) try stdout.print(",", .{});
        try stdout.print("{d}", .{length});
    }
    try stdout.print("]", .{});
}

fn printU16Array16(stdout: *std.Io.Writer, values: *const [16]u16) !void {
    try stdout.print("[", .{});
    for (values, 0..) |value, i| {
        if (i != 0) try stdout.print(",", .{});
        try stdout.print("{d}", .{value});
    }
    try stdout.print("]", .{});
}

fn printZlibHeaderJson(stdout: *std.Io.Writer, compressed_len: usize, info: vort.ZlibHeaderInfo) !void {
    try stdout.print(
        "{{\"schema\":\"vort.zlib_header_info\",\"schema_version\":1,\"compressed_bytes\":{d},\"data_offset\":{d},\"cmf\":{d},\"flg\":{d},\"compression_method\":{d},\"window_bits\":{d},\"window_size\":{d},\"fcheck\":{d},\"uses_dictionary\":{},\"flevel\":{d},\"dictionary_id\":",
        .{
            compressed_len,
            info.data_offset,
            info.cmf,
            info.flg,
            info.compression_method,
            info.window_bits,
            info.window_size,
            info.fcheck,
            info.uses_dictionary,
            info.flevel,
        },
    );
    try printOptionalJson(u32, stdout, info.dictionary_id);
    try stdout.print("}}\n", .{});
}

fn printGzipHeaderJson(stdout: *std.Io.Writer, compressed_len: usize, info: vort.GzipHeaderInfo) !void {
    try stdout.print(
        "{{\"schema\":\"vort.gzip_header_info\",\"schema_version\":1,\"compressed_bytes\":{d},\"data_offset\":{d},\"flags\":{d},\"text\":{},\"mtime\":{d},\"xfl\":{d},\"os\":{d},\"extra_present\":{},\"extra_len\":{d},\"extra_hex\":",
        .{
            compressed_len,
            info.data_offset,
            info.flags,
            info.text,
            info.mtime,
            info.xfl,
            info.os,
            info.extra != null,
            if (info.extra) |extra| extra.len else 0,
        },
    );
    if (info.extra) |extra| {
        try stdout.print("\"", .{});
        try printHexInline(stdout, extra);
        try stdout.print("\"", .{});
    } else {
        try stdout.print("null", .{});
    }
    try stdout.print(",\"filename\":", .{});
    try printOptionalJsonBytes(stdout, info.filename);
    try stdout.print(",\"comment\":", .{});
    try printOptionalJsonBytes(stdout, info.comment);
    try stdout.print(",\"header_crc\":", .{});
    try printOptionalJson(u16, stdout, info.header_crc);
    try stdout.print("}}\n", .{});
}

fn printOptionalJsonBytes(stdout: *std.Io.Writer, maybe_bytes: ?[]const u8) !void {
    if (maybe_bytes) |bytes| {
        try printJsonBytes(stdout, bytes);
    } else {
        try stdout.print("null", .{});
    }
}

fn printJsonBytes(stdout: *std.Io.Writer, bytes: []const u8) !void {
    try stdout.print("\"", .{});
    for (bytes) |byte| {
        switch (byte) {
            '"' => try stdout.print("\\\"", .{}),
            '\\' => try stdout.print("\\\\", .{}),
            '\n' => try stdout.print("\\n", .{}),
            '\r' => try stdout.print("\\r", .{}),
            '\t' => try stdout.print("\\t", .{}),
            else => {
                if (byte >= 0x20 and byte <= 0x7e) {
                    try stdout.print("{c}", .{byte});
                } else {
                    try stdout.print("\\u00{x:0>2}", .{byte});
                }
            },
        }
    }
    try stdout.print("\"", .{});
}

fn printValidationFailure(stdout: *std.Io.Writer, label: []const u8, report: vort.ValidationReport) !void {
    try stdout.print("{s}_validation_ok=false mode={s} stage={s} error={s}", .{
        label,
        @tagName(report.mode),
        @tagName(report.stage),
        report.error_name,
    });
    if (report.recoverability_hint != .none) try stdout.print(" hint={s}", .{@tagName(report.recoverability_hint)});
    if (report.frame_index) |value| try stdout.print(" frame_index={d}", .{value});
    if (report.frame_offset) |value| try stdout.print(" frame_offset={d}", .{value});
    if (report.uncompressed_offset) |value| try stdout.print(" uncompressed_offset={d}", .{value});
    if (report.frame_flags) |value| try stdout.print(" frame_flags={d}", .{value});
    if (report.frame_mode.len != 0) try stdout.print(" frame_mode={s}", .{report.frame_mode});
    try stdout.print("\n", .{});
}

fn printValidationJson(stdout: *std.Io.Writer, label: []const u8, report: vort.ValidationReport, stream_len: usize, sidecar_len: ?usize) !void {
    try stdout.print("{{\"schema\":\"vort.validation_report\",\"schema_version\":1,\"target\":\"{s}\",\"ok\":{},\"mode\":\"{s}\",\"stage\":\"{s}\",\"error\":", .{
        label,
        report.ok,
        @tagName(report.mode),
        @tagName(report.stage),
    });
    try std.json.Stringify.value(report.error_name, .{}, stdout);
    try stdout.print(",\"recoverability_hint\":\"{s}\",\"frame_index\":", .{@tagName(report.recoverability_hint)});
    try printOptionalJson(usize, stdout, report.frame_index);
    try stdout.print(",\"frame_offset\":", .{});
    try printOptionalJson(usize, stdout, report.frame_offset);
    try stdout.print(",\"uncompressed_offset\":", .{});
    try printOptionalJson(u64, stdout, report.uncompressed_offset);
    try stdout.print(",\"frame_flags\":", .{});
    try printOptionalJson(u8, stdout, report.frame_flags);
    try stdout.print(",\"frame_mode\":", .{});
    try std.json.Stringify.value(report.frame_mode, .{}, stdout);
    try stdout.print(",\"frame_count\":{d},\"total_uncompressed\":{d},\"combined_checksum\":", .{ report.frame_count, report.total_uncompressed });
    try printOptionalJson(u32, stdout, report.combined_checksum);
    try stdout.print(",\"stream_bytes\":{d},\"sidecar_bytes\":", .{stream_len});
    try printOptionalJson(usize, stdout, sidecar_len);
    try stdout.print("}}\n", .{});
}

fn printOptionalJson(comptime T: type, stdout: *std.Io.Writer, value: ?T) !void {
    if (value) |payload| {
        try stdout.print("{d}", .{payload});
    } else {
        try stdout.print("null", .{});
    }
}

fn printOptionalBoolJson(stdout: *std.Io.Writer, value: ?bool) !void {
    if (value) |payload| {
        try stdout.print("{}", .{payload});
    } else {
        try stdout.print("null", .{});
    }
}

fn parseParserMode(text: ?[]const u8) vort.ParserMode {
    return parseCompressionOptions(text).parser;
}

fn makeDemoLdmPrefix() [33_000]u8 {
    var out: [33_000]u8 = undefined;
    var x: u32 = 0x1234_5678;
    for (&out) |*byte| {
        x = x *% 1664525 +% 1013904223;
        byte.* = @truncate(x >> 24);
    }
    return out;
}

fn parseBlockLen(text: ?[]const u8, default: usize) !usize {
    const value = text orelse return default;
    const parsed = try std.fmt.parseInt(usize, value, 10);
    if (parsed == 0) return error.InvalidBlockPlan;
    return parsed;
}

fn encodeXzFile(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
    stored_only: bool,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const check = try parseXzCheck(args.next());
    const block_size = try parseBlockLen(args.next(), 1024 * 1024);
    var filter_storage: [3]vort.XzFilter = undefined;
    const xz_filters = try filters_cli.parse(args.next(), &filter_storage);
    const dictionary_size = try parseBlockLen(args.next(), 4096);
    const parser = try parseXzParser(args.next());
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(512 * 1024 * 1024));
    defer init.gpa.free(input);
    const options = vort.XzEncodeOptions{
        .check = check,
        .block_size = block_size,
        .dictionary_size = dictionary_size,
        .filters = xz_filters,
    };
    const encoded = if (stored_only)
        try vort.encodeXzStoredAlloc(init.gpa, input, options)
    else switch (parser) {
        .greedy => try vort.encodeXzAlloc(init.gpa, input, options),
        .lazy => try vort.encodeXzLazyAlloc(init.gpa, input, options),
    };
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    try stdout.print("xz_mode={s} input_bytes={d} compressed_bytes={d} blocks={d} dictionary={d} parser={s} path={s}\n", .{
        if (stored_only) "stored" else "compressed",
        input.len,
        encoded.len,
        if (input.len == 0) 0 else 1 + (input.len - 1) / block_size,
        dictionary_size,
        @tagName(parser),
        output_path,
    });
}

fn parseXzCheck(text: ?[]const u8) !vort.XzCheck {
    const value = text orelse return .crc64;
    if (std.mem.eql(u8, value, "none")) return .none;
    if (std.mem.eql(u8, value, "crc32")) return .crc32;
    if (std.mem.eql(u8, value, "crc64")) return .crc64;
    if (std.mem.eql(u8, value, "sha256")) return .sha256;
    return error.InvalidChecksumMode;
}

fn parseXzParser(text: ?[]const u8) !vort.XzEncodeParser {
    const value = text orelse return .greedy;
    if (std.mem.eql(u8, value, "greedy")) return .greedy;
    if (std.mem.eql(u8, value, "lazy")) return .lazy;
    return error.InvalidParserMode;
}

fn parseLzmaSizeMode(text: ?[]const u8) !vort.LzmaSizeMode {
    const value = text orelse return .end_marker;
    if (std.mem.eql(u8, value, "end-marker") or std.mem.eql(u8, value, "unknown")) return .end_marker;
    if (std.mem.eql(u8, value, "known")) return .known;
    return error.InvalidLzmaSizeMode;
}

fn parseTarCompression(text: ?[]const u8) !vort.TarCompression {
    const value = text orelse return .none;
    if (std.mem.eql(u8, value, "none") or std.mem.eql(u8, value, "tar")) return .none;
    if (std.mem.eql(u8, value, "gzip") or std.mem.eql(u8, value, "gz")) return .gzip;
    if (std.mem.eql(u8, value, "bzip2") or std.mem.eql(u8, value, "bz2")) return .bzip2;
    if (std.mem.eql(u8, value, "brotli") or std.mem.eql(u8, value, "br")) return .brotli;
    if (std.mem.eql(u8, value, "compress-z") or std.mem.eql(u8, value, "compress") or std.mem.eql(u8, value, "Z")) return .compress_z;
    if (std.mem.eql(u8, value, "lzma") or std.mem.eql(u8, value, "tlz")) return .lzma;
    if (std.mem.eql(u8, value, "xz")) return .xz;
    if (std.mem.eql(u8, value, "lz4")) return .lz4;
    if (std.mem.eql(u8, value, "lzip") or std.mem.eql(u8, value, "lz")) return .lzip;
    if (std.mem.eql(u8, value, "lzf")) return .lzf;
    if (std.mem.eql(u8, value, "zstandard") or std.mem.eql(u8, value, "zstd")) return .zstandard;
    if (std.mem.eql(u8, value, "lzop") or std.mem.eql(u8, value, "lzo") or std.mem.eql(u8, value, "tzo")) return .lzop;
    return error.UnknownTarCompression;
}

fn parseCabCompression(text: ?[]const u8) !vort.CabCompression {
    const value = text orelse return .mszip;
    if (std.mem.eql(u8, value, "stored") or std.mem.eql(u8, value, "none")) return .none;
    if (std.mem.eql(u8, value, "mszip")) return .mszip;
    if (std.mem.eql(u8, value, "quantum") or std.mem.eql(u8, value, "qtm")) return .quantum;
    if (std.mem.eql(u8, value, "lzx")) return .lzx;
    return error.UnsupportedCabinetCompression;
}

fn parseCabWindowBits(text: ?[]const u8, compression: vort.CabCompression) !u5 {
    const value = text orelse return if (compression == .quantum) 18 else 15;
    const window_bits = try std.fmt.parseInt(u5, value, 10);
    const minimum: u5 = if (compression == .quantum) 10 else 15;
    if (window_bits < minimum or window_bits > 21) return error.InvalidCabinetOptions;
    return window_bits;
}

fn parseCabQuantumLevel(text: ?[]const u8) !u4 {
    const value = text orelse return 1;
    const level = try std.fmt.parseInt(u4, value, 10);
    if (level < 1 or level > 7) return error.InvalidCabinetOptions;
    return level;
}

fn parseSeekabilityTier(text: ?[]const u8) !vort.SeekabilityTier {
    const value = text orelse return error.MissingCorpusPath;
    if (std.mem.eql(u8, value, "seek-fast") or std.mem.eql(u8, value, "seek_fast")) return .seek_fast;
    if (std.mem.eql(u8, value, "balanced")) return .balanced;
    if (std.mem.eql(u8, value, "ratio")) return .ratio;
    return error.InvalidSeekabilityTier;
}

fn parseIterations(text: ?[]const u8, default: usize) !usize {
    const value = text orelse return default;
    const parsed = try std.fmt.parseInt(usize, value, 10);
    if (parsed == 0) return error.InvalidBlockPlan;
    return parsed;
}

fn parseOptionalLimit(text: ?[]const u8) !?usize {
    const value = text orelse return null;
    return try std.fmt.parseInt(usize, value, 10);
}

fn parseBrotliStoredOptions(window_bits_text: ?[]const u8, metadata: ?[]const u8) !vort.BrotliStoredStreamOptions {
    const value = window_bits_text orelse return .{ .metadata = metadata orelse "" };
    const window_bits = try std.fmt.parseInt(u5, value, 10);
    if (window_bits < 10 or window_bits > 24) return error.InvalidBlockPlan;
    return .{ .window_bits = window_bits, .metadata = metadata orelse "" };
}

fn parseOptionalMemberIndex(text: ?[]const u8) !usize {
    const value = text orelse return 0;
    return try std.fmt.parseInt(usize, value, 10);
}

fn parseSidecarValidationMode(text: ?[]const u8) !vort.SidecarValidationMode {
    const value = text orelse return .full;
    if (std.mem.eql(u8, value, "metadata") or std.mem.eql(u8, value, "fast")) return .metadata;
    if (std.mem.eql(u8, value, "full")) return .full;
    return error.InvalidSidecarValidationMode;
}

const ValidationOutputFormat = enum { text, json };

fn parseValidationOutputFormat(text: ?[]const u8) !ValidationOutputFormat {
    const value = text orelse return .text;
    if (std.mem.eql(u8, value, "text")) return .text;
    if (std.mem.eql(u8, value, "json")) return .json;
    return error.InvalidSidecarValidationMode;
}

fn parseHeaderInspectOutputFormat(text: ?[]const u8) !HeaderInspectOutputFormat {
    const value = text orelse return .text;
    if (std.mem.eql(u8, value, "text")) return .text;
    if (std.mem.eql(u8, value, "json")) return .json;
    return error.InvalidSidecarValidationMode;
}

fn parseCompressionOptions(text: ?[]const u8) vort.CompressionOptions {
    const value = text orelse return vort.optionsForCompressionLevel(.default);
    if (std.mem.eql(u8, value, "fastest")) return vort.optionsForCompressionLevel(.fastest);
    if (std.mem.eql(u8, value, "fast")) return vort.optionsForCompressionLevel(.fast);
    if (std.mem.eql(u8, value, "hash")) return .{ .parser = .hash };
    if (std.mem.eql(u8, value, "default")) return vort.optionsForCompressionLevel(.default);
    if (std.mem.eql(u8, value, "best")) return vort.optionsForCompressionLevel(.best);
    if (std.mem.eql(u8, value, "filtered")) return .{ .strategy = .filtered };
    if (std.mem.eql(u8, value, "huffman") or std.mem.eql(u8, value, "huffman-only")) return .{ .strategy = .huffman_only };
    if (std.mem.eql(u8, value, "rle")) return .{ .strategy = .rle };
    if (std.mem.eql(u8, value, "greedy")) return .{ .parser = .greedy };
    if (std.mem.eql(u8, value, "lazy")) return .{ .parser = .lazy };
    if (std.mem.eql(u8, value, "optimal")) return .{ .parser = .optimal };
    return vort.optionsForCompressionLevel(.default);
}

fn parseZstdNativeSelection(text: ?[]const u8) !vort.ZstdNativeFrameSelection {
    const value = text orelse return .auto;
    if (std.mem.eql(u8, value, "auto")) return .auto;
    if (std.mem.eql(u8, value, "raw_or_rle") or std.mem.eql(u8, value, "raw-rle")) return .raw_or_rle;
    if (std.mem.eql(u8, value, "literal_only") or std.mem.eql(u8, value, "literal-only")) return .literal_only;
    if (std.mem.eql(u8, value, "fast_compressed") or std.mem.eql(u8, value, "fast-compressed")) return .fast_compressed;
    return error.InvalidZstdNativeSelection;
}

fn parseOptionalBool(text: ?[]const u8, default: bool) !bool {
    const value = text orelse return default;
    if (std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "1") or std.mem.eql(u8, value, "yes")) return true;
    if (std.mem.eql(u8, value, "false") or std.mem.eql(u8, value, "0") or std.mem.eql(u8, value, "no")) return false;
    return error.InvalidBoolean;
}
