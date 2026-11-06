-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Host editor only; accepted changes still travel through the command/ACK path.
OSP.PermissionUI = {}
local UI = OSP.PermissionUI
local P = OSP.Permissions
local selected = "guest"
local draft = nil
local capturing = false
local page = 1
local accepted = {}
local deleted = {}
function UI.cancelInput() capturing=false end
function UI.capturing() return capturing end
function UI.key()
    local key=string.lower(InputLastPressedKey() or "")
    if key=="" or key=="lmb" or key=="rmb" or key=="mmb" then return end
    if key=="esc" or key=="return" or key=="enter" then capturing=false
    elseif key=="backspace" then draft.name=draft.name:sub(1,-2)
    else
        if key=="space" then key=" " end
        if #key==1 and key:match("^[ -~]$") and #draft.name<40 then draft.name=draft.name..key end
    end
    InputClear()
end
function UI.saved(template)
    if template then selected=template.id;draft=OSP.copy(template);accepted[template.id]=OSP.copy(template);capturing=false end
end
function UI.deleted(id) if id then deleted[id]=true;accepted[id]=nil end;selected="guest";draft=nil;capturing=false end
local function lookup(roles,id)
    for _,role in ipairs(roles) do if role.id==id then return role end end
end
local function changed(role)
    if not draft then return false end
    if draft.id~=role.id or draft.name~=role.name or draft.version~=role.version then return true end
    for _,spec in ipairs(P.spec) do
        if draft.permissions[spec.id]~=role.permissions[spec.id] then return true end
    end
    return false
end
function UI.draw(api,roles,player,width)
    local T=OSP.L
    roles=OSP.copy(roles or P.list({}))
    for id in pairs(deleted) do
        local found=false
        for i=#roles,1,-1 do if roles[i].id==id then table.remove(roles,i);found=true end end
        if not found then deleted[id]=nil end
    end
    for id,template in pairs(accepted) do
        local current=lookup(roles,id)
        if current and current.version>=template.version then accepted[id]=nil
        else
            for i=#roles,1,-1 do if roles[i].id==id then table.remove(roles,i) end end
            roles[#roles+1]=OSP.copy(template)
        end
    end
    local role=lookup(roles,selected) or roles[1]
    if not lookup(roles,selected) then selected=role.id;draft=nil end
    local index=1
    for i,r in ipairs(roles) do if r.id==selected then index=i end end
    local y=78
    api.label(0,y,T("permission_target")..": "..(player and player.name or "—"),17,width-120)
    if api.button("permission_player_prev",width-108,y-4,48,32,"<","plain",not player or api.playerIndex()<=1) then api.playerStep(-1) end
    if api.button("permission_player_next",width-54,y-4,48,32,">","plain",not player or api.playerIndex()>=api.playerCount()) then api.playerStep(1) end
    y=y+36
    local current=player and lookup(roles,player.role or (player.admin and "admin" or "guest"))
    api.label(0,y,T("assigned_role",player and player.host and T("host") or P.name(current or roles[1])),15,width)
    y=y+34
    if api.button("permission_prev",0,y,44,36,"<","plain",index<=1) then selected=roles[index-1].id;draft=nil;capturing=false;page=1 end
    if api.button("permission_next",width-44,y,44,36,">","plain",index>=#roles) then selected=roles[index+1].id;draft=nil;capturing=false;page=1 end
    role=lookup(roles,selected) or roles[1]
    api.label(56,y+8,P.name(role),18,width-112)
    y=y+48
    if api.button("permission_apply",0,y,width,36,T("apply_role"),"active",not player or player.host or player.profileReady==false or changed(role)) then
        api.ask("role_assign",player.id,{id=role.id},T("confirm_role_assign",P.name(role),api.playerCaption()))
    end
    y=y+48
    local half=(width-8)/2
    if api.button("permission_copy",0,y,half,36,T("copy_role"),"plain",false) then
        local name=T("custom_template").." 1"
        local n=1
        while true do
            local found=false
            for _,r in ipairs(roles) do if P.name(r):lower()==name:lower() then found=true end end
            if not found then break end
            n=n+1;name=T("custom_template").." "..n
        end
        draft={id="",name=name,version=0,permissions=OSP.copy(role.permissions)}
        capturing=false
    end
    if api.button("permission_reload",half+8,y,half,36,T("reload_role"),"plain",false) then draft=nil;capturing=false end
    y=y+48
    local editable=not role.builtin
    if not draft then draft=OSP.copy(role) end
    if draft.id=="" then editable=true end
    if api.button("permission_name",0,y,width,36,editable and (draft.name..(capturing and "_" or "")) or T("builtin_role"),"plain",not editable) then capturing=not capturing end
    y=y+46
    api.label(0,y,T(changed(role) and "save_before_apply" or "permission_scope_help"),14,width)
    y=y+32
    local per=6
    local last=math.max(1,math.ceil(#P.spec/per));page=math.max(1,math.min(page,last))
    for i=1,per do
        local spec=P.spec[(page-1)*per+i]
        if spec then
            local value=draft.permissions[spec.id] or 0
            local key=value==0 and "scope_off" or spec.target and value==1 and "scope_self" or spec.target and "scope_players" or "scope_on"
            api.label(0,y+8,T("permission_"..spec.id),17,width-185)
            if api.button("permission_cap_"..spec.id,width-175,y,175,34,T(key),value>0 and "active" or "plain",not editable) then
                draft.permissions[spec.id]=spec.target and (value+1)%3 or value==0 and 2 or 0
            end
            y=y+42
        end
    end
    if api.button("permission_page_prev",0,y,105,32,"< "..T("prev_short"),"plain",page<=1) then page=page-1 end
    api.label(115,y+8,T("page_count",page,last),14,width-235)
    if api.button("permission_page_next",width-105,y,105,32,T("next_short").." >","plain",page>=last) then page=page+1 end
    y=y+44
    if api.button("permission_save",0,y,half,36,T("save_role"),"active",not editable or not P.validName(draft.name)) then
        api.command("role_save",0,OSP.copy(draft));capturing=false
    end
    if api.button("permission_delete",half+8,y,half,36,T("delete_role"),"danger",role.builtin or draft.id=="") then
        api.ask("role_delete",0,{id=role.id,version=role.version},T("confirm_role_delete",P.name(role)))
    end
    y=y+52
    return y+api.paragraph(0,y,T("permission_host_reserved"),14,width)+20
end
