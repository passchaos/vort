"""Independent paired statistical math; no producer or filesystem imports."""
import math,random
from package_io import require


def close(a,b,label):require(math.isclose(a,b,rel_tol=1e-12,abs_tol=1e-12),'Statistic differs: '+label)


def geometric(values):
    values=list(values);require(values and all(v>0 for v in values),'Nonpositive paired ratio')
    return math.exp(math.fsum(math.log(value) for value in values)/len(values))


def mean(values):
    values=list(values);return math.fsum(values)/len(values)


def percentile(values):
    values=sorted(values)
    return [values[int((len(values)-1)*p)] for p in [.025,.975]]


def stratified(pairs,seed):
    strata=[[p['ratio'] for p in pairs if p['order'][0]==name] for name in ['old_exact','current']]
    require(all(strata),'Missing AB/BA stratum')
    rng=random.Random(seed)
    return percentile(geometric(rng.choice(group) for group in strata for _ in group) for _ in range(20000))


def matrix_ci(pairs):
    # Each sampled round is the same corpus block for all12 primary rows.
    logs={i:mean(math.log(p['ratio']) for p in pairs if p['round']==i) for i in range(6)}
    rng=random.Random('matrix-explicit16')
    draws=[]
    for _ in range(20000):
        rounds=[rng.choice((0,2,4)) for _ in range(3)]+[rng.choice((1,3,5)) for _ in range(3)]
        draws.append(math.exp(mean(logs[i] for i in rounds)))
    return percentile(draws)
