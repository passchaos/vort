from pathlib import Path
import datetime,hashlib,json,subprocess
base=Path('/tmp/vort-brotli-context-cache-20261025')
root=Path('/home/passchaos/project-z/vort-brotli-context-cache')
out=base/'post-rebase';out.mkdir(exist_ok=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def snapshot():
 paths=list((root/'src').rglob('*'))+list((root/'tools').rglob('*'))+[root/'build.zig',root/'build.zig.zon']
 return {str(p.relative_to(root)):sha(p) for p in paths if p.is_file() and "__pycache__" not in p.parts and p.suffix != ".pyc"}
before=snapshot()
command=['taskset','-c','2-7','/home/passchaos/Temp/zig-x86_64-linux-0.16.0/zig','test','src/br.zig',str(base/'record-releasefast.o'),'--test-filter','literal context','--test-filter','q8 quality profile','-O','ReleaseFast']
started=datetime.datetime.now(datetime.timezone.utc).isoformat()
with (out/'test.log').open('wb') as log:
 result=subprocess.run(command,cwd=root,stdout=log,stderr=subprocess.STDOUT)
assert result.returncode==0
assert b'All 76 tests passed.' in (out/'test.log').read_bytes()
exe=Path(json.loads((base/'restored-profile-executable.json').read_text())['path'])
command_smoke=['python3','tools/br/quality_stage_profile_smoke.py','--executable',str(exe),'--output',str(out/'file-smoke.json')]
result_smoke=subprocess.run(command_smoke,cwd=root,capture_output=True,text=True)
assert result_smoke.returncode==0,result_smoke.stderr
after=snapshot();assert before==after
metadata={'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),
 'started_utc':started,'completed_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
 'test_command':command,'test_exit_code':result.returncode,'passed_test_count':76,
 'smoke_command':command_smoke,'smoke_exit_code':result_smoke.returncode,
 'record_object_sha256':sha(base/'record-releasefast.o'),'profile_executable_sha256':sha(exe),
 'source_before':before,'source_after':after,'source_stable':True,
 'scope':'Full src/tools/build before-after hash coverage for handoff checks. Final restored runtime and tools checks have full source coverage; candidate timing evidence retains its separate source/executable epoch.'}
(out/'result.json').write_text(json.dumps(metadata,indent=2)+'\n')
print(json.dumps({k:v for k,v in metadata.items() if not k.startswith('source_')}),flush=True)
