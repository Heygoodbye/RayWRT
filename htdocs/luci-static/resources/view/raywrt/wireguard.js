'use strict';
'require view';
'require fs';
'require uci';
'require ui';

const helper='/usr/libexec/raywrt-wireguard-split';
function parse(s){const x={};String(s||'').split('\n').forEach(l=>{const i=l.indexOf('=');if(i>0)x[l.slice(0,i)]=l.slice(i+1).trim();});return x;}

return view.extend({
 addFooter(){},
 load(){return Promise.all([L.resolveDefault(fs.exec('/usr/libexec/raywrt-tools',['status']),{}),L.resolveDefault(fs.exec(helper,['status']),{}),L.resolveDefault(uci.load('network'),null)]);},
 render([toolsResult,result]){
  const toolsStatus=parse(toolsResult.stdout),s=parse(result.stdout),interfaces=uci.sections('network','interface'),wireguard=interfaces.filter(x=>x.proto==='wireguard');
  const upstreams=interfaces.filter(x=>x['.name']!=='lan'&&x['.name']!=='loopback'&&x.proto!=='wireguard'&&['dhcp','pppoe','static','qmi','wwan'].includes(x.proto));
  const selectedWg=wireguard.find(x=>x['.name']===(s.interface==='not-selected'?'':s.interface))||wireguard[0];
  const selectedWan=upstreams.find(x=>x['.name']===(s.wan_interface||'wan'))||upstreams.find(x=>x['.name']==='wan')||upstreams[0];
  const wgSelect=E('select',{class:'rw-wg-split-select','aria-label':'WireGuard interface'},wireguard.map(x=>E('option',{value:x['.name'],selected:selectedWg&&x['.name']===selectedWg['.name']},x['.name']+(x.disabled==='1'?' · Disabled':''))));
  const wanSelect=E('select',{class:'rw-wg-split-select','aria-label':'Direct WAN interface'},upstreams.map(x=>E('option',{value:x['.name'],selected:selectedWan&&x['.name']===selectedWan['.name']},x['.name']+' · '+x.proto)));
  const status=E('strong',{id:'rw-wg-split-status'},'Checking…');
  const details=E('div',{class:'rw-wg-split-details',id:'rw-wg-split-details'});
  const feedback=E('pre',{class:'rw-wg-split-log',id:'rw-wg-split-log',hidden:''});
  const save=E('button',{class:'btn',click:()=>this.configure(wgSelect.value,wanSelect.value,feedback)},'Save interfaces');
  const toggle=E('button',{class:'btn primary',id:'rw-wg-split-toggle',click:()=>this.toggle(wgSelect.value,wanSelect.value,feedback)},s.enabled==='1'?'Disable Iran direct routing':'Enable Iran direct routing');
  const refresh=E('button',{class:'btn',click:()=>this.startJob('refresh',feedback)},'Update Iran IP list');
  if(!wireguard.length){wgSelect.disabled=true;save.disabled=true;if(s.enabled!=='1')toggle.disabled=true;refresh.disabled=true;}
  if(!upstreams.length){wanSelect.disabled=true;save.disabled=true;if(s.enabled!=='1')toggle.disabled=true;}
  const root=E('div',{class:'rw-tools rw-wireguard'},[
   E('h1',{},'WireGuard'),E('p',{},'Manage native OpenWrt WireGuard interfaces and RayWRT-only traffic routing.'),
   E('section',{class:'rw-card'},[E('h2',{},'Support'),E('p',{},toolsStatus.tool_wireguard==='installed'?'Installed'+(toolsStatus.version_wireguard?' · '+toolsStatus.version_wireguard:''):toolsStatus.tool_wireguard==='available'?'Available in configured feeds':'Not available in current package indexes'),
    E('p',{},'Package manager: '+(toolsStatus.manager||'unknown')+' · Architecture: '+(toolsStatus.arch||'unknown')),
    E('a',{class:'btn',href:L.url('admin/raywrt-tools')},'Review packages')]),
   E('section',{class:'rw-card rw-wg-split-card'},[
    E('div',{class:'rw-wg-split-heading'},[E('div',{},[E('h2',{},'Iran direct routing'),E('p',{},'Send Iranian IPv4 ranges over your regular WAN. Other IPv4 traffic keeps using the WireGuard default route.')]),status]),
    E('p',{class:'rw-wg-split-description'},'This is a RayWRT feature. It uses a separate routing table and nftables rules; it does not change Passwall 2 or DNS. When you enable it, RayWRT starts the selected WireGuard interface if needed and verifies its IPv4 default route. If activation fails, it restores the prior interface and peer settings.'),
    E('div',{class:'rw-wg-split-form'},[
     E('label',{},['WireGuard interface',wgSelect]),E('label',{},['Direct WAN',wanSelect]),
     E('div',{class:'rw-wg-split-actions'},[save,toggle,refresh])
    ]),details,
    E('p',{class:'rw-wg-split-note'},'IPv4 only. IPv6 traffic is not changed by this feature. Iranian routing uses routed CIDR ranges fetched from the Iran IP database; update the list periodically.'),feedback
   ]),
   E('section',{class:'rw-card'},[E('h2',{},'Configured interfaces'),wireguard.length?E('ul',{},wireguard.map(x=>E('li',{},x['.name']+' · '+(x.disabled==='1'?'Disabled':'Configured')))):E('p',{},'No WireGuard interfaces configured.'),
    wireguard.length?E('p',{},'Peers: '+uci.sections('network').filter(x=>x['.type']?.startsWith('wireguard_')).length):E('span'),
    E('a',{class:'btn',href:L.url('admin/network/network')},'Open Network Interfaces')])
  ]);
  this.root=root;this.updateStatus(s,details,status,toggle);this.polling=false;
  return root;
 },
 updateStatus(s,details,status,toggle){
  const states={active:['Active · Iran IPv4 via WAN','rw-state-ok'],disabled:['Off',''], 'needs-attention':['Needs attention','rw-state-warn']};
  const state=states[s.state]||['Unavailable','rw-state-warn'];
  status.textContent=state[0];status.className=state[1];
  toggle.textContent=s.enabled==='1'?'Disable Iran direct routing':'Enable Iran direct routing';
  details.replaceChildren(
   E('span',{},'WireGuard default route: '+(s.route_device||'unknown')),
   E('span',{},'Iran IPv4 ranges: '+(s.iran_ipv4_ranges||'0')),
   E('span',{},'List updated: '+(s.list_updated||'never')),
   E('span',{},'WAN egress: '+(s.wan_interface||'wan')+(s.wan_gateway&&s.wan_gateway!=='unavailable'?' via '+s.wan_gateway:''))
  );
 },
 async configure(wg,wan,feedback){
  if(!wg||!wan)return;
  feedback.hidden=false;feedback.textContent='Saving the selected interfaces…';
  try{const r=await fs.exec(helper,['configure',wg,wan]);if(r.code!==0)throw Error(r.stderr||r.stdout||'Could not save interfaces');feedback.textContent=r.stdout||'Saved.';this.refreshStatus();}
  catch(e){feedback.textContent=e.message;}
 },
 async toggle(wg,wan,feedback){
  const button=this.root?.querySelector('#rw-wg-split-toggle');if(button)button.disabled=true;
  try{
   const s=parse((await fs.exec(helper,['status'])).stdout);
   if(s.enabled==='1'){
    feedback.hidden=false;feedback.textContent='Disabling RayWRT’s Iran routing rules…';
    const r=await fs.exec(helper,['disable']);if(r.code!==0)throw Error(r.stderr||r.stdout||'Could not disable split routing');feedback.textContent=r.stdout||'Disabled.';await this.refreshStatus();return;
   }
   const configured=await fs.exec(helper,['configure',wg,wan]);if(configured.code!==0)throw Error(configured.stderr||configured.stdout||'Could not save interfaces');
   await this.startJob('enable',feedback);
  }catch(e){feedback.hidden=false;feedback.textContent=e.message;}
  finally{if(button&&!this.taskBusy)button.disabled=false;}
 },
 async startJob(action,feedback){
  if(this.taskBusy)return;this.taskBusy=true;this.setBusy(true);
  feedback.hidden=false;feedback.textContent=action==='enable'?'Starting Iran list download and route setup…':'Starting Iran IP list update…';
  try{
   const r=await fs.exec(helper,[action]);if(r.code!==0)throw Error(r.stderr||r.stdout||'Could not start the routing task');
   const job=parse(r.stdout).job_id;if(!job)throw Error(r.stderr||r.stdout||'Router did not confirm the routing task');
   this.pollJob(job,feedback);
  }catch(e){feedback.textContent=e.message;this.taskBusy=false;this.setBusy(false);}
 },
 async pollJob(job,feedback){
  if(!this.root?.isConnected||this.polling)return;this.polling=true;
  try{
   const r=await fs.exec(helper,['progress']);if(r.code!==0)throw Error(r.stderr||'Progress check failed');
   const [head,log]=String(r.stdout||'').split('--LOG--'),p=parse(head);
   if(p.job_id!==job){feedback.textContent='The router is checking the routing task…';setTimeout(()=>{this.polling=false;this.pollJob(job,feedback);},2000);return;}
   feedback.textContent=(log||'').trim()||(p.state==='starting'?'Starting the background worker…':p.state==='running'?'Preparing routes…':'');
   if(p.state==='starting'||p.state==='running'){setTimeout(()=>{this.polling=false;this.pollJob(job,feedback);},2000);return;}
   if(p.state==='success')feedback.textContent+=(feedback.textContent?'\n':'')+'Completed.';
   else if(p.state==='failed')feedback.textContent+=(feedback.textContent?'\n':'')+'Task failed. Review the message above.';
   await this.refreshStatus();this.taskBusy=false;this.setBusy(false);
  }catch(e){feedback.textContent='Connection delayed; checking again…';setTimeout(()=>{this.polling=false;this.pollJob(job,feedback);},4000);}
  finally{this.polling=false;}
 },
 setBusy(busy){this.root?.querySelectorAll('.rw-wg-split-actions button').forEach(b=>{b.disabled=busy;});},
 async refreshStatus(){
  if(!this.root?.isConnected)return;
  try{const r=await fs.exec(helper,['status']);if(r.code!==0)return;const s=parse(r.stdout);this.updateStatus(s,this.root.querySelector('#rw-wg-split-details'),this.root.querySelector('#rw-wg-split-status'),this.root.querySelector('#rw-wg-split-toggle'));}
  catch(e){}
 }
});
