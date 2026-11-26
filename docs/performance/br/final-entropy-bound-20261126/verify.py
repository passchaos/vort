#!/usr/bin/env python3
"""Portable verification of the rejected global-bound epoch using package data."""
from pathlib import Path
import json,math
from package_io import read_packages,require
from pilot import verify_pilot
from provenance import verify_provenance


def verify(root):
    packages,binding=read_packages(root)
    provenance=verify_provenance(packages['sources.tar.gz'],packages['bench.tar.gz'],packages['validation.tar.gz'])
    pilot=verify_pilot(packages['bench.tar.gz'])
    summary=json.loads((root/'summary.json').read_bytes())
    require(math.isclose(pilot['point_estimate_speedup_GM'],1.0156422687081639,rel_tol=1e-12) and
            summary['accepted'] is False and summary['CI'] is None and summary['full_approved'] is False and
            summary['owned_release_positive_coverage'] is False,'Published global rejection/coverage scope differs')
    minimum=min(pilot['rows'],key=lambda r:r['speedup_geomean'])
    require(minimum['case']=='nci' and math.isclose(minimum['speedup_geomean'],0.993756037054902,rel_tol=1e-12),
            'Global pilot minimum row differs')
    return {'schema':'vort.brotli.final-entropy-bound.offline-verification.v1','verified':True,
            'pilot':pilot,'provenance':provenance,
            'archive_members':{name:len(members) for name,members in binding['members'].items()},
            'conclusion':'Global primary pilot ROI rejected; no formal CI/full/global industry conclusion or nonzero owned-release coverage',
            'scope':'Package bytes only; no extraction/original-path access/producer import or eval/codec/foreign/build/timing execution'}


if __name__=='__main__':print(json.dumps(verify(Path(__file__).resolve().parent),indent=2,sort_keys=True))
