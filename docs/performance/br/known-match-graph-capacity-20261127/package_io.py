"""Package-only tar reader; no extraction or original-path access."""
import hashlib,io,json,tarfile
from pathlib import PurePosixPath


def require(value,message):
    if not value:raise ValueError(message)


def sha(data):return hashlib.sha256(data).hexdigest()
def load(files,name):return json.loads(files[name])


def read_tar(data,mode,directories=False):
    files={};seen=set()
    with tarfile.open(fileobj=io.BytesIO(data),mode=mode) as archive:
        for m in archive:
            path=PurePosixPath(m.name)
            require(not path.is_absolute() and '..' not in path.parts and m.name not in seen,'Unsafe archive member')
            seen.add(m.name)
            if directories and m.isdir():continue
            require(m.isfile() and (directories or m.mode==0o644),'Stored programs must remain ordinary data')
            files[m.name]=archive.extractfile(m).read()
    return files


def read_packages(root):
    names=set()
    for line in (root/'SHA256SUMS').read_text().splitlines():
        digest,name=line.split('  ',1);require(name==PurePosixPath(name).name and name not in names,'Unsafe checksum name')
        path=root/name;require(path.is_file() and not path.is_symlink() and sha(path.read_bytes())==digest,'Package file hash differs')
        names.add(name)
    require(names=={p.name for p in root.iterdir() if p.is_file() and p.name!='SHA256SUMS'},'Package checksum inventory differs')
    binding=json.loads((root/'archive-bindings.json').read_bytes());packages={}
    require(set(binding['archives'])==set(binding['members'])=={'sources.tar.gz','evidence.tar.gz'},'Archive set differs')
    for name,r in binding['archives'].items():
        data=(root/name).read_bytes();require(len(data)==r['bytes'] and sha(data)==r['sha256'],'Archive hash differs')
        files=read_tar(data,'r:gz');require(set(files)==set(binding['members'][name]),'Member inventory differs')
        for member,r in binding['members'][name].items():require(len(files[member])==r['bytes'] and sha(files[member])==r['sha256'],'Member hash differs')
        packages[name]=files
    return packages,binding
