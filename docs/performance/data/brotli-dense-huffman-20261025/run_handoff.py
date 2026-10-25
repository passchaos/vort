from pathlib import Path
import datetime,hashlib,json,subprocess
base=Path('/tmp/vort-br-tree-cost-20261025');root=Path('/home/passchaos/project-z/vort-brotli-context-cache');out=base/'post-rebase';out.mkdir(exist_ok=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def snapshot():
 paths=list((root/'src').rglob('*'))+list((root/'tools').rglob('*'))+[root/'build.zig',root/'build.zig.zon']
 return {str(p.relative_to(root)):sha(p) for p in paths if p.is_file() and '__pycache__' not in p.parts and p.suffix!='.pyc'}
before=snapshot();start=datetime.datetime.now(datetime.timezone.utc).isoformat();command=['taskset','-c','2-7,10-15','/home/passchaos/Temp/zig-x86_64-linux-0.16.0/zig','test','src/br.zig',str(base/'record-releasefast.o'),'--test-filter','dense Huffman','--test-filter','literal context','--test-filter','q8 quality profile','-O','ReleaseFast']
with out.joinpath('test.log').open('wb') as log:r=subprocess.run(command,cwd=root,stdout=log,stderr=subprocess.STDOUT)
assert r.returncode==0,out.joinpath('test.log').read_text()[-8000:]
exe=Path(json.loads(base.joinpath('profile-executable.json').read_text())['path']);smoke=['python3','tools/br/quality_stage_profile_smoke.py','--executable',str(exe),'--output',str(out/'file-smoke.json')];s=subprocess.run(smoke,cwd=root,capture_output=True,text=True);assert s.returncode==0,s.stderr
after=snapshot();assert before==after
import re
count=re.findall(r'All (\d+) tests passed.',out.joinpath('test.log').read_text());assert count==['78'],count
out.joinpath('result.json').write_text(json.dumps(dict(head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),start_utc=start,end_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),test_command=command,test_exit_code=r.returncode,passed_test_count=78,smoke_command=smoke,smoke_exit_code=s.returncode,profile_executable_sha256=sha(exe),record_object_sha256=sha(base/'record-releasefast.o'),source_before=before,source_after=after,source_stable=True,scope='Post-rebase actual ReleaseFast dense/context/q8 regression and5filealias/report smoke, full src/tools/build snapshot. Separate from timed evidence.'),indent=2)+'\n');print('post-rebase78tests and5file cases pass',flush=True)
