-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Local presentation preferences; hiding a tab never grants or revokes access.
OSP.Navigation={tabs={"players","session","tools","permissions","activity","appearance","settings","about","debug"}}
local N=OSP.Navigation
local root="savegame.mod.osp.navigation.hidden."
local behaviorRoot="savegame.mod.osp.navigation."
local function known(id)
    for _,tab in ipairs(N.tabs) do if tab==id then return true end end
    return false
end
function N.selectionMode()
    local value=GetString(behaviorRoot.."selection_mode")
    return (value=="close" or value=="leave") and value or "keep"
end
function N.setSelectionMode(value)
    if value~="keep" and value~="close" and value~="leave" then return false end
    SetString(behaviorRoot.."selection_mode",value);return true
end
function N.openingMode() return GetString(behaviorRoot.."opening_mode")=="players" and "players" or "last" end
function N.setOpeningMode(value)
    if value~="players" and value~="last" then return false end
    SetString(behaviorRoot.."opening_mode",value);return true
end
function N.lastTab()
    local value=GetString(behaviorRoot.."last_tab")
    return known(value) and value or "players"
end
function N.rememberTab(id)
    if not known(id) then return false end
    if GetString(behaviorRoot.."last_tab")~=id then SetString(behaviorRoot.."last_tab",id) end
    return true
end
function N.resetBehavior()
    N.setSelectionMode("keep");N.setOpeningMode("last")
    SetString(behaviorRoot.."last_tab","")
end
function N.visible(id)
    if id=="debug" then return GetString(root..id)=="0" end
    return known(id) and (id=="settings" or GetString(root..id)~="1")
end
function N.setVisible(id,visible)
    if not known(id) or id=="settings" or type(visible)~="boolean" then return false end
    SetString(root..id,visible and (id=="debug" and "0" or "") or "1");return true
end
function N.reset()
    for _,id in ipairs(N.tabs) do if id~="settings" then N.setVisible(id,id~="debug") end end
end
function N.list(eligible)
    local out={};for _,id in ipairs(N.tabs) do if N.visible(id) and (not eligible or eligible(id)) then out[#out+1]=id end end
    return out
end
function N.choose(wanted,accessible,eligible)
    if N.visible(wanted) and (not eligible or eligible(wanted)) and accessible(wanted) then return wanted end
    for _,id in ipairs(N.list(eligible)) do if accessible(id) then return id end end
    return "settings"
end
function N.draw(api,x,y,width,bodyOnly)
    local top=y
    if not bodyOnly then api.label(x,y,OSP.L("navigation_title"),20,width);y=y+32 end
    local cols=width>=460 and 2 or 1;local bw=(width-8*(cols-1))/cols;local i=0
    for _,id in ipairs(N.tabs) do
        if id~="settings" then
            local visible=N.visible(id)
            if api.button("navigation_"..id,x+(i%cols)*(bw+8),y+math.floor(i/cols)*44,bw,36,OSP.L(id).." · "..OSP.L(visible and "navigation_shown" or "navigation_hidden"),visible and "active" or "outlined") then N.setVisible(id,not visible) end
            i=i+1
        end
    end
    y=y+math.ceil(i/cols)*44
    api.label(x,y,OSP.L("navigation_settings_fixed"),15,width);y=y+30
    if api.button("navigation_restore",x,y,width,36,OSP.L("navigation_restore"),"plain") then N.reset() end
    return y+52-top
end
function N.drawBehavior(api,x,y,width,bodyOnly)
    local top=y
    if not bodyOnly then api.label(x,y,OSP.L("panel_behavior"),20,width);y=y+32 end
    api.label(x,y,OSP.L("behavior_selection"),16,width);y=y+28
    local cols=width>=600 and 3 or 1
    local bw=(width-8*(cols-1))/cols
    for i,value in ipairs({"keep","close","leave"}) do
        if api.button("behavior_selection_"..value,x+((i-1)%cols)*(bw+8),y+math.floor((i-1)/cols)*44,bw,36,
            OSP.L("behavior_selection_"..value),N.selectionMode()==value and "active" or "plain") then N.setSelectionMode(value) end
    end
    y=y+math.ceil(3/cols)*44
    api.label(x,y,OSP.L("behavior_selection_help"),13,width);y=y+36
    api.label(x,y,OSP.L("behavior_opening"),16,width);y=y+28
    cols=width>=420 and 2 or 1;bw=(width-8*(cols-1))/cols
    for i,value in ipairs({"last","players"}) do
        if api.button("behavior_opening_"..value,x+((i-1)%cols)*(bw+8),y+math.floor((i-1)/cols)*44,bw,36,
            OSP.L("behavior_opening_"..value),N.openingMode()==value and "active" or "plain") then N.setOpeningMode(value) end
    end
    y=y+math.ceil(2/cols)*44
    api.label(x,y,OSP.L("behavior_opening_help"),13,width)
    return y+36-top
end
