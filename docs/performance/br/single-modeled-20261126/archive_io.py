"""Read and hash this publication without extracting or running artifacts."""
import gzip
import hashlib
import io
import json
from pathlib import PurePosixPath
import tarfile


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def load(payloads, name):
    return json.loads(payloads[name])


def read_archives(root):
    binding = json.loads((root / "archive-bindings.json").read_bytes())
    packages = {}
    for name, expected in binding["archives"].items():
        data = (root / name).read_bytes()
        require(len(data) == expected["bytes"] and sha(data) == expected["sha256"],
                "Archive identity differs: " + name)
        payloads = {}
        with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as archive:
            for member in archive:
                path = PurePosixPath(member.name)
                require(member.isfile() and not path.is_absolute() and ".." not in path.parts,
                        "Unexpected archive member: " + member.name)
                require(member.name not in payloads, "Duplicate archive member: " + member.name)
                payloads[member.name] = archive.extractfile(member).read()
        records = binding["members"][name]
        require(set(payloads) == set(records), "Archive member inventory differs: " + name)
        for member, record in records.items():
            data = payloads[member]
            require(len(data) == record["bytes"] and sha(data) == record["sha256"],
                    "Member identity differs: " + member)
            transform = record.get("transform", "none")
            require(transform in ("none", "gzip"), "Unknown member transform")
            if transform == "gzip":
                original = gzip.decompress(data)
                require(len(original) == record["original_bytes"] and sha(original) == record["original_sha256"],
                        "Transformed original differs: " + member)
        packages[name] = payloads
    require(set(packages) == {"primary.tar.gz", "controls.tar.gz", "resources.tar.gz", "code-tests.tar.gz"},
            "Package set differs")
    return packages, binding


def command_options(command):
    argv = command.get("argv", command.get("command"))
    require(isinstance(argv, list), "Command argv is missing")
    options = {}
    for index, item in enumerate(argv):
        if item.startswith("--") and index + 1 < len(argv):
            require(item not in options, "Duplicate command option")
            options[item] = argv[index + 1]
    return argv, options
