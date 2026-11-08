-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
local registry,count={ ["savegame.mod.osp_beta.settings.collapsed.button_style"]="0" },0
local function check(v,message) assert(v,message);count=count+1 end
local env=setmetatable({},{__index=_G})
env.GetString=function(key) return registry[key] or "" end
env.SetString=function(key,value)
    check(key:match("^savegame%.mod%.osp_beta%.settings%.collapsed%.[a-z_]+$"),"bounded presentation writes")
    registry[key]=value
end
local chunk=assert(loadfile(arg[1]));setfenv(chunk,env);chunk()
local s=env.OSP.SettingsSections
for _,id in ipairs(s.ids) do check(not s.expanded(id),"default collapsed") end
check(not s.expanded("unknown"),"unknown section rejected")
check(not s.setExpanded("unknown",false),"cannot write unknown section")
check(not s.expanded("button_style"),"removed button style section ignores saved state")
check(not s.setExpanded("button_style",true),"removed button style section cannot be reopened")
check(registry["savegame.mod.osp_beta.settings.collapsed.button_style"]=="0","legacy button style state is left untouched")
check(not s.setExpanded("language","false"),"require boolean")
s.setExpanded("language",false);check(not s.expanded("language"),"collapse known section")
s.setExpanded("language",true);check(s.expanded("language") and not s.expanded("shortcut"),"independent states")
registry["savegame.mod.osp_beta.settings.collapsed.language"]="invalid"
check(not s.expanded("language"),"malformed state defaults to collapsed")
registry["savegame.mod.osp_beta.players.test.tools.abc"]="2"
for _,id in ipairs(s.ids) do s.setExpanded(id,true) end
s.reset()
for _,id in ipairs(s.ids) do check(not s.expanded(id),"reset collapses all") end
check(registry["savegame.mod.osp_beta.players.test.tools.abc"]=="2","reset preserves gameplay data")
print("PASS settings sections preferences: "..count.." assertions")
