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
    role_create_short="Create role",role_create_help="Creates a custom role based on %s.",role_edit_short="Edit",role_reset_short="Reset",role_delete_short="Delete",
    role_editor_create_title="Create role",role_editor_edit_title="Edit role",role_editor_based_on="Based on %s",
    role_editor_save_effect="Changes take effect after save.",role_name_label="Role name",
    role_editor_unsaved="Unsaved changes",role_editor_scope_help="Choose the access for each permission.",
    role_editor_discard="Discard",role_editor_save="Save",role_editor_reload="Reload",role_editor_delete="Delete",
    confirm_role_assign="Assign %s to %s?",confirm_role_delete="Delete %s?",confirm_role_reset="Reset %s?",permission_host_reserved="Host access is reserved.",
    permission_view_expand="Manage roles",permission_search="Search permissions by name, ID or category",role_select_label="Role",
    permission_search_empty="No matching permissions.",permission_builtin_readonly="Built-in role is read-only.",
    role_batch_selected="Selected: %d",role_batch_apply_count="Assign role (%d)",role_batch_empty="Select at least one eligible player.",
    confirm_role_batch="Assign %s to %d eligible players?",
    role_targets_title="Players",role_targets_none="There are no other players in this session.",
    role_targets_mark_all="Select all",role_targets_clear="Clear",role_targets_hint="Select players from the list.",
    role_targets_eligible="%d players will receive this role.",role_targets_unchanged="No changes for this selection.",
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

    local api={controls={},labels={},paragraphs={},images={},commands={},asks={},viewports={},dropdowns={},canCalls={},panels={},rows={},pendingValue=false,
        heightValue=800,
        click=nil,dropdownChoice=nil,wheelValue=0,resetCount=0,canHandler=nil,denied={},playerStepCalls=0,playerCountValue=2}
    function api.beginDraw()
        api.controls={};api.labels={};api.paragraphs={};api.images={};api.commands={};api.asks={};api.viewports={};api.dropdowns={};api.canCalls={};api.panels={};api.rows={}
    end
    function api.dropdown(id,x,y,w,h,items,current,disabled,onSelect)
        api.dropdowns[id]={x=x,y=y,w=w,h=h,items=copy(items),current=current,disabled=disabled==true}
        local choice=api.dropdownChoice
        if choice then
            api.dropdownChoice=nil
            if not disabled then onSelect(choice) end
        end
    end
    function api.label(x,y,value,size,width,muted,bold)
        api.labels[#api.labels+1]={x=x,y=y,text=tostring(value),size=size,width=width,muted=muted==true,bold=bold==true}
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
    function api.panel(x,y,w,h) api.panels[#api.panels+1]={x=x,y=y,w=w,h=h} end
    function api.height() return api.heightValue end
    function api.selectionRow(id,x,y,w,h,name,roleName,checked,disabled)
        local row={x=x,y=y,w=w,h=h,text=name,role=roleName,checked=checked==true,disabled=disabled==true}
        api.controls[id]=row;api.rows[#api.rows+1]=row
        if api.click==id then api.click=nil;return disabled~=true end
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
    function api.enableAssignment(players,namespace,actorJoin)
        api.batchPlayers=players;api.batchNamespace=namespace or string.rep('a',32);api.batchActorJoin=actorJoin or 1
        api.players=function() return api.batchPlayers end
        api.profileHost=function() return api.batchNamespace end
        api.groupAssignment=function(role,targets)
            return {host=api.batchNamespace,actorJoin=api.batchActorJoin,role=role,targets=copy(targets)}
        end
        api.checkbox=function(id,x,y,w,h,label,checked,disabled)
            api.controls[id]={x=x,y=y,w=w,h=h,text=label,checked=checked==true,disabled=disabled==true}
            if api.click==id then api.click=nil;return disabled~=true end
            return false
        end
    end

    return {env=env,UI=env.OSP.PermissionUI,P=env.OSP.Permissions,api=api,registry=registry,
        setKey=function(value) key=value end,clears=function() return clears end}
end

local player={id=9,name="Player",role="guest",host=false,profileReady=true}
local function builtinRoles(w) return w.P.list({}) end
local function customRole(w,permissions)
    permissions=copy(permissions or {})
    return {id="builder",name="Builder",builtin=false,version=1,permissions=permissions,
        initial={name="Builder",permissions=copy(permissions)}}
end
local function advanced(w,roles,width)
    if not w.UI.isExpanded() then w.UI.openExpanded() end
    w.api.beginDraw()
    w.UI.drawExpanded(w.api,roles,player,width or 1200,800)
    return w.api
end
local function expanded(w,roles,width,height)
    w.api.beginDraw()
    w.UI.drawExpanded(w.api,roles,player,width or 800,height or 540)
    return w.api
end
local function clickAdvanced(w,roles,id,width)
    w.api.click=id
    return advanced(w,roles,width)
end
local function clickExpanded(w,roles,id,width,height)
    w.api.click=id
    return expanded(w,roles,width,height)
end
local function typeSearch(w,value)
    for char in value:gmatch(".") do w.setKey(char);w.UI.key() end
end
local function enterExistingEditor(w,roles,width)
    advanced(w,roles,width)
    clickAdvanced(w,roles,"role_edit_custom",width)
    eq(w.UI.getState().view,"edit","custom Edit enters draft")
end
local function buttonLabel(api,text)
    for _,label in ipairs(api.labels) do if label.text==text then return label end end
end
local function within(rect,width,height,message)
    check(rect and rect.x>=0 and rect.y>=0 and rect.x+rect.w<=width and rect.y+rect.h<=height,message)
end

-- Compact assignment always uses the target list, with a fixed-width Role column on wide content.
for _,width in ipairs({400,719,720,800}) do
    local w=world();local roles=builtinRoles(w);local api=w.api
    local roster={{id=1,name="Host",role="admin",host=true,profileReady=true,profileChallenge=1},
        {id=9,name="Player",role="guest",host=false,profileReady=true,profileChallenge=2}}
    api.enableAssignment(roster);api.dropdownChoice="admin";api.beginDraw()
    w.UI.draw(api,roles,roster[2],width)
    local dropdown=api.dropdowns.permission_view_role_select
    local row=api.controls.permission_view_target_9
    local apply=api.controls.permission_view_batch_apply
    local manage=api.controls.permission_view_expand
    check(dropdown and row and apply and manage,"compact keeps targets, destination and actions at width "..width)
    eq(api.controls.permission_view_target_1,nil,"the host is outside the checkbox list")
    for _,id in ipairs({"role_target_prev","role_target_next","role_apply","permission_view_batch_mode","permission_view_batch_list"}) do
        eq(api.controls[id],nil,"removed assignment control is absent: "..id)
    end
    eq(w.UI.getState().batchMode,nil,"unified selection has no mode state")
    eq(w.UI.getState().batchListOpen,nil,"unified selection has no list visibility state")
    eq(apply.w,180,"Apply uses the normal 180-unit button width")
    eq(manage.w,180,"Manage roles uses the normal 180-unit secondary width")
    check(apply.x>=dropdown.x and apply.x+apply.w<=dropdown.x+dropdown.w,"Apply is aligned inside the Role block")
    if width>=720 then
        eq(api.panels[2].x,api.panels[1].x+api.panels[1].w+24,"wide content separates columns by 24 units")
        eq(api.panels[2].w,320,"wide content gives the Role destination a 320-unit column")
        eq(dropdown.w,288,"Role selector fills the padded destination column")
    else
        eq(api.panels[2].x,0,"narrow content stacks the Role destination below the list")
        check(dropdown.y>row.y+row.h,"narrow destination follows the target rows")
    end
    check(not api.controls.role_create_custom and not api.controls.role_edit_custom,"compact hides custom Role management")
    check(not api.controls.permission_view_search and not api.controls.permission_group_players,"compact hides detailed permissions")
    w.UI.openExpanded();expanded(w,roles,width,800)
    clickExpanded(w,roles,"role_create_custom",width,800)
    local before=w.UI.getState().draft
    w.UI.closeExpanded();w.api.beginDraw();w.UI.draw(w.api,roles,player,width)
    check(w.api.controls.permission_view_resume~=nil,"compact exposes resume for an unsaved draft")
    eq(w.api.controls.permission_view_expand,nil,"unsaved draft has no duplicate management entry")
    check(not w.api.controls.role_editor_name,"compact does not squeeze the advanced editor back in")
    w.api.click="permission_view_resume";w.UI.draw(w.api,roles,player,width)
    check(w.UI.isExpanded(),"resume opens the editor")
    eq(w.UI.getState().draft.name,before.name,"resume preserves draft")
end

-- New category sections begin closed. Their local preference survives reload.
do
    local reg={}
    local w=world(reg);local roles=builtinRoles(w)
    advanced(w,roles)
    for _,category in ipairs(w.P.categories) do
        eq(w.UI.getState().groups[category.id],false,"category defaults closed: "..category.id)
        check(w.api.controls["permission_group_"..category.id]~=nil,"category header is present")
    end
    check(w.api.controls.role_scope_heal_0==nil,"collapsed categories hide rows")
    clickAdvanced(w,roles,"permission_group_players")
    eq(w.UI.getState().groups.players,true,"click expands category")
    eq(reg["savegame.mod.osp_beta.permissions.expanded.players"],"1","expanded category persists locally")
    local restarted=world(reg)
    eq(restarted.UI.getState().groups.players,true,"expanded state restores after module reload")
    eq(restarted.UI.getState().groups.tools,false,"other categories remain closed")
    restarted.UI.closeExpanded()
    advanced(restarted,builtinRoles(restarted))
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
    clickAdvanced(w,roles,"permission_group_players")
    local before=copy(w.UI.getState().draft.permissions)
    clickAdvanced(w,roles,"role_scope_heal_2")
    local api=advanced(w,roles)
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
    clickAdvanced(w,roles,"permission_view_search")
    typeSearch(w,"infinite")
    local state=w.UI.getState()
    eq(state.query,"infinite","permission search captures its own query")
    eq(state.groups.tools,false,"search does not auto-open a category")
    local api=advanced(w,roles)
    check(api.controls.permission_group_tools~=nil,"matching category remains visible")
    eq(api.controls.permission_group_players,nil,"category without matches is hidden")
    eq(api.controls.role_scope_ammo_0,nil,"collapsed search result stays hidden")
    check(buttonLabel(api,"Tools and ammo (1/3)")~=nil,"category header shows matched and total counts")
    clickAdvanced(w,roles,"permission_group_tools")
    api=advanced(w,roles)
    check(api.controls.role_scope_ammo_0~=nil,"matching permission appears after explicit expansion")
    eq(api.controls.role_scope_tools_0,nil,"unmatched permission remains filtered out")
    eq(api.controls.role_scope_tools_all_0,nil,"search preserves only matching rows")
end

-- Presets keep their IDs and provenance while exposing the same editable draft controls as custom roles.
do
    local w=world();local roles=builtinRoles(w)
    advanced(w,roles)
    w.UI.openExpanded()
    check(w.UI.isExpanded(),"openExpanded enters the shared view")
    local api=expanded(w,roles)
    check(api.viewports[1]~=nil,"expanded mode uses a clipped local viewport")
    check(api.controls.role_edit_custom and not api.controls.role_edit_custom.disabled,"preset Edit is enabled in expanded mode")
    check(api.controls.role_delete and api.controls.role_delete.disabled,"built-in role Delete is disabled in expanded mode")
    eq(api.controls.permission_view_expand,nil,"expanded editor does not repeat compact management entry")
    check(api.dropdowns.permission_view_role_select~=nil,"expanded assignment uses the shared Role dropdown")
    eq(buttonLabel(api,"Built-in role is read-only."),nil,"preview no longer describes presets as read-only")
    api=clickExpanded(w,roles,"role_edit_custom")
    local draft=w.UI.getState().draft
    eq(w.UI.getState().view,"edit","preset Edit enters a draft")
    eq(draft.id,"guest","editing a preset retains its ID")
    eq(draft.name,"Guest","editing materializes the preset display name")
    eq(draft.nameKey,nil,"preset draft drops the localization key")
    eq(draft.version,0,"preset draft retains the current version")
    check(draft.builtin,"preset draft retains preset provenance")
    api=expanded(w,roles)
    check(api.controls.role_editor_name and not api.controls.role_editor_name.disabled,"preset name field is editable")
    api=clickAdvanced(w,roles,"role_editor_name")
    w.setKey("x");w.UI.key()
    draft=w.UI.getState().draft
    eq(draft.id,"guest","renaming does not change preset identity")
    eq(draft.name,"Guestx","preset name input accepts edits")
    eq(w.UI.getState().draft.version,0,"local edit does not invent a version")
    api=clickAdvanced(w,roles,"role_editor_save")
    eq(api.commands[1].action,"role_save","preset Edit uses the role save command")
    eq(api.commands[1].arg.id,"guest","preset Save retains the original ID")
    eq(api.commands[1].arg.name,"Guestx","preset Save carries the edited display name")
end

-- Both assignment layouts use one Role dropdown; focusPlayerRole never destroys an editor draft.
do
    local w=world();local roles=builtinRoles(w);roles[#roles+1]=customRole(w,{heal=2})
    local roster={{id=1,name="Host",role="admin",host=true,profileReady=true,profileChallenge=1},
        {id=9,name="Player",role="guest",host=false,profileReady=true,profileChallenge=2}}
    w.api.enableAssignment(roster)
    local api=advanced(w,roles,800)
    check(api.dropdowns.permission_view_role_select~=nil,"compact assignment uses the Role dropdown")
    eq(api.dropdowns.permission_view_role_select.current,"guest","compact dropdown starts at the selected role")
    api.dropdownChoice="builder"
    advanced(w,roles,800)
    eq(w.UI.getState().selected,"builder","compact dropdown selects the requested role")
    w.UI.openExpanded()
    api=expanded(w,roles,800,560)
    eq(api.dropdowns.permission_view_role_select.current,"builder","expanded dropdown shares compact selection")
    api.dropdownChoice="helper"
    expanded(w,roles,800,560)
    eq(w.UI.getState().selected,"helper","expanded dropdown selects locally")
    w.UI.closeExpanded()
    w.UI.focusPlayerRole("builder",roster[2],w.api.batchNamespace)
    eq(w.UI.getState().selected,"builder","player focus selects a role in assignment view")
    advanced(w,roles,800)
    eq(w.UI.getState().batchSelected,1,"explicit player focus selects one target")
    eq(w.UI.getState().batchSelection[w.api.batchNamespace..":9:2"].id,9,"focus records target ID and join marker")
    enterExistingEditor(w,roles,800)
    local draft=copy(w.UI.getState().draft)
    w.UI.focusPlayerRole("admin",roster[2],w.api.batchNamespace)
    eq(w.UI.getState().selected,"builder","player focus does not switch roles inside the editor")
    eq(w.UI.getState().draft.name,draft.name,"player focus preserves the editor draft")
    eq(w.UI.getState().draft.permissions.heal,draft.permissions.heal,"player focus preserves draft grants")
    clickAdvanced(w,roles,"role_editor_discard",800)
    w.UI.focusPlayerRole("admin",roster[2],w.api.batchNamespace)
    eq(w.UI.getState().selected,"admin","player focus works again after discarding the editor")
end

-- Narrow layouts put the scope controls below each permission label.
for _,width in ipairs({800,400}) do
    local w=world();local role=customRole(w,{heal=1});local roles={role}
    enterExistingEditor(w,roles,width)
    clickAdvanced(w,roles,"permission_group_players",width)
    local api=advanced(w,roles,width)
    local label=buttonLabel(api,"Heal")
    local scope=api.controls.role_scope_heal_1
    check(label and scope,"target permission has label and scope controls")
    if api.viewports[1].w<620 then check(scope.y>label.y+18,"narrow scope controls sit below the label")
    else check(math.abs(scope.y-label.y)<12,"wide scope controls share the permission row") end
    check(api.controls.role_scope_heal_0 and api.controls.role_scope_heal_2,"target scopes expose off, self and any")
    clickAdvanced(w,roles,"permission_group_tools",width)
    api=advanced(w,roles,width)
    check(api.controls.role_scope_tools_all_0 and api.controls.role_scope_tools_all_2,"global scopes expose off and on")
    eq(api.controls.role_scope_tools_all_1,nil,"global scopes do not expose self-only")
end

-- Creation copies the selected Role into a separate editor and never assigns it implicitly.
do
    local w=world();local roles=builtinRoles(w);roles[#roles+1]=customRole(w,{heal=1,tools=2})
    w.api.dropdownChoice="builder"
    advanced(w,roles)
    clickAdvanced(w,roles,"role_create_custom")
    local state=w.UI.getState()
    eq(state.view,"edit","Create opens the separate editor")
    eq(state.draft.id,"","new draft has no persisted ID")
    eq(state.draft.permissions.heal,1,"new draft copies the selected Role grants")
    eq(state.draft.permissions.tools,2,"copy retains all selected Role grants")
    eq(state.draft.nameKey,nil,"new draft materializes the selected display name")
    eq(state.draft.initial,nil,"new draft does not inherit the selected Role reset baseline")
    eq(state.draft.builtin,false,"copy is a custom Role draft")
    local api=advanced(w,roles)
    eq(api.controls.role_apply,nil,"editor has no player assignment action")
    eq(api.controls.permission_view_batch_apply,nil,"editor has no player assignment action")
    eq(api.dropdowns.permission_view_role_select,nil,"editor has no Role picker that could discard its draft")
    api=clickAdvanced(w,roles,"role_editor_save")
    eq(api.commands[1].action,"role_save","creation uses the role save command")
    eq(api.commands[1].arg.id,"","creation sends a new-role draft")
end

-- A delegate can delete without edit, while proposed grants above their ceiling are disabled.
do
    local w=world();local roles=builtinRoles(w);roles[#roles+1]=customRole(w,{heal=2})
    w.api.enableAssignment({
        {id=1,name="Host",role="admin",host=true,profileReady=true,profileChallenge=1},
        {id=9,name="Player",role="guest",host=false,profileReady=true,profileChallenge=2},
    })
    w.api.canHandler=function(action)
        if action=="role_delete" then return true end
        if action=="role_save" or action=="role_assign" then return false end
        return true
    end
    w.api.dropdownChoice="builder"
    local api=advanced(w,roles)
    check(api.controls.role_edit_custom.disabled,"role_save/role_edit denial disables Edit")
    check(api.controls.role_create_custom.disabled,"role_save/role_create denial disables copying this stronger Role")
    check(not api.controls.role_delete.disabled,"role_delete remains independent of role_edit")
    check(api.controls.permission_view_target_9.disabled,"role_assign denial disables the target checkbox")
    check(api.controls.permission_view_batch_apply.disabled,"role_assign denial leaves no applicable target")
    api=clickAdvanced(w,roles,"role_delete")
    eq(api.asks[1].action,"role_delete","Delete asks the existing server confirmation")
    eq(api.asks[1].arg.id,"builder","Delete targets the selected Role")
    eq(w.UI.getState().view,"assign","Delete does not require opening the editor")

    local limited=world();local limitedRole=customRole(limited,{heal=1});local limitedRoles={limitedRole}
    limited.api.canHandler=function(action,_,arg)
        if action=="role_save" then return arg and arg.permissions and (arg.permissions.heal or 0)<=1 end
        return true
    end
    enterExistingEditor(limited,limitedRoles)
    clickAdvanced(limited,limitedRoles,"permission_group_players")
    api=advanced(limited,limitedRoles)
    check(api.controls.role_scope_heal_0 and not api.controls.role_scope_heal_0.disabled,"allowed lower scope remains editable")
    check(api.controls.role_scope_heal_1 and not api.controls.role_scope_heal_1.disabled,"current allowed scope remains editable")
    check(api.controls.role_scope_heal_2.disabled,"scope proposal above the actor ceiling is disabled")
    clickAdvanced(limited,limitedRoles,"role_scope_heal_2")
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
    check(api.controls.permission_view_batch_apply and api.controls.role_create_custom and api.controls.role_edit_custom and api.controls.role_reset and api.controls.role_delete,
        "expanded assignment actions remain available at width "..width)
    within(api.controls.permission_view_batch_apply,width,560,"Apply stays inside width "..width)
    eq(api.controls.permission_view_batch_apply.w,180,"expanded Apply stays a normal button, not a page-width action")
    eq(api.controls.role_apply,nil,"legacy Apply control is absent")
    within(api.controls.role_create_custom,width,560,"Create stays inside width "..width)
    within(api.controls.role_edit_custom,width,560,"Edit stays inside width "..width)
    within(api.controls.role_reset,width,560,"Reset stays inside width "..width)
    within(api.controls.role_delete,width,560,"Delete stays inside width "..width)
    eq(api.controls.role_create_custom.y,api.controls.role_edit_custom.y,"Copy and Edit share the first preview row")
    eq(api.controls.role_reset.y,api.controls.role_delete.y,"Reset and Delete share the second preview row")
    check(api.controls.role_reset.y>api.controls.role_create_custom.y,"preview actions use a two-row grid")
    eq(api.controls.role_create_custom.text,"Create role","preview names role creation")
    local creationHelp=false
    for _,help in ipairs(api.paragraphs) do if help.text=="Creates a custom role based on Guest." then creationHelp=true end end
    check(creationHelp,"preview explains custom role creation and its source")
    eq(api.controls.role_edit_custom.text,"Edit","preview uses a short Edit caption")
    eq(api.controls.role_reset.text,"Reset","preview uses a short Reset caption")
    eq(api.controls.role_delete.text,"Delete","preview uses a short Delete caption")
    check(api.viewports[1] and api.viewports[1].h>0,"permission list has a scroll viewport at width "..width)
    eq(api.viewports[1].x,0,"short expanded layout scrolls management and permissions together")
    check(api.controls.permission_view_batch_apply.y+api.controls.permission_view_batch_apply.h<=560,"short expanded Apply remains fixed in its footer")
    local clear=api.controls.permission_view_search_clear
    check(clear.x+clear.w<=width-60,"expanded search leaves room for the tab close button")
end

-- Preview Reset confirms through the shared RPC and uses only the version supplied by the server ACK.
do
    local w=world();local roles=builtinRoles(w)
    w.api.dropdownChoice="admin"
    local api=advanced(w,roles,400)
    check(api.controls.role_reset and not api.controls.role_reset.disabled,"preset Reset is available when authorized")
    api=clickAdvanced(w,roles,"role_reset",400)
    eq(api.asks[1].action,"role_reset","preset Reset asks for the reset RPC")
    eq(api.asks[1].target,0,"preset Reset targets the role manager")
    eq(api.asks[1].arg.id,"admin","preset Reset targets the selected preset")
    eq(api.asks[1].arg.version,0,"preset Reset sends the current version")
    eq(api.asks[1].message,"Reset Admin?","preset Reset asks before any execution")
    eq(#api.commands,0,"confirmation request does not send a command directly")
    eq(w.UI.getState().selected,"admin","confirmation leaves the selected preset in place")

    local changed=customRole(w,{heal=2})
    changed.name="Builder Plus";changed.version=7
    local custom={changed}
    local cw=world()
    advanced(cw,custom,400)
    api=clickAdvanced(cw,custom,"role_reset",400)
    eq(api.asks[1].action,"role_reset","custom Reset uses the same RPC")
    eq(api.asks[1].arg.id,"builder","custom Reset targets its own role")
    eq(api.asks[1].arg.version,7,"custom Reset sends the current role version")
    eq(#api.commands,0,"custom Reset also waits for explicit confirmation and ACK")
    eq(cw.UI.getState().selected,"builder","custom Reset confirmation does not switch the role")

    local restored=copy(changed)
    restored.name=restored.initial.name
    restored.permissions=copy(restored.initial.permissions)
    restored.version=8
    cw.UI.saved(restored)
    eq(cw.UI.getState().view,"assign","accepted reset ACK returns to assignment")
    advanced(cw,custom,400)
    eq(cw.UI.getState().draft.version,8,"ACK data becomes the visible accepted version")
    api=clickAdvanced(cw,custom,"role_reset",400)
    eq(api.asks[1].arg.version,8,"the next Reset uses the ACK version")
    eq(api.asks[1].arg.version,restored.version,"UI does not synthesize a reset version")

    cw.api.canHandler=function(action) return action~="role_reset" end
    api=advanced(cw,custom,400)
    check(api.controls.role_reset.disabled,"role_reset authorization independently gates Reset")
end

-- Editor Reset is a distinct button, but still asks for role_reset and leaves an unacknowledged draft intact.
do
    local w=world();local role=customRole(w,{heal=1});role.version=4;local roles={role}
    enterExistingEditor(w,roles)
    clickAdvanced(w,roles,"permission_group_players")
    clickAdvanced(w,roles,"role_scope_heal_2")
    local before=copy(w.UI.getState().draft)
    local api=advanced(w,roles)
    check(api.controls.role_editor_reset and not api.controls.role_editor_reset.disabled,"editor exposes an authorized Reset separately")
    api=clickAdvanced(w,roles,"role_editor_reset")
    eq(api.asks[1].action,"role_reset","editor Reset reuses the role_reset RPC")
    eq(api.asks[1].arg.id,"builder","editor Reset targets the persisted role")
    eq(api.asks[1].arg.version,4,"editor Reset includes the persisted version")
    eq(#api.commands,0,"editor Reset waits for confirmation instead of saving immediately")
    eq(w.UI.getState().view,"edit","without ACK the editor stays open")
    eq(w.UI.getState().draft.permissions.heal,before.permissions.heal,"without ACK the local draft remains unchanged")
end

-- The narrow layout scrolls manager and permissions together while Apply stays fixed.
do
    local w=world();local roles=builtinRoles(w);roles[#roles+1]=customRole(w,{heal=1})
    w.UI.openExpanded()
    local api=expanded(w,roles,561,380)
    eq(api.viewports[1].y,47,"narrow scroll region starts below fixed search")
    eq(api.controls.permission_view_batch_apply.y,341,"narrow Apply remains at the bottom of a 640x480 style layout")
    check(api.viewports[1].h>0,"narrow management and permission list can scroll in a short panel")
end

-- Expanded editor controls remain fixed and reachable at each supported width.
for _,width in ipairs({400,800,1200}) do
    local w=world();local role=customRole(w,{heal=1});local roles={role}
    enterExistingEditor(w,roles,width)
    w.UI.openExpanded()
    local api=expanded(w,roles,width,560)
    for _,id in ipairs({"role_editor_name","role_editor_save","role_editor_discard","role_editor_reload","role_editor_delete","role_editor_reset"}) do
        check(api.controls[id]~=nil,"expanded editor keeps "..id.." at width "..width)
        within(api.controls[id],width,560,id.." stays inside width "..width)
    end
    check(api.viewports[1] and api.viewports[1].h>0,"expanded editor scopes have a viewport at width "..width)
    if width<760 then
        check(api.viewports[1].y>api.controls.role_editor_reset.y+api.controls.role_editor_reset.h,
            "narrow editor scroll begins below fixed actions")
    else
        check(api.viewports[1].x>0,"wide editor keeps management beside its permission list")
    end
end

-- The narrow editor reserves its third action row before giving the remainder to the permissions viewport.
do
    local w=world();local role=customRole(w,{heal=1});local roles={role}
    enterExistingEditor(w,roles,561)
    w.UI.openExpanded()
    local api=expanded(w,roles,561,380)
    within(api.controls.role_editor_reset,561,380,"editor Reset fits the short narrow layout")
    check(api.viewports[1] and api.viewports[1].h>0,"short narrow editor retains a scrollable permission viewport")
    check(api.viewports[1].y>=api.controls.role_editor_reset.y+api.controls.role_editor_reset.h,
        "short narrow editor begins the permission viewport after the full fixed footer")
    check(api.viewports[1].y+api.viewports[1].h<=380,"short narrow permission viewport stays inside the panel")
end

-- Expanded mode shares draft/search/groups, keeps fixed actions, and sends the full draft.
do
    local w=world();local role=customRole(w,{heal=1,respawn=2,tools=2});local roles={role}
    enterExistingEditor(w,roles)
    clickAdvanced(w,roles,"permission_view_search")
    typeSearch(w,"infinite")
    clickAdvanced(w,roles,"permission_group_tools")
    clickAdvanced(w,roles,"role_scope_ammo_2")
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
    clickAdvanced(w,roles,"permission_group_players")
    w.api.pendingValue=true
    local api=advanced(w,roles)
    check(api.controls.role_scope_heal_1.disabled,"pending disables scope edits")
    check(api.controls.role_editor_save.disabled,"pending disables Save")
    check(api.controls.role_editor_reset.disabled,"pending disables Reset")
    check(not api.controls.permission_group_players.disabled,"pending allows category browsing")
    check(not api.controls.permission_view_search.disabled,"pending allows permission search")
    clickAdvanced(w,roles,"permission_view_search")
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

-- Pending still permits local Role selection and permission browsing, but blocks target changes and Apply.
do
    local w=world();local roles=builtinRoles(w);roles[#roles+1]=customRole(w,{heal=1})
    w.api.enableAssignment({
        {id=1,name="Host",role="admin",host=true,profileReady=true,profileChallenge=1},
        {id=9,name="Player",role="guest",host=false,profileReady=true,profileChallenge=2},
    })
    w.UI.openExpanded()
    w.api.pendingValue=true
    w.api.dropdownChoice="builder"
    local api=expanded(w,roles,400,560)
    eq(w.UI.getState().selected,"builder","pending leaves Role selection local")
    check(api.dropdowns.permission_view_role_select and not api.dropdowns.permission_view_role_select.disabled,
        "pending leaves the Role dropdown enabled")
    check(api.controls.permission_view_target_9.disabled,"pending disables target selection")
    check(api.controls.permission_view_batch_apply.disabled,"pending disables unified assignment")
    api=clickExpanded(w,roles,"permission_view_target_9",400,560)
    eq(w.UI.getState().batchSelected,0,"pending target input cannot alter the selection")
    check(api.controls.role_create_custom.disabled and api.controls.role_edit_custom.disabled and api.controls.role_reset.disabled and api.controls.role_delete.disabled,
        "pending disables role mutations")
    check(not api.controls.permission_view_search.disabled and not api.controls.permission_group_players.disabled,
        "pending leaves search and group browsing enabled")
    api=clickExpanded(w,roles,"permission_group_players",400,560)
    eq(w.UI.getState().groups.players,true,"pending still expands a permission group")
end

-- openExpanded clears capture while preserving the independent query and draft.
do
    local w=world();local role=customRole(w,{heal=1});local roles={role}
    enterExistingEditor(w,roles)
    clickAdvanced(w,roles,"permission_view_search")
    typeSearch(w,"heal")
    clickAdvanced(w,roles,"role_editor_name")
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
    clickAdvanced(w,roles,"role_editor_name")
    check(w.UI.getState().nameFocused,"name field owns capture")
    clickAdvanced(w,roles,"permission_view_search")
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

-- Unified assignment always uses a host-free checkbox list and owns its selection state.
local function batchRoster()
    local roster={{id=1,name="Host",role="admin",host=true,profileReady=true,profileChallenge=1}}
    for id=9,19 do
        roster[#roster+1]={id=id,name="Player "..id,role="guest",host=false,profileReady=true,profileChallenge=id-7}
    end
    return roster
end
do
    local w=world();local roles=builtinRoles(w);local api=w.api
    local host={id=1,name="Host",role="admin",host=true,profileReady=true,profileChallenge=1}
    api.enableAssignment({host})
    api.beginDraw();w.UI.draw(api,roles,host,520)
    eq(#api.rows,0,"host-only lobby has its own empty target state")
    local emptyState=false;for _,paragraph in ipairs(api.paragraphs) do if paragraph.text=="There are no other players in this session." then emptyState=true end end
    check(emptyState,"empty state explains that no assignment target exists")
    eq(api.controls.permission_view_batch_apply.disabled,true,"host-only Apply is disabled")
    check(not api.controls.permission_view_expand.disabled,"role management still works in the empty state")
    eq(w.UI.getState().batchSelected,0,"host is never inserted into batch state")
end
do
    local w=world();local roles=builtinRoles(w);local api=w.api
    local roster={
        {id=1,name="Host",role="admin",host=true,profileReady=true,profileChallenge=1},
        {id=9,name="Player",role="guest",host=false,profileReady=true,profileChallenge=2},
    }
    api.enableAssignment(roster);api.dropdownChoice="self";api.beginDraw();w.UI.draw(api,roles,roster[2],520)
    check(api.controls.permission_view_target_9~=nil,"one-player lobby shows the eligible target")
    eq(api.controls.permission_view_batch_apply.disabled,true,"Apply is disabled before marking a target")
    api.click="permission_view_target_9";api.beginDraw();w.UI.draw(api,roles,roster[2],520)
    eq(w.UI.getState().batchSelected,1,"single-target selection uses the same list state")
    check(w.UI.hasBatchSelection(),"hasBatchSelection reflects a marked target")
    api.click="permission_view_batch_apply";api.beginDraw();w.UI.draw(api,roles,roster[2],520)
    local ask=api.asks[#api.asks]
    eq(ask.action,"roles_assign_many","single-target Apply uses the collective RPC")
    eq(ask.target,0,"collective assignment has no individual target argument")
    eq(ask.arg.role,"self","Role dropdown supplies the destination")
    eq(ask.arg.host,api.batchNamespace,"assignment snapshot is bound to the host namespace")
    eq(ask.arg.actorJoin,1,"assignment snapshot includes the author's join marker")
    eq(#ask.arg.targets,1,"single-target confirmation contains exactly one target")
    eq(ask.arg.targets[1].id,9,"single-target confirmation captures the selected ID")
    eq(ask.arg.targets[1].join,2,"single-target confirmation captures the selected join marker")
    check(ask.message:find("Self",1,true) and ask.message:find("1",1,true),"confirmation names the destination and target count")
    eq(#api.commands,0,"assignment waits for confirmation")
end
do
    local w=world();local roles=builtinRoles(w);local api=w.api;local roster=batchRoster()
    roster[2].role="self" -- Selecting an unchanged Role is allowed, but Apply omits that player.
    roster[3].profileReady=false
    roster[4].profileReady=nil
    api.enableAssignment(roster);api.heightValue=800;api.dropdownChoice="self"
    api.beginDraw();w.UI.draw(api,roles,roster[2],1000)
    api.click="permission_view_mark_all";api.beginDraw();w.UI.draw(api,roles,roster[2],1000)
    eq(w.UI.getState().batchSelected,9,"Mark all selects ready non-host targets across every page")
    eq(#api.rows,6,"target pages show no more than six rows")
    check(api.controls.permission_view_target_10.disabled,"profileReady=false remains restrictive")
    check(api.controls.permission_view_target_11.disabled,"missing profileReady remains restrictive")
    check(api.controls.permission_view_batch_page_next~=nil,"twelve-player lobby exposes pagination")
    api.click="permission_view_batch_page_next";api.beginDraw();w.UI.draw(api,roles,roster[2],1000)
    eq(w.UI.getState().batchPage,2,"Next opens the later page")
    eq(w.UI.getState().batchSelected,9,"marks survive pagination")
    check(#api.rows<=6,"later pages also cap the visible rows at six")
    api.click="permission_view_clear";api.beginDraw();w.UI.draw(api,roles,roster[2],1000)
    eq(w.UI.getState().batchSelected,0,"Clear unmarks targets from all pages")
    eq(api.controls.permission_view_batch_apply.disabled,true,"empty selection cannot be applied")
    api.click="permission_view_mark_all";api.beginDraw();w.UI.draw(api,roles,roster[2],1000)
    eq(w.UI.getState().batchSelected,9,"Mark all can be used again after Clear")
    api.canHandler=function(action,target)
        return not (action=="role_assign" and target==14)
    end
    api.beginDraw();w.UI.draw(api,roles,roster[2],1000)
    api.click="permission_view_batch_apply";api.beginDraw();w.UI.draw(api,roles,roster[2],1000)
    local ask=api.asks[#api.asks]
    eq(ask.action,"roles_assign_many","multi-target Apply uses the same collective RPC")
    eq(#ask.arg.targets,7,"Apply filters unchanged and unauthorized target Roles")
    for _,target in ipairs(ask.arg.targets) do check(target.id~=9 and target.id~=14,"snapshot excludes unchanged or denied target") end
    check(ask.message:find("Self",1,true) and ask.message:find("7",1,true),"multi-target confirmation reports eligible count")
    local snapshot=copy(ask.arg)
    api.batchPlayers[2].profileChallenge=99
    api.batchNamespace=string.rep("b",32)
    api.beginDraw();w.UI.draw(api,roles,roster[2],1000)
    eq(w.UI.getState().batchSelected,0,"reused IDs and changed namespaces clear stale selection")
    eq(ask.arg.targets[1].id,snapshot.targets[1].id,"pending confirmation keeps its target snapshot")
    eq(ask.arg.host,snapshot.host,"pending confirmation keeps its host snapshot")
end
do
    local w=world();local roles=builtinRoles(w);local api=w.api;local roster=batchRoster()
    api.enableAssignment(roster);api.dropdownChoice="admin";api.beginDraw();w.UI.draw(api,roles,roster[2],520)
    api.click="permission_view_target_9";api.beginDraw();w.UI.draw(api,roles,roster[2],520)
    api.canHandler=function(action) return action~="roles_assign_many" end
    api.beginDraw();w.UI.draw(api,roles,roster[2],520)
    check(api.controls.permission_view_batch_apply.disabled,"role_assign_many authority gates the unified Apply")
    api.click="permission_view_batch_apply";api.beginDraw();w.UI.draw(api,roles,roster[2],520)
    eq(#api.asks,0,"denied collective assignment never asks for confirmation")
    w.UI.openExpanded();api.beginDraw();w.UI.drawExpanded(api,roles,roster[2],1000,700)
    eq(w.UI.getState().batchSelected,1,"opening the expanded manager preserves marked targets")
    w.UI.closeExpanded()
end

print("PASS permission UI categories, scopes, search, viewport and ACK state: "..assertions.." assertions")
