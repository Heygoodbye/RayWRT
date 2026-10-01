"""Isolated OpenWrt SSH fixture. Binds only to this computer's loopback interface."""
import sys, pathlib, socket, threading, re, json, time
root=pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0,str(root/'.android-tools/python-libs'))
import paramiko
fixture=root/'android/.build/fixture-key'
if fixture.exists(): key=paramiko.RSAKey.from_private_key_file(str(fixture))
else:
 key=paramiko.RSAKey.generate(2048);key.write_private_key_file(str(fixture))
state={'enabled':'1','active':'node_ir','home':True,'gaming':False,'radio0':'0','radio1':'0','iface0':'1','iface1':'0','ssid0':'RayWRT 2G','ssid1':'RayWRT Home','key0':'initial-key','key1':'initial-key','reboots':0}
lock=threading.Lock()
log=root/'android/.build/fixture-commands.log'

def handle(command):
 with lock:
  with log.open('a',encoding='utf-8') as stream:stream.write(command+'\n')
  if command in ('uci -q show passwall2; uci -q show network; true','uci -q show passwall2; uci -q show network; uci -q show wireless; true'):
   return f"""passwall2.@global[0]=global
passwall2.@global[0].enabled='{state['enabled']}'
passwall2.@global[0].node='{state['active']}'
passwall2.node_ir=nodes
passwall2.node_ir.remarks='IR Server 1'
passwall2.node_ir.address='tehran.example'
passwall2.node_de=nodes
passwall2.node_de.remarks='Germany Node'
passwall2.node_de.address='Frankfurt, DE'
passwall2.node_tr=nodes
passwall2.node_tr.remarks='Turkey Node'
passwall2.node_tr.address='Istanbul, TR'
network.wg_home=interface
network.wg_home.proto='wireguard'
network.wg_gaming=interface
network.wg_gaming.proto='wireguard'
wireless.radio0=wifi-device
wireless.radio0.band='2g'
wireless.radio0.disabled='{state['radio0']}'
wireless.radio1=wifi-device
wireless.radio1.band='5g'
wireless.radio1.disabled='{state['radio1']}'
wireless.default_radio0=wifi-iface
wireless.default_radio0.device='radio0'
wireless.default_radio0.mode='ap'
wireless.default_radio0.disabled='{state['iface0']}'
wireless.default_radio0.key='{state['key0']}'
wireless.default_radio0.ssid='{state['ssid0']}'
wireless.default_radio0.encryption='psk2'
wireless.default_radio1=wifi-iface
wireless.default_radio1.device='radio1'
wireless.default_radio1.mode='ap'
wireless.default_radio1.disabled='{state['iface1']}'
wireless.default_radio1.key='{state['key1']}'
wireless.default_radio1.ssid='{state['ssid1']}'
wireless.default_radio1.encryption='sae-mixed'
""",0
  if command.startswith('sh -c '):
   ids='openwrt wow1 wow2 league_euw league_eune tarkov1 tarkov2 wot1 fortnite_de fortnite_fr fortnite_gb pubg1 pubg2 pubg3 pubg4'.split()
   return ''.join(f'{id}|error|NA|NA|NA|100|timeout|4|0\n' if id=='wot1' else f'{id}|ok|20|24|28|0||4|4\n' for id in ids),0
  if command.startswith('(sleep 2; reboot)'):state['reboots']+=1;return '',0
  if command.startswith('test -z '):
   import shlex
   tokens=shlex.split(command)
   for token in tokens:
    if token.startswith('wireless.') and '=' in token:
     k,v=token.split('=',1)
     m=re.match(r'wireless\.(radio[01])\.disabled',k)
     if m:state[m.group(1)]=v
     m=re.match(r'wireless\.default_radio([01])\.disabled',k)
     if m:state['iface'+m.group(1)]=v
     m=re.match(r'wireless\.default_radio([01])\.(ssid|key)',k)
     if m:state[m.group(2)+m.group(1)]=v
   return '',0
  if command=='fixture-state':return json.dumps(state),0
  if command.startswith('ubus call network.wireless status'):
   radios={}
   for i in (0,1):
    up=state['radio'+str(i)]!='1' and state['iface'+str(i)]!='1'
    radios['radio'+str(i)]={'up':up,'disabled':state['radio'+str(i)]=='1','interfaces':[{'section':'default_radio'+str(i),'ifname':'wlan'+str(i)}] if up else []}
   return json.dumps(radios),0
  if command.startswith('ubus call '):return json.dumps({'up':state['gaming'] if 'wg_gaming' in command else state['home']}),0
  if command.startswith('uci set '):
   m=re.search(r'\.node=(node_\w+)',command)
   if m:state['active']=m.group(1)
   m=re.search(r'\.enabled=(\d)',command)
   if m:state['enabled']=m.group(1)
   return '',0
  if command.startswith(('ifup ','ifdown ')):
   state['gaming' if 'wg_gaming' in command else 'home']=command.startswith('ifup ');return '',0
  if command=='exit 7':return 'Expected fixture failure',7
  if command=='printf fixture-ok':return 'fixture-ok',0
  return 'Unsupported fixture command',1

class Server(paramiko.ServerInterface):
 def check_auth_password(self,user,password):return paramiko.AUTH_SUCCESSFUL if user=='root' and password=='fixture' else paramiko.AUTH_FAILED
 def get_allowed_auths(self,user):return 'password'
 def check_channel_request(self,kind,chanid):return paramiko.OPEN_SUCCEEDED if kind=='session' else paramiko.OPEN_FAILED_ADMINISTRATIVELY_PROHIBITED
 def check_channel_exec_request(self,channel,command):
  def run():
   try:
    time.sleep(.1)
    text,code=handle(command.decode('utf-8'))
    if code:channel.send_stderr(text.encode())
    elif text:channel.send(text.encode())
    channel.send_exit_status(code);channel.shutdown_write();time.sleep(.05);channel.close()
   except Exception:pass
  threading.Thread(target=run,daemon=True).start();return True

def connection(client):
 transport=paramiko.Transport(client);transport.add_server_key(key)
 try:
  transport.start_server(server=Server())
  channels=[]
  while transport.is_active():
   channel=transport.accept(timeout=1)
   if channel is not None:channels.append(channel)
 except Exception:pass
 finally:transport.close()

sock=socket.socket();sock.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1);sock.bind(('127.0.0.1',22));sock.listen(8)
print('Loopback SSH fixture ready',flush=True)
while True:
 client,_=sock.accept();threading.Thread(target=connection,args=(client,),daemon=True).start()


