#!/usr/bin/env python3
"""Independent Snappy Framed/Xerial/Hadoop stream and memory contracts.

Ordinary raw blocks come from the system libsnappy C ABI. Directed token
fixtures and framing envelopes use transparent wire recipes and are checked
by libsnappy and snappy-java, including CRC-32C on native Framed streams.
This is correctness evidence; it makes no throughput or RSS comparison.
"""
from __future__ import annotations

import argparse
import ast
from collections import Counter
import ctypes as C
import ctypes.util
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import random
import shutil
import struct
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
IDENTIFIER = b"\xff\x06\0\0sNaPpY"
XERIAL_HEADER = b"\x82SNAPPY\0" + struct.pack(">II", 1, 1)


def require(value, context):
    if not value:
        raise AssertionError(context)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def command(*args, check=True):
    r = subprocess.run([str(a) for a in args], capture_output=True, cwd=ROOT)
    if check and r.returncode:
        raise RuntimeError(f"command failed: {args}\n{r.stderr.decode(errors='replace')}")
    return r


def cpu():
    for line in Path("/proc/cpuinfo").read_text().splitlines():
        if line.startswith("model name"):
            return line.split(":", 1)[1].strip()
    return "unknown"


def sources():
    paths = [ROOT / "src/snappy.zig", ROOT / "src/snappy_framing.zig", ROOT / "src/core.zig",
             ROOT / "src/checksum.zig", ROOT / "src/io/working_allocator.zig",
             *(ROOT / "src/snappy").rglob("*.zig"), *(ROOT / "src/snappy_framing").rglob("*.zig")]
    rows = [{"path": str(p.relative_to(ROOT)), "sha256": sha(p.read_bytes())} for p in sorted(paths)]
    return {"files": rows, "sha256": sha(json.dumps(rows, sort_keys=True).encode())}


class Snappy:
    def __init__(self, path=None):
        self.path = str(path or ctypes.util.find_library("snappy"))
        self.lib = C.CDLL(self.path)
        self.lib.snappy_max_compressed_length.argtypes = [C.c_size_t]
        self.lib.snappy_max_compressed_length.restype = C.c_size_t
        for name in ("snappy_compress", "snappy_uncompress"):
            fn = getattr(self.lib, name)
            fn.argtypes = [C.c_void_p, C.c_size_t, C.c_void_p, C.POINTER(C.c_size_t)]
            fn.restype = C.c_int
        self.lib.snappy_uncompressed_length.argtypes = [C.c_void_p, C.c_size_t, C.POINTER(C.c_size_t)]
        self.lib.snappy_uncompressed_length.restype = C.c_int
        self.lib.snappy_validate_compressed_buffer.argtypes = [C.c_void_p, C.c_size_t]
        self.lib.snappy_validate_compressed_buffer.restype = C.c_int

    def encode(self, data):
        out = C.create_string_buffer(self.lib.snappy_max_compressed_length(len(data)))
        size = C.c_size_t(len(out))
        require(self.lib.snappy_compress(data, len(data), out, C.byref(size)) == 0, "libsnappy encode")
        return out.raw[:size.value]

    def decode(self, data):
        require(self.lib.snappy_validate_compressed_buffer(data, len(data)) == 0, "libsnappy raw validation")
        size = C.c_size_t()
        require(self.lib.snappy_uncompressed_length(data, len(data), C.byref(size)) == 0, "libsnappy raw size")
        out = C.create_string_buffer(max(1, size.value))
        actual = C.c_size_t(size.value)
        require(self.lib.snappy_uncompress(data, len(data), out, C.byref(actual)) == 0 and actual.value == size.value, "libsnappy raw decode")
        return out.raw[:actual.value]

    def valid(self, data):
        return self.lib.snappy_validate_compressed_buffer(data, len(data)) == 0


def varint(n, width=None):
    out = bytearray()
    while n >= 128:
        out.append((n & 127) | 128)
        n >>= 7
    out.append(n)
    if width is not None:
        while len(out) < width:
            out[-1] |= 128
            out.append(0)
    return bytes(out)


def literal(data, width=None):
    require(data, "literal must be nonempty")
    n = len(data) - 1
    if width is None and n < 60:
        return bytes([n << 2]) + data
    width = width or max(1, (n.bit_length() + 7) // 8)
    require(1 <= width <= 4, "literal length width")
    return bytes([(59 + width) << 2]) + n.to_bytes(width, "little") + data


def copy(kind, offset, length):
    if kind == 1:
        require(1 <= offset <= 2047 and 4 <= length <= 11, "COPY1 range")
        return bytes([1 | ((length - 4) << 2) | ((offset >> 8) << 5), offset & 255])
    require(kind in (2, 4) and 1 <= length <= 64 and offset > 0, "COPY2/4 range")
    return bytes([((length - 1) << 2) | (2 if kind == 2 else 3)]) + offset.to_bytes(kind, "little")


def directed(ref, prefix, copies, width=None, header_width=None):
    expected = bytearray(prefix)
    tokens = bytearray(literal(prefix, width))
    for kind, distance, length in copies:
        tokens.extend(copy(kind, distance, length))
        for _ in range(length):
            expected.append(expected[-distance])
    raw = varint(len(expected), header_width) + tokens
    require(ref.decode(raw) == expected, "directed token fixture independently decoded")
    return raw, bytes(expected)


def raw_plan(raw):
    index, decoded, shift = 0, 0, 0
    while True:
        byte = raw[index]
        index += 1
        decoded |= (byte & 127) << shift
        if byte < 128:
            break
        shift += 7
    written, maximum = 0, 0
    while index < len(raw):
        tag = raw[index]
        index += 1
        kind = tag & 3
        if kind == 0:
            n = tag >> 2
            if n >= 60:
                width = n - 59
                n = int.from_bytes(raw[index:index + width], "little")
                index += width
            written += n + 1
            index += n + 1
        else:
            width = {1: 1, 2: 2, 3: 4}[kind]
            distance = int.from_bytes(raw[index:index + width], "little")
            if kind == 1:
                distance |= (tag & 224) << 3
                length = 4 + ((tag >> 2) & 7)
            else:
                length = 1 + (tag >> 2)
            index += width
            require(0 < distance <= written, "independent token offset invariant")
            maximum = max(maximum, distance)
            written += length
    require(index == len(raw) and written == decoded, "independent token/length plan")
    return decoded, maximum


def crc32c(data):
    crc = 0xFFFFFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = (crc >> 1) ^ (0x82F63B78 if crc & 1 else 0)
    return crc ^ 0xFFFFFFFF


def masked_crc(data):
    crc = crc32c(data)
    return ((crc >> 15) | ((crc << 17) & 0xFFFFFFFF)) + 0xA282EAD8 & 0xFFFFFFFF


def native_chunk(kind, payload):
    require(len(payload) <= 0xFFFFFF, "Framed 24-bit length")
    return bytes([kind]) + len(payload).to_bytes(3, "little") + payload


def frame(format, chunks, *, stored=False, skip=b"", group_sizes=None):
    if format == "native":
        result = bytearray(IDENTIFIER)
        if skip:
            result.extend(native_chunk(0xFE, skip))
        for raw, plain in chunks:
            body = plain if stored else raw
            result.extend(native_chunk(1 if stored else 0, struct.pack("<I", masked_crc(plain)) + body))
        return bytes(result)
    if format == "xerial":
        return XERIAL_HEADER + b"".join(struct.pack(">I", len(raw)) + raw for raw, _ in chunks)
    result = bytearray()
    sizes = group_sizes or ([len(chunks)] if chunks else [])
    start = 0
    for count in sizes:
        group = chunks[start:start + count]
        require(len(group) == count and sum(len(p) for _, p in group) > 0, "Hadoop positive outer pledge")
        result.extend(struct.pack(">I", sum(len(p) for _, p in group)))
        for raw, _ in group:
            result.extend(struct.pack(">I", len(raw)) + raw)
        start += count
    require(start == len(chunks), "Hadoop group recipe")
    return bytes(result)


JAVA = r'''import java.io.*;
import java.nio.file.*;
import org.xerial.snappy.*;
public final class StreamContractReference {
  public static void main(String[] a) throws Exception {
    byte[] wire=Files.readAllBytes(Path.of(a[1]));
    ByteArrayOutputStream output=new ByteArrayOutputStream();
    if(a[0].equals("hadoop")) {
      DataInputStream input=new DataInputStream(new ByteArrayInputStream(wire));
      while(input.available()>0) {
        int expected=input.readInt(),written=0;
        if(expected<=0) throw new IOException("outer pledge");
        while(written<expected) {
          int n=input.readInt(); if(n<=0) throw new IOException("chunk size");
          byte[] raw=input.readNBytes(n); if(raw.length!=n) throw new EOFException();
          byte[] plain=Snappy.uncompress(raw); output.write(plain); written+=plain.length;
        }
        if(written!=expected) throw new IOException("outer size mismatch");
      }
    } else {
      InputStream input=a[0].equals("native") ? new SnappyFramedInputStream(new ByteArrayInputStream(wire)) : new SnappyInputStream(new ByteArrayInputStream(wire));
      try(input) { input.transferTo(output); }
    }
    Files.write(Path.of(a[2]),output.toByteArray());
  }
}
'''


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--probe", type=Path, help="native probe (codec=src/snappy.zig)")
    p.add_argument("--framing-probe", type=Path, help="Xerial/Hadoop probe (codec=src/snappy_framing.zig)")
    p.add_argument("--format", choices=("all", "native", "xerial", "hadoop"), default="all")
    p.add_argument("--libsnappy", type=Path)
    p.add_argument("--snappy-java", type=Path)
    p.add_argument("--report", type=Path)
    p.add_argument("--work-dir", type=Path)
    p.add_argument("--prepare-only", action="store_true")
    args = p.parse_args()
    formats = ("native", "xerial", "hadoop") if args.format == "all" else (args.format,)
    if not args.prepare_only:
        require("native" not in formats or args.probe, "--probe required for native")
        require(not any(f != "native" for f in formats) or args.framing_probe, "--framing-probe required")
    probes = {"native": args.probe.resolve() if args.probe else None,
              "xerial": args.framing_probe.resolve() if args.framing_probe else None,
              "hadoop": args.framing_probe.resolve() if args.framing_probe else None}
    before, driver_sha = sources(), sha(Path(__file__).read_bytes())
    ref = Snappy(args.libsnappy)
    temporary = tempfile.TemporaryDirectory(prefix="vort-snappy-contract-") if args.work_dir is None else None
    work = Path(temporary.name) if temporary else args.work_dir.resolve()
    work.mkdir(parents=True, exist_ok=True)
    jar = args.snappy_java or next((q for q in (Path("/tmp/snappy-java-1.1.10.7.jar"), Path("/tmp/vort-snappy-java-1.1.10.7.jar")) if q.is_file()), None)
    java, javac = shutil.which("java"), shutil.which("javac")
    java_cp = None
    if jar and java and javac:
        source = work / "StreamContractReference.java"
        source.write_text(JAVA)
        command(javac, "-cp", jar, "-d", work, source)
        java_cp = str(work) + ":" + str(jar)
    require(java_cp, "snappy-java and Java required for independent envelope/CRC decode")
    rows, corpus, cases = [], [], []
    rng = random.Random(0x5AA77024)
    raw_cases = []
    for name, plain in (("empty", b""), ("tiny", b"snappy"), ("repeat", b"Snappy retained token cursor\n" * 1024),
                        ("random", rng.randbytes(16387)), ("source", (ROOT / "src/root.zig").read_bytes()[:16384])):
        raw = ref.encode(plain)
        require(ref.decode(raw) == plain, "independent system raw roundtrip")
        raw_cases.append((name, raw, plain, "system libsnappy encoder"))
    for kind in (1, 2, 4):
        raw, plain = directed(ref, b"ab", [(kind, 2, 8 if kind == 1 else 64)] * 4)
        raw_cases.append((f"copy{kind}-overlap", raw, plain, "manual Snappy tag recipe, libsnappy validated/decoded"))
    for width in (1, 2, 3, 4):
        raw, plain = directed(ref, b"noncanonical literal", [], width=width, header_width=5)
        raw_cases.append((f"literal-width{width}-varint5", raw, plain, "manual legal noncanonical literal/varint width, libsnappy decoded"))
    raw, plain = directed(ref, rng.randbytes(65535), [(4, 65535, 1)])
    raw_cases.append(("copy4-offset65535-native-boundary", raw, plain, "manual COPY4-u32 offset65535 with decoded65536 exact native bound, libsnappy decoded"))
    raw, plain = directed(ref, rng.randbytes(65536), [(4, 65536, 64)])
    raw_cases.append(("copy4-offset65536", raw, plain, "manual COPY4-u32 offset65536, independently libsnappy decoded"))
    raw, plain = directed(ref, rng.randbytes(70001), [(4, 70001, 64)])
    raw_cases.append(("copy4-offset70001", raw, plain, "manual COPY4-u32 offset70001, independently libsnappy decoded"))

    def independent(format, wire, expected, label, valid=True):
        inp, out = work / "reference-input", work / "reference-output"
        inp.write_bytes(wire)
        result = command(java, "-cp", java_cp, "StreamContractReference", format, inp, out, check=valid)
        if not valid:
            require(result.returncode != 0, (label, format, "independent rejection"))
            return result
        require(out.read_bytes() == expected, (label, format, "snappy-java full envelope output/CRC"))
        return result

    def add(format, name, wire, plain, origin, **metadata):
        independent(format, wire, plain, name)
        cases.append((format, name, wire, plain, metadata))
        corpus.append({"format": format, "name": name, "origin": origin, "compressed_bytes": len(wire), "output_bytes": len(plain),
                       "compressed_sha256": sha(wire), "output_sha256": sha(plain), **metadata})

    for format in formats:
        for name, raw, plain, origin in raw_cases:
            if format == "native" and len(plain) > 65536:
                continue
            if format == "hadoop" and not plain:
                add(format, name, b"", b"", "empty Hadoop consists of no outer blocks")
            else:
                add(format, name, frame(format, [(raw, plain)]), plain, origin + "; manual standard envelope", raw_bytes=len(raw), raw_max_offset=raw_plan(raw)[1])
        chunks = [(r, d) for n, r, d, _ in raw_cases if n in ("tiny", "repeat", "random")]
        add(format, "multi-chunk", frame(format, chunks, group_sizes=[2, 1] if format == "hadoop" else None),
            b"".join(d for _, d in chunks), "independent raw blocks + envelope recipe", raw_bytes=max(len(r) for r, _ in chunks))
        zero = next((r, d) for n, r, d, _ in raw_cases if n == "empty")
        tiny = next((r, d) for n, r, d, _ in raw_cases if n == "tiny")
        add(format, "zero-chunk-then-data", frame(format, [zero, tiny]), tiny[1], "legal raw zero output followed by data, independent libsnappy/envelope recipe")
        if format == "native":
            raw, plain = ref.encode(b"stored chunk view" * 71), b"stored chunk view" * 71
            add(format, "stored-skip-repeat-identifier", frame(format, [(raw, plain)], stored=True, skip=b"skippable\0\xff") + IDENTIFIER,
                plain, "uncompressed data + maskedCRC32C + skippable + repeated identifier recipe", skip_hex=b"skippable\0\xff".hex())

    # The probe runner and bounded contract matrix are intentionally below the
    # reference preparation so --prepare-only never needs a Vort executable.
    if not args.prepare_only:
        run_matrix(args, probes, ref, work, cases, raw_cases, rows, independent)
    require(before == sources(), "sources changed during differential; rebuild/rerun after source freeze")
    require(driver_sha == sha(Path(__file__).read_bytes()), "driver changed during differential")
    package = command("dpkg-query", "-W", "libsnappy1v5", check=False).stdout.decode().strip()
    library_path = Path("/lib/x86_64-linux-gnu/libsnappy.so.1").resolve() if not args.libsnappy else args.libsnappy.resolve()
    report = {"schema": "vort.snappy_stream_contracts", "schema_version": 1,
              "status": "reference_prepared" if args.prepare_only else "ok", "utc": datetime.now(timezone.utc).isoformat(),
              "cpu": cpu(), "python": sys.version, "zig": command("zig", "version").stdout.decode().strip(),
              "build_mode": rows[0]["build_mode"] if rows else None, "command": sys.argv,
              "sources": before, "driver_sha256": driver_sha,
              "probes": {f: {"path": str(q), "sha256": sha(q.read_bytes())} for f, q in probes.items() if q},
              "reference": {"libsnappy": str(library_path), "sha256": sha(library_path.read_bytes()), "package": package,
                            "snappy_java": str(jar), "jar_sha256": sha(jar.read_bytes()), "java": command(java, "-version").stderr.decode().strip(),
                            "helper_source_sha256": sha(JAVA.encode()), "helper_class_sha256": sha((work / "StreamContractReference.class").read_bytes())},
              "corpus": corpus, "cases": rows,
              "summary": {"streams": len(corpus), "runs": len(rows), "errors": dict(Counter(r["error"] for r in rows if r["error"])),
                          "oom_failure_cases": sum(r["oom_failure_cases"] for r in rows)}}
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"status": report["status"], **report["summary"]}, sort_keys=True))
    if temporary:
        temporary.cleanup()


def run_matrix(args, probes, ref, work, cases, raw_cases, rows, independent):
    formats = sorted({f for f, _, _, _, _ in cases})
    plans = {name: raw_plan(raw) for name, raw, _, _ in raw_cases}

    def check(format, name, wire, plain, pattern="mixed", error=None, atomic_ceiling=None, action="stream", **options):
        index = len(rows)
        inp, expected, out, cfg = (work / f"{index}-{suffix}" for suffix in ("input", "expected", "output", "config.json"))
        inp.write_bytes(wire)
        expected.write_bytes(plain)
        config = {"format": format, "action": action, "pattern": pattern, "expect_failure": error is not None, **options}
        cfg.write_text(json.dumps(config) + "\n")
        try:
            result = json.loads(command(probes[format], inp, expected, out, cfg).stdout)
        except Exception as exc:
            raise RuntimeError(f"Snappy {format} case {name}: {config}") from exc
        actual = out.read_bytes()
        require(actual == plain[:result["output_written"]], (name, format, "published prefix"))
        if action == "stream":
            snap = result["snapshot"]
            require(snap.get("total_input_read", snap["input_read"]) == result["input_read"]
                    and snap.get("total_output", snap["output_written"]) == len(actual), (name, "published accounting"))
            require(result["max_retained_decoded_capacity"] == 0, (name, "no whole decoded heap staging"))
            require(result["peak_working_bytes"] <= options.get("max_working_memory", 2**64 - 1), (name, "working budget"))
        if error is None:
            require(result["error"] is None and actual == plain, (name, "decode"))
        else:
            require(result["error"] in ([error] if isinstance(error, str) else error), (name, error, result["error"]))
            if action == "stream" and not result["finish_error"]:
                require(result["sticky_checks"] > 0, (name, "terminal step sticky"))
        if atomic_ceiling is not None:
            require(len(actual) <= atomic_ceiling, (name, format, "malformed/CRC chunk published before validation"))
        rows.append({"format": format, "name": name, "config": config, "compressed_sha256": sha(wire),
                     "output_sha256": sha(actual), "atomic_output_ceiling": atomic_ceiling, **result})
        return result

    for format, name, wire, plain, metadata in cases:
        for pattern in ("one", "mixed", "wide_zero"):
            result = check(format, name, wire, plain, pattern, check_one_shot=pattern == "wide_zero")
            if name in plans:
                decoded, max_offset = plans[name]
                require(decoded == len(plain) and result["max_history_capacity"] <= max_offset,
                        (name, format, "history follows actual COPY distance"))
                if max_offset > 65535:
                    require(result["max_history_capacity"] > 65535, (name, "large COPY4 history must not claim 64K bound"))
    for format in formats:
        _, _, wire, plain, _ = next(c for c in cases if c[0] == format and c[1] == "repeat")
        base = check(format, "resource-baseline", wire, plain, "wide_zero", reset_after=True, oom=True, move_when_output_pending=True)
        require(base["oom_failure_cases"] > 0 and base["reset_checks"] == 2 and base["moves"] == 1, "owned lifecycle/OOM/move coverage")
        for field, exact in (("max_output_len", len(plain)), ("max_working_memory", base["peak_working_bytes"])):
            check(format, field + "-exact", wire, plain, "wide_zero", **{field: exact})
            check(format, field + "-below", wire, plain, "wide_zero",
                  "WorkingMemoryLimitExceeded" if field == "max_working_memory" else "OutputLimitExceeded", **{field: exact - 1})
        raw = next(raw for name, raw, _, _ in raw_cases if name == "repeat")
        if format == "native":
            bound = max(6, len(raw) + 4)
            check(format, "payload-limit-exact", wire, plain, "wide_zero", max_chunk_payload_len=bound)
            check(format, "payload-limit-below", wire, plain, "wide_zero", "OutputLimitExceeded", max_chunk_payload_len=bound - 1)
        else:
            for field, exact in (("max_compressed_chunk_len", len(raw)), ("max_decoded_chunk_len", len(plain))):
                check(format, field + "-exact", wire, plain, "wide_zero", **{field: exact})
                check(format, field + "-below", wire, plain, "wide_zero", "OutputLimitExceeded", **{field: exact - 1})
        check(format, "expected-size-exact", wire, plain, expected_output_len=len(plain))
        check(format, "expected-size-above", wire, plain, error="SizeMismatch", expected_output_len=len(plain) + 1)
        for pattern in ("mixed", "wide_zero"):
            retry = check(format, "partial-finish-then-complete", wire, plain, pattern, finish_prefix_len=len(wire) - 1)
            require(retry["finish_retry_checks"] == 1, "partial EOF rejection must preserve supported retry")
        for cut in ((0, 1, 3, len(wire) - 1) if format != "hadoop" else (1, 3, len(wire) - 1)):
            check(format, f"truncated-envelope-{cut}", wire[:cut], plain, "wide_zero", "TruncatedFrame")

        good_raw, good_plain = next((r, d) for name, r, d, _ in raw_cases if name == "copy1-overlap")
        invalid = [
            ("copy-zero-offset", varint(12) + literal(b"abcd") + bytes([30, 0, 0]), b"abcd" * 3, "InvalidMatch"),
            ("literal-over-declared-size", varint(3) + literal(b"abcd"), b"abc", "SizeMismatch"),
            ("copy-truncated-offset", varint(12) + literal(b"abcd") + copy(4, 4, 8)[:-1], b"abcd" * 3, "TruncatedFrame"),
            ("raw-trailing-token", good_raw + b"\0", good_plain, "TrailingData"),
        ]
        for name, bad_raw, claimed, error in invalid:
            require(not ref.valid(bad_raw), (name, "independent raw rejection"))
            bad_wire = frame(format, [(bad_raw, claimed)])
            check(format, name + "-atomic-first", bad_wire, claimed, "wide_zero", error, atomic_ceiling=0)
            combined = frame(format, [(good_raw, good_plain), (bad_raw, claimed)])
            check(format, name + "-atomic-after-valid", combined, good_plain + claimed, "wide_zero", error, atomic_ceiling=len(good_plain))
        if format == "hadoop":
            too_small = (len(plain) - 1).to_bytes(4, "big") + wire[4:]
            check(format, "outer-pledge-too-small", too_small, plain, "wide_zero", "InvalidHadoopSnappyStream", atomic_ceiling=0)
            early = check(format, "outer-pledge-early-budget", wire[:4], plain, "wide_zero", "OutputLimitExceeded", max_output_len=len(plain) - 1)
            require(early["input_read"] == 4 and early["peak_working_bytes"] == 0, "Hadoop outer pledge must precede compressed allocation/publication")
            last = (ref.encode(b"z"), b"z")
            two = frame(format, [(good_raw, good_plain), last])
            prefix = 4 + 4 + len(good_raw)
            retry = check(format, "incomplete-outer-then-next-subchunk", two, good_plain + b"z", "wide_zero", finish_prefix_len=prefix)
            require(retry["finish_retry_checks"] == 1, "Hadoop incomplete outer retry")
        if format == "native":
            for stored in (False, True):
                checked = frame(format, [(good_raw, good_plain)], stored=stored)
                corrupted = checked[:14] + bytes([checked[14] ^ 1]) + checked[15:]
                rejected = independent(format, corrupted, None, "corrupt CRC", valid=False)
                check(format, "crc-before-output-" + str(stored), corrupted, good_plain, "wide_zero", "ChecksumMismatch", atomic_ceiling=0)
                rows[-1]["independent_rejection"] = {"decoder": "snappy-java Framed", "returncode": rejected.returncode,
                                                    "stderr_sha256": sha(rejected.stderr)}
            check(format, "bad-identifier", IDENTIFIER[:4] + b"x" + IDENTIFIER[5:], b"", error="InvalidMagic", atomic_ceiling=0)
            check(format, "unskippable-type", IDENTIFIER + native_chunk(2, b"x"), b"", error="UnsupportedSnappyFeature", atomic_ceiling=0)
            check(format, "unskippable-before-identifier-legacy-priority", native_chunk(2, b"x"), b"", error="UnsupportedSnappyFeature", atomic_ceiling=0)
            check(format, "missing-identifier", native_chunk(1, struct.pack("<I", masked_crc(b"x")) + b"x"), b"x", error="InvalidMagic", atomic_ceiling=0)
            for name, large_raw, large_plain, _ in raw_cases:
                if name.startswith("copy4-offset") and len(large_plain) > 65536:
                    check(format, name + "-framed-bound", frame(format, [(large_raw, large_plain)]), large_plain,
                          "wide_zero", "CorruptFrame", atomic_ceiling=0)
            second_plain = b"next independently encoded member"
            second = frame(format, [(ref.encode(second_plain), second_plain)])
            # Leave member sizes unpledged here so a too-small cumulative
            # quota is enforced when the next raw chunk arrives. A conflicting
            # explicit next-member pledge is a configuration rejection instead.
            config = {"frame_input_lengths": [len(wire), len(second)]}
            for pattern in ("mixed", "wide_zero"):
                total = len(plain) + len(second_plain)
                success = check(format, "next-stream-total-exact", wire + second, plain + second_plain, pattern, max_total_output_len=total, **config)
                require(success["streams"] == 2, "native nextStream accounting")
                check(format, "next-stream-total-below", wire + second, plain + second_plain, pattern, "OutputLimitExceeded", max_total_output_len=total - 1, **config)
            two_chunks = frame(format, [(good_raw, good_plain), (ref.encode(b"z"), b"z")])
            prefix = len(frame(format, [(good_raw, good_plain)]))
            retry = check(format, "finish-pledge-retry", two_chunks, good_plain + b"z", "wide_zero",
                          expected_output_len=len(good_plain) + 1, finish_prefix_len=prefix, finish_retry_error="SizeMismatch")
            require(retry["finish_retry_checks"] == 1, "native rejected pledge EOF must not seal input")
    if "native" in formats:
        for name, raw, plain, _ in raw_cases:
            check("native", name + "-raw-one-shot", raw, plain, action="raw")
        bad = varint(12) + literal(b"abcd") + bytes([30, 0, 0])
        check("native", "raw-one-shot-legacy-error", bad, b"abcd" * 3, error="InvalidMatch", action="raw")
        check("native", "raw-one-shot-length-error", varint(3) + literal(b"abcd"), b"abc", error="SizeMismatch", action="raw")


if __name__ == "__main__":
    main()
