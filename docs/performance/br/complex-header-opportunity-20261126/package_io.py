"""Read package bytes only; never extract or access captured original paths."""
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


def read_tar(data, mode, directories=False):
    files, seen = {}, set()
    with tarfile.open(fileobj=io.BytesIO(data), mode=mode) as archive:
        for member in archive:
            path = PurePosixPath(member.name)
            require(not path.is_absolute() and '..' not in path.parts and member.name not in seen,
                    'Unsafe or duplicate archive member')
            seen.add(member.name)
            if directories and member.isdir():
                continue
            require(member.isfile(), 'Archive member is not a regular file')
            if not directories:
                require(member.mode == 0o644, 'Stored programs must be data')
            files[member.name] = archive.extractfile(member).read()
    return files


def read_packages(root):
    recorded = set()
    for line in (root / 'SHA256SUMS').read_text().splitlines():
        digest, name = line.split('  ', 1)
        require(PurePosixPath(name).name == name and name not in recorded, 'Unsafe checksum name')
        path = root / name
        require(path.is_file() and not path.is_symlink() and sha(path.read_bytes()) == digest,
                'Package file SHA differs: ' + name)
        recorded.add(name)
    require(recorded == {p.name for p in root.iterdir() if p.is_file() and p.name != 'SHA256SUMS'},
            'Top-level package checksum inventory differs')
    binding = json.loads((root / 'archive-bindings.json').read_bytes())
    require(set(binding['archives']) == set(binding['members']) == {'sources.tar.gz', 'evidence.tar.gz'},
            'Archive inventory differs')
    packages = {}
    for name in binding['archives']:
        data = (root / name).read_bytes()
        require(sha(data) == binding['archives'][name]['sha256'] and len(data) == binding['archives'][name]['bytes'],
                'Archive SHA or size differs')
        files = read_tar(data, 'r:gz')
        require(set(files) == set(binding['members'][name]), 'Archive member inventory differs')
        for member, record in binding['members'][name].items():
            require(sha(files[member]) == record['sha256'] and len(files[member]) == record['bytes'],
                    'Archive member SHA or size differs: ' + member)
        packages[name] = files
    return packages, binding


def captured_member(path):
    prefix = '/tmp/vort-br-complex-header-observe.n64z2w22/'
    require(path.startswith(prefix), 'Captured path outside observer epoch')
    relative = path.removeprefix(prefix)
    require('..' not in PurePosixPath(relative).parts, 'Unsafe captured path')
    return relative
