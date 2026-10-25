from pathlib import Path
import datetime,hashlib,json,subprocess,time
base=Path('/tmp/vort-br-tree-cost-20261025')
root=Path('/home/passchaos/project-z/vort')
exe=Path('/home/passchaos/project-z/vort-brotli-context-cache/.zig-cache/o/ee59b567d9fa359fa365d21c6dd4ba7f/vort-br-planned-encode-bench')
prep=json.loads(Path('/tmp/vort-current-encode-baseline-20261025/preparation.json').read_text())
refs=[Path('/tmp/vort-br-general-experimental-build')/name for name in ('libbrotlienc.so.1.2.0','libbrotlidec.so.1.2.0','libbrotlicommon.so.1.2.0')]
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def snapshot():
 paths=list((root/'src').rglob('*'))+list((root/'tools').rglob('*'))+[root/'build.zig',root/'build.zig.zon']
 return {str(p.relative_to(root)):sha(p) for p in paths if p.is_file() and '__pycache__' not in p.parts and p.suffix!='.pyc'}
before=snapshot();out=base/'baseline14';out.mkdir(exist_ok=True)
command=['taskset','-c','8',str(exe),'--iterations','1','--planned-quality','8','--quality','8','--planned-mode','generic','--limit','65536','--samples-json',str(out/'samples.json'),'--csv',str(out/'samples.csv')]
for flag,path in zip(('--libbrotli-encoder','--libbrotli-decoder','--libbrotli-common'),refs):command.extend([flag,str(path)])
for row in prep['selected_inputs']:
 assert sha(row['frozen_path'])==row['input_sha256']
 command.extend(['--path',row['frozen_path']])
meta={'command':command,'source_before':before,'executable_sha256':sha(exe),
      'references':{str(p):sha(p) for p in refs},'start_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
      'scope':'Current f642d0d8 ordinary q8 baseline for exact tree-length optimization; 14 frozen64KiB inputs with five alternating Vort/reference rounds, full source/executable/reference identities and compiler monitor.'}
monitors=[]
with (out/'run.log').open('wb') as log:
 process=subprocess.Popen(command,cwd=root,stdout=log,stderr=subprocess.STDOUT)
 while True:
  monitors.append({'monotonic_ns':time.monotonic_ns(),'compilers':subprocess.run(['ps','-C','zig,clang,clang++,cc1,cc1plus','-o','pid=,comm='],capture_output=True,text=True).stdout.strip()})
  try:code=process.wait(timeout=.1);break
  except subprocess.TimeoutExpired:pass
after=snapshot();meta.update(exit_code=code,end_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),source_after=after,source_stable=before==after,
 compiler_observations=len(monitors),compiler_observations_with_process=sum(bool(m['compilers']) for m in monitors),
 references_stable=all(sha(p)==meta['references'][str(p)] for p in refs))
(out/'result.json').write_text(json.dumps(meta,indent=2)+'\n');(out/'compiler-monitor.json').write_text(json.dumps(monitors)+'\n')
assert code==0 and meta['source_stable'] and meta['references_stable'] and not meta['compiler_observations_with_process']
print('old baseline completed',flush=True)
