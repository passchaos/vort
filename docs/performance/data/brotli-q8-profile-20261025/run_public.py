from pathlib import Path
import datetime,hashlib,json,subprocess,time
base=Path('/tmp/vort-brotli-q8-profile-20261025')
root=Path('/home/passchaos/project-z/vort-brotli-q8-profile')
exe=Path(json.loads((base/'public-executable.json').read_text())['path'])
prep=json.loads(Path('/tmp/vort-current-encode-baseline-20261025/preparation.json').read_text())
refs=[Path('/tmp/vort-br-general-experimental-build')/name for name in ('libbrotlienc.so.1.2.0','libbrotlidec.so.1.2.0','libbrotlicommon.so.1.2.0')]
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def snapshot():return {str(p.relative_to(root)):sha(p) for p in (root/'src').rglob('*.zig')}
before=snapshot();out=base/'public14';out.mkdir(exist_ok=True)
command=['taskset','-c','8',str(exe),'--iterations','1','--planned-quality','8','--quality','8','--planned-mode','generic','--limit','65536','--samples-json',str(out/'samples.json'),'--csv',str(out/'samples.csv')]
for flag,path in zip(('--libbrotli-encoder','--libbrotli-decoder','--libbrotli-common'),refs):command.extend([flag,str(path)])
for row in prep['selected_inputs']:
 assert sha(row['frozen_path'])==row['input_sha256']
 command.extend(['--path',row['frozen_path']])
meta={'command':command,'source_before':before,'executable_sha256':sha(exe),
      'references':{str(p):sha(p) for p in refs},'start_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
      'scope':'Ordinary q8 encoder after diagnostic wiring; five alternating Vort/reference raw rounds per frozen64KiB input. No codec speed optimization is claimed by the instrumentation.'}
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
report=json.loads((out/'samples.json').read_text());old=json.loads((base/'baseline14/samples.json').read_text());prior={r['input_sha256']:r for r in old['rows']}
for row in report['rows']:assert row['settings']==prior[row['input_sha256']]['settings'] and row['wires']==prior[row['input_sha256']]['wires']
print(json.dumps({'rows':len(report['rows']),'wire_and_policy_unchanged':True,'source_and_references_stable':True,'compiler_observations_with_process':0}),flush=True)
