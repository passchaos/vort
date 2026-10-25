from pathlib import Path
import hashlib,json,shutil
base=Path('/tmp/vort-zstd-aggregate-totals-20261025')
root=Path('/home/passchaos/project-z/vort-zstd-aggregate-totals')
out=root/'docs/performance/data/zstd-aggregate-totals-20261025'
out.mkdir(parents=True,exist_ok=True)
for name in ['analysis.json','input-manifest.json','candidate-executable.json','profile-executable.json',
             'aggregate-review.md','decision-review.md','implementation-decision-notes.md','brotli-next-profile-plan.md','restored-source.json',
             'state_probe.zig','run_command.py','measure.py','run_stage.py','archive.py']:
 p=base/name
 if p.is_file():shutil.copy2(p,out/name)
for name in ['baseline14','candidate14','stage','aggregate-debug','aggregate-releasefast','aggregate-x86',
             'encoder-build','profile-build','state-native','state-x86','restored-cost-check','post-rebase']:
 directory=base/name
 if directory.exists():
  target=out/name;target.mkdir(exist_ok=True)
  for p in directory.iterdir():
   if p.is_file() and p.suffix in ['.json','.csv','.log']:shutil.copy2(p,target/p.name)
if (base/'rejected-source').exists():shutil.copytree(base/'rejected-source',out/'rejected-source',dirs_exist_ok=True)
files={str(p.relative_to(out)):hashlib.sha256(p.read_bytes()).hexdigest() for p in out.rglob('*') if p.is_file() and p.name!='artifact-manifest.json'}
(out/'artifact-manifest.json').write_text(json.dumps({'files':files},indent=2)+'\n')
print(json.dumps({'files':len(files),'bytes':sum(p.stat().st_size for p in out.rglob('*') if p.is_file())}))
