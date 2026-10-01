import pathlib
src=pathlib.Path('android/tests/emulator_test.py').read_text(encoding='utf-8-sig')
exec(src.split("wait_text('Disconnected')")[0])
wait_text('Disconnected')
set_text('Router IP or hostname','10.0.2.2');set_text('SSH password','fixture');tap(text='Connect')
time.sleep(1)
if any(n.get('text')=='Trust this router?' for n in dump()):tap(text='Trust')
wait_text('Connected · Router configurations loaded')
node(desc='Add node or subscription');tap(desc='Add node or subscription');node(text='Add to Passwall 2');node(text='Node link');node(text='Name (optional)')
tap(desc='Import node or subscription');node(text='Enter a supported node share link.')
screenshot('android-add-dialog.png');tap(text='Cancel');screenshot('android-add-header.png')
print('PASS: Android connection, compact Add control, dialog, invalid-link error')

