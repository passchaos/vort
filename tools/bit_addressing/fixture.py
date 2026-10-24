"""Create and inspect real sparse RFC Brotli input without reading hole payloads."""
import hashlib
import json
import os
from pathlib import Path

METADATA_LENGTHS = [16 * 1024 * 1024] * 32 + [1]


def sha(data):
    return hashlib.sha256(data).hexdigest()


class Bits:
    def __init__(self):
        self.data = bytearray()
        self.position = 0

    def put(self, value, count):
        assert 0 <= value < 1 << count
        for index in range(count):
            if self.position // 8 == len(self.data):self.data.append(0)
            self.data[self.position // 8] |= ((value >> index) & 1) << (self.position % 8)
            self.position += 1

    def align(self):
        if self.position % 8:self.put(0, 8 - self.position % 8)


def get(data, start, count):
    assert start + count <= len(data) * 8
    return sum(((data[(start + index) // 8] >> ((start + index) % 8)) & 1) << index for index in range(count))


def window(data):
    if get(data, 0, 1) == 0:return {"window_bits": 16, "header_bits": 1, "large_window": False}
    upper = get(data, 1, 3)
    if upper:return {"window_bits": 17 + upper, "header_bits": 4, "large_window": False}
    lower = get(data, 4, 3)
    if lower != 1:return {"window_bits": 17 if lower == 0 else 8 + lower, "header_bits": 7, "large_window": False}
    raise AssertionError("standalone tail uses reserved Large Window marker")


def compressed_prefix(data):
    info = window(data)
    bit = info["header_bits"]
    last = bool(get(data, bit, 1));bit += 1
    if last:
        assert get(data, bit, 1) == 0, "tail is final-empty"
        bit += 1
    nibbles = get(data, bit, 2) + 4;bit += 2
    assert nibbles < 7, "tail starts with metadata"
    length = get(data, bit, nibbles * 4) + 1;bit += nibbles * 4
    if not last:
        assert get(data, bit, 1) == 0, "tail starts with stored block"
        bit += 1
    return {**info, "final_compressed": last, "decoded_bytes": length,
            "compressed_header_start_bit": bit, "standalone_wire_bytes": len(data)}


def stat(path):
    s = path.stat()
    return {"file": str(path), "logical_bytes": s.st_size, "allocated_bytes": s.st_blocks * 512,
            "inode": s.st_ino, "mtime_ns": s.st_mtime_ns, "device": s.st_dev}


def write_prefix(path):
    records, regions = [], []
    cursor = 0
    with path.open("xb") as out:
        for index, length in enumerate(METADATA_LENGTHS):
            bits = Bits()
            if index == 0:bits.put(0, 1)  # Actual RFC WBITS=16.
            bits.put(0, 1);bits.put(3, 2);bits.put(0, 1)
            width = (length - 1).bit_length() // 8 + 1 if length > 1 else 1
            width = min(width, 3)
            bits.put(width, 2);bits.put(length - 1, width * 8);bits.align()
            header = bytes(bits.data)
            out.seek(cursor);out.write(header)
            regions.append({"offset": cursor, "hex": header.hex(), "sha256": sha(header)})
            records.append({"index": index, "header_offset": cursor, "header_bytes": len(header),
                            "payload_offset": cursor + len(header), "metadata_bytes": length,
                            "header_start_bit": cursor * 8 + (1 if index == 0 else 0)})
            cursor += len(header) + length
        out.truncate(cursor)
    assert cursor == 536871043
    return records, regions, cursor


def variant(path, regions, prefix_bytes, tail, tail_start_bit, tail_info):
    with path.open("xb") as out:
        for region in regions:
            out.seek(region["offset"]);out.write(bytes.fromhex(region["hex"]))
        out.seek(prefix_bytes);out.write(tail)
        out.truncate(prefix_bytes + len(tail))
    return {**stat(path), "write_regions": regions + [{"offset": prefix_bytes, "hex": tail.hex(), "sha256": sha(tail)}],
            "tail_start_bit": tail_start_bit, "tail": tail_info,
            "whole_file_sha256": None, "whole_file_sha256_note": "payload holes were not scanned for a whole-file digest"}


def generate(directory, standalone_tail):
    directory = Path(directory);directory.mkdir(parents=True, exist_ok=True)
    assert not (directory / "fixture.json").exists(), "large fixture manifest is frozen once"
    prefix = directory / "metadata-prefix.br"
    records, regions, prefix_bytes = write_prefix(prefix)
    metadata = variant(directory / "metadata-only.br", regions, prefix_bytes, b"\x03", prefix_bytes * 8,
                       {"final_empty": True, "used_bits": 2, "zero_padding_bits": 6, "expected_output_bytes": 0})
    small = Path(standalone_tail).read_bytes();info = compressed_prefix(small)
    assert info["window_bits"] == 16 and info["header_bits"] == 1 and not info["large_window"]
    assert info["decoded_bytes"] == 64 and info["final_compressed"], "require one final compressed tail"
    body = Bits()
    # Remove only the independently parsed real WBITS bit. Preserve every
    # remaining source bit, including its existing zero final-byte padding.
    for bit in range(info["header_bits"], len(small) * 8):body.put(get(small, bit, 1), 1)
    body.align()
    tail = variant(directory / "compressed-tail.br", regions, prefix_bytes, bytes(body.data), prefix_bytes * 8,
                   {**info, "standalone_sha256": sha(small), "removed_wbits_bits": info["header_bits"],
                    "copied_source_bits": len(small) * 8 - info["header_bits"], "added_zero_alignment_bits": 1,
                    "absolute_compressed_header_start_bit": prefix_bytes * 8 + info["compressed_header_start_bit"] - info["header_bits"],
                    "expected_output_bytes": 64, "expected_output_sha256": sha(b"R" * 64),
                    "fast_kernel_invocation_observed": False,
                    "scope": "valid compressed-header tail after >2^32 bit address; public profile is not a fast-kernel invocation counter"})
    assert metadata["logical_bytes"] == 536871044
    manifest = {"schema": "vort-real-wide-bit-fixture-v1", "window_bits": 16, "large_window": False,
                "metadata_bytes": sum(METADATA_LENGTHS), "metadata_blocks": len(records),
                "prefix": stat(prefix), "prefix_generated_once": True, "prefix_bytes": prefix_bytes,
                "metadata_headers": records, "metadata_only": metadata, "compressed_tail": tail,
                "sparse_variant_construction": "one logical prefix geometry; each independent variant writes only the same33headers and its own tail; no huge payload copy",
                "whole_file_sha256": None}
    (directory / "fixture.json").write_text(json.dumps(manifest, indent=2) + "\n")
    for key in ("metadata_only", "compressed_tail"):verify(manifest[key], manifest["metadata_headers"])
    return manifest


def verify(spec, headers):
    path = Path(spec["file"])
    assert path.stat().st_size == spec["logical_bytes"]
    fd = os.open(path, os.O_RDONLY)
    try:
        for region in spec["write_regions"]:
            data = os.pread(fd, len(bytes.fromhex(region["hex"])), region["offset"])
            assert sha(data) == region["sha256"] and data.hex() == region["hex"]
        for index, record in enumerate(headers):
            data = os.pread(fd, record["header_bytes"], record["header_offset"])
            bit = 1 if index == 0 else 0
            assert get(data, bit, 1) == 0;bit += 1
            assert get(data, bit, 2) == 3;bit += 2
            assert get(data, bit, 1) == 0;bit += 1
            width = get(data, bit, 2);bit += 2
            assert width in (1, 2, 3)
            assert get(data, bit, width * 8) + 1 == record["metadata_bytes"]
            assert (bit + width * 8 + 7) // 8 == record["header_bytes"]
        # Linux reports allocated ranges; validate their small physical pages,
        # and use the filesystem's guaranteed zero-read sparse holes elsewhere.
        position, extents = 0, []
        while position < spec["logical_bytes"]:
            try:start = os.lseek(fd, position, os.SEEK_DATA)
            except OSError as error:
                if error.errno == 6:break
                raise
            end = min(os.lseek(fd, start, os.SEEK_HOLE), spec["logical_bytes"])
            assert end - start <= 64 * 1024, "unexpected resident payload extent"
            data = bytearray(os.pread(fd, end - start, start))
            expected = bytearray(len(data))
            for region in spec["write_regions"]:
                raw = bytes.fromhex(region["hex"]);lo = max(start, region["offset"]);hi = min(end, region["offset"] + len(raw))
                if lo < hi:expected[lo - start:hi - start] = raw[lo - region["offset"]:hi - region["offset"]]
            assert data == expected, "physical page contains unrecorded nonzero data"
            extents.append({"offset": start, "bytes": end - start, "sha256": sha(data)})
            position = end
        assert len(extents) <= 34
        return {**stat(path), "all_written_headers_and_tail_verified": True, "allocated_extents": extents,
                "unwritten_sparse_holes": "zero by Linux sparse file read semantics", "whole_file_sha256": None}
    finally:os.close(fd)
