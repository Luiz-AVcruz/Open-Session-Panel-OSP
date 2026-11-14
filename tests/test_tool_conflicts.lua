-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Competing writes use the actual tool state between server ticks. They do not
-- change the OSP policy, emulating a mod that unconditionally enables its tool.
local count=0
local function check(value,message) assert(value,message);count=count+1 end
local function eq(a,b,message) check(a==b,(message or 'equality')..': '..tostring(a)..' ~= '..tostring(b)) end
local function fixture(name)
    local chunk=assert(loadfile('tests/test_'..name..'.lua'))
    setfenv(chunk,setmetatable({arg={arg[1],'fixture'}},{__index=_G}))
    return chunk()
end
local function world()
    local make=fixture('server')
    local w=make({catalog={'sledge','gun','airstrike','othermod'}})
    w.writes={}
    local set=w.api.SetToolEnabled
    w.api.SetToolEnabled=function(id,on,p)
        w.writes[#w.writes+1]={id=id,on=on,player=p};set(id,on,p)
    end
    return w,make
end
local function player(w,id)
    for _,p in ipairs(w.api.shared.osp.players) do if p.id==id then return p end end
end
local function suspended(w,id) return player(w,id).toolConflicts.airstrike==true end
local function offWrites(w,id)
    local n=0
    for _,v in ipairs(w.writes) do if v.id=='airstrike' and v.player==id and not v.on then n=n+1 end end
    return n
end
local function external(w,id) w.players[id].tools.airstrike=true;w.tick() end
local function conflict(w,id)
    eq(w.command(11,'tool',id,{id='airstrike',enabled=false}),true)
    for _=1,4 do external(w,id) end
    check(suspended(w,id),'rapid external re-enabling suspends this player/tool')
end
local conflictModeKey='savegame.mod.osp_beta.tool_conflict_modes.'..'616972737472696b65'

do
    local w=world()
    eq(w.api.shared.osp.toolConflictModes.airstrike,nil,'missing preference uses the suspension default')
    w.command(11,'tool',23,{id='airstrike',enabled=false})
    external(w,23);check(not suspended(w,23),'one reset is not a conflict')
    for _=1,6 do
        w.now=w.now+1.1;external(w,23)
        check(not suspended(w,23),'isolated resets do not accumulate forever')
    end
    for _=1,6 do
        w.command(11,'respawn',23)
        external(w,23)
        check(not suspended(w,23),'respawning resets the reversal sample')
    end
    eq(w.players[23].tools.airstrike,false,'ordinary enforcement continues')
end
do
    local w,make=world()
    eq(w.command(11,'tool_policy',0,{id='airstrike',mode='disabled'}),true)
    eq(w.command(11,'tool',23,{id='airstrike',enabled=true}),true,'host grant remains independent')
    local grantedOffWrites=offWrites(w,23)
    eq(w.command(11,'tool_conflict_mode',0,{id='airstrike',mode='attempt'}),true)
    eq(w.api.GetString(conflictModeKey),'attempt','choice persists in its own host namespace')
    eq(w.api.shared.osp.toolConflictModes.airstrike,'attempt')
    local activity=w.api.shared.osp.log[#w.api.shared.osp.log]
    eq(activity.action,'tool_conflict_mode');eq(activity.argument.id,'airstrike');eq(activity.argument.mode,'attempt')
    eq(w.api.shared.osp.toolPolicies.airstrike,false,'choice does not change global availability policy')
    eq(player(w,23).toolGrants.airstrike,true,'choice does not remove an exception')
    eq(player(w,23).toolRules.airstrike,true,'choice does not rewrite desired availability')
    eq(w.players[23].tools.airstrike,true,'granted tool stays enabled')
    eq(offWrites(w,23),grantedOffWrites,'granted tool receives no new OFF writes')
    external(w,23);external(w,23);external(w,23);external(w,23)
    check(not suspended(w,23),'allowed grant does not become a conflict from external inventory state')
    eq(w.players[23].tools.airstrike,true,'external activity does not override an allowed choice')

    eq(w.command(11,'tool',23,{id='airstrike',enabled=false}),true,'host can revoke the grant explicitly')
    local before=offWrites(w,23)
    for _=1,4 do external(w,23) end
    check(suspended(w,23),'attempt mode still detects the player-specific conflict')
    check(offWrites(w,23)>=before+4,'attempt mode keeps writing OFF after detection')
    w.players[23].tools.airstrike=true;w.players[23].tool='airstrike';external(w,23)
    check(w.players[23].tool~='airstrike','attempt mode keeps deselecting a denied conflicting tool')
    local beforeSuspend=offWrites(w,23)
    eq(w.command(11,'tool_conflict_mode',0,{id='airstrike',mode='suspend'}),true)
    eq(w.api.shared.osp.toolPolicies.airstrike,false,'suspension preserves the global policy')
    eq(player(w,23).toolGrants.airstrike,nil,'suspension does not invent or remove a grant')
    w.players[23].tools.airstrike=true;w.players[23].tool='airstrike';w.tick()
    eq(offWrites(w,23),beforeSuspend,'switching to suspend stops OFF writes on the next tick')
    eq(w.players[23].tool,'airstrike','suspend stops deselection on the next tick')
    eq(w.command(11,'tool_conflict_mode',0,{id='airstrike',mode='attempt'}),true)
    check(offWrites(w,23)>beforeSuspend,'switching back to attempt resumes normal denial')
    check(w.players[23].tool~='airstrike','switching back to attempt resumes deselection')

    local identity=w.identities[23]
    local nextMap=make({catalog={'sledge','gun','airstrike','othermod'},identities={[23]=identity}})
    eq(nextMap.api.shared.osp.toolConflictModes.airstrike,'attempt','saved choice reloads for a new map')
    nextMap.players[23].tools.airstrike=true;nextMap.tick()
    eq(nextMap.players[23].tools.airstrike,false,'late player conflict uses the restored choice')
    local late=make({catalog={'sledge','gun','othermod'},identities={[23]=identity}})
    eq(late.api.shared.osp.toolConflictModes.airstrike,'attempt','choice loads before its tool registers')
    late.writes={}
    local nativeSet=late.api.SetToolEnabled
    late.api.SetToolEnabled=function(id,on,p)
        late.writes[#late.writes+1]={id=id,on=on,player=p};nativeSet(id,on,p)
    end
    late.catalog={'sledge','gun','airstrike','othermod'};late.tick()
    check(not late.api.shared.osp.players[2].toolConflicts.airstrike,'registration alone does not invent a conflict')
    for _=1,5 do external(late,23) end
    check(late.api.shared.osp.players[2].toolConflicts.airstrike,'late registered tool uses the player-specific detector')
    local offBefore=0
    for _,v in ipairs(late.writes) do if v.id=='airstrike' and v.player==23 and not v.on then offBefore=offBefore+1 end end
    external(late,23)
    local offAfter=0
    for _,v in ipairs(late.writes) do if v.id=='airstrike' and v.player==23 and not v.on then offAfter=offAfter+1 end end
    check(offAfter>offBefore,'late registration respects the saved attempt strategy after detection')
end
do
    local make=fixture('server');local w=make({catalog={'sledge','gun','airstrike','othermod'}})
    w.api.SetString(conflictModeKey,'keep-trying')
    local bad=make({catalog={'sledge','gun','airstrike','othermod'}})
    eq(bad.api.shared.osp.toolConflictModes.airstrike,nil,'malformed saved mode fails closed to suspend')
    bad.writes={}
    local originalSet=bad.api.SetToolEnabled
    bad.api.SetToolEnabled=function(id,on,p)
        bad.writes[#bad.writes+1]={id=id,on=on,player=p};originalSet(id,on,p)
    end
    local ok,code=bad.command(11,'tool_conflict_mode',0,{id='airstrike',mode='keep-trying'})
    eq(ok,false);eq(code,'invalid','unsupported mode is rejected at the RPC boundary')
    ok,code=bad.command(11,'tool_conflict_mode',0,{id='missing',mode='attempt'})
    eq(ok,false);eq(code,'invalid','unregistered tool is rejected at the RPC boundary')
    ok,code=bad.command(11,'tool',23,{id='airstrike',enabled=false})
    eq(ok,true,code)
    for _=1,4 do external(bad,23) end
    check(suspended(bad,23),'malformed saved mode retains suspension after detection')
    local before=offWrites(bad,23)
    for _=1,8 do external(bad,23) end
    eq(offWrites(bad,23),before,'fail-closed suspend makes no further OFF writes')
end
do
    local w,make=world();conflict(w,23)
    local before=offWrites(w,23)
    for _=1,20 do external(w,23) end
    eq(offWrites(w,23),before,'no OFF writes after suspension')
    eq(w.players[23].tools.airstrike,true,'tool remains externally enabled')
    for _=1,8 do
        w.players[23].tool='airstrike';external(w,23)
        eq(w.players[23].tool,'airstrike','suspended conflict does not fight selecting Air Strike')
        w.players[23].tool='othermod';external(w,23)
        eq(w.players[23].tool,'othermod','suspended conflict does not interfere with other inventory items')
    end
    eq(offWrites(w,23),before,'selection restriction does not resume inventory flicker')
    check(not suspended(w,11),'host is independently controlled')
    eq(w.command(11,'tool',11,{id='airstrike',enabled=false}),true)
    eq(w.players[11].tools.airstrike,false,'normal host control remains available')
    local ok,code,details=w.command(11,'tool',23,{id='airstrike',enabled=false})
    eq(ok,true);eq(code,'ok');eq(details.inventoryConflicts,1);eq(details.affected,1)
    eq(offWrites(w,23),before,'direct RPC cannot bypass suspension')
    -- The original desired restriction survives, but suspension itself does not.
    local identity=w.identities[23]
    local nextMap=make({catalog={'sledge','gun','airstrike','othermod'},identities={[23]=identity}})
    check(not suspended(nextMap,23),'new map retries compatibility')
    nextMap.players[23].tools.airstrike=true;nextMap.tick()
    eq(nextMap.api.IsToolEnabled('airstrike',23),false,'saved desired rule survives suspension')
    -- Explicit enabling is safe and can remove a dormant personal block.
    eq(w.command(11,'tool',23,{id='airstrike',enabled=true}),true)
    check(suspended(w,23),'enabling does not re-arm an incompatible block')
    eq(w.command(11,'tool',23,{id='airstrike',enabled=false}),true)
    eq(offWrites(w,23),before)
end
do
    local w=world();conflict(w,23)
    local before=offWrites(w,23)
    local cases={
        {'tools',23,false}, {'tools_all',0,false},
        {'tools_filtered',23,{category='mod',enabled=false}},
        {'tools_filtered_all',0,{category='mod',enabled=false}},
        {'tools_selection',23,{category='mod',ids={'airstrike','othermod'},enabled=false}},
        {'tools_selection_all',0,{category='mod',ids={'airstrike','othermod'},enabled=false}},
        {'tool_all',0,{id='airstrike',enabled=false}},
        {'tool_policy',0,{id='airstrike',mode='disabled'}},
        {'tool_policy_bulk',0,{category='mod',mode='disabled'}},
        {'tool_policy_selection',0,{category='mod',ids={'airstrike','othermod'},mode='disabled'}},
    }
    for _,v in ipairs(cases) do
        local ok,code,details=w.command(11,v[1],v[2],v[3])
        eq(ok,true,v[1]..' retains the usage restriction');eq(code,'ok')
        eq(details.inventoryConflicts,1,v[1]..' reports use-only block')
        eq(offWrites(w,23),before,v[1]..' cannot bypass suspension')
        eq(w.players[23].tools.airstrike,true)
    end
    eq(w.players[23].tools.othermod,false,'other mod tools still blocked')
    eq(w.players[11].tools.airstrike,false,'global policy works on compatible players')
    -- Never choose another forbidden tool as the fallback, even if an
    -- external writer keeps several blocked inventory entries enabled.
    w.command(11,'tool_policy_bulk',0,{category='all',mode='disabled'})
    w.players[23].tools.othermod=true;w.players[23].tool='othermod';external(w,23)
    eq(w.players[23].tool,'','no permitted replacement leaves an empty selection')
    for _,id in ipairs({11,47}) do
        for _=1,4 do external(w,id) end
        check(suspended(w,id))
    end
    local ok,code,details=w.command(11,'tool_policy',0,{id='airstrike',mode='disabled'})
    eq(ok,true);eq(code,'ok');eq(details.inventoryConflicts,3);eq(details.affected,3)
    eq(w.command(11,'tool_policy',0,{id='airstrike',mode='default'}),true,'can remove dormant policy')
    local log=w.api.shared.osp.log
    eq(log[#log-1].inventoryConflicts,3,'activity retains fallback count')
end
do
    local w=world();conflict(w,23)
    local identity=w.identities[23]
    w.removed={23};w.tick();w.identify(23,identity)
    check(not suspended(w,23),'reused player ID has fresh compatibility state')
    conflict(w,23)
    w.catalog={'sledge','gun','othermod'};w.tick()
    check(not suspended(w,23),'removed tool discards transient detector')
    w.catalog={'sledge','gun','airstrike','othermod'};w.tick()
    eq(w.players[23].tools.airstrike,false,'re-registered tool retries saved block')
end

local ui=fixture('client')
for _,language in ipairs({'en','pt'}) do
    for _,size in ipairs({{640,480},{1920,1080}}) do
        local w=ui(size[1],size[2],{['savegame.mod.osp_beta.language']=language})
        local e=w.api
        e.IsToolEnabled=function(id) return id=='gun' or id=='sledge' end
        for _,p in ipairs(e.shared.osp.players) do p.toolConflicts={gun=true} end
        w:tick('p');w:draw();w:clickControl('tab_tools')
        local notice=w:draw()
        check(notice.confirm and notice.confirm.compatibility,'detected tool opens the compatibility choice')
        check(notice.controls.compatibility_choice_suspend and notice.controls.compatibility_choice_attempt,'authorized viewer gets both handling choices')
        w:clickControl('compatibility_notice_x')
        w:scrollTo('tool_gun');local st=w:draw()
        check(not st.controls.tool_gun.disabled,'global usage control remains available')
        if st.controls.tool_sledge then check(not st.controls.tool_sledge.disabled,'normal tool stays interactive') end
        w:clickControl('tool_more_gun');w:draw()
        local found=false
        for _,text in ipairs(w.texts) do
            if text==e.OSP.languages[language].tool_conflict_suspend_help then found=true end
        end
        check(found,'popup explains suspension and saved rules')
        w:clickControl('tools_popup_close')
        e.shared.osp.players[1].toolConflicts={}
        w:scrollTo('tool_gun');st=w:draw();check(not st.controls.tool_gun.disabled,'global tool action remains available')
        w:clickControl('tool_mode_player');w:clickControl('tool_player_next')
        w:scrollTo('tool_gun');st=w:draw();check(not st.controls.tool_gun.disabled,'usage control remains available for affected player')
        e.shared.osp.players[2].toolRules={gun=false}
        st=w:draw()
        w:clickControl('tool_gun')
        local sent=w.sent[#w.sent]
        eq(sent.args[2],'tool');eq(sent.args[4].enabled,true,'toggle uses desired block instead of visible inventory state')
        e.client.ospResult(true,'ok',{inventoryConflicts=1},sent.args[5])
        check(e.OSP.UI.getState().status:find(e.OSP.L('tool_inventory_count',1),1,true),'response explains use-only block')
        w:clickControl('tool_more_gun');st=w:draw()
        check(not st.controls.tools_disable_everyone.disabled,'bulk usage block remains available')
    end
end
-- First encounter is informational: it must not send a gameplay command,
-- consume a pending response, or recur after a map/game restart.
for _,language in ipairs({'en','pt'}) do
    local reg={['savegame.mod.osp_beta.language']=language}
    local w=ui(1024,768,reg);local e=w.api
    e.shared.osp.players[1].toolConflicts={gun=true}
    w:tick('p');w:draw();w:clickControl('tab_tools')
    local st=w:draw();check(st.confirm and st.confirm.info,'first encounter opens informational modal')
    check(st.controls.compatibility_choice_suspend and st.controls.compatibility_choice_attempt,'host can explicitly choose each handling mode')
    eq(#w.sent,0,'showing notice sends no gameplay command')
    check(st.confirm.message:find(e.OSP.L('compatibility_notice'),1,true),'notice explains limitation in selected language')
    w:clickControl('compatibility_notice_x')
    check(not w:draw().confirm,'acknowledgement closes notice')
    w:clickControl('tab_about');w:draw()
    local found=false
    for _,text in ipairs(w.texts) do if text==e.OSP.L('compatibility_detected_help') then found=true end end
    check(found,'About explains only the detected inventory conflict')
    for _,text in ipairs(w.texts) do check(text~='AC130 Airstrike','no static mod compatibility list') end
    e.shared.osp.players[1].toolConflicts={};w:draw()
    for _,text in ipairs(w.texts) do
        check(text~=e.OSP.L('compatibility_title'),'no compatibility section without a detected conflict')
    end
    local again=ui(1024,768,reg)
    again.api.shared.osp.players[1].toolConflicts={gun=true}
    again:tick('p');again:draw();again:clickControl('tab_tools')
    check(not again:draw().confirm,'local preference survives a new client/map')
    -- A different tool gets its own warning; unknown conflicts have no
    -- invented mod identity. Escape dismisses the notice without a request.
    again.api.shared.osp.players[1].toolConflicts.sledge=true
    check(again:draw().confirm.info,'new conflicting tool has separate first encounter')
    again:tick('esc');check(not again:draw().confirm,'Escape does not immediately reopen the notice')
    eq(#again.sent,0,'dismissal sends no gameplay command')
end
do
    local w=ui(1024,768,{});local e=w.api
    w:tick('p');w:draw();w:clickControl('tab_tools');w:clickControl('tool_gun')
    check(e.OSP.UI.getState().requestPending,'tool command is pending')
    e.shared.osp.players[1].toolConflicts={gun=true}
    check(not w:draw().confirm,'notice waits for pending command')
    w:ack();check(w:draw().confirm.info,'notice appears after response')
    eq(#w.sent,1,'informational modal never duplicates the tool command')
end
do
    local w=ui(1024,768,{});local e=w.api
    e.shared.osp.log={{seq=1,actor='Host',target='',action='tool_conflict_mode',result='ok',affected=3,skipped=0,
        inventoryConflicts=1,argument={id='gun',mode='attempt'}}}
    w:tick('p');w:draw();w:clickControl('tab_activity');w:draw()
    local found=false
    for _,text in ipairs(w.texts) do
        if text:find(e.OSP.L('compatibility_title'),1,true)
            and text:find(e.OSP.L('compatibility_mode_attempt'),1,true) and text:find('Pistol',1,true) then found=true end
    end
    check(found,'Activity names the affected tool and the localized compatibility choice')
    for _,text in ipairs(w.texts) do check(not text:find(e.OSP.L('status'),1,true),'Activity does not fall back to Status') end
end
for _,language in ipairs({'en','pt'}) do
    local w=ui(1024,768,{['savegame.mod.osp_beta.language']=language});local e=w.api
    e.shared.osp.tools[1]={id='airstrike',name='Air Strike',origin='mod',policy='disabled'}
    w:tick('p');w:draw();w:clickControl('tab_tools')
    check(not w:draw().confirm,'manual note alone does not declare a conflict')
    e.shared.osp.players[1].toolConflicts={airstrike=true}
    local st=w:draw()
    eq(st.confirm.message,e.OSP.L('compatibility_airstrike'),'known conflict identifies the supplying mod')
    w:clickControl('compatibility_notice_x');w:clickControl('tool_more_airstrike');w:draw()
    local found=false
    for _,text in ipairs(w.texts) do if text:find(e.OSP.L('compatibility_airstrike'),1,true) then found=true end end
    check(found,'tool popup uses manually documented cause')
    w:clickControl('tools_popup_compatibility');st=w:draw()
    check(st.confirm and st.confirm.toolId=='airstrike','tool popup reopens the choice for its detected tool')
    check(st.controls.compatibility_choice_suspend and st.controls.compatibility_choice_attempt,'reopened card keeps both authorized actions')
    w:clickControl('compatibility_notice_x')
    w:clickControl('tools_popup_close');w:clickControl('tab_about');w:draw();found=false
    for _,text in ipairs(w.texts) do if text:find(e.OSP.L('compatibility_airstrike'),1,true) then found=true end end
    check(found,'About uses the same known cause when detected')
    eq(#w.sent,0,'manual descriptions do not alter gameplay')
end
for _,language in ipairs({'en','pt'}) do
    for _,size in ipairs({{640,480},{1920,1080}}) do
        local w=ui(size[1],size[2],{['savegame.mod.osp_beta.language']=language});local e=w.api
        e.shared.osp.tools[1].policy='disabled'
        e.shared.osp.players[1].toolConflicts={gun=true}
        w:tick('p');w:draw();w:clickControl('tab_tools')
        w.capturePaint=true;local st=w:draw();w.capturePaint=false
        local card,cardIndex
        for i,paint in ipairs(w.paints) do
            if paint.kind=='rect' and paint.w>=400 and paint.w<st.layout.w and paint.h>200 and paint.h<st.layout.h then
                card=paint;cardIndex=i;break
            end
        end
        check(card~=nil,'choice card has a measurable background at '..size[1]..'x'..size[2])
        check(card.h<st.layout.h-24,'choice card content fits without viewport-height clipping')
        local suspend=st.controls.compatibility_choice_suspend
        local attempt=st.controls.compatibility_choice_attempt
        check(suspend and attempt and suspend.y==attempt.y,'choice buttons share one row')
        check(suspend.y+suspend.h<=card.y+card.h and attempt.y+attempt.h<=card.y+card.h,'choice buttons stay inside the card')
        for i=cardIndex+1,#w.paints do
            local paint=w.paints[i]
            if paint.kind=='text' then
                check(paint.x>=card.x and paint.x<card.x+card.w,'modal text starts within the card')
                check(paint.y>=card.y and paint.y+paint.font<=card.y+card.h,'modal text stays inside the card')
            end
        end
        w:clickControl('compatibility_choice_attempt')
        st=w:draw()
        check(st.requestPending and st.confirm.requestId~=nil,'choice waits for the ordinary server ACK')
        eq(st.controls.compatibility_choice_attempt.disabled,true,'choice buttons disable while the request is pending')
        eq(#w.sent,1,'choice sends exactly one mode command')
        eq(w.sent[1].args[2],'tool_conflict_mode');eq(w.sent[1].args[4].id,'gun');eq(w.sent[1].args[4].mode,'attempt')
        e.shared.osp.toolConflictModes={gun='attempt'}
        e.client.ospResult(true,'ok',{inventoryConflicts=1},st.confirm.requestId)
        w.capturePaint=true;st=w:draw();w.capturePaint=false
        check(st.confirm.result~=nil,'server ACK is shown inside the choice card')
        check(st.confirm.result:find(e.OSP.L('tool_inventory_count',1),1,true)~=nil,'ACK uses a generic conflict count while attempting')
        check(not st.confirm.result:find(e.OSP.L('tool_use_block_count',1),1,true),'ACK does not call an attempt a suspended block')
        local currentY,resultY,buttonY
        local currentText=e.OSP.L('compatibility_current',e.OSP.L('compatibility_mode_attempt'))
        for _,paint in ipairs(w.paints) do
            if paint.kind=='text' and paint.text==currentText then currentY=paint.y end
            if paint.kind=='text' and paint.text==st.confirm.result then resultY=paint.y end
        end
        buttonY=st.controls.compatibility_choice_attempt.y
        check(currentY and currentY<buttonY,'current mode stays above the action row')
        check(resultY and resultY< buttonY and resultY+14<=buttonY,'ACK result does not overlap the action row')
        eq(#w.sent,1,'ACK display does not duplicate the mode command')
        w:clickControl('compatibility_notice_x')
        st=w:draw();local attemptMeta=false
        for _,text in ipairs(w.texts) do if text==e.OSP.L('tool_attempt_count',1) then attemptMeta=true end end
        check(attemptMeta,'tool metadata distinguishes continued attempts from suspended blocks')
        w:clickControl('tool_more_gun');w:clickControl('tools_popup_compatibility')
        st=w:draw();check(st.confirm and st.confirm.toolId=='gun','the detected tool popup reopens the same choice')
        w:clickControl('compatibility_notice_x')
        eq(#w.sent,1,'closing and reopening never writes a mode')
    end
end
do
    local w=ui(640,480,{['savegame.mod.osp_beta.language']='pt'});local e=w.api
    local own=e.shared.osp.players[1]
    e.IsPlayerHost=function() return false end
    own.host=false;own.admin=true;own.permissions={tools=1};own.toolRules={gun=false}
    e.shared.osp.toolConflictModes={gun='attempt'};own.toolConflicts={gun=true}
    w:tick('p');w:draw();w:clickControl('tab_tools')
    local st=w:draw()
    check(st.confirm and st.confirm.compatibility,'tools-only delegate can read the detected conflict')
    eq(st.controls.compatibility_choice_suspend,nil,'tools-only delegate cannot suspend the global conflict handling')
    eq(st.controls.compatibility_choice_attempt,nil,'tools-only delegate cannot choose retry mode')
    check(table.concat(w.texts,'|'):find(e.OSP.L('compatibility_mode_attempt'),1,true)~=nil,'read-only notice shows the current choice')
    w:clickControl('compatibility_notice_close')
    eq(#w.sent,0,'read-only acknowledgement sends no mode command')
    eq(e.shared.osp.toolConflictModes.gun,'attempt','acknowledgement does not change the session choice')
    w:clickControl('tool_more_gun');w:clickControl('tools_popup_compatibility')
    st=w:draw();check(st.confirm and st.confirm.toolId=='gun','read-only tools popup can revisit the choice')
    eq(st.controls.compatibility_choice_attempt,nil,'reopened choice stays read-only')
    w:clickControl('compatibility_notice_close');eq(#w.sent,0)
end
for _,change in ipairs({'host','join','tool'}) do
    local w=ui(1024,768,{});local e=w.api
    e.shared.osp.players[1].toolConflicts={gun=true}
    w:tick('p');w:draw();w:clickControl('tab_tools')
    check(w:draw().confirm.compatibility,'real choice opens before stale-context check')
    if change=='host' then e.shared.osp.profileHost=string.rep('b',32)
    elseif change=='join' then e.shared.osp.players[1].profileChallenge=99
    else e.shared.osp.tools={{id='sledge',name='Sledge',origin='vanilla',policy='enabled'}} end
    st=w:draw()
    eq(st.confirm,nil,'stale '..change..' context closes the choice')
    eq(#w.sent,0,'stale '..change..' context cannot write a preference')
end
print('PASS tool conflict suspension, command boundaries and UI: '..count..' assertions')
