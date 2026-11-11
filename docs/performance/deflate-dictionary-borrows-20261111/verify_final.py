#!/usr/bin/env python3
"""Verify final acceptance artifacts separately from the immutable worker proof."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--external-root', type=Path)
    parser.add_argument('--source-root', type=Path, default=Path(__file__).resolve().parents[3])
    options = parser.parse_args()
    archive = Path(__file__).resolve().parent
    subprocess.run([sys.executable, str(archive / 'verify.py'), '--source-root', str(options.source_root)], check=True)
    data = json.loads((archive / 'validation.json').read_text())
    checked = 0
    for name, expected in data['archive_file_sha256'].items():
        assert hashlib.sha256((archive / name).read_bytes()).hexdigest() == expected, name
        checked += 1
    for name, expected in data['source_file_sha256'].items():
        content = subprocess.check_output(['git', 'show', data['implementation_revision'] + ':' + name], cwd=options.source_root)
        assert hashlib.sha256(content).hexdigest() == expected, name
        assert hashlib.sha256((options.source_root / name).read_bytes()).hexdigest() == expected, name
        checked += 2
    receipt = json.loads((archive / 'dictionary-wasm-receipt.json').read_text())
    assert receipt['ok'] and receipt['aggregate_exit_code'] == 0
    assert all(item['actual_exit_code'] == 0 for item in receipt['artifacts'])
    clone = json.loads((archive / 'clone-decode-report.json').read_text())
    assert clone['status'] == 'ok' and clone['cases'] == 40
    assert {event['label'] for event in clone['events']} == {'native', 'x86'}
    assert all(event['name'].startswith('decode-') and event['exit_code'] == 0 for event in clone['events'])
    assert data['observed_exit_codes'] == [0] * len(data['commands'])
    if options.external_root:
        retained = data['new_external_artifacts']
        for name, expected in retained['binary_sha256'].items():
            assert hashlib.sha256((options.external_root / name).read_bytes()).hexdigest() == expected, name
            checked += 1
        root = options.external_root / 'clone-decode-external'
        files = retained['clone-decode-external']['files_sha256']
        assert sum(1 for p in root.rglob('*') if p.is_file()) == len(files)
        for name, expected in files.items():
            assert hashlib.sha256((root / name).read_bytes()).hexdigest() == expected, name
            checked += 1
    print('Final acceptance verified:', checked, 'artifact/source checks, actual WASI, 40 decoder clone events')


if __name__ == '__main__':
    main()
