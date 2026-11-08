-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Direct UI contract checks; this mock does not render Teardown's native UI.
local assertions=0
local function check(value,message)
    assert(value,message)
    assertions=assertions+1
end
local function eq(actual,expected,message)
    check(actual==expected,(message or "equality")..": "..tostring(actual).." ~= "..tostring(expected))
end
local function copy(value)
    if type(value)~="table" then return value end
    local result={}
    for key,item in pairs(value) do result[copy(key)]=copy(item) end
    return result
end

local strings={
    role_guest="Guest",role_self="Self",role_helper="Helper",role_moderator="Moderator",role_admin="Admin",
    custom_role="Custom role",role_assignment_title="Assign access",role_player_target="Selected player",
    role_current="Current role: %s",host="Host",role_apply="Apply role",role_custom_section="Custom roles",
    role_create_custom="Create",role_edit_custom="Edit",role_preview_title="Permissions: %s",
    role_copy_short="Copy",role_edit_short="Edit",role_delete_short="Delete",
    role_editor_create_title="Create role",role_editor_edit_title="Edit role",role_editor_based_on="Based on %s",
    role_editor_save_effect="Changes take effect after save.",role_name_label="Role name",
    role_editor_unsaved="Unsaved changes",role_editor_scope_help="Choose the access for each permission.",
    role_editor_discard="Discard",role_editor_save="Save",role_editor_reload="Reload",role_editor_delete="Delete",
    confirm_role_assign="Assign %s to %s?",confirm_role_delete="Delete %s?",permission_host_reserved="Host access is reserved.",
    permission_view_expand="Expand",permission_search="Search permissions by name, ID or category",role_select_label="Role",
    permission_search_empty="No matching permissions.",permission_builtin_readonly="Built-in role is read-only.",
    permission_scope_off="Off",permission_scope_self="Self",permission_scope_any="Any",permission_scope_on="On",
    permission_category_players="Players",permission_category_players_help="Health and player control.",
    permission_category_movement="Movement",permission_category_movement_help="Teleport, flight and speed.",
    permission_category_abilities="Abilities",permission_category_abilities_help="Player abilities.",
    permission_category_tools="Tools and ammo",permission_category_tools_help="Tool access and ammunition.",
    permission_category_session="Session",permission_category_session_help="Announcements and shared rules.",
    permission_heal="Heal",permission_respawn="Respawn",permission_goto="Go to player",permission_bring="Bring player",
    permission_kill="Kill",permission_eject="Exit vehicle",permission_god="Invincibility",permission_fly="Fly",
    permission_noclip="Noclip",permission_freeze="Freeze",permission_speed="Speed",permission_strength="Strength",
    permission_tools="Tool use",permission_ammo="Infinite ammo",permission_heal_all="Heal everyone",
    permission_bring_all="Bring everyone",permission_tools_all="Bulk tool changes",permission_announce="Announcements",
    permission_rule_time="Change time",permission_rule_rain="Change rain",permission_rule_fog="Change fog",
    permission_rule_regen="Change regeneration",permission_reset_rules="Reset rules",
}

local function world(registry)
    registry=registry or {}
    local key,clears="",0
    local env={
        OSP={},
        InputLastPressedKey=function() return key end,
        InputClear=function() clears=clears+1;key="" end,
        GetString=function(name) return registry[name] or "" end,
        SetString=function(name,value) registry[name]=value end,
    }
    setmetatable(env,{__index=_G})
    env.OSP.copy=copy
    env.OSP.L=function(name,...)
        local value=strings[name] or name
        if select("#",...)>0 then return string.format(value,...) end
        return value
    end
    local function load(path)
        local chunk=assert(loadfile(path))
        setfenv(chunk,env)
        chunk()
    end
    load("mod/scripts/search_input.lua")
    load("mod/scripts/permissions.lua")
    load("mod/scripts/permissions_ui.lua")

    local api={controls={},labels={},paragraphs={},images={},commands={},asks={},viewports={},dropdowns={},canCalls={},pendingValue=false,
        click=nil,dropdownChoice=nil,wheelValue=0,resetCount=0,canHandler=nil,denied={},playerStepCalls=0,playerCountValue=2}
    function api.beginDraw()
        api.controls={};api.labels={};api.paragraphs={};api.images={};api.commands={};api.asks={};api.viewports={};api.dropdowns={};api.canCalls={}
    end
    function api.dropdown(id,x,y,w,h,items,current,disabled,onSelect)
        api.dropdowns[id]={x=x,y=y,w=w,h=h,items=copy(items),current=current,disabled=disabled==true}
        local choice=api.dropdownChoice
        if choice then
            api.dropdownChoice=nil
            if not disabled then onSelect(choice) end
        end
    end
    function api.label(x,y,value,size,width)
        api.labels[#api.labels+1]={x=x,y=y,text=tostring(value),size=size,width=width}
    end
    function api.paragraph(x,y,value,size,width)
        api.paragraphs[#api.paragraphs+1]={x=x,y=y,text=tostring(value),size=size,width=width}
        return 18
    end
    function api.button(id,x,y,w,h,value,style,disabled)
        api.controls[id]={x=x,y=y,w=w,h=h,text=value,style=style,disabled=disabled==true}
        if api.click==id then
            api.click=nil
            return disabled~=true
        end
        return false
    end
    function api.image(x,y,path) api.images[#api.images+1]={x=x,y=y,path=path} end
    function api.pending() return api.pendingValue end
    function api.can(action,target,arg)
        api.canCalls[#api.canCalls+1]={action=action,target=target,arg=copy(arg)}
        if api.canHandler then return api.canHandler(action,target,arg) end
        return api.denied[action]~=true
    end
    function api.command(action,target,arg)
        api.commands[#api.commands+1]={action=action,target=target,arg=copy(arg)}
    end
    function api.ask(action,target,arg,message)
        api.asks[#api.asks+1]={action=action,target=target,arg=copy(arg),message=message}
    end
    function api.resetScroll() api.resetCount=api.resetCount+1 end
    function api.playerIndex() return 1 end
    function api.playerCount() return api.playerCountValue end
    function api.playerStep(delta) api.playerStepCalls=api.playerStepCalls+delta end
    function api.playerCaption() return "Player" end
    function api.viewport(x,y,w,h,scroll,drawFn)
        local item={x=x,y=y,w=w,h=h,scroll=scroll}
        api.viewports[#api.viewports+1]=item
        item.contentHeight=drawFn()
        return item.contentHeight
    end
    function api.wheel(x,y,w,h)
        api.lastWheel={x=x,y=y,w=w,h=h}
        local value=api.wheelValue;api.wheelValue=0;return value
    end

    return {env=env,UI=env.OSP.PermissionUI,P=env.OSP.Permissions,api=api,registry=registry,
        setKey=function(value) key=value end,clears=function() return clears end}
end

local player={id=9,name="Player",role="guest",host=false,profileReady=true}
local function builtinRoles(w) return w.P.list({}) end
local function customRole(w,permissions)
    return {id="builder",name="Builder",builtin=false,version=1,permissions=copy(permissions or {})}
end
local function compact(w,roles,width)
    w.api.beginDraw()
    local height=w.UI.draw(w.api,roles,player,width or 800)
    return w.api,height
end
local function expanded(w,roles,width,height)
    w.api.beginDraw()
    w.UI.drawExpanded(w.api,roles,player,width or 800,height or 540)
    return w.api
end
local function clickCompact(w,roles,id,width)
    w.api.click=id
    return compact(w,roles,width)
end
local function clickExpanded(w,roles,id,width,height)
    w.api.click=id
    return expanded(w,roles,width,height)
end
local function typeSearch(w,value)
    for char in value:gmatch(".") do w.setKey(char);w.UI.key() end
end
local function enterExistingEditor(w,roles,width)
    compact(w,roles,width)
    clickCompact(w,roles,"role_edit_custom",width)
    eq(w.UI.getState().view,"edit","custom Edit enters draft")
end
local function buttonLabel(api,text)
    for _,label in ipairs(api.labels) do if label.text==text then return label end end
end
local function within(rect,width,height,message)
    check(rect and rect.x>=0 and rect.y>=0 and rect.x+rect.w<=width and rect.y+rect.h<=height,message)
end

-- New category sections begin closed. Their local preference survives reload.
do
    local reg={}
    local w=world(reg);local roles=builtinRoles(w)
    compact(w,roles)
    for _,category in ipairs(w.P.categories) do
        eq(w.UI.getState().groups[category.id],false,"category defaults closed: "..category.id)
        check(w.api.controls["permission_group_"..category.id]~=nil,"category header is present")
    end
    check(w.api.controls.role_scope_heal_0==nil,"collapsed categories hide rows")
    clickCompact(w,roles,"permission_group_players")
    eq(w.UI.getState().groups.players,true,"click expands category")
    eq(reg["savegame.mod.osp_beta.permissions.expanded.players"],"1","expanded category persists locally")
    local restarted=world(reg)
    eq(restarted.UI.getState().groups.players,true,"expanded state restores after module reload")
    eq(restarted.UI.getState().groups.tools,false,"other categories remain closed")
    restarted.UI.closeExpanded()
    compact(restarted,builtinRoles(restarted))
    eq(restarted.UI.getState().groups.players,true,"expanded state survives return to compact view")
end

-- Editing a legacy custom role fills newly added capabilities with zero.
do
    local w=world()
    local role=customRole(w,{heal=0,respawn=1,tools=2})
    local roles={role}
    enterExistingEditor(w,roles)
    local state=w.UI.getState()
    eq(state.draft.permissions.ammo,0,"legacy custom role receives new capability disabled")
    for _,spec in ipairs(w.P.spec) do
        check(state.draft.permissions[spec.id]~=nil,"draft has an explicit value for "..spec.id)
    end
    clickCompact(w,roles,"permission_group_players")
    local before=copy(w.UI.getState().draft.permissions)
    clickCompact(w,roles,"role_scope_heal_2")
    local api=compact(w,roles)
    state=w.UI.getState()
    eq(state.draft.permissions.heal,2,"selected target scope is applied")
    check(api.controls.role_scope_heal_2.style=="active","selected scope has a distinct selected outline")
    check(api.controls.role_scope_heal_1.style=="outlined","other scope remains independently selectable")
    for _,spec in ipairs(w.P.spec) do
        if spec.id~="heal" then eq(state.draft.permissions[spec.id],before[spec.id],"scope leaves "..spec.id.." unchanged") end
    end
end

-- Search hides unmatched categories but never opens a matching category.
do
    local w=world();local role=customRole(w,{tools=2,ammo=0});local roles={role}
    enterExistingEditor(w,roles)
    clickCompact(w,roles,"permission_view_search")
    typeSearch(w,"infinite")
    local state=w.UI.getState()
    eq(state.query,"infinite","permission search captures its own query")
    eq(state.groups.tools,false,"search does not auto-open a category")
    local api=compact(w,roles)
    check(api.controls.permission_group_tools~=nil,"matching category remains visible")
    eq(api.controls.permission_group_players,nil,"category without matches is hidden")
    eq(api.controls.role_scope_ammo_0,nil,"collapsed search result stays hidden")
    check(buttonLabel(api,"Tools and ammo (1/3)")~=nil,"category header shows matched and total counts")
    clickCompact(w,roles,"permission_group_tools")
    api=compact(w,roles)
    check(api.controls.role_scope_ammo_0~=nil,"matching permission appears after explicit expansion")
    eq(api.controls.role_scope_tools_0,nil,"unmatched permission remains filtered out")
    eq(api.controls.role_scope_tools_all_0,nil,"search preserves only matching rows")
end

-- Read-only built-ins expose values but no scope or Edit mutations.
do
    local w=world();local roles=builtinRoles(w)
    compact(w,roles)
    w.UI.openExpanded()
    check(w.UI.isExpanded(),"openExpanded enters the shared view")
    local api=expanded(w,roles)
    check(api.viewports[1]~=nil,"expanded mode uses a clipped local viewport")
    eq(api.controls.role_editor_name,nil,"built-in role has no name editor")
    check(api.controls.role_edit_custom and api.controls.role_edit_custom.disabled,"built-in role Edit is disabled in expanded mode")
    check(api.controls.role_delete and api.controls.role_delete.disabled,"built-in role Delete is disabled in expanded mode")
    eq(api.controls.permission_view_expand,nil,"compact panel leaves expansion control to the tab header")
    check(api.dropdowns.permission_view_role_select~=nil,"expanded assignment uses the shared Role dropdown")
    check(buttonLabel(api,"Built-in role is read-only.")~=nil,"built-in restriction is stated")
    clickExpanded(w,roles,"permission_group_players")
    api=expanded(w,roles)
    eq(api.controls.role_scope_heal_0,nil,"built-in rows have no editable scope controls")
    check(buttonLabel(api,"Off")~=nil,"built-in permission scopes remain readable")
end

-- Both assignment layouts use one Role dropdown; focusPlayerRole never destroys an editor draft.
do
    local w=world();local roles=builtinRoles(w);roles[#roles+1]=customRole(w,{heal=2})
    local api=compact(w,roles,800)
    check(api.dropdowns.permission_view_role_select~=nil,"compact assignment uses the Role dropdown")
    eq(api.dropdowns.permission_view_role_select.current,"guest","compact dropdown starts at the selected role")
    eq(api.controls.permission_view_role_prev,nil,"compact assignment has no previous-role control")
    eq(api.controls.permission_view_role_next,nil,"compact assignment has no next-role control")
    api.dropdownChoice="builder"
    compact(w,roles,800)
    eq(w.UI.getState().selected,"builder","compact dropdown selects the requested role")
    w.UI.openExpanded()
    api=expanded(w,roles,800,560)
    eq(api.dropdowns.permission_view_role_select.current,"builder","expanded dropdown shares compact selection")
    api.dropdownChoice="helper"
    expanded(w,roles,800,560)
    eq(w.UI.getState().selected,"helper","expanded dropdown selects locally")
    w.UI.focusPlayerRole("builder")
    eq(w.UI.getState().selected,"builder","player focus selects a role in assignment view")
    w.UI.closeExpanded()
    enterExistingEditor(w,roles,800)
    local draft=copy(w.UI.getState().draft)
    w.UI.focusPlayerRole("admin")
    eq(w.UI.getState().selected,"builder","player focus does not switch roles inside the editor")
    eq(w.UI.getState().draft.name,draft.name,"player focus preserves the editor draft")
    eq(w.UI.getState().draft.permissions.heal,draft.permissions.heal,"player focus preserves draft grants")
    clickCompact(w,roles,"role_editor_discard",800)
    w.UI.focusPlayerRole("admin")
    eq(w.UI.getState().selected,"admin","player focus works again after discarding the editor")
end

-- Narrow layouts put the scope controls below each permission label.
for _,width in ipairs({800,400}) do
    local w=world();local role=customRole(w,{heal=1});local roles={role}
    enterExistingEditor(w,roles,width)
    clickCompact(w,roles,"permission_group_players",width)
    local api=compact(w,roles,width)
    local label=buttonLabel(api,"Heal")
    local scope=api.controls.role_scope_heal_1
    check(label and scope,"target permission has label and scope controls")
    if width<620 then check(scope.y>label.y+18,"narrow scope controls sit below the label")
    else check(math.abs(scope.y-label.y)<12,"wide scope controls share the permission row") end
    check(api.controls.role_scope_heal_0 and api.controls.role_scope_heal_2,"target scopes expose off, self and any")
    clickCompact(w,roles,"permission_group_tools",width)
    api=compact(w,roles,width)
    check(api.controls.role_scope_tools_all_0 and api.controls.role_scope_tools_all_2,"global scopes expose off and on")
    eq(api.controls.role_scope_tools_all_1,nil,"global scopes do not expose self-only")
end

-- Creation copies the selected Role into a separate editor and never assigns it implicitly.
do
    local w=world();local roles=builtinRoles(w);roles[#roles+1]=customRole(w,{heal=1,tools=2})
    w.api.dropdownChoice="builder"
    compact(w,roles)
    clickCompact(w,roles,"role_create_custom")
    local state=w.UI.getState()
    eq(state.view,"edit","Create opens the separate editor")
    eq(state.draft.id,"","new draft has no persisted ID")
    eq(state.draft.permissions.heal,1,"new draft copies the selected Role grants")
    eq(state.draft.permissions.tools,2,"copy retains all selected Role grants")
    local api=compact(w,roles)
    eq(api.controls.role_apply,nil,"editor has no player assignment action")
    eq(api.controls.role_target_next,nil,"editor has no player selector")
    eq(api.dropdowns.permission_view_role_select,nil,"editor has no Role picker that could discard its draft")
    api=clickCompact(w,roles,"role_editor_save")
    eq(api.commands[1].action,"role_save","creation uses the role save command")
    eq(api.commands[1].arg.id,"","creation sends a new-role draft")
end

-- A delegate can delete without edit, while proposed grants above their ceiling are disabled.
do
    local w=world();local roles=builtinRoles(w);roles[#roles+1]=customRole(w,{heal=2})
    w.api.canHandler=function(action)
        if action=="role_delete" then return true end
        if action=="role_save" or action=="role_assign" then return false end
        return true
    end
    w.api.dropdownChoice="builder"
    local api=compact(w,roles)
    check(api.controls.role_edit_custom.disabled,"role_save/role_edit denial disables Edit")
    check(api.controls.role_create_custom.disabled,"role_save/role_create denial disables copying this stronger Role")
    check(not api.controls.role_delete.disabled,"role_delete remains independent of role_edit")
    check(api.controls.role_apply.disabled,"role_assign denial disables assignment")
    api=clickCompact(w,roles,"role_delete")
    eq(api.asks[1].action,"role_delete","Delete asks the existing server confirmation")
    eq(api.asks[1].arg.id,"builder","Delete targets the selected Role")
    eq(w.UI.getState().view,"assign","Delete does not require opening the editor")

    local limited=world();local limitedRole=customRole(limited,{heal=1});local limitedRoles={limitedRole}
    limited.api.canHandler=function(action,_,arg)
        if action=="role_save" then return arg and arg.permissions and (arg.permissions.heal or 0)<=1 end
        return true
    end
    enterExistingEditor(limited,limitedRoles)
    clickCompact(limited,limitedRoles,"permission_group_players")
    api=compact(limited,limitedRoles)
    check(api.controls.role_scope_heal_0 and not api.controls.role_scope_heal_0.disabled,"allowed lower scope remains editable")
    check(api.controls.role_scope_heal_1 and not api.controls.role_scope_heal_1.disabled,"current allowed scope remains editable")
    check(api.controls.role_scope_heal_2.disabled,"scope proposal above the actor ceiling is disabled")
    clickCompact(limited,limitedRoles,"role_scope_heal_2")
    eq(limited.UI.getState().draft.permissions.heal,1,"disabled scope cannot raise the draft")
end

-- Expanded layouts keep all actions inside the view and use a separate list viewport.
for _,width in ipairs({400,800,1200}) do
    local w=world();local roles=builtinRoles(w);roles[#roles+1]=customRole(w,{heal=1})
    w.UI.openExpanded()
    local api=expanded(w,roles,width,560)
    local dropdown=api.dropdowns.permission_view_role_select
    check(dropdown~=nil,"expanded Role dropdown exists at width "..width)
    within(dropdown,width,560,"Role dropdown stays inside width "..width)
    check(api.controls.role_apply and api.controls.role_create_custom and api.controls.role_edit_custom and api.controls.role_delete,
        "expanded assignment actions remain available at width "..width)
    within(api.controls.role_apply,width,560,"Apply stays inside width "..width)
    within(api.controls.role_create_custom,width,560,"Create stays inside width "..width)
    within(api.controls.role_edit_custom,width,560,"Edit stays inside width "..width)
    within(api.controls.role_delete,width,560,"Delete stays inside width "..width)
    check(api.viewports[1] and api.viewports[1].h>0,"permission list has a scroll viewport at width "..width)
    if width>=760 then check(api.viewports[1].x>0,"wide layout places management beside the permission list")
    else
        eq(api.viewports[1].x,0,"narrow layout stacks management and permissions")
        check(api.controls.role_apply.y+api.controls.role_apply.h<=560,"narrow Apply remains fixed in its footer")
    end
    local clear=api.controls.permission_view_search_clear
    check(clear.x+clear.w<=width-60,"expanded search leaves room for the tab close button")
end

-- The narrow layout scrolls manager and permissions together while Apply stays fixed.
do
    local w=world();local roles=builtinRoles(w);roles[#roles+1]=customRole(w,{heal=1})
    w.UI.openExpanded()
    local api=expanded(w,roles,561,380)
    eq(api.viewports[1].y,47,"narrow scroll region starts below fixed search")
    eq(api.controls.role_apply.y,341,"narrow Apply remains at the bottom of a 640x480 style layout")
    check(api.viewports[1].h>0,"narrow management and permission list can scroll in a short panel")
end

-- Expanded editor controls remain fixed and reachable at each supported width.
for _,width in ipairs({400,800,1200}) do
    local w=world();local role=customRole(w,{heal=1});local roles={role}
    enterExistingEditor(w,roles,width)
    w.UI.openExpanded()
    local api=expanded(w,roles,width,560)
    for _,id in ipairs({"role_editor_name","role_editor_save","role_editor_discard","role_editor_reload","role_editor_delete"}) do
        check(api.controls[id]~=nil,"expanded editor keeps "..id.." at width "..width)
        within(api.controls[id],width,560,id.." stays inside width "..width)
    end
    check(api.viewports[1] and api.viewports[1].h>0,"expanded editor scopes have a viewport at width "..width)
    if width<760 then
        check(api.viewports[1].y>api.controls.role_editor_delete.y+api.controls.role_editor_delete.h,
            "narrow editor scroll begins below fixed actions")
    else
        check(api.viewports[1].x>0,"wide editor keeps management beside its permission list")
    end
end

-- Expanded mode shares draft/search/groups, keeps fixed actions, and sends the full draft.
do
    local w=world();local role=customRole(w,{heal=1,respawn=2,tools=2});local roles={role}
    enterExistingEditor(w,roles)
    clickCompact(w,roles,"permission_view_search")
    typeSearch(w,"infinite")
    clickCompact(w,roles,"permission_group_tools")
    clickCompact(w,roles,"role_scope_ammo_2")
    eq(w.UI.getState().draft.permissions.ammo,2,"filtered capability updates the draft")
    local query=w.UI.getState().query
    w.UI.openExpanded()
    local api=expanded(w,roles,900,560)
    eq(w.UI.getState().query,query,"query is shared with expanded mode")
    eq(w.UI.getState().groups.tools,true,"expanded mode shares category state")
    check(api.controls.role_editor_save~=nil and api.controls.role_editor_discard~=nil,"expanded footer keeps explicit Save and Discard")
    api=clickExpanded(w,roles,"role_editor_save",900,560)
    eq(#api.commands,1,"expanded Save uses the role command path")
    local payload=api.commands[1].arg
    eq(payload.id,"builder","Save retains role identity")
    eq(payload.permissions.ammo,2,"Save includes the filtered capability")
    eq(payload.permissions.heal,1,"Save includes permissions outside the filter")
    eq(payload.permissions.respawn,2,"Save preserves other hidden permission values")
    eq(#(function() local ids={};for id in pairs(payload.permissions) do ids[#ids+1]=id end;return ids end)(),#w.P.spec,"Save sends every current capability")
    -- No saved callback means a rejected/version-conflicted request leaves the draft intact.
    expanded(w,roles,900,560)
    eq(w.UI.getState().draft.permissions.ammo,2,"pre-ACK conflict state keeps the draft")
    local saved=copy(role);saved.version=2;saved.permissions=copy(payload.permissions)
    w.UI.saved(saved)
    eq(w.UI.isExpanded(),false,"accepted Save ACK closes expanded mode")
    eq(w.UI.getState().view,"assign","accepted Save returns to role assignment")
    eq(w.UI.getState().query,query,"accepted Save keeps the search query")
    eq(w.UI.getState().searchFocused,false,"accepted Save closes expanded mode without search focus")
end

-- Pending blocks role edits while search and category consultation remain available.
do
    local w=world();local role=customRole(w,{heal=1});local roles={role}
    enterExistingEditor(w,roles)
    clickCompact(w,roles,"permission_group_players")
    w.api.pendingValue=true
    local api=compact(w,roles)
    check(api.controls.role_scope_heal_1.disabled,"pending disables scope edits")
    check(api.controls.role_editor_save.disabled,"pending disables Save")
    check(not api.controls.permission_group_players.disabled,"pending allows category browsing")
    check(not api.controls.permission_view_search.disabled,"pending allows permission search")
    clickCompact(w,roles,"permission_view_search")
    typeSearch(w,"heal")
    eq(w.UI.getState().query,"heal","search capture works while pending")
    check(w.UI.capturing(),"search focus is reported to root input routing")
    local before=copy(w.UI.getState().draft)
    w.UI.cancelInput()
    eq(w.UI.capturing(),false,"cancelInput clears both focus modes")
    eq(w.UI.getState().query,"heal","cancelInput preserves search query")
    eq(w.UI.getState().draft.name,before.name,"cancelInput preserves the draft")
    eq(w.UI.getState().draft.permissions.heal,before.permissions.heal,"cancelInput preserves permissions")
end

-- Pending still permits local player/Role selection and browsing, but blocks server mutations.
do
    local w=world();local roles=builtinRoles(w);roles[#roles+1]=customRole(w,{heal=1})
    w.UI.openExpanded()
    w.api.pendingValue=true
    w.api.dropdownChoice="builder"
    local api=expanded(w,roles,400,560)
    eq(w.UI.getState().selected,"builder","pending leaves Role selection local")
    check(api.dropdowns.permission_view_role_select and not api.dropdowns.permission_view_role_select.disabled,
        "pending leaves the Role dropdown enabled")
    check(api.controls.role_target_next and not api.controls.role_target_next.disabled,
        "pending leaves player selection enabled")
    check(api.controls.role_apply.disabled,"pending disables assignment")
    check(api.controls.role_create_custom.disabled and api.controls.role_edit_custom.disabled and api.controls.role_delete.disabled,
        "pending disables role mutations")
    check(not api.controls.permission_view_search.disabled and not api.controls.permission_group_players.disabled,
        "pending leaves search and group browsing enabled")
    api=clickExpanded(w,roles,"role_target_next",400,560)
    eq(api.playerStepCalls,1,"pending still routes local player selection")
    api=clickExpanded(w,roles,"permission_group_players",400,560)
    eq(w.UI.getState().groups.players,true,"pending still expands a permission group")
end

-- openExpanded clears capture while preserving the independent query and draft.
do
    local w=world();local role=customRole(w,{heal=1});local roles={role}
    enterExistingEditor(w,roles)
    clickCompact(w,roles,"permission_view_search")
    typeSearch(w,"heal")
    clickCompact(w,roles,"role_editor_name")
    local before=copy(w.UI.getState())
    check(before.nameFocused and before.query=="heal","name capture and query are established before opening")
    w.UI.openExpanded()
    local after=w.UI.getState()
    eq(after.nameFocused,false,"openExpanded clears name focus")
    eq(after.searchFocused,false,"openExpanded clears search focus")
    eq(after.query,before.query,"openExpanded preserves the search query")
    eq(after.draft.name,before.draft.name,"openExpanded preserves the draft name")
    eq(after.draft.permissions.heal,before.draft.permissions.heal,"openExpanded preserves draft grants")
end

-- Save input and name input never share focus; tab/close cancellation preserves state.
do
    local w=world();local role=customRole(w,{heal=1});local roles={role}
    enterExistingEditor(w,roles)
    clickCompact(w,roles,"role_editor_name")
    check(w.UI.getState().nameFocused,"name field owns capture")
    clickCompact(w,roles,"permission_view_search")
    eq(w.UI.getState().nameFocused,false,"search click leaves name capture")
    check(w.UI.getState().searchFocused,"search field owns capture")
    typeSearch(w,"x")
    local before=w.UI.getState()
    w.UI.closeExpanded()
    eq(w.UI.getState().query,before.query,"closeExpanded preserves query")
    eq(w.UI.getState().draft.name,before.draft.name,"closeExpanded preserves draft")
    eq(w.UI.getState().groups.players,before.groups.players,"closeExpanded preserves group state")
    eq(w.UI.capturing(),false,"closeExpanded clears focus")
end

print("PASS permission UI categories, scopes, search, viewport and ACK state: "..assertions.." assertions")
