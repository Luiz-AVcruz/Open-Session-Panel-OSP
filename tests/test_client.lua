-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Simulates engine input and UI state. This is not a game renderer.
local assertions=0
local function check(v,msg) assert(v,msg);assertions=assertions+1 end
local function eq(a,b,msg) check(a==b,(msg or 'equality')..': '..tostring(a)..' ~= '..tostring(b)) end
local function world(width,height,previousRegistry)
    local w={reg=previousRegistry or {},sent={},texts={},now=0,input='',wheel=0,mouse={x=0,y=0},click=false,held=false,released=false,armed={},
        width=width,height=height,t={x=0,y=0,s=1},stack={},drawn=false,hp=1}
    local env=setmetatable({client={},shared={osp={ready=true,version='1.2.0',rules={},log={},
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
    env.GetPlayerHealth=function() return w.hp end
    env.IsPlayerHost=function(p) return p==11 end
    env.GetTime=function() return w.now end
    env.IsToolEnabled=function(id,p) return id=='sledge' end
    env.ServerCall=function(fn,...) w.sent[#w.sent+1]={fn=fn,args={...}} end
    env.PauseMenuButton=function() return false end
    env.InputLastPressedKey=function() return w.input end
    env.InputPressed=function(k) return k==w.input or (k=='lmb' and w.click) end
    env.InputDown=function(k) return k=="lmb" and w.held or false end
    env.InputValue=function(k) assert(k=='mousewheel');return w.wheel end
    env.InputClear=function() w.input='';w.click=false;w.held=false;w.released=false;w.wheel=0 end
    env.SetFloat=function() error('HUD must never write health or gameplay') end
    env.UiPush=function() local t=w.t;w.stack[#w.stack+1]={x=t.x,y=t.y,s=t.s,font=t.font} end
    env.UiPop=function() assert(#w.stack>0,'balanced UI stack');w.t=table.remove(w.stack) end
    env.UiTranslate=function(x,y) w.t.x=w.t.x+x*w.t.s;w.t.y=w.t.y+y*w.t.s end
    env.UiScale=function(s) w.t.s=w.t.s*s end
    env.UiCanvasSize=function() return {w=w.width,h=w.height} end
    env.UiWidth=function() return width end;env.UiHeight=function() return height end
    env.UiFont=function(path,size) assert(path=='regular.ttf' or path=='bold.ttf');w.t.font=size end
    env.UiGetTextSize=function(s) return #s*(w.t.font or 20)*.55,(w.t.font or 20) end
    env.UiText=function(s) assert(w.drawn);w.texts[#w.texts+1]=s;return #s*(w.t.font or 20)*.55,w.t.font or 20 end
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
    local chunk=assert(loadfile(arg[1]));setfenv(chunk,env);chunk();env.client.init();w.api=env
    function w:tick(key,wheel)
        self.now=self.now+.1;self.input=key or '';self.wheel=wheel or 0;env.client.tick(.1);self.input='';self.wheel=0
    end
    function w:draw()
        self.texts={};self.drawn=true;self.t={x=0,y=0,s=1};self.stack={}
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
    r=w:scrollTo('health_toggle');x,y=point(r);w:pressAt(x,y)
    eq(w.reg['savegame.mod.osp.health_hud'],true,'toggle reacts on press in background padding')
    for i=1,3 do w:holdAt(x,y);eq(w.reg['savegame.mod.osp.health_hud'],true,'hold does not repeat') end
    w:releaseAt(x,y);eq(w.reg['savegame.mod.osp.health_hud'],true,'release does not repeat')
    local st=w:draw();local count=#w.sent
    w:pressAt(x,st.layout.oy+st.layout.contentY+st.layout.contentH+4)
    eq(#w.sent,count,'outside viewport sends no command')
    eq(w.reg['savegame.mod.osp.health_hud'],true,'outside viewport leaves toggle unchanged')
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
    local beforeMods=#w.sent
    w:clickControl('mods_disable_player')
    local modConfirm=e.OSP.UI.getState().confirm
    eq(modConfirm.action,'tools_filtered');eq(modConfirm.target,23)
    eq(modConfirm.arg.category,'mod');eq(modConfirm.arg.enabled,false)
    eq(#w.sent,beforeMods,'mod shortcut waits for confirmation')
    w:clickControl('confirm_cancel');eq(#w.sent,beforeMods,'cancel mod block sends nothing')
    w:clickControl('mods_disable_player');w:clickControl('confirm_accept')
    local modRequest=w.sent[#w.sent].args
    eq(modRequest[2],'tools_filtered');eq(modRequest[3],23)
    eq(modRequest[4].category,'mod');eq(modRequest[4].enabled,false);w:ack()
    w:clickControl('mods_disable_everyone');modConfirm=e.OSP.UI.getState().confirm
    eq(modConfirm.action,'tool_policy_bulk');eq(modConfirm.message,e.OSP.L('confirm_mods_global'),'persistent scope is explicit')
    w:clickControl('confirm_accept');modRequest=w.sent[#w.sent].args
    eq(modRequest[2],'tool_policy_bulk');eq(modRequest[3],0)
    eq(modRequest[4].category,'mod');eq(modRequest[4].mode,'disabled');w:ack()
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
    w:clickControl('tools_disable_filtered');eq(e.OSP.UI.getState().confirm.action,'tool_policy_bulk')
    w:clickControl('confirm_accept');eq(w.sent[#w.sent].args[2],'tool_policy_bulk');eq(w.sent[#w.sent].args[4].category,'mod');w:ack()
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
    w:clickControl('tools_disable_everyone');eq(e.OSP.UI.getState().confirm.action,'tools_filtered_all');w:clickControl('confirm_cancel')
    w:clickControl('tab_settings');eq(w.reg['savegame.mod.osp.health_hud'],nil,'HUD starts disabled')
    w:clickControl('health_toggle');eq(w.reg['savegame.mod.osp.health_hud'],true)
    w:clickControl('rebind');w:tick('w');eq(e.OSP.UI.getState().keyCapture,true);w:tick('f8');eq(e.OSP.UI.getState().menuKey,'f8')
    local oldStatus=e.OSP.UI.getState().status;e.client.ospResult(false,'error',{},nil)
    eq(e.OSP.UI.getState().status,oldStatus,'unsolicited nil ACK ignored')
    w:clickControl('tab_about');w:draw();local combined=table.concat(w.texts,'|');check(combined:find('Luiz%-AVcruz')~=nil,'about author')
    e.client.ospAnnouncement('Host','Hello everyone');check(e.OSP.UI.getState().status:find('Hello everyone')~=nil,'announcement visible with menu open')
    e.OSP.UI.open(false);w.now=w.now+7;w.hp=.4;w:draw();combined=table.concat(w.texts,'|');check(combined:find('40%%')~=nil,'health HUD displays actual health')
    w.hp=0;w:draw();eq(#w.texts,0,'dead player has no additional indicator');w.hp=.4
    local nextMap=world(size[1],size[2],w.reg);nextMap.hp=.5;nextMap:draw();check(table.concat(nextMap.texts,'|'):find('50%%')~=nil,'HUD preference persists across maps')
    w.reg['savegame.mod.osp.health_hud']=false;w:draw();eq(#w.texts,0,'disabled HUD adds no text')
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
    local protected=d:scrollTo('mods_disable_player');eq(protected.disabled,true,'individual shortcut protects host')
    local beforeBlock=#d.sent;d:pressAt(protected.x+2,protected.y+2);d:releaseAt(protected.x+2,protected.y+2)
    eq(#d.sent,beforeBlock);eq(de.OSP.UI.getState().confirm,nil,'disabled shortcut cannot open confirmation')
    d:clickControl('mods_disable_everyone');local delegatedConfirm=de.OSP.UI.getState().confirm
    eq(delegatedConfirm.action,'tools_filtered_all')
    eq(delegatedConfirm.message,de.OSP.L('confirm_mods_nonhost'),'delegate sees temporary scope and host exclusion')
    d:clickControl('confirm_accept');local delegatedRequest=d.sent[#d.sent].args
    eq(delegatedRequest[2],'tools_filtered_all');eq(delegatedRequest[3],0)
    eq(delegatedRequest[4].category,'mod');eq(delegatedRequest[4].enabled,false);d:ack()
    de.shared.osp.tools={{id='gun',origin='vanilla'}}
    eq(d:scrollTo('mods_disable_everyone').disabled,true,'no mod tools disables bulk shortcut')
    d:clickControl('player_11')
    eq(d:scrollTo('mods_disable_player').disabled,true,'no mod tools disables selected shortcut')
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
    for _,id in ipairs({'player_action_god','player_action_fly','player_action_freeze','speed_up','player_admin','reset_player','mods_disable_player'}) do
        eq(w:scrollTo(id).disabled,true,'waiting profile disables '..id)
    end
    w:clickControl('tab_tools');w:clickControl('tool_mode_player')
    eq(w:scrollTo('tools_enable_filtered').disabled,true)
    eq(w:scrollTo('tool_gun').disabled,true)
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
print('PASS client interaction, viewport and translation contracts: '..assertions..' assertions (mock UI)')
