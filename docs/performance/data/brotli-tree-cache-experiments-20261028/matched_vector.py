import csv,hashlib,json,math,statistics,subprocess,sys
from pathlib import Path
root=Path(sys.argv[1]);corpus=Path("/home/passchaos/Work/corpora/silesia-20261025/files");paths=sorted(corpus.iterdir());out=root/("matched-vector-"+sys.argv[2]);out.mkdir(exist_ok=True)
records=[];values={};shapes={};reference={}
for block in range(int(sys.argv[2])):
 for limit in [4096,16384,65536]:
  labels=["baseline","candidate"] if block%2==0 else ["candidate","baseline"]
  for label in labels:
   jp=out/f"{label}-{block}-{limit}.json";cp=jp.with_suffix(".csv")
   cmd=["taskset","-c","2",str(root/("bench-baseline" if label=="baseline" else "bench-vector")),"--quality","8","--planned-quality=8","--planned-mode=generic","--reference-lgwin=16","--reference-mode=generic","--iterations","3","--limit",str(limit),"--samples-json",str(jp),"--csv",str(cp)]
   for role,lib in [("encoder","libbrotlienc"),("decoder","libbrotlidec"),("common","libbrotlicommon")]:cmd.extend(["--libbrotli-"+role,str(root/"reference-build"/(lib+".so.1.2.0"))])
   for path in paths:cmd.extend(["--path",str(path)])
   subprocess.run(cmd,check=True);data=json.loads(jp.read_text());assert data["reference_version"]==0x1002000;assert len(data["rows"])==12
   for row in data["rows"]:
    key=(row["case"],row["input_bytes"]);s=row["settings"];assert s["parameters_match"] and s["vort_wire_window_bits"]==s["reference_wire_window_bits"]==16
    shape=(row["input_sha256"],row["wires"],s)
    if key in shapes:assert shapes[key]==shape
    shapes[key]=shape;values.setdefault((key,label),[]).extend(r["vort_ns"]/row["iterations"] for r in row["rounds"])
    if label=="candidate":reference.setdefault(key,[]).extend(r["reference_ns"]/row["iterations"] for r in row["rounds"])
   records.append(dict(block=block,label=label,limit=limit,command=cmd,result=data,csv=cp.read_text()))
rows=[]
for key in sorted(shapes):
 old=statistics.median(values[key,"baseline"]);new=statistics.median(values[key,"candidate"]);ref=statistics.median(reference[key]);wires=shapes[key][1]
 rows.append(dict(case=key[0],input_bytes=key[1],baseline_ns=old,candidate_ns=new,reference_ns=ref,ratio=new/old,candidate_over_reference_time=new/ref,candidate_wire_bytes=wires["vort_bytes"],reference_wire_bytes=wires["reference_bytes"],size_ratio=wires["vort_bytes"]/wires["reference_bytes"]))
result=dict(cases=len(rows),all_wires_settings_equal=True,all_parameters_match=True,geometric_ratio=math.exp(statistics.mean(math.log(r["ratio"]) for r in rows)),reference_time_ratio=math.exp(statistics.mean(math.log(r["candidate_over_reference_time"]) for r in rows)),size_ratio=math.exp(statistics.mean(math.log(r["size_ratio"]) for r in rows)),rows=rows,raw=records)
(out/"comparison.json").write_text(json.dumps(result,indent=2)+"\n")
print(json.dumps({k:v for k,v in result.items() if k not in ["rows","raw"]}))
