"""Read sealed package data without extraction or captured-path access."""
import hashlib, io, json, tarfile
from pathlib import PurePosixPath


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
                    'Unsafe/duplicate archive member')
            seen.add(member.name)
            if directories and member.isdir():
                continue
            require(member.isfile(), 'Archive member is not ordinary data')
            if not directories:
                require(member.mode == 0o644, 'Stored executable must remain archive data')
            files[member.name] = archive.extractfile(member).read()
    return files


def read_packages(root):
    recorded = set()
    for line in (root / 'SHA256SUMS').read_text().splitlines():
        digest, name = line.split('  ', 1)
        require(PurePosixPath(name).name == name and name not in recorded, 'Unsafe checksum filename')
        path = root / name
        require(path.is_file() and not path.is_symlink() and sha(path.read_bytes()) == digest,
                'Package file hash differs: ' + name)
        recorded.add(name)
    require(recorded == {p.name for p in root.iterdir() if p.is_file() and p.name != 'SHA256SUMS'},
            'Package checksum inventory differs')
    binding = json.loads((root / 'archive-bindings.json').read_bytes())
    require(set(binding['archives']) == set(binding['members']) == {'sources.tar.gz', 'bench.tar.gz', 'validation.tar.gz'},
            'Archive inventory differs')
    packages = {}
    for name, record in binding['archives'].items():
        data = (root / name).read_bytes()
        require(len(data) == record['bytes'] and sha(data) == record['sha256'], 'Archive bytes differ')
        files = read_tar(data, 'r:gz')
        require(set(files) == set(binding['members'][name]), 'Archive member set differs')
        for member, expected in binding['members'][name].items():
            require(len(files[member]) == expected['bytes'] and sha(files[member]) == expected['sha256'],
                    'Archive member identity differs: ' + member)
        packages[name] = files
    return packages, binding


def bench_member(value):
    prefix = '/tmp/vort-br-global-entropy-bound-ab.lf41tsx3/benchmark/'
    require(value.startswith(prefix) and '..' not in PurePosixPath(value).parts, 'Captured path outside local epoch')
    return value.removeprefix(prefix)
