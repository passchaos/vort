from pathlib import Path
import datetime,hashlib,json,subprocess
base=Path('/tmp/vort-brotli-context-cache-20261025');root=Path('/home/passchaos/project-z/vort-brotli-context-cache');zig='/home/passchaos/Temp/zig-x86_64-linux-0.16.0/zig'
files=[base/'cache_layout.zig',root/'src/br/encoder/literal_tree_score_cache.zig',root/'src/br/encoder/literal_context_profile.zig',root/'src/br/encoder/quality_profile.zig']
def snapshot():return {str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
before=snapshot();rows=[]
for target in ['native','x86-linux-gnu']:
 command=['taskset','-c','6-7,14-15',zig,'build-exe','-O','ReleaseFast','-femit-bin='+str(base/('cache-layout-'+target))]
 if target!='native':command+=['-target',target]
 command+=['--dep','cache','--dep','quality','-Mroot='+str(base/'cache_layout.zig'),'-Mcache=src/br/encoder/literal_tree_score_cache.zig','-Mquality=src/br/encoder/quality_profile.zig']
 compiled=subprocess.run(command,cwd=root,capture_output=True,text=True);assert compiled.returncode==0,compiled.stderr
 exe=base/('cache-layout-'+target);run=subprocess.run([str(exe)],capture_output=True,text=True);assert run.returncode==0,run.stderr
 rows.append(dict(target=target,command=command,executable_sha256=hashlib.sha256(exe.read_bytes()).hexdigest(),output=run.stderr))
after=snapshot();assert before==after
(base/'cache-layout.json').write_text(json.dumps(dict(rows=rows,source_before=before,source_after=after,source_stable=True,end_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),scope='ABI sizes only; not complete stack, heap, or RSS.'),indent=2)+'\n')
print(json.dumps(rows),flush=True)
