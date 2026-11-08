-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
local registry,count={},0
local function check(v,message) assert(v,message);count=count+1 end
local env=setmetatable({},{__index=_G})
env.GetString=function(k) return registry[k] or "" end
env.SetString=function(k,v) check(k=="savegame.mod.osp_beta.view_mode","bounded writes");registry[k]=v end
local chunk=assert(loadfile(arg[1]));setfenv(chunk,env);chunk()
local v,n=env.OSP.ViewMode,env.OSP.Navigation
check(v.get()=="auto" and v.resolve()=="multi","missing detection defaults to full view")
env.IsMultiplayer=function() return false end
check(v.resolve()=="single","native solo")
env.IsMultiplayer=function() return true end
check(v.resolve()=="multi","native multiplayer regardless of roster")
for _,detector in ipairs({function() error("unavailable") end,function() return nil end,function() return 0 end}) do
 env.IsMultiplayer=detector;check(v.resolve()=="multi","failed or invalid detection defaults to full view")
end
check(not v.set("invalid"),"reject invalid preference")
v.set("single");check(v.resolve()=="single","manual solo works without detector")
v.set("multi");env.IsMultiplayer=function() return false end
check(v.resolve()=="multi","manual multi overrides native solo")
registry["savegame.mod.osp_beta.view_mode"]="invalid";check(v.get()=="auto" and v.resolve()=="single","invalid saved preference uses auto")
local eligible=function(id) return v.eligible(id,"single") end
check(#n.list(eligible)==7,"solo filters Permissions")
check(n.choose("permissions",function() return true end,eligible)=="players","hidden active tab gets valid fallback")
check(n.visible("permissions"),"context does not overwrite visibility")
check(#n.list()==8,"full view recovers tabs")
print("PASS view mode preferences and detection: "..count.." assertions")
