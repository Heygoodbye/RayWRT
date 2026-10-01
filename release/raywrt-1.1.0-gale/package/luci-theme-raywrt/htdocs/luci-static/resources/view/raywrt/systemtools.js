'use strict';
'require view';
'require rpc';
'require fs';

const info=rpc.declare({object:'system',method:'info'});
const mounts=rpc.declare({object:'luci',method:'getMountPoints',expect:{result:[]}});
function bytes(n){return Number.isFinite(n)?String.format('%1024.1mB',n):'Unavailable';}
function row(name,value){return E('div',{class:'rw-info-row'},[E('span',{},name),E('strong',{},value)]);}
function parse(s){const x={};String(s||'').split('\n').forEach(l=>{const i=l.indexOf('=');if(i>0)x[l.slice(0,i)]=l.slice(i+1).trim();});return x;}
return view.extend({
 addFooter(){},
 load(){return Promise.all([L.resolveDefault(info(),{}),L.resolveDefault(mounts(),[]),L.resolveDefault(fs.exec('/usr/libexec/raywrt-tools',['status']),{})]);},
 render([sys,mountList,status]){
  const m=sys.memory||{},swap=sys.swap||{},root=sys.root||{},s=parse(status.stdout);
  const external=(Array.isArray(mountList)?mountList:[]).filter(x=>/^\/dev\/(sd|usb)/.test(x.device||''));
  return E('div',{class:'rw-tools'},[
   E('h1',{},'Settings & System Tools'),E('p',{},'Memory, storage and package manager information from this router.'),
   E('p',{},E('a',{class:'btn',href:L.url('admin/system/system')},'Open router settings')),
   E('div',{class:'rw-tools-grid'},[
    E('section',{class:'rw-card'},[E('h2',{},'Memory'),
     row('Total',bytes(m.total)),row('Available',bytes(m.available)),row('Cached',bytes(m.cached)),row('Buffered',bytes(m.buffered)),row('Swap',bytes(swap.total)),
     E('p',{},'Cached memory is reclaimable by Linux. Clearing it routinely does not improve performance.')]),
    E('section',{class:'rw-card'},[E('h2',{},'Storage'),
     row('Root used',bytes(root.used*1024)),row('Root total',bytes(root.total*1024)),row('Root free',bytes(root.free*1024)),
     E('p',{},external.length?external.length+' external mount(s) detected.':'No external storage mount detected. Exroot setup is unavailable.'),
     E('a',{class:'btn',href:L.url('admin/raywrt-tools/backup')},'Backup configuration')]),
    E('section',{class:'rw-card'},[E('h2',{},'Package manager'),row('Manager',s.manager||'Unavailable'),row('OpenWrt',s.release||'Unavailable'),row('Architecture',s.arch||'Unavailable'),
     E('a',{class:'btn',href:L.url('admin/raywrt-tools/packages')},'Open package manager')])
   ])
  ]);
 }
});
