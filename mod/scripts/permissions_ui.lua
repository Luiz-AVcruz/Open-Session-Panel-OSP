-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Host editor only; accepted changes still travel through the command/ACK path.
OSP.PermissionUI = {}
local UI = OSP.PermissionUI
local P = OSP.Permissions
local selected = "guest"
local draft = nil
local capturingName = false
local view = "assign"
local expanded = false
local expandedScroll = 0
local expandedContentHeight = 0
local accepted = {}
local deleted = {}
local lastAPI = nil
local search = OSP.SearchInput.new()
local groupExpanded = {}
local groupRoot="savegame.mod.osp_beta.permissions.expanded."
for _,category in ipairs(P.categories or {}) do
    groupExpanded[category.id]=type(GetString)=="function" and GetString(groupRoot..category.id)=="1" or false
end

local function resetScroll(api)
    if api and api.resetScroll then api.resetScroll() end
end

local function isPending(api)
    return api and api.pending and api.pending() or false
end

local function can(api,action,target,arg)
    if not api or type(api.can)~="function" then return true end
    return api.can(action,target or 0,arg)==true
end

local function canSaveRole(api,role)
    return can(api,"role_save",0,role)
end

local function copyDraft(role)
    local value=OSP.copy(role)
    value.permissions=value.permissions or {}
    for _,spec in ipairs(P.spec) do
        if value.permissions[spec.id]==nil then value.permissions[spec.id]=0 end
    end
    return value
end

function UI.cancelInput()
    capturingName=false
    search.blur()
end

function UI.capturing()
    return capturingName or search.focused
end

function UI.key()
    if search.focused then
        if search.key() then expandedScroll=0 end
        return
    end
    if not capturingName or not draft then return end
    local key=string.lower(InputLastPressedKey() or "")
    if key=="" or key=="lmb" or key=="rmb" or key=="mmb" then return end
    if key=="esc" or key=="return" or key=="enter" then capturingName=false
    elseif key=="backspace" then draft.name=draft.name:sub(1,-2)
    else
        if key=="space" then key=" " end
        if #key==1 and key:match("^[ -~]$") and #draft.name<40 then draft.name=draft.name..key end
    end
    InputClear()
end

function UI.isExpanded() return expanded end

function UI.openExpanded()
    capturingName=false
    search.blur()
    expanded=true
    expandedScroll=0
    expandedContentHeight=0
    resetScroll(lastAPI)
end

function UI.focusPlayerRole(id)
    if view~="assign" or type(id)~="string" or id=="" then return end
    selected=id
    draft=nil
    capturingName=false
    search.blur()
    expandedContentHeight=0
    expandedScroll=0
    resetScroll(lastAPI)
end

function UI.closeExpanded()
    expanded=false
    UI.cancelInput()
end

function UI.getState()
    return {
        query=search.query,view=view,draft=OSP.copy(draft),selected=selected,
        expanded=expanded,groups=OSP.copy(groupExpanded),searchFocused=search.focused,
        nameFocused=capturingName,scroll=expandedScroll,
    }
end

function UI.saved(role)
    if role then
        selected=role.id
        draft=copyDraft(role)
        accepted[role.id]=OSP.copy(role)
        capturingName=false
        search.blur()
        view="assign"
        expanded=false
        expandedScroll=0
        expandedContentHeight=0
        resetScroll(lastAPI)
    end
end

function UI.deleted(id)
    if id then deleted[id]=true;accepted[id]=nil end
    selected="guest";draft=nil;capturingName=false;search.blur();view="assign";expanded=false
    expandedScroll=0;expandedContentHeight=0
    resetScroll(lastAPI)
end

local function lookup(roles,id)
    for _,role in ipairs(roles) do if role.id==id then return role end end
end

local function changed(role)
    if not draft then return false end
    if draft.id~=role.id or draft.name~=role.name or draft.version~=role.version then return true end
    local draftPermissions=draft.permissions or {}
    local rolePermissions=role.permissions or {}
    for _,spec in ipairs(P.spec) do
        if (draftPermissions[spec.id] or 0)~=(rolePermissions[spec.id] or 0) then return true end
    end
    return false
end

local function prepareRoles(roles)
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
    if not role then
        roles=P.list({})
        role=roles[1]
    end
    if not lookup(roles,selected) then
        selected=role.id;draft=nil;view="assign";capturingName=false
    end
    if view=="edit" and role.builtin and draft and draft.id~="" then
        view="assign";draft=nil;capturingName=false
    end
    if view=="edit" and not draft then view="assign" end
    return roles,role
end

local function scopeString(value)
    if value==0 then return "permission_scope_off" end
    if value==1 then return "permission_scope_self" end
    return "permission_scope_any"
end

local function canSetScope(api,spec,value)
    if not draft then return false end
    local proposed=OSP.copy(draft)
    proposed.permissions[spec.id]=value
    return canSaveRole(api,proposed)
end

local function drawScopeRow(api,T,spec,value,width,y,editing,pending)
    local title=T("permission_"..spec.id)
    local narrow=width<620
    local scopeValues=spec.target and {0,1,2} or {0,2}
    if narrow then
        api.label(0,y,title,16,width)
        if editing then
            local by=y+25;local gap=4;local buttonWidth=(width-gap*(#scopeValues-1))/#scopeValues
            for i,scope in ipairs(scopeValues) do
                local x=(i-1)*(buttonWidth+gap)
                if api.button("role_scope_"..spec.id.."_"..scope,x,by,buttonWidth,32,
                    T(scope==0 and "permission_scope_off" or scope==1 and "permission_scope_self" or spec.target and "permission_scope_any" or "permission_scope_on"),
                    value==scope and "active" or "outlined",pending or not canSetScope(api,spec,scope)) then
                    draft.permissions[spec.id]=scope;search.blur();capturingName=false
                end
            end
            return 63
        end
        local scopeKey=value==0 and "permission_scope_off" or value==1 and "permission_scope_self"
            or spec.target and "permission_scope_any" or "permission_scope_on"
        api.label(0,y+23,T(scopeKey),14,width)
        return 44
    end

    if editing then
        local controlWidth=spec.target and math.min(336,math.max(240,width-260)) or math.min(230,math.max(164,width-300))
        local labelWidth=math.max(140,width-controlWidth-12)
        api.label(0,y+8,title,16,labelWidth)
        local gap=4;local buttonWidth=(controlWidth-gap*(#scopeValues-1))/#scopeValues
        for i,scope in ipairs(scopeValues) do
            local x=labelWidth+12+(i-1)*(buttonWidth+gap)
            local key=scope==0 and "permission_scope_off" or scope==1 and "permission_scope_self"
                or spec.target and "permission_scope_any" or "permission_scope_on"
            if api.button("role_scope_"..spec.id.."_"..scope,x,y,buttonWidth,34,T(key),
                value==scope and "active" or "outlined",pending or not canSetScope(api,spec,scope)) then
                draft.permissions[spec.id]=scope;search.blur();capturingName=false
            end
        end
        return 42
    end

    local scopeKey=value==0 and "permission_scope_off" or value==1 and "permission_scope_self"
        or spec.target and "permission_scope_any" or "permission_scope_on"
    api.label(0,y+7,title,16,width-190)
    api.label(width-184,y+7,T(scopeKey),14,184)
    return 34
end

local function matchingGroups(T)
    local groups={}
    for _,category in ipairs(P.categories or {}) do
        local specs={}
        for _,spec in ipairs(P.spec) do
            if spec.category==category.id then specs[#specs+1]=spec end
        end
        local matched={}
        local categoryMatches=search.matches(T("permission_category_"..category.id),category.id)
        for _,spec in ipairs(specs) do
            if categoryMatches or search.matches(T("permission_"..spec.id),spec.id) then
                matched[#matched+1]=spec
            end
        end
        if #matched>0 then
            groups[#groups+1]={category=category,specs=specs,matched=matched}
        end
    end
    return groups
end

local function drawPermissionGroups(api,T,role,width,editing,pending,top)
    local startY=top or 0
    local y=startY
    local groups=matchingGroups(T)
    if #groups==0 then
        api.label(0,y,T("permission_search_empty"),15,width)
        return 28
    end
    for _,group in ipairs(groups) do
        local id=group.category.id
        local countText=tostring(#group.matched)
        if search.query~="" then countText=countText.."/"..#group.specs end
        local headerText=T("permission_category_"..id).." ("..countText..")"
        if api.button("permission_group_"..id,0,y,width,36,"","outlined",false) then
            groupExpanded[id]=not groupExpanded[id]
            if type(SetString)=="function" then SetString(groupRoot..id,groupExpanded[id] and "1" or "0") end
            search.blur();capturingName=false
        end
        if api.image then
            api.image(8,y+10,groupExpanded[id] and "MOD/ui/section-down.png" or "MOD/ui/section-right.png")
        end
        api.label(32,y+8,headerText,16,width-40)
        y=y+42
        if groupExpanded[id] then
            local descriptionHeight=api.paragraph(0,y,T("permission_category_"..id.."_help"),14,width)
            y=y+(descriptionHeight or 18)+4
            for _,spec in ipairs(group.matched) do
                local value=role.permissions and role.permissions[spec.id] or 0
                y=y+drawScopeRow(api,T,spec,value,width,y,editing,pending)
                y=y+3
            end
            y=y+5
        end
    end
    return y-startY
end

local function drawSearch(api,T,x,y,width,reserveRight)
    local available=math.max(120,width-(reserveRight or 0))
    local inputWidth=math.max(60,available-48)
    local clearX=x+available-40
    local shown=search.query
    if shown=="" then shown=T("permission_search") end
    if search.focused then shown=shown.."_" end
    if api.button("permission_view_search",x,y,inputWidth,34,shown,search.focused and "active" or "plain",false) then
        capturingName=false;search.focused=true
    end
    if api.button("permission_view_search_clear",clearX,y,40,34,"X","plain",search.query=="") then
        search.clear();capturingName=false;search.blur();expandedScroll=0
    end
    return y+43
end

local function selectRole(roles,id,api)
    if view~="assign" then return end
    local role=lookup(roles,id)
    if role then
        selected=role.id;draft=nil;capturingName=false;search.blur();expandedContentHeight=0;expandedScroll=0
        resetScroll(api)
    end
end

local function enterExistingEdit(role,api)
    if role and not role.builtin then
        draft=copyDraft(role);capturingName=false;search.blur();view="edit"
        expandedContentHeight=0;expandedScroll=0;resetScroll(api)
    end
end

local function nextCustomName(T,roles)
    local name=T("custom_role").." 1"
    local n=1
    while true do
        local found=false
        for _,candidate in ipairs(roles) do
            if P.name(candidate):lower()==name:lower() then found=true;break end
        end
        if not found then break end
        n=n+1;name=T("custom_role").." "..n
    end
    return name
end

local function newRoleDraft(T,roles,role)
    local value=copyDraft(role)
    value.id="";value.name=nextCustomName(T,roles);value.version=0
    return value
end

local function createRole(api,T,roles,role)
    draft=newRoleDraft(T,roles,role)
    capturingName=false;search.blur();view="edit";expandedContentHeight=0;expandedScroll=0
    resetScroll(api)
end

local function drawCompactHeading(api,T,width,titleKey)
    local y=78
    api.label(0,y,titleKey and T(titleKey) or T("role_assignment_title"),20,width)
    return y+43
end

local function drawPlayerSelector(api,T,player,width,y)
    local targetName=player and player.name or "—"
    api.label(0,y,T("role_player_target")..": "..targetName,16,width-120)
    if api.button("role_target_prev",width-108,y-4,48,32,"<","plain",not player or api.playerIndex()<=1) then api.playerStep(-1) end
    if api.button("role_target_next",width-54,y-4,48,32,">","plain",not player or api.playerIndex()>=api.playerCount()) then api.playerStep(1) end
    return y+38
end

local function drawRoleDropdown(api,T,roles,width,y)
    local items={}
    for _,candidate in ipairs(roles) do
        items[#items+1]={id=candidate.id,label=P.name(candidate)}
    end
    api.label(0,y,T("role_select_label"),15,width)
    api.dropdown("permission_view_role_select",0,y+20,width,36,items,selected,false,function(id)
        selectRole(roles,id,api)
    end)
    return y+62
end

local function drawRoleActions(api,T,roles,role,width,y)
    local proposal=newRoleDraft(T,roles,role)
    local createDisabled=isPending(api) or not can(api,"role_create",0,proposal) or not canSaveRole(api,proposal)
    local editDisabled=role.builtin or isPending(api) or not canSaveRole(api,role)
    local deleteDisabled=role.builtin or isPending(api) or not can(api,"role_delete",0,{id=role.id,version=role.version})
    local createLabel=T(width<760 and "role_copy_short" or "role_create_custom")
    local editLabel=T(width<760 and "role_edit_short" or "role_edit_custom")
    local deleteLabel=T(width<760 and "role_delete_short" or "role_editor_delete")
    local function drawCreate(x,w,buttonY)
        if api.button("role_create_custom",x,buttonY,w,36,createLabel,"plain",createDisabled) then createRole(api,T,roles,role) end
    end
    local function drawEdit(x,w,buttonY)
        if api.button("role_edit_custom",x,buttonY,w,36,editLabel,"plain",editDisabled) then enterExistingEdit(role,api) end
    end
    local function drawDelete(x,w,buttonY)
        if api.button("role_delete",x,buttonY,w,36,deleteLabel,"danger",deleteDisabled) then
            search.blur();capturingName=false
            api.ask("role_delete",0,{id=role.id,version=role.version},T("confirm_role_delete",P.name(role)))
        end
    end
    if width<340 then
        local half=(width-4)/2
        drawCreate(0,width,y)
        drawEdit(0,half,y+40)
        drawDelete(half+4,half,y+40)
        return y+82
    end
    local gap=4
    local buttonWidth=(width-gap*2)/3
    drawCreate(0,buttonWidth,y)
    drawEdit(buttonWidth+gap,buttonWidth,y)
    drawDelete((buttonWidth+gap)*2,buttonWidth,y)
    return y+42
end

local function currentRole(roles,player)
    if not player then return nil end
    return lookup(roles,player.role or (player.admin and "admin" or "guest"))
end

local function drawPlayerCurrent(api,T,roles,player,width,y)
    local current=currentRole(roles,player)
    api.label(0,y,T("role_current",player and player.host and T("host") or P.name(current or roles[1])),15,width)
    return current,y+30
end

local function drawRoleAssignment(api,T,player,current,role,width,y)
    if api.button("role_apply",0,y,width,36,T("role_apply"),"active",
        isPending(api) or not player or player.host or player.profileReady==false or (current and current.id==role.id)
            or not can(api,"role_assign",player and player.id,{id=role.id})) then
        search.blur();capturingName=false
        api.ask("role_assign",player.id,{id=role.id},T("confirm_role_assign",P.name(role),api.playerCaption()))
    end
    return y+42
end

local function drawAssignmentSelection(api,T,roles,player,width,y)
    y=drawPlayerSelector(api,T,player,width,y)
    local current
    current,y=drawPlayerCurrent(api,T,roles,player,width,y)
    y=drawRoleDropdown(api,T,roles,width,y)
    local role=lookup(roles,selected) or roles[1]
    return role,y,current
end

local function drawAssignmentManagement(api,T,roles,player,width,y,includeApply)
    local current
    local role
    role,y,current=drawAssignmentSelection(api,T,roles,player,width,y)
    if includeApply then y=drawRoleAssignment(api,T,player,current,role,width,y) end
    api.label(0,y,T("role_custom_section"),18,width)
    y=y+29
    y=drawRoleActions(api,T,roles,role,width,y)
    return role,y
end

local function drawAssignment(api,T,roles,player,width,role)
    local y=drawCompactHeading(api,T,width,"role_assignment_title")
    role,y=drawAssignmentManagement(api,T,roles,player,width,y,true)
    if role.builtin then
        api.label(0,y,T("permission_builtin_readonly"),14,width)
        y=y+20
    end
    api.label(0,y,T("role_preview_title",P.name(role)),17,width)
    y=y+27
    y=drawSearch(api,T,0,y,width)
    y=y+drawPermissionGroups(api,T,role,width,false,isPending(api),y)
    return y+8
end

local function discardDraft(api)
    draft=nil;capturingName=false;search.blur();view="assign";expandedContentHeight=0
    resetScroll(api)
end

local function drawEditActions(api,T,role,width,y,fixedY)
    local isNew=draft.id==""
    local waiting=isPending(api)
    local baseY=fixedY or y
    local half=(width-8)/2
    if api.button("role_editor_discard",0,baseY,half,36,T("role_editor_discard"),"plain",waiting) then
        discardDraft(api)
        return true
    end
    if api.button("role_editor_save",half+8,baseY,half,36,T("role_editor_save"),"active",
        waiting or not P.validName(draft.name) or not canSaveRole(api,draft)) then
        capturingName=false;search.blur()
        api.command("role_save",0,OSP.copy(draft))
    end
    if not fixedY then y=baseY+43 end
    if not isNew then
        local reloadY=fixedY and fixedY+42 or y
        if api.button("role_editor_reload",0,reloadY,half,36,T("role_editor_reload"),"plain",
            waiting or not canSaveRole(api,role) or not changed(role)) then
            draft=copyDraft(role);capturingName=false;search.blur();expandedContentHeight=0
            resetScroll(api)
        end
        if api.button("role_editor_delete",half+8,reloadY,half,36,T("role_editor_delete"),"danger",
            waiting or not can(api,"role_delete",0,{id=role.id,version=role.version})) then
            capturingName=false;search.blur()
            api.ask("role_delete",0,{id=role.id,version=role.version},T("confirm_role_delete",P.name(role)))
        end
        if not fixedY then y=reloadY+42 end
    end
    if fixedY then return false end
    local helpHeight=api.paragraph(0,y,T("permission_host_reserved"),14,width)
    return y+(helpHeight or 18)+16
end

local function drawCompactEditor(api,T,width,role)
    local y=drawCompactHeading(api,T,width,draft.id=="" and "role_editor_create_title" or "role_editor_edit_title")
    if draft.id=="" then api.label(0,y,T("role_editor_based_on",P.name(role)),14,width)
    else api.label(0,y,T("role_editor_save_effect"),14,width) end
    y=y+24
    api.label(0,y,T("role_name_label"),15,width)
    y=y+20
    local waiting=isPending(api)
    if waiting then capturingName=false end
    local shown=draft.name..(capturingName and "_" or "")
    if api.button("role_editor_name",0,y,width,36,shown,capturingName and "active" or "plain",
        waiting or not canSaveRole(api,draft)) then
        search.blur();capturingName=true
    end
    y=y+43
    api.label(0,y,T(changed(role) and "role_editor_unsaved" or "role_editor_scope_help"),14,width)
    y=y+24
    y=drawSearch(api,T,0,y,width)
    y=y+drawPermissionGroups(api,T,draft,width,true,waiting,y)
    local bottom=drawEditActions(api,T,role,width,y)
    if bottom==true then return 0 end
    return bottom
end

local function drawExpandedEditorIdentity(api,T,role,width,y)
    api.label(0,y,T(draft.id=="" and "role_editor_create_title" or "role_editor_edit_title"),18,width)
    y=y+25
    api.label(0,y,draft.id=="" and T("role_editor_based_on",P.name(role)) or T("role_editor_save_effect"),13,width)
    y=y+21
    api.label(0,y,T("role_name_label"),14,width)
    y=y+20
    local waiting=isPending(api)
    if waiting then capturingName=false end
    local shown=draft.name..(capturingName and "_" or "")
    if api.button("role_editor_name",0,y,width,34,shown,capturingName and "active" or "plain",
        waiting or not canSaveRole(api,draft)) then
        search.blur();capturingName=true
    end
    y=y+40
    api.label(0,y,T(changed(role) and "role_editor_unsaved" or "role_editor_scope_help"),13,width)
    return y+23
end

local function drawExpandedViewport(api,x,y,width,bottom,drawBody)
    local listHeight=math.max(0,bottom-y)
    if listHeight<=0 then return end
    if api.wheel then
        local delta=api.wheel(x,y,width,listHeight) or 0
        if delta~=0 then expandedScroll=expandedScroll-delta*48 end
    end
    expandedScroll=math.max(0,math.min(expandedScroll,math.max(0,expandedContentHeight-listHeight)))
    local bodyHeight=0
    local function drawContent() bodyHeight=drawBody();return bodyHeight end
    if api.viewport then
        local heightFromViewport=api.viewport(x,y,width,listHeight,expandedScroll,drawContent)
        if type(heightFromViewport)=="number" then bodyHeight=heightFromViewport end
    else
        bodyHeight=drawContent()
    end
    expandedContentHeight=bodyHeight
    expandedScroll=math.max(0,math.min(expandedScroll,math.max(0,expandedContentHeight-listHeight)))
end

local function drawExpandedPermissionList(api,T,role,x,y,width,bottom,editing)
    local contentRole=editing and draft or role
    api.label(x,y,T("role_preview_title",P.name(contentRole)),17,width)
    y=y+25
    if not editing and contentRole.builtin then
        api.label(x,y,T("permission_builtin_readonly"),13,width)
        y=y+20
    end
    drawExpandedViewport(api,x,y,width,bottom,function()
        return drawPermissionGroups(api,T,contentRole,width,editing,isPending(api))
    end)
end

local function drawExpandedWide(api,T,roles,player,role,width,height,top)
    local gap=16
    local managerWidth=math.min(360,math.max(300,math.floor(width*0.34)))
    local listX=managerWidth+gap
    local listWidth=math.max(0,width-listX)
    if view=="edit" and draft then
        local y=drawExpandedEditorIdentity(api,T,role,managerWidth,top)
        if drawEditActions(api,T,role,managerWidth,y,y) then return end
        drawExpandedPermissionList(api,T,role,listX,top,listWidth,height,true)
        return
    end
    role=lookup(roles,selected) or role
    drawAssignmentManagement(api,T,roles,player,managerWidth,top,true)
    role=lookup(roles,selected) or role
    drawExpandedPermissionList(api,T,role,listX,top,listWidth,height,false)
end

local function drawExpandedNarrow(api,T,roles,player,role,width,height,top)
    if view=="edit" and draft then
        local y=drawExpandedEditorIdentity(api,T,role,width,top)
        if drawEditActions(api,T,role,width,y,y) then return end
        y=y+42+(draft.id=="" and 0 or 42)
        drawExpandedPermissionList(api,T,role,0,y,width,height,true)
        return
    end
    role=lookup(roles,selected) or role
    local footerHeight=42
    local applyY=height-footerHeight+3
    local function drawManagementAndPermissions()
        local selectedRole,y=drawAssignmentManagement(api,T,roles,player,width,0,false)
        api.label(0,y,T("role_preview_title",P.name(selectedRole)),17,width)
        y=y+25
        if selectedRole.builtin then
            api.label(0,y,T("permission_builtin_readonly"),13,width)
            y=y+20
        end
        return y+drawPermissionGroups(api,T,selectedRole,width,false,isPending(api),y)
    end
    drawExpandedViewport(api,0,top,width,math.max(top,applyY),drawManagementAndPermissions)
    role=lookup(roles,selected) or role
    drawRoleAssignment(api,T,player,currentRole(roles,player),role,width,applyY)
end

local function drawExpanded(api,T,roles,player,role,width,height)
    local waiting=isPending(api)
    if waiting and capturingName then capturingName=false end
    local top=drawSearch(api,T,0,0,width,60)+4
    if width>=760 then drawExpandedWide(api,T,roles,player,role,width,height,top)
    else drawExpandedNarrow(api,T,roles,player,role,width,height,top) end
end

function UI.draw(api,roles,player,width)
    local T=OSP.L
    lastAPI=api
    if expanded then return 0 end
    local role
    roles,role=prepareRoles(roles)
    if view=="edit" then return drawCompactEditor(api,T,width,role) end
    return drawAssignment(api,T,roles,player,width,role)
end

function UI.drawExpanded(api,roles,player,width,height)
    local T=OSP.L
    lastAPI=api
    local role
    roles,role=prepareRoles(roles)
    if view=="edit" and not draft then view="assign" end
    drawExpanded(api,T,roles,player,role,width,height)
end
