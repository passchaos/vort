"""Read package archives as data only; original paths are string keys."""
from pathlib import PurePosixPath
import hashlib,io,json,tarfile


def require(value,message):
    if not value:raise ValueError(message)


def sha(data):return hashlib.sha256(data).hexdigest()
def load(files,name):return json.loads(files[name])


def member(path):
    prefix='/tmp/vort-br-shared-literal-model-ab.p9wbbc7q/'
    require(path.startswith(prefix) and '..' not in PurePosixPath(path).parts,'Captured path outside frozen performance epoch')
    return path.removeprefix(prefix)


def read_packages(root):
    expected_files=set()
    for line in (root/'SHA256SUMS').read_text().splitlines():
        digest,name=line.split('  ',1)
        require(name==PurePosixPath(name).name and name not in expected_files,'Unsafe checksum name')
        path=root/name;require(path.is_file() and not path.is_symlink() and sha(path.read_bytes())==digest,'Top-level hash differs: '+name)
        expected_files.add(name)
    require(expected_files=={p.name for p in root.iterdir() if p.is_file() and p.name!='SHA256SUMS'},'Top-level checksum inventory differs')
    binding=json.loads((root/'archive-bindings.json').read_bytes())
    require(set(binding['archives'])==set(binding['members'])=={'sources.tar.gz','performance.tar.gz','validation.tar.gz'},'Archive inventory differs')
    packages={}
    for name,record in binding['archives'].items():
        data=(root/name).read_bytes();require(len(data)==record['bytes'] and sha(data)==record['sha256'],'Archive identity differs')
        files={}
        with tarfile.open(fileobj=io.BytesIO(data),mode='r:gz') as archive:
            for item in archive:
                path=PurePosixPath(item.name)
                require(item.isfile() and item.mode==0o644 and not path.is_absolute() and '..' not in path.parts and item.name not in files,'Unsafe archive member')
                files[item.name]=archive.extractfile(item).read()
        require(set(files)==set(binding['members'][name]),'Archive member inventory differs')
        for item,record in binding['members'][name].items():
            require(len(files[item])==record['bytes'] and sha(files[item])==record['sha256'],'Member identity differs: '+item)
        packages[name]=files
    return packages,binding
