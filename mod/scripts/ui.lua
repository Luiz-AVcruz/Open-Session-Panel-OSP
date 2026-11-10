-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Rendering and input are local; gameplay changes are confirmed by the server.
function OSP.installClient()
    local flightInputReport,flightInputSequence=nil,0
    local strengthInputReport,strengthInputSequence=nil,0
    local ROOT="savegame.mod.osp_beta."
    local menu,tab,selected=false,"players",nil
    local selectedJoin,selectedHost=nil,nil
    local toolMode,filter="global","all"
    local tipKey,tipSince,tooltip=nil,nil,nil
    local function resetTooltip() tipKey=nil;tipSince=nil;tooltip=nil end
    local toolsPopup=nil
    local collectivePopup=nil
    local collectiveScope="player"
    local collectiveRole="guest"
    local collectiveExcludeSelf=false
    local collectivePage=1
    local collectiveSelection={}
    local collectiveHostNamespace=nil
    local collectiveActorJoin=nil
    local shortcuts=OSP.Shortcuts
    local shortcutRequest,shortcutNotice,shortcutUntil=nil,nil,0
    local search=OSP.ToolSearch
    local movementSettings=nil
    local pages={players=1,tools=1,activity=1}
    local scroll,maxScroll,bodyHovered=0,0,false
    local permissionViewport=nil
    local permissionWheel=0
    local dropdown=nil
    local dropdownDrawing=false
    local function closeDropdown() dropdown=nil end
    local function permissionExpanded() return OSP.PermissionUI.isExpanded() end
    local typing,capturing,draft=false,false,""
    local confirm,status,statusUntil,notice,noticeUntil=nil,nil,0,nil,0
    local seq,pending,sentAt,lastAction=0,nil,0,nil
    local numericFrame={time=0}
    local sentInInputFrame=false
    local identityHost,identityRetry=nil,0
    local identityJoin,identityPending=nil,nil
    local me=0
    local controls,layout={},{}
    local mouseX,mouseY=0,0
    local drawOx,drawOy=0,0
    local clickConsumed=false
    local lmbPressed=false
    local clip=nil
    local C=OSP.Theme.colors()
    local navigation=OSP.Navigation
    local viewMode=OSP.ViewMode.resolve()
    local function solo() return viewMode=="single" end
    local function eligible(id) return OSP.ViewMode.eligible(id,viewMode) end
    local function personalTab(id) return id=="settings" or id=="appearance" or id=="about" or id=="debug" end
    local function lang() return GetString(ROOT.."language")=="pt" and "pt" or "en" end
    OSP.getLanguage=lang
    local function T(k,...) return OSP.L(k,...) end
    local function state() return shared and shared.osp or nil end
    local function roster() local s=state();return s and s.players or {} end
    local function findPlayer(id) for _,p in ipairs(roster()) do if p.id==id then return p end end end
    local collectiveRequestEligible
    local roleBatchRequestEligible
    local function captureTargetContext(target)
        local s=state();local p=findPlayer(target);local namespace=s and s.profileHost;local challenge=p and p.profileChallenge
        if type(namespace)~="string" or #namespace~=32 or not namespace:match("^[0-9a-f]+$")
            or not OSP.finite(challenge) or challenge<1 or challenge%1~=0 then return nil end
        return {host=namespace,targetJoin=challenge}
    end
    local function sameTargetContext(target,expected)
        if type(expected)~="table" then return false end
        for key in pairs(expected) do if key~="host" and key~="targetJoin" then return false end end
        local current=captureTargetContext(target)
        return current~=nil and expected.host==current.host and expected.targetJoin==current.targetJoin
    end
    local function host() return IsPlayerHost(me) end
    local function admin() local p=findPlayer(me);return host() or (p and p.admin==true) or false end
    local function ownPermissions()
        local p=findPlayer(me)
        return p and p.permissions or OSP.Permissions.resolve(p and p.admin and "admin" or "guest").permissions
    end
    local function rolesAccess() return host() or OSP.Permissions.canManageRoles(ownPermissions()) end
    local function allowed(action,target,arg)
        if action=="players_group" then return collectiveRequestEligible and collectiveRequestEligible(arg) or false end
        if action=="roles_assign_many" then return roleBatchRequestEligible and roleBatchRequestEligible(arg) or false end
        if action=="collective_future" then return host() and type(arg)=="boolean" end
        if host() then return true end
        local P=OSP.Permissions;local values=ownPermissions()
        if not P.allows(values,action,target,arg,me) then return false end
        local custom={}
        for _,r in ipairs(state() and state().templates or {}) do custom[r.id]=r end
        local current,proposed,templateId
        if action=="role_assign" or action=="reset_player" then
            local p=findPlayer(target)
            if not p or p.host or p.profileReady==false then return false end
            current=p.permissions or P.resolve(p.role or (p.admin and "admin" or "guest"),custom).permissions
            if action=="role_assign" then
                if type(arg)~="table" then return false end
                proposed=P.resolve(arg.id,custom).permissions
            else proposed=P.resolve("guest",custom).permissions end
        elseif action=="role_save" then
            if type(arg)~="table" then return false end
            proposed=P.normalize(arg.permissions)
            if not proposed then return false end
            if arg.id~="" then
                local r=custom[arg.id];if not r then return false end
                current=r.permissions;templateId=arg.id
            end
        elseif action=="role_delete" or action=="role_reset" then
            local r=type(arg)=="table" and custom[arg.id]
            if not r then return false end
            current=r.permissions;templateId=arg.id
            if action=="role_reset" then
                if not r.initial then return false end
                proposed=r.initial.permissions
            else proposed=P.resolve("guest",custom).permissions end
        end
        if templateId then
            for _,p in ipairs(roster()) do if p.host and p.role==templateId then return false end end
        end
        return (not current or P.within(current,values)) and (not proposed or P.within(proposed,values))
    end
    local function permittedControl(id)
        if id=="effects_on_load_on" or id=="effects_on_load_off" or id=="collective_future_on" or id=="collective_future_off" then return host() and not pending end
        if id:match("^group_") then
            if id=="group_popup_close" then return true end
            if id=="group_popup_on" or id=="group_popup_off" then return true end
            if id:match("^group_scope_option_") or id:match("^group_role_option_") then return true end
            if id=="group_scope" or id=="group_role" or id=="group_exclude_self" or id=="group_mark_all" or id=="group_clear" then return true end
            if id:match("^group_page_") then return true end
            local playerId=tonumber(id:match("^group_manual_(%d+)$"))
            if playerId then return collectiveScope=="manual" end
            local action=id:match("^group_(%w+)$")
            return action=="god" or action=="fly" or action=="noclip" or action=="freeze"
                or action=="strength" or action=="ammo" or action=="heal" or action=="bring"
        end
        if id:match("^permission_view_") or id:match("^permission_group_") then return rolesAccess() end
        if id=="tab_permissions" or id:match("^permission_") or id:match("^role_") then return rolesAccess() and (not pending or id=="tab_permissions") end
        local target=selected or me
        local verb=id:match("^player_action_(.+)$")
        if verb then return allowed(verb,target) end
        if id=="speed_down" or id=="speed_up" then return allowed("speed",target) end
        if id=="player_speed_value" then return allowed("speed",target) end
        if id=="god_settings" then return target==me and allowed("god",target) end
        if id=="fly_settings" or id=="fly_speed_value" or id=="fly_boost_value" then return allowed("fly",target) end
        if id=="noclip_settings" or id=="noclip_speed_value" or id=="noclip_boost_value" then return allowed("noclip",target) end
        if id=="strength_settings" or id=="strength_force_value" or id=="strength_mass_value"
            or id=="strength_throw_on" or id=="strength_throw_off" or id=="strength_throw_speed_value"
            or id=="shortcut_strength" or id=="shortcut_clear_strength" then return allowed("strength",target) end
        if id=="ammo_settings" or id=="shortcut_ammo" or id=="shortcut_clear_ammo" then return allowed("ammo",target) end
        if id=="player_role_manage" then return rolesAccess() end
        if id=="reset_player" then return allowed("reset_player",target) end
        if id=="restart" or id=="reset_rules" then return allowed(id,0) end
        local key=id:match("^rule_(%a+)_")
        if key then return allowed("rule",0,{key=key}) end
        if id=="regen_on" or id=="regen_off" then return allowed("rule",0,{key="regen"}) end
        if id=="announcement_field" or id=="announcement_send" then return allowed("announce",0) end
        if id:match("^tool_more_") then return toolMode=="global" and allowed("tool_policy",0) or toolMode~="global" and allowed("tools_all",0) end
        if id=="tools_enable_everyone" or id=="tools_disable_everyone" or id=="tools_enable_results_everyone" or id=="tools_disable_results_everyone" or id:match("^tool_everyone_") then return allowed("tools_all",0) end
        if id=="tools_reset_filtered" or id:match("^tool_reset_") then return allowed("tool_policy",0) end
        if id=="tools_enable_filtered" or id=="tools_disable_filtered" or id=="tools_enable_results" or id=="tools_disable_results" then return toolMode=="global" and allowed("tool_policy",0) or toolMode~="global" and allowed("tools",target) end
        if id:match("^tool_") and not id:match("^tool_player_") and not id:match("^tool_mode_") then
            return toolMode=="global" and allowed("tool_policy",0) or toolMode~="global" and allowed("tool",target)
        end
        return true
    end
    local function roleLabel(p)
        if p.host then return T("host") end
        local wanted=p.role or (p.admin and "admin" or "guest")
        for _,role in ipairs(state() and state().templates or OSP.Permissions.list({})) do
            if role.id==wanted then return OSP.Permissions.name(role) end
        end
        return T("guest")
    end
    local function keybind() local k=GetString(ROOT.."menu_key");return OSP.validKey(k) and k or "p" end
    local function shortcutContextAllowed()
        -- Tool availability also becomes false while grabbing or using Plank.
        -- Check gameplay and current player state independently of the tool.
        return GetBool("game.player.interactive") and not GetBool("game.paused")
            and not GetBool("game.map.enabled") and IsPlayerValid(me)
            and GetPlayerHealth(me)>0 and GetPlayerVehicle(me)==0 and GetPlayerScreen(me)==0
    end
    local function setStatus(s,seconds) status=s;statusUntil=GetTime()+(seconds or 5) end
    local function checkConfirmationTarget()
        if confirm and confirm.target~=0 and not sameTargetContext(confirm.target,confirm.targetContext) then
            confirm=nil;setStatus(T("result_unavailable"));lmbPressed=false;clickConsumed=true;InputClear();return false
        end
        return true
    end
    local function shortcutMessage(action,message,seconds)
        shortcutNotice=T(action=="god" and "god_short" or action).." · "..message
        shortcutUntil=GetTime()+(seconds or 5);setStatus(shortcutNotice,seconds)
    end
    local function closeMovement() movementSettings=nil;OSP.NumberInput.cancel();shortcuts.cancel() end
    local function closeTools() toolsPopup=nil;search.blur() end
    local function clearManualSelection() collectiveSelection={} end
    local function resetCollective()
        collectiveScope="player";collectiveRole="guest";collectiveExcludeSelf=false;collectivePage=1
        clearManualSelection();collectivePopup=nil;closeDropdown()
        if OSP.PermissionUI.clearBatchSelection then OSP.PermissionUI.clearBatchSelection() end
    end
    local function selectPlayer(id)
        local p=findPlayer(id);local namespace=state() and state().profileHost
        local join=p and p.profileChallenge
        id=p and p.id or nil
        if selected~=id or selectedJoin~=join or selectedHost~=namespace then
            closeDropdown();resetTooltip();closeMovement();closeTools();confirm=nil
            OSP.PermissionUI.cancelInput();OSP.NumberInput.cancel()
        end
        selected=id;selectedJoin=join;selectedHost=namespace
    end
    local function resetSelection()
        selectPlayer(me);pages.players=1
    end
    local function validateSelection()
        local p=selected and findPlayer(selected)
        if not p or p.profileChallenge~=selectedJoin or (state() and state().profileHost)~=selectedHost then
            if selected then lmbPressed=false;numericFrame.mousePressed=false;clickConsumed=true;InputClear() end
            resetSelection()
        end
    end
    local function setTab(t,keepTarget)
        t=navigation.choose(t,function(id) return personalTab(id) or admin() and (id~="permissions" or rolesAccess()) end,eligible)
        if tab~=t then
            closeDropdown();resetTooltip();closeMovement();closeTools();scroll=0;confirm=nil;typing=false;capturing=false
            shortcuts.cancel();OSP.PermissionUI.closeExpanded();OSP.PermissionUI.cancelInput();OSP.NumberInput.cancel()
            resetCollective()
            if not keepTarget and navigation.selectionMode()=="leave" then resetSelection() end
            tab=t
        end
        if menu then navigation.rememberTab(t) end
    end
    local function setMenu(value)
        local changed=menu~=value
        shortcuts.cancel();capturing=false;resetTooltip()
        if changed and value then
            local wanted=navigation.openingMode()=="players" and "players" or navigation.lastTab()
            menu=true;validateSelection();setTab(wanted);confirm=nil
        elseif not value then
            menu=false;closeDropdown();closeMovement();closeTools();confirm=nil;typing=false
            OSP.PermissionUI.closeExpanded();OSP.PermissionUI.cancelInput();OSP.NumberInput.cancel()
            resetCollective()
            if changed and navigation.selectionMode()~="keep" then resetSelection() end
        end
    end
    local function refreshViewMode()
        local current=OSP.ViewMode.resolve()
        if current==viewMode then return end
        viewMode=current
        closeDropdown()
        resetTooltip();closeMovement();closeTools();confirm=nil;typing=false;capturing=false
        collectivePopup=nil
        shortcuts.cancel();OSP.PermissionUI.closeExpanded();OSP.PermissionUI.cancelInput();OSP.NumberInput.cancel()
        pages.players=1;pages.tools=1;scroll=0
        if menu then lmbPressed=false;clickConsumed=true;InputClear() end
        if solo() then resetCollective();selectPlayer(me);toolMode="global" elseif not allowed("tool_policy",0) then toolMode="player" end
        setTab(tab)
    end
    local function command(action,target,arg,expectedContext,frozenContext)
        if sentInInputFrame then setStatus(T("request_pending"));return false end
        target=target or 0
        local targetContext
        if target~=0 then
            if frozenContext then
                if not expectedContext or not sameTargetContext(target,expectedContext) then
                    setStatus(T("result_unavailable"));return false
                end
                targetContext=expectedContext
            else
                targetContext=captureTargetContext(target)
                if not targetContext then setStatus(T("result_unavailable"));return false end
            end
        end
        if not admin() or not allowed(action,target,arg) then setStatus(T("result_denied"));return false end
        if pending then setStatus(T("request_pending"));return false end
        seq=seq+1;pending=seq;sentAt=GetTime();lastAction=action
        setStatus(T("request_sent"),8)
        sentInInputFrame=true
        ServerCall("server.ospCommand",me,action,target,arg,pending,targetContext)
        return true
    end
    local function ask(action,target,arg,message)
        target=target or 0
        local targetContext
        if target~=0 then
            targetContext=captureTargetContext(target)
            if not targetContext then setStatus(T("result_unavailable"));return end
        end
        closeDropdown();typing=false;capturing=false;OSP.PermissionUI.cancelInput();OSP.NumberInput.cancel();InputClear()
        confirm={action=action,target=target,arg=arg,message=message,targetContext=targetContext}
    end
    local function rgb(c) UiColor(c[1],c[2],c[3],c[4] or 1) end
    local function rect(x,y,w,h,color)
        if w<=0 or h<=0 then return end
        UiPush();UiTranslate(x,y);rgb(color);UiRect(w,h);UiPop()
    end
    local function utf8clip(value,n)
        value=tostring(value or "");local starts={}
        for i=1,#value do local b=value:byte(i);if b<128 or b>=192 then starts[#starts+1]=i end end
        if #starts<=n then return value end
        local keep=math.max(0,n-3);return value:sub(1,(starts[keep+1] or 1)-1).."..."
    end
    local function label(x,y,value,size,color,width,bold)
        value=tostring(value or "")
        UiPush();UiTranslate(x,y);UiAlign("left top");UiFont(bold and "bold.ttf" or "regular.ttf",size)
        UiTextDisableWildcards(true);rgb(color or C.text)
        if width then
            UiWindow(width,size*1.35,true,true)
            if UiGetTextSize(value)>width then
                local lo,hi,best=3,#value,"..."
                while lo<=hi do local mid=math.floor((lo+hi)/2);local q=utf8clip(value,mid)
                    if UiGetTextSize(q)<=width then best=q;lo=mid+1 else hi=mid-1 end
                end
                value=best
            end
        end
        UiText(value);UiPop()
    end
    local function inside(x,y,w,h,mx,my) return mx>=x and my>=y and mx<x+w and my<y+h end
    local function button(id,x,y,w,h,value,kind,disabled,modal)
        disabled=disabled or not permittedControl(id) or (dropdown~=nil and not dropdownDrawing and id~=dropdown.id) or ((confirm~=nil or movementSettings~=nil or toolsPopup~=nil or collectivePopup~=nil or permissionExpanded()) and not modal)
        local controlDisabled=disabled
        local hitEnabled=not disabled
        local visible=true
        if clip then
            visible=x+w>clip.x and x<clip.x+clip.w and y+h>clip.y and y<clip.y+clip.h
            if not inside(clip.x,clip.y,clip.w,clip.h,mouseX,mouseY) then hitEnabled=false end
        end
        if not visible then return false end
        local hover=hitEnabled and inside(x,y,w,h,mouseX,mouseY)
        -- Use the painted rectangle and viewport for input too. Native button
        -- hit registration must not depend on a preceding clipped text draw.
        -- React on press, once per frame; holding/releasing never repeats it.
        local clicked=hover and not clickConsumed and (lmbPressed or InputPressed("lmb"))
        if clicked then
            clickConsumed=true
            local nextTab=id:match("^tab_(.+)$")
            local nextPlayer=tonumber(id:match("^player_(%d+)$"))
            local contextChange=id=="close" or nextTab and nextTab~=tab or nextPlayer and nextPlayer~=selected
                or id=="role_target_prev" or id=="role_target_next" or id=="tool_player_prev" or id=="tool_player_next"
            if contextChange then OSP.NumberInput.cancel() else OSP.NumberControl.beforeAction() end
            shortcuts.cancel();capturing=false;search.blur()
        end
        local col,edge=OSP.Theme.buttonPaint(C,kind,hover,clicked)
        if col then rect(x,y,w,h,col) end
        if edge then
            rect(x,y,w,1,edge);rect(x,y+h-1,w,1,edge)
            rect(x,y,1,h,edge);rect(x+w-1,y,1,h,edge)
        end
        if kind=="active" then rect(x,y,3,h,C.accent) end
        local textColor=controlDisabled and C.disabled or (kind=="danger" and C.danger or C.text)
        if kind=="recovery" then textColor={1,1,1,1} end
        label(x+10,y+(h-17)/2,value,17,textColor,w-20)
        local x0,y0,x1,y1=x,y,x+w,y+h
        if clip then x0=math.max(x0,clip.x);y0=math.max(y0,clip.y);x1=math.min(x1,clip.x+clip.w);y1=math.min(y1,clip.y+clip.h) end
        controls[id]={x=drawOx+x0,y=drawOy+y0,w=math.max(0,x1-x0),h=math.max(0,y1-y0),disabled=controlDisabled}
        return clicked==true
    end
    local function dropdownField(id,x,y,w,h,items,current,disabled,onSelect,expanded)
        local caption="?";local index=1
        for n,item in ipairs(items) do if item.id==current then caption=item.label;index=n;break end end
        local open=dropdown and dropdown.id==id and dropdown.expanded==expanded
        if button(id,x,y,w,h,"",open and "active" or "outlined",disabled or confirm~=nil,expanded) then
            if open then closeDropdown()
            else
                OSP.PermissionUI.cancelInput()
                dropdown={id=id,expanded=expanded,first=1,highlight=index,keyboard=true}
                open=true
            end
        end
        label(x+10,y+(h-16)/2,caption,16,disabled and C.disabled or C.text,w-44)
        UiPush();UiTranslate(x+w-26,y+(h-16)/2);rgb(C.muted);UiImage("MOD/ui/section-down.png");UiPop()
        if open and dropdown then
            local d=dropdown
            d.items=items;d.current=current;d.onSelect=onSelect;d.seen=true
            d.field={x=drawOx+x,y=drawOy+y,w=w,h=h}
            if disabled or confirm or (tab=="permissions" and not rolesAccess()) then closeDropdown() end
        end
    end
    local function numberField(id,x,y,w,h,value,minimum,maximum,decimals,onCommit,disabled,caption,modal,extra)
        local visible=not clip or x+w>clip.x and x<clip.x+clip.w and y+h>clip.y and y<clip.y+clip.h
        local pointerAllowed=not clip or inside(clip.x,clip.y,clip.w,clip.h,mouseX,mouseY)
        local originTab,originMode,originPopup=tab,viewMode,movementSettings
        local target=selected or me
        local targeted=id:match("^player_") or id:match("^fly_") or id:match("^noclip_") or id:match("^strength_")
        local context=targeted and captureTargetContext(target) or nil
        local function valid()
            return menu and tab==originTab and viewMode==originMode and movementSettings==originPopup
                and not confirm and not pending and permittedControl(id)
                and (not targeted or context and (selected or me)==target and sameTargetContext(target,context))
        end
        local blocked=disabled or not permittedControl(id) or (movementSettings or toolsPopup or permissionExpanded()) and not modal
        UiPush();UiTranslate(x,y)
        local geometry=OSP.NumberControl.draw({id=id,w=w,h=h,value=value,minimum=minimum,maximum=maximum,
            decimals=decimals,onCommit=onCommit,colors=C,disabled=blocked,caption=caption,visible=visible,
            pointerAllowed=pointerAllowed,consumed=clickConsumed,valid=valid,
            gradient=extra and extra.gradient,unset=extra and extra.unset,
            consume=function() clickConsumed=true end,
            focus=function() typing=false;capturing=false;shortcuts.cancel();search.blur();OSP.PermissionUI.cancelInput() end})
        UiPop()
        if geometry then
            local x0,y0,x1,y1=x,y,x+w,y+h
            if clip then x0=math.max(x0,clip.x);y0=math.max(y0,clip.y);x1=math.min(x1,clip.x+clip.w);y1=math.min(y1,clip.y+clip.h) end
            controls[id]={x=drawOx+x0,y=drawOy+y0,w=x1-x0,h=y1-y0,disabled=blocked or not valid(),numeric=true,
                textX=drawOx+x+geometry.textX,textW=geometry.textW}
        end
    end
    local function title(name,subtitle)
        label(0,0,name,25,C.text,layout.contentW,true)
        if subtitle then label(0,33,subtitle,15,C.muted,layout.contentW) end
        rect(0,62,layout.contentW,1,C.line)
    end
    local function page(key,n,per,x,y)
        local last=math.max(1,math.ceil(n/per));pages[key]=math.max(1,math.min(last,pages[key] or 1))
        label(x,y+7,T("page_count",pages[key],last),15,C.muted,150)
        if button(key.."_prev",x+145,y,100,32,"< "..T("prev_short"),"plain",pages[key]<=1) then pages[key]=pages[key]-1 end
        if button(key.."_next",x+253,y,100,32,T("next_short").." >","plain",pages[key]>=last) then pages[key]=pages[key]+1 end
        return pages[key]
    end
    local function selectedPlayer()
        if solo() then selectPlayer(me);return findPlayer(me) end
        local list=roster()
        validateSelection()
        if not selected and #list>0 then selectPlayer(findPlayer(me) and me or list[1].id) end
        return findPlayer(selected)
    end
    local function actionForPlayer(p,verb,caption,value,kind)
        if verb=="kill" then ask("kill",p.id,nil,T("confirm_kill",utf8clip(p.name,24)))
        else command(verb,p.id,value) end
    end
    local function checkboxButton(id,x,y,w,h,text,checked,disabled)
        local clicked=button(id,x,y,w,h,"",checked and "active" or "outlined",disabled)
        local box=16;local bx=x+9;local by=y+(h-box)/2
        rect(bx,by,box,box,C.muted);rect(bx+1,by+1,box-2,box-2,C.side)
        if checked then rect(bx+4,by+4,box-8,box-8,C.accent) end
        label(x+33,y+(h-17)/2,text,15,disabled and C.disabled or C.text,math.max(0,w-40))
        return clicked
    end
    local function collectiveIdentityKey(id,join,namespace)
        return tostring(namespace)..":"..tostring(id)..":"..tostring(join)
    end
    local function validJoin(value) return OSP.finite(value) and value>=1 and value%1==0 end
    local function validateCollectiveSelection()
        local s=state();local namespace=s and s.profileHost
        for key,entry in pairs(collectiveSelection) do
            local p=findPlayer(entry.id)
            if entry.host~=namespace or not p or p.profileChallenge~=entry.join then collectiveSelection[key]=nil end
        end
    end
    local function groupMatches(p,scope,role,excludeSelf)
        if scope=="manual" then
            local namespace=state() and state().profileHost
            return collectiveSelection[collectiveIdentityKey(p.id,p.profileChallenge,namespace)]~=nil
        end
        local C=OSP.Collective
        if C and C.matches then return C.matches(p,scope,role,excludeSelf,me) end
        if excludeSelf and p.id==me then return false end
        if scope=="role" then return not p.host and (p.role or (p.admin and "admin" or "guest"))==role end
        return scope=="all"
    end
    local function groupTargets(action,scope,role,excludeSelf,value,snapshot)
        local result={};local ns=state() and state().profileHost
        if not snapshot then validateCollectiveSelection() end
        local candidates=snapshot or roster()
        local hostActor=host()
        local globalAction=action=="heal" and "heal_all" or action=="bring" and "bring_all" or nil
        if globalAction and not allowed(globalAction,0) then return result end
        for _,candidate in ipairs(candidates) do
            local p
            if snapshot then
                local current=findPlayer(candidate.id)
                if current and current.profileChallenge==candidate.join then p=current end
            else p=candidate end
            if p and validJoin(p.profileChallenge) and groupMatches(p,scope,role,excludeSelf) then
                local eligible=true
                if action=="bring" and (p.id==me or (p.health or 0)<=0) then eligible=false end
                if action=="god" or action=="fly" or action=="noclip" or action=="freeze" or action=="strength" or action=="ammo" then
                    if not hostActor and p.host then eligible=false end
                    if hostActor and p.profileReady~=true then eligible=false end
                    if not hostActor and p.id==me and value==false and p.profileReady~=true then eligible=false end
                    if not allowed(action,p.id) then eligible=false end
                elseif not hostActor and p.host then eligible=false end
                if eligible then
                    if snapshot then result[#result+1]={id=candidate.id,join=candidate.join}
                    else result[#result+1]={id=p.id,join=p.profileChallenge,name=p.name,player=p} end
                end
            end
        end
        return result
    end
    local function currentRoleId(p) return p and (p.role or (p.admin and "admin" or "guest")) end
    local function roleExists(id)
        for _,role in ipairs(state() and state().templates or OSP.Permissions.list({})) do if role.id==id then return true end end
        return false
    end
    collectiveRequestEligible=function(arg)
        local C=OSP.Collective;local s=state();local own=findPlayer(me)
        if type(arg)~="table" or not s or arg.host~=s.profileHost or not own or arg.actorJoin~=own.profileChallenge
            or (arg.scope~="all" and arg.scope~="role" and arg.scope~="manual")
            or type(arg.excludeSelf)~="boolean" or type(arg.targets)~="table" then return false end
        if C and C.validRequest and not C.validRequest(arg) then return false end
        if arg.scope=="role" and (type(arg.role)~="string" or not roleExists(arg.role)) then return false end
        if arg.scope~="role" and arg.role~=nil then return false end
        local action=arg.action
        if type(action)~="string" then return false end
        local effect=C and C.effects and C.effects[action]~=nil
        if not effect and action~="heal" and action~="bring" then return false end
        local targets=groupTargets(action,arg.scope,arg.role,arg.excludeSelf,arg.value,arg.targets)
        if #targets>0 then return true end
        local future=host() and s.collectiveFuture==true and (arg.scope=="all" or arg.scope=="role") and effect
        return future==true and #arg.targets==0
    end
    roleBatchRequestEligible=function(arg)
        local C=OSP.Collective;local s=state();local own=findPlayer(me)
        if type(arg)~="table" or not s or arg.host~=s.profileHost or not own or arg.actorJoin~=own.profileChallenge
            or type(arg.role)~="string" or not roleExists(arg.role) or type(arg.targets)~="table" then return false end
        if C and C.validAssignment and not C.validAssignment(arg) then return false end
        local seen,count={},0
        for _,target in ipairs(arg.targets) do
            if type(target)~="table" or type(target.id)~="number" or type(target.join)~="number" or seen[target.id] then return false end
            seen[target.id]=true
            local p=findPlayer(target.id)
            if p and p.profileChallenge==target.join and not p.host and p.profileReady==true
                and currentRoleId(p)~=arg.role and allowed("role_assign",p.id,{id=arg.role}) then count=count+1 end
        end
        return count>0
    end
    local function collectiveRequest(action,value,scope,role,excludeSelf,targets)
        local s=state();local own=findPlayer(me)
        if not s or type(s.profileHost)~="string" or not own or type(own.profileChallenge)~="number" then return nil end
        local arg={host=s.profileHost,actorJoin=own.profileChallenge,action=action,scope=scope,
            excludeSelf=excludeSelf==true,targets={}}
        if scope=="role" then arg.role=role end
        if OSP.Collective and OSP.Collective.effects[action] then arg.value=value==true end
        for _,p in ipairs(targets or {}) do arg.targets[#arg.targets+1]={id=p.id,join=p.join} end
        return arg
    end
    local function groupActionState(action,targets)
        if #targets==0 then return "none" end
        local enabled=0
        for _,target in ipairs(targets) do
            local p=target.player or findPlayer(target.id)
            if p and ((action=="god" and p.god==true) or (action=="fly" and p.fly==true)
                or (action=="noclip" and p.noclip==true) or (action=="freeze" and p.freeze==true)
                or (action=="strength" and p.strength==true) or (action=="ammo" and p.ammo==true)) then enabled=enabled+1 end
        end
        if enabled==0 then return "off" end
        if enabled==#targets then return "on" end
        return "mixed"
    end
    local function openCollectivePopup(action,targets,scope,role,excludeSelf)
        local frozen={};for _,p in ipairs(targets) do frozen[#frozen+1]={id=p.id,join=p.join,name=p.name} end
        local base=collectiveRequest(action,nil,scope,role,excludeSelf,frozen)
        if not base then setStatus(T("result_unavailable"));return end
        collectivePopup={action=action,base=base,host=base.host,actorJoin=base.actorJoin,names={}}
        for _,p in ipairs(frozen) do collectivePopup.names[#collectivePopup.names+1]=p.name end
        closeDropdown();OSP.NumberControl.beforeAction();OSP.PermissionUI.cancelInput();InputClear()
    end
    local function sendCollective(base,value)
        local arg=OSP.copy(base);arg.value=value
        collectivePopup=nil
        command("players_group",0,arg)
    end
    local function drawCollectivePlayers(w)
        local scope=collectiveScope;local y=78
        local excludeSelf=scope~="manual" and collectiveExcludeSelf or false
        validateCollectiveSelection()
        if scope=="all" then
            if checkboxButton("group_exclude_self",0,y,math.min(w,340),34,T("group_exclude_self"),collectiveExcludeSelf,false) then
                collectiveExcludeSelf=not collectiveExcludeSelf
            end
            y=y+45
        elseif scope=="role" then
            local roleItems={}
            for _,role in ipairs(state() and state().templates or OSP.Permissions.list({})) do
                roleItems[#roleItems+1]={id=role.id,label=OSP.Permissions.name(role)}
            end
            if not roleExists(collectiveRole) and #roleItems>0 then collectiveRole=roleItems[1].id end
            local roleWidth=math.min(360,w)
            dropdownField("group_role",0,y,roleWidth,36,roleItems,collectiveRole,#roleItems==0,function(id) collectiveRole=id end,false)
            if #roleItems>0 and checkboxButton("group_exclude_self",roleWidth+10,y,math.min(270,w-roleWidth-10),36,
                T("group_exclude_self"),collectiveExcludeSelf,false) then
                collectiveExcludeSelf=not collectiveExcludeSelf
            end
            y=y+48
        elseif scope=="manual" then
            local selectedCount=0;for _ in pairs(collectiveSelection) do selectedCount=selectedCount+1 end
            local gap=8;local buttonW=math.min(150,(w-2*gap)/3)
            if button("group_mark_all",0,y,buttonW,34,T("group_mark_all"),"plain",#roster()==0) then
                local ns=state() and state().profileHost
                for _,p in ipairs(roster()) do
                    if validJoin(p.profileChallenge) then
                        collectiveSelection[collectiveIdentityKey(p.id,p.profileChallenge,ns)]={id=p.id,join=p.profileChallenge,host=ns}
                    end
                end
            end
            if button("group_clear",buttonW+gap,y,buttonW,34,T("group_clear"),"plain",selectedCount==0) then clearManualSelection() end
            label(buttonW*2+gap*2,y+9,T("group_selected_count",selectedCount),14,C.muted,math.max(0,w-(buttonW*2+gap*2)))
            y=y+42
            local rows=math.max(2,math.min(5,math.floor((layout.contentH-220)/42)))
            local last=math.max(1,math.ceil(#roster()/rows));collectivePage=math.max(1,math.min(last,collectivePage))
            local first=(collectivePage-1)*rows+1
            for i=first,math.min(#roster(),first+rows-1) do
                local p=roster()[i];local key=collectiveIdentityKey(p.id,p.profileChallenge,state() and state().profileHost)
                local checked=collectiveSelection[key]~=nil
                local blocked=not validJoin(p.profileChallenge) or not host() and p.host
                if checkboxButton("group_manual_"..p.id,0,y,math.min(w,510),34,utf8clip(p.name,24).."  ·  "..roleLabel(p),checked,blocked) then
                    if checked then collectiveSelection[key]=nil
                    else collectiveSelection[key]={id=p.id,join=p.profileChallenge,host=state() and state().profileHost} end
                end
                y=y+39
            end
            if #roster()>rows then
                local pageLabel=T("page_count",collectivePage,last)
                label(0,y+7,pageLabel,15,C.muted,140)
                if button("group_page_prev",145,y,100,32,"< "..T("prev_short"),"plain",collectivePage<=1) then collectivePage=collectivePage-1 end
                if button("group_page_next",253,y,100,32,T("next_short").." >","plain",collectivePage>=last) then collectivePage=collectivePage+1 end
                y=y+38
            end
            y=y+5
        end

        local actions={"god","fly","noclip","freeze","strength","ammo","heal","bring"}
        local cols=w>=520 and 2 or 1;local gap=8;local bw=(w-gap*(cols-1))/cols
        local future=host() and state() and state().collectiveFuture==true and (scope=="all" or scope=="role")
        local rowY=y
        for i,action in ipairs(actions) do
            local x=((i-1)%cols)*(bw+gap);local py=rowY+math.floor((i-1)/cols)*44
            local candidates=groupTargets(action,scope,scope=="role" and collectiveRole or nil,excludeSelf,nil)
            local stateKey=(action=="heal" or action=="bring") and nil or groupActionState(action,candidates)
            local futureEmpty=future and stateKey=="none" and action~="heal" and action~="bring"
            local caption
            if action=="heal" then caption=T("group_heal_count",#candidates)
            elseif action=="bring" then caption=T("group_bring_count",#candidates)
            else caption=T(action=="god" and "god_short" or action).."  ·  "..T(stateKey=="on" and "group_state_on" or stateKey=="off" and "group_state_off" or stateKey=="mixed" and "group_state_mixed" or "group_state_none") end
            local pendingNow=pending~=nil
            if action=="heal" or action=="bring" then
                local arg=collectiveRequest(action,nil,scope,collectiveRole,action=="bring" or excludeSelf,candidates)
                local canRequest=not pendingNow and arg and allowed("players_group",0,arg)
                if button("group_"..action,x,py,bw,38,caption,"plain",not canRequest) then command("players_group",0,arg) end
            else
                local desired=stateKey~="on"
                local arg=collectiveRequest(action,desired,scope,collectiveRole,excludeSelf,candidates)
                local canRequest=not pendingNow and arg and allowed("players_group",0,arg)
                if button("group_"..action,x,py,bw,38,caption,stateKey=="on" and "active" or "plain",pendingNow or not canRequest and not futureEmpty) then
                    if stateKey=="mixed" or futureEmpty then openCollectivePopup(action,candidates,scope,collectiveRole,excludeSelf)
                    else sendCollective(arg,desired) end
                end
            end
        end
        local groupRows=math.ceil(#actions/cols)
        local yBottom=rowY+groupRows*44
        local totalEligible=0
        for _,action in ipairs(actions) do totalEligible=math.max(totalEligible,#groupTargets(action,scope,scope=="role" and collectiveRole or nil,excludeSelf,nil)) end
        local emptyFuture=future and totalEligible==0
        if emptyFuture then label(0,yBottom+5,T("group_future_empty"),14,C.accent,w)
        elseif totalEligible==0 then label(0,yBottom+5,T("group_no_targets"),14,C.muted,w) end
        if scope=="manual" and next(collectiveSelection)==nil then label(0,yBottom+5,T("group_no_selection"),14,C.muted,w) end
        return yBottom+44
    end
    local function drawPlayers()
        local w=layout.contentW;local list=roster();local p=selectedPlayer()
        title(T(solo() and "player_solo_title" or "players_title"),not solo() and T("player_count",#list) or nil)
        if not solo() then
            local items={{id="player",label=T("group_scope_player")},{id="all",label=T("group_scope_all")},
                {id="role",label=T("group_scope_role")},{id="manual",label=T("group_scope_manual")}}
            local width=math.min(232,math.max(190,w*.42))
            dropdownField("group_scope",w-width,13,width,36,items,collectiveScope,false,function(id)
                collectiveScope=id;collectivePage=1
            end,false)
            if collectiveScope~="player" then return drawCollectivePlayers(w) end
        end
        if not p then label(0,88,T("no_players"),18,C.muted,w);return 130 end
        local two=not solo() and w>=650;local listW=two and math.min(250,math.floor(w*.31)) or w
        local ax=two and listW+24 or 0;local aw=two and w-ax or w
        local rows=two and math.max(2,math.min(5,math.floor((layout.contentH-155)/48))) or 2
        local listBottom=solo() and 0 or 94+rows*48+40
        if not solo() then
            label(0,78,T("select_player"),14,C.muted,listW,true)
            local pageNum=math.max(1,math.min(math.max(1,math.ceil(#list/rows)),pages.players));pages.players=pageNum
            for i=1,rows do local player=list[(pageNum-1)*rows+i]
                if player then
                    local role=roleLabel(player)
                    local suffix="  ·  "..role
                    if button("player_"..player.id,0,102+(i-1)*48,listW,40,utf8clip(player.name,15)..suffix,
                        player.id==p.id and "active" or "plain",false) then selectPlayer(player.id) end
                end
            end
            if #list>rows then page("players",#list,rows,0,102+rows*48) end
        end
        local top=solo() and 78 or two and 82 or listBottom+8
        label(ax,top,p.name,22,C.text,aw,true)
        local life=math.floor((p.health or 0)*100+0.5)
        label(ax,top+31,T("health",life)..(solo() and "" or "  ·  "..roleLabel(p)),15,C.muted,aw)
        label(ax,top+53,T(host() and "player_options_saved" or p.id==me and "player_self_off_saved" or "tip_temporary"),12,C.muted,aw)
        local blocked=p.host and not host();local waiting=(host() or p.id==me) and p.profileReady==false;local gap=8
        local cols=aw>=400 and 2 or 1;local bw=(aw-gap*(cols-1))/cols
        local buttons={
            {"heal","heal"},{"go_to","goto"},{"respawn","respawn"},{"bring","bring"},
            {"kill","kill",nil,"danger"},{"eject","eject"},
            {"god_mode","god",not p.god},{"freeze","freeze",not p.freeze},
            {"fly","fly",not p.fly},{"noclip","noclip",not p.noclip},
        }
        if solo() then
            for i=#buttons,1,-1 do if buttons[i][2]=="goto" or buttons[i][2]=="bring" then table.remove(buttons,i) end end
        end
        local by=top+82
        for i,item in ipairs(buttons) do
            local x=ax+((i-1)%cols)*(bw+gap);local y=by+math.floor((i-1)/cols)*43
            local verb=item[2];local cap=T(verb=="god" and "god_short" or item[1])
            if verb=="god" or verb=="fly" or verb=="noclip" or verb=="freeze" then cap=cap.."  ·  "..T(p[verb] and "on_short" or "off_short") end
            local persistent=verb=="god" or verb=="fly" or verb=="noclip" or verb=="freeze"
            local sameTarget=(verb=="goto" or verb=="bring") and p.id==me
            local dis=(blocked and verb~="goto") or (waiting and persistent) or (verb=="eject" and not p.vehicle) or sameTarget
            local movement=verb=="fly" or verb=="noclip"
            local configurable=movement or (verb=="god" and p.id==me)
            local configuring=movementSettings and movementSettings.player==p.id and movementSettings.mode==verb
            local actionWidth=configurable and bw-46 or bw
            if button("player_action_"..verb,x,y,actionWidth,37,cap,item[4],dis) then actionForPlayer(p,verb,cap,item[3],item[4]) end
            if configurable and button(verb.."_settings",x+bw-40,y,40,37,"...",configuring and "active" or "plain",blocked or waiting) then
                movementSettings={player=p.id,mode=verb,challenge=p.profileChallenge};shortcuts.message=nil
                typing=false;capturing=false;OSP.PermissionUI.cancelInput()
            end
        end
        local y=by+math.ceil(#buttons/cols)*43+7
        local abilityMinWidth=0
        UiPush();UiFont("regular.ttf",17)
        for _,ability in ipairs({"strength","ammo"}) do
            for _,stateKey in ipairs({"on_short","off_short"}) do
                abilityMinWidth=math.max(abilityMinWidth,UiGetTextSize(T(ability).."  ·  "..T(stateKey))+68)
            end
        end
        UiPop()
        local abilityCols=cols==2 and aw>=abilityMinWidth*2+gap and 2 or 1
        local abilityWidth=(aw-gap*(abilityCols-1))/abilityCols
        for i,ability in ipairs({"strength","ammo"}) do
            local x=ax+((i-1)%abilityCols)*(abilityWidth+gap)
            local row=y+math.floor((i-1)/abilityCols)*43
            local configuring=movementSettings and movementSettings.player==p.id and movementSettings.mode==ability
            local caption=T(ability).."  ·  "..T(p[ability] and "on_short" or "off_short")
            if button("player_action_"..ability,x,row,abilityWidth-48,37,caption,p[ability] and "active" or "plain",blocked or waiting) then
                local value=p.id==me and {expected=p[ability]==true,value=not p[ability]} or not p[ability]
                command(ability,p.id,value)
            end
            if button(ability.."_settings",x+abilityWidth-40,row,40,37,"...",configuring and "active" or "plain",blocked or waiting) then
                movementSettings={player=p.id,mode=ability,challenge=p.profileChallenge};shortcuts.message=nil
                typing=false;capturing=false;OSP.PermissionUI.cancelInput()
            end
        end
        y=y+math.ceil(2/abilityCols)*43
        label(ax,y+8,T("speed_short"),16,C.muted,88)
        local challenge=p.profileChallenge
        numberField("player_speed_value",ax+96,y,aw-208,34,p.speed or 1,.5,3,2,
            function(value)
                local current=findPlayer(p.id)
                if current and current.profileChallenge==challenge then command("speed",p.id,value)
                else setStatus(T("result_unavailable")) end
            end,blocked or waiting,"×"..tostring(p.speed or 1))
        if button("speed_down",ax+aw-104,y,48,34,"-","plain",blocked or waiting) then command("speed",p.id,math.max(.5,(p.speed or 1)-.25)) end
        if button("speed_up",ax+aw-50,y,48,34,"+","plain",blocked or waiting) then command("speed",p.id,math.min(3,(p.speed or 1)+.25)) end
        y=y+43
        if not solo() and rolesAccess() and not p.host then
            if button("player_role_manage",ax,y,aw,37,T("manage_player_role"),"plain",p.profileReady==false) then
                setTab("permissions",true)
                OSP.PermissionUI.focusPlayerRole(p.role or (p.admin and "admin" or "guest"),p,state() and state().profileHost)
            end
            y=y+49
        end
        if allowed("reset_player",p.id) then
            if p.profileReady==false then label(ax,y,T("profile_waiting"),14,C.muted,aw);y=y+29 end
            if button("reset_player",ax,y,aw,37,T("reset_player"),"plain",waiting) then
                ask("reset_player",p.id,nil,T("confirm_reset_player",utf8clip(p.name,24)))
            end
            y=y+49
        end
        if solo() then return y+10 end
        return math.max(listBottom,y+10)
    end
    local function drawPlayerTooltip()
        tooltip=nil
        if tab~="players" or confirm or movementSettings or toolsPopup or collectivePopup or typing or capturing
            or search.focused or shortcuts.capture or OSP.NumberInput.active() or OSP.PermissionUI.capturing()
            or clickConsumed or InputDown("lmb") then resetTooltip();return end
        local p=findPlayer(selected)
        if not p then resetTooltip();return end
        local mx,my=layout.ox+mouseX,layout.oy+mouseY
        local persistent={god=true,freeze=true,fly=true,noclip=true,strength=true,ammo=true,speed=true}
        local candidate,text
        for id,r in pairs(controls) do
            if inside(r.x,r.y,r.w,r.h,mx,my) then
                local action=id:match("^player_action_(.+)$")
                if id=="player_speed_value" or id=="speed_up" or id=="speed_down" then action="speed" end
                if id=="fly_settings" then action="fly" elseif id=="noclip_settings" then action="noclip" end
                if id=="strength_settings" then action="strength" elseif id=="ammo_settings" then action="ammo" end
                local relevant=action or id=="player_role_manage" or id=="reset_player"
                if relevant then
                    if r.disabled then
                        if (action=="goto" or action=="bring") and p.id==me and permittedControl(id) then text=T("tip_select_another_player")
                        elseif p.host and not host() and action~="goto" then text=T("protects_host")
                        elseif (host() or p.id==me) and p.profileReady==false and (persistent[action] or id=="player_role_manage" or id=="reset_player") then text=T("profile_waiting")
                        elseif not permittedControl(id) then text=T("result_denied")
                        elseif action=="eject" and not p.vehicle then text=T("tip_no_vehicle") end
                    end
                    if not text then
                        if id=="fly_settings" or id=="noclip_settings" then text=T("tip_movement_settings")
                        elseif id=="strength_settings" then text=T("tip_strength_settings")
                        elseif id=="ammo_settings" then text=T("tip_ammo_settings")
                        elseif action=="fly" then text=T("tip_fly")
                        elseif action=="noclip" then text=T("tip_noclip")
                        elseif action=="strength" then text=T("tip_strength")
                        elseif action=="ammo" then text=T("tip_ammo")
                        elseif id=="player_role_manage" then text=T("tip_admin")
                        elseif id=="reset_player" then text=T("tip_reset") end
                    end
                    if text then candidate={id=id,r=r};break end
                end
            end
        end
        if not candidate then resetTooltip();return end
        local key=candidate.id..":"..p.id..":"..tostring(p.profileChallenge)..":"..text..":"..candidate.r.x..":"..candidate.r.y..":"..candidate.r.w..":"..candidate.r.h
        if tipKey~=key then tipKey=key;tipSince=GetTime();return end
        if GetTime()-tipSince<.6 then return end
        local w=math.min(360,layout.w-24);local lines={};local line=""
        UiPush();UiFont("regular.ttf",14)
        for word in text:gmatch("%S+") do
            local nextLine=line=="" and word or line.." "..word
            if line~="" and UiGetTextSize(nextLine)>w-24 then lines[#lines+1]=line;line=word else line=nextLine end
        end
        if line~="" then lines[#lines+1]=line end
        UiPop()
        local h=#lines*18+20;local r=candidate.r
        local x=math.max(12,math.min(layout.w-w-12,r.x-layout.ox))
        local y=r.y-layout.oy+r.h+8
        if y+h>layout.h-12 then y=r.y-layout.oy-h-8 end
        y=math.max(12,math.min(layout.h-h-12,y))
        rect(x,y,w,h,C.side);rect(x,y,w,1,C.line);rect(x,y+h-1,w,1,C.line)
        rect(x,y,1,h,C.line);rect(x+w-1,y,1,h,C.line)
        for i,value in ipairs(lines) do label(x+12,y+10+(i-1)*18,value,14,C.text) end
        tooltip={id=candidate.id,text=text,x=layout.ox+x,y=layout.oy+y,w=w,h=h,lines=lines}
    end
    local function permissionAPI(list,expanded)
        return {
            label=function(x,y,value,size,width,muted,bold) label(x,y,value,size,muted and C.muted or C.text,width,bold) end,
            height=function() return layout.contentH end,
            panel=function(x,y,w,h)
                rect(x,y,w,h,C.side);rect(x,y,w,1,C.line)
            end,
            selectionRow=function(id,x,y,w,h,name,role,checked,disabled)
                local clicked=button(id,x,y,w,h,"","plain",disabled or (expanded and confirm~=nil),expanded)
                local edge=checked and C.accent or C.muted
                local boxY=y+(h-16)/2
                rect(x+10,boxY,16,16,edge);rect(x+11,boxY+1,14,14,C.side)
                if checked then rect(x+14,boxY+4,8,8,C.accent) end
                label(x+36,y+5,name,15,disabled and C.disabled or C.text,w-46)
                label(x+36,y+25,role,12,C.muted,w-46)
                rect(x+8,y+h-1,w-16,1,C.line)
                return clicked
            end,
            paragraph=function(x,y,value,size,width)
                UiPush();UiTranslate(x,y);UiAlign("left top");UiFont("regular.ttf",size)
                UiTextDisableWildcards(true);UiWordWrap(width);rgb(C.muted)
                local _,height=UiText(value);UiPop()
                return height
            end,
            can=allowed,
            dropdown=function(id,x,y,w,h,items,current,disabled,onSelect) dropdownField(id,x,y,w,h,items,current,disabled,onSelect,expanded) end,
            image=function(x,y,path) UiPush();UiTranslate(x,y);rgb(C.muted);UiImage(path);UiPop() end,
            button=function(id,x,y,w,h,value,kind,disabled)
                return button(id,x,y,w,h,value,kind,disabled or (expanded and confirm~=nil),expanded)
            end,
            checkbox=checkboxButton,
            viewport=function(x,y,w,h,offset,draw)
                if expanded then permissionViewport={x=drawOx+x,y=drawOy+y,w=w,h=h} end
                local oldX,oldY,oldOx,oldOy,oldClip=mouseX,mouseY,drawOx,drawOy,clip
                UiPush();UiTranslate(x,y);UiWindow(w,h,true,true);UiTranslate(0,-offset)
                mouseX,mouseY=oldX-x,oldY-y+offset;drawOx,drawOy=oldOx+x,oldOy+y-offset
                clip={x=0,y=offset,w=w,h=h}
                local contentHeight=draw()
                UiPop();mouseX,mouseY,drawOx,drawOy,clip=oldX,oldY,oldOx,oldOy,oldClip
                if contentHeight>h then
                    local thumb=math.max(24,h*h/contentHeight)
                    rect(x+w-3,y,2,h,C.line)
                    rect(x+w-4,y+(h-thumb)*math.min(1,offset/(contentHeight-h)),4,thumb,C.muted)
                end
                return contentHeight
            end,
            wheel=function(x,y,w,h)
                if confirm or dropdown or not expanded or not inside(x,y,w,h,mouseX,mouseY) then return 0 end
                local delta=permissionWheel;permissionWheel=0;return delta
            end,
            pending=function() return pending~=nil end,
            ask=ask,command=command,resetScroll=function() scroll=0 end,
            players=function() return list end,
            profileHost=function() return state() and state().profileHost end,
            groupAssignment=function(role,targets)
                local s=state();local own=findPlayer(me)
                if not s or not own then return nil end
                local captured={}
                for _,target in ipairs(targets or {}) do captured[#captured+1]={id=target.id,join=target.join} end
                return {host=s.profileHost,actorJoin=own.profileChallenge,role=role,targets=captured}
            end,
        }
    end
    local function drawPermissions()
        if not rolesAccess() then setTab("settings");return 0 end
        title(T("permissions"),T("permissions_subtitle"))
        return OSP.PermissionUI.draw(permissionAPI(roster(),false),state() and state().templates,nil,layout.contentW)
    end
    local function drawSession()
        local w=layout.contentW;local s=state();local rules=s and s.rules or {}
        title(T("session_rules"),T("session_subtitle"))
        local rows={{"time","time_scale",1,.1,.1,2},{"rain","rain",0,.1,0,1},{"fog","fog",100,50,10,1000}}
        local y=78
        for _,r in ipairs(rows) do
            local v=rules[r[1]];local shown=v==nil and T("map_default") or tostring(v)..(r[1]=="time" and "×" or r[1]=="fog" and " m" or "")
            label(0,y+9,T(r[2]),17,C.text,math.max(100,w-340))
            numberField("rule_"..r[1].."_value",w-310,y,190,34,v==nil and r[3] or v,r[5],r[6],r[1]=="fog" and 0 or 2,
                function(value) command("rule",0,{key=r[1],value=value}) end,false,shown,false,{unset=v==nil})
            for _,d in ipairs({-1,1}) do
                local id="rule_"..r[1]..(d<0 and "_down" or "_up")
                if button(id,w-(d<0 and 104 or 50),y,48,34,d<0 and "-" or "+","plain",false) then
                    local nextValue=math.max(r[5],math.min(r[6],(v==nil and r[3] or v)+d*r[4]))
                    command("rule",0,{key=r[1],value=math.floor(nextValue*100+.5)/100})
                end
            end
            rect(0,y+43,w,1,C.line);y=y+54
        end
        label(0,y+8,T("regeneration"),17,C.text,math.max(100,w-350))
        label(w-330,y+8,rules.regen==nil and T("map_default") or T(rules.regen and "on" or "off"),16,C.muted,168)
        if button("regen_on",w-150,y,72,34,T("on_short"),rules.regen==true and "active" or "plain",false) then command("rule",0,{key="regen",value=true}) end
        if button("regen_off",w-72,y,72,34,T("off_short"),rules.regen==false and "active" or "plain",false) then command("rule",0,{key="regen",value=false}) end
        y=y+51
        local bw=math.min(300,(w-10)/2)
        if button("reset_rules",0,y,bw,38,T("reset_rules"),"plain",false) then command("reset_rules",0) end
        if allowed("restart",0) and button("restart",bw+10,y,bw,38,T("restart"),"danger",false) then ask("restart",0,nil,T("confirm_restart")) end
        y=y+58
        if solo() then return y end
        label(0,y,T("announcement"),20,C.text,w,true);y=y+31
        local fieldW=math.max(120,w-160)
        if button("announcement_field",0,y,fieldW,38,draft~="" and draft..(typing and "_" or "") or T("type_announcement"),typing and "active" or "plain",false) then typing=true;capturing=false;InputClear() end
        if button("announcement_send",fieldW+10,y,150,38,T("send_short"),"active",false) then
            if #draft==0 then setStatus(T("announcement_empty")) elseif command("announce",0,draft) then draft="";typing=false end
        end
        label(0,y+48,T("announcement_help"),14,C.muted,w)
        return y+78
    end
    local function toolName(tool)
        if tool.nameKey and GetTranslatedStringByKey then
            local ok,value=pcall(GetTranslatedStringByKey,tool.nameKey,tool.name or tool.id)
            if ok and type(value)=="string" and value~="" then return value end
        end
        return tool.name or tool.id
    end
    local function filteredTools()
        local s=state();local result={};local counts={all=0,vanilla=0,mod=0}
        for _,tool in ipairs(s and s.tools or {}) do
            local origin=tool.origin or OSP.toolOrigin(tool.id)
            counts.all=counts.all+1;counts[origin]=(counts[origin] or 0)+1
            if (filter=="all" or filter==origin) and search.matches(toolName(tool),tool.id) then result[#result+1]=tool end
        end
        return result,counts
    end
    -- Manually documented causes; detection alone does not identify a writer.
    local compatibilityNotes={airstrike="compatibility_airstrike"}
    local function compatibilityText(id,fallback) return T(compatibilityNotes[id] or fallback) end
    local function toolConflict(p,id)
        return p and p.toolConflicts and p.toolConflicts[id]==true
    end
    local function toolConflictCount(id)
        local n=0
        for _,p in ipairs(roster()) do if toolConflict(p,id) then n=n+1 end end
        return n
    end
    local function toolChoice(p,tool)
        if tool.policy=="disabled" then
            if not p.toolGrants or p.toolGrants[tool.id]~=true then return false end
            if p.toolRules and p.toolRules[tool.id]~=nil then return p.toolRules[tool.id] end
            return true
        end
        if p.toolRules and p.toolRules[tool.id]~=nil then return p.toolRules[tool.id] end
        if tool.policy=="enabled" then return true end
        return IsToolEnabled(tool.id,p.id)
    end
    local function checkCompatibilityNotice()
        if not menu or tab~="tools" or confirm or pending or toolsPopup or dropdown or search.focused then return end
        local p=selectedPlayer()
        for _,tool in ipairs(state() and state().tools or {}) do
            local conflict=toolMode=="global" and toolConflictCount(tool.id)>0 or toolMode=="player" and toolConflict(p,tool.id)
            local key=ROOT.."compatibility.seen."..tool.id:gsub(".",function(c) return string.format("%02x",c:byte()) end)
            if conflict and GetString(key)~="1" then
                SetString(key,"1")
                confirm={info=true,target=0,toolName=toolName(tool),message=compatibilityText(tool.id,"compatibility_notice")}
                typing=false;capturing=false;OSP.NumberInput.cancel();OSP.PermissionUI.cancelInput();InputClear()
                return
            end
        end
    end
    local function drawTools()
        local w=layout.contentW;local items,counts=filteredTools();local p=selectedPlayer()
        if solo() then toolMode="global" elseif not allowed("tool_policy",0) then toolMode="player" end
        title(T("tools_title_short"),solo() and T("tools_solo_description") or T(toolMode=="global" and "global_description" or host() and "player_tools_saved" or "selected_only"))
        local y=77;local bw=math.min(230,(w-8)/2)
        if not solo() then
            if button("tool_mode_global",0,y,bw,34,T("global_rules"),toolMode=="global" and "active" or "plain",not allowed("tool_policy",0)) then toolMode="global";pages.tools=1 end
            if button("tool_mode_player",bw+8,y,bw,34,T("player_rules"),toolMode=="player" and "active" or "plain",false) then toolMode="player";pages.tools=1 end
            y=y+44
        end
        if toolMode=="player" then
            local list=roster();local index=1
            for i,q in ipairs(list) do if p and q.id==p.id then index=i end end
            label(0,y+8,T("selected_player")..": "..(p and p.name or "—"),16,C.text,w-120)
            if button("tool_player_prev",w-108,y,48,32,"<","plain",index<=1) then selectPlayer(list[index-1].id) end
            if button("tool_player_next",w-54,y,48,32,">","plain",index>=#list) then selectPlayer(list[index+1].id) end
            y=y+42
        end
        if button("tools_search",0,y,w-48,34,search.query~="" and search.query..(search.focused and "_" or "") or T("tools_search"),search.focused and "active" or "plain",false) then
            search.focused=true;typing=false;capturing=false;OSP.NumberInput.cancel();OSP.PermissionUI.cancelInput()
        end
        if button("tools_search_clear",w-40,y,40,34,"X","plain",search.query=="") then search.clear();pages.tools=1;scroll=0 end
        y=y+44
        local fw=(w-16)/3
        for i,c in ipairs({{"all","filter_all"},{"vanilla","filter_vanilla"},{"mod","filter_mod"}}) do
            if button("filter_"..c[1],(i-1)*(fw+8),y,fw,32,T(c[2]).." ("..counts[c[1]]..")",filter==c[1] and "active" or "plain",false) then filter=c[1];pages.tools=1;scroll=0 end
        end
        y=y+42
        label(0,y+8,T("tools_results",#items,counts[filter]),14,C.muted,w-175)
        local function openActions(tool)
            local ids={};for _,item in ipairs(tool and {tool} or items) do ids[#ids+1]=item.id end
            local categoryIds={}
            for _,item in ipairs(state().tools or {}) do
                if filter=="all" or filter==(item.origin or OSP.toolOrigin(item.id)) then categoryIds[#categoryIds+1]=item.id end
            end
            toolsPopup={ids=tool and ids or categoryIds,resultIds=ids,category=filter,query=search.query,mode=toolMode,player=p and p.id,challenge=p and p.profileChallenge,tool=tool and OSP.copy(tool)}
            search.blur()
        end
        if button("tools_actions",w-165,y,165,34,T("tools_group_actions"),"plain",counts[filter]==0) then openActions() end
        y=y+44
        if #items==0 then label(0,y,T(counts.all==0 and "no_tools" or "tools_no_match"),17,C.muted,w);return y+44 end
        local per=math.min(8,math.max(1,math.floor((layout.contentH-y-46)/45)))
        local pg=math.max(1,math.min(math.ceil(#items/per),pages.tools));pages.tools=pg
        local blocked=not p or (p.host and not host()) or (host() and p.profileReady==false)
        for row=1,per do
            local tool=items[(pg-1)*per+row]
            if tool then
                local ry=y+(row-1)*45;local policy=tool.policy or "default"
                local exception=p and p.toolGrants and p.toolGrants[tool.id]==true
                local canGrant=p and allowed("tool_policy",0) and allowed("tool",p.id)
                local locked=policy=="disabled" and toolMode=="player" and not exception and not canGrant
                local enabled=false
                if p then
                    if policy=="disabled" or toolConflict(p,tool.id) then enabled=toolChoice(p,tool)
                    else enabled=IsToolEnabled(tool.id,p.id) end
                end
                local active=enabled
                if toolMode=="global" and not solo() then active=policy=="default" and IsToolEnabled(tool.id,me) or policy=="enabled" end
                local meta=locked and T("blocked_by_host") or toolMode=="global" and T("policy_"..policy) or T(enabled and "tool_enabled" or "tool_disabled")
                if solo() then meta=T(enabled and "tool_enabled" or "tool_disabled") end
                if toolMode=="player" and policy=="disabled" and exception and not toolConflict(p,tool.id) then
                    meta=T(enabled and "tool_exception_enabled" or "tool_exception_paused")
                end
                local conflicts=toolConflictCount(tool.id)
                if toolMode=="global" and conflicts>0 then
                    meta=T(policy=="disabled" and "tool_use_block_count" or "tool_inventory_conflict",conflicts)
                elseif toolMode=="player" and toolConflict(p,tool.id) then
                    meta=T(enabled and "tool_inventory_conflict" or "tool_use_block")
                end
                label(0,ry+3,toolName(tool),17,C.text,w-204)
                label(0,ry+24,meta,13,C.muted,w-204)
                if button("tool_"..tool.id,w-194,ry+3,144,34,T(active and "deactivate" or "activate"),active and "active" or "plain",not p or (toolMode=="global" and not allowed("tool_policy",0)) or (toolMode=="player" and (blocked or not allowed("tool",p.id) or locked and not enabled))) then
                    if toolMode=="global" then
                        local mode=active and "disabled" or "enabled"
                        if active then ask("tool_policy",0,{id=tool.id,mode=mode},T("confirm_tool_global",toolName(tool)))
                        else command("tool_policy",0,{id=tool.id,mode=mode}) end
                    else command("tool",p.id,{id=tool.id,enabled=not enabled}) end
                end
                if button("tool_more_"..tool.id,w-40,ry+3,40,34,"...","plain",toolMode=="global" and (not allowed("tool_policy",0) or not solo() and policy=="default" and conflicts==0)) then openActions(tool) end
                rect(0,ry+44,w,1,C.line)
            end
        end
        y=y+per*45+4;page("tools",#items,per,0,y);return y+42
    end
    local function drawActivity()
        local w=layout.contentW;local s=state();local log=s and s.log or {}
        title(T("activity_title"),T("activity_subtitle"))
        if #log==0 then label(0,90,T("no_activity"),17,C.muted,w);return 140 end
        local per=math.min(9,math.max(1,math.floor((layout.contentH-125)/48)))
        local pg=math.max(1,math.min(math.max(1,math.ceil(#log/per)),pages.activity));pages.activity=pg
        local y=78
        for i=1,per do local e=log[#log-(pg-1)*per-i+1]
            if e then
                local actor=math.min(140,w*.21);local result=math.min(105,w*.16);local target=math.min(125,w*.18)
                local actionW=math.max(100,w-actor-result-target-24)
                local key=({heal="heal",kill="kill",respawn="respawn",["goto"]="go_to",bring="bring",eject="eject",god="god_mode",fly="fly",fly_speed="fly_normal_action",fly_boost="fly_shift_action",noclip_speed="noclip_normal_action",noclip_boost="noclip_shift_action",noclip="noclip",freeze="freeze",strength="strength",ammo="ammo",ammo_restore="ammo_restore",strength_force="strength_force_label",strength_mass="strength_mass_label",strength_throw="strength_throw",strength_throw_speed="strength_throw_speed_label",speed="speed",effects_off_on_load="effects_on_load",collective_future="collective_actions",players_group="collective_actions",roles_assign_many="role_assignment_title",admin="admin_access",role_assign="permissions",role_save="permissions",role_delete="permissions",role_reset="permissions",reset_player="reset_player",heal_all="heal_all",bring_all="bring_all",rule="session_rules",reset_rules="reset_rules",restart="restart",announce="announcement",tool="tools",tool_all="tools",tools="tools",tools_all="tools",tool_policy="global_rules",tool_policy_bulk="global_rules",tool_policy_selection="global_rules",tools_selection="tools",tools_selection_all="tools",tools_filtered="tools",tools_filtered_all="tools"})[e.action] or "status"
                local detail=T(key)
                if type(e.argument)=="table" then
                    local a=e.argument
                    if e.action=="players_group" then
                        local action=T(a.action=="god" and "god_short" or a.action or "collective_actions")
                        local scope=T("group_scope_"..tostring(a.scope or "all"))
                        detail=T("group_activity",action).." · "..scope
                        if a.role then
                            local name=a.role
                            for _,role in ipairs(s.templates or {}) do if role.id==a.role then name=OSP.Permissions.name(role);break end end
                            detail=detail.." · "..name
                        end
                        if type(a.enabled)=="boolean" then detail=detail.." · "..T(a.enabled and "group_state_on" or "group_state_off") end
                    elseif e.action=="roles_assign_many" then
                        local name=a.role or "?"
                        for _,role in ipairs(s.templates or {}) do if role.id==a.role then name=OSP.Permissions.name(role);break end end
                        detail=T("role_batch_activity",name)
                    elseif a.key then
                        local ruleNames={time="time_scale",rain="rain",fog="fog",regen="regeneration"}
                        detail=T(ruleNames[a.key] or "session_rules")
                        local value=a.value
                        if type(value)=="boolean" then value=T(value and "on" or "off")
                        elseif OSP.finite(value) then
                            if a.key=="rain" then value=tostring(math.floor(value*100+.5)).."%"
                            elseif a.key=="fog" then value=tostring(value).." m"
                            elseif a.key=="time" then value=tostring(value).."×" end
                        end
                        detail=detail.." · "..tostring(value)
                    else
                        if a.enabled~=nil then detail=detail.." · "..T(a.enabled and "on" or "off") end
                        if a.mode then detail=T("policy_"..a.mode) end
                        if a.id then
                            local name=a.id
                            for _,tool in ipairs(s.tools or {}) do if tool.id==a.id then name=toolName(tool);break end end
                            detail=detail.." · "..name
                        end
                        if a.category then detail=detail.." · "..T("filter_"..a.category) end
                        if a.tools then detail=detail.." · "..T("tools_selection_count",a.tools) end
                    end
                elseif type(e.argument)=="boolean" then detail=detail.." · "..T(e.argument and "on" or "off")
                elseif type(e.argument)=="number" then detail=detail.." · "..tostring(e.argument)
                elseif type(e.argument)=="string" then detail=detail.." · "..utf8clip(e.argument,64) end
                label(0,y+7,e.actor or "?",16,C.text,actor)
                label(actor+8,y+7,detail,16,C.text,actionW)
                label(actor+actionW+16,y+7,e.target~="" and e.target or "—",15,C.muted,target)
                local resultKey=e.result=="ok" and "done" or e.result=="partial" and "result_partial" or "error_short"
                label(w-result,y+7,T(resultKey),15,e.result=="ok" and C.success or e.result=="partial" and C.accent or C.danger,result)
                local counts=T("counts_short",e.affected or 0,e.skipped or 0)
                if (e.inventoryConflicts or 0)>0 then counts=counts.." · "..T("tool_inventory_count",e.inventoryConflicts) end
                label(0,y+28,counts,13,C.muted,w)
                rect(0,y+46,w,1,C.line);y=y+48
            end
        end
        page("activity",#log,per,0,y+6);return y+48
    end
    local function drawSettings()
        local w=layout.contentW;title(T("settings"),T("settings_subtitle"))
        local y=85
        local sections=OSP.SettingsSections
        local function section(id,key)
            local expanded=sections.expanded(id)
            if button("settings_section_"..id,0,y,w,58,"","outlined",false) then
                expanded=not expanded;sections.setExpanded(id,expanded)
                if id=="shortcut" then shortcuts.cancel();capturing=false end
            end
            label(10,y+9,T(key),17,C.text,w-48)
            UiPush();UiTranslate(w-28,y+21);rgb(C.muted)
            UiImage(expanded and "MOD/ui/section-down.png" or "MOD/ui/section-right.png");UiPop()
            label(10,y+33,T("settings_help_"..id),13,C.muted,w-48)
            y=y+68
            return expanded
        end
        local api={
            label=function(x,py,value,size,width) label(x,py,value,size,C.text,width) end,
            button=function(id,x,py,width,height,value,kind) return button(id,x,py,width,height,value,kind,false) end,
        }
        if section("language","language") then
            if button("language_en",0,y,160,38,T("english"),lang()=="en" and "active" or "plain",false) then SetString(ROOT.."language","en");setStatus(T("preference_saved")) end
            if button("language_pt",168,y,160,38,T("portuguese"),lang()=="pt" and "active" or "plain",false) then SetString(ROOT.."language","pt");setStatus(T("preference_saved")) end
            y=y+54
        end
        if section("shortcut","menu_key") then
            label(0,y+9,string.upper(keybind()),18,C.accent,100,true)
            local menuCapture=shortcuts.capture=="menu"
            if button("rebind",130,y,math.min(220,w-130),38,T(menuCapture and "cancel" or "change_key"),"plain",false) then
                if menuCapture then shortcuts.cancel() else shortcuts.begin("menu") end
                capturing=shortcuts.capture=="menu";typing=false;confirm=nil
            end
            y=y+54
        end
        if section("view_mode","view_mode") then y=y+OSP.ViewMode.draw(api,0,y,w,true)+12 end
        if section("behavior","panel_behavior") then y=y+navigation.drawBehavior(api,0,y,w,true)+12 end
        if section("navigation","navigation_title") then y=y+navigation.draw(api,0,y,w,true)+12 end
        if host() and section("effects_on_load","effects_on_load") then
            label(0,y+7,T("effects_on_load_toggle"),16,C.text,w)
            local value=state() and state().effectsOffOnLoad
            local known=type(value)=="boolean"
            if button("effects_on_load_on",0,y+34,84,36,T("effects_on_load_on"),value==true and "active" or "plain",not known) and value~=true then
                command("effects_off_on_load",0,true)
            end
            if button("effects_on_load_off",92,y+34,84,36,T("effects_on_load_off"),value==false and "active" or "plain",not known) and value~=false then
                command("effects_off_on_load",0,false)
            end
            label(0,y+78,T("effects_on_load_keeps"),13,C.muted,w)
            y=y+106
        end
        if host() and not solo() then
            local expanded=GetString(ROOT.."settings.collapsed.collective")=="0"
            if button("settings_section_collective",0,y,w,58,"","outlined",false) then
                expanded=not expanded;SetString(ROOT.."settings.collapsed.collective",expanded and "0" or "1")
            end
            label(10,y+9,T("collective_actions"),17,C.text,w-48)
            UiPush();UiTranslate(w-28,y+21);rgb(C.muted)
            UiImage(expanded and "MOD/ui/section-down.png" or "MOD/ui/section-right.png");UiPop()
            label(10,y+33,T("collective_settings_help"),13,C.muted,w-48)
            y=y+68
            if expanded then
                local value=state() and state().collectiveFuture
                local known=type(value)=="boolean"
                label(0,y+7,T("collective_future_label"),16,C.text,w)
                local choiceW=math.min(300,math.floor((w-8)/2))
                if button("collective_future_off",0,y+34,choiceW,38,T("collective_future_present"),value==false and "active" or "plain",not known or pending) and value~=false then
                    command("collective_future",0,false)
                end
                if button("collective_future_on",choiceW+8,y+34,choiceW,38,T("collective_future_all"),value==true and "active" or "plain",not known or pending) and value~=true then
                    command("collective_future",0,true)
                end
                label(0,y+80,T("collective_future_help"),13,C.muted,w)
                y=y+112
            end
        end
        return y
    end
    local function drawAppearance()
        local w=layout.contentW;title(T("appearance"),T("appearance_subtitle"))
        return 85+OSP.Theme.drawAppearance({
                label=function(x,py,value,size,width,color) label(x,py,value,size,color or C.text,width) end,
                button=function(id,x,y,width,height,value,kind) return button(id,x,y,width,height,value,kind,false) end,
                image=function(x,y,path) UiPush();UiTranslate(x,y);rgb(C.muted);UiImage(path);UiPop() end,
                number=numberField,
                rect=rect,
                mouse=function() return mouseX,mouseY end,
                visible=function() return not confirm and (not clip or inside(clip.x,clip.y,clip.w,clip.h,mouseX,mouseY)) end,
                pressed=function() return not clickConsumed and (lmbPressed or InputPressed("lmb")) end,
                down=function() return InputDown("lmb") end,
                consume=function() clickConsumed=true;OSP.NumberInput.cancel() end,
            },0,85,w)
    end
    local function drawDebug()
        local w=layout.contentW;title(T("debug"),T("debug_subtitle"))
        local y=85
        local function paragraph(text,color)
            UiPush();UiTranslate(0,y);UiAlign("left top");UiFont("regular.ttf",15)
            UiTextDisableWildcards(true);UiWordWrap(w);rgb(color or C.muted)
            local _,height=UiText(text);UiPop();y=y+height+14
        end
        local bw=math.min(w,320)
        if button("debug_reset_first_entry",0,y,bw,36,T("debug_reset_first_entry"),"outlined",false) then
            ClearKey(ROOT.."compatibility.seen")
            setStatus(T("debug_first_entry_reset"))
        end
        y=y+46;paragraph(T("debug_reset_help"))
        if button("debug_preview_notice",0,y,bw,36,T("debug_preview_notice"),"outlined",pending~=nil) then
            confirm={info=true,target=0,toolName=T("debug_sample_tool"),message=T("compatibility_notice")}
        end
        y=y+46;paragraph(T("debug_preview_help"))
        rect(0,y,w,1,C.line);y=y+18
        label(0,y,T("debug_state"),20,C.text,w,true);y=y+34
        local s=state();local own=findPlayer(me);local conflicts=0
        for _,tool in ipairs(s and s.tools or {}) do if toolConflictCount(tool.id)>0 then conflicts=conflicts+1 end end
        paragraph(T("version",OSP.version),C.text)
        paragraph(T("debug_panel_mode",T("view_"..(solo() and "single" or "multi")),T("view_"..OSP.ViewMode.get())),C.text)
        paragraph(T("debug_server",T(s and s.ready and "debug_ready" or "debug_waiting")),C.text)
        paragraph(T("debug_profile",T(own and own.profileReady and "debug_ready" or "debug_waiting")),C.text)
        paragraph(T("debug_roster",#roster(),T(host() and "debug_yes" or "debug_no")),C.text)
        paragraph(T("debug_tools",s and #(s.tools or {}) or 0,conflicts),C.text)
        paragraph(T("debug_pending",T(pending and "debug_yes" or "debug_no")),C.text)
        if status then paragraph(T("debug_last_status",status),C.text) end
        y=y+6
        if button("debug_hide",0,y,bw,36,T("debug_hide"),"outlined",false) then
            navigation.setVisible("debug",false);setTab("settings")
        end
        return y+52
    end
    local function drawAbout()
        local w=layout.contentW;title(T("about_title"),T("about_subtitle"))
        local entries={{T("version",OSP.version),C.accent},{"Luiz-AVcruz",C.text},{T("about_summary"),C.text},
            {T("license"),C.text},{T("license_permission"),C.muted},{T("source_included"),C.text},
            {T("source_location"),C.muted},{T("source_offer"),C.muted},{T("limits"),C.muted}}
        local hasConflicts=false
        for _,tool in ipairs(state() and state().tools or {}) do
            local n=toolConflictCount(tool.id)
            if n>0 then
                if not hasConflicts then entries[#entries+1]={T("compatibility_title"),C.accent};hasConflicts=true end
                entries[#entries+1]={T("compatibility_detected",toolName(tool),n),C.text}
                entries[#entries+1]={compatibilityText(tool.id,"compatibility_detected_help"),C.muted}
            end
        end
        local y=86
        for _,e in ipairs(entries) do
            UiPush();UiTranslate(0,y);UiAlign("left top");UiFont("regular.ttf",17);UiTextDisableWildcards(true)
            UiWordWrap(w);rgb(e[2]);local _,h=UiText(e[1]);UiPop()
            y=y+math.max(30,h+12)
        end
        return y+20
    end
    local function drawMovementPopup()
        if not movementSettings then return end
        local current=movementSettings
        local p=findPlayer(current.player)
        if not p or p.profileChallenge~=current.challenge or selected~=p.id or tab~="players"
            or not allowed(current.mode,p.id) or (p.host and not host()) or (host() and p.profileReady==false) then
            closeMovement();return
        end
        local personal=p.id==me;local god=current.mode=="god";local strength=current.mode=="strength";local ammo=current.mode=="ammo"
        local popupHeight=god and 210 or ammo and (personal and 286 or 242) or strength and (personal and 360 or 314) or personal and 396 or 340
        local w=math.min(layout.w-32,540);local h=math.min(layout.h-24,popupHeight)
        local x,y=(layout.w-w)/2,(layout.h-h)/2
        if not clickConsumed and lmbPressed and not inside(x,y,w,h,mouseX,mouseY) then
            clickConsumed=true;OSP.NumberControl.beforeAction();closeMovement();return
        end
        rect(0,0,layout.w,layout.h,{0,0,0,.65});rect(x,y,w,h,C.side);rect(x,y,w,3,C.accent)
        label(x+20,y+18,T(current.mode.."_settings_title"),20,C.text,w-92,true)
        if button("movement_popup_close",x+w-54,y+12,36,34,"X",nil,false,true) then closeMovement();return end
        label(x+20,y+53,T("selected_short")..": "..p.name,15,C.muted,w-40)
        if strength then
            local values={
                {"strength_force_value","strength_force_label","strength_force",p.strengthForce or OSP.strength.force,OSP.strength.minForce,OSP.strength.maxForce,2},
                {"strength_mass_value","strength_mass_label","strength_mass",p.strengthMass or OSP.strength.mass,OSP.strength.minMass,OSP.strength.maxMass,0},
            }
            for i,field in ipairs(values) do
                local row=y+82+(i-1)*42
                label(x+20,row+8,T(field[2]),15,C.text,w-190)
                numberField(field[1],x+w-160,row,140,34,field[4],field[5],field[6],field[7],
                    function(value)
                        local target=findPlayer(current.player)
                        if target and target.profileChallenge==current.challenge then command(field[3],current.player,value)
                        else setStatus(T("result_unavailable")) end
                    end,false,nil,true)
            end
            local throwY=y+166
            label(x+20,throwY+8,T("strength_throw"),15,C.text,w-190)
            if button("strength_throw_on",x+w-160,throwY,70,34,T("on_short"),p.strengthThrow and "active" or "plain",false,true) then
                command("strength_throw",current.player,true)
            end
            if button("strength_throw_off",x+w-82,throwY,70,34,T("off_short"),not p.strengthThrow and "active" or "plain",false,true) then
                command("strength_throw",current.player,false)
            end
            if p.strengthThrow then
                local row=y+208
                label(x+20,row+8,T("strength_throw_speed_label"),15,C.text,w-190)
                numberField("strength_throw_speed_value",x+w-160,row,140,34,p.strengthThrowSpeed or OSP.strength.throwSpeed,
                    OSP.strength.minThrowSpeed,OSP.strength.maxThrowSpeed,2,
                    function(value)
                        local target=findPlayer(current.player)
                        if target and target.profileChallenge==current.challenge then command("strength_throw_speed",current.player,value)
                        else setStatus(T("result_unavailable")) end
                    end,false,nil,true)
            end
        elseif not god and not ammo then
            for i,field in ipairs({{current.mode.."_speed_value","fly_speed_label",current.mode.."_speed",p[current.mode.."Speed"] or OSP.flight.normal},
                {current.mode.."_boost_value","fly_boost_label",current.mode.."_boost",p[current.mode.."Boost"] or OSP.flight.shift}}) do
                local row=y+86+(i-1)*44
                label(x+20,row+8,T(field[2]),15,C.text,w-190)
                numberField(field[1],x+w-160,row,140,34,field[4],OSP.flight.min,OSP.flight.max,2,
                    function(value)
                        local target=findPlayer(current.player)
                        if target and target.profileChallenge==current.challenge then command(field[3],current.player,value)
                        else setStatus(T("result_unavailable")) end
                    end,false,nil,true)
            end
        end
        local py=y+(god and 86 or ammo and 86 or strength and (p.strengthThrow and 254 or 210) or 180)
        if personal then
            shortcuts.drawBinding({
                label=function(px,py,value,size,width) label(px,py,value,size,C.text,width) end,
                button=function(id,px,py,width,height,value,kind,disabled) return button(id,px,py,width,height,value,kind,disabled,true) end,
            },current.mode,x+20,py,w-40,T("context_shortcut"))
            py=py+44
        end
        local function paragraph(value,size,color)
            UiPush();UiTranslate(x+20,py);UiAlign("left top");UiFont("regular.ttf",size)
            UiTextDisableWildcards(true);UiWordWrap(w-40);rgb(color)
            local _,height=UiText(value);UiPop();py=py+height+10
        end
        if ammo then paragraph(T("ammo_compatibility"),14,C.muted)
        elseif not god and not strength then
            paragraph(T("fly_speed_note"),13,C.muted)
            if current.mode=="fly" then paragraph(T("fly_help"),14,C.muted) end
            paragraph(T("fly_controls"),14,C.muted)
        end
        py=y+h-42
        local helpKey=strength and "strength_popup_help" or ammo and "ammo_restore_help" or "movement_popup_help"
        paragraph(OSP.NumberInput.active() and T("number_help") or shortcuts.capture and T("press_key") or personal and shortcuts.problem(current.mode) and T(shortcuts.problem(current.mode)) or shortcuts.message and T(shortcuts.message) or (status and GetTime()<statusUntil and status) or T(helpKey),13,C.accent)
    end
    local function drawToolsPopup()
        if not toolsPopup then return end
        local v=toolsPopup;local p=findPlayer(v.player)
        if tab~="tools" or toolMode~=v.mode or not p or selected~=p.id or p.profileChallenge~=v.challenge then closeTools();return end
        local w=math.min(layout.w-32,540);local h=math.min(layout.h-24,v.mode=="player" and not v.tool and v.query~="" and 384 or 340);local x,y=(layout.w-w)/2,(layout.h-h)/2
        if not clickConsumed and lmbPressed and not inside(x,y,w,h,mouseX,mouseY) then clickConsumed=true;closeTools();return end
        rect(0,0,layout.w,layout.h,{0,0,0,.65});rect(x,y,w,h,C.side);rect(x,y,w,3,C.accent)
        label(x+18,y+16,T("tools_actions"),20,C.text,w-82,true)
        if button("tools_popup_close",x+w-54,y+10,36,34,"X",nil,false,true) then closeTools();return end
        local half=(w-44)/2
        local searching=not v.tool and v.query~=""
        label(x+18,y+51,v.tool and toolName(v.tool) or searching and T("tools_group_counts",#v.ids,#v.resultIds) or T("tools_selection_count",#v.ids),16,C.text,w-36)
        label(x+18,y+77,T("filter_"..v.category)..(searching and " · "..v.query or ""),14,C.muted,w-36)
        local py=y+108
        local function action(id,caption,column,verb,arg,danger,disabled,query)
            if button(id,x+18+(column=="right" and half+8 or column=="center" and (w-36-half)/2 or 0),py,half,34,T(caption),danger and "danger" or nil,disabled,true) then
                closeTools()
                local count=arg.value.ids and #arg.value.ids or 1
                if danger then
                    local message=T("tools_confirm_selection",count).." "..T(caption).." · "..(arg.scope or "").." · "..(v.tool and utf8clip(toolName(v.tool),40) or T("filter_"..v.category)..(query and " · "..query or ""))
                    if v.mode=="global" and verb=="tool_policy_selection" and arg.value.mode=="disabled" then message=message.." "..T("global_block_clears_exceptions") end
                    ask(verb,arg.target,arg.value,message)
                else command(verb,arg.target,arg.value) end
            end
        end
        if v.mode=="global" then
            label(x+18,py,T(solo() and "tools_solo_description" or "global_description"),14,C.muted,w-36);py=py+28
            if not v.tool then
                action("tools_enable_filtered","enable_category","left","tool_policy_selection",{target=0,value={category=v.category,ids=v.ids,mode="enabled"}},false,not allowed("tool_policy",0))
                action("tools_disable_filtered","disable_category","right","tool_policy_selection",{target=0,scope=T("global_rules"),value={category=v.category,ids=v.ids,mode="disabled"}},true,not allowed("tool_policy",0));py=py+44
                if searching then
                    action("tools_enable_results","tools_enable_results","left","tool_policy_selection",{target=0,value={category=v.category,ids=v.resultIds,mode="enabled"}},false,not allowed("tool_policy",0) or #v.resultIds==0,v.query)
                    action("tools_disable_results","tools_disable_results","right","tool_policy_selection",{target=0,scope=T("global_rules"),value={category=v.category,ids=v.resultIds,mode="disabled"}},true,not allowed("tool_policy",0) or #v.resultIds==0,v.query);py=py+44
                end
            end
            action("tools_reset_filtered","restore_category","center",v.tool and "tool_policy" or "tool_policy_selection",{target=0,scope=T("global_rules"),value=v.tool and {id=v.tool.id,mode="default"} or {category=v.category,ids=v.ids,mode="default"}},true,not allowed("tool_policy",0))
        else
            local blocked=p.host and not host() or host() and p.profileReady==false
            if not v.tool then
                label(x+18,py,T("selected_player")..": "..p.name,14,C.text,w-36);py=py+24
                action("tools_enable_filtered","enable_category","left","tools_selection",{target=p.id,value={category=v.category,ids=v.ids,enabled=true}},false,blocked or not allowed("tools",p.id))
                action("tools_disable_filtered","disable_category","right","tools_selection",{target=p.id,scope=utf8clip(p.name,24),value={category=v.category,ids=v.ids,enabled=false}},true,blocked or not allowed("tools",p.id));py=py+44
                if searching then
                    action("tools_enable_results","tools_enable_results","left","tools_selection",{target=p.id,value={category=v.category,ids=v.resultIds,enabled=true}},false,blocked or not allowed("tools",p.id) or #v.resultIds==0,v.query)
                    action("tools_disable_results","tools_disable_results","right","tools_selection",{target=p.id,scope=utf8clip(p.name,24),value={category=v.category,ids=v.resultIds,enabled=false}},true,blocked or not allowed("tools",p.id) or #v.resultIds==0,v.query);py=py+44
                end
            end
            label(x+18,py,T(host() and "tools_present" or "tools_present_except_host"),14,C.text,w-36);py=py+24
            local args=function(on) return v.tool and {id=v.tool.id,enabled=on} or {category=v.category,ids=v.ids,enabled=on} end
            local verb=v.tool and "tool_all" or "tools_selection_all"
            action("tools_enable_everyone",v.tool and "enable_everyone" or "enable_category","left",verb,{target=0,value=args(true)},false,not allowed("tools_all",0))
            action("tools_disable_everyone",v.tool and "disable_everyone" or "disable_category","right",verb,{target=0,scope=T(host() and "tools_present" or "tools_present_except_host"),value=args(false)},true,not allowed("tools_all",0));py=py+44
            if searching then
                action("tools_enable_results_everyone","tools_enable_results","left","tools_selection_all",{target=0,value={category=v.category,ids=v.resultIds,enabled=true}},false,not allowed("tools_all",0) or #v.resultIds==0,v.query)
                action("tools_disable_results_everyone","tools_disable_results","right","tools_selection_all",{target=0,scope=T(host() and "tools_present" or "tools_present_except_host"),value={category=v.category,ids=v.resultIds,enabled=false}},true,not allowed("tools_all",0) or #v.resultIds==0,v.query)
            end
        end
        local incompatible=false
        for _,id in ipairs(v.ids) do if toolConflictCount(id)>0 then incompatible=true;break end end
        UiPush();UiTranslate(x+18,y+h-40);UiAlign("left top");UiFont("regular.ttf",13);UiWordWrap(w-36);UiTextDisableWildcards(true);rgb(C.accent)
        UiText(incompatible and compatibilityText(v.tool and v.tool.id,"tool_conflict_help") or T("movement_popup_help"));UiPop()
    end
    local function drawCollectivePopup()
        local current=collectivePopup
        if not current then return end
        local s=state();local own=findPlayer(me)
        if tab~="players" or not s or s.profileHost~=current.host or not own or own.profileChallenge~=current.actorJoin then
            collectivePopup=nil;return
        end
        local w=math.min(layout.w-32,420);local h=190;local x=(layout.w-w)/2;local y=(layout.h-h)/2
        if not clickConsumed and lmbPressed and not inside(x,y,w,h,mouseX,mouseY) then
            clickConsumed=true;collectivePopup=nil;return
        end
        rect(0,0,layout.w,layout.h,{0,0,0,.65});rect(x,y,w,h,C.side);rect(x,y,w,3,C.accent)
        label(x+20,y+16,T("group_popup_title",T(current.action=="god" and "god_short" or current.action)),19,C.text,w-92,true)
        if #current.base.targets>0 then
            label(x+20,y+50,T("group_popup_targets",#current.base.targets),14,C.muted,w-40)
        else
            label(x+20,y+50,T("group_future_empty"),14,C.muted,w-40)
        end
        if button("group_popup_close",x+w-54,y+11,36,34,"X","outlined",false,true) then collectivePopup=nil;return end
        local canOn,canOff=false,false
        local onArg=OSP.copy(current.base);onArg.value=true
        local offArg=OSP.copy(current.base);offArg.value=false
        if not pending then canOn=allowed("players_group",0,onArg);canOff=allowed("players_group",0,offArg) end
        local half=(w-52)/2
        if button("group_popup_on",x+20,y+h-58,half,38,T("group_popup_on"),"active",not canOn,true) then sendCollective(current.base,true) end
        if button("group_popup_off",x+32+half,y+h-58,half,38,T("group_popup_off"),"plain",not canOff,true) then sendCollective(current.base,false) end
    end
    local function drawModal()
        if not confirm then return end
        if confirm.info then
            local w=math.min(layout.w-32,480);local lines={};local line=""
            UiPush();UiFont("regular.ttf",16)
            for word in confirm.message:gmatch("%S+") do
                local nextLine=line=="" and word or line.." "..word
                if line~="" and UiGetTextSize(nextLine)>w-40 then lines[#lines+1]=line;line=word else line=nextLine end
            end
            if line~="" then lines[#lines+1]=line end
            UiPop()
            local h=154+#lines*22;local x,y=(layout.w-w)/2,(layout.h-h)/2
            rect(0,0,layout.w,layout.h,{0,0,0,.65});rect(x,y,w,h,C.side);rect(x,y,w,3,C.accent)
            label(x+20,y+18,T("compatibility_notice_title"),20,C.text,w-40,true)
            label(x+20,y+52,confirm.toolName,18,C.accent,w-40,true)
            for i,value in ipairs(lines) do label(x+20,y+82+(i-1)*22,value,16,C.text,w-40) end
            if button("compatibility_notice_close",x+w-148,y+h-54,128,36,T("understood"),"outlined",not confirm.ready,true) then confirm=nil;return end
            confirm.ready=true;return
        end
        local w=math.min(layout.w-32,540);local h=math.min(layout.h-32,232);local x=(layout.w-w)/2;local y=(layout.h-h)/2
        rect(0,0,layout.w,layout.h,{0,0,0,.65});rect(x,y,w,h,C.side);rect(x,y,w,3,C.accent)
        label(x+20,y+18,T("confirmation"),20,C.text,w-40,true)
        UiPush();UiTranslate(x+20,y+55);UiAlign("left top");UiFont("regular.ttf",17)
        UiTextDisableWildcards(true);UiWordWrap(w-40);UiWindow(w-40,h-124,true,true)
        rgb(C.text);UiText(confirm.message);UiPop()
        local awaitingFrame=not confirm.ready
        if button("confirm_cancel",x+w-246,y+h-53,102,38,T("cancel"),"plain",awaitingFrame,true) then confirm=nil;return end
        if button("confirm_accept",x+w-136,y+h-53,116,38,T("confirm"),"danger",awaitingFrame,true) then
            local current=confirm;confirm=nil;command(current.action,current.target,current.arg,current.targetContext,true)
        end
        if confirm then confirm.ready=true end
    end
    local function render()
        setTab(tab)
        checkConfirmationTarget()
        checkCompatibilityNotice()
        refreshViewMode()
        OSP.NumberControl.beginFrame(numericFrame)
        local tabs=navigation.list(eligible);local navCols=math.min(4,#tabs)
        local canvas=UiCanvasSize();local W=math.min(1120,canvas.w*.85);local H=math.min(720,canvas.h*.82)
        local ox=(canvas.w-W)/2;local oy=(canvas.h-H)/2;local narrow=W<900
        local header=58;local headerCenter=header/2;local side=narrow and 0 or 174;local navH=narrow and (6+math.ceil(#tabs/navCols)*36) or 0
        local cx=narrow and 18 or side+22;local cy=header+navH+18
        local cw=W-cx-18;local ch=H-cy-18
        layout={w=W,h=H,ox=ox,oy=oy,contentX=cx,contentY=cy,contentW=cw,contentH=ch,narrow=narrow}
        controls={};UiPush();UiTranslate(ox,oy);UiAlign("left top");UiWindow(W,H,true)
        mouseX,mouseY=UiGetMousePos();drawOx,drawOy=ox,oy
        rect(0,0,W,H,C.back);rect(0,0,W,header,C.side);rect(0,header-1,W,1,C.line)
        rect(18,headerCenter-12,4,24,C.accent);label(31,headerCenter-21/2,T("app_title"),21,C.text,W-215,true)
        if not solo() and ((tab=="players" and collectiveScope=="player") or (tab=="tools" and toolMode=="player")) then
            local target=findPlayer(selected) or roster()[1]
            local x=math.max(260,W-490)
            if target and W-145-x>=90 then label(x,headerCenter-14/2,T("selected_short")..": "..target.name,14,C.muted,W-145-x) end
        end
        if button("close",W-122,headerCenter-34/2,104,34,T("close"),"outlined",false) then setMenu(false) end
        if not narrow then rect(0,header,side,H-header,C.side);rect(side,header,1,H-header,C.line) end
        for i,t in ipairs(tabs) do
            local x,y,w,h
            if narrow then w=(W-36-(navCols-1)*4)/navCols;h=32;x=18+((i-1)%navCols)*(w+4);y=header+7+math.floor((i-1)/navCols)*36
            else x=12;y=header+19+(i-1)*43;w=side-24;h=37 end
            if button("tab_"..t,x,y,w,h,T(solo() and t=="players" and "player_solo" or t),tab==t and "active" or "outlined",not admin() and not personalTab(t)) then setTab(t) end
        end
        if not narrow then label(22,H-32,T("version",OSP.version),13,C.muted,side-44) end
        clip={x=cx,y=cy,w=cw,h=ch};bodyHovered=inside(cx,cy,cw,ch,mouseX,mouseY)
        UiPush();UiTranslate(cx,cy);UiWindow(cw,ch,true,true);UiTranslate(0,-scroll)
        mouseX,mouseY=mouseX-cx,mouseY-cy+scroll
        drawOx,drawOy=ox+cx,oy+cy-scroll
        clip={x=0,y=scroll,w=cw,h=ch}
        local contentHeight=0
        local s=state()
        if tab=="debug" then contentHeight=drawDebug()
        elseif not s or not s.ready then title(T("connecting"));contentHeight=90
        elseif not admin() and not personalTab(tab) then setTab("settings");contentHeight=drawSettings()
        elseif tab=="players" then contentHeight=drawPlayers()
        elseif tab=="session" then contentHeight=drawSession()
        elseif tab=="tools" then contentHeight=drawTools()
        elseif tab=="permissions" then contentHeight=drawPermissions()
        elseif tab=="activity" then contentHeight=drawActivity()
        elseif tab=="appearance" then contentHeight=drawAppearance()
        elseif tab=="settings" then contentHeight=drawSettings()
        else contentHeight=drawAbout() end
        UiPop();clip=nil
        mouseX,mouseY=mouseX+cx,mouseY+cy-scroll
        drawOx,drawOy=ox,oy
        maxScroll=math.max(0,contentHeight-ch);scroll=math.max(0,math.min(scroll,maxScroll))
        if maxScroll>0 then
            local trackH=ch;local thumb=math.max(24,ch*ch/contentHeight)
            rect(W-7,cy,2,trackH,C.line);rect(W-8,cy+(trackH-thumb)*(scroll/maxScroll),4,thumb,C.muted)
        end
        if OSP.NumberInput.active() and not movementSettings then label(cx,H-17,T("number_help"),13,C.accent,cw)
        elseif status and GetTime()<statusUntil then label(cx,H-17,status,13,C.accent,cw) end
        drawPlayerTooltip();drawMovementPopup();drawToolsPopup();drawCollectivePopup();if not permissionExpanded() then drawModal() end
        OSP.NumberControl.endFrame(clickConsumed);UiPop()
    end
    local function drawPermissionModal()
        if not permissionExpanded() then return end
        if not menu or tab~="permissions" or not rolesAccess() then OSP.PermissionUI.closeExpanded();closeDropdown();return end
        local canvas=UiCanvasSize()
        local w,h=math.min(1320,canvas.w*.94),math.min(900,canvas.h*.90)
        local x,y=(canvas.w-w)/2,(canvas.h-h)/2
        local mx,my=UiGetMousePos()
        if not dropdown and not confirm and not clickConsumed and lmbPressed and not inside(x,y,w,h,mx,my) then
            clickConsumed=true;OSP.PermissionUI.closeExpanded();return
        end
        local oldLayout,oldX,oldY,oldOx,oldOy,oldClip=layout,mouseX,mouseY,drawOx,drawOy,clip
        rect(0,0,canvas.w,canvas.h,{0,0,0,.70})
        UiPush();UiTranslate(x,y);UiAlign("left top");UiWindow(w,h,true)
        layout={w=w,h=h,ox=x,oy=y,contentW=w-40,contentH=h-40,permissionModal=true}
        mouseX,mouseY=mx-x,my-y;drawOx,drawOy=x,y;clip={x=0,y=0,w=w,h=h}
        rect(0,0,w,h,C.side);rect(0,0,w,3,C.accent)
        UiPush();UiTranslate(20,16)
        mouseX,mouseY=mouseX-20,mouseY-16;drawOx,drawOy=x+20,y+16
        clip={x=0,y=0,w=w-40,h=h-52}
        OSP.PermissionUI.drawExpanded(permissionAPI(roster(),true),state() and state().templates,nil,w-40,h-52)
        UiPop();mouseX,mouseY=mx-x,my-y;drawOx,drawOy=x,y;clip={x=0,y=0,w=w,h=h}
        if button("permission_view_close",w-54,12,36,34,"X","outlined",confirm~=nil,true) then OSP.PermissionUI.closeExpanded() end
        if status and GetTime()<statusUntil then label(20,h-20,status,13,C.accent,w-40) end
        drawModal()
        UiPop()
        layout.permissionModalBounds={x=x,y=y,w=w,h=h}
        oldLayout.permissionModalBounds=layout.permissionModalBounds
        layout,mouseX,mouseY,drawOx,drawOy,clip=oldLayout,oldX,oldY,oldOx,oldOy,oldClip
    end
    local function drawDropdown()
        local d=dropdown
        if not d then return end
        local permissionDropdown=d.id:match("^permission_view_")~=nil
        if not menu or not d.seen or confirm or (permissionDropdown and (tab~="permissions" or not rolesAccess()))
            or (not permissionDropdown and tab~="players") or permissionExpanded()~=d.expanded or #d.items==0 then closeDropdown();return end
        local bounds=d.expanded and layout.permissionModalBounds or {x=layout.ox,y=layout.oy,w=layout.w,h=layout.h}
        if not bounds then closeDropdown();return end
        local f=d.field;local below=bounds.y+bounds.h-12-(f.y+f.h+4)
        local above=f.y-4-(bounds.y+12)
        local down=below>=math.min(280,#d.items*34+8) or below>=above
        local available=math.max(0,down and below or above)
        local rows=math.max(1,math.min(8,#d.items,math.floor((available-8)/34)))
        local w=math.min(f.w,bounds.w-24);local h=rows*34+8
        local x=math.max(bounds.x+12,math.min(bounds.x+bounds.w-w-12,f.x))
        local y=down and f.y+f.h+4 or f.y-h-4
        y=math.max(bounds.y+8,math.min(bounds.y+bounds.h-h-8,y))
        local mx,my=UiGetMousePos()
        if inside(x,y,w,h,mx,my) and permissionWheel~=0 then d.first=d.first-permissionWheel;permissionWheel=0 end
        d.first=math.max(1,math.min(#d.items-rows+1,math.floor(d.first)))
        if d.keyboard then
            if d.highlight<d.first then d.first=d.highlight elseif d.highlight>=d.first+rows then d.first=d.highlight-rows+1 end
            d.keyboard=false
        end
        d.bounds={x=x,y=y,w=w,h=h}
        local oldX,oldY,oldOx,oldOy,oldClip=mouseX,mouseY,drawOx,drawOy,clip
        UiPush();UiAlign("left top")
        mouseX,mouseY=mx,my;drawOx,drawOy=0,0;clip={x=x,y=y,w=w,h=h};dropdownDrawing=true
        rect(x,y,w,h,C.side);rect(x,y,w,1,C.line);rect(x,y+h-1,w,1,C.line)
        rect(x,y,1,h,C.line);rect(x+w-1,y,1,h,C.line)
        for row=1,rows do
            local index=d.first+row-1;local item=d.items[index]
            if item then
                local clicked=button(d.id.."_option_"..item.id,x+4,y+4+(row-1)*34,w-8,32,item.label,
                    item.id==d.current and "active" or index==d.highlight and "outlined" or "plain",item.disabled,true)
                if (clicked or d.choose and d.highlight==index) and not item.disabled then
                    closeDropdown();d.onSelect(item.id);clickConsumed=true;break
                end
            end
        end
        if #d.items>rows then
            local thumb=(h-8)*rows/#d.items
            rect(x+w-3,y+4,2,h-8,C.line)
            rect(x+w-3,y+4+(h-8-thumb)*(d.first-1)/(#d.items-rows),2,thumb,C.muted)
        end
        d.choose=false
        UiPop();dropdownDrawing=false;mouseX,mouseY,drawOx,drawOy,clip=oldX,oldY,oldOx,oldOy,oldClip
    end
    local function isMouseKey(key) return key=="lmb" or key=="rmb" or key=="mmb" end
    local function consumeText()
        local k=InputLastPressedKey();if not k or k=="" then return end;k=string.lower(k)
        -- Mouse input belongs to buttons; clearing it here in tick would erase
        -- the press before client.draw can handle Send, Close or navigation.
        if isMouseKey(k) then return end
        if k=="esc" then typing=false;draft="";InputClear();return end
        if k=="return" or k=="enter" then if #draft>0 and command("announce",0,draft) then draft="";typing=false end;InputClear();return end
        if k=="backspace" then draft=draft:sub(1,-2);InputClear();return end
        if k=="space" then k=" " end
        if #k==1 and k:match("^[%w%s%p]$") and #draft<240 then draft=draft..k end
        InputClear()
    end
    function client.ospResult(ok,code,details,id)
        if not pending or id~=pending then return end
        local names={ok="result_ok",partial="result_partial",denied="result_denied",invalid="result_invalid",protected="result_protected",unavailable="result_unavailable",error="result_error",rate_limited="result_rate_limited",state_changed="shortcut_state_changed",conflict="role_conflict",template_limit="role_limit"}
        local msg=T(names[code] or "result_error")
        local defaultSaved=ok and lastAction=="players_group" and details and details.defaultsSaved==true
        if defaultSaved then
            if code=="partial" then msg=msg.."  "..T("group_default_saved") else msg=T("group_default_saved") end
        end
        if details and details.inventoryConflicts and details.inventoryConflicts>0 then
            msg=msg.."  "..T("tool_inventory_count",details.inventoryConflicts)
        end
        if details and details.skipped and details.skipped>0 then msg=msg.."  "..T("skipped",details.skipped) end
        if details and details.failed and details.failed>0 then msg=msg.."  "..T("failed_count",details.failed) end
        if ok and lastAction=="rule" then msg=T("rules_saved") elseif ok and lastAction=="reset_rules" then msg=T("rules_reset") end
        if ok and lastAction=="effects_off_on_load" then msg=T("effects_on_load_saved") end
        if ok and (lastAction=="role_save" or lastAction=="role_reset") and details then OSP.PermissionUI.saved(details.template) end
        if ok and lastAction=="role_delete" and details then OSP.PermissionUI.deleted(details.deleted) end
        if shortcutRequest then
            local own=findPlayer(me);local request=shortcutRequest;shortcutRequest=nil
            if not own or own.profileChallenge~=request.challenge then msg=T("result_unavailable")
            elseif ok then msg=T(request.value and "on" or "off") end
            shortcutMessage(request.action,msg)
            msg=shortcutNotice
        end
        pending=nil;lastAction=nil;setStatus(msg)
    end
    function client.ospAnnouncement(actor,message)
        notice=T("announcement_by",utf8clip(actor or "?",40),message or "")
        noticeUntil=GetTime()+6;setStatus(notice,6)
    end
    function client.ospIdentity(namespace,challenge,id)
        local s=state()
        local p=findPlayer(me)
        if s and p and identityPending and identityPending.host==namespace and identityPending.join==challenge
            and p.profileChallenge==challenge and namespace==s.profileHost and type(namespace)=="string" and #namespace==32 and namespace:match("^[0-9a-f]+$")
            and type(id)=="string" and #id<=12 and id:match("^p%d+$") then
            SetString(ROOT.."identity."..namespace,id);identityHost=namespace;identityJoin=challenge;identityPending=nil
        end
    end
    function client.init()
        me=GetLocalPlayer()
        collectiveHostNamespace=state() and state().profileHost
        local own=findPlayer(me);collectiveActorJoin=own and own.profileChallenge
        if LoadLanguageTable and GetInt then LoadLanguageTable(GetInt("options.language")) end
        if GetString(ROOT.."language")=="" then SetString(ROOT.."language","en") end
        if not OSP.validKey(GetString(ROOT.."menu_key")) then SetString(ROOT.."menu_key","p") end
    end
    local function updateCollectiveContext(s,own)
        local namespace=s and s.profileHost
        local function invalidate()
            local active=collectiveScope~="player" or next(collectiveSelection)~=nil or collectivePopup~=nil
                or OSP.PermissionUI.hasBatchSelection and OSP.PermissionUI.hasBatchSelection()
            resetCollective();OSP.PermissionUI.clearBatchSelection()
            if active then lmbPressed=false;clickConsumed=true;InputClear() end
        end
        if collectiveHostNamespace~=nil and namespace~=collectiveHostNamespace then
            invalidate()
        end
        collectiveHostNamespace=namespace
        local join=own and own.profileChallenge
        if collectiveActorJoin~=nil and join~=collectiveActorJoin then
            invalidate()
        end
        collectiveActorJoin=join
        validateCollectiveSelection()
        if collectivePopup and (not s or s.profileHost~=collectivePopup.host or not own or own.profileChallenge~=collectivePopup.actorJoin) then
            collectivePopup=nil;lmbPressed=false;clickConsumed=true;InputClear()
        end
    end
    local function escapeCollectivePopup()
        if collectivePopup and InputPressed("esc") then
            collectivePopup=nil;lmbPressed=false;InputClear();return true
        end
        return false
    end
    local function collectivePopupOpen() return collectivePopup~=nil end
    function client.tick(dt)
        sentInInputFrame=false
        numericFrame=OSP.NumberInput.sample()
        permissionWheel=InputValue("mousewheel")
        refreshViewMode()
        local pauseInputBlocked=GetBool("game.paused") or InputPressed("pause") or InputPressed("esc")
        -- Preserve a simultaneous click before keyboard capture calls InputClear.
        if (InputLastPressedKey() or "")~="" or InputPressed("lmb") or InputValue("mousewheel")~=0 then resetTooltip() end
        local wasMenu=menu
        setTab(tab)
        lmbPressed=numericFrame.mousePressed
        checkConfirmationTarget()
        if me==0 then me=GetLocalPlayer() end
        local s=state()
        local p=findPlayer(me)
        updateCollectiveContext(s,p)
        if s and s.profileHost and p and p.profileChallenge and not host() and IsPlayerValid(me)
            and (identityHost~=s.profileHost or identityJoin~=p.profileChallenge) and GetTime()>=identityRetry then
            identityRetry=GetTime()+1
            identityPending={host=s.profileHost,join=p.profileChallenge}
            ServerCall("server.ospIdentify",me,s.profileHost,p.profileChallenge,GetString(ROOT.."identity."..s.profileHost))
        end
        if pending and GetTime()-sentAt>=8 then
            if shortcutRequest then shortcutMessage(shortcutRequest.action,T("request_unknown"),10);shortcutRequest=nil else setStatus(T("request_unknown"),10) end
            pending=nil;lastAction=nil
        end
        if tab~="permissions" then validateSelection() end
        if movementSettings then
            local target=findPlayer(movementSettings.player)
            if not target or target.profileChallenge~=movementSettings.challenge or selected~=target.id
                or not allowed(movementSettings.mode,target.id) then closeMovement();lmbPressed=false;InputClear() end
        end
        if toolsPopup then
            local target=findPlayer(toolsPopup.player)
            if not target or target.profileChallenge~=toolsPopup.challenge then closeTools();lmbPressed=false;InputClear() end
        end
        if menu and dropdown then
            if InputPressed("esc") then closeDropdown();lmbPressed=false;InputClear()
            elseif InputPressed("uparrow") or InputPressed("downarrow") then
                dropdown.highlight=math.max(1,math.min(#dropdown.items,dropdown.highlight+(InputPressed("uparrow") and -1 or 1)))
                dropdown.keyboard=true;InputClear()
            elseif InputPressed("return") or InputPressed("enter") then dropdown.choose=true;InputClear() end
        elseif menu and OSP.NumberInput.active() then OSP.NumberInput.key(numericFrame)
        elseif menu and toolsPopup and InputPressed("esc") then closeTools();lmbPressed=false;InputClear()
        elseif menu and movementSettings and InputPressed("esc") then
            closeMovement();lmbPressed=false;InputClear()
        elseif menu and escapeCollectivePopup() then
        elseif menu and search.focused then
            if search.key() then pages.tools=1;scroll=0 end
        elseif menu and tab=="permissions" and OSP.PermissionUI.capturing() then
            OSP.PermissionUI.key()
        elseif menu and permissionExpanded() and InputPressed("esc") then
            if confirm then confirm=nil else OSP.PermissionUI.closeExpanded() end
            lmbPressed=false;InputClear()
        elseif shortcuts.capture then
            shortcuts.key();capturing=shortcuts.capture=="menu"
            if shortcuts.message then setStatus(T(shortcuts.message)) end
        elseif typing then consumeText()
        else
            if InputPressed(keybind()) then setMenu(not menu) end
            if menu and InputPressed("esc") then if confirm then confirm=nil else setMenu(false) end end
        end
        if menu and bodyHovered and not confirm and not movementSettings and not toolsPopup and not collectivePopupOpen() and not dropdown and not permissionExpanded() and not OSP.NumberControl.dragging() then
            local delta=InputValue("mousewheel")
            if delta~=0 then scroll=math.max(0,math.min(maxScroll,scroll-delta*48)) end
        end
        if PauseMenuButton(T("pause_button"),"bottom_bar",false) then setMenu(true);confirm=nil end
        if not admin() and not personalTab(tab) then setTab("settings") end
        if not wasMenu and not menu and not shortcuts.capture and not typing and not capturing
            and not confirm and not movementSettings and not toolsPopup and not collectivePopupOpen() and not search.focused
            and not OSP.NumberInput.active() and not permissionExpanded() and not OSP.PermissionUI.capturing()
            and not InputPressed(keybind()) and not shortcuts.modified() then
            local action,count=nil,0
            for _,id in ipairs(shortcuts.actions) do
                local key=shortcuts.binding(id)
                if key~="" and InputPressed(key) then action=id;count=count+1 end
            end
            if count==1 and not pauseInputBlocked and shortcutContextAllowed() then
                local own=findPlayer(me)
                if pending then shortcutMessage(action,T("request_pending"))
                elseif not s or not s.ready or not own or not IsPlayerValid(me) or (own.health or 0)<=0
                    or type(own.profileChallenge)~="number" or (host() and own.profileReady~=true) then shortcutMessage(action,T("result_unavailable"))
                elseif not admin() or not allowed(action,me) then shortcutMessage(action,T("result_denied"))
                else
                    local value=own[action]==true
                    shortcutRequest={action=action,value=not value,challenge=own.profileChallenge}
                    shortcutMessage(action,T("request_sent"),8)
                    if not command(action,me,{expected=value,value=not value}) then
                        shortcutRequest=nil;shortcutMessage(action,status or T("result_error"))
                    end
                end
            end
        end
        local own=findPlayer(me)
        if s and s.ready and own and own.fly and OSP.finite(own.profileChallenge) then
            -- The native HUD uses interactive for gameplay, independently of
            -- canusetool (which also blocks grabs and the Plank tool).
            local allowed=not pauseInputBlocked and not menu and not GetBool("game.map.enabled")
                and GetBool("game.player.interactive")
            local now=GetTime()
            if not flightInputReport or flightInputReport.allowed~=allowed
                or flightInputReport.challenge~=own.profileChallenge or flightInputReport.host~=s.profileHost
                or now-flightInputReport.at>=0.2 then
                flightInputSequence=flightInputSequence+1
                flightInputReport={allowed=allowed,challenge=own.profileChallenge,host=s.profileHost,at=now}
                ServerCall("server.ospFlightInput",me,s.profileHost,own.profileChallenge,flightInputSequence,allowed)
            end
        else flightInputReport=nil end
        if s and s.ready and own and own.strength==true and OSP.finite(own.profileChallenge) then
            -- Strength is server-owned; this heartbeat only says whether the
            -- local player's current context permits gameplay input.
            local allowed=not pauseInputBlocked and not menu and shortcutContextAllowed()
            local now=GetTime()
            if not strengthInputReport or strengthInputReport.allowed~=allowed
                or strengthInputReport.challenge~=own.profileChallenge or strengthInputReport.host~=s.profileHost
                or now-strengthInputReport.at>=0.2 then
                strengthInputSequence=strengthInputSequence+1
                strengthInputReport={allowed=allowed,challenge=own.profileChallenge,host=s.profileHost,at=now}
                ServerCall("server.ospStrengthInput",me,s.profileHost,own.profileChallenge,strengthInputSequence,allowed)
            end
        else strengthInputReport=nil end
    end
    function client.draw()
        C=OSP.Theme.colors()
        if not menu then resetTooltip() end
        if not menu or tab~="appearance" then OSP.Theme.cancelDrag() end
        clickConsumed=false;permissionViewport=nil
        if menu then
            if dropdown then
                local mx,my=UiGetMousePos();local d=dropdown
                if lmbPressed and not inside(d.field.x,d.field.y,d.field.w,d.field.h,mx,my)
                    and (not d.bounds or not inside(d.bounds.x,d.bounds.y,d.bounds.w,d.bounds.h,mx,my)) then
                    closeDropdown();clickConsumed=true
                end
                if dropdown then dropdown.seen=false end
            end
            numericFrame.mousePressed=lmbPressed and not clickConsumed
            UiMakeInteractive();render();drawPermissionModal();drawDropdown();permissionWheel=0;lmbPressed=false;return
        end
        lmbPressed=false
        local canvas=UiCanvasSize()
        if shortcutNotice and GetTime()<shortcutUntil then
            local maxWidth=math.min(360,canvas.w-40);local textWidth=maxWidth-24;local lines={};local line=""
            UiPush();UiFont("regular.ttf",15)
            for word in shortcutNotice:gmatch("%S+") do
                local nextLine=line=="" and word or line.." "..word
                if line~="" and UiGetTextSize(nextLine)>textWidth then lines[#lines+1]=line;line=word else line=nextLine end
            end
            if line~="" then lines[#lines+1]=line end
            local text=table.concat(lines,"\n");local measuredWidth,measuredHeight=UiGetTextSize(text)
            local w=math.min(maxWidth,measuredWidth+24);local h=measuredHeight+16
            UiPop()
            local y=notice and GetTime()<noticeUntil and 164 or 40
            UiPush();UiTranslate((canvas.w-w)/2,y);rect(0,0,w,h,C.side);rect(0,0,3,h,C.accent)
            UiTranslate(12,8);UiFont("regular.ttf",15);UiAlign("left top");UiTextDisableWildcards(true);UiWordWrap(w-24);rgb(C.text);UiText(text);UiPop()
        end
        if notice and GetTime()<noticeUntil then
            local w=math.min(700,canvas.w-40);UiPush();UiTranslate((canvas.w-w)/2,40);UiWindow(w,112,true)
            rect(0,0,w,112,C.back);rect(0,0,4,112,C.accent);UiTranslate(18,14);UiWordWrap(w-36)
            UiFont("regular.ttf",18);UiAlign("left top");UiTextDisableWildcards(true);rgb(C.text);UiText(notice);UiPop()
        end
    end
    OSP.UI={getState=function() return {open=menu,tab=tab,selected=selected,confirm=confirm,movementPopup=OSP.copy(movementSettings),collectivePopup=OSP.copy(collectivePopup),collectiveScope=collectiveScope,collectiveSelection=OSP.copy(collectiveSelection),permissionExpanded=permissionExpanded(),permissionViewport=OSP.copy(permissionViewport),roleDropdown=dropdown and {id=dropdown.id,first=dropdown.first,bounds=OSP.copy(dropdown.bounds)} or nil,toolsPopup=OSP.copy(toolsPopup),searchQuery=search.query,searchFocused=search.focused,keyCapture=shortcuts.capture~=nil,shortcutNotice=shortcutNotice,typing=typing,language=lang(),menuKey=keybind(),requestPending=pending~=nil,pendingId=pending,status=status,layout=OSP.copy(layout),controls=OSP.copy(controls),tooltip=OSP.copy(tooltip),scroll=scroll,maxScroll=maxScroll,filter=filter,toolMode=toolMode,viewMode=viewMode} end,
        open=function(v) setMenu(v==true) end,selectTab=setTab}
end
