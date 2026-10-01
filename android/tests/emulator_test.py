import sys, pathlib, subprocess, xml.etree.ElementTree as ET, re, time
sys.stdout.reconfigure(encoding='utf-8')
root=pathlib.Path(__file__).resolve().parents[2]
adb=str(root/'.android-tools/sdk/platform-tools/adb.exe')
serial='emulator-5556'
build=root/'android/.build'
def run(*args):
 result=subprocess.run([adb,'-s',serial,*args],capture_output=True,text=True,encoding='utf-8')
 if result.returncode:raise RuntimeError(result.stderr or result.stdout)
 return result.stdout

def dump():
 run('shell','uiautomator','dump','/sdcard/raywrt-test.xml')
 run('pull','/sdcard/raywrt-test.xml',str(build/'ui-test.xml'))
 return list(ET.parse(build/'ui-test.xml').iter('node'))

def node(desc=None,text=None):
 for n in dump():
  if (desc is not None and n.get('content-desc')==desc) or (text is not None and n.get('text','').casefold()==text.casefold()):return n
 raise AssertionError('UI element missing: '+str(desc or text))

def tap(desc=None,text=None):
 n=node(desc,text);x1,y1,x2,y2=map(int,re.findall(r'\d+',n.get('bounds')));run('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2))

def set_text(desc,value):
 n=node(desc=desc);old=n.get('text','');x1,y1,x2,y2=map(int,re.findall(r'\d+',n.get('bounds')))
 run('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2))
 run('shell','input','keyevent','KEYCODE_MOVE_END')
 if old:run('shell','input','keyevent',*(['KEYCODE_DEL']*(len(old)+2)))
 run('shell','input','text',value)
 run('shell','input','keyevent','KEYCODE_BACK')

def wait_text(value,timeout=20):
 deadline=time.monotonic()+timeout
 while time.monotonic()<deadline:
  if any(n.get('text')==value for n in dump()):return
  time.sleep(.2)
 raise AssertionError('Missing UI state: '+value)

def screenshot(name):
 run('shell','screencap','-p','/sdcard/raywrt-shot.png');run('pull','/sdcard/raywrt-shot.png',str(build/name))

wait_text('Disconnected')
assert not any('preview' in n.get('text','').lower() for n in dump())
node(desc='Open Heygoodbye on GitHub')
set_text('Router IP or hostname','10.0.2.2')
set_text('SSH password','fixture')
tap(text='Connect')
wait_text('Trust this router?')
tap(text='Trust')
wait_text('Connected · Router configurations loaded')
node(text='IR Server 1');node(text='Germany Node');node(text='Turkey Node')
screenshot('android-connected.png')
tap(desc='Set Active Turkey Node')
wait_text('Updated · SSH connected')
node(desc='✓  Active Turkey Node')
tap(text='WireGuard')
node(text='wg_home');node(text='wg_gaming')
tap(desc='Connect wg_gaming')
wait_text('Updated · SSH connected')
node(desc='Disconnect wg_gaming')
screenshot('android-wireguard.png')
tap(text='Disconnect')
wait_text('Disconnected')
print('PASS: Android launch, credit, SSH trust/login, node switching, tabs, WireGuard connect, and disconnect')

