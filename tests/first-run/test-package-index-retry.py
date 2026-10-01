#!/usr/bin/env python3
"""Exercise the real fixed installer with stale, failing and missing indexes."""
import os, subprocess, tempfile
from pathlib import Path
base=Path(__file__).resolve().parents[2]
source=base/'root/usr/libexec/raywrt-tools'
if not source.exists(): source=base/'package/luci-theme-raywrt/root/usr/libexec/raywrt-tools'
for scenario in ['stale','update_fail','missing']:
 with tempfile.TemporaryDirectory() as directory:
  root=Path(directory); bin=root/'bin'; bin.mkdir()
  apk=bin/'apk'
  apk.write_text("""#!/bin/sh
case "$1" in
 info) exit 1 ;;
 search) [ "$SCENARIO" = stale ] && [ -f "$TEST_ROOT/refreshed" ] && echo ttyd-1.7.7-r1; exit 0 ;;
 update) echo update >>"$TEST_ROOT/calls"; touch "$TEST_ROOT/refreshed"; [ "$SCENARIO" != update_fail ] ;;
 add) echo add >>"$TEST_ROOT/calls"; exit 0 ;;
esac
"""); apk.chmod(0o755)
  df=bin/'df';df.write_text('#!/bin/sh\necho header\necho "overlay 100000 0 100000"\n');df.chmod(0o755)
  helper=root/'helper';helper.write_text(source.read_text().replace('jobdir=/tmp/raywrt-tools','jobdir='+str(root/'job')).replace('invalidate_luci_menu_cache\n',' :\n'))
  env=dict(os.environ, PATH=str(bin)+':'+os.environ['PATH'],TEST_ROOT=str(root),SCENARIO=scenario)
  result=subprocess.run(['sh',str(helper),'worker','terminal','install'],env=env)
  calls=(root/'calls').read_text().splitlines()
  assert calls.count('update')==1, calls
  assert ('add' in calls)==(scenario=='stale'),calls
  assert (root/'job/state').read_text().strip()==('success' if scenario=='stale' else 'failed')
print('PASS: one index refresh; successful retry; failed refresh and missing package never install')
