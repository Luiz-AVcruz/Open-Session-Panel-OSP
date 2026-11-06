-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Host editor only; accepted changes still travel through the command/ACK path.
OSP.PermissionUI = {}
local UI = OSP.PermissionUI
local P = OSP.Permissions
local selected = "guest"
local draft = nil
local capturing = false
local view = "assign"
local previewPage, editorPage = 1, 1
local accepted = {}
local deleted = {}
local lastAPI = nil

local function resetScroll(api)
    if api and api.resetScroll then api.resetScroll() end
end

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
function UI.saved(role)
    if role then
        selected=role.id
        draft=OSP.copy(role)
        accepted[role.id]=OSP.copy(role)
        capturing=false
        view="assign"
        previewPage,editorPage=1,1
        resetScroll(lastAPI)
    end
end
function UI.deleted(id)
    if id then deleted[id]=true;accepted[id]=nil end
    selected="guest";draft=nil;capturing=false;view="assign";previewPage,editorPage=1,1
    resetScroll(lastAPI)
end

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
local function assign(api,T,roles,player,width)
    local y=78
    api.label(0,y,T("role_assignment_title"),20,width)
    y=y+36
    api.label(0,y,T("role_player_target")..": "..(player and player.name or "—"),17,width-120)
    if api.button("role_target_prev",width-108,y-4,48,32,"<","plain",not player or api.playerIndex()<=1) then api.playerStep(-1) end
    if api.button("role_target_next",width-54,y-4,48,32,">","plain",not player or api.playerIndex()>=api.playerCount()) then api.playerStep(1) end
    y=y+40

    local current=player and lookup(roles,player.role or (player.admin and "admin" or "guest"))
    api.label(0,y,T("role_current",player and player.host and T("host") or P.name(current or roles[1])),15,width)
    y=y+34
    local index=1
    for i,role in ipairs(roles) do if role.id==selected then index=i;break end end
    if api.button("role_select_prev",0,y,44,36,"<","plain",index<=1) then
        selected=roles[index-1].id;previewPage=1;resetScroll(api)
    end
    if api.button("role_select_next",width-44,y,44,36,">","plain",index>=#roles) then
        selected=roles[index+1].id;previewPage=1;resetScroll(api)
    end
    local role=lookup(roles,selected) or roles[1]
    api.label(56,y+8,P.name(role),18,width-112)
    y=y+48
    if api.button("role_apply",0,y,width,36,T("role_apply"),"active",
        not player or player.host or player.profileReady==false or (current and current.id==role.id)) then
        api.ask("role_assign",player.id,{id=role.id},T("confirm_role_assign",P.name(role),api.playerCaption()))
    end
    y=y+47

    api.label(0,y,T("role_custom_section"),18,width)
    y=y+32
    local half=(width-8)/2
    if api.button("role_create_custom",0,y,half,36,T("role_create_custom"),"plain",false) then
        local name=T("custom_role").." 1"
        local n=1
        while true do
            local found=false
            for _,candidate in ipairs(roles) do if P.name(candidate):lower()==name:lower() then found=true;break end end
            if not found then break end
            n=n+1;name=T("custom_role").." "..n
        end
        draft={id="",name=name,version=0,permissions=OSP.copy(role.permissions)}
        capturing=false;editorPage=1;view="edit";resetScroll(api)
    end
    if api.button("role_edit_custom",half+8,y,half,36,T("role_edit_custom"),"plain",role.builtin) then
        draft=OSP.copy(role);capturing=false;editorPage=1;view="edit";resetScroll(api)
    end
    y=y+48

    api.label(0,y,T("role_preview_title",P.name(role)),17,width)
    y=y+28
    local per=6
    local pages=math.max(1,math.ceil(#P.spec/per))
    previewPage=math.max(1,math.min(previewPage,pages))
    for i=1,per do
        local spec=P.spec[(previewPage-1)*per+i]
        if spec then
            local value=(role.permissions and role.permissions[spec.id]) or 0
            local scope=value==0 and "scope_off" or spec.target and value==1 and "scope_self" or spec.target and "scope_players" or "scope_on"
            api.label(0,y+7,T("permission_"..spec.id),17,width-180)
            api.label(width-175,y+7,T(scope),15,175)
            y=y+32
        end
    end
    if api.button("role_preview_prev",0,y,104,32,"< "..T("prev_short"),"plain",previewPage<=1) then previewPage=previewPage-1 end
    api.label(114,y+8,T("page_count",previewPage,pages),14,width-228)
    if api.button("role_preview_next",width-104,y,104,32,T("next_short").." >","plain",previewPage>=pages) then previewPage=previewPage+1 end
    return y+42
end

local function edit(api,T,role,width)
    local isNew=draft.id==""
    local y=78
    api.label(0,y,T(isNew and "role_editor_create_title" or "role_editor_edit_title"),20,width)
    y=y+30
    if isNew then
        api.label(0,y,T("role_editor_based_on",P.name(role)),14,width)
    else
        api.label(0,y,T("role_editor_save_effect"),14,width)
    end
    y=y+32
    api.label(0,y,T("role_name_label"),15,width)
    y=y+22
    local value=draft.name..(capturing and "_" or "")
    if api.button("role_editor_name",0,y,width,36,value,"plain",false) then capturing=not capturing end
    y=y+45
    api.label(0,y,T(changed(role) and "role_editor_unsaved" or "role_editor_scope_help"),14,width)
    y=y+30
    local per=6
    local pages=math.max(1,math.ceil(#P.spec/per))
    editorPage=math.max(1,math.min(editorPage,pages))
    for i=1,per do
        local spec=P.spec[(editorPage-1)*per+i]
        if spec then
            local value=draft.permissions[spec.id] or 0
            local scope=value==0 and "scope_off" or spec.target and value==1 and "scope_self" or spec.target and "scope_players" or "scope_on"
            api.label(0,y+7,T("permission_"..spec.id),17,width-180)
            if api.button("role_scope_"..spec.id,width-175,y,175,34,T(scope),value>0 and "active" or "plain",false) then
                draft.permissions[spec.id]=spec.target and (value+1)%3 or value==0 and 2 or 0
            end
            y=y+40
        end
    end
    if api.button("role_editor_prev",0,y,104,32,"< "..T("prev_short"),"plain",editorPage<=1) then editorPage=editorPage-1 end
    api.label(114,y+8,T("page_count",editorPage,pages),14,width-228)
    if api.button("role_editor_next",width-104,y,104,32,T("next_short").." >","plain",editorPage>=pages) then editorPage=editorPage+1 end
    y=y+42
    local half=(width-8)/2
    if api.button("role_editor_discard",0,y,half,36,T("role_editor_discard"),"plain",false) then
        capturing=false;draft=nil;view="assign";editorPage=1;resetScroll(api)
        return 0
    end
    if api.button("role_editor_save",half+8,y,half,36,T("role_editor_save"),"active",not P.validName(draft.name)) then
        api.command("role_save",0,OSP.copy(draft));capturing=false
    end
    y=y+44
    if not isNew then
        if api.button("role_editor_reload",0,y,width,34,T("role_editor_reload"),"plain",not changed(role)) then
            draft=OSP.copy(role);capturing=false;editorPage=1;resetScroll(api)
            return y+34
        end
        y=y+40
    end
    if not isNew and api.button("role_editor_delete",0,y,width,36,T("role_editor_delete"),"danger",false) then
        api.ask("role_delete",0,{id=role.id,version=role.version},T("confirm_role_delete",P.name(role)))
        capturing=false
    end
    y=y+48
    return y+api.paragraph(0,y,T("permission_host_reserved"),14,width)+18
end

function UI.draw(api,roles,player,width)
    local T=OSP.L
    lastAPI=api
    roles=OSP.copy(roles or P.list({}))
    for id in pairs(deleted) do
        local found=false
        for i=#roles,1,-1 do if roles[i].id==id then table.remove(roles,i);found=true end end
        if not found then deleted[id]=nil end
    end
    for id,role in pairs(accepted) do
        local current=lookup(roles,id)
        if current and current.version>=role.version then accepted[id]=nil
        else
            for i=#roles,1,-1 do if roles[i].id==id then table.remove(roles,i) end end
            roles[#roles+1]=OSP.copy(role)
        end
    end
    local role=lookup(roles,selected) or roles[1]
    if not lookup(roles,selected) then selected=role.id;draft=nil;view="assign" end
    if view=="edit" and role.builtin and draft and draft.id~="" then view="assign";draft=nil;capturing=false end
    if view=="edit" and not draft then view="assign" end
    if view=="edit" then return edit(api,T,role,width) end
    return assign(api,T,roles,player,width)
end
