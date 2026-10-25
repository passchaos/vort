import heapq,json,random
from pathlib import Path

def package(f,maxbits=15):
 n=len(f);nodes=[(w,None,None,i) for i,w in enumerate(f)];leaves=sorted(range(n),key=lambda i:(nodes[i][0],i));current=list(leaves)
 for d in range(1,maxbits):
  pairs=[]
  for j in range(0,len(current)-1,2):
   a,b=current[j:j+2];i=len(nodes);nodes.append((nodes[a][0]+nodes[b][0],a,b,None));pairs.append(i)
  current=sorted(leaves+pairs,key=lambda i:(nodes[i][0],i))
 multiplicities=[0]*len(nodes)
 for i in current[:2*n-2]:multiplicities[i]+=1
 for i in range(len(nodes)-1,n-1,-1):
  _,a,b,_=nodes[i];multiplicities[a]+=multiplicities[i];multiplicities[b]+=multiplicities[i]
 return multiplicities[:n]
def natural(f):
 nodes=[(w,None,None) for w in f];q=[(w,i) for i,w in enumerate(f)];heapq.heapify(q)
 while len(q)>1:
  a,b=heapq.heappop(q),heapq.heappop(q);i=len(nodes);nodes.append((a[0]+b[0],a[1],b[1]));heapq.heappush(q,(a[0]+b[0],i))
 lengths=[0]*len(f);stack=[(len(nodes)-1,0)]
 while stack:
  i,d=stack.pop();_,a,b=nodes[i]
  if a is None:lengths[i]=d
  else:stack.extend([(a,d+1),(b,d+1)])
 return lengths
state=random.Random(0x6a09e667);count=0;refused=0
for n in [129,130,159,192,255,256]:
 for variant in range(300):
  if variant<4:f=[variant+1]*n
  elif variant%4==0:f=[1+state.randrange(8) for _ in range(n)]
  elif variant%4==1:f=[1+state.randrange(65536) for _ in range(n)]
  elif variant%4==2:f=[1<<state.randrange(31) for _ in range(n)]
  else:f=[1 if i<n-4 else 0xffffffff-state.randrange(100) for i in range(n)]
  f.sort(reverse=True);a=natural(f)
  if max(a)>15:refused+=1;continue
  b=package(f);count+=1
  if a!=b:
   data=dict(equal=False,n=n,variant=variant,freqs=f,natural=a,package=b);Path('/tmp/vort-br-tree-cost-20261025/tie-probe.json').write_text(json.dumps(data));print(data);raise SystemExit(1)
r=dict(equal=True,accepted=count,refused=refused,scope='Independent Python heap-Huffman and serial-tied package-merge algorithm probe; not producer compiled-code verification.')
Path('/tmp/vort-br-tree-cost-20261025/tie-probe.json').write_text(json.dumps(r,indent=2)+'\n');print(r)
