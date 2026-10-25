from pathlib import Path
import datetime,hashlib,json,subprocess,time
base=Path('/tmp/vort-brotli-q8-profile-20261025')
root=Path('/home/passchaos/project-z/vort-brotli-q8-profile')
prep=json.loads(Path('/tmp/vort-current-encode-baseline-20261025/preparation.json').read_text())
exe=Path(json.loads((base/'profile-executable.json').read_text())['path'])
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def snapshot():return {str(p.relative_to(root)):sha(p) for p in (root/'src').rglob('*.zig')}
before=snapshot();out=base/'profile14';out.mkdir(exist_ok=True)
command=['taskset','-c','8',str(exe),'--rounds','5','--json',str(out/'samples.json')]
for row in prep['selected_inputs']:
 assert sha(row['frozen_path'])==row['input_sha256']
 command.extend(['--path',row['frozen_path']])
meta={'command':command,'source_before':before,'executable_sha256':sha(exe),
      'start_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
      'scope':'Actual q8 profile and ordinary encoding alternate in one process; every profiled wire is compared with the ordinary public encoder. Profile stages are instrumented and must not be ranked as competitor throughput.'}
monitors=[]
with (out/'run.log').open('wb') as log:
 process=subprocess.Popen(command,cwd=root,stdout=log,stderr=subprocess.STDOUT)
 while True:
  monitors.append({'monotonic_ns':time.monotonic_ns(),'compilers':subprocess.run(['ps','-C','zig,clang,clang++,cc1,cc1plus','-o','pid=,comm='],capture_output=True,text=True).stdout.strip()})
  try:code=process.wait(timeout=.1);break
  except subprocess.TimeoutExpired:pass
after=snapshot();meta.update(exit_code=code,end_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),source_after=after,
 source_stable=before==after,compiler_observations=len(monitors),compiler_observations_with_process=sum(bool(p['compilers']) for p in monitors))
(out/'compiler-monitor.json').write_text(json.dumps(monitors)+'\n');(out/'result.json').write_text(json.dumps(meta,indent=2)+'\n')
assert code==0 and before==after and meta['compiler_observations_with_process']==0
command=['python3','tools/br/quality_profile_gate.py','--json',str(out/'samples.json'),'--executable',str(exe),'--output',str(out/'gate-result.json')]
gate=subprocess.run(command,cwd=root,capture_output=True,text=True)
assert gate.returncode==0,gate.stdout+gate.stderr
old=json.loads((base/'baseline14/samples.json').read_text())
prior={row['input_sha256']:row for row in old['rows']}
report=json.loads((out/'samples.json').read_text())
for row in report['rows']:
 assert row['wire_bytes']==prior[row['input_sha256']]['wires']['vort_bytes']
 assert row['wire_sha256']==prior[row['input_sha256']]['wires']['vort_sha256']
print(json.dumps({'rows':len(report['rows']),'rounds':sum(len(r['rounds']) for r in report['rows']),
                 'all_old_wires_equal':True,'all_event_and_timing_gates_passed':True,'source_stable':True,
                 'compiler_observations_with_process':0}),flush=True)
