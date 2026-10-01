'use strict';
'require view';
'require fs';

const helper='/usr/libexec/raywrt-terminal';
function parse(s){const x={};String(s||'').split('\n').forEach(l=>{const i=l.indexOf('=');if(i>0)x[l.slice(0,i)]=l.slice(i+1).trim();});return x;}
function button(label,fn){return E('button',{type:'button',class:'btn',click:fn},label);}
return view.extend({
 addFooter(){},
 load(){return L.resolveDefault(fs.exec(helper,['status']),{});},
 render(result){
  const status=parse(result.stdout),ready=status.backend==='installed';
  const user=E('input',{type:'text',value:'root',autocomplete:'username','aria-label':'Username'});
  this.login=E('section',{class:'rw-card rw-terminal-login'},[E('h2',{},'RayWRT Terminal'),E('label',{},['Username',user]),E('p',{},'Your current LuCI administrator session authorizes this terminal.'),button('Connect',()=>this.connect(user.value))]);
  const toolbar=E('div',{class:'rw-terminal-toolbar'},[E('strong',{},'RayWRT Terminal'),E('span',{id:'rw-terminal-status'},'● Disconnected'),button('New Session',()=>this.connect('root')),button('Reconnect',()=>this.connect('root')),button('Fullscreen',()=>this.panel.requestFullscreen?.())]);
  this.panel=E('section',{class:'rw-card rw-terminal-panel',hidden:''},[toolbar,E('div',{id:'rw-terminal-screen'}),E('p',{id:'rw-terminal-error'},'')]);
  const root=E('div',{class:'rw-tools rw-terminal'},[E('h1',{},'Terminal'),ready?this.login:E('section',{class:'rw-card'},[E('h2',{},'Interactive backend unavailable'),E('p',{},'Install the official ttyd backend in RayWRT Tools. Its stock service remains disabled; RayWRT launches short lived, credential protected sessions.'),E('a',{class:'btn',href:L.url('admin/raywrt-tools')},'Open RayWRT Tools')]),this.panel]);
  this.root=root;return root;
 },
 async connect(username){
  if(username.trim()!=='root'){this.login.querySelector('p').textContent='Only root is supported.';return;}
  try{
   this.login.querySelector('p').textContent='Starting a protected terminal session…';
   this.frame?.remove();
   const result=await fs.exec(helper,['start']);if(result.code!==0)throw Error(result.stderr||'Terminal could not start');
   const s=parse(result.stdout);if(!/^\d+$/.test(s.port)||! /^[a-f0-9]{48}$/.test(s.token||''))throw Error('Invalid terminal session response');
   this.login.hidden=true;this.panel.hidden=false;
   this.panel.querySelector('#rw-terminal-status').textContent='● Connecting';
   const screen=this.panel.querySelector('#rw-terminal-screen');screen.replaceChildren();
   const frame=E('iframe',{title:'Root shell',src:location.protocol+'//'+location.hostname+':'+s.port+'/'+s.token+'/',style:'width:100%;height:100%;border:0;background:#0b1217'});
   this.frame=frame;screen.appendChild(frame);
   frame.onload=()=>{this.panel.querySelector('#rw-terminal-status').textContent='● Session opened';};
  }catch(e){this.login.hidden=false;this.panel.hidden=true;this.login.querySelector('p').textContent=e.message;}
 },
 unload(){this.frame?.remove();}
});
