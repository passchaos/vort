from pathlib import Path
import hashlib,json,shutil
base=Path('/tmp/vort-zstd-anchor-cache-20261025');root=Path('/home/passchaos/project-z/vort-zstd-anchor-cache');out=root/'docs/performance/data/zstd-anchor-cache-20261025';out.mkdir(parents=True,exist_ok=True)
names=['input-manifest.json','anchor-review.md','experiment-samples.json','experiment-result.json','experiment-analysis.json','experiment-verification.json','experiment-monitor.json','run_experiment.py','measure.py','run_command.py','archive.py','next-cost-preparation-plan.md','next-accounting-plan.md']
for name in names:
 p=base/name
 if p.is_file():shutil.copy2(p,out/name)
for group in ['baseline14','cache-debug','cache-releasefast','cache-x86','experiment-build','finder-debug','finder-releasefast','finder-x86','complete-family','complete-check','cli-help','route-smoke','default-wire','post-rebase']:
 directory=base/group
 if directory.exists():
  target=out/group;target.mkdir(exist_ok=True)
  for p in directory.iterdir():
   if p.is_file() and p.suffix in ['.json','.csv','.log']:shutil.copy2(p,target/p.name)
count_free=base/'count-free'
if count_free.exists():
 target=out/'count-free';target.mkdir(exist_ok=True)
 for p in count_free.iterdir():
  if p.is_file() and p.suffix in ['.json','.md','.zig','.py','.txt','.log']:shutil.copy2(p,target/p.name)
 if (count_free/'exactasm').exists():shutil.copytree(count_free/'exactasm',target/'exactasm',dirs_exist_ok=True)
files={str(p.relative_to(out)):hashlib.sha256(p.read_bytes()).hexdigest() for p in out.rglob('*') if p.is_file() and p.name!='artifact-manifest.json'}
(out/'artifact-manifest.json').write_text(json.dumps({'files':files},indent=2)+'\n');print(json.dumps({'files':len(files),'bytes':sum(p.stat().st_size for p in out.rglob('*') if p.is_file())}))
