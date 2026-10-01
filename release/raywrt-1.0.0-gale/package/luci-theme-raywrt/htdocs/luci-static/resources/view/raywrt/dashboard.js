'use strict';
'require view';
'require rpc';
'require network';
'require uci';
'require fs';

const board = rpc.declare({object:'system',method:'board'});
const info = rpc.declare({object:'system',method:'info'});
const deviceStatus = rpc.declare({object:'network.device',method:'status',params:['name']});
const interfaceStatus = rpc.declare({object:'network.interface',method:'status',params:['interface']});
const interfaces = rpc.declare({object:'network.interface',method:'dump',expect:{interface:[]}});
const leases = rpc.declare({object:'luci-rpc',method:'getDHCPLeases'});
const hostHints = rpc.declare({object:'luci-rpc',method:'getHostHints',expect:{'':{}}});
const date = rpc.declare({object:'luci',method:'getUnixtime',expect:{result:0}});
const wirelessStatus = rpc.declare({object:'network.wireless',method:'status'});

function safe(p, fallback) { return L.resolveDefault(p, fallback); }
function item(label, value) { return E('div',{class:'rw-info-row'},[E('span',{},label),E('strong',{},value == null ? 'Unavailable' : value)]); }
function card(title, content, extra) { return E('section',{class:'rw-card '+(extra||'')},[E('h2',{},title),content]); }
function pct(n) { return Number.isFinite(n) ? Math.max(0,Math.min(100,n)).toFixed(n<10?1:0)+'%' : '—'; }
function size(n) { return n == null ? 'Unavailable' : String.format('%1024.1mB', n); }
function trafficSize(n) {
 if (!Number.isFinite(+n)) return 'Unavailable';
 const units=['B','KB','MB','GB','TB']; let value=Math.max(0,+n),unit=0;
 while(value>=1000&&unit<units.length-1){value/=1000;unit++;}
 return value.toFixed(1)+' '+units[unit];
}
function rate(n) { if (!Number.isFinite(n)) return '—'; return n >= 1000000 ? (n/1000000).toFixed(1)+' Mbps' : (n/1000).toFixed(1)+' Kbps'; }
function macKey(value) { return String(value||'').replace(/[^0-9a-f]/gi,'').toUpperCase(); }
function svgNode(tag,attrs,children){
 const node=document.createElementNS('http://www.w3.org/2000/svg',tag);
 for(const [name,value] of Object.entries(attrs||{}))node.setAttribute(name,String(value));
 for(const child of (Array.isArray(children)?children:children?[children]:[]))node.appendChild(child);
 return node;
}
function graph(a,b) {
 const svg = svgNode('svg',{viewBox:'0 0 400 90',preserveAspectRatio:'none',class:'rw-graph','aria-label':'Recent download and upload speed'});
 [18,40,62,84].forEach(y=>svg.appendChild(svgNode('line',{x1:'0',y1:String(y),x2:'400',y2:String(y),class:'rw-graph-grid'})));
 [a,b].forEach((series,i)=>{
  svg.appendChild(svgNode('polygon',{class:i?'rw-graph-upload-area':'rw-graph-download-area',points:'',fill:i?'#ba8af3':'#57d99a','fill-opacity':'0.12'}));
  svg.appendChild(svgNode('polyline',{class:i?'rw-graph-upload':'rw-graph-download',points:'',fill:'none',stroke:i?'#ba8af3':'#57d99a','stroke-width':'2.5','stroke-linecap':'round','stroke-linejoin':'round'}));
 });
 return svg;
}
function sparkline(id,color){return svgNode('svg',{id,viewBox:'0 0 100 34',preserveAspectRatio:'none',class:'rw-spark','aria-hidden':'true'},svgNode('polyline',{points:'',fill:'none',stroke:color,'stroke-width':'2'}));}

return view.extend({
 addFooter(){},
 load() { return Promise.resolve(); },
 render() {
  this.board = {}; this.info = {}; this.now = 0; this.networks = []; this.radios = [];
  this.previous = null; this.download=[]; this.upload=[]; this.busy={};
  const hour = this.now ? new Date(this.now*1000).getHours() : new Date().getHours();
  const greeting = hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';
  this.wan = null;
  const dashboard=E('div',{class:'rw-dashboard'},[
   E('div',{class:'rw-hero'},[E('div',{},[E('h1',{},greeting),E('p',{id:'rw-health'},'Checking network status…')]),E('div',{class:'rw-hero-tools'},[E('div',{class:'rw-clock',id:'rw-clock'},''),E('button',{type:'button',class:'rw-hero-toggle',title:'Toggle decorative background','aria-label':'Toggle decorative background',click:()=>{const off=document.body.classList.toggle('rw-no-hero');localStorage.setItem('raywrt-no-hero',off?'1':'0');}},'◐')])]),
   E('div',{class:'rw-metrics'},[
    card('CPU',E('div',{},[E('strong',{id:'rw-cpu'},'—'),sparkline('rw-cpu-spark','#57d99a')]),'rw-metric rw-green'),
    card('Memory',E('div',{},[E('strong',{id:'rw-memory'},'—'),sparkline('rw-memory-spark','#78b2ff')]),'rw-metric rw-blue'),
    E('section',{class:'rw-card rw-metric rw-orange rw-temperature',hidden:''},[E('h2',{},'Temperature'),E('strong',{id:'rw-temp'},'—')]),
    E('a',{class:'rw-card rw-metric rw-green rw-traffic-card',href:L.url('admin/raywrt-tools/usage')},[E('h2',{},'Total Used'),E('strong',{id:'rw-traffic-total-recorded'},'—')]),
    card('Uptime',E('strong',{id:'rw-uptime'},'—'),'rw-metric rw-purple')]),
   E('div',{class:'rw-dashboard-grid'},[
    E('div',{class:'rw-dashboard-main'},[
     card('Internet',E('div',{},[
      E('div',{class:'rw-status',id:'rw-wan-status'},'Checking…'),
      E('div',{class:'rw-speed'},[E('div',{},[E('small',{},'↓ Download'),E('strong',{id:'rw-down'},'—')]),E('div',{},[E('small',{},'↑ Upload'),E('strong',{id:'rw-up'},'—')])]),
      E('div',{class:'rw-chart-heading'},[E('span',{},'Live traffic · last 90 seconds'),E('div',{class:'rw-chart-legend'},[E('span',{class:'rw-legend-download'},'Download'),E('span',{class:'rw-legend-upload'},'Upload')])]),
      graph([],[]), E('div',{class:'rw-internet-meta',id:'rw-wan-address'},'')
     ]),'rw-internet'),
     card('Network Overview',E('div',{class:'rw-topology'},[
      E('div',{id:'rw-topology-internet'},'◎ Internet · Checking…'),
      E('div',{},'↓'),E('div',{id:'rw-router'},'▣ Router · —'),
      E('div',{},'↓'),E('div',{id:'rw-topology-clients'},'LAN and Wi-Fi client data loading…')
     ]),'rw-topology-card'),
     card('Connected Devices',E('div',{class:'rw-table-scroll'},E('table',{class:'table rw-device-table'},[
      E('thead',{},E('tr',{},['Device','IP address','Connection','Download','Upload','Today'].map(x=>E('th',{},x)))),
      E('tbody',{id:'rw-device-list'},E('tr',{},E('td',{colspan:'6'},'Loading…')))
     ])),'rw-devices')
    ]),
    E('div',{class:'rw-dashboard-side'},[
     card('System Information',E('div',{},[
      item('Hostname',E('span',{id:'rw-hostname'},'—')),item('Model',E('span',{id:'rw-model'},'—')),item('Firmware',E('span',{id:'rw-firmware'},'—')),item('Kernel',E('span',{id:'rw-kernel'},'—')),
      item('Local time',E('span',{id:'rw-time'},'—')),item('Load average',E('span',{id:'rw-load'},'—'))
     ])),
     card('Storage',E('div',{},[E('div',{class:'rw-progress'},E('span',{id:'rw-storage-bar',style:'width:0%'})),item('Writable overlay',E('span',{id:'rw-storage'},'—'))])),
     card('Wi-Fi',E('div',{id:'rw-wifi-list'},'Loading…')),
     card('Quick Actions',E('div',{class:'rw-actions'},[
      E('a',{class:'btn',href:L.url('admin/raywrt/reboot')},'Reboot'),
      E('a',{class:'btn',href:L.url('admin/system/flash')},'Backup / Upgrade')
     ]))
    ])
   ])
  ]);
  if (localStorage.getItem('raywrt-no-hero')==='1') document.body.classList.add('rw-no-hero');
  this.onVisibility=()=>{ if (!document.hidden) this.pollDue(true); };
  document.addEventListener('visibilitychange',this.onVisibility);
  this.timer=setInterval(()=>this.pollDue(false),1000);
  window.setTimeout(()=>{this.drawGraph();this.bootstrap();},0);
  this.unload=()=>{ clearInterval(this.timer); document.removeEventListener('visibilitychange',this.onVisibility); };
  return dashboard;
 },
 duration(value) { const s=Number(value); if (!Number.isFinite(s)||s<0) return 'Unavailable'; if(s<3600)return Math.floor(s/60)+'m'; if(s<86400)return Math.floor(s/3600)+'h '+Math.floor(s%3600/60)+'m'; return Math.floor(s/86400)+'d '+Math.floor(s%86400/3600)+'h'; },
 async bootstrap() {
  const [b,sys,_,__,nets,radios,dump,wirelessRuntime,wifiNetworks]=await Promise.all([
   safe(board(),{}),safe(info(),{}),safe(uci.load('network'),null),safe(uci.load('wireless'),null),
   safe(network.getNetworks(),[]),safe(network.getWifiDevices(),[]),safe(interfaces(),[]),safe(wirelessStatus(),{}),safe(network.getWifiNetworks(),[])
  ]);
  if (!document.getElementById('rw-hostname')) return;
  this.board=b; this.networks=nets; this.radios=radios;
  this.wifiNetworks=wifiNetworks;
  const candidates=Array.isArray(dump)?dump:(dump.interface||[]);
  const routed=candidates.filter(x=>x.up && x.route?.some(r=>r.mask===0 && (r.target==='0.0.0.0'||r.target==='::')))
   .sort((a,b)=>(a.metric||0)-(b.metric||0));
  const name=routed[0]?.interface||nets.find(n=>n.getName()==='wan')?.getName()||nets.find(n=>n.getName().startsWith('wan'))?.getName();
  this.wanName=name;
  const lan=nets.find(n=>n.getName()==='lan');
  this.lanDevice=candidates.find(x=>x.interface==='lan')?.l3_device;
  document.getElementById('rw-hostname').textContent=b.hostname||'Unavailable';
  document.getElementById('rw-model').textContent=b.model||'Unavailable';
  document.getElementById('rw-firmware').textContent=b.release?.description||'Unavailable';
  document.getElementById('rw-kernel').textContent=b.kernel||'Unavailable';
  document.getElementById('rw-router').textContent='▣ '+(b.hostname||'Router')+' · '+(lan?.getIPAddr()||'Address unavailable');
  const wifi=radios.flatMap(r=>uci.sections('wireless','wifi-iface').filter(s=>s.device===r.getName()&&s.mode==='ap').map(s=>({radio:r,ssid:s})));
  const list=document.getElementById('rw-wifi-list');list.replaceChildren();
  await Promise.all(wifi.map(async x=>{
   const name=x.radio.getName(),device=x.ssid.device||name,band=uci.get('wireless',device,'band'),configured=uci.get('wireless',device,'disabled')!=='1'&&x.ssid.disabled!=='1';
   const runtime=wirelessRuntime?.[name]||wirelessRuntime?.[device]||Object.values(wirelessRuntime||{}).find(r=>r?.config?.path&&r.config.path===x.radio.getPath?.());
   const running=runtime?.up===true||runtime?.up===1||runtime?.up==='true';
   const status=!configured?'Disabled':running?'Enabled':runtime?.pending?'Starting':runtime?'Unavailable':'Enabled';
   const bandLabel=band==='5g'?'5 GHz':band==='2g'?'2.4 GHz':band||'Wi-Fi';
   list.appendChild(E('div',{class:'rw-wifi-row'},[
    E('span',{'data-band':bandLabel,'data-wifi-device':name},[E('strong',{},x.ssid.ssid||'Hidden SSID'),E('small',{},bandLabel+' · updating clients…')]),
    E('a',{class:'btn',href:L.url('admin/network/wireless')},status)
   ]));
  }));
  if(!wifi.length)list.textContent='No access points configured';
  this.updateSystem(sys);
  this.detectTemperature();
  this.pollDue(true);
 },
 updateSystem(sys) {
  if(!document.getElementById('rw-memory'))return;
  const m=sys.memory||{},root=sys.root||{};
  document.getElementById('rw-memory').textContent=pct(m.total?(m.total-(m.available??m.free))/m.total*100:NaN);
  if(m.total)this.drawSpark('memory',100*(m.total-(m.available??m.free))/m.total);
  document.getElementById('rw-uptime').textContent=this.duration(sys.uptime);
  document.getElementById('rw-load').textContent=Array.isArray(sys.load)?sys.load.map(x=>(x/65535).toFixed(2)).join('  '):'Unavailable';
  if(sys.localtime){const d=new Date(sys.localtime*1000);document.getElementById('rw-time').textContent=d.toLocaleString();document.getElementById('rw-clock').textContent=d.toLocaleTimeString([],{hour:'2-digit',minute:'2-digit'});}
  if(root.total){document.getElementById('rw-storage').textContent=size(root.used*1024)+' used / '+size(root.total*1024)+' total · '+pct(root.used/root.total*100);document.getElementById('rw-storage-bar').style.width=pct(root.used/root.total*100);}
 },
 async detectTemperature() {
  const entries=await safe(fs.list('/sys/class/thermal'),[]);
  const zones=entries.filter(x=>/^thermal_zone\d+$/.test(x.name)).slice(0,16);
  const readings=await Promise.all(zones.map(async z=>({
   type:(await safe(fs.read('/sys/class/thermal/'+z.name+'/type'),'' )).trim(),
   value:Number((await safe(fs.read('/sys/class/thermal/'+z.name+'/temp'),'' )).trim())
  })));
  const valid=x=>/cpu|soc|processor|tsens|ipq4019/i.test(x.type)&&Number.isInteger(x.value)&&x.value>=5000&&x.value<=125000;
  const choice=readings.find(valid);
  if(choice){document.getElementById('rw-temp').textContent=(choice.value/1000).toFixed(1)+'°C';document.querySelector('.rw-temperature')?.removeAttribute('hidden');}
  else document.querySelector('.rw-temperature')?.remove();
 },
 pollDue(force) {
  if(document.hidden||!document.getElementById('rw-down'))return;
  const now=Date.now();this.due??={};
  for(const [key,interval,fn] of [['fast',1000,'fastPoll'],['system',4000,'systemPoll'],['wan',5000,'wanPoll'],['leases',12000,'leasesPoll'],['usage',30000,'usagePoll']]){
   if(!this.busy[key]&&(force||now>=(this.due[key]||0))){this.due[key]=now+interval;this.busy[key]=true;this[fn]().finally(()=>{this.busy[key]=false;});}
  }
 },
 async fastPoll() {
  const [cpuData,counters]=await Promise.all([safe(fs.read('/proc/stat'),''),this.wanDevice?safe(deviceStatus(this.wanDevice),{}):Promise.resolve({})]);
  const line=cpuData.split('\n')[0]?.trim().split(/\s+/);
  if(line?.[0]==='cpu'){
   const vals=line.slice(1).map(Number),total=vals.reduce((a,b)=>a+b,0),idle=vals[3]+(vals[4]||0);
   if(this.cpuPrevious&&total>this.cpuPrevious.total){const busy=100*(1-(idle-this.cpuPrevious.idle)/(total-this.cpuPrevious.total));if(Number.isFinite(busy)){document.getElementById('rw-cpu').textContent=pct(busy);this.drawSpark('cpu',busy);}}
   this.cpuPrevious={total,idle};
  }
  const rx=Number(counters.statistics?.rx_bytes),tx=Number(counters.statistics?.tx_bytes),now=Date.now();
  if(this.wanDevice&&Number.isFinite(rx)&&Number.isFinite(tx)){
   if(this.previous?.dev===this.wanDevice&&rx>=this.previous.rx&&tx>=this.previous.tx){
    const dt=(now-this.previous.time)/1000,down=(rx-this.previous.rx)*8/dt,up=(tx-this.previous.tx)*8/dt;
    if(dt>0&&down<1e10&&up<1e10){this.download.push(down);this.upload.push(up);this.download=this.download.slice(-90);this.upload=this.upload.slice(-90);document.getElementById('rw-down').textContent=rate(down);document.getElementById('rw-up').textContent=rate(up);this.drawGraph();}
   } else {this.download=[];this.upload=[];document.getElementById('rw-down').textContent='—';document.getElementById('rw-up').textContent='—';this.drawGraph();}
   this.previous={dev:this.wanDevice,rx,tx,time:now};
  }
 },
 drawGraph(){
  const svg=document.querySelector('.rw-graph');if(!svg)return;
  const max=Math.max(1,...this.download,...this.upload);
  [['download',this.download],['upload',this.upload]].forEach(([kind,arr])=>{
   let points=arr.map((v,j)=>`${arr.length===1?0:j*400/(arr.length-1)},${84-Math.max(0,v)*68/max}`);
   if(arr.length===1)points.push(`400,${84-Math.max(0,arr[0])*68/max}`);
   const line=svg.querySelector('.rw-graph-'+kind),area=svg.querySelector('.rw-graph-'+kind+'-area');
   if(line)line.setAttribute('points',points.join(' '));
   if(area)area.setAttribute('points',points.length?`0,90 ${points.join(' ')} 400,90`:'' );
  });
 },
 drawSpark(kind,value){this.spark??={cpu:[],memory:[]};const arr=this.spark[kind];arr.push(Math.max(0,Math.min(100,value)));if(arr.length>30)arr.shift();const svg=document.getElementById('rw-'+kind+'-spark');if(svg)svg.firstElementChild.setAttribute('points',arr.map((v,i)=>(i*100/29)+','+(32-v*.3)).join(' '));},
 async systemPoll(){this.updateSystem(await safe(info(),{}));},
 async usagePoll(){const result=await safe(fs.exec('/usr/libexec/raywrt-usage-control',['summary']),{});if(!document.getElementById('rw-traffic-total-recorded'))return;const values={};String(result.stdout||'').split('\n').forEach(line=>{const at=line.indexOf('=');if(at>0)values[line.slice(0,at)]=line.slice(at+1).trim();});const total=+values.total_recorded;if(Number.isFinite(total))document.getElementById('rw-traffic-total-recorded').textContent=trafficSize(total);},
 async wanPoll(){
  if(!this.wanName)return;
  const status=await safe(interfaceStatus(this.wanName),{}),up=!!status.up,device=status.l3_device||status.device;
  if(device!==this.wanDevice){this.wanDevice=device;this.previous=null;}
  document.getElementById('rw-health').textContent=up?'WAN interface is connected.':'WAN is disconnected or unavailable.';
  document.getElementById('rw-wan-status').textContent=this.wanName+' · '+(up?'Connected':'Disconnected');
  document.getElementById('rw-topology-internet').textContent='◎ Internet · '+(up?'Online':'Offline');
  const ipv4=status['ipv4-address']?.map(x=>x.address).join(', '),ipv6=status['ipv6-address']?.map(x=>x.address).join(', ');
  document.getElementById('rw-wan-address').textContent=[ipv4&&'IPv4 '+ipv4,ipv6&&'IPv6 '+ipv6].filter(Boolean).join(' · ')||'No WAN address';
 },
 async leasesPoll(){
  const [data,hints,neigh4,neigh6,stations,usage]=await Promise.all([
   safe(leases(),{}),safe(hostHints(),{}),safe(fs.exec('/sbin/ip',['-f','inet','neigh','show']),{}),safe(fs.exec('/sbin/ip',['-f','inet6','neigh','show']),{}),
   Promise.all((this.wifiNetworks||[]).map(async net=>({net,peers:await safe(net.getAssocList(),[])}))),
   safe(fs.exec('/usr/libexec/raywrt-device-usage-control',['live']),{})
  ]);
  const v4=Array.isArray(data)?data:(data.dhcp_leases||[]),v6=data.dhcp6_leases||[];
  const rows=new Map();
  const hintsByMac=new Map(Object.entries(hints).map(([mac,hint])=>[macKey(mac),hint]));
  v4.forEach(x=>{if(x.macaddr)rows.set(macKey(x.macaddr),{mac:x.macaddr,ip:x.ipaddr,name:x.hostname});});
  v6.forEach(x=>{const ip=x.ip6addr||x.ip6addrs?.[0];if(x.macaddr){const key=macKey(x.macaddr),old=rows.get(key)||{};rows.set(key,{mac:x.macaddr,ip:old.ip||ip,name:old.name||x.hostname});}});
  for(const line of ((neigh4.stdout||'')+'\n'+(neigh6.stdout||'')).split('\n')){
   const match=line.match(/^(\S+) dev (\S+) lladdr ([0-9a-f:]{17}).*\b(REACHABLE|DELAY|PROBE|STALE)\b/i);
   if(!match||match[2]!==this.lanDevice)continue;
   const key=macKey(match[3]),row=rows.get(key)||{mac:match[3]};
   row.ip ||=match[1];row.neighborActive=match[4]!=='STALE';rows.set(key,row);
  }
  const wifiClientCounts={};
  stations.forEach(({net,peers})=>{
   const peersList=Array.isArray(peers)?peers:Array.isArray(peers?.results)?peers.results:Object.values(peers||{});
   const wifiDevice=net.getWifiDeviceName();
   wifiClientCounts[wifiDevice]=(wifiClientCounts[wifiDevice]||0)+peersList.length;
   peersList.forEach(peer=>{
   const address=typeof peer==='string'?peer:peer?.mac||peer?.addr||peer?.address||peer?.macaddr;
   const key=macKey(address);if(!key)return;const row=rows.get(key)||{mac:address};
   row.wifi=true;
   rows.set(key,row);
   });
  });
  this.wifiClientCounts=wifiClientCounts;
  document.querySelectorAll('[data-wifi-device]').forEach(row=>{
   const count=this.wifiClientCounts?.[row.dataset.wifiDevice]||0,band=row.dataset.band||'Wi-Fi';
   const small=row.querySelector('small');if(small)small.textContent=band+' · '+count+' connected';
  });
  rows.forEach((row,key)=>{
   const hint=hintsByMac.get(key);
   if(hint){row.name ||= hint.name?.replace(/\.lan$/i,'');row.ip ||= hint.ipaddrs?.[0]||hint.ip6addrs?.[0];}
  });
  const today=new Map();
  const deviceToday=String(usage.stdout||'').split('--TODAY--')[1]?.split('--HISTORY--')[0]||'';
  deviceToday.trim().split('\n').forEach(line=>{const [mac,down,up]=line.split(',');if(mac)today.set(macKey(mac),{down:+down||0,up:+up||0});});
  const body=document.getElementById('rw-device-list');body.replaceChildren();
  [...rows.values()].slice(0,30).forEach(x=>{const deviceMac=String(x.mac||'').toUpperCase(),key=macKey(deviceMac),bytes=today.get(key)||{down:0,up:0};body.appendChild(E('tr',{},[
   E('td',{},E('a',{href:L.url('admin/raywrt-tools/usage')+'?device='+encodeURIComponent(deviceMac)},x.name||'Unknown Device · '+deviceMac)),
   E('td',{},x.ip||'—'),E('td',{},x.wifi?'Wi-Fi':x.neighborActive?'LAN':'Unknown'),
   E('td',{},trafficSize(bytes.down)),E('td',{},trafficSize(bytes.up)),E('td',{},trafficSize(bytes.down+bytes.up))]));});
  if(!rows.size)body.appendChild(E('tr',{},E('td',{colspan:'6'},'No known devices')));
  document.getElementById('rw-topology-clients').textContent=rows.size+' known device'+(rows.size===1?'':'s');
 }
});
