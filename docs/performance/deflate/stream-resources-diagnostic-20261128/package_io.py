"""Explicit mapped, data-only package I/O; never execute captured programs.

This diagnostic adapter reads an uncompressed data tar; no captured codec loads.

Adapted from prepared-fixed-variants-20261126/package_io.py: ordinary members,
mode 0644, exact inventory and hashes, no extraction or original-path fallback.
"""
import hashlib
import json
from pathlib import Path, PurePosixPath
import tarfile


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def identity(stream):
    digest, length = hashlib.sha256(), 0
    for chunk in iter(lambda: stream.read(1024 * 1024), b""):
        digest.update(chunk)
        length += len(chunk)
    return {"bytes": length, "sha256": digest.hexdigest()}


def member_name(name):
    path = PurePosixPath(name)
    require(bool(name) and str(path) == name and name != "." and not path.is_absolute()
            and ".." not in path.parts and "\\" not in name and "\x00" not in name,
            "Unsafe or noncanonical member: " + str(name))
    return name


def validate_mapping(entries):
    members = set()
    for original, record in entries.items():
        path = Path(original)
        require(path.is_absolute() and ".." not in path.parts, "Original identity must be an exact absolute path")
        member = member_name(record["member"])
        require(member not in members, "Two original paths alias one archive member")
        members.add(member)


class OriginalStore:
    def __init__(self, entries):
        validate_mapping(entries)
        self.entries, self.identities = entries, {}

    def open(self, original):
        require(original in self.entries, "Unmapped original: " + original)
        path = Path(original)
        require(path.is_file() and not path.is_symlink(), "Expected ordinary original file: " + original)
        require(path.resolve() == path.absolute(), "Original path contains an implicit symlink mapping")
        return path.open("rb")

    def read(self, original):
        with self.open(original) as stream:
            data = stream.read()
        actual = {"bytes": len(data), "sha256": sha(data)}
        self._check(original, actual)
        self.identities[original] = actual
        return data

    def _check(self, original, actual):
        expected = self.entries[original].get("declared")
        require(expected is None or actual == expected, "Original declared SHA/size changed: " + original)

    def identity(self, original):
        if original not in self.identities:
            with self.open(original) as stream:
                actual = identity(stream)
            self._check(original, actual)
            self.identities[original] = actual
        return self.identities[original]

    def close(self):
        pass


class ArchiveStore:
    def __init__(self, archive_path, entries):
        validate_mapping(entries)
        self.entries, self.identities = entries, {}
        self.archive = tarfile.open(archive_path, "r:")
        self.members = {}
        try:
            for member in self.archive.getmembers():
                name = member_name(member.name)
                require(name not in self.members and member.isfile() and member.mode == 0o644,
                        "Duplicate or non-data archive member: " + name)
                self.members[name] = member
            require(set(self.members) == {value["member"] for value in entries.values()}, "Exact archive inventory differs")
        except BaseException:
            self.archive.close()
            raise

    def open(self, original):
        require(original in self.entries, "Unmapped original; no host-path fallback: " + original)
        return self.archive.extractfile(self.members[self.entries[original]["member"]])

    def identity(self, original):
        if original not in self.identities:
            with self.open(original) as stream:
                actual = identity(stream)
            expected = {key: self.entries[original][key] for key in ("bytes", "sha256")}
            require(actual == expected, "Mapped archive SHA/size differs: " + original)
            self.identities[original] = actual
        return self.identities[original]

    def read(self, original):
        with self.open(original) as stream:
            data = stream.read()
        actual = {"bytes": len(data), "sha256": sha(data)}
        require(actual == self.identity(original), "Archive changed during read")
        return data

    def close(self):
        self.archive.close()


def load(store, original):
    return json.loads(store.read(str(original)))


def equal_files(store, left, right):
    require(store.identity(str(left)) == store.identity(str(right)), "Complete peer wire SHA/size differs")
    with store.open(str(left)) as old, store.open(str(right)) as new:
        while True:
            a, b = old.read(1024 * 1024), new.read(1024 * 1024)
            require(a == b, "Complete peer wire bytes differ")
            if not a:
                return
