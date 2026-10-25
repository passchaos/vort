from pathlib import Path
import hashlib,json,shutil
base=Path('/tmp/vort-zstd-single-price-20261025');root=Path('/home/passchaos/project-z/vort-zstd-single-price');out=root/'docs/performance/data/zstd-single-price-20261025';out.mkdir(parents=True,exist_ok=True)
names=['candidate-executable.json','input-manifest.json','analysis.json','micro-samples.json','micro-result.json','micro-analysis.json','module-debug.log','offset-debug.log','offset-debug-final.log','candidate-work.json','candidate-work-result.json','single-cost-review.md','single-cost-elf.md','single-cost-elf.json','measure.py','run_command.py','archive.py']
for name in names:
 p=base/name
 if p.is_file():shutil.copy2(p,out/name)
groups=['baseline14','candidate14','candidate14-compile-overlap','micro-build','scalar-debug','scalar-releasefast','scalar-x86','scalar-debug-final','scalar-releasefast-final','scalar-x86-final','winner-debug','winner-x86','encoder-build','encoder-build-final','complete-family','complete-check','cli-help','route-smoke','post-rebase']
for group in groups:
 source=base/group
 if source.exists():
  target=out/group;target.mkdir(exist_ok=True)
  for p in source.iterdir():
   if p.is_file() and p.suffix in ['.json','.csv','.log']:shutil.copy2(p,target/p.name)
for directory in ['single-cost-elf-evidence']:
 if (base/directory).exists():shutil.copytree(base/directory,out/directory,dirs_exist_ok=True)
if (base/'memory').exists():
 target=out/'memory';target.mkdir(exist_ok=True)
 for p in (base/'memory').iterdir():
  if p.is_file() and p.suffix in ['.json','.md','.zig','.py','.log','.txt']:shutil.copy2(p,target/p.name)
files={str(p.relative_to(out)):hashlib.sha256(p.read_bytes()).hexdigest() for p in out.rglob('*') if p.is_file() and p.name!='artifact-manifest.json'}
(out/'artifact-manifest.json').write_text(json.dumps({'files':files},indent=2)+'\n');print(json.dumps({'files':len(files),'bytes':sum(p.stat().st_size for p in out.rglob('*') if p.is_file())}))
