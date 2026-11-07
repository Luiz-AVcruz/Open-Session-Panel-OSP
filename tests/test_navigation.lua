-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
local registry,count={},0
local function check(v,message) assert(v,message);count=count+1 end
local env=setmetatable({},{__index=_G})
env.GetString=function(key) return registry[key] or '' end
env.SetString=function(key,value) check(key:match('^savegame%.mod%.osp%.navigation%.hidden%.[a-z]+$'),'bounded preference write');registry[key]=value end
local chunk=assert(loadfile(arg[1]));setfenv(chunk,env);chunk()
local n=env.OSP.Navigation
check(#n.list()==7,'default tabs visible')
check(not n.setVisible('settings',false),'settings cannot be hidden')
check(not n.setVisible('unknown',false),'unknown tabs rejected')
check(not n.setVisible('players','false'),'nonboolean rejected')
n.setVisible('players',false);check(n.choose('players',function() return true end)=='session','first visible fallback')
check(n.choose('tools',function() return true end)=='tools','preserve valid tab')
for _,id in ipairs(n.tabs) do if id~='settings' then n.setVisible(id,false) end end
registry['savegame.mod.osp.navigation.hidden.settings']='1'
check(#n.list()==1 and n.list()[1]=='settings','settings survives even malformed saved flag')
check(n.choose('players',function() return true end)=='settings','all hidden fallback')
registry['savegame.mod.osp.players.p1.role']='keep'
n.reset();check(#n.list()==7,'restore all')
check(registry['savegame.mod.osp.players.p1.role']=='keep','reset preserves other data')
check(n.choose('permissions',function(id) return id=='settings' or id=='about' end)=='settings','access still enforced')
print('PASS navigation preferences: '..count..' assertions')
