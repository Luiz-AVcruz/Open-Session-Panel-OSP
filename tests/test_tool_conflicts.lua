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

do
    local w=world()
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
    local w,make=world();conflict(w,23)
    local before=offWrites(w,23)
    for _=1,20 do external(w,23) end
    eq(offWrites(w,23),before,'no OFF writes after suspension')
    eq(w.players[23].tools.airstrike,true,'tool remains externally enabled')
    for _=1,8 do
        w.players[23].tool='airstrike';external(w,23)
        check(w.players[23].tool~='airstrike','blocked tool is deselected even after inventory control stops')
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
    w.players[23].tools.othermod=true;w.players[23].tool='airstrike';external(w,23)
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
        w:draw();w:clickControl('compatibility_notice_close')
        w:scrollTo('tool_gun');local st=w:draw()
        check(not st.controls.tool_gun.disabled,'global usage control remains available')
        if st.controls.tool_sledge then check(not st.controls.tool_sledge.disabled,'normal tool stays interactive') end
        w:clickControl('tool_more_gun');w:draw()
        local found=false
        for _,text in ipairs(w.texts) do
            if text==e.OSP.languages[language].tool_conflict_help then found=true end
        end
        check(found,'popup explains suspension and saved rules')
        w:clickControl('tools_popup_close')
        e.shared.osp.players[1].toolConflicts={}
        w:scrollTo('tool_gun');st=w:draw();check(not st.controls.tool_gun.disabled,'partial global action remains possible')
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
    eq(#w.sent,0,'showing notice sends no gameplay command')
    check(st.confirm.message:find(e.OSP.L('compatibility_notice'),1,true),'notice explains limitation in selected language')
    w:clickControl('compatibility_notice_close')
    check(not w:draw().confirm,'acknowledgement closes notice')
    w:clickControl('tab_about');w:draw()
    local found=false
    for _,text in ipairs(w.texts) do if text==e.OSP.L('compatibility_airstrike') then found=true end end
    check(found,'About attributes the examined conflict to Airstrike behavior')
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
print('PASS tool conflict suspension, command boundaries and UI: '..count..' assertions')
