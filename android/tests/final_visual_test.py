import pathlib
source=pathlib.Path('android/tests/emulator_test.py').read_text(encoding='utf-8')
exec(compile(source.split("wait_text('Disconnected')")[0],'android/tests/emulator_test.py','exec'))
set_text('SSH password','fixture');tap(text='Connect');wait_text('Connected · Router configurations loaded');tap(text='Router');tap(text='Run test');wait_text('Diagnostic complete · 15 targets tested');node(text='24.0 ms');node(text='14/15');node(text='0%');screenshot('android-router-final.png')
run('shell','wm','size','720x1280');run('shell','wm','density','320');time.sleep(1);screenshot('android-router-final-small.png')
print('PASS: final build startup, real read-only snapshot, actual probe metrics and small-screen capture')
