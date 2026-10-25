from pathlib import Path
import hashlib,json,shutil
base=Path('/tmp/vort-brotli-context-cache-20261025');root=Path('/home/passchaos/project-z/vort-brotli-context-cache');out=root/'docs/performance/data/brotli-context-score-20261025';out.mkdir(parents=True,exist_ok=True)
for p in base.rglob('*'):
 if not p.is_file() or '__pycache__' in p.parts:continue
 if p.suffix not in ('.json','.csv','.log','.md','.py','.zig','.asm','.txt'):continue
 # Source snapshots are bounded to the changed codec/diagnostic files, not a
 # second complete monolithic br root copied into the report.
 if 'candidate-source-parent' in p.parts and p.name=='br.zig':continue
 target=out/p.relative_to(base);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,target)
files={str(p.relative_to(out)):hashlib.sha256(p.read_bytes()).hexdigest() for p in out.rglob('*') if p.is_file() and p.name!='artifact-manifest.json'}
out.joinpath('artifact-manifest.json').write_text(json.dumps({'files':files,'scope':'Candidate and restored-runtime epochs are separate. Raw source/executable identities, unsuccessful attempts, compiler monitors, functional and timing evidence are retained. No binary, object, or corpus contents copied.'},indent=2)+'\n')
assert all(hashlib.sha256((out/name).read_bytes()).hexdigest()==sha for name,sha in files.items())
print(json.dumps({'files':len(files),'bytes':sum(p.stat().st_size for p in out.rglob('*') if p.is_file())}))
