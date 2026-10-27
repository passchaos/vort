import hashlib,json,re,statistics,subprocess,sys
from pathlib import Path
root=Path(sys.argv[1]);paths=sorted(p for p in (root/"corpus").glob("*.bin") if any(p.name.startswith(n+"-") for n in ["mozilla","samba","dickens","xml","mr","x-ray"]));records=[];values={};shapes={}
for block in range(7):
 for path in paths:
  labels=["baseline","candidate"] if block%2==0 else ["candidate","baseline"]
  for label in labels:
   cmd=["taskset","-c","2",str(root/("q8-"+label)),str(path),"5"]
   output=subprocess.check_output(cmd,text=True)
   row=dict(re.findall(r"(\w+)=(\w+)",output));ns=int(row["ns"])/int(row["iterations"])
   shape=(row["input"],row["wire"],row["wire_sha"])
   if path.name in shapes: assert shapes[path.name]==shape
   shapes[path.name]=shape;values.setdefault((path.name,label),[]).append(ns)
   records.append(dict(block=block,label=label,command=cmd,raw=output,ns_per_call=ns,input_sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
rows=[]
for path in paths:
 old=statistics.median(values[path.name,"baseline"]);new=statistics.median(values[path.name,"candidate"])
 rows.append(dict(case=path.name,baseline_ns=old,candidate_ns=new,ratio=new/old,wire_sha256=shapes[path.name][2]))
import math
result=dict(geometric_ratio=math.exp(statistics.mean(math.log(row["ratio"]) for row in rows)),rows=rows,raw=records)
(root/"q8-comparison.json").write_text(json.dumps(result,indent=2)+"\n")
print(json.dumps(dict(geometric_ratio=result["geometric_ratio"],cases=len(rows),all_wires_equal=True)))
