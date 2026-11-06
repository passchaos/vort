"""Independent ZIP64 structure and Python zipfile metadata checks."""

from __future__ import annotations

from dataclasses import asdict, dataclass
from pathlib import Path
import struct
import zipfile

U32_MAX = (1 << 32) - 1
METHODS = {"deflate": 8, "zstd": 93}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read_at(source, offset: int, length: int) -> bytes:
    require(offset >= 0 and length >= 0, "negative ZIP extent")
    source.seek(offset)
    data = source.read(length)
    require(len(data) == length, f"truncated ZIP structure at {offset}")
    return data


def extra_fields(data: bytes) -> dict[int, bytes]:
    fields = {}
    offset = 0
    while offset < len(data):
        require(len(data) - offset >= 4, "truncated ZIP extra header")
        field_id, size = struct.unpack_from("<HH", data, offset)
        offset += 4
        require(size <= len(data) - offset, "truncated ZIP extra payload")
        require(field_id not in fields, "duplicate ZIP extra field")
        fields[field_id] = data[offset:offset + size]
        offset += size
    return fields


@dataclass(frozen=True)
class ZipMetadata:
    archive_size: int
    compressed_offset: int
    compressed_size: int
    uncompressed_size: int
    crc32: int
    method: int
    flags: int
    descriptor_offset: int
    central_offset: int
    central_size: int
    zip64_eocd_offset: int
    local_version_needed: int
    central_version_needed: int

    def report(self) -> dict:
        return dict(
            asdict(self), entry_name="wide.bin", entries=1,
            local_zip64_sentinels_checked=True,
            local_zip64_zero_placeholders_checked=True,
            signed_zip64_descriptor_checked=True,
            central_zip64_metadata_checked=True,
            zip64_eocd_and_locator_checked=True,
            legacy_eocd_sentinels_checked=True,
            python_zipfile_metadata_checked=True,
            archive_extents_contiguous=True,
        )


def inspect_zip(path: Path, format_name: str, count: int) -> ZipMetadata:
    """Check every record and its extent without decompressing via zipfile."""
    archive_size = path.stat().st_size
    require(archive_size >= 22 + 20 + 56 + 46 + 30 + 24, "ZIP is too short")
    with path.open("rb") as source:
        # The probe emits no archive comment, so the fixed EOCD must end at EOF.
        eocd_offset = archive_size - 22
        end = struct.unpack("<IHHHHIIH", read_at(source, eocd_offset, 22))
        require(end == (0x06054B50, 0, 0, 0xFFFF, 0xFFFF,
                        U32_MAX, U32_MAX, 0), "ZIP64 legacy EOCD mismatch")
        locator_offset = eocd_offset - 20
        locator = struct.unpack("<IIQI", read_at(source, locator_offset, 20))
        require(locator[0] == 0x07064B50 and locator[1] == 0 and locator[3] == 1,
                "ZIP64 locator signature or disk metadata mismatch")
        zip64_offset = locator[2]
        require(zip64_offset + 56 == locator_offset, "ZIP64 EOCD extent mismatch")
        end64 = struct.unpack("<IQHHIIQQQQ", read_at(source, zip64_offset, 56))
        require(end64[0] == 0x06064B50 and end64[1] == 44,
                "ZIP64 EOCD signature or size mismatch")
        require(end64[2] >= 45 and end64[3] >= 45, "ZIP64 EOCD version mismatch")
        require(end64[4:8] == (0, 0, 1, 1), "ZIP64 EOCD entry or disk mismatch")
        central_size, central_offset = end64[8:10]
        require(46 <= central_size <= 46 + 3 * 0xFFFF,
                "single-entry central directory has an invalid size")
        require(central_offset + central_size == zip64_offset,
                "central directory extent mismatch")
        central = read_at(source, central_offset, central_size)
        header = struct.unpack_from("<IHHHHHHIIIHHHHHII", central)
        require(header[0] == 0x02014B50, "central header signature mismatch")
        version_needed, flags, method = header[2:5]
        require(version_needed >= (63 if format_name == "zstd" else 45),
                "central version does not support the requested ZIP64 method")
        require(method == METHODS[format_name], "central compression method mismatch")
        require(flags & 8 and not flags & (1 | 0x40), "descriptor/encryption flags mismatch")
        require(header[8:10] == (U32_MAX, U32_MAX) and header[16] == U32_MAX,
                "central ZIP64 sentinels mismatch")
        name_len, extra_len, comment_len = header[10:13]
        require(header[13] == 0, "central entry belongs to another disk")
        require(46 + name_len + extra_len + comment_len == central_size,
                "central directory has trailing bytes or another entry")
        require(central[46:46 + name_len] == b"wide.bin", "central filename mismatch")
        central_extra = extra_fields(central[46 + name_len:46 + name_len + extra_len])
        require(1 in central_extra and len(central_extra[1]) == 24,
                "central ZIP64 size/offset extra mismatch")
        uncompressed, compressed, local_offset = struct.unpack("<QQQ", central_extra[1])
        require(uncompressed == count, "central uncompressed size mismatch")
        require(compressed > 0 and local_offset == 0, "compressed size or local offset mismatch")
        local = struct.unpack("<IHHHHHIIIHH", read_at(source, local_offset, 30))
        require(local[0] == 0x04034B50, "local header signature mismatch")
        require(local[1] == version_needed and local[2:6] == header[3:7],
                "local/central version, flags, method or timestamp mismatch")
        require(local[6:9] == (0, U32_MAX, U32_MAX),
                "local CRC or ZIP64 size sentinels mismatch")
        local_name_len, local_extra_len = local[9:11]
        local_tail = read_at(source, 30, local_name_len + local_extra_len)
        require(local_tail[:local_name_len] == b"wide.bin", "local filename mismatch")
        local_extra = extra_fields(local_tail[local_name_len:])
        require(local_extra.get(1) == bytes(16), "local ZIP64 zero placeholders mismatch")
        compressed_offset = 30 + local_name_len + local_extra_len
        descriptor_offset = compressed_offset + compressed
        require(descriptor_offset + 24 == central_offset,
                "compressed member/descriptor/central extents mismatch")
        descriptor = struct.unpack("<IIQQ", read_at(source, descriptor_offset, 24))
        crc = header[7]
        require(descriptor == (0x08074B50, crc, compressed, uncompressed),
                "signed ZIP64 data descriptor mismatch")

    # zipfile is an independent metadata oracle even when method 93 extraction
    # is unsupported by the installed Python version.
    with zipfile.ZipFile(path, "r", allowZip64=True) as archive:
        entries = archive.infolist()
        require(len(entries) == 1 and archive.comment == b"", "zipfile entry/comment mismatch")
        info = entries[0]
        require(info.filename == "wide.bin" and not info.is_dir(), "zipfile filename mismatch")
        require((info.compress_type, info.file_size, info.compress_size, info.CRC,
                 info.header_offset, info.flag_bits, info.extract_version) ==
                (method, uncompressed, compressed, crc, 0, flags, version_needed),
                "zipfile metadata differs from independently parsed records")
        require(archive.start_dir == central_offset, "zipfile central directory offset mismatch")

    return ZipMetadata(archive_size, compressed_offset, compressed, uncompressed,
                       crc, method, flags, descriptor_offset, central_offset,
                       central_size, zip64_offset, local[1], version_needed)
