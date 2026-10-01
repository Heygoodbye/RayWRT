#!/usr/bin/env python3
"""Run the real status helper with missing and restored accounting files."""
import os
import subprocess
import tempfile
from datetime import date
from pathlib import Path

source = Path(__file__).resolve().parents[2] / 'root/usr/libexec/raywrt-usage-control'
if not source.exists():
    source = Path(__file__).resolve().parents[2] / 'package/luci-theme-raywrt/root/usr/libexec/raywrt-usage-control'
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    bindir = root / 'bin'
    bindir.mkdir()
    for name, code in [('uci', 'exit 1'), ('ip', 'exit 0')]:
        stub = bindir / name
        stub.write_text('#!/bin/sh\n' + code + '\n')
        stub.chmod(0o755)
    script = source.read_text()
    for path in ['/etc/raywrt-usage.csv', '/tmp/raywrt-usage.state',
                 '/etc/raywrt-device-usage.csv', '/tmp/raywrt-device-usage-today.csv',
                 '/tmp/raywrt-usage-anomaly']:
        script = script.replace(path, str(root / Path(path).name))
    helper = root / 'helper'
    helper.write_text(script)
    env = dict(os.environ, PATH=str(bindir) + ':' + os.environ['PATH'])

    def total(action='status'):
        output = subprocess.check_output(['sh', str(helper), action], env=env, text=True)
        if action == 'summary':
            assert len(output.splitlines()) == 1, 'Summary must not return history or diagnostics'
        return int(next(line.split('=', 1)[1] for line in output.splitlines()
                        if line.startswith('total_recorded=')))

    assert total() == total('summary') == 0, 'No files on first boot must still return zero successfully'
    (root / 'raywrt-usage.state').write_text('download=1234\nupload=456\n')
    assert total() == total('summary') == 1690, 'Live traffic must count before the first history save'
    (root / 'raywrt-usage.csv').write_text(f'2020-01-01,100,200\n{date.today()},10,20\n')
    assert total() == total('summary') == 1990, 'Saved current day must not double count live traffic'
print('PASS: first-boot and restored-history usage totals')
