from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import datetime,hashlib,json,subprocess
base=Path('/tmp/vort-deflate64-index-capacity-20261025');root=Path('/home/passchaos/project-z/vort-brotli-context-cache');oldroot=Path('/home/passchaos/project-z/vort');zig='/home/passchaos/Temp/zig-x86_64-linux-0.16.0/zig'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def snapshot(tree):
 paths=list((tree/'src').rglob('*'))+list((tree/'tools').rglob('*'))+[tree/'build.zig',tree/'build.zig.zon']
 return {str(p.relative_to(tree)):sha(p) for p in paths if p.is_file() and '__pycache__' not in p.parts and p.suffix!='.pyc'}
before={str(tree):snapshot(tree) for tree in (oldroot,root)};started=datetime.datetime.now(datetime.timezone.utc).isoformat()
def build(label,tree,cpus):
 out=base/('build-'+label);out.mkdir(exist_ok=True);exe=base/(label+'-index-probe-final')
 cmd=['taskset','-c',cpus,zig,'build-exe','-O','ReleaseFast','--dep','codec','--dep','benchmark_provenance','-Mroot='+str(root/'tools/deflate64_index_probe.zig'),'-Mcodec='+str(tree/'src/deflate64.zig'),'-Mbenchmark_provenance='+str(tree/'tools/benchmark_provenance.zig'),'-femit-bin='+str(exe)]
 with out.joinpath('run.log').open('wb') as log:r=subprocess.run(cmd,cwd=root,stdout=log,stderr=subprocess.STDOUT)
 return dict(label=label,command=cmd,exit_code=r.returncode,executable=str(exe),executable_sha256=sha(exe) if r.returncode==0 else None,log_sha256=sha(out/'run.log'))
with ThreadPoolExecutor(max_workers=2) as pool:
 futures=[pool.submit(build,'old',oldroot,'2-5,10-13'),pool.submit(build,'new',root,'6-7,14-15')];rows=[f.result() for f in futures]
after={str(tree):snapshot(tree) for tree in (oldroot,root)};meta=dict(start_utc=started,end_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),runs=rows,source_before=before,source_after=after,source_stable=before==after,tool_sha256=sha(root/'tools/deflate64_index_probe.zig'),zig_sha256=sha(Path(zig)),scope='Old/new common resource/timing tool compiled in parallel against distinct codec source roots. Complete before/after src/tools/build identity, no source attribution inferred from later artifacts.')
base.joinpath('probe-builds.json').write_text(json.dumps(meta,indent=2)+'\n');print(rows,flush=True);assert before==after and all(r['exit_code']==0 for r in rows)
