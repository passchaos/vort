#!/usr/bin/env python3
"""Build an isolated, source-matched Brotli context-map observer reference.

No shared checkout is modified. The cache has a full source/header SHA manifest,
the exact patched decoder and observer source, compiler command, and library SHA.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile


HERE = Path(__file__).resolve().parent


def sha256(body):
    return hashlib.sha256(body).hexdigest()


def build(source=None, cache=None):
    source = Path(source or os.environ.get("BROTLI_SOURCE", Path.home() / "Work/brotli")).resolve()
    if not (source / "c/dec/decode.c").is_file():
        raise RuntimeError(f"Brotli source missing at {source}; set BROTLI_SOURCE or pass --source")
    files = sorted(path for path in (source / "c").rglob("*")
                   if path.is_file() and path.suffix in (".c", ".h", ".inc"))
    snapshot = {str(path.relative_to(source)): path.read_bytes() for path in files}
    hashes = {name: sha256(body) for name, body in snapshot.items()}
    observer = (HERE / "observer.c").read_bytes()
    compiler = shlex.split(os.environ.get("CC", "cc"))
    compiler_version = subprocess.check_output(compiler + ["--version"], text=True).splitlines()[0]
    identity = {"source_sha256": hashes, "observer_sha256": sha256(observer),
                "builder_sha256": sha256(Path(__file__).read_bytes()),
                "compiler": compiler, "compiler_version": compiler_version}
    key = sha256(json.dumps(identity, sort_keys=True).encode())[:24]
    cache = Path(cache or os.environ.get("BRLC_REFERENCE_CACHE", Path(tempfile.gettempdir()) / "vort-brlc-reference"))
    target = cache / key
    library = target / "libbrlc_reference.so"
    manifest_path = target / "manifest.json"
    if library.is_file() and manifest_path.is_file():
        manifest = json.loads(manifest_path.read_text())
        if manifest.get("library_sha256") == sha256(library.read_bytes()):
            return library.resolve()
    cache.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix=key + ".", dir=cache))
    try:
        for name, body in snapshot.items():
            destination = work / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(body)
        for name in ("LICENSE", "README.md"):
            if (source / name).is_file():
                shutil.copyfile(source / name, work / name)
        (work / "observer.c").write_bytes(observer)
        decoder = (work / "c/dec/decode.c").read_text()
        declarations = '#include "state.h"\n'
        header_anchor = '        BROTLI_DCHECK(s->meta_block_remaining_len <=\n'
        maps_anchor = '        allocation_success &= BrotliDecoderHuffmanTreeGroupInit(\n'
        for anchor in (declarations, header_anchor):
            if decoder.count(anchor) != 1:
                raise RuntimeError(f"upstream decoder observer anchor changed: {anchor!r}")
        if decoder.count(maps_anchor) != 3:
            raise RuntimeError("upstream decoder context-map anchor changed")
        decoder = decoder.replace(declarations, declarations +
            '\nvoid brlc_observe(const BrotliDecoderState* state, unsigned kind);\n', 1)
        decoder = decoder.replace(header_anchor, '        brlc_observe(s, 0);\n' + header_anchor, 1)
        decoder = decoder.replace(maps_anchor, '        brlc_observe(s, 1);\n' + maps_anchor, 1)
        (work / "decode.original.c").write_bytes(snapshot["c/dec/decode.c"])
        (work / "c/dec/decode.c").write_text(decoder)
        compiled = sorted(str(path.relative_to(work)) for directory in ("common", "dec", "enc")
                          for path in (work / "c" / directory).glob("*.c"))
        command = compiler + ["-O2", "-std=c99", "-fPIC", "-fvisibility=hidden",
                              "-shared", "-Wl,-Bsymbolic", "-I.", "-Ic/include",
                              "observer.c"] + compiled + ["-lm", "-o", "libbrlc_reference.so"]
        subprocess.run(command, cwd=work, check=True, capture_output=True, text=True)
        try:
            commit = subprocess.check_output(["git", "-C", str(source), "rev-parse", "HEAD"], text=True).strip()
        except subprocess.CalledProcessError:
            commit = None
        identity.update({"source_root": str(source), "source_git_commit": commit,
                         "build_command": command, "patched_decoder_sha256": sha256(decoder.encode()),
                         "library_sha256": sha256((work / "libbrlc_reference.so").read_bytes()),
                         "observation": "after upstream header; after both DecodeContextMap calls and inverse MTF"})
        (work / "manifest.json").write_text(json.dumps(identity, indent=2, sort_keys=True) + "\n")
        try:
            work.rename(target)
        except OSError:
            # Independent workers may finish the same content-keyed build
            # concurrently. Keep the already completed reference in place.
            if not library.is_file() or not manifest_path.is_file():
                raise
            completed = json.loads(manifest_path.read_text())
            if completed.get("library_sha256") != sha256(library.read_bytes()):
                raise RuntimeError(f"incomplete or corrupt reference cache at {target}")
        return library.resolve()
    except subprocess.CalledProcessError as error:
        raise RuntimeError(f"private Brotli observer build failed: {error.stderr}") from error
    finally:
        if work.exists():
            shutil.rmtree(work)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path)
    parser.add_argument("--cache", type=Path)
    args = parser.parse_args()
    print(build(args.source, args.cache))
