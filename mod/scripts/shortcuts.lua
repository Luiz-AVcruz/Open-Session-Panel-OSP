-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Bindings and capture are local preferences; gameplay authority stays on the server.
OSP.Shortcuts={actions={"god","fly","noclip"},capture=nil,message=nil}
local S=OSP.Shortcuts
local root="savegame.mod.osp."
local keys={}
for key in ("abcdefghijklmnopqrstuvwxyz0123456789"):gmatch('.') do keys[#keys+1]=key end
for i=1,12 do keys[#keys+1]="f"..i end
for _,key in ipairs({"insert","home","end","delete","esc","tab","backspace","space","shift","ctrl","alt","return","uparrow","downarrow","leftarrow","rightarrow","pgup","pgdown"}) do keys[#keys+1]=key end
local function known(id) return id=="god" or id=="fly" or id=="noclip" end
function S.menuKey()
    local key=GetString(root.."menu_key");return OSP.validKey(key) and key or "p"
end
function S.raw(id) return known(id) and GetString(root.."shortcuts."..id) or "" end
function S.problem(id)
    local key=S.raw(id)
    if key=="" then return nil end
    if not OSP.validKey(key) then return "invalid_key" end
    if key==S.menuKey() then return "shortcut_conflict" end
    for _,other in ipairs(S.actions) do if id~=other and S.raw(other)==key then return "shortcut_conflict" end end
end
function S.binding(id) return not S.problem(id) and S.raw(id) or "" end
function S.assign(id,key)
    if id~="menu" and not known(id) then return false,"invalid_key" end
    if key=="" and known(id) then SetString(root.."shortcuts."..id,"");return true end
    if not OSP.validKey(key) then return false,"invalid_key" end
    if id~="menu" and key==S.menuKey() then return false,"shortcut_conflict" end
    for _,other in ipairs(S.actions) do if id~=other and S.raw(other)==key then return false,"shortcut_conflict" end end
    SetString(root..(id=="menu" and "menu_key" or "shortcuts."..id),key);return true
end
function S.cancel() S.capture=nil end
function S.begin(id)
    if id=="menu" or known(id) then S.capture=id;S.message=nil end
end
function S.reset()
    for _,id in ipairs(S.actions) do S.assign(id,"") end
    S.cancel();S.message=nil
end
function S.modified() return InputDown("shift") or InputDown("ctrl") or InputDown("alt") end
function S.pressedKey()
    local found
    for _,key in ipairs(keys) do
        if InputPressed(key) then if found then return "multiple" end;found=key end
    end
    if found then return found end
    local last=string.lower(InputLastPressedKey() or "")
    if last=="" or last=="lmb" or last=="rmb" or last=="mmb" then return nil end
    return last
end
function S.key()
    if not S.capture then return end
    local key=S.pressedKey()
    if InputPressed("esc") or key=="esc" then S.cancel();InputClear();return end
    if not key then return end
    local ok,reason
    if S.modified() or key=="multiple" then ok=false;reason="shortcut_single_key"
    else ok,reason=S.assign(S.capture,key) end
    S.message=ok and "shortcut_saved" or reason
    if ok then S.cancel() end
    InputClear()
end
function S.drawBinding(api,id,x,y,width,caption)
    if not known(id) then return end
    local keyX=x+width*.40;local clearX=x+width*.80
    local active=S.capture==id;local raw=S.raw(id);local problem=S.problem(id)
    api.label(x,y+8,caption or OSP.L(id=="god" and "god_short" or id),17,width*.38)
    local caption=active and OSP.L("cancel") or raw~="" and string.upper(raw)..(problem and " !" or "") or OSP.L("shortcut_unset")
    if api.button("shortcut_"..id,keyX,y,width*.40-8,36,caption,active and "active" or "plain") then
        if active then S.cancel() else S.begin(id) end
    end
    if api.button("shortcut_clear_"..id,clearX,y,width*.20,36,OSP.L("shortcut_clear"),"plain",raw=="") then S.assign(id,"");S.cancel();S.message=nil end
    return problem
end
function S.draw(api,x,y,width)
    local top=y
    api.label(x,y,OSP.L("personal_shortcuts"),20,width);y=y+30
    api.label(x,y,OSP.L("shortcuts_help"),14,width);y=y+27
    local warning
    for _,id in ipairs(S.actions) do
        local problem=S.drawBinding(api,id,x,y,width)
        warning=warning or problem
        y=y+44
    end
    if api.button("shortcuts_reset",x,y,width,36,OSP.L("shortcuts_reset"),"plain") then S.reset() end
    y=y+46
    api.label(x,y,OSP.L("shortcuts_conflict_help"),13,width);y=y+25
    if S.capture then api.label(x,y,OSP.L("press_key"),15,width);y=y+25 end
    if warning or S.message then api.label(x,y,OSP.L(warning or S.message),14,width);y=y+25 end
    return y-top+12
end
