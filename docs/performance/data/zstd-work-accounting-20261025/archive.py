from pathlib import Path
import hashlib,json,shutil
base=Path('/tmp/vort-zstd-work-accounting-20261025')
root=Path('/home/passchaos/project-z/vort-zstd-work-accounting')
out=root/'docs/performance/data/zstd-work-accounting-20261025'
out.mkdir(parents=True,exist_ok=True)
names=['input-manifest.json','candidate-executable.json','analysis.json','state_probe.zig','state-analysis.json',
       'profile-work.json','profile-result.json','accounting-review.md','accounting-elf.md','accounting-elf.json',
       'final-evidence-review.md','measure.py','run_command.py','run_focus.py','archive.py']
for name in names:
 p=base/name
 if p.is_file():shutil.copy2(p,out/name)
groups=['baseline14','candidate14','accounting-debug','accounting-releasefast','accounting-x86','state-native',
        'state-x86','state-x86-final','encoder-build','complete-family','complete-check','cli-help','post-rebase','repeated-focus']
for group in groups:
 directory=base/group
 if directory.exists():
  target=out/group;target.mkdir(exist_ok=True)
  for p in directory.iterdir():
   if p.is_file() and p.suffix in ['.json','.csv','.log']:shutil.copy2(p,target/p.name)
if (base/'exactasm').exists():shutil.copytree(base/'exactasm',out/'exactasm',dirs_exist_ok=True)
if (base/'memory').exists():
 target=out/'memory';target.mkdir(exist_ok=True)
 for p in (base/'memory').iterdir():
  if p.is_file() and p.suffix in ['.json','.md','.zig','.py','.log','.txt']:shutil.copy2(p,target/p.name)
files={str(p.relative_to(out)):hashlib.sha256(p.read_bytes()).hexdigest() for p in out.rglob('*') if p.is_file() and p.name!='artifact-manifest.json'}
(out/'artifact-manifest.json').write_text(json.dumps({'files':files},indent=2)+'\n')
print(json.dumps({'files':len(files),'bytes':sum(p.stat().st_size for p in out.rglob('*') if p.is_file())}))
