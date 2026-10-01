local u=require('uci').cursor()
local fs=require('nixio.fs')
local api=require('luci.passwall2.api')
local mode,link,name,id=arg[1],arg[2],arg[3],arg[4]
local function fail(s) io.stderr:write(s..'\n');os.exit(1) end
local function q(s) return "'"..s:gsub("'","'\\''").."'" end
if mode=='update' or mode=='delete' then
 local section,index=id:match('^@([%w_]+)%[(%d+)%]$')
 if section then
  local expected=mode=='update' and 'subscribe_list' or 'nodes'
  if section~=expected then fail('Invalid configuration identifier.') end
  local resolved=nil;local position=0
  u:foreach('passwall2',section,function(s)
   if position==tonumber(index) then resolved=s['.name'] end
   position=position+1
  end)
  if not resolved then fail('Configuration no longer exists. Refresh first.') end
  id=resolved
 end
end
if mode=='delete' then
 if not id:match('^[%w_]+$') or u:get('passwall2',id)~='nodes' then fail('Node no longer exists. Refresh first.') end
 if next(u:changes('passwall2') or {}) then fail('Apply pending Passwall changes in LuCI first.') end
 local referenced=false
 u:foreach('passwall2',nil,function(section)
  if section['.name']~=id then
   for key,value in pairs(section) do
    if key:sub(1,1)~='.' then
     if type(value)=='table' then for _,item in ipairs(value) do if item==id then referenced=true end end
     elseif type(value)=='string' then for item in value:gmatch('%S+') do if item==id then referenced=true end end end
    end
   end
  end
 end)
 if referenced then fail('This node is active or referenced by another configuration. Select another active node and remove its references in LuCI first.') end
 u:delete('passwall2',id);u:commit('passwall2');print('Configuration deleted.');return
end
if not fs.access('/usr/share/passwall2/subscribe.lua') then fail('Passwall 2 importer is not installed.') end
if fs.access(api.LOCK_PREFIX..'_subscribe.lock') or fs.access(api.LOCK_PREFIX..'_rule_update.lock') then fail('Passwall is updating. Try again shortly.') end
if next(u:changes('passwall2') or {}) then fail('Apply pending Passwall changes in LuCI first.') end
local before={}
u:foreach('passwall2','nodes',function(n) before[n['.name']]=true end)
local created=false
if mode=='node' then
 if fs.access('/tmp/links.conf') then fail('A LuCI node import is pending. Finish it first.') end
 local f=io.open('/tmp/links.conf','w');if not f then fail('Cannot create import input.') end
 f:write(link);f:close();fs.chmod('/tmp/links.conf',384)
 os.execute('lua /usr/share/passwall2/subscribe.lua add default >/dev/null 2>&1')
 fs.remove('/tmp/links.conf')
else
 if mode=='subscription' then
  if name=='' then name='RayWRT '..os.date('%Y%m%d %H%M%S') end
  local duplicate=false
  u:foreach('passwall2','subscribe_list',function(s) if (s.remark or ''):lower()==name:lower() then duplicate=true end end)
  if duplicate or name:lower()=='default' then fail('Choose a unique subscription name.') end
  id=u:add('passwall2','subscribe_list');created=true
  u:set('passwall2',id,'remark',name);u:set('passwall2',id,'url',link)
  u:set('passwall2',id,'enabled','0');u:set('passwall2',id,'allowInsecure','0')
 elseif mode=='update' then
  if u:get('passwall2',id)~='subscribe_list' then fail('Subscription no longer exists. Refresh first.') end
  name=u:get('passwall2',id,'remark') or ''
 else fail('Invalid import operation.') end
 u:delete('passwall2',id,'md5');u:commit('passwall2')
 os.execute('lua /usr/share/passwall2/subscribe.lua start '..q(id)..' manual >/dev/null 2>&1')
end
u:unload('passwall2');u:load('passwall2')
local count=0
u:foreach('passwall2','nodes',function(n)
 if mode=='node' and not before[n['.name']] then
  count=count+1;if name~='' then u:set('passwall2',n['.name'],'remarks',name) end
 elseif mode~='node' and (n.group or ''):lower()==name:lower() then count=count+1 end
end)
if mode=='node' then u:commit('passwall2') end
if count==0 or (mode~='node' and not u:get('passwall2',id,'md5')) then
 if created then u:delete('passwall2',id);u:commit('passwall2') end
 fail('No usable nodes imported. Check the link, router internet access and installed proxy core.')
end
print('Imported '..count..' node'..(count==1 and '' or 's')..'.')


