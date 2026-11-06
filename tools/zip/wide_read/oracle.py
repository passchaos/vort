"""Independent ZIP metadata and bounded unzip/zipfile content receipts."""
from dataclasses import asdict, dataclass
import hashlib
from pathlib import Path
import struct
import subprocess
import zipfile
import zlib

CHUNK = 65536
REPEATED = b"R" * CHUNK


def require(ok, detail):
    if not ok:
        raise AssertionError(detail)


@dataclass
class Metadata:
    archive_size: int
    compressed_offset: int
    compressed_size: int
    uncompressed_size: int
    crc32: int
    method: int
    flags: int
    central_offset: int
    name: str

    def report(self):
        return asdict(self)


def metadata(path, count):
    with zipfile.ZipFile(path, "r", allowZip64=True) as archive:
        entries = archive.infolist()
        require(len(entries) == 1, "single ZIP entry")
        info = entries[0]
        require(info.filename == "wide.bin" and info.file_size == count, "ZIP metadata name/Count")
        with Path(path).open("rb") as source:
            source.seek(info.header_offset)
            fixed = source.read(30)
            require(len(fixed) == 30 and fixed[:4] == b"PK\x03\x04", "actual local header")
            fields = struct.unpack("<IHHHHHIIIHH", fixed)
            require(fields[2] == info.flag_bits and fields[3] == info.compress_type, "local/central method and flags")
            name = source.read(fields[9])
            require(name == b"wide.bin", "actual local name")
            extra = source.read(fields[10])
            require(len(extra) == fields[10], "local extra extent")
        return Metadata(Path(path).stat().st_size, info.header_offset + 30 + fields[9] + fields[10],
                        info.compress_size, info.file_size, info.CRC, info.compress_type,
                        info.flag_bits, archive.start_dir, info.filename)


def check_stream(source, count, crc, callback=None):
    total, checksum, calls = 0, 0, 0
    next_progress = 256 * 1024 * 1024
    while data := source.read(CHUNK):
        require(data == REPEATED[:len(data)], "independent decoded content")
        total += len(data)
        checksum = zlib.crc32(data, checksum)
        calls += 1
        require(total <= count, "independent excess output")
        if callback and total >= next_progress:
            callback(dict(output_written=total, crc32=checksum & 0xFFFFFFFF, calls=calls))
            next_progress = total + 256 * 1024 * 1024
    require(total == count and checksum & 0xFFFFFFFF == crc, "independent final Count/CRC")
    return dict(output_written=total, crc32=checksum & 0xFFFFFFFF, calls=calls,
                completed=True, all_output_bytes_checked=True, output_chunk_bytes=CHUNK)


def unzip(path, entry, executable, callback=None):
    command = [str(executable), "-p", str(path), entry.name]
    with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE) as process:
        try:
            receipt = check_stream(process.stdout, entry.uncompressed_size, entry.crc32, callback)
            status = process.wait()
        except BaseException:
            process.kill()
            process.wait()
            raise
        stderr = process.stderr.read(CHUNK)
    require(status == 0, ("Info-ZIP failure", status, stderr.decode(errors="replace")))
    return dict(receipt, command=command, exit_code=status, input_read=entry.compressed_size,
                oracle="Info-ZIP unzip -p", eof=True)


def stored_archive(path, count):
    crc, accepted, calls = 0, 0, 0
    info = zipfile.ZipInfo("wide.bin", (1980, 1, 1, 0, 0, 0))
    info.compress_type = zipfile.ZIP_STORED
    with zipfile.ZipFile(path, "w", allowZip64=True) as archive:
        with archive.open(info, "w", force_zip64=True) as sink:
            while accepted < count:
                data = REPEATED[:min(CHUNK, count - accepted)]
                require(sink.write(data) == len(data), "real stored source receipt")
                accepted += len(data)
                crc = zlib.crc32(data, crc)
                calls += 1
    return dict(actual_source_bytes=accepted, crc32=crc & 0xFFFFFFFF, calls=calls,
                zip_bytes=Path(path).stat().st_size, stored_bytes_physically_written=True)


def stored_decode(path, entry, callback=None):
    with zipfile.ZipFile(path, "r", allowZip64=True) as archive:
        with archive.open(entry.name) as source:
            receipt = check_stream(source, entry.uncompressed_size, entry.crc32, callback)
    return dict(receipt, input_read=entry.compressed_size, oracle="Python zipfile stored", eof=True)


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as source:
        while data := source.read(CHUNK):
            digest.update(data)
    return digest.hexdigest()
