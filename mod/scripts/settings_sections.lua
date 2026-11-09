-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Local presentation only. Missing or malformed preferences mean collapsed.
OSP.SettingsSections={ids={"language","shortcut","view_mode","behavior","navigation","effects_on_load","palette","background"}}
local S=OSP.SettingsSections
local root="savegame.mod.osp.settings.collapsed."
local function known(id)
    for _,value in ipairs(S.ids) do if id==value then return true end end
    return false
end
function S.expanded(id) return known(id) and GetString(root..id)=="0" end
function S.setExpanded(id,value)
    if not known(id) or type(value)~="boolean" then return false end
    SetString(root..id,value and "0" or "1");return true
end
function S.reset()
    for _,id in ipairs(S.ids) do S.setExpanded(id,false) end
end
