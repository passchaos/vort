from pathlib import Path
import hashlib,json,shutil
base=Path('/tmp/vort-zstd-wide-reduction-20261025');root=Path('/home/passchaos/project-z/vort-zstd-wide-reduction');out=root/'docs/performance/data/zstd-wide-reduction-20261025';out.mkdir(parents=True,exist_ok=True)
names=['input-manifest.json','candidate-executable.json','analysis.json','kernel-analysis.json','kernel-samples.json','reduction-review.md','source-notes.md','reduction-elf.md','reduction-elf.json','candidate-work.json','candidate-work-result.json','measure.py','run_command.py','archive.py','next-single-sequence-cost.md']
for name in names:
 p=base/name
 if p.is_file():shutil.copy2(p,out/name)
for group in ['baseline14','candidate14','reduction-debug','reduction-releasefast','reduction-x86','kernel-build','encoder-build','complete-family','complete-check','cli-help','kernel-route-smoke','post-rebase']:
 source=base/group
 if source.exists():
  target=out/group;target.mkdir(exist_ok=True)
  for p in source.iterdir():
   if p.is_file() and p.suffix in ['.json','.csv','.log']:shutil.copy2(p,target/p.name)
for directory in ['reduction-elf-evidence']:
 if (base/directory).exists():shutil.copytree(base/directory,out/directory,dirs_exist_ok=True)
files={str(p.relative_to(out)):hashlib.sha256(p.read_bytes()).hexdigest() for p in out.rglob('*') if p.is_file() and p.name!='artifact-manifest.json'}
(out/'artifact-manifest.json').write_text(json.dumps({'files':files},indent=2)+'\n');print(json.dumps({'files':len(files),'bytes':sum(p.stat().st_size for p in out.rglob('*') if p.is_file())}))
