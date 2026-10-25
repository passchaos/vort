from pathlib import Path
import datetime,hashlib,json,subprocess
base=Path('/tmp/vort-deflate64-index-capacity-20261025');root=Path('/home/passchaos/project-z/vort-brotli-context-cache');oldroot=Path('/home/passchaos/project-z/vort');out=base/'resources';out.mkdir(exist_ok=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def snapshot(tree):
 paths=list((tree/'src').rglob('*'))+list((tree/'tools').rglob('*'))+[tree/'build.zig',tree/'build.zig.zon']
 return {str(p.relative_to(tree)):sha(p) for p in paths if p.is_file() and '__pycache__' not in p.parts and p.suffix!='.pyc'}
before={str(t):snapshot(t) for t in [oldroot,root]};rows=[];started=datetime.datetime.now(datetime.timezone.utc).isoformat()
for label in ['old','new']:
 exe=base/(label+'-index-probe-final');cmd=['taskset','-c','8',str(exe)];exe_hash=sha(exe)
 with out.joinpath(label+'.json').open('wb') as samples,out.joinpath(label+'.log').open('wb') as log:r=subprocess.run(cmd,cwd=root,stdout=samples,stderr=log)
 assert r.returncode==0,out.joinpath(label+'.log').read_text();assert exe_hash==sha(exe)
 rows.append(dict(label=label,command=cmd,exit_code=0,executable_sha256=exe_hash,samples_sha256=sha(out/(label+'.json'))))
after={str(t):snapshot(t) for t in [oldroot,root]};assert before==after
cmd=['python3','tools/deflate64_index_gate.py','--old',str(out/'old.json'),'--new',str(out/'new.json'),'--report',str(out/'comparison.json')];gate=subprocess.run(cmd,cwd=root,capture_output=True,text=True);assert gate.returncode==0,gate.stdout+gate.stderr
out.joinpath('result.json').write_text(json.dumps(dict(start_utc=started,end_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),runs=rows,source_before=before,source_after=after,source_stable=True,gate_command=cmd,gate_exit_code=gate.returncode,gate_source_sha256=sha(root/'tools/deflate64_index_gate.py'),scope='Untimed old/new codec requested allocator live/peak resources and exact wire identity. Does not imply compiler-free speed, RSS, backing remap transient or all allocator ranking.'),indent=2)+'\n')
for label in ['old','new']:
 r=json.loads(out.joinpath(label+'.json').read_text());print(label,[(x['name'],x['memory_at_return']['peak_requested_bytes']) for x in r['one_shot']], 'streampeak',r['streaming']['memory_before_deinit']['peak_requested_bytes'],'remaps',r['streaming']['memory_before_deinit']['successful_remaps'])
