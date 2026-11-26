"""Read and hash package bytes without extraction or original-path access."""
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


def lines(files, name):
    return [json.loads(line) for line in files[name].splitlines()]


def read_tar(data, mode, directories=False):
    files, seen = {}, set()
    with tarfile.open(fileobj=io.BytesIO(data), mode=mode) as archive:
        for member in archive:
            path = PurePosixPath(member.name)
            require(not path.is_absolute() and '..' not in path.parts and member.name not in seen,
                    'Unsafe or duplicate archive member: ' + member.name)
            seen.add(member.name)
            if directories and member.isdir():
                continue
            require(member.isfile(), 'Non-file archive member: ' + member.name)
            if not directories:
                require(member.mode == 0o644, 'Archived program must be data: ' + member.name)
            files[member.name] = archive.extractfile(member).read()
    return files


def read_packages(root):
    sums = {}
    for line in (root / 'SHA256SUMS').read_text().splitlines():
        digest, name = line.split('  ', 1)
        require(PurePosixPath(name).name == name and name not in sums,
                'Unsafe or duplicate package checksum name')
        path = root / name
        require(path.is_file() and not path.is_symlink(), 'Expected ordinary package file')
        require(sha(path.read_bytes()) == digest, 'Package file SHA differs: ' + name)
        sums[name] = digest
    actual = {path.name for path in root.iterdir() if path.is_file() and path.name != 'SHA256SUMS'}
    require(set(sums) == actual, 'Top-level package checksum inventory differs')
    binding = json.loads((root / 'archive-bindings.json').read_bytes())
    names = {'v2-reserved-sink.tar.gz', 'v3-direct-bits.tar.gz', 'common.tar.gz'}
    require(set(binding['archives']) == set(binding['members']) == names, 'Archive set differs')
    packages = {}
    for name in sorted(names):
        data = (root / name).read_bytes()
        expected = binding['archives'][name]
        require(len(data) == expected['bytes'] and sha(data) == expected['sha256'],
                'Archive binding differs: ' + name)
        files = read_tar(data, 'r:gz')
        require(set(files) == set(binding['members'][name]), 'Archive inventory differs: ' + name)
        for member, expected in binding['members'][name].items():
            require(len(files[member]) == expected['bytes'] and sha(files[member]) == expected['sha256'],
                    'Archive member differs: ' + member)
        packages[name] = files
    return packages, binding


def verify_reference(common, record):
    reference = load(common, 'reference-map.json')[record['path']]
    data = common[reference['member']]
    require(record['sha256'] == reference['sha256'] == sha(data) and
            record.get('size', record.get('bytes')) == reference['bytes'] == len(data),
            'Captured reference differs')
