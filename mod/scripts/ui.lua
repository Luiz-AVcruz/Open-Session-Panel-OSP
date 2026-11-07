-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Rendering and input are local; gameplay changes are confirmed by the server.
function OSP.installClient()
    local ROOT="savegame.mod.osp."
    local menu,tab,selected=false,"players",nil
    local toolMode,filter="global","all"
    local tipKey,tipSince,tooltip=nil,nil,nil
    local function resetTooltip() tipKey=nil;tipSince=nil;tooltip=nil end
    local toolsPopup=nil
    local shortcuts=OSP.Shortcuts
    local shortcutRequest,shortcutNotice,shortcutUntil=nil,nil,0
    local search=OSP.ToolSearch
    local movementSettings=nil
    local pages={players=1,tools=1,activity=1}
    local scroll,maxScroll,bodyHovered=0,0,false
    local typing,capturing,draft=false,false,""
    local confirm,status,statusUntil,notice,noticeUntil=nil,nil,0,nil,0
    local seq,pending,sentAt,lastAction=0,nil,0,nil
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
    local function lang() return GetString(ROOT.."language")=="pt" and "pt" or "en" end
    OSP.getLanguage=lang
    local function T(k,...) return OSP.L(k,...) end
    local function state() return shared and shared.osp or nil end
    local function roster() local s=state();return s and s.players or {} end
    local function findPlayer(id) for _,p in ipairs(roster()) do if p.id==id then return p end end end
    local function host() return IsPlayerHost(me) end
    local function admin() local p=findPlayer(me);return host() or (p and p.admin==true) or false end
    local function allowed(action,target,arg)
        if host() then return true end
        local p=findPlayer(me)
        local values=p and p.permissions
        if not values then values=OSP.Permissions.resolve(p and p.admin and "admin" or "guest").permissions end
        return OSP.Permissions.allows(values,action,target,arg,me)
    end
    local function permittedControl(id)
        if id=="tab_permissions" or id:match("^permission_") or id:match("^role_") then return host() and (not pending or id=="tab_permissions") end
        local target=selected or me
        local verb=id:match("^player_action_(.+)$")
        if verb then return allowed(verb,target) end
        if id=="speed_down" or id=="speed_up" then return allowed("speed",target) end
        if id=="player_speed_value" then return allowed("speed",target) end
        if id=="god_settings" then return target==me and allowed("god",target) end
        if id=="fly_settings" or id=="fly_speed_value" or id=="fly_boost_value" then return allowed("fly",target) end
        if id=="noclip_settings" or id=="noclip_speed_value" or id=="noclip_boost_value" then return allowed("noclip",target) end
        if id=="player_admin" or id=="reset_player" then return host() end
        if id=="heal_all" or id=="bring_all" or id=="restart" or id=="reset_rules" then return allowed(id,0) end
        local key=id:match("^rule_(%a+)_")
        if key then return allowed("rule",0,{key=key}) end
        if id=="regen_on" or id=="regen_off" then return allowed("rule",0,{key="regen"}) end
        if id=="announcement_field" or id=="announcement_send" then return allowed("announce",0) end
        if id:match("^tool_more_") then return toolMode=="global" and host() or allowed("tools_all",0) end
        if id=="tools_enable_everyone" or id=="tools_disable_everyone" or id=="tools_enable_results_everyone" or id=="tools_disable_results_everyone" or id:match("^tool_everyone_") then return allowed("tools_all",0) end
        if id=="tools_reset_filtered" or id:match("^tool_reset_") then return host() end
        if id=="tools_enable_filtered" or id=="tools_disable_filtered" or id=="tools_enable_results" or id=="tools_disable_results" then return toolMode=="global" and host() or allowed("tools",target) end
        if id:match("^tool_") and not id:match("^tool_player_") and not id:match("^tool_mode_") then
            return toolMode=="global" and host() or allowed("tool",target)
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
    local function setStatus(s,seconds) status=s;statusUntil=GetTime()+(seconds or 5) end
    local function shortcutMessage(action,message,seconds)
        shortcutNotice=T(action=="god" and "god_short" or action).." · "..message
        shortcutUntil=GetTime()+(seconds or 5);setStatus(shortcutNotice,seconds)
    end
    local function closeMovement() movementSettings=nil;OSP.NumberInput.cancel();shortcuts.cancel() end
    local function closeTools() toolsPopup=nil;search.blur() end
    local function setTab(t)
        t=navigation.choose(t,function(id) return id=="settings" or id=="about" or admin() and (id~="permissions" or host()) end)
        if tab~=t then resetTooltip();closeMovement();closeTools();tab=t;scroll=0;confirm=nil;typing=false;capturing=false;shortcuts.cancel();OSP.PermissionUI.cancelInput();OSP.NumberInput.cancel() end
    end
    local function command(action,target,arg)
        if not admin() or not allowed(action,target,arg) then setStatus(T("result_denied"));return false end
        if pending then setStatus(T("request_pending"));return false end
        seq=seq+1;pending=seq;sentAt=GetTime();lastAction=action
        setStatus(T("request_sent"),8)
        ServerCall("server.ospCommand",me,action,target or 0,arg,pending)
        return true
    end
    local function ask(action,target,arg,message)
        typing=false;capturing=false;OSP.PermissionUI.cancelInput();OSP.NumberInput.cancel();InputClear()
        confirm={action=action,target=target or 0,arg=arg,message=message}
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
        disabled=disabled or not permittedControl(id) or ((confirm~=nil or movementSettings~=nil or toolsPopup~=nil) and not modal)
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
        if clicked then clickConsumed=true;OSP.NumberInput.cancel();shortcuts.cancel();capturing=false;search.blur() end
        local col=kind=="active" and C.selected or (hover and C.hover or C.surface)
        if kind=="plain" then col=hover and C.hover or C.side end
        if clicked then col=C.selected end
        if kind=="recovery" then col={.08,.08,.08,1} end
        rect(x,y,w,h,col)
        if kind=="outlined" then
            local edge=hover and C.accent or C.line
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
    local function numberField(id,x,y,w,h,value,minimum,maximum,decimals,onCommit,disabled,caption,modal)
        local text=OSP.NumberInput.active(id) and OSP.NumberInput.caption(id,value) or caption or tostring(value)
        local kind=OSP.NumberInput.active(id) and "active" or "plain"
        if modal and not OSP.NumberInput.active(id) then kind=nil end
        if button(id,x,y,w,h,text,kind,disabled,modal) then
            typing=false;capturing=false;OSP.PermissionUI.cancelInput()
            OSP.NumberInput.begin(id,value,minimum,maximum,decimals,onCommit)
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
        local list=roster()
        if selected and not findPlayer(selected) then selected=nil;confirm=nil;OSP.NumberInput.cancel() end
        if not selected and #list>0 then selected=findPlayer(me) and me or list[1].id end
        return findPlayer(selected)
    end
    local function actionForPlayer(p,verb,caption,value,kind)
        if verb=="kill" then ask("kill",p.id,nil,T("confirm_kill",utf8clip(p.name,24)))
        else command(verb,p.id,value) end
    end
    local function drawPlayers()
        local w=layout.contentW;local list=roster();local p=selectedPlayer()
        title(T("players_title"),T("player_count",#list))
        if not p then label(0,88,T("no_players"),18,C.muted,w);return 130 end
        local two=w>=650;local listW=two and math.min(250,math.floor(w*.31)) or w
        local ax=two and listW+24 or 0;local aw=two and w-ax or w
        local rows=two and math.max(2,math.min(5,math.floor((layout.contentH-155)/48))) or 2
        local listBottom=94+rows*48+40
        label(0,78,T("select_player"),14,C.muted,listW,true)
        local pageNum=math.max(1,math.min(math.max(1,math.ceil(#list/rows)),pages.players));pages.players=pageNum
        for i=1,rows do local player=list[(pageNum-1)*rows+i]
            if player then
                local role=roleLabel(player)
                local suffix="  ·  "..role
                if button("player_"..player.id,0,102+(i-1)*48,listW,40,utf8clip(player.name,15)..suffix,
                    player.id==p.id and "active" or "plain",false) then selected=player.id;confirm=nil end
            end
        end
        if #list>rows then page("players",#list,rows,0,102+rows*48) end
        local top=two and 82 or listBottom+8
        label(ax,top,p.name,22,C.text,aw,true)
        local life=math.floor((p.health or 0)*100+0.5)
        label(ax,top+31,T("health",life).."  ·  "..roleLabel(p),15,C.muted,aw)
        label(ax,top+53,T(host() and "player_options_saved" or "tip_temporary"),12,C.muted,aw)
        local blocked=p.host and not host();local waiting=host() and p.profileReady==false;local gap=8
        local cols=aw>=400 and 2 or 1;local bw=(aw-gap*(cols-1))/cols
        local buttons={
            {"heal","heal"},{"go_to","goto"},{"respawn","respawn"},{"bring","bring"},
            {"kill","kill",nil,"danger"},{"eject","eject"},
            {"god_mode","god",not p.god},{"freeze","freeze",not p.freeze},
            {"fly","fly",not p.fly},{"noclip","noclip",not p.noclip},
        }
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
        if host() and not p.host then
            if button("player_admin",ax,y,aw,37,T(p.admin and "revoke_admin" or "grant_admin"),"plain",waiting) then command("admin",p.id,not p.admin) end
            y=y+49
        end
        if host() then
            if waiting then label(ax,y,T("profile_waiting"),14,C.muted,aw);y=y+29 end
            if button("reset_player",ax,y,aw,37,T("reset_player"),"plain",waiting) then
                ask("reset_player",p.id,nil,T("confirm_reset_player",utf8clip(p.name,24)))
            end
            y=y+49
        end
        if button("heal_all",ax,y,bw,37,T("heal_all"),"plain",false) then command("heal_all",0) end
        if cols==2 then
            if button("bring_all",ax+bw+gap,y,bw,37,T("bring_all"),"plain",false) then command("bring_all",0) end
        else y=y+43;if button("bring_all",ax,y,bw,37,T("bring_all"),"plain",false) then command("bring_all",0) end end
        return math.max(listBottom,y+46)
    end
    local function drawPlayerTooltip()
        tooltip=nil
        if tab~="players" or confirm or movementSettings or toolsPopup or typing or capturing
            or search.focused or shortcuts.capture or OSP.NumberInput.active() or OSP.PermissionUI.capturing()
            or clickConsumed or InputDown("lmb") then resetTooltip();return end
        local p=findPlayer(selected)
        if not p then resetTooltip();return end
        local mx,my=layout.ox+mouseX,layout.oy+mouseY
        local persistent={god=true,freeze=true,fly=true,noclip=true,speed=true}
        local candidate,text
        for id,r in pairs(controls) do
            if inside(r.x,r.y,r.w,r.h,mx,my) then
                local action=id:match("^player_action_(.+)$")
                if id=="player_speed_value" or id=="speed_up" or id=="speed_down" then action="speed" end
                if id=="fly_settings" then action="fly" elseif id=="noclip_settings" then action="noclip" end
                local relevant=action or id=="player_admin" or id=="reset_player"
                if relevant then
                    if r.disabled then
                        if (action=="goto" or action=="bring") and p.id==me and permittedControl(id) then text=T("tip_select_another_player")
                        elseif p.host and not host() and action~="goto" then text=T("protects_host")
                        elseif host() and p.profileReady==false and (persistent[action] or id=="player_admin" or id=="reset_player") then text=T("profile_waiting")
                        elseif not permittedControl(id) then text=T("result_denied")
                        elseif action=="eject" and not p.vehicle then text=T("tip_no_vehicle") end
                    end
                    if not text then
                        if id=="fly_settings" or id=="noclip_settings" then text=T("tip_movement_settings")
                        elseif action=="fly" then text=T("tip_fly")
                        elseif action=="noclip" then text=T("tip_noclip")
                        elseif id=="player_admin" then text=T("tip_admin")
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
    local function drawPermissions()
        if not host() then setTab("settings");return 0 end
        title(T("permissions"),T("permissions_subtitle"))
        local list=roster();local p=selectedPlayer()
        local function playerIndex()
            for i,q in ipairs(list) do if p and p.id==q.id then return i end end
            return 1
        end
        return OSP.PermissionUI.draw({
            label=function(x,y,value,size,width) label(x,y,value,size,C.text,width) end,
            paragraph=function(x,y,value,size,width)
                UiPush();UiTranslate(x,y);UiAlign("left top");UiFont("regular.ttf",size)
                UiTextDisableWildcards(true);UiWordWrap(width);rgb(C.muted)
                local _,height=UiText(value);UiPop()
                return height
            end,
            button=button,ask=ask,command=command,resetScroll=function() scroll=0 end,
            playerCaption=function() return p and utf8clip(p.name,24) or "?" end,
            playerIndex=playerIndex,playerCount=function() return #list end,
            playerStep=function(d) local q=list[playerIndex()+d];if q then selected=q.id end end,
        },state() and state().templates,p,layout.contentW)
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
                function(value) command("rule",0,{key=r[1],value=value}) end,false,shown)
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
        if host() and button("restart",bw+10,y,bw,38,T("restart"),"danger",false) then ask("restart",0,nil,T("confirm_restart")) end
        y=y+58
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
    local function drawTools()
        local w=layout.contentW;local items,counts=filteredTools();local p=selectedPlayer()
        if not host() then toolMode="player" end
        title(T("tools_title_short"),T(toolMode=="global" and "global_description" or host() and "player_tools_saved" or "selected_only"))
        local y=77;local bw=math.min(230,(w-8)/2)
        if button("tool_mode_global",0,y,bw,34,T("global_rules"),toolMode=="global" and "active" or "plain",not host()) then toolMode="global";pages.tools=1 end
        if button("tool_mode_player",bw+8,y,bw,34,T("player_rules"),toolMode=="player" and "active" or "plain",false) then toolMode="player";pages.tools=1 end
        y=y+44
        if toolMode=="player" then
            local list=roster();local index=1
            for i,q in ipairs(list) do if p and q.id==p.id then index=i end end
            label(0,y+8,T("selected_player")..": "..(p and p.name or "—"),16,C.text,w-120)
            if button("tool_player_prev",w-108,y,48,32,"<","plain",index<=1) then selected=list[index-1].id end
            if button("tool_player_next",w-54,y,48,32,">","plain",index>=#list) then selected=list[index+1].id end
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
                local locked=policy=="disabled" and toolMode=="player"
                local enabled=p and IsToolEnabled(tool.id,p.id) or false
                local active=enabled
                if toolMode=="global" then active=policy=="default" and IsToolEnabled(tool.id,me) or policy=="enabled" end
                local meta=locked and T("blocked_by_host") or toolMode=="global" and T("policy_"..policy) or T(enabled and "tool_enabled" or "tool_disabled")
                label(0,ry+3,toolName(tool),17,C.text,w-204)
                label(0,ry+24,meta,13,C.muted,w-204)
                if button("tool_"..tool.id,w-194,ry+3,144,34,T(active and "deactivate" or "activate"),active and "active" or "plain",not p or (toolMode=="player" and (blocked or locked and not enabled))) then
                    if toolMode=="global" then
                        local mode=active and "disabled" or "enabled"
                        if active then ask("tool_policy",0,{id=tool.id,mode=mode},T("confirm_tool_global",toolName(tool)))
                        else command("tool_policy",0,{id=tool.id,mode=mode}) end
                    else command("tool",p.id,{id=tool.id,enabled=not enabled}) end
                end
                if button("tool_more_"..tool.id,w-40,ry+3,40,34,"...","plain",toolMode=="global" and policy=="default") then openActions(tool) end
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
                local key=({heal="heal",kill="kill",respawn="respawn",["goto"]="go_to",bring="bring",eject="eject",god="god_mode",fly="fly",fly_speed="fly_normal_action",fly_boost="fly_shift_action",noclip_speed="noclip_normal_action",noclip_boost="noclip_shift_action",noclip="noclip",freeze="freeze",speed="speed",admin="admin_access",role_assign="permissions",role_save="permissions",role_delete="permissions",reset_player="reset_player",heal_all="heal_all",bring_all="bring_all",rule="session_rules",reset_rules="reset_rules",restart="restart",announce="announcement",tool="tools",tool_all="tools",tools="tools",tools_all="tools",tool_policy="global_rules",tool_policy_bulk="global_rules",tool_policy_selection="global_rules",tools_selection="tools",tools_selection_all="tools",tools_filtered="tools",tools_filtered_all="tools"})[e.action] or "status"
                local detail=T(key)
                if type(e.argument)=="table" then
                    local a=e.argument
                    if a.key then
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
                label(w-result,y+7,e.result=="ok" and T("done") or T("error_short"),15,e.result=="ok" and C.success or C.danger,result)
                label(0,y+28,T("counts_short",e.affected or 0,e.skipped or 0),13,C.muted,w)
                rect(0,y+46,w,1,C.line);y=y+48
            end
        end
        page("activity",#log,per,0,y+6);return y+48
    end
    local function drawSettings()
        local w=layout.contentW;title(T("settings"),T("settings_subtitle"))
        local y=85;label(0,y,T("language"),17,C.text,w,true);y=y+29
        if button("language_en",0,y,160,38,T("english"),lang()=="en" and "active" or "plain",false) then SetString(ROOT.."language","en");setStatus(T("preference_saved")) end
        if button("language_pt",168,y,160,38,T("portuguese"),lang()=="pt" and "active" or "plain",false) then SetString(ROOT.."language","pt");setStatus(T("preference_saved")) end
        y=y+59;rect(0,y,w,1,C.line);y=y+20
        label(0,y,T("menu_key"),17,C.text,w,true);y=y+29
        label(0,y+9,string.upper(keybind()),18,C.accent,100,true)
        local menuCapture=shortcuts.capture=="menu"
        if button("rebind",130,y,math.min(220,w-130),38,T(menuCapture and "cancel" or "change_key"),"plain",false) then
            if menuCapture then shortcuts.cancel() else shortcuts.begin("menu") end
            capturing=shortcuts.capture=="menu";typing=false;confirm=nil
        end
        y=y+59;rect(0,y,w,1,C.line);y=y+20
        y=y+10
        y=y+navigation.draw({
            label=function(x,py,value,size,width) label(x,py,value,size,C.text,width) end,
            button=function(id,x,py,width,height,value,kind) return button(id,x,py,width,height,value,kind,false) end,
        },0,y,w)+12
        local height=OSP.Theme.draw({
            label=function(x,py,value,size,width,color) label(x,py,value,size,color or C.text,width) end,
            button=function(id,x,py,width,height,value,kind) return button(id,x,py,width,height,value,kind,false) end,
            number=numberField,
            rect=rect,
            mouse=function() return mouseX,mouseY end,
            visible=function() return not confirm and (not clip or inside(clip.x,clip.y,clip.w,clip.h,mouseX,mouseY)) end,
            pressed=function() return not clickConsumed and (lmbPressed or InputPressed("lmb")) end,
            down=function() return InputDown("lmb") end,
            consume=function() clickConsumed=true;OSP.NumberInput.cancel() end,
        },0,y,w)
        return y+height
    end
    local function drawAbout()
        local w=layout.contentW;title(T("about_title"),T("about_subtitle"))
        local entries={{T("version",OSP.version),C.accent},{"Luiz-AVcruz",C.text},{T("about_summary"),C.text},
            {T("license"),C.text},{T("license_permission"),C.muted},{T("source_included"),C.text},
            {T("source_location"),C.muted},{T("source_offer"),C.muted},{T("limits"),C.muted}}
        local y=86
        for _,e in ipairs(entries) do
            UiPush();UiTranslate(0,y);UiAlign("left top");UiFont("regular.ttf",17);UiTextDisableWildcards(true)
            UiWordWrap(w);rgb(e[2]);local _,h=UiGetTextSize(e[1]);UiText(e[1]);UiPop()
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
        local personal=p.id==me;local god=current.mode=="god"
        local w=math.min(layout.w-32,540);local h=math.min(layout.h-24,god and 210 or personal and 396 or 340)
        local x,y=(layout.w-w)/2,(layout.h-h)/2
        if not clickConsumed and lmbPressed and not inside(x,y,w,h,mouseX,mouseY) then
            clickConsumed=true;closeMovement();return
        end
        rect(0,0,layout.w,layout.h,{0,0,0,.65});rect(x,y,w,h,C.side);rect(x,y,w,3,C.accent)
        label(x+20,y+18,T(current.mode.."_settings_title"),20,C.text,w-92,true)
        if button("movement_popup_close",x+w-54,y+12,36,34,"X",nil,false,true) then closeMovement();return end
        label(x+20,y+53,T("selected_short")..": "..p.name,15,C.muted,w-40)
        if not god then
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
        local py=y+(god and 86 or 180)
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
        if not god then
            paragraph(T("fly_speed_note"),13,C.muted)
            if current.mode=="fly" then paragraph(T("fly_help"),14,C.muted) end
            paragraph(T("fly_controls"),14,C.muted)
        end
        py=y+h-42
        paragraph(OSP.NumberInput.active() and T("number_help") or shortcuts.capture and T("press_key") or personal and shortcuts.problem(current.mode) and T(shortcuts.problem(current.mode)) or shortcuts.message and T(shortcuts.message) or (status and GetTime()<statusUntil and status) or T("movement_popup_help"),13,C.accent)
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
                if danger then ask(verb,arg.target,arg.value,T("tools_confirm_selection",count).." "..T(caption).." · "..(arg.scope or "").." · "..(v.tool and utf8clip(toolName(v.tool),40) or T("filter_"..v.category)..(query and " · "..query or "")))
                else command(verb,arg.target,arg.value) end
            end
        end
        if v.mode=="global" then
            label(x+18,py,T("global_description"),14,C.muted,w-36);py=py+28
            if not v.tool then
                action("tools_enable_filtered","enable_category","left","tool_policy_selection",{target=0,value={category=v.category,ids=v.ids,mode="enabled"}},false,not host())
                action("tools_disable_filtered","disable_category","right","tool_policy_selection",{target=0,scope=T("global_rules"),value={category=v.category,ids=v.ids,mode="disabled"}},true,not host());py=py+44
                if searching then
                    action("tools_enable_results","tools_enable_results","left","tool_policy_selection",{target=0,value={category=v.category,ids=v.resultIds,mode="enabled"}},false,not host() or #v.resultIds==0,v.query)
                    action("tools_disable_results","tools_disable_results","right","tool_policy_selection",{target=0,scope=T("global_rules"),value={category=v.category,ids=v.resultIds,mode="disabled"}},true,not host() or #v.resultIds==0,v.query);py=py+44
                end
            end
            action("tools_reset_filtered","restore_category","center",v.tool and "tool_policy" or "tool_policy_selection",{target=0,scope=T("global_rules"),value=v.tool and {id=v.tool.id,mode="default"} or {category=v.category,ids=v.ids,mode="default"}},true,not host())
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
            action("tools_enable_everyone",v.tool and "enable_everyone" or "enable_category","left",verb,{target=0,value=args(true)},false,not allowed("tools_all",0) or v.tool and v.tool.policy=="disabled")
            action("tools_disable_everyone",v.tool and "disable_everyone" or "disable_category","right",verb,{target=0,scope=T(host() and "tools_present" or "tools_present_except_host"),value=args(false)},true,not allowed("tools_all",0));py=py+44
            if searching then
                action("tools_enable_results_everyone","tools_enable_results","left","tools_selection_all",{target=0,value={category=v.category,ids=v.resultIds,enabled=true}},false,not allowed("tools_all",0) or #v.resultIds==0,v.query)
                action("tools_disable_results_everyone","tools_disable_results","right","tools_selection_all",{target=0,scope=T(host() and "tools_present" or "tools_present_except_host"),value={category=v.category,ids=v.resultIds,enabled=false}},true,not allowed("tools_all",0) or #v.resultIds==0,v.query)
            end
        end
        label(x+18,y+h-34,T("movement_popup_help"),13,C.accent,w-36)
    end
    local function drawModal()
        if not confirm then return end
        local w=math.min(layout.w-32,540);local h=math.min(layout.h-32,232);local x=(layout.w-w)/2;local y=(layout.h-h)/2
        rect(0,0,layout.w,layout.h,{0,0,0,.65});rect(x,y,w,h,C.side);rect(x,y,w,3,C.accent)
        label(x+20,y+18,T("confirmation"),20,C.text,w-40,true)
        UiPush();UiTranslate(x+20,y+55);UiAlign("left top");UiFont("regular.ttf",17)
        UiTextDisableWildcards(true);UiWordWrap(w-40);UiWindow(w-40,h-124,true,true)
        rgb(C.text);UiText(confirm.message);UiPop()
        local awaitingFrame=not confirm.ready
        if button("confirm_cancel",x+w-246,y+h-53,102,38,T("cancel"),"plain",awaitingFrame,true) then confirm=nil;return end
        if button("confirm_accept",x+w-136,y+h-53,116,38,T("confirm"),"danger",awaitingFrame,true) then
            local current=confirm;confirm=nil;command(current.action,current.target,current.arg)
        end
        if confirm then confirm.ready=true end
    end
    local function render()
        setTab(tab)
        local tabs=navigation.list();local navCols=math.min(4,#tabs)
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
        if tab=="players" or (tab=="tools" and toolMode=="player") then
            local target=findPlayer(selected) or roster()[1]
            local x=math.max(260,W-490)
            if target and W-145-x>=90 then label(x,headerCenter-14/2,T("selected_short")..": "..target.name,14,C.muted,W-145-x) end
        end
        if button("close",W-122,headerCenter-34/2,104,34,T("close"),"outlined",false) then shortcuts.cancel();menu=false;closeTools();confirm=nil;typing=false;capturing=false;OSP.PermissionUI.cancelInput();OSP.NumberInput.cancel() end
        if not narrow then rect(0,header,side,H-header,C.side);rect(side,header,1,H-header,C.line) end
        for i,t in ipairs(tabs) do
            local x,y,w,h
            if narrow then w=(W-36-(navCols-1)*4)/navCols;h=32;x=18+((i-1)%navCols)*(w+4);y=header+7+math.floor((i-1)/navCols)*36
            else x=12;y=header+19+(i-1)*43;w=side-24;h=37 end
            if button("tab_"..t,x,y,w,h,T(t),tab==t and "active" or "outlined",not admin() and t~="settings" and t~="about") then setTab(t) end
        end
        if not narrow then label(22,H-32,T("version",OSP.version),13,C.muted,side-44) end
        clip={x=cx,y=cy,w=cw,h=ch};bodyHovered=inside(cx,cy,cw,ch,mouseX,mouseY)
        UiPush();UiTranslate(cx,cy);UiWindow(cw,ch,true,true);UiTranslate(0,-scroll)
        mouseX,mouseY=mouseX-cx,mouseY-cy+scroll
        drawOx,drawOy=ox+cx,oy+cy-scroll
        clip={x=0,y=scroll,w=cw,h=ch}
        local contentHeight=0
        local s=state()
        if not s or not s.ready then title(T("connecting"));contentHeight=90
        elseif not admin() and tab~="settings" and tab~="about" then setTab("settings");contentHeight=drawSettings()
        elseif tab=="players" then contentHeight=drawPlayers()
        elseif tab=="session" then contentHeight=drawSession()
        elseif tab=="tools" then contentHeight=drawTools()
        elseif tab=="permissions" then contentHeight=drawPermissions()
        elseif tab=="activity" then contentHeight=drawActivity()
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
        drawPlayerTooltip();drawMovementPopup();drawToolsPopup();drawModal();UiPop()
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
        local names={ok="result_ok",denied="result_denied",invalid="result_invalid",protected="result_protected",unavailable="result_unavailable",error="result_error",rate_limited="result_rate_limited",state_changed="shortcut_state_changed",conflict="role_conflict",template_limit="role_limit"}
        local msg=T(names[code] or "result_error")
        if details and details.skipped and details.skipped>0 then msg=msg.."  "..T("skipped",details.skipped) end
        if ok and lastAction=="rule" then msg=T("rules_saved") elseif ok and lastAction=="reset_rules" then msg=T("rules_reset") end
        if ok and lastAction=="role_save" and details then OSP.PermissionUI.saved(details.template) end
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
        if LoadLanguageTable and GetInt then LoadLanguageTable(GetInt("options.language")) end
        if GetString(ROOT.."language")=="" then SetString(ROOT.."language","en") end
        if not OSP.validKey(GetString(ROOT.."menu_key")) then SetString(ROOT.."menu_key","p") end
    end
    function client.tick(dt)
        -- Preserve a simultaneous click before keyboard capture calls InputClear.
        if (InputLastPressedKey() or "")~="" or InputPressed("lmb") or InputValue("mousewheel")~=0 then resetTooltip() end
        local wasMenu=menu
        setTab(tab)
        lmbPressed=InputPressed("lmb")
        if me==0 then me=GetLocalPlayer() end
        local s=state()
        local p=findPlayer(me)
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
        if selected and not findPlayer(selected) then selected=nil;confirm=nil;OSP.NumberInput.cancel() end
        if movementSettings then
            local target=findPlayer(movementSettings.player)
            if not target or target.profileChallenge~=movementSettings.challenge or selected~=target.id
                or not allowed(movementSettings.mode,target.id) then closeMovement();lmbPressed=false;InputClear() end
        end
        if toolsPopup then
            local target=findPlayer(toolsPopup.player)
            if not target or target.profileChallenge~=toolsPopup.challenge then closeTools();lmbPressed=false;InputClear() end
        end
        if menu and toolsPopup and InputPressed("esc") then closeTools();lmbPressed=false;InputClear()
        elseif menu and movementSettings and InputPressed("esc") then
            closeMovement();lmbPressed=false;InputClear()
        elseif menu and search.focused then
            if search.key() then pages.tools=1;scroll=0 end
        elseif menu and OSP.NumberInput.active() then
            OSP.NumberInput.key()
        elseif menu and tab=="permissions" and OSP.PermissionUI.capturing() then
            OSP.PermissionUI.key()
        elseif shortcuts.capture then
            shortcuts.key();capturing=shortcuts.capture=="menu"
            if shortcuts.message then setStatus(T(shortcuts.message)) end
        elseif typing then consumeText()
        else
            if InputPressed(keybind()) then menu=not menu;confirm=nil;if not menu then closeMovement();closeTools();OSP.PermissionUI.cancelInput();OSP.NumberInput.cancel() end end
            if menu and InputPressed("esc") then if confirm then confirm=nil else menu=false;closeMovement();closeTools();OSP.PermissionUI.cancelInput();OSP.NumberInput.cancel() end end
        end
        if menu and bodyHovered and not confirm and not movementSettings and not toolsPopup then
            local delta=InputValue("mousewheel")
            if delta~=0 then scroll=math.max(0,math.min(maxScroll,scroll-delta*48)) end
        end
        if PauseMenuButton(T("pause_button"),"bottom_bar",false) then menu=true;setTab(tab);confirm=nil end
        if not admin() and tab~="settings" and tab~="about" then setTab("settings") end
        if not wasMenu and not menu and not shortcuts.capture and not typing and not capturing
            and not confirm and not movementSettings and not toolsPopup and not search.focused
            and not OSP.NumberInput.active() and not OSP.PermissionUI.capturing()
            and not InputPressed(keybind()) and not shortcuts.modified() then
            local action,count=nil,0
            for _,id in ipairs(shortcuts.actions) do
                local key=shortcuts.binding(id)
                if key~="" and InputPressed(key) then action=id;count=count+1 end
            end
            if count==1 and not InputPressed("pause") and not InputPressed("esc") and not GetBool("game.paused") and GetPlayerCanUseTool(me) then
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
    end
    function client.draw()
        C=OSP.Theme.colors()
        if not menu then resetTooltip() end
        if not menu or tab~="settings" then OSP.Theme.cancelDrag() end
        clickConsumed=false
        if menu then UiMakeInteractive();render();lmbPressed=false;return end
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
    OSP.UI={getState=function() return {open=menu,tab=tab,selected=selected,confirm=confirm,movementPopup=OSP.copy(movementSettings),toolsPopup=OSP.copy(toolsPopup),searchQuery=search.query,searchFocused=search.focused,keyCapture=shortcuts.capture~=nil,shortcutNotice=shortcutNotice,typing=typing,language=lang(),menuKey=keybind(),requestPending=pending~=nil,pendingId=pending,status=status,layout=OSP.copy(layout),controls=OSP.copy(controls),tooltip=OSP.copy(tooltip),scroll=scroll,maxScroll=maxScroll,filter=filter,toolMode=toolMode} end,
        open=function(v) shortcuts.cancel();capturing=false;resetTooltip();menu=v==true;if not menu then closeMovement();closeTools();confirm=nil;typing=false;capturing=false;OSP.PermissionUI.cancelInput();OSP.NumberInput.cancel() end end,selectTab=setTab}
end
