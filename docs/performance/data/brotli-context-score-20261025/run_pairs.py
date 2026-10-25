from pathlib import Path
import datetime,hashlib,json,subprocess,time,statistics,math
base=Path('/tmp/vort-brotli-context-cache-20261025');root=Path('/home/passchaos/project-z/vort-brotli-context-cache');oldroot=Path('/home/passchaos/project-z/vort-brotli-q8-profile');out=base/'paired14';out.mkdir(exist_ok=True)
commands={name:json.loads(base.joinpath(directory,'result.json').read_text())['command'] for name,directory in [('old','baseline14'),('new','public14')]}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def snapshot(root):
 paths=list((root/'src').rglob('*'))+list((root/'tools').rglob('*'))+[root/'build.zig',root/'build.zig.zon']
 return {str(p.relative_to(root)):sha(p) for p in paths if p.is_file() and '__pycache__' not in p.parts and p.suffix!='.pyc'}
initial={str(r):snapshot(r) for r in [root,oldroot]};exes={n:sha(Path(cmd[3])) for n,cmd in commands.items()};refs=json.loads(base.joinpath('public14/result.json').read_text())['references'];inputs=json.loads(base.joinpath('input-manifest.json').read_text());runs=[];monitors=[]
for pair in range(3):
 for name in (['old','new'] if pair%2==0 else ['new','old']):
  command=list(commands[name]);sample=out/f'pair{pair}-{name}.json';csv=out/f'pair{pair}-{name}.csv'
  command[command.index('--samples-json')+1]=str(sample);command[command.index('--csv')+1]=str(csv)
  runroot=oldroot if name=='old' else root;start=datetime.datetime.now(datetime.timezone.utc).isoformat()
  with (out/f'pair{pair}-{name}.log').open('wb') as log:
   process=subprocess.Popen(command,cwd=runroot,stdout=log,stderr=subprocess.STDOUT)
   while True:
    monitors.append(dict(pair=pair,name=name,monotonic_ns=time.monotonic_ns(),compilers=subprocess.run(['ps','-C','zig,clang,clang++,cc1,cc1plus','-o','pid=,comm='],capture_output=True,text=True).stdout.strip()))
    try:code=process.wait(timeout=.1);break
    except subprocess.TimeoutExpired:pass
  assert code==0
  runs.append(dict(pair=pair,name=name,command=command,cwd=str(runroot),started_utc=start,end_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),exit_code=code))
assert initial=={str(r):snapshot(r) for r in [root,oldroot]}
assert exes=={n:sha(Path(cmd[3])) for n,cmd in commands.items()}
assert all(sha(Path(p))==h for p,h in refs.items()) and all(sha(Path(p))==h for p,h in inputs.items())
assert all(not m['compilers'] for m in monitors)
reports={(run['pair'],run['name']):json.loads(out.joinpath(f"pair{run['pair']}-{run['name']}.json").read_text()) for run in runs};rows=[]
for index,row in enumerate(reports[(0,'old')]['rows']):
 ratios=[]
 for pair in range(3):
  a=reports[(pair,'old')]['rows'][index];b=reports[(pair,'new')]['rows'][index]
  assert a['input_sha256']==b['input_sha256'] and a['settings']==b['settings'] and a['wires']==b['wires']
  ratios.append(statistics.median(r['vort_ns'] for r in a['rounds'])/statistics.median(r['vort_ns'] for r in b['rounds']))
 rows.append(dict(case=row['case'],ratios=ratios,median=statistics.median(ratios),geomean=math.exp(statistics.mean(map(math.log,ratios)))))
result=dict(runs=runs,rows=rows,version_geomean=math.exp(statistics.mean(math.log(r['geomean']) for r in rows)),source_before=initial,source_after=initial,source_stable=True,executable_sha256=exes,reference_files=refs,input_files=inputs,compiler_observations=len(monitors),compiler_observations_with_process=0,scope='Three alternating old/new ordinary q8 version process pairs, every process five Vort/reference rounds per input. Same settings/wires; point ratios with no statistical-significance claim.')
out.joinpath('compiler-monitor.json').write_text(json.dumps(monitors)+'\n');out.joinpath('result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k in ['version_geomean','rows']}),flush=True)
