from pathlib import Path
import hashlib,json,shutil
base=Path('/tmp/vort-br-tree-cost-20261025');root=Path('/home/passchaos/project-z/vort-brotli-context-cache');out=root/'docs/performance/data/brotli-dense-huffman-20261025';out.mkdir(parents=True,exist_ok=True)
for p in base.rglob('*'):
 if not p.is_file() or '__pycache__' in p.parts or p.suffix not in ['.json','.csv','.log','.md','.py','.zig','.asm','.txt']:continue
 t=out/p.relative_to(base);t.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,t)
files={str(p.relative_to(out)):hashlib.sha256(p.read_bytes()).hexdigest() for p in out.rglob('*') if p.is_file() and p.name!='artifact-manifest.json'}
out.joinpath('artifact-manifest.json').write_text(json.dumps(dict(files=files,scope='Exact dense Huffman construction and old/current public q8 comparison. Raw identities, unsuccessful attempts, fixed tests, microbench/public/profile evidence and final source bindings retained separately. No compiler objects/executables or corpus contents included.'),indent=2)+'\n')
assert all(hashlib.sha256((out/p).read_bytes()).hexdigest()==h for p,h in files.items());print(dict(files=len(files),bytes=sum(p.stat().st_size for p in out.rglob('*') if p.is_file())))
