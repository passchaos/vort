from pathlib import Path
import hashlib,json,shutil
base=Path('/tmp/vort-zstd-frequency-merge-20261025');root=Path('/home/passchaos/project-z/vort-zstd-frequency-merge');out=root/'docs/performance/data/zstd-frequency-merge-20261025';out.mkdir(parents=True,exist_ok=True)
names=['input-manifest.json','candidate-executable.json','analysis.json','micro-samples.json','micro-analysis.json','micro-result.json','merge-review.md','merge-elf.md','merge-elf.json','candidate-work.json','candidate-work-result.json','next-paired-finder-plan.md','measure.py','run_command.py','archive.py']
for name in names:
 p=base/name
 if p.is_file():shutil.copy2(p,out/name)
for group in ['baseline14','candidate14','merge-debug','merge-releasefast','merge-x86','micro-build','encoder-build','complete-family','complete-check','cli-help','route-smoke','post-rebase']:
 source=base/group
 if source.exists():
  target=out/group;target.mkdir(exist_ok=True)
  for p in source.iterdir():
   if p.is_file() and p.suffix in ['.json','.csv','.log']:shutil.copy2(p,target/p.name)
if (base/'merge-elf-evidence').exists():shutil.copytree(base/'merge-elf-evidence',out/'merge-elf-evidence',dirs_exist_ok=True)
files={str(p.relative_to(out)):hashlib.sha256(p.read_bytes()).hexdigest() for p in out.rglob('*') if p.is_file() and p.name!='artifact-manifest.json'}
(out/'artifact-manifest.json').write_text(json.dumps({'files':files},indent=2)+'\n');print(json.dumps({'files':len(files),'bytes':sum(p.stat().st_size for p in out.rglob('*') if p.is_file())}))
