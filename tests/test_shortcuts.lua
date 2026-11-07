-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
local registry,pressed,down,last={}, {}, {}, ''
local count=0
local function check(v,m) assert(v,m);count=count+1 end
local env=setmetatable({},{__index=_G})
env.GetString=function(k) return registry[k] or '' end
env.SetString=function(k,v) check(k=='savegame.mod.osp.menu_key' or k:match('^savegame%.mod%.osp%.shortcuts%.[a-z]+$'),'bounded writes');registry[k]=v end
env.InputPressed=function(k) return pressed[k]==true end
env.InputDown=function(k) return down[k]==true end
env.InputLastPressedKey=function() return last end
env.InputClear=function() pressed={};last='' end
local chunk=assert(loadfile(arg[1]));setfenv(chunk,env);chunk()
local s=env.OSP.Shortcuts
for _,id in ipairs(s.actions) do check(s.binding(id)=='','no defaults') end
check(not s.assign('freeze','f8'),'only scoped actions configurable')
check(not s.assign('god','w'),'reserved gameplay key')
check(not s.assign('god','p'),'menu collision')
check(s.assign('god','f8'),'valid assignment')
local ok,reason=s.assign('fly','f8');check(not ok and reason=='shortcut_conflict','duplicate refused')
check(not s.assign('menu','f8'),'panel rebind also rejects collision')
registry['savegame.mod.osp.shortcuts.fly']='f8'
check(s.binding('god')=='' and s.binding('fly')=='','corrupt duplicates never execute')
s.assign('fly','');registry['savegame.mod.osp.menu_key']='f8';check(s.binding('god')=='','menu wins stored collision')
registry['savegame.mod.osp.menu_key']='p'
s.begin('fly');s.key();check(s.capture=='fly','empty event does not cancel')
last='w';s.key();check(s.capture=='fly' and s.message=='invalid_key','invalid event allows retry')
pressed={w=true};s.key();check(s.capture=='fly' and s.message=='invalid_key','physical reserved key also gives feedback')
pressed={f9=true};s.key();check(s.capture==nil and s.binding('fly')=='f9','physical event without last-key works')
s.begin('noclip');last='f10';s.key();check(s.binding('noclip')=='f10','last-key fallback works')
s.begin('noclip');pressed={f11=true};down={shift=true};s.key();check(s.capture=='noclip' and s.binding('noclip')=='f10','modifier rejected without mutation')
down={};pressed={f11=true,f12=true};s.key();check(s.capture=='noclip' and s.message=='shortcut_single_key','multiple keys rejected')
pressed={esc=true};s.key();check(s.capture==nil and s.binding('noclip')=='f10','cancel preserves assignment')
registry['savegame.mod.osp.identity.host']='keep';s.reset()
check(s.binding('god')=='' and s.binding('fly')=='' and s.binding('noclip')=='','clear all')
check(registry['savegame.mod.osp.identity.host']=='keep' and s.menuKey()=='p','reset only personal actions')
print('PASS shortcut preferences and capture: '..count..' assertions')
