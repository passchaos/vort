from pathlib import Path
import hashlib,json,shutil
base=Path('/tmp/vort-zstd-cost-bound-20261025');root=Path('/home/passchaos/project-z/vort-zstd-cost-bound');out=root/'docs/performance/data/zstd-winner-bound-20261025';out.mkdir(parents=True,exist_ok=True)
names=['analysis.json','input-manifest.json','candidate-executable.json','bound-contract-audit.md','winner-cache-review.md','weighted-module-contract.md','shadow-work.json','shadow-result.json','prune-work-initial.json','weighted-debug.log','weighted-releasefast.log','weighted-x86.log','winner-extended-debug.log','winner-extended-releasefast.log','winner-extended-x86.log','shadow-profile-debug.log','shadow-profile-releasefast.log','shadow-build.log','prune-build.log','prepared-legacy-debug.log','encoder-build.log','measure.py','run_command.py','archive.py','next-bound-hotpath.md']
for name in names:
 p=base/name
 if p.is_file():shutil.copy2(p,out/name)
for group in ['current14','complete-family','complete-check','cli-help','post-rebase']:
 directory=base/group
 if directory.exists():
  target=out/group;target.mkdir(exist_ok=True)
  for p in directory.iterdir():
   if p.is_file() and p.suffix in ['.json','.csv','.log']:shutil.copy2(p,target/p.name)
if (base/'memory').exists():
 target=out/'memory';target.mkdir(exist_ok=True)
 for p in (base/'memory').iterdir():
  if p.is_file() and p.suffix in ['.json','.md','.zig','.py','.log','.txt']:shutil.copy2(p,target/p.name)
files={str(p.relative_to(out)):hashlib.sha256(p.read_bytes()).hexdigest() for p in out.rglob('*') if p.is_file() and p.name!='artifact-manifest.json'}
(out/'artifact-manifest.json').write_text(json.dumps({'files':files},indent=2)+'\n')
print(json.dumps({'files':len(files),'bytes':sum(p.stat().st_size for p in out.rglob('*') if p.is_file())}))
