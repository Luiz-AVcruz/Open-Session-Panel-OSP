-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Simulates engine input and UI state. This is not a game renderer.
local assertions=0
local function check(v,msg) assert(v,msg);assertions=assertions+1 end
local function eq(a,b,msg) check(a==b,(msg or 'equality')..': '..tostring(a)..' ~= '..tostring(b)) end
local function world(width,height,previousRegistry)
    local w={reg=previousRegistry or {},sent={},texts={},now=0,input='',wheel=0,mouse={x=0,y=0},click=false,held=false,released=false,armed={},
        width=width,height=height,t={x=0,y=0,s=1},stack={},drawn=false,hp=1}
    local env=setmetatable({client={},shared={osp={ready=true,version='1.4.0',rules={},log={},
        tools={{id='gun',name='gun',nameKey='TOOL_NAME_GUN',origin='vanilla',policy='default'},
               {id='sledge',name='Sledge',origin='vanilla',policy='enabled'},
               {id='mytool',name=string.rep('X',90),origin='mod',policy='disabled'}},
        players={{id=11,name='Host',health=1,host=true,admin=true,god=false,fly=false,freeze=false,speed=1,vehicle=false,profileChallenge=1},
                 {id=23,name=string.rep('Long name ',20),health=1,host=false,admin=false,god=false,fly=false,freeze=false,speed=1,vehicle=true,profileChallenge=2}}}}},{__index=_G})
    env.GetString=function(k) return w.reg[k] or '' end
    env.SetString=function(k,v) w.reg[k]=v end
    env.GetBool=function(k) return w.reg[k] or false end
    env.SetBool=function(k,v) assert(k=='savegame.mod.osp.health_hud');w.reg[k]=v end
    env.GetInt=function() return 0 end;env.LoadLanguageTable=function() end
    env.GetTranslatedStringByKey=function(k,fallback) if k=='TOOL_NAME_GUN' then return 'Pistol' end;return fallback end
    env.GetLocalPlayer=function() return 11 end
    env.IsPlayerValid=function(p) return p==11 or p==23 end
    env.GetPlayerHealth=function() error('Client must not read health for an additional HUD') end
    env.IsPlayerHost=function(p) return p==11 end
    env.GetTime=function() return w.now end
    env.GetPlayerCanUseTool=function(p) assert(p==11);return w.canUseTool~=false end
    env.IsToolEnabled=function(id,p) return id=='sledge' end
    env.ServerCall=function(fn,...) w.sent[#w.sent+1]={fn=fn,args={...}} end
    env.PauseMenuButton=function() return false end
    env.InputLastPressedKey=function() return w.input end
    env.InputPressed=function(k) return k==w.input or (k=='lmb' and w.click) end
    env.InputDown=function(k) return k=="lmb" and w.held or (w.mods and w.mods[k]) or false end
    env.InputValue=function(k) assert(k=='mousewheel');return w.wheel end
    env.InputClear=function() w.input='';w.click=false;w.held=false;w.released=false;w.wheel=0 end
    env.SetFloat=function() error('HUD must never write health or gameplay') end
    env.UiPush=function() local t=w.t;w.stack[#w.stack+1]={x=t.x,y=t.y,s=t.s,font=t.font,color=t.color} end
    env.UiPop=function() assert(#w.stack>0,'balanced UI stack');w.t=table.remove(w.stack) end
    env.UiTranslate=function(x,y) w.t.x=w.t.x+x*w.t.s;w.t.y=w.t.y+y*w.t.s end
    env.UiScale=function(s) w.t.s=w.t.s*s end
    env.UiCanvasSize=function() return {w=w.width,h=w.height} end
    env.UiWidth=function() return width end;env.UiHeight=function() return height end
    env.UiFont=function(path,size) assert(path=='regular.ttf' or path=='bold.ttf');w.t.font=size end
    env.UiGetTextSize=function(s)
        local longest,lines=0,0
        for line in (s..'\n'):gmatch('(.-)\n') do
            local _,bytes=line:gsub('[\128-\191]','');longest=math.max(longest,#line-bytes);lines=lines+1
        end
        return longest*(w.t.font or 20)*.55,lines*(w.t.font or 20)
    end
    env.UiText=function(s) assert(w.drawn);w.texts[#w.texts+1]=s;if w.capturePaint then w.paints[#w.paints+1]={kind='text',x=w.t.x,y=w.t.y,font=w.t.font,color=w.t.color,text=s} end;return #s*(w.t.font or 20)*.55,w.t.font or 20 end
    env.UiGetMousePos=function() return (w.mouse.x-w.t.x)/w.t.s,(w.mouse.y-w.t.y)/w.t.s end
    -- A completed native click may be reported on release. InputPressed is
    -- a separate engine event; a press must not wait for this return value.
    env.UiBlankButton=function(bw,bh)
        local x,y=env.UiGetMousePos()
        local key=table.concat({w.t.x,w.t.y,bw,bh},":")
        local inside=x>=0 and y>=0 and x<bw and y<bh
        if w.click and inside then w.armed[key]=true end
        return w.released and inside and w.armed[key] or false
    end
    for _,name in ipairs({'UiColor','UiRect','UiWindow','UiAlign','UiMakeInteractive','UiWordWrap','UiTextDisableWildcards'}) do
        env[name]=function() assert(w.drawn,name..' outside draw') end
    end
    env.UiColor=function(...) assert(w.drawn);if w.capturePaint then w.t.color={...} end end
    env.UiRect=function(width,height)
        assert(w.drawn)
        if w.capturePaint then w.paints[#w.paints+1]={kind='rect',x=w.t.x,y=w.t.y,w=width*w.t.s,h=height*w.t.s,color=w.t.color} end
    end
    local chunk=assert(loadfile(arg[1]));setfenv(chunk,env);chunk();env.client.init();w.api=env
    function w:tick(key,wheel)
        self.now=self.now+.1;self.input=key or '';self.wheel=wheel or 0;env.client.tick(.1);self.input='';self.wheel=0
    end
    function w:draw()
        self.texts={};self.paints={};self.drawn=true;self.t={x=0,y=0,s=1};self.stack={}
        env.client.draw();self.drawn=false;eq(#self.stack,0,'UI stack balanced')
        return env.OSP.UI.getState()
    end
    function w:scrollTo(id)
        for _=1,40 do
            local st=self:draw();local r=st.controls[id]
            if r and r.w>=20 and r.h>=20 then return r end
            if st.maxScroll==0 then error('missing control: '..id) end
            local l=st.layout;self.mouse={x=l.ox+l.contentX+10,y=l.oy+l.contentY+l.contentH/2}
            if st.scroll>=st.maxScroll then self:tick(nil,100) else self:tick(nil,-1) end
        end
        error('control not reachable by scrolling: '..id)
    end
    function w:pressAt(x,y,key)
        self.now=self.now+1/60
        self.mouse={x=x,y=y};self.click=true;self.held=true;self.released=false;self.input=key or 'lmb'
        env.client.tick(1/60)
        local st=self:draw();self.click=false;self.input='';return st
    end
    function w:holdAt(x,y)
        self.now=self.now+1/60;self.mouse={x=x,y=y}
        self.click=false;self.held=true;self.released=false;self.input=''
        env.client.tick(1/60);return self:draw()
    end
    function w:releaseAt(x,y)
        self.now=self.now+1/60;self.mouse={x=x,y=y}
        self.click=false;self.held=false;self.released=true;self.input=''
        env.client.tick(1/60)
        local st=self:draw();self.released=false;self.armed={};return st
    end
    function w:clickControl(id)
        local r=self:scrollTo(id)
        check(not r.disabled,'disabled control: '..id)
        local x,y=r.x+r.w/2,r.y+r.h/2
        self:pressAt(x,y);self:releaseAt(x,y)
    end
    function w:ack(ok,code,id)
        env.client.ospResult(ok~=false,code or 'ok',{},id or self.sent[#self.sent].args[5])
    end
    return w
end
-- Identity is private to this host and survives a fresh client Lua context.
do
    local namespace=string.rep('a',32)
    local w=world(1920,1080);local e=w.api
    e.IsPlayerHost=function() return false end;e.shared.osp.profileHost=namespace
    w:tick();eq(w.sent[#w.sent].fn,'server.ospIdentify');eq(w.sent[#w.sent].args[3],1);eq(w.sent[#w.sent].args[4],'')
    local before=#w.sent;w:tick();eq(#w.sent,before,'identity requests are throttled')
    w.now=w.now+1;w:tick();eq(#w.sent,before+1,'lost reply can be retried')
    e.client.ospIdentity(string.rep('b',32),1,'p8');eq(w.reg['savegame.mod.osp.identity.'..namespace],nil)
    e.client.ospIdentity(namespace,1,'host');eq(w.reg['savegame.mod.osp.identity.'..namespace],nil)
    e.client.ospIdentity(namespace,1,'p8');eq(w.reg['savegame.mod.osp.identity.'..namespace],'p8')
    before=#w.sent;w.now=w.now+2;w:tick();eq(#w.sent,before,'ACK stops identity retries')
    e.shared.osp.players[1].profileChallenge=2;w.now=w.now+2;w:tick()
    e.client.ospIdentity(namespace,1,'p99');eq(w.reg['savegame.mod.osp.identity.'..namespace],'p8','old join reply is ignored')
    e.client.ospIdentity(namespace,2,'p9');eq(w.reg['savegame.mod.osp.identity.'..namespace],'p9')
    e.client.ospIdentity(namespace,1,'p8');eq(w.reg['savegame.mod.osp.identity.'..namespace],'p9','stale reply cannot overwrite current profile')
    local map=world(1024,768,w.reg);local m=map.api
    m.IsPlayerHost=function() return false end;m.shared.osp.profileHost=namespace;m.shared.osp.players[1].profileChallenge=3
    map:tick();eq(map.sent[#map.sent].args[4],'p9','new map sends saved identity')
    m.client.ospIdentity(namespace,2,'p99');eq(map.reg['savegame.mod.osp.identity.'..namespace],'p9','old map reply is ignored')
    m.shared.osp.profileHost=string.rep('c',32);map.now=map.now+2;map:tick()
    eq(map.sent[#map.sent].args[4],'','another host does not reuse the profile')
end
-- Mouse presses are sampled in tick before draw. Text capture must not
-- InputClear the LMB event before the Send/Close/tab button receives it.
do
    local w=world(1920,1080);local e=w.api;e.OSP.UI.open(true);e.OSP.UI.selectTab('session')
    w:clickControl('announcement_field');w:tick('h')
    local r=w:scrollTo('announcement_send');w:pressAt(r.x+2,r.y+2)
    eq(#w.sent,1,'focused text does not swallow send press')
    eq(w.sent[1].args[2],'announce');eq(w.sent[1].args[4],'h');w:releaseAt(r.x+2,r.y+2);w:ack()
    w:clickControl('announcement_field');w:tick('h')
    r=w:scrollTo('announcement_send');w:pressAt(r.x+2,r.y+2,'i')
    eq(#w.sent,2,'typing and clicking in the same frame does not lose the click')
    eq(w.sent[2].args[4],'hi','last typed character is included');w:releaseAt(r.x+2,r.y+2);w:ack()
    w:clickControl('tab_settings');w:clickControl('rebind')
    eq(e.OSP.UI.getState().keyCapture,true)
    w:clickControl('tab_about');eq(e.OSP.UI.getState().tab,'about','key capture does not swallow mouse navigation')
    eq(e.OSP.UI.getState().keyCapture,false);eq(e.OSP.UI.getState().menuKey,'p')
end
-- Corners are outside the short text label. Local actions must respond on
-- the down edge, with no repeat during hold or release, on every viewport.
for _,size in ipairs({{1280,720},{1920,1080},{1024,768},{2560,1080}}) do
 for _,language in ipairs({'en','pt'}) do
  for _,corner in ipairs({{2,2},{-2,2},{2,-2},{-2,-2}}) do
    local w=world(unpack(size));local e=w.api
    w.reg['savegame.mod.osp.language']=language;e.OSP.UI.open(true)
    local r=w:scrollTo('tab_settings')
    local function point(rect)
        return rect.x+(corner[1]>0 and corner[1] or rect.w+corner[1]),rect.y+(corner[2]>0 and corner[2] or rect.h+corner[2])
    end
    local x,y=point(r);w:pressAt(x,y)
    eq(e.OSP.UI.getState().tab,'settings','tab reacts on press in background padding')
    w:releaseAt(x,y)
    w:clickControl('palette_custom')
    r=w:scrollTo('palette_R_plus');x,y=point(r);w:pressAt(x,y)
    local color=w.reg['savegame.mod.osp.theme.custom.back']
    check(color~=nil,'RGB control reacts on press in background padding')
    for i=1,3 do w:holdAt(x,y);eq(w.reg['savegame.mod.osp.theme.custom.back'],color,'hold does not repeat') end
    w:releaseAt(x,y);eq(w.reg['savegame.mod.osp.theme.custom.back'],color,'release does not repeat')
    local st=w:draw();local count=#w.sent
    w:pressAt(x,st.layout.oy+st.layout.contentY+st.layout.contentH+4)
    eq(#w.sent,count,'outside viewport sends no command')
    eq(w.reg['savegame.mod.osp.theme.custom.back'],color,'outside viewport leaves color unchanged')
    w:releaseAt(x,y)
  end
 end
end
for _,size in ipairs({{1280,720},{1920,1080},{2560,1440},{1024,768},{2560,1080}}) do
 for _,language in ipairs({'en','pt'}) do
    local w=world(unpack(size));local e=w.api;w.reg['savegame.mod.osp.language']=language
    w:tick('p');local st=w:draw();eq(st.open,true)
    check(st.layout.w<=1120 and st.layout.h<=720,'panel maximum')
    check(st.layout.w<=size[1]*.85+.01 and st.layout.h<=size[2]*.82+.01,'canvas budget')
    eq(st.layout.narrow,st.layout.w<900,'navigation breakpoint')
    for _,r in pairs(st.controls) do
        check(r.x>=st.layout.ox-.01 and r.y>=st.layout.oy-.01 and r.x+r.w<=st.layout.ox+st.layout.w+.01 and r.y+r.h<=st.layout.oy+st.layout.h+.01,'control inside panel')
    end
    w:clickControl('player_23');eq(e.OSP.UI.getState().selected,23)
    eq(e.OSP.UI.getState().controls.mods_disable_player,nil,'redundant tools shortcut removed')
    w:clickControl('reset_player');eq(e.OSP.UI.getState().confirm.action,'reset_player')
    w:clickControl('confirm_accept');eq(w.sent[#w.sent].args[2],'reset_player');eq(w.sent[#w.sent].args[3],23);w:ack()
    w:clickControl('player_action_kill')
    w.width,w.height=1024,768;local resized=w:draw()
    eq(resized.selected,23,'selection survives resolution change');check(resized.confirm~=nil,'dialog survives resolution change')
    check(resized.layout.w<=w.width*.85+.01 and resized.layout.h<=w.height*.82+.01,'resized canvas budget')
    w:clickControl('confirm_cancel');w.width,w.height=size[1],size[2];w:draw()
    local sent=#w.sent;w:clickControl('player_action_kill');eq(#w.sent,sent,'kill requires confirmation')
    check(e.OSP.UI.getState().confirm~=nil,'kill confirm open')
    w:clickControl('confirm_cancel');eq(#w.sent,sent,'cancel sends nothing')
    w:clickControl('player_action_kill');w:clickControl('confirm_accept');eq(w.sent[#w.sent].args[2],'kill');eq(w.sent[#w.sent].args[3],23)
    local oldId=w.sent[#w.sent].args[5]
    w:clickControl('player_action_heal');eq(#w.sent,sent+1,'wait for acknowledgement');w:ack()
    w:clickControl('player_action_heal');w:clickControl('player_action_kill')
    e.client.ospResult(true,'ok',{},oldId);eq(e.OSP.UI.getState().requestPending,true);check(e.OSP.UI.getState().confirm~=nil,'old ACK does not close dialog')
    w:ack();check(e.OSP.UI.getState().confirm~=nil,'ACK preserves unsent dialog');w:clickControl('confirm_cancel')
    w:clickControl('player_action_heal');local late=w.sent[#w.sent].args[5];local count=#w.sent
    w.now=w.now+9;w:tick();eq(#w.sent,count,'no automatic replay');eq(e.OSP.UI.getState().requestPending,false)
    w:clickControl('player_action_heal');e.client.ospResult(true,'ok',{},late);eq(e.OSP.UI.getState().requestPending,true);w:ack()
    w:clickControl('tab_session');w:clickControl('announcement_field');w:tick('h');w:tick('p');eq(e.OSP.UI.getState().open,true)
    w:tick('return');eq(w.sent[#w.sent].args[2],'announce');eq(w.sent[#w.sent].args[4],'hp');w:ack()
    w:clickControl('restart');w:clickControl('confirm_accept');eq(w.sent[#w.sent].args[2],'restart');w:ack()
    w:clickControl('tab_tools');eq(e.OSP.UI.getState().toolMode,'global')
    w:clickControl('filter_mod');eq(e.OSP.UI.getState().filter,'mod')
    w:clickControl('tools_actions');w:clickControl('tools_disable_filtered');eq(e.OSP.UI.getState().confirm.action,'tool_policy_selection')
    w:clickControl('confirm_accept');eq(w.sent[#w.sent].args[2],'tool_policy_selection');eq(w.sent[#w.sent].args[4].category,'mod');w:ack()
    for i=1,30 do
        e.shared.osp.tools[#e.shared.osp.tools+1]={id='mod'..i,name='Extra tool '..i,origin='mod',policy='default'}
    end
    w:clickControl('filter_mod');local filterState=w:draw()
    check(filterState.controls.tool_gun==nil,'vanilla item absent from mods filter')
    check(filterState.controls.tools_next and not filterState.controls.tools_next.disabled,'long list has next page')
    w:clickControl('tools_next');local nextState=w:draw();check(nextState.controls.tool_mytool==nil,'pagination advances')
    w:clickControl('filter_vanilla');w:clickControl('tool_gun');eq(w.sent[#w.sent].args[2],'tool_policy');eq(w.sent[#w.sent].args[4].id,'gun');eq(w.sent[#w.sent].args[4].mode,'enabled');w:ack()
    w:clickControl('tool_mode_player');eq(e.OSP.UI.getState().toolMode,'player')
    w:clickControl('tool_gun');eq(w.sent[#w.sent].args[2],'tool');eq(w.sent[#w.sent].args[3],23);w:ack()
    w:clickControl('tools_actions');w:clickControl('tools_disable_everyone');eq(e.OSP.UI.getState().confirm.action,'tools_selection_all');w:clickControl('confirm_cancel')
    w:clickControl('tab_settings');eq(e.OSP.UI.getState().controls.health_toggle,nil,'health toggle removed')
    w:clickControl('palette_ocean');eq(w.reg['savegame.mod.osp.theme.mode'],'ocean')
    w:clickControl('palette_custom');w:clickControl('palette_R_plus')
    check(w.reg['savegame.mod.osp.theme.custom.back']~=nil,'custom RGB control saves')
    w:clickControl('palette_restore');eq(w.reg['savegame.mod.osp.theme.mode'],'classic')
    w:clickControl('rebind');w:tick('w');eq(e.OSP.UI.getState().keyCapture,true);w:tick('f8');eq(e.OSP.UI.getState().menuKey,'f8')
    local oldStatus=e.OSP.UI.getState().status;e.client.ospResult(false,'error',{},nil)
    eq(e.OSP.UI.getState().status,oldStatus,'unsolicited nil ACK ignored')
    w:clickControl('tab_about');w:draw();local combined=table.concat(w.texts,'|');check(combined:find('Luiz%-AVcruz')~=nil,'about author')
    e.client.ospAnnouncement('Host','Hello everyone');check(e.OSP.UI.getState().status:find('Hello everyone')~=nil,'announcement visible with menu open')
    e.OSP.UI.open(false);w.now=w.now+7
    w.reg['savegame.mod.osp.health_hud']=true -- Old saved preferences must not resurrect the removed HUD.
    w:draw();eq(#w.texts,0,'no health HUD even with old setting enabled')
    local nextMap=world(size[1],size[2],w.reg);nextMap:draw();eq(#nextMap.texts,0,'no HUD after map reload')
    e.IsPlayerHost=function() return false end;e.shared.osp.players[1].admin=false;e.OSP.UI.selectTab('players');w:tick();e.OSP.UI.open(true);w:draw();eq(e.OSP.UI.getState().tab,'settings')
    w:clickControl('tab_about');w:draw();eq(e.OSP.UI.getState().tab,'about','guests can read about')
    local d=world(size[1],size[2]);local de=d.api
    de.IsPlayerHost=function() return false end
    de.shared.osp.players[1].host=false;de.shared.osp.players[1].admin=true
    de.shared.osp.players[2].host=true;de.shared.osp.players[2].admin=true
    d:tick('p');d:clickControl('tab_tools');local ds=d:draw()
    eq(ds.toolMode,'player','delegated admin receives temporary mode')
    eq(ds.controls.tool_mode_global.disabled,true,'global policy restricted to host')
    d:clickControl('filter_mod');ds=d:draw()
    eq(ds.controls.tool_mytool.disabled,true,'global block prevents individual enabling')
    d:clickControl('filter_vanilla');d:clickControl('tool_player_next');ds=d:draw()
    eq(ds.controls.tool_gun.disabled,true,'delegated admin cannot change host tools')
    d:clickControl('tab_players')
    eq(d:draw().controls.mods_disable_everyone,nil,'redundant bulk shortcut removed')
    for k in pairs(e.OSP.languages.en) do check(e.OSP.languages.pt[k]~=nil,'missing PT '..k) end
    for k in pairs(e.OSP.languages.pt) do check(e.OSP.languages.en[k]~=nil,'missing EN '..k) end
 end
end
-- Gameplay requests share the full painted hit area, but still dispatch
-- once, wait for ACK, and require a second press for destructive confirmation.
do
    local w=world(1920,1080);local e=w.api;e.OSP.UI.open(true)
    local function edge(id)
        local r=w:scrollTo(id);return r.x+2,r.y+r.h-2
    end
    local x,y=edge('player_23');w:pressAt(x,y)
    eq(e.OSP.UI.getState().selected,23,'player selection on padding press')
    w:releaseAt(x,y)
    x,y=edge('player_action_heal');local count=#w.sent;w:pressAt(x,y)
    eq(#w.sent,count+1,'gameplay RPC starts on padding press')
    eq(e.OSP.UI.getState().status,e.OSP.L('request_sent'),'immediate feedback does not claim completion')
    eq(w.sent[#w.sent].args[2],'heal')
    for i=1,3 do w:holdAt(x,y);eq(#w.sent,count+1,'held press does not resend RPC') end
    w:releaseAt(x,y);eq(#w.sent,count+1,'release does not resend RPC');w:ack()
    local hx,hy=edge('player_action_heal')
    x,y=edge('player_action_kill');count=#w.sent;w:pressAt(x,y)
    eq(#w.sent,count,'opening confirmation never sends destructive RPC')
    local c=w:scrollTo('confirm_accept');local cx,cy=c.x+2,c.y+2
    w:holdAt(cx,cy);eq(#w.sent,count,'dragging held opening press onto confirm does not accept')
    w:releaseAt(cx,cy);eq(#w.sent,count,'release over confirmation does not accept')
    w:pressAt(hx,hy);eq(#w.sent,count,'modal blocks underlying gameplay button')
    w:releaseAt(hx,hy)
    w:pressAt(cx,cy);eq(#w.sent,count+1,'second new press confirms')
    eq(w.sent[#w.sent].args[2],'kill');w:releaseAt(cx,cy);w:ack()
    e.IsPlayerHost=function() return false end;e.shared.osp.players[1].admin=false
    w:tick();local st=w:draw();local disabled=st.controls.tab_tools;count=#w.sent
    w:pressAt(disabled.x+2,disabled.y+2)
    eq(e.OSP.UI.getState().tab,'settings','disabled tab ignores padding press');eq(#w.sent,count)
end
-- A host must not silently issue a temporary change before identification.
do
    local w=world(1024,768);local e=w.api
    e.shared.osp.players[2].profileReady=false;e.OSP.UI.open(true)
    w:clickControl('player_23')
    for _,id in ipairs({'player_action_god','player_action_fly','player_action_noclip','fly_settings','noclip_settings','player_speed_value','player_action_freeze','speed_up','player_admin','reset_player'}) do
        eq(w:scrollTo(id).disabled,true,'waiting profile disables '..id)
    end
    w:clickControl('tab_tools');w:clickControl('tool_mode_player')
    w:clickControl('tools_actions');eq(w:scrollTo('tools_enable_filtered').disabled,true)
    w:clickControl('tools_popup_close');eq(w:scrollTo('tool_gun').disabled,true)
end
-- An immediate host ACK must win over the provisional 'request sent' status.
do
    local w=world(1920,1080);local e=w.api;e.OSP.UI.open(true)
    e.ServerCall=function(fn,...)
        local a={...};w.sent[#w.sent+1]={fn=fn,args=a}
        e.client.ospResult(true,'ok',{},a[5])
    end
    w:clickControl('player_action_heal')
    eq(e.OSP.UI.getState().requestPending,false)
    eq(e.OSP.UI.getState().status,e.OSP.L('result_ok'),'synchronous ACK stays visible')
end
-- A non-empty history must distinguish values and toggle direction.
for _,language in ipairs({'en','pt'}) do
    local w=world(1920,1080);local e=w.api
    w.reg['savegame.mod.osp.language']=language
    e.shared.osp.log={
        {actor='Host',target='Guest',action='tool',argument={id='gun',enabled=true},result='ok'},
        {actor='Host',target='Guest',action='tool',argument={id='gun',enabled=false},result='ok'},
        {actor='Host',target='',action='rule',argument={key='rain',value=.2},result='ok'},
        {actor='Host',target='',action='rule',argument={key='rain',value=.8},result='ok'},
        {actor='Host',target='',action='announce',argument='A different announcement',result='ok'},
    }
    e.OSP.UI.open(true);e.OSP.UI.selectTab('activity');w:draw()
    local function hasBoth(a,b)
        for _,s in ipairs(w.texts) do if s:find(a,1,true) and s:find(b,1,true) then return true end end
        return false
    end
    check(hasBoth(e.OSP.L('on'),'Pistol'),'history shows enabled state')
    check(hasBoth(e.OSP.L('off'),'Pistol'),'history shows disabled state')
    check(hasBoth(e.OSP.L('rain'),'20%'),'history shows lower rain value')
    check(hasBoth(e.OSP.L('rain'),'80%'),'history shows higher rain value')
    check(hasBoth(e.OSP.L('announcement'),'A different'),'history includes announcement content')
end
-- Host role assignment and its separate custom-role editor.
for _,size in ipairs({{1024,768},{1920,1080}}) do
 for _,language in ipairs({'en','pt'}) do
    local w=world(unpack(size));local e=w.api
    w.reg['savegame.mod.osp.language']=language
    e.shared.osp.templates=e.OSP.Permissions.list({})
    e.OSP.UI.open(true);w:clickControl('tab_permissions')
    local st=w:draw()
    eq(st.controls.role_editor_name,nil,'assignment view hides editor name')
    eq(st.controls.role_editor_save,nil,'assignment view hides editor save')
    eq(st.controls.role_scope_heal,nil,'assignment view hides editable permissions')
    w:clickControl('role_target_next')
    w:clickControl('role_select_next') -- Self only.
    w:clickControl('role_apply');eq(e.OSP.UI.getState().confirm.action,'role_assign')
    w:clickControl('confirm_accept')
    eq(w.sent[#w.sent].args[2],'role_assign');eq(w.sent[#w.sent].args[3],23);eq(w.sent[#w.sent].args[4].id,'self');w:ack()
    w:clickControl('role_create_custom')
    st=w:draw()
    eq(st.controls.role_apply,nil,'editor hides role assignment')
    eq(st.controls.role_target_prev,nil,'editor hides player selection')
    eq(st.controls.role_create_custom,nil,'editor hides custom-role browser actions')
    eq(w:scrollTo('role_editor_save').disabled,false,'new custom role can be saved')
    w:clickControl('role_editor_name');check(e.OSP.PermissionUI.capturing(),'name capture starts')
    w:clickControl('close');eq(e.OSP.PermissionUI.capturing(),false,'Close cancels name capture')
    e.OSP.UI.open(true);w:clickControl('role_editor_name');check(e.OSP.PermissionUI.capturing())
    e.OSP.UI.open(false);eq(e.OSP.PermissionUI.capturing(),false,'programmatic close cancels name capture')
    e.OSP.UI.open(true);w:clickControl('role_editor_name');w:tick('x')
    local beforeDiscard=#w.sent
    w:clickControl('role_editor_discard')
    eq(#w.sent,beforeDiscard,'discarding a new role sends no save request')
    eq(w:draw().controls.role_apply~=nil,true,'discard returns to role assignment')
    w:clickControl('role_create_custom');w:clickControl('role_editor_name')
    for i=1,40 do w:tick('backspace') end
    for letter in ('medi'):gmatch('.') do w:tick(letter) end
    local r=w:scrollTo('role_editor_save')
    w:pressAt(r.x+2,r.y+2,'c');w:releaseAt(r.x+2,r.y+2)
    local request=w.sent[#w.sent]
    eq(request.args[2],'role_save');eq(request.args[4].name,'medic')
    eq(request.args[4].permissions.heal,1,'copy keeps self scope')
    local saved={id='c1',name='medic',version=1,builtin=false,permissions=request.args[4].permissions}
    e.client.ospResult(true,'ok',{template=saved},request.args[5])
    -- Shared intentionally still contains only builtins: the ACK is enough to
    -- keep the new role selected after the editor returns to assignment.
    st=w:draw()
    eq(st.controls.role_editor_name,nil,'ACK returns to assignment view')
    eq(st.controls.role_create_custom~=nil,true,'ACK returns to custom-role actions')
    eq(w:scrollTo('role_edit_custom').disabled,false,'saved copy survives delayed shared state')
    w:clickControl('role_apply');eq(e.OSP.UI.getState().confirm.arg.id,'c1')
    w:clickControl('confirm_cancel')
    e.shared.osp.templates[#e.shared.osp.templates+1]=saved
    w:clickControl('role_edit_custom')
    st=w:draw()
    eq(st.controls.role_apply,nil,'editing a role cannot assign it in the editor')
    w:clickControl('role_scope_heal')
    local editedRequestRect=w:scrollTo('role_editor_save')
    w:pressAt(editedRequestRect.x+2,editedRequestRect.y+2,'c');w:releaseAt(editedRequestRect.x+2,editedRequestRect.y+2)
    local edited=w.sent[#w.sent].args[4]
    eq(w.sent[#w.sent].args[2],'role_save')
    eq(edited.id,'c1');eq(edited.version,1);eq(edited.permissions.heal,2,'scope changes independently')
    e.client.ospResult(false,'conflict',{},w.sent[#w.sent].args[5])
    eq(e.OSP.UI.getState().status,e.OSP.L('role_conflict'))
    st=w:draw()
    eq(st.controls.role_scope_heal.disabled,false,'conflict leaves the custom editor and draft active')
    saved.version=2;saved.permissions.heal=0
    for i,entry in ipairs(e.shared.osp.templates) do if entry.id=='c1' then e.shared.osp.templates[i]=saved end end
    w:draw()
    w:clickControl('role_editor_reload')
    w:clickControl('role_scope_heal') -- Reloaded blocked value, now allow self only.
    local r2=w:scrollTo('role_editor_save')
    w:pressAt(r2.x+2,r2.y+2,'c');w:releaseAt(r2.x+2,r2.y+2)
    local refreshed=w.sent[#w.sent].args[4]
    eq(refreshed.version,2,'reload uses latest template version')
    eq(refreshed.permissions.heal,1,'reload discards stale draft permissions')
    e.client.ospResult(false,'conflict',{},w.sent[#w.sent].args[5])
    w:draw()
    eq(w:scrollTo('role_editor_reload').disabled,false,'failed save preserves the latest draft')
    w:clickControl('role_editor_discard')
    eq(w:draw().controls.role_apply~=nil,true,'discard returns to assignment mode')
    w:clickControl('role_edit_custom')
    w:clickControl('role_editor_delete');w:clickControl('confirm_accept')
    eq(w.sent[#w.sent].args[2],'role_delete')
    e.client.ospResult(true,'ok',{deleted='c1'},w.sent[#w.sent].args[5])
    st=w:draw()
    eq(st.controls.role_editor_delete,nil,'delete ACK returns to assignment mode')
    eq(st.controls.role_select_next~=nil,true,'deleted role is hidden before shared catches up')
 end
end
-- Per-control UI gating agrees with the server's public capability vocabulary.
do
    local w=world(1920,1080);local e=w.api
    e.GetLocalPlayer=function() return 23 end;e.client.init()
    e.shared.osp.players[2].admin=true;e.shared.osp.players[2].role='self'
    e.shared.osp.players[2].permissions=e.OSP.Permissions.resolve('self').permissions
    e.OSP.UI.open(true);w:draw()
    eq(e.OSP.UI.getState().selected,23,'delegated panel defaults to its own player')
    eq(w:scrollTo('player_action_heal').disabled,false)
    eq(w:scrollTo('player_action_kill').disabled,true)
    eq(w:scrollTo('heal_all').disabled,true)
    w:clickControl('player_11')
    eq(w:scrollTo('player_action_heal').disabled,true,'self permission cannot edit another player')
    eq(w:scrollTo('tab_permissions').disabled,true,'template management is host-only')
    w:clickControl('tab_session')
    eq(w:scrollTo('rule_rain_up').disabled,true)
    eq(w:scrollTo('announcement_send').disabled,true)
    -- Revocation arriving while a modal is open still blocks command dispatch.
    w:clickControl('tab_players');w:clickControl('player_23')
    e.shared.osp.players[2].permissions=e.OSP.Permissions.resolve('admin').permissions
    w:clickControl('player_action_kill')
    e.shared.osp.players[2].permissions=e.OSP.Permissions.resolve('self').permissions
    local before=#w.sent;w:clickControl('confirm_accept')
    eq(#w.sent,before,'revocation prevents a stale confirmation from sending')
end
-- Numeric edits use the same permission/command path as the +/- controls.
for _,size in ipairs({{1024,768},{1920,1080}}) do
 for _,language in ipairs({'en','pt'}) do
    local w=world(unpack(size));local e=w.api
    w.reg['savegame.mod.osp.language']=language;e.OSP.UI.open(true)
    local function edit(id,text,action,value,key)
        w:clickControl(id);check(e.OSP.NumberInput.active(id),'number field takes focus')
        for char in text:gmatch('.') do w:tick(char) end
        local before=#w.sent;w:tick('return')
        eq(e.OSP.NumberInput.active(),false,'Enter ends numeric input')
        eq(#w.sent,before+1,'one numeric commit sends one request')
        local request=w.sent[#w.sent]
        eq(request.args[2],action)
        if key then eq(request.args[4].key,key);eq(request.args[4].value,value)
        else eq(request.args[4],value) end
        w:ack()
    end
    edit('player_speed_value','99','speed',3)
    edit('player_speed_value','-8','speed',.5)
    edit('player_speed_value','1,75','speed',1.75)
    eq(w:draw().controls.fly_speed_value,nil,'Fly tuning stays hidden until opened')
    w:clickControl('fly_settings')
    edit('fly_speed_value','12.5','fly_speed',12.5)
    edit('fly_boost_value','32','fly_boost',32)
    edit('fly_boost_value','999','fly_boost',100)
    edit('fly_speed_value','0','fly_speed',.5)
    local open=w:draw()
    eq(open.controls.fly_boost_value.h,34,'opening reveals the complete Shift field')
    w:clickControl('movement_popup_close')
    w:clickControl('noclip_settings')
    eq(w:draw().controls.fly_speed_value,nil,'Noclip popup does not show Fly fields')
    edit('noclip_speed_value','25.5','noclip_speed',25.5)
    edit('noclip_boost_value','41','noclip_boost',41)
    edit('noclip_boost_value','999','noclip_boost',100)
    edit('noclip_speed_value','0','noclip_speed',.5)
    w:clickControl('movement_popup_close');eq(w:draw().controls.noclip_speed_value,nil,'Noclip popup can close')
    w:clickControl('fly_settings')
    w:clickControl('movement_popup_close');eq(w:draw().controls.fly_speed_value,nil,'Fly popup can close')
    local before=#w.sent
    w:clickControl('player_speed_value');w:tick('2');w:tick('esc')
    eq(#w.sent,before,'Escape discards a numeric edit')
    eq(e.OSP.NumberInput.active(),false)
    w:clickControl('player_speed_value');w:tick('2');w:clickControl('close')
    eq(#w.sent,before,'Close cannot save an unfinished number')
    eq(e.OSP.NumberInput.active(),false)
    e.OSP.UI.open(true);w:clickControl('player_speed_value')
    local r=w:scrollTo('speed_up');w:pressAt(r.x+2,r.y+2,'9');w:releaseAt(r.x+2,r.y+2)
    eq(#w.sent,before+1,'simultaneous typing and mouse keeps the +/- press')
    eq(w.sent[#w.sent].args[4],1.25,'+/- discards the unfinished typed value');w:ack()
    w:clickControl('tab_session')
    edit('rule_time_value','0','rule',.1,'time')
    edit('rule_time_value','9','rule',2,'time')
    edit('rule_rain_value','-1','rule',0,'rain')
    edit('rule_rain_value','7','rule',1,'rain')
    edit('rule_rain_value','0.37','rule',.37,'rain')
    edit('rule_fog_value','1','rule',10,'fog')
    edit('rule_fog_value','9000','rule',1000,'fog')
    edit('rule_fog_value','151.8','rule',152,'fog')
    -- Each row captures its own rule key, and edits cannot survive navigation.
    before=#w.sent;w:clickControl('rule_fog_value');w:tick('5');w:clickControl('tab_players');w:tick('return')
    eq(#w.sent,before,'changing tabs cancels the number draft')
    w:clickControl('tab_settings');w:clickControl('palette_custom')
    local color=e.OSP.Theme.colors().back
    local green,blue=math.floor(color[2]*255+.5)/255,math.floor(color[3]*255+.5)/255
    w:clickControl('palette_R_value');w:tick('9');w:tick('9');w:tick('9');w:tick('return')
    eq(e.OSP.Theme.colors().back[1],1,'RGB typed in the panel clamps at 255')
    eq(e.OSP.Theme.colors().back[2],green,'editing red keeps green')
    eq(e.OSP.Theme.colors().back[3],blue,'editing red keeps blue')
    eq(#w.sent,before,'personal color editing sends no server command')
 end
end
do
    local w=world(1920,1080);local e=w.api
    e.GetLocalPlayer=function() return 23 end;e.client.init()
    local p=e.shared.osp.players[2];p.admin=true;p.role='self';p.permissions=e.OSP.Permissions.resolve('self').permissions
    e.OSP.UI.open(true);w:draw();w:clickControl('player_speed_value');w:tick('2')
    p.permissions=e.OSP.Permissions.normalize({})
    local before=#w.sent;w:tick('return')
    eq(#w.sent,before,'revoking speed access also blocks an already-open field')
    p.permissions=e.OSP.Permissions.resolve('self').permissions
    w:clickControl('player_11');eq(w:scrollTo('player_speed_value').disabled,true,'self-only scope protects other numeric targets')
    w:clickControl('player_23');w:clickControl('player_speed_value');w:tick('2')
    p.profileChallenge=99;w:tick('return')
    eq(#w.sent,before,'a reused session player cannot receive an old numeric edit')
end
do
    local w=world(1024,768);local e=w.api
    e.GetLocalPlayer=function() return 23 end;e.client.init()
    local p=e.shared.osp.players[2];p.admin=true;p.permissions=e.OSP.Permissions.normalize({fly=1})
    e.OSP.UI.open(true);w:draw()
    eq(w:scrollTo('noclip_settings').disabled,true,'Fly grants cannot edit Noclip')
    w:clickControl('fly_settings');w:clickControl('fly_speed_value');w:tick('2')
    p.permissions=e.OSP.Permissions.normalize({})
    local before=#w.sent;w:tick('return');eq(#w.sent,before,'revocation blocks an open movement editor')
    p.permissions=e.OSP.Permissions.normalize({noclip=1});w:draw()
    eq(w:scrollTo('fly_settings').disabled,true,'Noclip grants cannot edit Fly')
    w:clickControl('noclip_settings');w:clickControl('noclip_boost_value');w:tick('4')
    p.profileChallenge=77;w:tick('return');eq(#w.sent,before,'movement tuning checks the target join before sending')
    w:clickControl('noclip_settings');w:clickControl('noclip_speed_value');w:tick('5')
    w:clickControl('movement_popup_close');w:clickControl('player_11');w:tick('return')
    eq(#w.sent,before,'switching target discards movement drafts')
    eq(w:scrollTo('noclip_settings').disabled,true,'self-only Noclip cannot edit host settings')
end
for _,size in ipairs({{640,480},{1024,768},{1920,1080}}) do
 for _,language in ipairs({'en','pt'}) do
    local w=world(unpack(size));local e=w.api
    w.reg['savegame.mod.osp.language']=language;e.OSP.UI.open(true)
    local a=w:scrollTo('player_action_fly');local b=w:scrollTo('player_action_noclip')
    eq(a.y,b.y,'Fly and Noclip share one row');check(a.x<b.x,'Fly is left of Noclip')
    for _,mode in ipairs({'fly','noclip'}) do
        local before=#w.sent
        w:clickControl(mode..'_settings');local st=w:draw()
        eq(st.movementPopup.mode,mode,'opening click keeps the popup open')
        eq(st.controls.player_action_heal.disabled,true,'popup blocks background controls')
        local field=w:scrollTo(mode..'_speed_value');eq(field.h,34)
        local boost=w:scrollTo(mode..'_boost_value');eq(boost.h,34)
        check(field.x>=st.layout.ox and field.x+field.w<=st.layout.ox+st.layout.w,'field inside panel width')
        check(boost.y>=st.layout.oy and boost.y+boost.h<=st.layout.oy+st.layout.h,'field inside panel height')
        local oldScroll=st.scroll;w:tick('',-5);eq(w:draw().scroll,oldScroll,'wheel cannot scroll background under popup')
        w:clickControl(mode..'_speed_value');w:tick('2')
        local close=e.OSP.UI.getState().controls.close
        local outside=e.OSP.UI.getState().layout
        w:pressAt(outside.ox+2,outside.oy+2);w:releaseAt(outside.ox+2,outside.oy+2)
        st=w:draw();eq(st.movementPopup,nil,'outside press closes popup')
        eq(st.open,true,'outside press does not click the main Close button underneath')
        eq(#w.sent,before,'outside press discards the unfinished value')
        eq(e.OSP.NumberInput.active(),false)
        w:clickControl(mode..'_settings');w:clickControl(mode..'_boost_value');w:tick('3');w:tick('esc')
        eq(w:draw().movementPopup,nil,'one Escape closes the focused popup')
        eq(e.OSP.UI.getState().open,true);eq(#w.sent,before,'Escape cannot save the draft')
        w:clickControl(mode..'_settings');w:clickControl(mode..'_speed_value');w:tick('4')
        w:clickControl('movement_popup_close');eq(w:draw().movementPopup,nil,'X closes popup')
        eq(#w.sent,before,'X cannot save the draft')
        w:clickControl(mode..'_settings');e.OSP.UI.open(false)
        eq(w:draw().movementPopup,nil,'closing panel clears popup')
        e.OSP.UI.open(true)
    end
 end
end
for _,size in ipairs({{1024,768},{1920,1080}}) do
 for _,language in ipairs({'en','pt'}) do
    local w=world(unpack(size));local e=w.api;e.OSP.UI.open(true)
    w.reg['savegame.mod.osp.language']=language
    for i=1,13 do e.shared.osp.tools[#e.shared.osp.tools+1]={id='kit'..i,name='Câmera '..i,origin='mod',policy='default'} end
    w:clickControl('tab_tools')
    for _,mode in ipairs({'global','player'}) do
        w:clickControl('tool_mode_'..mode);w:clickControl('tools_actions');w:draw()
        local captions=table.concat(w.texts,'|')
        check(captions:find(e.OSP.L('enable_category'),1,true)~=nil,'unsearched group names category')
        check(captions:find(e.OSP.L('tools_enable_results'),1,true)==nil,'no search-result action without a query')
        w:clickControl('tools_popup_close')
    end
    w:clickControl('tool_mode_global');w:clickControl('tools_search')
    for char in ('pistol'):gmatch('.') do w:tick(char) end
    local st=w:draw();check(st.controls.tool_gun~=nil,'translated name searchable');eq(st.controls.tool_sledge,nil)
    w:tick('esc');eq(w:draw().open,true,'Escape only blurs search');eq(e.OSP.ToolSearch.query,'pistol')
    w:clickControl('tools_search_clear');w:clickControl('filter_mod');w:clickControl('tools_search')
    for char in ('CAMERA'):gmatch('.') do w:tick(char) end
    w:tick('return');st=w:draw();check(st.controls.tools_next and not st.controls.tools_next.disabled,'matches span pages')
    w:clickControl('tools_next');w:clickControl('tools_actions')
    st=w:draw();eq(#st.toolsPopup.resultIds,13,'batch snapshot includes every matching page')
    check(table.concat(w.texts,'|'):find(e.OSP.L('tools_enable_results'),1,true)~=nil,'searched group names results')
    eq(st.controls.tools_search.disabled,true,'popup blocks query changes')
    eq(#st.toolsPopup.ids,14,'Mods category includes nonmatches across pages and excludes vanilla')
    e.shared.osp.tools[#e.shared.osp.tools+1]={id='late',name='Camera late',origin='mod',policy='default'}
    w:clickControl('tools_disable_results');eq(#e.OSP.UI.getState().confirm.arg.ids,13,'confirmation freezes IDs')
    w:clickControl('confirm_accept');local request=w.sent[#w.sent]
    eq(request.args[2],'tool_policy_selection');eq(#request.args[4].ids,13)
    for _,id in ipairs(request.args[4].ids) do check(id:find('kit',1,true)==1,'outside matches excluded') end
    e.client.ospResult(false,'invalid',{},request.args[5]);local count=#w.sent
    w:tick();w:draw();eq(#w.sent,count,'no fallback to broad category commands')
    w:clickControl('tools_actions');local close=w:draw().controls.close
    w:pressAt(close.x+2,close.y+2);w:releaseAt(close.x+2,close.y+2)
    eq(w:draw().open,true);eq(e.OSP.UI.getState().toolsPopup,nil,'outside press closes actions without clicking through')
    w:clickControl('tools_search_clear');w:clickControl('tools_search');w:tick('%');w:tick('return')
    st=w:draw();eq(st.controls.tools_actions.disabled,false,'category actions remain available without search matches')
    w:clickControl('tools_actions');st=w:draw()
    eq(#st.toolsPopup.resultIds,0,'empty search snapshot')
    eq(st.controls.tools_disable_results.disabled,true,'empty result scope cannot be applied')
    eq(st.controls.tools_disable_filtered.disabled,false,'category remains available with empty results')
    w:clickControl('tools_popup_close')
    w:clickControl('tools_search_clear');w:clickControl('tool_more_mytool')
    eq(w:draw().toolsPopup.tool.id,'mytool','row secondary menu uses exact tool')
    w:tick('esc');eq(w:draw().toolsPopup,nil)
    w:clickControl('tools_search');w:tick('k');e.OSP.UI.open(false);e.OSP.UI.open(true)
    eq(w:draw().searchQuery,'k','term survives reopening this mission')
    local nextMap=world(size[1],size[2],w.reg);eq(nextMap.api.OSP.ToolSearch.query,'','term is not saved between missions')
 end
end
-- Category and result action rows coexist; each dispatches its own frozen IDs.
for _,size in ipairs({{640,480},{1024,768},{1920,1080}}) do
 for _,language in ipairs({'en','pt'}) do
  for _,mode in ipairs({'global','player'}) do
    local w=world(unpack(size));local e=w.api;e.OSP.UI.open(true)
    w.reg['savegame.mod.osp.language']=language
    w:clickControl('tab_tools');w:clickControl('tool_mode_'..mode)
    e.OSP.ToolSearch.query='pistol'
    w:clickControl('tools_actions');local st=w:draw()
    eq(#st.toolsPopup.ids,3);eq(#st.toolsPopup.resultIds,1)
    eq(st.controls.tools_scope_category,nil,'no scope selector')
    eq(st.controls.tools_scope_results,nil,'no extra click needed to reach results')
    local last=mode=='global' and 'tools_reset_filtered' or 'tools_disable_results_everyone'
    local height=math.min(st.layout.h-24,mode=='player' and 384 or 340)
    for _,id in ipairs({'tools_enable_filtered','tools_disable_filtered','tools_enable_results','tools_disable_results',last}) do
        local r=st.controls[id]
        check(r.x>=st.layout.ox and r.x+r.w<=st.layout.ox+st.layout.w,'action inside panel width')
        check(r.y>=st.layout.oy and r.y+r.h<=st.layout.oy+(st.layout.h+height)/2-34,'action clear of popup footer')
    end
    check(st.controls.tools_enable_results.y>st.controls.tools_enable_filtered.y,'result row follows category')
    check(st.controls[last].y>st.controls.tools_enable_results.y,'defaults or everyone follows result row')
    if mode=='global' then
        local r=st.controls.tools_reset_filtered
        check(math.abs(r.x+r.w/2-(st.layout.ox+st.layout.w/2))<.01,'lone reset button stays centered')
        check(math.abs(r.w-st.controls.tools_enable_filtered.w)<.01,'centered button keeps normal width')
    end
    e.shared.osp.tools[#e.shared.osp.tools+1]={id='late',name='Pistol late',origin='mod',policy='default'}
    w:draw();eq(#e.OSP.UI.getState().toolsPopup.ids,3,'category snapshot excludes late tools')
    eq(#e.OSP.UI.getState().toolsPopup.resultIds,1,'result snapshot excludes late tools')
    eq(#w.sent,0,'opening and drawing do not dispatch actions')
    w:clickControl('tools_disable_results');local confirmation=e.OSP.UI.getState().confirm
    eq(#confirmation.arg.ids,1,'result confirmation count')
    check(confirmation.message:find('pistol',1,true)~=nil,'result confirmation includes query')
    w:clickControl('confirm_accept');local request=w.sent[#w.sent]
    eq(request.args[2],mode=='global' and 'tool_policy_selection' or 'tools_selection')
    eq(#request.args[4].ids,1);eq(request.args[4].ids[1],'gun','result command excludes nonmatches')
    eq(e.OSP.ToolSearch.query,'pistol','result action preserves query')
    w:ack();w:clickControl('tools_actions');w:clickControl('tools_disable_filtered')
    confirmation=e.OSP.UI.getState().confirm
    eq(#confirmation.arg.ids,4,'category confirmation count includes nonmatches')
    check(confirmation.message:find('pistol',1,true)==nil,'category confirmation does not claim search scope')
    w:clickControl('confirm_accept');request=w.sent[#w.sent]
    eq(#request.args[4].ids,4);eq(request.args[4].category,'all')
    eq(e.OSP.ToolSearch.query,'pistol','category action preserves query')
    w:ack();w:clickControl('tools_actions')
    if mode=='global' then w:clickControl('tools_reset_filtered') else w:clickControl('tools_disable_everyone') end
    confirmation=e.OSP.UI.getState().confirm
    eq(#confirmation.arg.ids,4,'defaults and everyone category actions include nonmatches')
    check(confirmation.message:find('pistol',1,true)==nil,'category defaults or everyone confirmation has no query')
    w:clickControl('confirm_cancel')
    if mode=='player' then
        w:clickControl('tools_actions');w:clickControl('tools_disable_results_everyone')
        confirmation=e.OSP.UI.getState().confirm;eq(#confirmation.arg.ids,2,'everyone has an independent result action')
        check(confirmation.message:find('pistol',1,true)~=nil)
        w:clickControl('confirm_accept');request=w.sent[#w.sent]
        eq(request.args[2],'tools_selection_all');eq(#request.args[4].ids,2);w:ack()
    end
    w:clickControl('tools_search_clear');w:clickControl('tools_actions');st=w:draw()
    eq(st.controls.tools_enable_results,nil,'result row disappears after clearing search')
    eq(st.controls.tools_disable_results,nil)
    eq(st.controls.tools_disable_results_everyone,nil,'everyone result row also disappears')
    check(st.controls.tools_enable_filtered~=nil,'category row stays visible')
    w:clickControl('tools_popup_close');e.OSP.ToolSearch.query='%';w:clickControl('tools_actions');st=w:draw()
    eq(st.controls.tools_enable_results.disabled,true,'zero matches disable result row')
    eq(st.controls.tools_disable_results.disabled,true)
    eq(st.controls.tools_enable_filtered.disabled,false,'zero matches do not block category')
    if mode=='player' then eq(st.controls.tools_disable_results_everyone.disabled,true) end
  end
 end
end
-- Result controls preserve the same delegated capabilities as category controls.
do
    local w=world(1024,768);local e=w.api
    e.IsPlayerHost=function() return false end
    local me=e.shared.osp.players[1];me.host=false;me.admin=true
    me.permissions=e.OSP.Permissions.resolve('self').permissions
    e.OSP.UI.open(true);w:clickControl('tab_tools');e.OSP.ToolSearch.query='pistol';w:clickControl('tools_actions')
    local st=w:draw()
    eq(st.controls.tools_enable_results.disabled,false,'self delegate can change own results')
    eq(st.controls.tools_disable_results_everyone.disabled,true,'self delegate cannot change everyone results')
    me.permissions=e.OSP.Permissions.normalize({});w:draw()
    eq(e.OSP.UI.getState().controls.tools_enable_results.disabled,true,'revocation disables already open result actions')
    eq(#w.sent,0)
end
-- Navigation must be recognizable without a pointer, across palettes and layouts.
for _,size in ipairs({{640,480},{1024,768},{1920,1080}}) do
 for _,language in ipairs({'en','pt'}) do
  for _,palette in ipairs({'classic','ocean','forest','violet','light','custom'}) do
    local w=world(unpack(size));local e=w.api;w.capturePaint=true
    w.reg['savegame.mod.osp.language']=language;w.reg['savegame.mod.osp.theme.mode']=palette
    if palette=='custom' then w.reg['savegame.mod.osp.theme.custom.surface']='334155';w.reg['savegame.mod.osp.theme.custom.line']='94a3b8' end
    e.OSP.UI.open(true);local st=w:draw();local c=e.OSP.Theme.colors()
    local close=st.controls.close
    for _,p in ipairs(w.paints) do
        if p.kind=='text' and (p.text==e.OSP.L('app_title') or p.text==e.OSP.L('close') or p.text:find(e.OSP.L('selected_short')..':',1,true)==1) then
            check(math.abs(p.y+p.font/2-(close.y+close.h/2))<.01,'header text shares the close button center')
        end
    end
    local function painted(r,color)
        for _,p in ipairs(w.paints) do
            if p.kind=='rect' and math.abs(p.x-r.x)<.01 and math.abs(p.y-r.y)<.01 and math.abs(p.w-r.w)<.01 and math.abs(p.h-r.h)<.01 then
                local same=true;for i=1,4 do if p.color[i]~=color[i] then same=false end end
                if same then return true end
            end
        end
        return false
    end
    for _,id in ipairs({'close','tab_settings'}) do
        local r=st.controls[id]
        check(painted(r,c.surface),'idle navigation has a visible button surface: '..id)
        check(painted({x=r.x,y=r.y,w=r.w,h=1},c.line),'idle navigation has a permanent outline: '..id)
    end
    local active=st.controls.tab_players
    check(painted(active,c.selected),'selected tab keeps its selected surface')
    check(painted({x=active.x,y=active.y,w=3,h=active.h},c.accent),'selected tab keeps its accent marker')
    local r=st.controls.tab_settings;w.mouse={x=r.x+2,y=r.y+2};w:draw()
    check(painted(r,c.hover),'hover highlights the button surface')
    check(painted({x=r.x,y=r.y,w=r.w,h=1},c.accent),'hover highlights the outline')
    e.IsPlayerHost=function() return false end;e.shared.osp.players[1].admin=false;w:tick()
    st=w:draw();r=st.controls.tab_players;w.mouse={x=r.x+2,y=r.y+2};st=w:draw()
    eq(st.controls.tab_players.disabled,true)
    check(painted(r,c.surface),'disabled navigation stays visible without hover activation')
    check(painted({x=r.x,y=r.y,w=r.w,h=1},c.line),'disabled navigation keeps neutral outline')
    w:pressAt(r.x+2,r.y+2);eq(e.OSP.UI.getState().tab,'settings','disabled navigation cannot change tabs')
  end
 end
end
-- Hiding tabs reflows navigation and survives new client contexts.
for _,size in ipairs({{640,480},{1024,768},{1920,1080}}) do
 for _,language in ipairs({'en','pt'}) do
    local w=world(unpack(size));local e=w.api;w.reg['savegame.mod.osp.language']=language;e.OSP.UI.open(true)
    local before=w:draw();local session=before.controls.tab_session
    w:clickControl('tab_settings');w:clickControl('navigation_players');local st=w:draw()
    eq(st.controls.tab_players,nil,'hidden tab has no click target')
    eq(st.controls.tab_session.x,before.controls.tab_players.x,'remaining tabs move left/up')
    eq(st.controls.tab_session.y,before.controls.tab_players.y,'no empty first slot')
    w:clickControl('navigation_permissions');w:clickControl('tab_tools');e.OSP.UI.open(false);e.OSP.UI.open(true)
    eq(w:draw().tab,'tools','reopen preserves last visible tab')
    e.OSP.Navigation.setVisible('tools',false);w:tick();st=w:draw()
    eq(st.tab,'session','hidden active tab falls back to first accessible tab')
    local nextMap=world(size[1],size[2],w.reg);nextMap.api.OSP.UI.open(true)
    eq(nextMap:draw().controls.tab_players,nil,'hidden choices survive new mission')
    w:clickControl('tab_settings')
    for _,id in ipairs(e.OSP.Navigation.tabs) do if id~='settings' then e.OSP.Navigation.setVisible(id,false) end end
    st=w:draw();eq(st.tab,'settings');check(st.controls.tab_settings~=nil)
    if st.layout.narrow then check(st.layout.contentY<before.layout.contentY,'single navigation row releases content height') end
    for id in pairs(st.controls) do if id:match('^tab_') then eq(id,'tab_settings') end end
    w:clickControl('navigation_restore');st=w:draw();check(st.controls.tab_players~=nil,'restore exposes all tabs')
    -- Hide a page while it owns a draft/modal, before it can consume more input.
    w:clickControl('tab_players');w:clickControl('fly_settings');w:clickControl('fly_speed_value');w:tick('4')
    e.OSP.Navigation.setVisible('players',false);w:tick('return')
    eq(e.OSP.UI.getState().movementPopup,nil);eq(e.OSP.NumberInput.active(),false);eq(#w.sent,0,'hidden page draft never dispatches')
    e.IsPlayerHost=function() return false end;e.shared.osp.players[1].admin=false
    e.OSP.Navigation.setVisible('settings',false);e.OSP.Navigation.setVisible('about',false);w:tick();st=w:draw()
    eq(st.tab,'settings','guest fallback stays accessible');eq(st.controls.tab_session.disabled,true,'showing tabs never grants permissions')
 end
end
-- Tooltips use visible hit rectangles, time and player context, never input capture.
for _,size in ipairs({{640,480},{1024,768},{1920,1080}}) do
 for _,language in ipairs({'en','pt'}) do
    local w=world(unpack(size));local e=w.api;e.OSP.UI.open(true);w.reg['savegame.mod.osp.language']=language
    local function hover(id)
        local r=w:scrollTo(id);w.mouse={x=r.x+r.w/2,y=r.y+r.h/2};w:draw();return r
    end
    local function wait() w.now=w.now+.61;return w:draw() end
    local initial=w:draw();local joined=table.concat(w.texts,'|')
    check(not joined:find(e.OSP.L('protects_host'),1,true),'host reminder no longer occupies page')
    local savedCount=0;for _,value in ipairs(w.texts) do if value==e.OSP.L('player_options_saved') then savedCount=savedCount+1 end end
    eq(savedCount,1,'persistence appears once as a page note')
    hover('player_action_fly');w.now=w.now+.59;eq(w:draw().tooltip,nil,'no tooltip before delay')
    w.now=w.now+.02;local st=w:draw();local t=st.tooltip;check(t~=nil,'tooltip appears after delay')
    eq(t.id,'player_action_fly');check(t.text:find(e.OSP.L('player_options_saved'),1,true)==nil,'specific hints do not repeat persistence')
    check(t.x>=st.layout.ox and t.y>=st.layout.oy and t.x+t.w<=st.layout.ox+st.layout.w and t.y+t.h<=st.layout.oy+st.layout.h,'wrapped tip inside panel')
    for _,line in ipairs(t.lines) do local _,bytes=line:gsub('[\128-\191]','');check((#line-bytes)*14*.55<=t.w-24,'every wrapped line fits') end
    hover('player_action_noclip');eq(w:draw().tooltip,nil,'changing control resets delay');wait();check(w:draw().tooltip~=nil)
    w:tick('',1);eq(w:draw().tooltip,nil,'scroll clears tooltip')
    hover('fly_settings');wait();w:clickControl('fly_settings');eq(w:draw().tooltip,nil,'popup suppresses background hints')
    w.now=w.now+2;eq(w:draw().tooltip,nil);w:clickControl('movement_popup_close')
    hover('player_speed_value');wait();w:clickControl('player_speed_value');w.now=w.now+1;eq(w:draw().tooltip,nil,'numeric editor suppresses hints')
    e.OSP.NumberInput.cancel();hover('player_action_fly');wait()
    e.shared.osp.players[1].profileChallenge=99;eq(w:draw().tooltip,nil,'new player entry resets existing hint')
    w:clickControl('player_action_kill');w.now=w.now+1;eq(w:draw().tooltip,nil,'confirmation suppresses hints')
    w:clickControl('confirm_cancel')
    w:clickControl('tab_settings');eq(w:draw().tooltip,nil,'other pages have no tooltips')
    w:clickControl('tab_players');hover('player_action_fly');wait();e.OSP.UI.open(false);eq(e.OSP.UI.getState().tooltip,nil,'closing clears tooltip')
    e.OSP.UI.open(true);hover('player_action_eject');st=wait()
    eq(st.tooltip.text,e.OSP.L('tip_no_vehicle'),'disabled vehicle control explains reason')
    eq(st.controls.player_action_eject.disabled,true,'hint never enables disabled control')
    eq(#w.sent,0,'hovering and editing without confirmation sends no commands')
    e.shared.osp.players[1].profileReady=false;hover('player_action_god');st=wait();eq(st.tooltip.text,e.OSP.L('profile_waiting'))
    check(table.concat(w.texts,'|'):find(e.OSP.L('profile_waiting'),1,true)~=nil,'pending profile status stays visible')
 end
end
-- Delegates receive temporary/policy explanations rather than host persistence claims.
do
    local w=world(1920,1080);local e=w.api;e.IsPlayerHost=function() return false end
    local me=e.shared.osp.players[1];me.host=false;me.admin=true;me.permissions=e.OSP.Permissions.resolve('self').permissions
    e.shared.osp.players[2].host=true;e.OSP.UI.open(true)
    local function hint(id)
        local r=w:scrollTo(id);w.mouse={x=r.x+r.w/2,y=r.y+r.h/2};w:draw();w.now=w.now+.61;return w:draw().tooltip
    end
    eq(hint('player_action_god'),nil,'persistence alone does not create a tooltip')
    check(table.concat(w.texts,'|'):find(e.OSP.L('tip_temporary'),1,true)~=nil,'delegate sees temporary note in page')
    w:clickControl('player_23');eq(hint('player_action_god').text,e.OSP.L('protects_host'))
    w:clickControl('player_11');me.permissions=e.OSP.Permissions.normalize({})
    eq(hint('player_action_god').text,e.OSP.L('result_denied'))
end
-- Physical shortcuts target self, guard the observed state and never queue input.
for _,size in ipairs({{640,480},{1024,768},{1920,1080}}) do
 for _,language in ipairs({'en','pt'}) do
    local w=world(unpack(size));local e=w.api;w.reg['savegame.mod.osp.language']=language
    e.shared.osp.players[1].profileReady=true
    e.OSP.Shortcuts.assign('god','f8');e.OSP.Shortcuts.assign('fly','f9');e.OSP.Shortcuts.assign('noclip','f10')
    e.OSP.UI.open(true);w:clickControl('player_23');w:tick('f8');eq(#w.sent,0,'open panel blocks shortcut')
    e.OSP.UI.open(false);w:tick('f8');eq(#w.sent,1)
    local request=w.sent[1];eq(request.args[2],'god');eq(request.args[3],11,'ignores selected other player')
    eq(request.args[4].expected,false);eq(request.args[4].value,true)
    check(e.OSP.UI.getState().shortcutNotice:find(e.OSP.L('request_sent'),1,true)~=nil,'no optimistic success')
    w:tick('f9');eq(#w.sent,1,'pending actions are not queued');w:ack();w:tick();eq(#w.sent,1)
    check(e.OSP.UI.getState().shortcutNotice:find(e.OSP.L('on'),1,true)~=nil,'ACK confirms requested boolean')
    w:tick('f8');request=w.sent[#w.sent];eq(request.args[4].expected,false,'stale publication carries stale expectation')
    w:ack(false,'state_changed');check(e.OSP.UI.getState().shortcutNotice:find(e.OSP.L('shortcut_state_changed'),1,true)~=nil)
    e.shared.osp.players[1].god=true;w:tick('f8');eq(w.sent[#w.sent].args[4].value,false,'new published state toggles off')
    w:ack();local count=#w.sent;w.mods={shift=true};w:tick('f9');eq(#w.sent,count);w.mods={}
    w.reg['game.paused']=true;w:tick('f9');eq(#w.sent,count);w.reg['game.paused']=false
    w.canUseTool=false;w:tick('f9');eq(#w.sent,count,'vehicle/dead/interactive context blocks');w.canUseTool=true
    local pressed=e.InputPressed;e.InputPressed=function(k) return k=='f9' or k=='f10' end
    w:tick();eq(#w.sent,count,'simultaneous actions ignored');e.InputPressed=pressed
    e.shared.osp.players[1].profileReady=false;w:tick('f9');eq(#w.sent,count,'host profile must be ready')
    e.shared.osp.players[1].profileReady=true;w:tick('f9');request=w.sent[#w.sent]
    w.now=w.now+9;w:tick();check(e.OSP.UI.getState().shortcutNotice:find(e.OSP.L('request_unknown'),1,true)~=nil)
    local notice=e.OSP.UI.getState().shortcutNotice;e.client.ospResult(true,'ok',{},request.args[5]);eq(e.OSP.UI.getState().shortcutNotice,notice,'late ACK cannot resurrect success')
    e.IsPlayerHost=function() return false end;e.shared.osp.players[1].host=false;e.shared.osp.players[1].admin=false
    count=#w.sent;w:tick('f8');eq(#w.sent,count,'guest cannot dispatch shortcut')
    local nextMap=world(size[1],size[2],w.reg);eq(nextMap.api.OSP.Shortcuts.binding('god'),'f8','personal binding survives map change')
    e.IsPlayerHost=function(p) return p==11 end;e.shared.osp.players[1].host=true;e.shared.osp.players[1].admin=true
    e.OSP.UI.open(true);w:clickControl('tab_players');w:clickControl('player_11');w:clickControl('god_settings');w:clickControl('shortcut_god');eq(e.OSP.Shortcuts.capture,'god')
    w:tick('w');eq(e.OSP.Shortcuts.capture,'god','invalid key preserves capture');w:tick('f11');eq(e.OSP.Shortcuts.binding('god'),'f11')
    w:clickControl('movement_popup_close');w:clickControl('tab_settings');eq(w:draw().controls.shortcut_god,nil,'binding list removed from in-map Settings')
    w:clickControl('rebind');w:tick('f11');eq(e.OSP.Shortcuts.capture,'menu','panel capture rejects action collision')
    w:clickControl('rebind');eq(e.OSP.Shortcuts.capture,nil,'explicit cancel works')
    w:clickControl('tab_players');w:clickControl('god_settings');w:clickControl('shortcut_clear_god');eq(e.OSP.Shortcuts.binding('god'),'')
    w:clickControl('movement_popup_close');w:clickControl('fly_settings');w:clickControl('shortcut_clear_fly');eq(e.OSP.Shortcuts.binding('fly'),'')
 end
end
-- Same-frame panel transitions, held keys and delegated permissions keep their boundaries.
do
    local w=world(1920,1080);local e=w.api;local own=e.shared.osp.players[1]
    own.profileReady=true;e.OSP.Shortcuts.assign('fly','f8')
    e.IsPlayerHost=function() return false end;own.host=false;own.admin=true;own.permissions=e.OSP.Permissions.resolve('self').permissions
    w:tick('f8');eq(#w.sent,1,'delegate may toggle own granted Fly');w:ack()
    own.permissions=e.OSP.Permissions.normalize({});local count=#w.sent;w:tick('f8');eq(#w.sent,count,'revoked permission immediately stops dispatch')
    own.permissions=e.OSP.Permissions.resolve('self').permissions
    local input=e.InputPressed;e.InputPressed=function(k) return k=='p' or k=='f8' end
    w:tick();eq(#w.sent,count,'opening panel and shortcut in one frame cannot dispatch')
    w:tick();eq(#w.sent,count,'closing panel and shortcut in one frame cannot dispatch');e.InputPressed=input
    local down=e.InputDown;e.InputDown=function(k) return k=='f8' or down(k) end
    w:tick();eq(#w.sent,count,'held physical key without a press cannot repeat')
    e.InputDown=down;w.reg['savegame.mod.osp.shortcuts.noclip']='f8';w:tick('f8');eq(#w.sent,count,'stored duplicates are inactive')
end
-- Immediate replies must not be replaced by the pending toast after dispatch.
do
    local w=world(1920,1080);local e=w.api;e.shared.osp.players[1].profileReady=true;e.OSP.Shortcuts.assign('fly','f8')
    e.ServerCall=function(fn,...) local a={...};w.sent[#w.sent+1]={args=a};e.client.ospResult(true,'ok',{},a[5]) end
    w:tick('f8');eq(#w.sent,1);eq(e.OSP.UI.getState().requestPending,false)
    check(e.OSP.UI.getState().shortcutNotice:find(e.OSP.L('on'),1,true)~=nil)
    w:tick();eq(#w.sent,1,'holding without a new press cannot repeat')
end
-- Contextual binding fields are adjacent to their actions and remain personal.
for _,size in ipairs({{640,480},{1024,768},{1920,1080}}) do
 for _,language in ipairs({'en','pt'}) do
    local w=world(unpack(size));local e=w.api;w.reg['savegame.mod.osp.language']=language;e.OSP.UI.open(true)
    for _,mode in ipairs({'god','fly','noclip'}) do
        w:clickControl(mode..'_settings');local st=w:draw();local field=st.controls['shortcut_'..mode]
        check(field~=nil,'binding directly available in contextual popup')
        check(field.x>=st.layout.ox and field.x+field.w<=st.layout.ox+st.layout.w,'binding fits panel width')
        check(field.y>=st.layout.oy and field.y+field.h<st.layout.oy+st.layout.h-35,'binding clear of popup footer')
        if mode=='god' then eq(st.controls.god_speed_value,nil,'invincibility popup has no movement controls') end
        w:clickControl('shortcut_'..mode);eq(e.OSP.Shortcuts.capture,mode)
        local close=w:draw().controls.close
        local outside=e.OSP.UI.getState().layout
        w:pressAt(outside.ox+2,outside.oy+2);w:releaseAt(outside.ox+2,outside.oy+2)
        eq(e.OSP.Shortcuts.capture,nil,'outside close cancels capture');eq(e.OSP.UI.getState().movementPopup,nil)
        eq(e.OSP.Shortcuts.binding(mode),'','closing without valid key leaves preference unchanged')
    end
    w:clickControl('player_23');local st=w:draw();eq(st.controls.god_settings,nil,'no personal shortcut popup for another player')
    w:clickControl('fly_settings');st=w:draw();eq(st.controls.shortcut_fly,nil,'another player movement popup never edits local binding')
    check(st.controls.fly_speed_value~=nil,'other-player speed configuration remains available')
    eq(#w.sent,0,'opening and closing shortcut settings sends no gameplay commands')
 end
end
-- Shortcut feedback sizes to measured text and keeps its top-center anchor.
for _,size in ipairs({{640,480},{1024,768},{1920,1080}}) do
 for _,language in ipairs({'en','pt'}) do
    local w=world(unpack(size));local e=w.api;e.OSP.UI.open(false);e.shared.osp.players[1].profileReady=true;w.reg['savegame.mod.osp.language']=language
    e.OSP.Shortcuts.assign('god','f8');e.OSP.Shortcuts.assign('fly','f9');w.capturePaint=true
    local function geometry(expectedY,compact)
        local st=w:draw();local box,band=w.paints[1],w.paints[2];local paintedText
        check(box and box.kind=='rect' and band and band.kind=='rect','shortcut notice background and accent are drawn')
        for _,paint in ipairs(w.paints) do if paint.kind=='text' then paintedText=paint;break end end
        check(paintedText~=nil,'shortcut notice text is drawn')
        eq(paintedText.text:gsub('\n',' '),st.shortcutNotice,'wrapped text preserves the notice')
        eq(paintedText.font,15,'shortcut notice keeps its font size')
        check(box.x>=20 and box.x+box.w<=size[1]-20,'notice keeps side margins')
        check(math.abs(box.x-(size[1]-box.w)/2)<.01,'notice stays horizontally centered')
        eq(box.y,expectedY,'notice keeps its top anchor and announcement offset')
        check(box.y+box.h<=size[2],'notice box fits canvas height')
        eq(band.x,box.x);eq(band.y,box.y);eq(band.w,3);eq(band.h,box.h)
        eq(paintedText.x,box.x+12,'notice uses horizontal padding')
        eq(paintedText.y,box.y+8,'notice uses vertical padding')
        w.t.font=15
        local _,textHeight=e.UiGetTextSize(paintedText.text)
        eq(box.h,textHeight+16,'notice height follows measured text and vertical padding')
        local lineCount,maxLineWidth=0,0
        for line in (paintedText.text..'\n'):gmatch('(.-)\n') do
            lineCount=lineCount+1;local lineWidth=e.UiGetTextSize(line);maxLineWidth=math.max(maxLineWidth,lineWidth)
            check(lineWidth<=box.w-24+.01,'each notice line fits its measured content width')
        end
        check(box.w<=math.min(360,size[1]-40)+.01,'notice respects maximum width')
        check(math.abs(box.w-(maxLineWidth+24))<.01,'notice width follows its widest line and padding')
        if compact then check(box.w<360 and box.h<72,'short and pending notices remain compact') end
        return st,paintedText,box,lineCount
    end
    w:tick('f8');w:ack();local st,text,box,lines=geometry(40,true)
    eq(lines,1,'short ACK notice stays on one line')
    check(st.shortcutNotice:find(e.OSP.L('on'),1,true)~=nil,'short ACK notice shows confirmed value')
    e.client.ospAnnouncement('Host','Session announcement stays visible')
    w:tick('f8');w:tick('f9');st,text,box,lines=geometry(164,true)
    check(st.shortcutNotice:find(e.OSP.L('request_pending'),1,true)~=nil,'pending notice keeps its pending message')
    check(w.paints[4] and w.paints[4].kind=='rect' and w.paints[4].y==40,'session announcement keeps its existing position')
    w:ack();w.now=w.now+7
    local originalL=e.OSP.L;local longText={
        en='The server confirmed the requested value after checking the current player and session state.',
        pt='O servidor confirmou o valor solicitado após verificar o jogador atual e o estado da sessão.'
    }
    e.OSP.L=function(key,...)
        if key=='on' then return longText[language] end
        return originalL(key,...)
    end
    w:tick('f8');w:ack();st,text,box,lines=geometry(40,false)
    check(lines>1,'long translated notice wraps across measured lines')
    check(text.text:find('\n',1,true)~=nil,'long notice contains explicit line breaks')
    e.OSP.L=originalL
 end
end
print('PASS client interaction, viewport and translation contracts: '..assertions..' assertions (mock UI)')
