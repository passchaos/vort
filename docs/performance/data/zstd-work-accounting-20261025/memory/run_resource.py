from pathlib import Path
import os,json,hashlib,subprocess,sys,re
root=Path(__file__).resolve().parent
kind=sys.argv[1]
setup=json.loads((root/'setup.json').read_text())
tree=Path(setup['worktrees'][kind])
assert not (root/(kind+'-execution.json')).exists(),'Refusing to repeat the completed XML resource execution'
built=json.loads((root/(kind+'-build.json')).read_text())
assert len(built['commands'])==2 and all(command['exit']==0 for command in built['commands'])
head_before=subprocess.run(['git','rev-parse','HEAD'],cwd=tree,capture_output=True,text=True,check=True).stdout.strip()
assert head_before==setup['heads'][kind]
paths=sorted((tree/'src').rglob('*.zig'))
before={str(p.relative_to(tree)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
assert before==json.loads((root/(kind+'-source-before.json')).read_text())
command=['taskset','-c','8',str(root/('probe-'+kind))]
with (root/(kind+'.stdout')).open('wb') as stdout,(root/(kind+'.log')).open('wb') as stderr:
 p=subprocess.run(command,cwd=tree,stdout=stdout,stderr=stderr)
log=(root/(kind+'.log')).read_text()
def row(label):
 matches=re.findall(r'(?m)^'+label+r' (\{[^\n]+\})',log)
 return json.loads(matches[-1]) if matches else None
returned=row('RETURN');cleanup=row('CLEANUP');oom=row('OOM')
events=[json.loads(value) for value in re.findall(r'(?m)^EVENT (\{[^\n]+\})',log)]
(root/(kind+'-allocation-events.json')).write_text(json.dumps(events,indent=2)+'\n')
after={str(p.relative_to(tree)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
head_after=subprocess.run(['git','rev-parse','HEAD'],cwd=tree,capture_output=True,text=True,check=True).stdout.strip()
result={'head_before':head_before,'head_after':head_after,'command':command,'exit':p.returncode,'source_stable':before==after,'source_sha256':after['src/zstd.zig'],'executable_sha256':hashlib.sha256((root/('probe-'+kind)).read_bytes()).hexdigest(),'object_sha256':hashlib.sha256((root/(kind+'-x2.o')).read_bytes()).hexdigest(),'returned':returned,'cleanup':cleanup,'optional_small_oom':oom,'request_event_count':len(events),'input_bytes':setup['input_bytes'],'input_sha256':setup['input_sha256'],'scope':setup['scope'],'shared_build_environment':setup['concurrent_environment']}
(root/(kind+'-source-after.json')).write_text(json.dumps(after,indent=2)+'\n')
(root/(kind+'-execution.json')).write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
assert p.returncode==0 and returned['output_bytes']==5078 and returned['output_sha256']==setup['expected_output_sha256']
assert cleanup['live_after_caller_free']==0 and cleanup['increased_bytes']==cleanup['released_bytes']
assert before==after

assert before==after # Source bytes, not a commit-only HEAD transition, bind this resource run.
