-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
local count=0
local function check(v,m) assert(v,m);count=count+1 end
local function eq(a,b,m) check(a==b,(m or 'equality')..': '..tostring(a)..' ~= '..tostring(b)) end
local function equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function fixture(width,height,registry)
    local f=assert(loadfile('tests/test_client.lua'))
    setfenv(f,setmetatable({arg={arg[1],'fixture'}},{__index=_G}))
    local world=f()
    return world(width or 1920,height or 1080,registry)
end

local w=fixture();local e=w.api;local A=e.OSP.Activity
local logs={
    {seq=7,actor='Host',action='tool',target='Offline',result='partial',affected=2,skipped=1,inventoryConflicts=2,argument={id='gun',enabled=true}},
    {seq=5,actor='Twin',action='tools',target='',result='ok',affected=1,skipped=0,argument={category='vanilla',tools=1,enabled=true}},
    {seq=6,actor='Team',action='players_group',target='',result='ok',affected=2,skipped=0,argument={action='heal',scope='all',enabled=true}},
    {seq=7,actor='Other',action='rule',target='',result='error',affected=0,skipped=1,argument={key='rain',value=.25}},
    {seq=3,actor='Older',action='heal',target='Host',result='ok',affected=1,skipped=0},
    {actor='Niña',action='status',target='',result='error',affected=0,skipped=0},
    {seq=2,actor='Twin',action='tool_policy',target='',result='ok',affected=1,skipped=0,argument={id='gun',mode='enabled'}},
}
local context={templates={},tools={{id='gun',name='Pistol'}}}
local function T(key,...)
    return e.OSP.L(key,...)
end
local function toolName(tool) return tool.name end
local function clip(value,n) return value end
local state=A.new()
local rows=A.filtered(logs,state,context,T,toolName,clip)
eq(rows[1].entry.action,'tool','equal sequences keep source order')
eq(rows[2].entry.action,'rule','equal sequence second entry stays second')
eq(rows[4].entry.actor,'Niña','missing sequence falls back to its original position')
state.toggleOrder();rows=A.filtered(logs,state,context,T,toolName,clip)
eq(rows[1].entry.action,'tool_policy','ascending order starts with the smallest sequence')
eq(rows[2].entry.action,'heal','stable ascending sequence order')
eq(rows[3].entry.actor,'Twin','equal sequence stays source-stable')

local options=A.actionOptions(logs,'ammo_restore',T);local grouped,restore=0,false
for _,item in ipairs(options) do
    if item.id=='tools' then grouped=grouped+1 end
    if item.id=='ammo_restore' then restore=true end
end
eq(grouped,1,'actions sharing the Tools label use one filter option')
check(restore,'selected action stays labelled after it leaves the log')
local people=A.playerOptions(logs,'Removed player',T);local names={}
for _,item in ipairs(people) do names[item.label]=(names[item.label] or 0)+1 end
eq(names.Twin,1,'repeated player names are grouped')
check(names.Offline==1,'disconnected historical target remains selectable')
check(names['Removed player']==1,'selected player stays labelled after leaving the buffer')
check(names.Team==1 and names.Niña==1,'only names recorded in the log are offered')
eq(A.playerFromOptionId(A.playerOptionId('Offline')),'Offline','historical player filter id round-trips')

state=A.new();state.setPlayer('Host');rows=A.filtered(logs,state,context,T,toolName,clip)
eq(#rows,2,'player filter matches actor or target')
state.setAction('tools');rows=A.filtered(logs,state,context,T,toolName,clip)
eq(#rows,1,'action and player filters combine with AND')
eq(rows[1].entry.action,'tool','combined filter keeps the actor match')
state.setPlayer('Offline');rows=A.filtered(logs,state,context,T,toolName,clip)
eq(#rows,1,'offline target matches without consulting the live roster')
state.search.query='#7';rows=A.filtered(logs,state,context,T,toolName,clip)
eq(#rows,1,'literal search includes the visible action sequence ID')
state.setAction('all');state.setPlayer(nil);state.search.query='25%'
rows=A.filtered(logs,state,context,T,toolName,clip)
eq(#rows,1,'literal percent finds the formatted rain detail')
state.search.query='players_group';rows=A.filtered(logs,state,context,T,toolName,clip)
eq(#rows,1,'raw action ID is searchable')
state.search.query='failed';rows=A.filtered(logs,state,context,T,toolName,clip)
eq(#rows,2,'localized result text is searchable')
state.action='tools';state.player='Offline';state.search.query='no match'
rows=A.filtered(logs,state,context,T,toolName,clip)
eq(#rows,0,'search, action and player filters combine with AND')
state.order='asc';state.search.query='';check(not state.isDefault(),'non-default filters are detected')
state.reset();check(state.isDefault() and state.order=='desc','clear resets query, filters and ordering')

-- The helper sorts copies and preserves the server-owned snapshot.
local original=e.OSP.copy(logs);A.filtered(logs,A.new(),context,T,toolName,clip)
check(equal(logs,original),'filtering never mutates the shared log')
local hundred={}
for i=1,100 do hundred[i]={seq=i,actor='Host',action='heal',target='',result='ok',affected=1,skipped=0} end
rows=A.filtered(hundred,A.new(),context,T,toolName,clip)
eq(#rows,100,'the panel handles the server log limit')
eq(rows[1].entry.seq,100,'newest sequence appears first at the limit')
table.remove(hundred,1);hundred[#hundred+1]={seq=101,actor='Host',action='heal',target='',result='ok',affected=1,skipped=0}
rows=A.filtered(hundred,A.new(),context,T,toolName,clip)
eq(#rows,100,'rolling log remains bounded')
eq(rows[1].entry.seq,101,'new activity does not require resetting ordering')
eq(rows[#rows].entry.seq,2,'oldest retained activity follows the discarded entry')

-- Every catalog has the same format placeholders; unknown preferences use EN.
local function placeholders(value)
    local out={}
    for spec in value:gmatch('%%[%+%- #0-9%.]*[a-zA-Z]') do out[#out+1]=spec:sub(-1) end
    return table.concat(out)
end
for key,value in pairs(e.OSP.languages.en) do
    check(e.OSP.languages.es[key]~=nil,'Spanish key exists: '..key)
    eq(placeholders(e.OSP.languages.es[key]),placeholders(value),'Spanish format placeholders: '..key)
end
for _,language in ipairs({'en','pt','es'}) do
    for _,option in ipairs(e.OSP.languageOptions) do
        check(e.OSP.languages[language][option.key]~=nil,'language selector label exists in '..language..': '..option.key)
    end
    for _,key in ipairs({'activity_search','activity_search_help','activity_action_filter','activity_player_filter',
        'activity_order_newest','activity_order_oldest','activity_clear','activity_all_actions','activity_all_players',
        'activity_entries_count','activity_no_history','activity_no_matches','activity_id'}) do
        check(e.OSP.languages[language][key]~=nil,'new key exists in '..language..': '..key)
    end
end
eq(e.OSP.languages.en.portuguese,'Português','language labels keep their own names in English')
eq(e.OSP.languages.pt.english,'English','language labels keep their own names in Portuguese')
eq(e.OSP.languages.es.spanish,'Español','language labels keep their own names in Spanish')
w.reg['savegame.mod.osp_beta.language']='es'
eq(e.OSP.L('activity_entries_count',2,7),'2 de 7 registros','Spanish formatted activity count')
eq(e.OSP.L('activity_id',17),'#17','formatted visible sequence id')
e.OSP.languages.en.__fallback_probe='English fallback';e.OSP.languages.es.__fallback_probe=nil
w.reg['savegame.mod.osp_beta.language']='es'
eq(e.OSP.resolveLanguage('es'),'es','Spanish preference resolves')
eq(e.OSP.L('__fallback_probe'),'English fallback','missing Spanish string falls back to English')
w.reg['savegame.mod.osp_beta.language']='unknown'
eq(e.OSP.getLanguage(),'en','unknown preference resolves to English')
eq(e.OSP.L('activity_subtitle'),'Actions recorded in this session.','unknown preference displays English')

local function chooseDropdown(ui, field, option)
    ui:clickControl(field)
    for _=1,20 do
        local st=ui:draw()
        if st.controls[option] then ui:clickControl(option);return end
        local box=st.activityDropdown and st.activityDropdown.bounds
        if box then ui.mouse={x=box.x+box.w/2,y=box.y+box.h/2};ui:tick(nil,-2) end
    end
    error('Activity dropdown option not reachable: '..option)
end

-- Live UI: all controls remain present with an empty log, and search capture
-- is independent from ToolsSearch and menu/ability shortcuts.
for _,size in ipairs({{640,480},{1024,768},{1920,1080}}) do
    local ui=fixture();ui.width=size[1];ui.height=size[2];local env=ui.api
    env.OSP.UI.open(true);ui:clickControl('tab_activity')
    local empty=ui:draw()
    for _,id in ipairs({'activity_search','activity_action_filter','activity_player_filter','activity_order','activity_clear'}) do
        check(empty.controls[id]~=nil,'empty Activity keeps control reachable at '..size[1]..'x'..size[2]..': '..id)
    end
    check(table.concat(ui.texts,'|'):find(env.OSP.L('activity_no_history'),1,true)~=nil,'empty history has its own message')
    env.OSP.ToolSearch.query='tools-only';ui:clickControl('activity_search');ui:tick('ñ')
    eq(env.OSP.UI.getState().activity.query,'ñ','activity captures UTF-8 text')
    eq(env.OSP.ToolSearch.query,'tools-only','activity query is independent from ToolSearch')
    ui:tick('backspace');eq(env.OSP.UI.getState().activity.query,'','activity Backspace removes the full UTF-8 character')
    ui:tick('p');check(env.OSP.UI.getState().open,'menu shortcut does not close while Activity search is focused')
    eq(env.OSP.UI.getState().activity.query,'p','focused input captures the menu shortcut key as text')
    ui:tick('backspace');ui:tick('f1');eq(env.OSP.UI.getState().activity.query,'','named key does not enter Activity query')
    check(#ui.sent==0,'search and empty filters send no gameplay RPC')
end

-- Settings exposes the shared language list at all requested UI widths.
for _,size in ipairs({{640,480},{1024,768},{1920,1080}}) do
    local ui=fixture();ui.width=size[1];ui.height=size[2];local env=ui.api
    ui.reg['savegame.mod.osp_beta.settings.collapsed.language']='0';env.OSP.UI.open(true);ui:clickControl('tab_settings')
    for _,language in ipairs({'en','pt','es'}) do
        ui:clickControl('language_'..language)
        eq(env.OSP.UI.getState().language,language,'Settings selects '..language..' at '..size[1]..'x'..size[2])
    end
    eq(#ui.sent,0,'Settings language is a local preference')
end

-- Filters, sorting and their labels survive locale changes, tab changes and
-- closing/reopening; a new client context starts clean for the next mission.
do
    local ui=fixture();local env=ui.api;env.shared.osp.log=e.OSP.copy(logs);env.OSP.UI.open(true);ui:clickControl('tab_activity')
    chooseDropdown(ui,'activity_action_filter','activity_action_filter_option_heal')
    eq(env.OSP.UI.getState().activity.action,'heal','action dropdown applies its filter')
    chooseDropdown(ui,'activity_player_filter','activity_player_filter_option_player:Host')
    eq(env.OSP.UI.getState().activity.player,'Host','player dropdown filters historical actor or target names')
    ui:clickControl('activity_order');eq(env.OSP.UI.getState().activity.order,'asc','order toggle switches to oldest first')
    ui:clickControl('activity_search');ui:tick('o');ui:tick('l');ui:tick('d')
    local before=env.OSP.copy(env.shared.osp.log)
    ui.reg['savegame.mod.osp_beta.language']='es';local st=ui:draw()
    eq(st.activity.action,'heal','locale change keeps the selected action filter')
    eq(st.activity.order,'asc','locale change keeps ordering')
    check(table.concat(ui.texts,'|'):find(env.OSP.L('heal'),1,true)~=nil,'selected action label follows the current locale')
    ui:tick('z');st=ui:draw()
    check(table.concat(ui.texts,'|'):find(env.OSP.L('activity_no_matches'),1,true)~=nil,'empty result set differs from an empty history')
    ui:tick('backspace');eq(env.OSP.UI.getState().activity.query,'old','Backspace restores the prior search')
    env.OSP.UI.selectTab('tools');eq(env.OSP.UI.getState().activity.query,'old','tab change preserves Activity query')
    env.OSP.UI.selectTab('activity');eq(env.OSP.UI.getState().activity.action,'heal','tab return preserves Activity filter')
    env.OSP.UI.open(false);env.OSP.UI.open(true)
    eq(env.OSP.UI.getState().activity.order,'asc','closing and reopening preserves Activity state')
    eq(env.OSP.UI.getState().activity.query,'old','closing and reopening preserves Activity search')
    ui:clickControl('activity_clear');local cleared=env.OSP.UI.getState()
    check(cleared.activity.action=='all' and cleared.activity.player==nil and cleared.activity.query=='' and cleared.activity.order=='desc',
        'Clear filters resets search, action, player and order')
    eq(cleared.activityPage,1,'clear returns to the first page')
    check(equal(env.shared.osp.log,before),'UI interactions never mutate shared.log')
    local nextMap=fixture();nextMap.reg=ui.reg
    check(nextMap.api.OSP.UI.getState().activity.order=='desc' and nextMap.api.OSP.UI.getState().activity.query=='',
        'new client context does not persist Activity filters')
    eq(#ui.sent,0,'filters, tabs and language changes send no gameplay RPC')
end

-- A full buffer can roll over while a page is selected. The page clamps to
-- the new result count without clearing the selected type.
do
    local ui=fixture();local env=ui.api;local log={}
    for i=1,100 do
        log[i]={seq=i,actor='Host',action=i<=24 and 'tool' or 'heal',target='',result='ok',affected=1,skipped=0,
            argument=i<=24 and {id='gun',enabled=true} or nil}
    end
    env.shared.osp.log=log;env.OSP.UI.open(true);ui:clickControl('tab_activity')
    chooseDropdown(ui,'activity_action_filter','activity_action_filter_option_tools')
    ui:clickControl('activity_next');ui:clickControl('activity_next')
    eq(env.OSP.UI.getState().activityPage,3,'filtered Activity reaches page three')
    local rolled={}
    for i=1,88 do rolled[i]={seq=i+12,actor='Host',action='heal',target='',result='ok',affected=1,skipped=0} end
    for i=89,100 do rolled[i]={seq=i+12,actor='Host',action='tool',target='',result='ok',affected=1,skipped=0,argument={id='gun',enabled=true}} end
    env.shared.osp.log=rolled;local st=ui:draw()
    eq(st.activity.action,'tools','buffer rollover keeps the selected action and label')
    eq(st.activityPage,2,'page clamps to the remaining filtered results without resetting to one')
    local selected=false;for _,item in ipairs(A.actionOptions(rolled,st.activity.action,T)) do if item.id=='tools' then selected=item.label==T('tools') end end
    check(selected,'selected action remains in its dropdown after older rows roll out')
end

print('PASS Activity filters, Unicode search, localization and UI: '..count..' assertions')
