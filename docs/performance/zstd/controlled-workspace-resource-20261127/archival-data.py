from pathlib import Path
import tarfile,hashlib,json,datetime
R=Path('/tmp/vort-zstd-workspace-resource-yireuk68')
G=Path('/tmp/vort-zstd-controlled-workspace-gate.xhrilazx')
D=Path('/home/passchaos/project-z/vort/docs/performance/zstd/controlled-workspace-resource-20261127')

def file_hash(path):
 d=hashlib.sha256()
 with path.open('rb') as f:
  for part in iter(lambda:f.read(1048576),b''):d.update(part)
 return d.hexdigest()

specs={}
for label,source in [('baseline-source',R/'baseline-source'),('candidate-source',R/'candidate-source'),('resource-evidence',R),('copernicus-gate',G)]:
 files=[p for p in sorted(source.rglob('*')) if p.is_file() and not (label=='resource-evidence' and any(x in ('baseline-source','candidate-source','local-cache','global-cache','__pycache__') for x in p.relative_to(source).parts)) and not (label=='resource-evidence' and p.name=='archive_data.py')]
 members={str(p.relative_to(source)):{'bytes':p.stat().st_size,'sha256':file_hash(p)} for p in files}
 archive=D/'archives'/(label+'.tar.xz')
 with tarfile.open(archive,'w:xz',preset=3) as tar:
  for p in files:
   name=str(p.relative_to(source));info=tarfile.TarInfo(name);info.size=p.stat().st_size;info.mode=0o644;info.uid=info.gid=0;info.mtime=0
   with p.open('rb') as stream:tar.addfile(info,stream)
 assert all(file_hash(source/name)==entry['sha256'] for name,entry in members.items())
 specs[label]={'path':str(archive.relative_to(D)),'source_original_path':str(source),'bytes':archive.stat().st_size,'sha256':file_hash(archive),'members':members}
 print(label,'files',len(members),'archive_bytes',archive.stat().st_size,flush=True)
files={str(p.relative_to(D)):{'bytes':p.stat().st_size,'sha256':file_hash(p)} for p in sorted(D.iterdir()) if p.is_file() and p.name not in ('inventory.json',)}
inventory={'schema':'vort-workspace-resource-inventory-v1','created_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'archive_format':'deterministic regular-file tar.xz preset3, uid/gid/mtime0','archives':specs,'files':files,'omitted':'resource compiler local/global caches and __pycache__; all frozen src retained separately; no omitted gate source, original failure or successful logs','producer_was_data_only':True,'codec_test_build_timing_executed_during_archival':False}
(D/'inventory.json').write_text(json.dumps(inventory,indent=2)+'\n')
print('inventory complete',len(files),'top-level files',sum(len(x['members']) for x in specs.values()),'archive members',flush=True)
