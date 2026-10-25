from pathlib import Path
import hashlib,json,shutil
base=Path('/tmp/vort-brotli-q8-profile-20261025')
root=Path('/home/passchaos/project-z/vort-brotli-q8-profile')
out=root/'docs/performance/data/brotli-q8-profile-20261025'
out.mkdir(parents=True,exist_ok=True)
names=['profile-executable.json','public-executable.json','input-manifest.json','analysis.json','br-tool-source-bindings.json',
       'profile-review.md','profile-elf.md','profile-elf.json','final-evidence-review.md',
       'next-context-profile-plan.md','tool-build-smoke.json','tool-smoke-gate.json',
       'tool-paths-smoke.json','tool-file-smoke.json','run_profile.py','run_public.py','analyze_profile.py','run_command.py','archive.py']
for name in names:
 p=base/name
 if p.is_file():shutil.copy2(p,out/name)
groups=['baseline14','public14','profile14','contracts-debug','contracts-releasefast','contracts-x86',
        'contracts-debug-fixed','contracts-releasefast-fixed','contracts-x86-fixed','tool-build','tool-build-fixed',
        'contracts-debug-linked','contracts-releasefast-linked','contracts-x86-linked','public-bench-build',
        'tool-paths-build','complete-family','complete-check','final-check','cli-help','post-rebase','python-gates']
for group in groups:
 directory=base/group
 if directory.exists():
  target=out/group;target.mkdir(exist_ok=True)
  for p in directory.iterdir():
   if p.is_file() and p.suffix in ['.json','.csv','.log']:shutil.copy2(p,target/p.name)
if (base/'focusedasm').exists():shutil.copytree(base/'focusedasm',out/'focusedasm',dirs_exist_ok=True)
files={str(p.relative_to(out)):hashlib.sha256(p.read_bytes()).hexdigest() for p in out.rglob('*') if p.is_file() and p.name!='artifact-manifest.json'}
(out/'artifact-manifest.json').write_text(json.dumps({'files':files},indent=2)+'\n')
print(json.dumps({'files':len(files),'bytes':sum(p.stat().st_size for p in out.rglob('*') if p.is_file())}))
