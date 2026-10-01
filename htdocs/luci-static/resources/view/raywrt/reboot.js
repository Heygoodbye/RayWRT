'use strict';
'require view';
'require rpc';
'require ui';

const reboot=rpc.declare({object:'system',method:'reboot'});
return view.extend({
 addFooter(){},
 load(){return Promise.resolve();},
 render(){return E('div',{class:'rw-tools'},[
  E('h1',{},'Restart router'),
  E('section',{class:'rw-card'},[E('p',{},'Restarting temporarily disconnects all network clients. Configuration is retained.'),
   E('button',{class:'btn cbi-button-negative',click:()=>this.confirm()},'Restart router')]),
  E('p',{id:'rw-reboot-progress',role:'status'},'')
 ]);},
 confirm(){ui.showModal('Restart router?',[E('p',{},'All network connections will be temporarily interrupted.'),E('div',{class:'right'},[
  E('button',{class:'btn',click:()=>ui.hideModal()},'Cancel'),
  E('button',{class:'btn cbi-button-negative',click:()=>{ui.hideModal();this.perform();}},'Restart')
 ])]);},
 async perform(){
  const status=document.getElementById('rw-reboot-progress');status.textContent='Sending restart request…';
  try{await reboot();}catch(e){} // The connection commonly closes during reboot.
  status.textContent='Waiting for router to return…';
  let attempts=0,offline=false;
  const check=async()=>{
   if(!document.getElementById('rw-reboot-progress'))return;
   try{const response=await fetch('/',{cache:'no-store',signal:AbortSignal.timeout(2500)});if(response.ok&&offline){status.textContent='Router is back online. Reload this page to sign in again.';return;}}
   catch(e){offline=true;}
   if(++attempts<60)this.timer=setTimeout(check,3000);else status.textContent='Still waiting. Check the router’s status lights and reconnect manually.';
  };
  this.timer=setTimeout(check,3000);
 },
 unload(){if(this.timer)clearTimeout(this.timer);}
});
