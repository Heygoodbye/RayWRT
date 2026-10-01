'use strict';
'require view';
'require fs';
'require ui';

const helper='/usr/libexec/raywrt-tools';
const registry=[
 {id:'passwall2',name:'Passwall 2',category:'VPN & Proxy',description:'Proxy and routing',route:'admin/services/passwall2',packages:['luci-app-passwall2']},
 {id:'wireguard',name:'WireGuard',category:'VPN & Proxy',description:'Secure VPN tunnels',route:'admin/raywrt-tools/wireguard',packages:['luci-proto-wireguard','wireguard-tools','kmod-wireguard']},
 {id:'xray',name:'Xray Core',category:'VPN & Proxy',description:'Proxy service core',packages:['xray-core']},
 {id:'singbox',name:'Sing-box',category:'VPN & Proxy',description:'Proxy service core',packages:['sing-box']},
 {id:'openvpn',name:'OpenVPN',category:'VPN & Proxy',description:'VPN service and LuCI app',route:'admin/vpn/openvpn',packages:['openvpn-openssl','luci-app-openvpn']},
 {id:'wifi',name:'Wi-Fi',category:'Network',description:'Wireless networks and access points',route:'admin/network/wireless'},
 {id:'interfaces',name:'Interfaces & Routing',category:'Network',description:'LAN, WAN and routes',route:'admin/network/network'},
 {id:'firewall',name:'Firewall',category:'Network',description:'Zones, rules and forwards',route:'admin/network/firewall'},
 {id:'diagnostics',name:'Diagnostics',category:'Diagnostics',description:'OpenWrt website and gaming latency tests',route:'admin/raywrt-tools/diagnostics'},
 {id:'packages',name:'Packages',category:'System',description:'Browse and manage packages',route:'admin/raywrt-tools/packages'},
 {id:'backup',name:'Backup',category:'System',description:'Save or restore configuration',route:'admin/raywrt-tools/backup'},
 {id:'reboot',name:'Reboot',category:'System',description:'Restart the router safely',route:'admin/raywrt/reboot'},
 {id:'storage',name:'Storage & Memory',category:'System',description:'Available space and memory',route:'admin/raywrt-tools/settings'},
 {id:'terminal',name:'Terminal',category:'Advanced',description:'Root shell inside the RayWRT panel',route:'admin/raywrt-tools/terminal',packages:['ttyd']},
 {id:'logs',name:'Logs',category:'Advanced',description:'System and kernel logs',route:'admin/status/logs'}
];
const quick=['passwall2','wireguard','terminal','usage'];
registry.push({id:'usage',name:'Data Usage',category:'Network',description:'Daily and per-device traffic',route:'admin/raywrt-tools/usage'});
function parse(text){const result={};String(text||'').split('\n').forEach(line=>{const i=line.indexOf('=');if(i>0)result[line.slice(0,i)]=line.slice(i+1).trim();});return result;}
function label(state){return ({installed:'Installed',install_failed:'Install incomplete',available:'Available',not_installed:'Not installed',checking:'Initializing packages…',index_error:'Repository check failed',package_not_found:'Not in configured repositories',unsupported:'Unsupported',unavailable:'Unavailable',active:'Active',disabled:'Disabled',configured:'Configured',not_configured:'Not configured',error:'Error'})[state]||'Unknown';}
function icon(id){return ({passwall2:'◈',wireguard:'◇',xray:'✳',singbox:'⬡',openvpn:'⌁',wifi:'◉',interfaces:'↔',firewall:'⬢',diagnostics:'⌕',packages:'▦',backup:'▣',reboot:'⟳',storage:'▤',terminal:'›_',logs:'≋',usage:'⌁'})[id]||'◆';}
// The backend returns state only. This view owns action selection, and keeps
// one rendered node per semantic action ID even when branches converge.
function normalizeActions(actions){const byId=new Map();for(const action of actions){if(action&&action.id&&!byId.has(action.id))byId.set(action.id,action);}return [...byId.values()];}

return view.extend({
 addFooter(){},
 load(){return Promise.resolve();},
 render(){
  this.active=true;
  this.installPending=true;
  this.state={};
  const root=E('div',{class:'rw-tools','data-raywrt-build':'1.0.0-tools4'},[
   E('div',{class:'rw-tools-head'},E('div',{},[E('h1',{},'RayWRT Tools'),E('p',{},'Quick access to router tools and settings.')])) ,
   E('label',{class:'rw-tools-search'},[E('span',{},'⌕'),E('input',{id:'rw-tools-search',type:'search',placeholder:'Search tools…','aria-label':'Search tools'})]),
   E('section',{class:'rw-tools-section'},[E('h2',{},'Quick Access'),E('div',{id:'rw-tools-quick',class:'rw-tools-grid rw-tools-quick'},E('p',{class:'rw-tool-loading'},'Loading tools…'))]),
   E('section',{class:'rw-tools-section'},[E('h2',{},'Categories'),E('div',{id:'rw-tool-groups'},E('p',{class:'rw-tool-loading'},'Loading categories…'))]),
   E('details',{class:'rw-tools-manage'},[E('summary',{},'Router details and package indexes'),E('div',{class:'rw-tool-facts',id:'rw-tool-facts'},'Loading tool status…'),E('button',{class:'btn',click:()=>this.refreshIndexes()},'Refresh package indexes')]),
   E('details',{class:'rw-card rw-install-console',id:'rw-install-console'},[E('summary',{},'Installation activity'),E('div',{id:'rw-install-state'},'Idle'),E('pre',{id:'rw-install-log'},'No installation running.'),E('button',{class:'btn',click:()=>navigator.clipboard.writeText(document.getElementById('rw-install-log').textContent)},'Copy log')])
  ]);
  root.querySelector('#rw-tools-search').addEventListener('input',ev=>this.filter(ev.target.value));
  this.onVisibility=()=>{if(!document.hidden&&this.active&&this.installPending)this.pollInstall();};
  document.addEventListener('visibilitychange',this.onVisibility);
  window.setTimeout(()=>this.loadStatus(),0);
  return root;
 },
 async loadStatus(checkProgress=true,forceRefresh=false){
  try{const result=await fs.exec(helper,[forceRefresh?'refresh_status':'status']);if(result.code!==0)throw Error(result.stderr||'Status unavailable');this.state=parse(result.stdout);this.draw();if(checkProgress){this.installPending=true;this.pollInstall();}}
  catch(e){this.stateError=e.message;const facts=document.getElementById('rw-tool-facts'),quick=document.getElementById('rw-tools-quick'),groups=document.getElementById('rw-tool-groups');if(facts)facts.replaceChildren(E('span',{},'Tool status unavailable: '+e.message),E('button',{class:'rw-tool-secondary',click:()=>this.loadStatus(false,true)},'Retry'));if(quick)quick.replaceChildren(E('p',{},'Tool status is unknown.'));if(groups)groups.replaceChildren(E('p',{},'Retry the status check.'));}
 },
 card(t,quickAccess=false){
  const s=this.state,state=s['tool_'+t.id],busy=this.busyTool===t.id,known=['installed','install_failed','available','not_installed','checking','index_error','package_not_found','unsupported','unavailable','active','disabled','configured','not_configured','error'].includes(state),installed=state==='installed',available=state==='available'||state==='not_installed',isRoute=state==='active'||state==='disabled'||state==='configured'||state==='not_configured';
  const routeOk=s['route_'+t.id]==='yes'||isRoute;
  const passwallStatus=t.id==='passwall2'&&installed?(s.passwall_runtime==='running'?'Running':s.passwall_configured==='yes'?'Installed · Configured · Stopped':'Installed · Not configured'):null;
  const status=busy?'Installing…':!known?'Unknown':passwallStatus|| (t.id==='wireguard'&&installed?(s.wireguard_configured==='yes'?'Configured':'Not configured'):label(state));
  let primary,primaryActionId;
  if(busy){primaryActionId='installing';primary=E('button',{class:'rw-tool-disabled',disabled:true},'Installing…');}
  else if(state==='checking'){primaryActionId='checking';primary=E('button',{class:'rw-tool-disabled',disabled:true},'Checking…');}
  else if(state==='index_error'){primaryActionId='retry-indexes';primary=E('button',{class:'rw-tool-open',click:()=>this.refreshIndexes()},'Retry indexes');}
  else if(t.id==='passwall2'&&state==='install_failed'){primaryActionId='retry-install';primary=E('button',{class:'rw-tool-open',click:()=>this.review(t,'install')},'Retry install');}
  else if(!known){primaryActionId='retry';primary=E('button',{class:'rw-tool-open',click:()=>this.loadStatus(false)},'Retry');}
  else if(t.id==='usage'&&state==='disabled'){primaryActionId='enable';primary=E('button',{class:'rw-tool-open',click:()=>this.enableUsage()},'Enable');}
  else if(t.packages&&installed&&routeOk&&t.route){primaryActionId='open';primary=E('a',{class:'rw-tool-open',href:L.url(t.id==='openvpn'&&s.openvpn_route?s.openvpn_route:t.route)},t.id==='wireguard'&&s.wireguard_configured!=='yes'?'Configure':'Open');}
  else if(t.packages&&installed){primaryActionId='manage';primary=E('button',{class:'rw-tool-open',click:()=>this.review(t,'manage')},'Manage');}
  else if(t.packages&&available){primaryActionId='install';primary=E('button',{class:'rw-tool-open',click:()=>this.review(t,'install')},'Install');}
  else if(t.packages){primaryActionId='unavailable';primary=E('span',{class:'rw-tool-disabled'},state==='package_not_found'?'Unavailable':'Unsupported');}
  else if(routeOk&&t.route){primaryActionId='open';primary=E('a',{class:'rw-tool-open',href:L.url(t.id==='openvpn'&&s.openvpn_route?s.openvpn_route:t.route)},'Open');}
  else{primaryActionId='retry';primary=E('button',{class:'rw-tool-open',click:()=>this.loadStatus(false)},'Retry');}
  const secondary=[];
  if(t.packages&&installed&&t.id!=='passwall2'&&primary.tagName==='A')secondary.push({id:'manage',node:E('button',{class:'rw-tool-secondary',click:()=>this.review(t,'manage')},'Manage')});
  // The primary branch is the sole owner of Retry/fallback generation.
  // Secondary actions are independent semantic actions such as Manage.
  const actionNodes=normalizeActions([{id:primaryActionId,node:primary},...secondary]).map(action=>action.node);
  const card=E('article',{class:'rw-tool-card','data-tool':(t.name+' '+t.category+' '+t.description).toLowerCase()},[
   E('div',{class:'rw-tool-title'},[E('span',{class:'rw-tool-icon','aria-hidden':'true'},icon(t.id)),E('div',{class:'rw-tool-heading'},[E('h3',{},t.name),E('span',{class:'rw-tool-state rw-state-'+(installed?'installed':available?'available':status.toLowerCase().replace(/\s+/g,'-'))},status)])]),
   E('p',{},t.description),
   E('div',{class:'rw-tool-actions'},actionNodes)
  ]);
  return card;
 },
 draw(){
  const facts=document.getElementById('rw-tool-facts'),groups=document.getElementById('rw-tool-groups'),quickRoot=document.getElementById('rw-tools-quick');
  if(!groups||!quickRoot)return;
  const s=this.state;
  if(facts)facts.textContent=`Package manager: ${s.manager||'Unavailable'} · Architecture: ${s.arch||'Unavailable'} · Overlay free: ${s.overlay_kb?Math.round(+s.overlay_kb/1024)+' MiB':'Unavailable'}`;
  quickRoot.replaceChildren(...quick.map(id=>registry.find(t=>t.id===id)).filter(Boolean).map(t=>this.card(t,true)));
  groups.replaceChildren();
  ['VPN & Proxy','Network','System','Diagnostics','Advanced'].forEach(category=>{
   const items=registry.filter(t=>t.category===category);if(!items.length)return;
   const details=E('details',{class:'rw-tools-category'}),summary=E('summary',{},[E('span',{},category),E('small',{},`${items.length} tools`)]),grid=E('div',{class:'rw-tools-grid'});
   details.append(summary);
   items.forEach(t=>grid.appendChild(this.card(t)));
   details.appendChild(grid);groups.appendChild(details);
  });
  this.filter(document.getElementById('rw-tools-search')?.value||'');
  if(s.indexes==='pending'||s.indexes==='initializing'){
   if(this.statusTimer)clearTimeout(this.statusTimer);
   this.statusTimer=window.setTimeout(()=>{if(this.active&&!document.hidden)this.loadStatus(false);},8000);
  }else if(this.statusTimer){clearTimeout(this.statusTimer);this.statusTimer=null;}
 },
 filter(query){
  const term=String(query||'').trim().toLowerCase();
  document.querySelectorAll('.rw-tool-card').forEach(card=>{card.hidden=!!term&&!card.dataset.tool.includes(term);});
  document.querySelectorAll('.rw-tools-category').forEach(category=>{
   const hasVisible=!!category.querySelector('.rw-tool-card:not([hidden])');
   category.hidden=!!term&&!hasVisible;
   if(term&&hasVisible)category.open=true;
  });
  const quick=document.getElementById('rw-tools-quick')?.closest('.rw-tools-section');
  if(quick)quick.hidden=!!term&&!quick.querySelector('.rw-tool-card:not([hidden])');
 },
 review(t,operation='install'){
  const s=this.state;
  const passwallSource=t.id==='passwall2'&&s.tool_passwall2!=='installed';
  const sourceBase='https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-'+(s.release||'').split('.').slice(0,2).join('.')+'/'+(s.arch||'unknown');
  const details=E('div',{},[
   E('p',{},operation==='remove'?'Remove '+t.name+' and its fixed package set?':operation==='update'?'Check configured feeds for a newer '+t.name+' package?':passwallSource?'Install Passwall 2 after adding the reviewed compatible package source?':operation==='install'?'Install '+t.name+' and its fixed package set?':'Manage '+t.name+' packages on this router.'),
   E('p',{},'Packages: '+t.packages.join(', ')),
   E('p',{},'OpenWrt '+(s.release||'unknown')+' · '+(s.arch||'unknown')+' · '+(s.manager||'unknown')),
   E('p',{},'Overlay free: '+(s.overlay_kb?Math.round(+s.overlay_kb/1024)+' MiB':'unknown')+' · /tmp free: '+(s.tmp_kb?Math.round(+s.tmp_kb/1024)+' MiB':'unknown')+' · RAM available: '+(s.memory_available_kb?Math.round(+s.memory_available_kb/1024)+' MiB':'unknown')+'. Exact package size is determined by the package manager.'),
   E('p',{},'Configured repositories:'),
   E('pre',{class:'rw-review-repos'},Object.keys(s).filter(k=>k.startsWith('repository_')).map(k=>s[k]).join('\n')||'None found'),
   passwallSource?E('div',{},[E('p',{},'Signing key: https://master.dl.sourceforge.net/project/openwrt-passwall-build/apk.pub'),E('p',{},'Repositories to add:'),E('pre',{class:'rw-review-repos'},['passwall_packages','passwall_luci','passwall2'].map(name=>sourceBase+'/'+name+'/packages.adb').join('\n')),E('p',{},'Existing feed configuration is backed up and restored if index refresh or package availability checks fail.')]):E('span'),
   E('p',{},'This changes installed packages. Back up configuration before removing packages.')
  ]);
  ui.showModal((operation==='install'?'Install ':'Manage ')+t.name,[details,E('div',{class:'right'},[
   E('button',{class:'btn',click:()=>ui.hideModal()},'Cancel'),
   operation==='install'?E('button',{class:'btn cbi-button-positive',click:()=>{ui.hideModal();this.execute(t,'install');}},'Install'):E('button',{class:'btn cbi-button-positive',click:()=>{ui.hideModal();this.execute(t,'update');}},'Check for updates'),
   operation!=='install'?E('button',{class:'btn cbi-button-negative',click:()=>{ui.hideModal();this.execute(t,'remove');}},'Remove'):E('span')
  ])]);
 },
 async enableUsage(){try{const r=await fs.exec('/usr/libexec/raywrt-usage-control',['configure','1',this.state.retention||'30',this.state.save_minutes||'30']);if(r.code!==0)throw Error(r.stderr||'Could not enable accounting');await this.loadStatus(false);}catch(e){ui.addNotification(null,E('p',{},e.message));}},
 async execute(t,operation){
  const state=document.getElementById('rw-install-state'),log=document.getElementById('rw-install-log'),panel=document.getElementById('rw-install-console');
  if(!state||!log)return;
  this.installPending=true;
  if(operation==='install'){this.busyTool=t.id;this.draw();}
  panel.open=true;state.textContent='Starting '+operation+' for '+t.name+'…';log.textContent='Checking packages and storage…';
  let previousId='none',startSent=false;
  try{
   const before=await fs.exec(helper,['progress']);if(before.code!==0)throw Error(before.stderr||'Could not read the current job state');
   previousId=parse(String(before.stdout||'').split('--LOG--')[0]).job_id||'none';
   this.awaitingStartConfirmation=false;this.expectedJobId=null;
   startSent=true;
   const r=await fs.exec(helper,t.id==='passwall2'&&operation==='install'?['install_passwall2']:['start',t.id,operation]);
   if(r.code!==0){state.textContent='Could not start operation';log.textContent=r.stderr||r.stdout||'Router rejected the package operation.';this.installPending=false;this.busyTool=null;this.loadStatus(false);return;}
   this.expectedJobId=parse(r.stdout).job_id||null;
   this.pollInstall();
  }
  catch(e){
   if(!startSent){state.textContent='Could not start operation';log.textContent=e.message;this.installPending=false;this.busyTool=null;this.loadStatus(false);return;}
   this.awaitingStartConfirmation=true;this.previousJobId=previousId;this.startWaitAttempts=0;this.startRequestError=e.message;
   state.textContent='Checking whether the router started the job…';log.textContent='The start request timed out or did not return. Checking the router’s recorded job before reporting a result.';this.pollInstall();
  }
 },
 async pollInstall(){
  if(!this.active||document.hidden||!document.getElementById('rw-install-log')||this.pollInFlight)return;
  this.pollInFlight=true;
  try{const r=await fs.exec(helper,['progress']);if(r.code!==0)throw Error(r.stderr||'Progress check failed');const [head,tail]=String(r.stdout||'').split('--LOG--');const progress=parse(head),job=progress.state;
   if(this.awaitingStartConfirmation&&progress.job_id===this.previousJobId){
    this.startWaitAttempts=(this.startWaitAttempts||0)+1;
    if(this.startWaitAttempts>=10){this.awaitingStartConfirmation=false;this.installPending=false;document.getElementById('rw-install-state').textContent='Could not confirm that the router started the job';document.getElementById('rw-install-log').textContent=this.startRequestError||'No new package job appeared.';return;}
    this.installPending=true;this.installTimer=window.setTimeout(()=>this.pollInstall(),2000);return;
   }
   if(this.expectedJobId&&progress.job_id!==this.expectedJobId){this.installPending=true;this.installTimer=window.setTimeout(()=>this.pollInstall(),2000);return;}
   this.awaitingStartConfirmation=false;
   document.getElementById('rw-install-state').textContent=({running:'Installing',success:'Success',failed:'Failed'})[job]||job;
   document.getElementById('rw-install-log').textContent=(tail||'').trim()||'Waiting for output…';
   if(job==='running'||job==='starting'||!['success','failed','idle'].includes(job)){this.installPending=true;this.installTimer=window.setTimeout(()=>this.pollInstall(),job==='running'?2000:4000);return;}
   const trackedJob=!!(this.expectedJobId||this.awaitingStartConfirmation);
   this.installPending=false;this.busyTool=null;
   if(job!=='idle'&&trackedJob){this.expectedJobId=null;this.loadStatus(false);}
  }catch(e){const state=document.getElementById('rw-install-state');if(!state)return;state.textContent='Connection delayed · checking again';this.installPending=true;this.installTimer=window.setTimeout(()=>this.pollInstall(),4000);}
  finally{this.pollInFlight=false;}
 },
 async refreshIndexes(){
  const state=document.getElementById('rw-install-state'),log=document.getElementById('rw-install-log'),panel=document.getElementById('rw-install-console');
  if(!state||!log)return;panel.open=true;this.installPending=true;this.expectedJobId=null;state.textContent='Starting package index refresh';log.textContent='Starting background refresh…';
  try{const r=await fs.exec(helper,['refresh']);if(r.code!==0)throw Error(r.stderr||r.stdout||'Could not start package index refresh');this.expectedJobId=parse(r.stdout).job_id||null;this.awaitingStartConfirmation=false;this.pollInstall();}
  catch(e){this.installPending=false;state.textContent='Refresh failed';log.textContent=e.message;}
 },
 unload(){this.active=false;document.removeEventListener('visibilitychange',this.onVisibility);if(this.installTimer)clearTimeout(this.installTimer);if(this.statusTimer)clearTimeout(this.statusTimer);}
});
