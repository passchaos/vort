"""Execute the unchanged packaged Planck mathematics on a memory filesystem."""
import ast
import contextlib
import datetime
import fnmatch
import io
import json
import posixpath
import sys
import types

from archive_io import load, require, sha


def replay(campaign):
    expected = load(campaign, "formal-verification.json")
    original_root = posixpath.dirname(expected["reducer"]["path"])
    files = {original_root + "/" + name: data for name, data in campaign.items()}
    for fixture in load(campaign, "fixtures.json"):
        files[fixture["origin"]] = campaign["fixtures/" + posixpath.basename(fixture["path"])]
    reference = expected["retained_reference_identity"]
    files[reference["path"]] = campaign["references/" + posixpath.basename(reference["path"])]

    class MemoryPath:
        def __init__(self, value="."):
            self.path = posixpath.normpath(str(value))

        def __str__(self):
            return self.path

        def __truediv__(self, value):
            return MemoryPath(posixpath.join(self.path, str(value)))

        def __eq__(self, other):
            return isinstance(other, MemoryPath) and self.path == other.path

        @property
        def name(self):
            return posixpath.basename(self.path)

        @property
        def parent(self):
            return MemoryPath(posixpath.dirname(self.path))

        def resolve(self):
            return self

        def with_suffix(self, suffix):
            return MemoryPath(posixpath.splitext(self.path)[0] + suffix)

        def is_file(self):
            return self.path in files

        def is_dir(self):
            return any(name.startswith(self.path + "/") for name in files)

        def glob(self, pattern):
            return [MemoryPath(name) for name in sorted(files) if posixpath.dirname(name) == self.path and fnmatch.fnmatch(posixpath.basename(name), pattern)]

        def read_text(self):
            return files[self.path].decode()

        def open(self, mode="r"):
            require(mode in ("r", "rb"), "Reducer attempted an unsupported file operation")
            return io.BytesIO(files[self.path]) if mode == "rb" else io.StringIO(files[self.path].decode())

        def write_text(self, value):
            files[self.path] = value.encode()

    source = campaign["formal_reduce.py"]
    require(len(source) == expected["reducer"]["bytes"] and sha(source) == expected["reducer"]["sha256"], "Authoritative Planck reducer differs")
    tree = ast.parse(source, filename="packaged_formal_reduce.py")
    allowed = {"argparse", "datetime", "hashlib", "json", "math", "random", "re", "statistics", "struct", "sys"}
    body = []
    for node in tree.body:
        if isinstance(node, ast.ImportFrom) and node.module == "pathlib":
            require([item.name for item in node.names] == ["Path"], "Unexpected reducer pathlib import")
            continue
        if isinstance(node, ast.Import):
            require(all(item.name in allowed for item in node.names), "Reducer has non-statistical imports")
        body.append(node)
    tree.body = body
    module = types.ModuleType("packaged_planck_math")
    module.__file__ = expected["reducer"]["path"]
    module.Path = MemoryPath
    exec(compile(tree, "packaged_formal_reduce.py", "exec"), module.__dict__)

    class FrozenDatetime(datetime.datetime):
        @classmethod
        def now(cls, tz=None):
            return datetime.datetime.fromisoformat(expected["generated_utc"])

    module.datetime = types.SimpleNamespace(datetime=FrozenDatetime, timezone=datetime.timezone)
    previous = sys.argv
    try:
        sys.argv = ["packaged_formal_reduce.py", "--prefix", "formal", "--controls", original_root + "/controls-manifest.json"]
        with contextlib.redirect_stdout(io.StringIO()):
            exit_code = module.main()
    finally:
        sys.argv = previous
    actual = json.loads(files[original_root + "/formal-verification.json"])
    require(actual == expected, "Packaged Planck full statistics/CI/draw digests/gates differ")
    require(exit_code == 1 and actual["evidence_integrity_pass"] and not actual["complete_acceptance_pass"], "Expected policy gate failure differs")
    receipt = load(campaign, "formal-reducer-exit.json")
    require(receipt["exit_code"] == 1 and receipt["reason"] == "expected_gate_failure" and receipt["evidence_integrity_pass"], "Producer expected gate-failure receipt differs")
    return actual
