"""Package reader used only after release; no original-path or executable access."""
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


def load(files, name):
    return json.loads(files[name])


def json_documents(data):
    text = data.decode()
    decoder = json.JSONDecoder()
    position = 0
    documents = []
    while position < len(text):
        while position < len(text) and text[position].isspace():
            position += 1
        if position == len(text):
            break
        document, position = decoder.raw_decode(text, position)
        documents.append(document)
    return documents


def read_packages(root):
    binding = json.loads((root / "archive-bindings.json").read_bytes())
    packages = {}
    for name, expected in binding["archives"].items():
        content = (root / name).read_bytes()
        require(len(content) == expected["bytes"] and sha(content) == expected["sha256"], "Package hash differs")
        files = {}
        with tarfile.open(fileobj=io.BytesIO(content), mode="r:gz") as archive:
            for member in archive:
                path = PurePosixPath(member.name)
                require(member.isfile() and not path.is_absolute() and ".." not in path.parts and member.name not in files,
                        "Unsafe or duplicate archive member")
                files[member.name] = archive.extractfile(member).read()
        require(set(files) == set(binding["members"][name]), "Package member inventory differs")
        for member, record in binding["members"][name].items():
            require(len(files[member]) == record["bytes"] and sha(files[member]) == record["sha256"], "Member hash differs")
        packages[name] = files
    require(set(packages) == {"sources.tar.gz", "benchmark.tar.gz", "validation.tar.gz"}, "Package set differs")
    return packages, binding
