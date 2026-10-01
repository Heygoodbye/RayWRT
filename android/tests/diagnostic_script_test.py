"""Execute the bundled shell diagnostic with a fake ping, never public hosts."""
import pathlib, subprocess, json
root=pathlib.Path(__file__).resolve().parents[2]
fake=root/'android/.build/fakebin';fake.mkdir(exist_ok=True)
(fake/'ping').write_text('''#!/bin/sh
for host do :; done
case "$host" in
  92.223.20.1) echo '4 packets transmitted, 0 packets received, 100% packet loss'; exit 1;;
  ping-fr.ds.on.epicgames.com) echo 'ping: bad address'; exit 1;;
  185.60.112.157) echo '4 packets transmitted, 3 packets received, 25% packet loss'; echo 'round-trip min/avg/max = 20.0/30.0/40.0 ms';;
  *) echo '4 packets transmitted, 4 received, 0% packet loss'; echo 'rtt min/avg/max/mdev = 10.0/20.0/30.0/1.0 ms';;
esac
''',encoding='utf-8',newline='\n')
result=subprocess.run(['C:/Program Files/Git/bin/bash.exe','-c','PATH="$PWD/android/.build/fakebin:$PATH" sh companion/diagnostics.sh run'],cwd=root,capture_output=True,text=True)
assert result.returncode==0,result.stderr
rows={p[0]:p for line in result.stdout.splitlines() if (p:=line.split('|'))}
assert len(rows)==15
assert all(len(p)==9 for p in rows.values())
assert rows['wot1'][7:]==['4','0']
assert rows['fortnite_fr'][6:] == ['dns_error','NA','NA']
assert rows['wow1'][7:]==['4','3']
assert rows['wow1'][3]=='30.0'
assert rows['wow2'][7:]==['4','4']
(root/'android/.build/diagnostic-script-output.txt').write_text(result.stdout,encoding='utf-8')
print('PASS: real shell diagnostic parses received counts, packet loss, DNS failure and missing replies without network access')
