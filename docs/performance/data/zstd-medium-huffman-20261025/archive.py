from pathlib import Path
import hashlib, json, shutil
base=Path('/tmp/vort-zstd-duplicate-profile-20261025')
root=Path('/home/passchaos/project-z/vort-zstd-duplicate-profile')
out=root/'docs/performance/data/zstd-medium-huffman-20261025'
out.mkdir(parents=True,exist_ok=True)
top=['input-manifest.json','old-build-metadata.json','old-build.log','baseline-profile-source.json',
     'medium-workspace.md','medium-workspace-review.md','frequency-plan-review.md',
     'industry-status.md','medium-elf-stack.md','medium-elf-stack.json','candidate-executable.json',
     'analysis.json','next-exact-cost-plan.md']
groups=['focused-debug','focused-releasefast','focused-x86','profile-contract-debug','profile-contract-releasefast',
        'build-old-profile','build-new-profile','work-old','work-new','public-old','public-new','wire14',
        'medium-debug','medium-releasefast','medium-x86','medium-encoder-build','complete-family','complete-check',
        'cli-help','diagnostic-smoke','post-rebase-medium','post-rebase-profile']
for name in top:
    p=base/name
    if p.exists(): shutil.copy2(p,out/name)
for group in groups:
    directory=base/group
    if directory.exists():
        target=out/group;target.mkdir(exist_ok=True)
        for p in directory.iterdir():
            if p.is_file() and p.suffix in ('.json','.csv','.log'):
                shutil.copy2(p,target/p.name)
for directory in ('medium-elf-stack-evidence',):
    if (base/directory).exists(): shutil.copytree(base/directory,out/directory,dirs_exist_ok=True)
reject=out/'rejected-frequency-cache';reject.mkdir(exist_ok=True)
source=base/'rejected-frequency-cache'
for p in source.iterdir():
    target=reject/(p.name+'.txt' if p.suffix=='.zig' else p.name)
    shutil.copy2(p,target)
for name in ('measure.py','run_command.py','archive.py','analyze.py'):
    shutil.copy2(base/name,out/name)
files={str(p.relative_to(out)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(out.rglob('*')) if p.is_file() and p.name!='artifact-manifest.json'}
(out/'artifact-manifest.json').write_text(json.dumps({'files':files},indent=2)+'\n')
print(json.dumps({'artifact_files':len(files),'artifact_bytes':sum(p.stat().st_size for p in out.rglob('*') if p.is_file()),'path':str(out)}))
