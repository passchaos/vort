#!/usr/bin/env python3
"""Portable data-only verification of completed shared-model archive scope."""
from pathlib import Path
import json
from package_io import read_packages,require
from provenance import verify_provenance
from performance import verify_performance
from validation import verify_validation


def verify(root):
    packages,binding=read_packages(root);files=packages['performance.tar.gz'];validation=packages['validation.tar.gz']
    source=verify_provenance(packages['sources.tar.gz'],files,validation)
    perf=verify_performance(files);focused=verify_validation(validation)
    status=json.loads((root/'gate-status.json').read_bytes())
    require(status==focused['full_library_gate'],'Public full-gate status differs')
    merge=perf['full90']['primary_gate_pass'] and perf['public_controls']['all_row_floors_pass'] and perf['small4KiB_controls']['all_row_floors_pass'] and status['actual_exit']==0
    require(merge and status['mergeAllowed'] is True,'Frozen source, functional and declared performance merge gates differ')
    return {'schema':'vort.brotli.shared-literal-model.offline-verification.v1','verified_completed_scope':True,
            'source':source,'performance':perf,'validation':focused,'mergeAllowed':merge,
            'full_library_gate_status':status['status'],'archive_members':{name:len(members) for name,members in binding['members'].items()},
            'scope':'Package data only; no producer imports/codec/foreign/compiler/timing execution; frozen declared gates allow merge, without industry-best or historical3x-repair claim'}


if __name__=='__main__':print(json.dumps(verify(Path(__file__).resolve().parent),indent=2,sort_keys=True))
