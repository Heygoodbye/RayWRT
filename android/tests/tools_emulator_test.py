import pathlib
source=pathlib.Path(__file__).with_name('emulator_test.py').read_text(encoding='utf-8')
exec(compile(source.split("wait_text('Disconnected')")[0],str(pathlib.Path(__file__).with_name('emulator_test.py')),'exec'))

wait_text('Disconnected')
set_text('Router IP or hostname','10.0.2.2')
set_text('SSH password','fixture')
tap(text='Connect');wait_text('Trust this router?');tap(text='Trust')
wait_text('Connected · Router configurations loaded')
tap(text='Router');tap(text='Run test')
wait_text('Diagnostic complete · 15 targets tested')
node(text='24.0 ms');node(text='14/15');node(text='0%');node(text='0/56 probes lost')
screenshot('android-router-tools.png')

def scroll_to(desc=None,text=None):
 for _ in range(6):
  nodes=dump(); viewport=next(n for n in nodes if n.get('class')=='android.widget.ScrollView');vx,vy,vr,vb=map(int,re.findall(r'\d+',viewport.get('bounds')))
  for n in nodes:
   if (desc and n.get('content-desc')==desc) or (text and n.get('text')==text):
    x1,y1,x2,y2=map(int,re.findall(r'\d+',n.get('bounds')))
    if y2>y1 and y1>=vy and y2<=vb:return n
  run('shell','input','swipe',str((vx+vr)//2),str(vy+(vb-vy)*8//10),str((vx+vr)//2),str(vy+(vb-vy)*3//10),'300')
 raise AssertionError('Cannot scroll to '+str(desc or text))

scroll_to(desc='Select 5 GHz');tap(desc='Select 5 GHz')
scroll_to(desc='Wi-Fi password');tap(text='Show');assert node(desc='Wi-Fi password').get('text')=='initial-key';tap(text='Hide')
screenshot('android-wifi-read-state.png')
for _ in range(3):run('shell','input','swipe','540','650','540','1450','300')
scroll_to(desc='Enable 2.4 GHz');before=node(desc='Enable 2.4 GHz').get('text');assert before=='Enable'
tap(desc='Enable 2.4 GHz');tap(text='Cancel')
assert node(desc='Enable 2.4 GHz').get('text')==before
tap(desc='Enable 2.4 GHz');tap(text='Apply')
wait_text('Wi-Fi state refreshed. Reconnect if needed.')
node(desc='Disable 2.4 GHz')
scroll_to(desc='Wi-Fi SSID');set_text('Wi-Fi SSID','AndroidPrototype')
scroll_to(desc='Wi-Fi password');set_text('Wi-Fi password','android-key-123')
scroll_to(text='Save changes');tap(text='Save changes');wait_text('Save Wi-Fi changes?');tap(text='Save')
wait_text('Wi-Fi settings saved. Reconnect using the new settings if needed.')
scroll_to(desc='Wi-Fi SSID');assert node(desc='Wi-Fi SSID').get('text')=='AndroidPrototype'
screenshot('android-router-wireless.png')
scroll_to(text='Reboot router');tap(text='Reboot router');wait_text('Reboot router?');tap(text='Cancel')
run('shell','input','swipe','540','650','540','1450','300')
run('shell','input','swipe','540','650','540','1450','300')
node(text='Connected')
scroll_to(text='Reboot router')
tap(text='Reboot router');wait_text('Reboot router?');tap(text='Reboot')
wait_text('Reboot requested. Reconnect after the router starts.')
run('shell','input','swipe','540','650','540','1450','300')
run('shell','input','swipe','540','650','540','1450','300')
node(text='Disconnected')
print('PASS: Android Router tab, 15-target ping, cancel/apply radio switch, SSID/password save, cancel/confirm reboot')
