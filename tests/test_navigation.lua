-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
local registry,count={},0
local function check(v,message) assert(v,message);count=count+1 end
local env=setmetatable({},{__index=_G})
env.GetString=function(key) return registry[key] or '' end
env.SetString=function(key,value) check(key:match('^savegame%.mod%.osp%.navigation%.hidden%.[a-z]+$') or key:match('^savegame%.mod%.osp%.navigation%.[a-z_]+$'),'bounded preference write');registry[key]=value end
local chunk=assert(loadfile(arg[1]));setfenv(chunk,env);chunk()
local n=env.OSP.Navigation
check(#n.list()==8,'default tabs visible')
check(n.tabs[6]=='appearance' and n.tabs[7]=='settings','Appearance is a main tab before Settings')
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
n.reset();check(#n.list()==8,'restore all')
check(registry['savegame.mod.osp.players.p1.role']=='keep','reset preserves other data')
check(n.choose('permissions',function(id) return id=='settings' or id=='about' end)=='settings','access still enforced')
check(n.selectionMode()=='keep' and n.openingMode()=='last' and n.lastTab()=='players','behavior defaults preserve existing navigation')
check(not n.setSelectionMode('unknown') and not n.setOpeningMode(false),'invalid choices rejected')
for _,mode in ipairs({'keep','close','leave'}) do check(n.setSelectionMode(mode) and n.selectionMode()==mode,'selection mode round trip') end
check(n.setOpeningMode('players') and n.openingMode()=='players','fixed opening tab')
check(n.rememberTab('tools') and n.lastTab()=='tools','last tab remembered')
check(not n.rememberTab('unknown') and n.lastTab()=='tools','unknown last tab rejected')
n.reset();check(n.selectionMode()=='leave' and n.openingMode()=='players' and n.lastTab()=='tools','show all only resets visibility')
local fresh=assert(loadfile(arg[1]));setfenv(fresh,env);fresh()
n=env.OSP.Navigation
check(n.selectionMode()=='leave' and n.openingMode()=='players' and n.lastTab()=='tools','new Lua context shares local preferences')
registry['savegame.mod.osp.navigation.selection_mode']='invalid'
registry['savegame.mod.osp.navigation.opening_mode']='invalid'
registry['savegame.mod.osp.navigation.last_tab']='invalid'
check(n.selectionMode()=='keep' and n.openingMode()=='last' and n.lastTab()=='players','malformed preferences fall back safely')
n.resetBehavior();check(n.selectionMode()=='keep' and n.openingMode()=='last' and n.lastTab()=='players','personal behavior reset')
check(registry['savegame.mod.osp.players.p1.role']=='keep','behavior reset preserves server choices')
print('PASS navigation preferences: '..count..' assertions')
