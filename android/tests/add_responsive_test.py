import pathlib
src=pathlib.Path('android/tests/add_emulator_test.py').read_text(encoding='utf-8-sig')
exec(src.split("print('PASS:")[0])
time.sleep(1)
tap(desc='Add node or subscription');node(text='Add to Passwall 2')
for desc in ['Cancel adding node','Import node or subscription']:
 n=node(desc=desc);x1,y1,x2,y2=map(int,re.findall(r'\d+',n.get('bounds')));assert x2<=720 and y2<=1280 and x2>x1 and y2-y1>=96,(desc,n.attrib)
screenshot('android-add-small.png')
edits=[n for n in dump() if n.get('class')=='android.widget.EditText']
n=edits[0];x1,y1,x2,y2=map(int,re.findall(r'\d+',n.get('bounds')));run('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2));time.sleep(1)
screenshot('android-add-keyboard.png');tap(desc='Cancel adding node')
assert not any(n.get('text')=='Add to Passwall 2' for n in dump())
run('shell','wm','size','reset');run('shell','wm','density','reset')
print('PASS: small-screen buttons, keyboard interaction and Cancel dismissal')

