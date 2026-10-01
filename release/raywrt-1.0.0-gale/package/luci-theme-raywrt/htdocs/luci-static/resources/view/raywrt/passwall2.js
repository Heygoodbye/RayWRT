'use strict';
'require view';
'require fs';
'require ui';

const helper='/usr/libexec/raywrt-tools';
const source='https://raw.githubusercontent.com/saeed9400/IRAN_Passwall2/main/v1/Passwall-IR.sh';
function parse(s){const x={};String(s||'').split('\n').forEach(l=>{const i=l.indexOf('=');if(i>0)x[l.slice(0,i)]=l.slice(i+1).trim();});return x;}
function wait(ms){return new Promise(resolve=>window.setTimeout(resolve,ms));}
function readinessText(status){return [
 'Passwall2 package: '+(status.passwall_package==='yes'?'PASS':'FAIL'),
 'LuCI route: '+(status.passwall_luci_route==='yes'?'PASS':'FAIL')+' (admin/services/passwall2)',
 'Xray package: '+(status.passwall_xray_package==='yes'?'PASS':'FAIL'),
 'Xray binary: '+(status.passwall_xray_ready==='yes'?'PASS':'FAIL')+(status.passwall_xray_path?' ('+status.passwall_xray_path+')':''),
 'Transparent proxy nft_tproxy: '+(status.passwall_nft_tproxy==='yes'?'PASS':'FAIL'),
 'Transparent proxy nft_socket: '+(status.passwall_nft_socket==='yes'?'PASS':'FAIL'),
 'Passwall service path: '+(status.passwall_service_ready==='yes'?'PASS':'FAIL')+(status.passwall_service?' ('+status.passwall_service+')':''),
 'Configured: '+(status.passwall_configured==='yes'?'YES':'NO'),
 'Running: '+(status.passwall_runtime==='running'?'YES':'NO')
].join('\n');}

return view.extend({
 addFooter(){},
 load(){return L.resolveDefault(fs.exec(helper,['status']),{});},
 render(result){
  this.active=true;
  this.installPending=false;
  this.status=parse(result.stdout);
  const state=this.status.tool_passwall2||'unknown';
  const installed=state==='installed';
  const supported=this.status.manager==='apk'||this.status.manager==='opkg';
  if(installed)window.setTimeout(()=>window.location.replace(L.url('admin/services/passwall2')),0);
  const ssh='ssh root@'+window.location.hostname;
  const steps=this.status.manager==='apk'?[['Open RayWRT Terminal or SSH',ssh],['Add the signed Passwall repository','RayWRT installs the repository key and feeds automatically.'],['Install packages','apk update && apk add luci-app-passwall2 xray-core kmod-nft-tproxy kmod-nft-socket']]:[['Open RayWRT Terminal or SSH',ssh],['Download installer','wget '+source+' -O Passwall-IR.sh'],['Run installer','chmod +x Passwall-IR.sh && ./Passwall-IR.sh'],['One-line version','rm -f Passwall-IR.sh && wget '+source+' && chmod +x Passwall-IR.sh && sh Passwall-IR.sh']];
  const manual=E('section',{class:'rw-card rw-passwall-manual',id:'rw-passwall-manual',hidden:''},[
   E('h2',{},'Manual Installation'),
   E('p',{},this.status.manager==='apk'?'This router uses APK. The Install button configures the signed Passwall repository and installs Passwall 2 and Xray.':'These commands use the requested external script on compatible opkg firmware.'),
   ...steps.map(([label,command])=>E('div',{class:'rw-manual-step'},[E('h3',{},label),E('code',{},command),E('button',{class:'btn',click:()=>this.copy(command)},'Copy')])),
   E('a',{class:'btn',href:L.url('admin/raywrt-tools/terminal')},'Open RayWRT Terminal')
  ]);
  const statusText=installed?'Installed · '+(this.status.passwall_runtime==='running'?'Running':this.status.passwall_configured==='yes'?'Configured · Stopped':'Not configured'):state==='install_failed'?'Installed · readiness check failed':state==='not_installed'?'Not installed':state==='unsupported'?'Unsupported':state==='unavailable'?'Installer unavailable · check network and retry':'Unable to determine Passwall 2 status';
  let primary;
  if(installed)primary=E('a',{class:'btn cbi-button-positive',href:L.url('admin/services/passwall2')},'Open Passwall 2');
  else if(state==='install_failed'&&supported)primary=E('button',{class:'btn cbi-button-positive',id:'rw-passwall-install',click:()=>this.review()},'Retry installation');
  else if(state==='not_installed'&&supported)primary=E('button',{class:'btn cbi-button-positive',id:'rw-passwall-install',click:()=>this.review()},'Install Passwall 2');
  else primary=E('button',{class:'btn cbi-button-positive',id:'rw-passwall-retry',click:()=>this.refreshStatus()},'Retry status');
  const root=E('div',{class:'rw-tools rw-passwall'},[
   E('h1',{},'Passwall 2'),E('p',{},'Proxy & routing for OpenWrt'),
   E('section',{class:'rw-card'},[
    E('h2',{},'Status'),E('p',{id:'rw-passwall-status'},statusText),
    E('p',{},this.status.manager==='apk'?'Installer: signed Passwall APK feed':this.status.manager==='opkg'?'Installer: IRAN_Passwall2':'Installer: checking availability'),
    E('p',{},this.status.manager==='apk'?'Source: openwrt-passwall-build on SourceForge':this.status.manager==='opkg'?'Source: github.com/saeed9400/IRAN_Passwall2':'Passwall 2 has a dedicated RayWRT installer.'),
    this.status.manager==='apk'?E('p',{class:'rw-passwall-warning'},'This router uses APK. Installation uses the signed Passwall APK repository; the requested opkg-only script cannot run here.'):E('span'),
    state==='install_failed'?E('pre',{class:'rw-passwall-readiness'},readinessText(this.status)):E('span'),
    E('div',{class:'rw-tool-actions'},[primary,
     supported&&!installed?E('button',{class:'btn',id:'rw-passwall-check-download',click:()=>this.preflight()},'Check download'):E('span'),
     supported&&!installed?E('button',{class:'btn',click:()=>this.toggleManual()},'Manual Instructions'):E('span')])
   ]),
   E('section',{class:'rw-card rw-install-console'},[E('h2',{},'Installation console'),E('div',{id:'rw-passwall-state'},'Idle'),E('pre',{id:'rw-passwall-log'},'No installation attempted.'),E('div',{class:'rw-tool-actions'},[
    E('button',{class:'btn',click:()=>this.preflight()},'Check download'),E('a',{class:'btn',href:L.url('admin/raywrt-tools/terminal')},'Open Terminal'),E('button',{class:'btn',click:()=>this.toggleManual()},'Manual Instructions')
   ])]),manual
  ]);
  this.root=root;
  this.onVisibility=()=>{if(!document.hidden&&this.active&&this.installPending)this.poll();};
  document.addEventListener('visibilitychange',this.onVisibility);
  window.setTimeout(()=>this.poll(),0);
  return root;
 },
 copy(s){navigator.clipboard.writeText(s).then(()=>ui.addNotification(null,E('p',{},'Copied.'))).catch(e=>ui.addNotification(null,E('p',{},'Copy failed: '+e.message)));},
 toggleManual(){const el=this.root.querySelector('#rw-passwall-manual');el.hidden=!el.hidden;if(!el.hidden)el.scrollIntoView({behavior:'smooth',block:'nearest'});},
 async refreshStatus(){
  const status=this.root.querySelector('#rw-passwall-status'),state=this.root.querySelector('#rw-passwall-state'),log=this.root.querySelector('#rw-passwall-log');
  if(state)state.textContent='Checking Passwall 2 status…';
  try{const r=await fs.exec(helper,['refresh_status']);if(r.code!==0)throw Error(r.stderr||'Status check failed');this.status=parse(r.stdout);if(this.status.tool_passwall2==='installed'){if(state)state.textContent='Installed · opening management panel…';window.location.replace(L.url('admin/services/passwall2'));return;}if(status)status.textContent=this.status.tool_passwall2==='not_installed'?'Not installed':this.status.tool_passwall2==='install_failed'?'Installed · readiness check failed':'Unable to determine Passwall 2 status';if(this.status.tool_passwall2==='install_failed'&&log)log.textContent=readinessText(this.status);if(state)state.textContent='Status check complete';}
  catch(e){if(state)state.textContent='Status check failed';if(log)log.textContent=e.message;}
 },
 review(){ui.showModal('Install Passwall 2?',E('div',{},[
  E('p',{},this.status.manager==='apk'?'Installer source: signed openwrt-passwall-build APK feed':'Installer source: saeed9400/IRAN_Passwall2'),this.status.manager==='apk'?E('span'):E('p',{},'Script: v1/Passwall-IR.sh'),
  E('p',{},this.status.manager==='apk'?'RayWRT will add the signed Passwall APK repository and install Passwall 2 and Xray. Package installation changes the router software and may briefly interrupt services.':'RayWRT will download and execute this external installation script on compatible opkg firmware. It may replace dnsmasq and alter DNS and routing settings.'),
  E('div',{class:'right'},[E('button',{class:'btn',click:()=>ui.hideModal()},'Cancel'),E('button',{class:'btn cbi-button-positive',click:()=>{ui.hideModal();this.install();}},'Install')])
 ]));},
 async preflight(){
  const state=this.root.querySelector('#rw-passwall-state'),log=this.root.querySelector('#rw-passwall-log');this.installPending=true;this.jobPurpose='preflight';state.textContent='Starting download check';log.textContent='Starting background download check…';
  try{const r=await fs.exec(helper,['preflight_passwall2']);if(r.code!==0)throw Error(r.stderr||r.stdout||'Could not start download check');this.expectedJobId=parse(r.stdout).job_id||null;this.awaitingStartConfirmation=false;this.poll();}
  catch(e){this.installPending=false;this.jobPurpose=null;state.textContent='Download check failed';log.textContent=e.message;}
 },
 async install(){
  const state=this.root.querySelector('#rw-passwall-state'),log=this.root.querySelector('#rw-passwall-log'),status=this.root.querySelector('#rw-passwall-status'),button=this.root.querySelector('#rw-passwall-install');
  this.installPending=true;if(button)button.disabled=true;status.textContent='Installing…';state.textContent='Preparing installer';log.textContent='Starting fixed installer action…';let previousId='none',startSent=false;
  try{const before=await fs.exec(helper,['progress']);if(before.code!==0)throw Error(before.stderr||'Could not read the current job state');previousId=parse(String(before.stdout||'').split('--LOG--')[0]).job_id||'none';this.awaitingStartConfirmation=false;this.expectedJobId=null;startSent=true;const r=await fs.exec(helper,['install_passwall2']);if(r.code!==0){status.textContent='Not installed';if(button)button.disabled=false;state.textContent='Could not start installer';log.textContent=r.stderr||r.stdout||'Router rejected the installer request.';this.installPending=false;return;}this.expectedJobId=parse(r.stdout).job_id||null;this.poll();}
  catch(e){if(!startSent){status.textContent='Not installed';if(button)button.disabled=false;state.textContent='Could not start installer';log.textContent=e.message;this.installPending=false;return;}this.awaitingStartConfirmation=true;this.previousJobId=previousId;this.startWaitAttempts=0;this.startRequestError=e.message;state.textContent='Checking whether the router started the installer…';log.textContent='The start request did not return. Checking the router’s recorded job before reporting a result.';this.poll();}
 },
 async verifyInstalledAndOpen(){
  const state=this.root.querySelector('#rw-passwall-state'),status=this.root.querySelector('#rw-passwall-status'),log=this.root.querySelector('#rw-passwall-log'),button=this.root.querySelector('#rw-passwall-install');
  state.textContent='Installation complete · checking Passwall 2…';
  for(let attempt=0;attempt<6;attempt++){
   if(attempt)await wait(1000);
   const result=await fs.exec(helper,['status']);
   if(result.code===0){this.status=parse(result.stdout);if(this.status.tool_passwall2==='installed'){
    status.textContent='Installed · '+(this.status.version_passwall2||'version unknown');state.textContent='Passwall 2 is ready · opening its management panel…';
    window.setTimeout(()=>{if(this.active)window.location.replace(L.url('admin/services/passwall2'));},700);return true;
   }}
  }
  const result=await fs.exec(helper,['status']);if(result.code===0)this.status=parse(result.stdout);
  const incomplete=this.status.tool_passwall2==='install_failed';
  status.textContent=incomplete?'Installed · readiness check failed':'Not installed';state.textContent=incomplete?'Installation requirements failed':'Installer finished without a complete Passwall 2 installation.';log.textContent=readinessText(this.status);if(button)button.disabled=false;return false;
 },
 async poll(){
  if(!this.active||!this.root?.isConnected||document.hidden||this.pollInFlight)return;
  this.pollInFlight=true;
  try{
   const r=await fs.exec(helper,['progress']);if(r.code!==0)throw Error(r.stderr||'Progress check failed');const [head,tail]=String(r.stdout||'').split('--LOG--');const progress=parse(head),job=progress.state;
   if(this.awaitingStartConfirmation&&progress.job_id===this.previousJobId){this.startWaitAttempts=(this.startWaitAttempts||0)+1;if(this.startWaitAttempts>=10){this.awaitingStartConfirmation=false;this.installPending=false;this.root.querySelector('#rw-passwall-state').textContent='Could not confirm that the router started the installer';this.root.querySelector('#rw-passwall-log').textContent=this.startRequestError||'No new package job appeared.';return;}this.installPending=true;this.timer=setTimeout(()=>this.poll(),2000);return;}
   if(this.expectedJobId&&progress.job_id!==this.expectedJobId){this.installPending=true;this.timer=setTimeout(()=>this.poll(),2000);return;}
   this.awaitingStartConfirmation=false;const trackedJob=!!(this.jobPurpose||this.expectedJobId),preflight=this.jobPurpose==='preflight';this.root.querySelector('#rw-passwall-state').textContent=job==='failed'?(preflight?'Download check failed':'Automatic installation failed'):job==='success'?(preflight?'Download verified':'Installation complete · checking state…'):job==='running'?(preflight?'Checking download…':'Installing…'):job==='starting'?(preflight?'Starting download check…':'Starting installer…'):job;this.root.querySelector('#rw-passwall-log').textContent=(tail||'').trim()||'Waiting for output…';
   if(job==='running'||job==='starting'||!['success','failed','idle'].includes(job)){this.installPending=true;this.timer=setTimeout(()=>this.poll(),job==='running'?2000:4000);return;}
   if(job==='success'&&!preflight){this.installPending=false;this.jobPurpose=null;await this.verifyInstalledAndOpen();return;}
   this.installPending=false;
   if(!preflight&&job==='failed'&&trackedJob){await this.refreshStatus();const b=this.root.querySelector('#rw-passwall-install');if(b)b.disabled=false;this.root.querySelector('#rw-passwall-manual').hidden=false;}
   this.jobPurpose=null;this.expectedJobId=null;
  }catch(e){this.installPending=true;this.root.querySelector('#rw-passwall-state').textContent='Connection delayed · checking again';this.timer=setTimeout(()=>this.poll(),4000);}
  finally{this.pollInFlight=false;}
 },
 unload(){this.active=false;document.removeEventListener('visibilitychange',this.onVisibility);if(this.timer)clearTimeout(this.timer);}
});
