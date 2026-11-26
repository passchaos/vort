"""Read sealed package bytes without extraction or original-path access."""
from pathlib import PurePosixPath
import hashlib
import io
import json
import tarfile


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def load(files, name):
    return json.loads(files[name])


def read_packages(root):
    checksums = {}
    for line in (root / 'SHA256SUMS').read_text().splitlines():
        digest, name = line.split('  ', 1)
        require(name == PurePosixPath(name).name and name not in checksums, 'Unsafe checksum name')
        path = root / name
        require(path.is_file() and not path.is_symlink() and sha(path.read_bytes()) == digest,
                'Top-level package file changed: ' + name)
        checksums[name] = digest
    require(set(checksums) == {p.name for p in root.iterdir() if p.is_file() and p.name != 'SHA256SUMS'},
            'Top-level package inventory differs')
    binding = json.loads((root / 'archive-bindings.json').read_bytes())
    expected = {'sources.tar.gz', 'timing.tar.gz', 'diagnostic.tar.gz'}
    require(set(binding['archives']) == set(binding['members']) == expected, 'Archive set differs')
    packages = {}
    for name in sorted(expected):
        data = (root / name).read_bytes()
        require(sha(data) == binding['archives'][name]['sha256'] and len(data) == binding['archives'][name]['bytes'],
                'Archive binding differs')
        files = {}
        with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as archive:
            for member in archive:
                path = PurePosixPath(member.name)
                require(member.isfile() and member.mode == 0o644 and not path.is_absolute() and
                        '..' not in path.parts and member.name not in files, 'Unsafe archive member')
                files[member.name] = archive.extractfile(member).read()
        require(set(files) == set(binding['members'][name]), 'Archive member inventory differs')
        for member, record in binding['members'][name].items():
            require(sha(files[member]) == record['sha256'] and len(files[member]) == record['bytes'],
                    'Archive member binding differs: ' + member)
        packages[name] = files
    return packages, binding


def virtual_source(sources, prefix):
    return {name.removeprefix(prefix): data for name, data in sources.items() if name.startswith(prefix)}


def closed_path(value, origin_root, prefix=''):
    require(value.startswith(origin_root + '/'), 'Unexpected captured path scope')
    relative = value.removeprefix(origin_root + '/')
    require('..' not in PurePosixPath(relative).parts, 'Unsafe captured path')
    return prefix + relative
