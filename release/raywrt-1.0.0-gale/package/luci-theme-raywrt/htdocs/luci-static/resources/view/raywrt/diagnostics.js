'use strict';
'require view';
'require fs';

const helper='/usr/libexec/raywrt-diagnostics';
const groups=[
 {id:'openwrt',name:'OpenWrt website',targets:['openwrt']},
 {id:'wow',name:'World of Warcraft · EU',targets:['wow1','wow2']},
 {id:'league',name:'League of Legends · EUW / EUNE',targets:['league_euw','league_eune']},
 {id:'tarkov',name:'Escape from Tarkov · EU',targets:['tarkov1','tarkov2']},
 {id:'wot',name:'World of Tanks · EU',targets:['wot1']},
 {id:'fortnite',name:'Fortnite · EU',targets:['fortnite_de','fortnite_fr','fortnite_gb']},
 {id:'pubg',name:'PUBG · EU',targets:['pubg1','pubg2','pubg3','pubg4']}
];
const labels={openwrt:'OpenWrt website',wow1:'EU Server 1',wow2:'EU Server 2',league_euw:'EU Server 1',league_eune:'EU Server 2',tarkov1:'EU Server 1',tarkov2:'EU Server 2',wot1:'EU Server 1',fortnite_de:'Germany',fortnite_fr:'France',fortnite_gb:'UK',pubg1:'EU Server 1',pubg2:'EU Server 2',pubg3:'EU Server 3',pubg4:'EU Server 4'};
function parseResults(text){return String(text||'').trim().split('\n').filter(Boolean).map(line=>{const [id,state,min,avg,max,loss,detail]=line.split('|');return{id,state,min:+min,avg:+avg,max:+max,loss:+loss,detail};});}
function ms(value){return Number.isFinite(value)?value.toFixed(1)+' ms':'—';}
function errorLabel(detail){return detail==='dns_error'?'DNS lookup failed':detail==='no_route'?'No route from router':detail==='permission_error'?'Ping permission error':'No replies';}

return view.extend({
 addFooter(){},
 load(){return Promise.resolve();},
 render(){
  this.active=true;this.rows=[];this.stage='idle';
  const root=E('div',{class:'rw-tools rw-diagnostics'},[
   E('h1',{},'Diagnostics'),
   E('p',{},'Check reachability and latency to OpenWrt and selected game servers. Server addresses are kept private.'),
   E('section',{class:'rw-card rw-diagnostics-intro'},[
    E('p',{},'All 15 endpoints are pinged concurrently from the router. Each endpoint receives four probes. Multi-server game results include the mean and range of the individual server averages.'),
    E('button',{class:'btn cbi-button-positive',click:()=>this.runTests()},'Run all tests'),
    E('span',{id:'rw-diagnostics-state','aria-live':'polite'},'Tests ready · 15 endpoints')
   ]),
   E('div',{id:'rw-diagnostics-results',class:'rw-diagnostics-grid'})
  ]);
  this.root=root;this.renderResults();return root;
 },
 async runTests(){
  if(this.running||!this.root?.isConnected)return;
  this.running=true;this.stage='testing';
  const button=this.root.querySelector('button'),state=this.root.querySelector('#rw-diagnostics-state');
  button.disabled=true;button.textContent='Testing…';state.textContent='Testing all 15 endpoints concurrently from the router.';this.renderResults();
  try{
   const response=await fs.exec(helper,['run']);
   if(response.code!==0)throw Error(response.stderr||'The router could not run the connectivity tests.');
   this.rows=parseResults(response.stdout);this.stage='done';this.renderResults();
   const passed=this.rows.filter(x=>x.state==='ok').length;
   state.textContent=`Finished · ${passed} of ${this.rows.length} endpoints replied.`;
  }catch(error){
   this.stage='error';this.errorMessage=error.message;state.textContent='Test request failed.';this.renderResults();
  }finally{this.running=false;if(button.isConnected){button.disabled=false;button.textContent='Run all tests';}}
 },
 renderResults(){
  const results=this.root.querySelector('#rw-diagnostics-results');
  results.replaceChildren(...groups.map(group=>{
   const rows=group.targets.map(id=>({id,result:this.rows.find(row=>row.id===id)}));
   const passed=rows.map(item=>item.result).filter(row=>row?.state==='ok'&&Number.isFinite(row.avg));
   const averages=passed.map(row=>row.avg),mean=averages.length?averages.reduce((sum,value)=>sum+value,0)/averages.length:NaN;
   const range=averages.length>1?` · Range ${Math.min(...averages).toFixed(1)}–${Math.max(...averages).toFixed(1)} ms`:'';
   let summary=this.stage==='idle'?'Ready to test':this.stage==='testing'?'Testing…':passed.length?`Mean ${ms(mean)}${range}`:'No endpoint replied';
   if(this.stage==='error')summary='Test request failed';
   const summaryClass=this.stage==='testing'?'rw-diagnostic-partial':passed.length===rows.length?'rw-diagnostic-ok':passed.length?'rw-diagnostic-partial':'rw-diagnostic-fail';
   return E('section',{class:'rw-card rw-diagnostic-group'},[
    E('div',{class:'rw-diagnostic-heading'},[E('h2',{},group.name),E('strong',{class:summaryClass},summary)]),
    this.stage==='error'?E('p',{class:'rw-diagnostic-fail'},this.errorMessage||'The connectivity test failed.'):null,
    E('div',{class:'rw-diagnostic-targets'},rows.map(item=>{
     const row=item.result;
     const status=this.stage==='testing'?E('span',{class:'rw-diagnostic-partial'},'Testing…'):this.stage==='idle'?E('span',{},'Not tested'):row?.state==='ok'?E('span',{class:'rw-diagnostic-ok'},`${ms(row.avg)} avg · ${row.loss}% loss`):E('span',{class:'rw-diagnostic-fail'},errorLabel(row?.detail));
     return E('div',{class:'rw-diagnostic-target'},[E('strong',{},labels[item.id]||'Server'),status]);
    }))
   ].filter(Boolean));
  }));
 }
});
