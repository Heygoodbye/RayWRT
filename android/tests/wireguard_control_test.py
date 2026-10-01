"""Exercise the shared app routing script against an isolated router-command fixture."""
import os, pathlib, subprocess, tempfile

root = pathlib.Path(__file__).resolve().parents[2]
bash = pathlib.Path('C:/Program Files/Git/bin/bash.exe')
script = (root/'companion/wireguard-control.sh').read_text(encoding='utf-8-sig')
assert script == (root/'android/app/src/main/assets/wireguard-control.sh').read_text(encoding='utf-8-sig')
stub = r'''#!/bin/sh
name=${0##*/}
printf '%s %s\n' "$name" "$*" >> "$FIXTURE/log"
case "$name" in
 uci)
  [ "$1" != -q ] || shift
  case "$1" in
   changes) [ "${PENDING:-0}" != 1 ] || echo pending;;
   get) case "$2" in
    raywrt.wireguard_split.interface) cat "$FIXTURE/selected";;
    raywrt.wireguard_split.wan_interface) echo wan_custom;;
    network.wan_custom.proto) echo dhcp;;
    network.*.proto) echo wireguard;;
    *) exit 1;; esac;;
   set|commit) :;;
   *) exit 1;; esac;;
 helper)
  case "$1" in
   progress)
    if [ ! -f "$FIXTURE/job" ]; then echo state=idle; echo job_id=none
    elif [ ! -f "$FIXTURE/polled" ]; then touch "$FIXTURE/polled"; echo state=running; echo job_id=test-job
    else echo "state=${JOB_RESULT:-success}"; echo job_id=test-job; echo --LOG--; echo 'fixture router result'; fi;;
   configure) printf '%s' "$2" > "$FIXTURE/selected";;
   enable) touch "$FIXTURE/job"; echo started; echo job_id=test-job;;
   disable) :;;
   status) echo state=active; printf 'interface=%s\n' "$(cat "$FIXTURE/selected")";;
   *) exit 1;; esac;;
 ubus) [ "$2" = network ] || echo '{"up":true}';;
 jsonfilter) cat >/dev/null; echo true;;
 ifup|ifdown|sleep|firewall) :;;
 *) exit 1;;
esac
'''

def run(action, interface, selected='wg_old', pending=False, failure=False):
    with tempfile.TemporaryDirectory(prefix='raywrt-routing-') as directory:
        p = pathlib.Path(directory)
        for name in ['uci','helper','ubus','jsonfilter','ifup','ifdown','sleep','firewall']:
            (p/name).write_text(stub, encoding='utf-8', newline='\n')
        (p/'selected').write_text(selected, encoding='utf-8')
        unix = '/'+p.drive[0].lower()+p.as_posix()[2:]
        local = script.replace('helper=/usr/libexec/raywrt-wireguard-split', "helper='"+unix+"/helper'")
        local = local.replace('/tmp/raywrt-wg-control.lock', unix+'/control.lock')
        local = local.replace('/etc/init.d/firewall', unix+'/firewall')
        env = os.environ.copy()
        env.update(FIXTURE=unix, PENDING='1' if pending else '0', JOB_RESULT='failed' if failure else 'success')
        result = subprocess.run([str(bash), '-c', 'chmod +x "$FIXTURE"/*; export PATH="$FIXTURE:$PATH"; sh -c "$1" fixture "$2" "$3"', '--', local, action, interface], env=env, capture_output=True, text=True)
        log=(p/'log').read_text() if (p/'log').exists() else ''
        return result, log

r, log=run('connect','wg_new')
assert r.returncode==0, r.stderr
assert 'helper configure wg_new wan_custom' in log and 'helper enable' in log
assert log.index('helper disable') < log.index('ifdown wg_old') < log.index('ifup wg_new') < log.index('helper configure') < log.index('helper enable')
assert 'uci set network.wg_old.disabled=1' in log and 'uci set network.wg_new.disabled=0' in log
assert 'firewall reload' in log
assert log.count('helper progress')>=3 and 'helper status' in log
r, log=run('connect','wg_old')
assert r.returncode==0 and 'helper configure wg_old wan_custom' in log and 'helper enable' in log
r, log=run('disconnect','wg_old')
assert r.returncode==0 and 'helper disable' in log and 'ifdown wg_old' in log and 'helper enable' not in log
r, log=run('disconnect','wg_other')
assert r.returncode==0 and 'helper disable' not in log and 'ifdown wg_other' in log
r, log=run('connect','wg_new',pending=True)
assert r.returncode!=0 and 'uci set' not in log and 'helper disable' not in log
r, log=run('connect','wg_new',failure=True)
assert r.returncode!=0 and 'fixture router result' in r.stderr and 'routing failed' in r.stderr
print('PASS: routing selection, enable, switch, reconnect, disconnect, pending changes and worker failure')
