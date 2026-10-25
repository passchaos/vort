from pathlib import Path
import datetime,hashlib,json,subprocess
base=Path('/tmp/vort-deflate64-one-shot-20261025');root=Path('/home/passchaos/project-z/vort-brotli-context-cache');out=base/'post-rebase';out.mkdir(exist_ok=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def snapshot():
 paths=list((root/'src').rglob('*'))+list((root/'tools').rglob('*'))+[root/'build.zig',root/'build.zig.zon']
 return {str(p.relative_to(root)):sha(p) for p in paths if p.is_file() and '__pycache__' not in p.parts and p.suffix!='.pyc'}
commands=[('codec',['taskset','-c','2-7,10-15','/home/passchaos/Temp/zig-x86_64-linux-0.16.0/zig','test','src/deflate64.zig','-O','ReleaseFast']),('zip',['taskset','-c','2-7,10-15','/home/passchaos/Temp/zig-x86_64-linux-0.16.0/zig','build','test-zip-deflate64-stream','-Doptimize=ReleaseFast','-j2','--summary','all'])]
before=snapshot();started=datetime.datetime.now(datetime.timezone.utc).isoformat();rows=[]
for name,command in commands:
 with out.joinpath(name+'.log').open('wb') as log:result=subprocess.run(command,cwd=root,stdout=log,stderr=subprocess.STDOUT)
 assert result.returncode==0,out.joinpath(name+'.log').read_text()[-6000:]
 rows.append(dict(name=name,command=command,exit_code=result.returncode))
assert 'All 99 tests passed.' in out.joinpath('codec.log').read_text()
assert '44/44 tests passed' in out.joinpath('zip.log').read_text()
after=snapshot();assert before==after
out.joinpath('result.json').write_text(json.dumps(dict(head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),start_utc=started,end_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),commands=rows,codec_tests=99,zip_tests=44,source_before=before,source_after=after,source_stable=True,scope='Post-rebase actual ReleaseFast Deflate64 and ZIP method9 contracts under full stable source snapshot; external token/unzip campaigns retain their prior source/executable identities.'),indent=2)+'\n');print('post-rebase codec99 andZIP44 pass',flush=True)
