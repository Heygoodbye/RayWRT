import sys,pathlib
root=pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0,str(root/'.android-tools/python-libs'))
from lupa import LuaRuntime
script=(root/'companion/node-import.lua').read_text(encoding='utf-8-sig')
def run(mode,valid=True,pending=False,anonymous=False):
 lua=LuaRuntime(unpack_returned_tuples=True)
 lua.execute('''
 db={old={['.name']='old',['.type']='nodes',remarks='Existing',group='default'},global={['.name']='global',['.type']='global',node='old',enabled='0'}}
 files={}; committed=0; calls=0
 u={}
 function u:changes() return pending and {x=true} or {} end
 function u:foreach(c,t,f) for _,v in pairs(db) do if t==nil or v['.type']==t then f(v) end end end
 function u:get(c,id,k) if not db[id] then return nil end return k and db[id][k] or db[id]['.type'] end
 function u:set(c,id,k,v) db[id][k]=v end
 function u:add(c,t) db.sub={['.name']='sub',['.type']=t};return 'sub' end
 function u:delete(c,id,k) if k then db[id][k]=nil else db[id]=nil end end
 function u:commit() committed=committed+1 end
 function u:load() end;function u:unload() end
 fs={access=function(p) return p=='/usr/share/passwall2/subscribe.lua' or files[p] end,chmod=function()end,remove=function(p) files[p]=nil end}
 require=function(n) if n=='uci' then return {cursor=function()return u end} elseif n=='nixio.fs' then return fs else return {LOCK_PREFIX='/tmp/passwall2'} end end
 io.open=function(p,m) files[p]=true;return {write=function()end,close=function()end} end
 io.stderr={write=function(self,s) lastError=s end}
 os.exit=function() error('IMPORT_FAILED') end
 os.execute=function(cmd)
  calls=calls+1
  if valid then db.new={['.name']='new',['.type']='nodes',group=arg[1]=='node' and 'default' or db.sub.remark};if db.sub then db.sub.md5='abc' end end
  return 0
 end
 ''')
 lua.globals().valid=valid;lua.globals().pending=pending
 lua.globals().arg=lua.table_from([mode,'vless://id@host:443','EU','sub'])
 if mode=='delete':lua.execute("db.sub={['.name']='sub',['.type']='nodes'};if not valid then db.global.node='sub' end")
 if mode=='update':lua.execute("db.sub={['.name']='sub',['.type']='subscribe_list',remark='EU',url='https://example.com',md5='old'}")
 if anonymous:lua.globals().arg[4]='@subscribe_list[0]'
 try:lua.execute(script);ok=True
 except Exception as e:
  if 'IMPORT_FAILED' not in str(e):raise
  ok=False
 assert ok==(valid and not pending),(mode,valid,pending)
 assert lua.eval("db.global.enabled=='0'")
 assert mode=='delete' or lua.eval("db.global.node=='old'")
 if mode=='delete' and valid and not pending:assert lua.eval('db.sub==nil')
 assert not lua.eval("files['/tmp/links.conf']")
 if not valid and mode=='subscription':assert lua.eval('db.sub==nil')
 if pending:assert lua.eval('calls==0')
for mode in ['node','subscription','update']:
 for valid in [True,False]:run(mode,valid)
run('node',True,True)
run('delete',True);run('delete',False);run('delete',True,True)
run('update',True,anonymous=True);run('update',False,anonymous=True)
print('PASS: 7 Lua importer scenarios, rollback, pending changes, existing active node preserved')
