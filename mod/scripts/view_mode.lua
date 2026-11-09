-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Presentation only. Session authority and stored gameplay rules are unchanged.
OSP.ViewMode={}
local V=OSP.ViewMode
local key="savegame.mod.osp.view_mode"
function V.get()
    local value=GetString(key)
    return (value=="single" or value=="multi") and value or "auto"
end
function V.set(value)
    if value~="auto" and value~="single" and value~="multi" then return false end
    SetString(key,value);return true
end
function V.resolve()
    local value=V.get()
    if value~="auto" then return value end
    -- Native session type, never roster size: a multiplayer host can be alone.
    if type(IsMultiplayer)=="function" then
        local ok,multiplayer=pcall(IsMultiplayer)
        if ok and type(multiplayer)=="boolean" then return multiplayer and "multi" or "single" end
    end
    return "multi"
end
function V.eligible(tab,mode) return mode~="single" or tab~="permissions" end
function V.draw(api,x,y,width,bodyOnly)
    local heading=bodyOnly and 0 or 32
    if not bodyOnly then api.label(x,y,OSP.L("view_mode"),20,width) end
    local cols=width>=420 and 3 or 1
    local bw=(width-8*(cols-1))/cols
    for i,value in ipairs({"auto","single","multi"}) do
        if api.button("view_mode_"..value,x+((i-1)%cols)*(bw+8),y+heading+math.floor((i-1)/cols)*44,bw,36,OSP.L("view_"..value),V.get()==value and "active" or "plain") then V.set(value) end
    end
    return 10+heading+math.ceil(3/cols)*44
end
