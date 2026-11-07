-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Local presentation preferences; hiding a tab never grants or revokes access.
OSP.Navigation={tabs={"players","session","tools","permissions","activity","settings","about"}}
local N=OSP.Navigation
local root="savegame.mod.osp.navigation.hidden."
local function known(id)
    for _,tab in ipairs(N.tabs) do if tab==id then return true end end
    return false
end
function N.visible(id)
    return known(id) and (id=="settings" or GetString(root..id)~="1")
end
function N.setVisible(id,visible)
    if not known(id) or id=="settings" or type(visible)~="boolean" then return false end
    SetString(root..id,visible and "" or "1");return true
end
function N.reset()
    for _,id in ipairs(N.tabs) do if id~="settings" then N.setVisible(id,true) end end
end
function N.list()
    local out={};for _,id in ipairs(N.tabs) do if N.visible(id) then out[#out+1]=id end end
    return out
end
function N.choose(wanted,accessible)
    if N.visible(wanted) and accessible(wanted) then return wanted end
    for _,id in ipairs(N.list()) do if accessible(id) then return id end end
    return "settings"
end
function N.draw(api,x,y,width)
    local top=y;api.label(x,y,OSP.L("navigation_title"),20,width);y=y+32
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
