#!/usr/bin/env python3
"""Independent LZX match, frame-state, WIM-window and WOF differentials."""
import argparse
import ctypes
import ctypes.util
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import random
import platform
import subprocess
import tempfile
from pathlib import Path


def run(*args):
    return subprocess.run([str(arg) for arg in args], check=True, capture_output=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--probe", type=Path, required=True)
    parser.add_argument("--wimlib-dir", type=Path, required=True)
    parser.add_argument("--mspack-dir", type=Path, required=True)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    module_spec = importlib.util.spec_from_file_location("cab_diff", "tools/cab/diff.py")
    cab_diff = importlib.util.module_from_spec(module_spec)
    module_spec.loader.exec_module(cab_diff)
    rows = []
    with tempfile.TemporaryDirectory(prefix="vort-lzx-matches-") as directory:
        temp = Path(directory)
        wim = temp / "wimlib-probe"
        mspack = temp / "mspack-probe"
        run("cc", "-O2", f"-I{args.wimlib_dir / 'include'}", "tools/wof/wimlib_probe.c",
            args.wimlib_dir / ".libs/libwim.a", "-lpthread", "-o", wim)
        run("cc", "-O2", f"-I{args.mspack_dir / 'mspack'}", "tools/lzx/mspack_probe.c",
            args.mspack_dir / ".libs/libmspack.a", "-o", mspack)
        rng = random.Random(0x1A11E)
        prefix = rng.randbytes(8192)
        aligned = prefix + b"".join(prefix[((row * 137) % 1020) * 8:][:24] for row in range(512))
        text = (b"LZX full match and repeated offset interop\n" * 2000)[:66000]
        mixed = text[:32768] + rng.randbytes(32768) + text[:32768] + b"odd tail 12345"
        x86 = bytearray(text)
        for index in range(64, len(x86) - 16, 4096):
            x86[index] = 0xe8
            x86[index + 1:index + 5] = (12_000_000 - index - 1).to_bytes(4, "little", signed=True)
        families = {"text": text, "random": rng.randbytes(65536), "aligned": aligned,
                    "mixed": mixed, "x86": bytes(x86), "window-history": prefix * 12}

        def encode(mode, name, data, bits):
            source, output, repeat = temp / "source", temp / "encoded", temp / "repeat"
            source.write_bytes(data)
            stats = json.loads(run(args.probe, mode, source, output, bits).stderr)
            run(args.probe, mode, source, repeat, bits)
            wire = output.read_bytes()
            assert wire == repeat.read_bytes(), (mode, name, bits, "determinism")
            row = {"format": mode, "case": name, "window_bits": bits, **stats,
                   "input_sha256": hashlib.sha256(data).hexdigest(),
                   "encoded_sha256": hashlib.sha256(wire).hexdigest()}
            if mode == "cab":
                assert cab_diff.libarchive_extract(output)["payload.bin"] == data
                restored = temp / "mspack-output"
                run(mspack, output, restored)
                assert restored.read_bytes() == data, (mode, name, bits, "libmspack")
            elif mode == "wim":
                restored = temp / "wim-output"
                run(wim, "decode", "lzx", output, restored, len(data), 1 << bits)
                assert restored.read_bytes() == data, (mode, name, bits, "wimlib")
                reference = temp / "literal-reference"
                run(args.probe, "reference", source, reference, bits)
                row["reference_bytes"] = reference.stat().st_size
                assert len(wire) <= row["reference_bytes"], (name, bits, "reference size")
            else:
                # The WOF decoder checks each compressed chunk independently;
                # equal-sized chunks are raw, with cumulative offsets in the header.
                import struct
                count = (len(data) + 32767) // 32768
                table_len = max(0, count - 1) * 4
                offsets = [0] + [struct.unpack_from("<I", wire, 4 * i)[0] for i in range(count - 1)] + [len(wire) - table_len]
                row["compressed_chunks"] = 0
                row["raw_chunks"] = 0
                for chunk in range(count):
                    raw = data[chunk * 32768:][:32768]
                    payload = wire[table_len + offsets[chunk]:table_len + offsets[chunk + 1]]
                    if len(payload) == len(raw):
                        assert payload == raw
                        row["raw_chunks"] += 1
                    else:
                        chunk_input, chunk_output = temp / "chunk", temp / "chunk-output"
                        chunk_input.write_bytes(payload)
                        run(wim, "decode", "lzx", chunk_input, chunk_output, len(raw), 32768)
                        assert chunk_output.read_bytes() == raw
                        row["compressed_chunks"] += 1
                assert len(wire) <= len(data) + table_len
                if name == "mixed":
                    assert row["compressed_chunks"] > 0 and row["raw_chunks"] > 0
            rows.append(row)
            return row

        for bits in range(15, 22):
            for size in (1, 2, 3, 9, 257, 32768):
                encode("wim", f"size-{size}", (b"tiny and short LZX\n" * 2000)[:size], bits)
            for name, data in families.items():
                encode("cab", name, data, bits)
                bounded = data[:1 << bits]
                row = encode("wim", name, bounded, bits)
                if name == "text" and len(bounded) >= 32768:
                    assert row["encoded"] < len(bounded) // 20
        wide = (rng.randbytes(65536) * 32)[:2 * 1024 * 1024]
        encode("wim", "wide-2m", wide, 21)
        for name, data in families.items():
            encode("wof", name, data, 15)
        for bits in (15, 16, 21):
            source = temp / "set-source"
            source.write_bytes(mixed)
            output, repeated = temp / f"set-{bits}", temp / f"set-repeat-{bits}"
            stats = json.loads(run(args.probe, "cab-set", source, output, bits).stderr)
            run(args.probe, "cab-set", source, repeated, bits)
            parts = sorted(output.glob("*.cab"))
            assert len(parts) == stats["parts"] and len(parts) > 1
            for first, second in zip(parts, sorted(repeated.glob("*.cab"))):
                assert first.read_bytes() == second.read_bytes()
                assert first.stat().st_size <= 2048
            restored = temp / "set-restored"
            run(mspack, parts[0], restored, *parts[1:])
            assert restored.read_bytes() == mixed
            rows.append({"format": "cab-set", "case": "mixed", "window_bits": bits, **stats,
                         "input_sha256": hashlib.sha256(mixed).hexdigest(),
                         "encoded_sha256": hashlib.sha256(b"".join(p.read_bytes() for p in parts)).hexdigest()})
        archive = ctypes.CDLL(ctypes.util.find_library("archive"))
        archive.archive_version_string.restype = ctypes.c_char_p
        source_paths = [Path("src/lzx.zig"), Path("src/cab/lzx.zig"), Path("src/cab/writer.zig"), Path("src/wof/writer.zig"), Path("src/huffman.zig")]
        source_paths += sorted(Path("src/cab/lzx").glob("*.zig"))
        source_paths += [Path("tools/lzx/match_probe.zig"), Path("tools/lzx/match_diff.py"), Path("tools/lzx/mspack_probe.c"), Path("tools/wof/wimlib_probe.c")]
        report = {"schema": "vort-lzx-matches-v1", "claim": "wire correctness and compressed sizes; no throughput claim",
                  "date": datetime.now(timezone.utc).date().isoformat(), "platform": platform.platform(),
                  "repository_commit": run("git", "rev-parse", "HEAD").stdout.decode().strip(),
                  "probe_sha256": hashlib.sha256(args.probe.read_bytes()).hexdigest(),
                  "source_sha256": {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in source_paths},
                  "libarchive_version": archive.archive_version_string().decode(),
                  "wimlib_version": run(wim, "version").stdout.decode().strip(),
                  "wimlib_git": run("git", "-C", args.wimlib_dir, "rev-parse", "HEAD").stdout.decode().strip(),
                  "mspack_git": run("git", "-C", args.mspack_dir, "rev-parse", "HEAD").stdout.decode().strip(),
                  "rows": rows}
        if args.report:
            args.report.write_text(json.dumps(report, indent=2) + "\n")
        print(f"lzx_matches={len(rows)} cab={sum(r['format'] == 'cab' for r in rows)} "
              f"wim={sum(r['format'] == 'wim' for r in rows)} wof={sum(r['format'] == 'wof' for r in rows)} "
              f"cab_sets={sum(r['format'] == 'cab-set' for r in rows)} "
              f"wimlib={report['wimlib_version']} libarchive=ok libmspack=ok")


if __name__ == "__main__":
    main()
