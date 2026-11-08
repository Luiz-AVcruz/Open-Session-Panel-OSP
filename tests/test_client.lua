-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Simulates engine input and UI state. This is not a game renderer.
local assertions=0
local function check(v,msg) assert(v,msg);assertions=assertions+1 end
local function eq(a,b,msg) check(a==b,(msg or 'equality')..': '..tostring(a)..' ~= '..tostring(b)) end
local function world(width,height,previousRegistry)
    local w={reg=previousRegistry or {},sent={},identitySent={},flightReports={},strengthReports={},texts={},now=0,input='',wheel=0,mouse={x=0,y=0},click=false,held=false,released=false,armed={},
        width=width,height=height,t={x=0,y=0,s=1},stack={},drawn=false,hp=1,vehicle=0,screen=0}
    local env=setmetatable({client={},shared={osp={ready=true,version='1.5.0',profileHost=string.rep('a',32),rules={},log={},
        tools={{id='gun',name='gun',nameKey='TOOL_NAME_GUN',origin='vanilla',policy='default'},
               {id='sledge',name='Sledge',origin='vanilla',policy='enabled'},
               {id='mytool',name=string.rep('X',90),origin='mod',policy='disabled'}},
        players={{id=11,name='Host',health=1,host=true,admin=true,god=false,fly=false,freeze=false,speed=1,ammo=false,ammoRestore=true,strength=false,strengthForce=1,strengthMass=5000,strengthThrow=false,strengthThrowSpeed=20,vehicle=false,profileChallenge=1},
                 {id=23,name=string.rep('Long name ',20),health=1,host=false,admin=false,god=false,fly=false,freeze=false,speed=1,ammo=false,ammoRestore=true,strength=false,strengthForce=1,strengthMass=5000,strengthThrow=false,strengthThrowSpeed=20,vehicle=true,profileChallenge=2}}}}},{__index=_G})
    -- Older scenarios explicitly exercise expanded Settings; use an empty
    -- supplied registry below to test the actual first-run defaults.
    if not previousRegistry then
        for _,id in ipairs({"language","shortcut","view_mode","navigation","palette","background"}) do w.reg["savegame.mod.osp_beta.settings.collapsed."..id]="0" end
    end
    env.GetString=function(k) return w.reg[k] or '' end
    env.SetString=function(k,v) w.reg[k]=v end
    env.GetBool=function(k)
        if k=='game.player.interactive' and w.reg[k]==nil then return true end
        return w.reg[k] or false
    end
    env.SetBool=function(k,v) assert(k=='savegame.mod.osp_beta.health_hud');w.reg[k]=v end
    env.GetInt=function() return 0 end;env.LoadLanguageTable=function() end
    env.GetTranslatedStringByKey=function(k,fallback) if k=='TOOL_NAME_GUN' then return 'Pistol' end;return fallback end
    env.GetLocalPlayer=function() return 11 end
    env.IsPlayerValid=function(p) return p==11 or p==23 end
    env.GetPlayerHealth=function(p)
        assert(not w.drawn,'HUD must not read health');assert(p==env.GetLocalPlayer());return w.hp
    end
    env.GetPlayerVehicle=function(p) assert(p==env.GetLocalPlayer());return w.vehicle end
    env.GetPlayerScreen=function(p) assert(p==env.GetLocalPlayer());return w.screen end
    env.IsPlayerHost=function(p) return p==11 end
    env.GetTime=function() return w.now end
    env.GetPlayerCanUseTool=function(p) assert(p==11);return w.canUseTool~=false end
    env.IsToolEnabled=function(id,p) return id=='sledge' end
    env.ServerCall=function(fn,...)
        local out=fn=='server.ospFlightInput' and w.flightReports or fn=='server.ospStrengthInput' and w.strengthReports or fn=='server.ospIdentify' and w.identitySent or w.sent
        out[#out+1]={fn=fn,args={...}}
    end
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
    env.UiImage=function(path)
        assert(w.drawn)
        check(path=="MOD/ui/section-down.png" or path=="MOD/ui/section-right.png","known disclosure asset")
        w.images[#w.images+1]=path;return 16,16
    end
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
        self.texts={};self.paints={};self.images={};self.drawn=true;self.t={x=0,y=0,s=1};self.stack={}
        env.client.draw();self.drawn=false;eq(#self.stack,0,'UI stack balanced')
        return env.OSP.UI.getState()
    end
    function w:scrollTo(id)
        for _=1,40 do
            local st=self:draw();local r=st.controls[id]
            if r and r.w>=20 and r.h>=20 then return r end
            if st.permissionExpanded and st.permissionViewport then
                local v=st.permissionViewport
                self.mouse={x=v.x+10,y=v.y+v.h/2}
                local before=env.OSP.PermissionUI.getState().scroll
                self:tick(nil,-2);self:draw()
                if env.OSP.PermissionUI.getState().scroll==before and before>0 then self:tick(nil,100) end
            else
                if st.maxScroll==0 then error('missing control: '..id) end
                local l=st.layout;self.mouse={x=l.ox+l.contentX+10,y=l.oy+l.contentY+l.contentH/2}
                if st.scroll>=st.maxScroll then self:tick(nil,100) else self:tick(nil,-1) end
            end
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
    function w:chooseRole(id)
        self:clickControl('permission_view_role_select')
        local option='permission_view_role_select_option_'..id
        for _=1,30 do
            local st=self:draw();local r=st.controls[option]
            if r and r.h>=20 then self:clickControl(option);return end
            local b=st.roleDropdown and st.roleDropdown.bounds
            assert(b,'role dropdown is open')
            self.mouse={x=b.x+b.w/2,y=b.y+b.h/2};self:tick(nil,-2)
        end
        error('role is not reachable in dropdown: '..id)
    end
    function w:editControl(id)
        self:clickControl(id)
        self.mods={ctrl=true};self:tick('a');self.mods=nil
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
    w:tick();eq(w.identitySent[#w.identitySent].fn,'server.ospIdentify');eq(w.identitySent[#w.identitySent].args[3],1);eq(w.identitySent[#w.identitySent].args[4],'')
    local before=#w.identitySent;w:tick();eq(#w.identitySent,before,'identity requests are throttled')
    w.now=w.now+1;w:tick();eq(#w.identitySent,before+1,'lost reply can be retried')
    e.client.ospIdentity(string.rep('b',32),1,'p8');eq(w.reg['savegame.mod.osp_beta.identity.'..namespace],nil)
    e.client.ospIdentity(namespace,1,'host');eq(w.reg['savegame.mod.osp_beta.identity.'..namespace],nil)
    e.client.ospIdentity(namespace,1,'p8');eq(w.reg['savegame.mod.osp_beta.identity.'..namespace],'p8')
    before=#w.identitySent;w.now=w.now+2;w:tick();eq(#w.identitySent,before,'ACK stops identity retries')
    e.shared.osp.players[1].profileChallenge=2;w.now=w.now+2;w:tick()
    e.client.ospIdentity(namespace,1,'p99');eq(w.reg['savegame.mod.osp_beta.identity.'..namespace],'p8','old join reply is ignored')
    e.client.ospIdentity(namespace,2,'p9');eq(w.reg['savegame.mod.osp_beta.identity.'..namespace],'p9')
    e.client.ospIdentity(namespace,1,'p8');eq(w.reg['savegame.mod.osp_beta.identity.'..namespace],'p9','stale reply cannot overwrite current profile')
    local map=world(1024,768,w.reg);local m=map.api
    m.IsPlayerHost=function() return false end;m.shared.osp.profileHost=namespace;m.shared.osp.players[1].profileChallenge=3
    map:tick();eq(map.identitySent[#map.identitySent].args[4],'p9','new map sends saved identity')
    m.client.ospIdentity(namespace,2,'p99');eq(map.reg['savegame.mod.osp_beta.identity.'..namespace],'p9','old map reply is ignored')
    m.shared.osp.profileHost=string.rep('c',32);map.now=map.now+2;map:tick()
    eq(map.identitySent[#map.identitySent].args[4],'','another host does not reuse the profile')
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
    w.reg['savegame.mod.osp_beta.language']=language;w.reg['savegame.mod.osp_beta.settings.collapsed.palette']='1';e.OSP.UI.open(true)
    local r=w:scrollTo('tab_appearance')
    local function point(rect)
        return rect.x+(corner[1]>0 and corner[1] or rect.w+corner[1]),rect.y+(corner[2]>0 and corner[2] or rect.h+corner[2])
    end
    local x,y=point(r);w:pressAt(x,y)
    eq(e.OSP.UI.getState().tab,'appearance','Appearance tab reacts on press in background padding')
    w:releaseAt(x,y)
    w:clickControl('settings_section_palette');w:clickControl('palette_custom')
    r=w:scrollTo('palette_R_plus');x,y=point(r);w:pressAt(x,y)
    local color=w.reg['savegame.mod.osp_beta.theme.custom.back']
    check(color~=nil,'RGB control reacts on press in background padding')
    for i=1,3 do w:holdAt(x,y);eq(w.reg['savegame.mod.osp_beta.theme.custom.back'],color,'hold does not repeat') end
    w:releaseAt(x,y);eq(w.reg['savegame.mod.osp_beta.theme.custom.back'],color,'release does not repeat')
    local st=w:draw();local count=#w.sent
    w:pressAt(x,st.layout.oy+st.layout.contentY+st.layout.contentH+4)
    eq(#w.sent,count,'outside viewport sends no command')
    eq(w.reg['savegame.mod.osp_beta.theme.custom.back'],color,'outside viewport leaves color unchanged')
    w:releaseAt(x,y)
  end
 end
end
for _,size in ipairs({{1280,720},{1920,1080},{2560,1440},{1024,768},{2560,1080}}) do
 for _,language in ipairs({'en','pt'}) do
    local w=world(unpack(size));local e=w.api;w.reg['savegame.mod.osp_beta.language']=language
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
    w:clickControl('confirm_accept');eq(w.sent[#w.sent].args[2],'reset_player');eq(w.sent[#w.sent].args[3],23)
    eq(w.sent[#w.sent].args[6].host,e.shared.osp.profileHost,'targeted confirmation sends its frozen host namespace')
    eq(w.sent[#w.sent].args[6].targetJoin,2,'targeted confirmation sends its frozen join marker');w:ack()
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
    w:clickControl('tool_gun');eq(w.sent[#w.sent].args[2],'tool');eq(w.sent[#w.sent].args[3],23)
    eq(w.sent[#w.sent].args[6].host,e.shared.osp.profileHost,'immediate targeted action captures its namespace')
    eq(w.sent[#w.sent].args[6].targetJoin,2,'immediate targeted action captures the current entry');w:ack()
    w:clickControl('tools_actions');w:clickControl('tools_disable_everyone');eq(e.OSP.UI.getState().confirm.action,'tools_selection_all');w:clickControl('confirm_cancel')
    w:clickControl('tab_settings');eq(e.OSP.UI.getState().controls.health_toggle,nil,'health toggle removed')
    w.reg['savegame.mod.osp_beta.settings.collapsed.palette']='1';w:clickControl('tab_appearance');w:clickControl('settings_section_palette');w:clickControl('palette_ocean');eq(w.reg['savegame.mod.osp_beta.theme.mode'],'ocean')
    w:clickControl('palette_custom');w:clickControl('palette_R_plus')
    check(w.reg['savegame.mod.osp_beta.theme.custom.back']~=nil,'custom RGB control saves')
    w:clickControl('palette_restore');eq(w.reg['savegame.mod.osp_beta.theme.mode'],'classic')
    w:clickControl('tab_settings');w:clickControl('rebind');w:tick('w');eq(e.OSP.UI.getState().keyCapture,true);w:tick('f8');eq(e.OSP.UI.getState().menuKey,'f8')
    local oldStatus=e.OSP.UI.getState().status;e.client.ospResult(false,'error',{},nil)
    eq(e.OSP.UI.getState().status,oldStatus,'unsolicited nil ACK ignored')
    w:clickControl('tab_about');w:draw();local combined=table.concat(w.texts,'|');check(combined:find('Luiz%-AVcruz')~=nil,'about author')
    e.client.ospAnnouncement('Host','Hello everyone');check(e.OSP.UI.getState().status:find('Hello everyone')~=nil,'announcement visible with menu open')
    e.OSP.UI.open(false);w.now=w.now+7
    w.reg['savegame.mod.osp_beta.health_hud']=true -- Old saved preferences must not resurrect the removed HUD.
    w:draw();eq(#w.texts,0,'no health HUD even with old setting enabled')
    local nextMap=world(size[1],size[2],w.reg);nextMap:draw();eq(#nextMap.texts,0,'no HUD after map reload')
    e.IsPlayerHost=function() return false end;e.shared.osp.players[1].admin=false;e.OSP.UI.selectTab('players');w:tick();e.OSP.UI.open(true);w:draw();eq(e.OSP.UI.getState().tab,'appearance')
    w:clickControl('tab_about');w:draw();eq(e.OSP.UI.getState().tab,'about','guests can read about')
    local d=world(size[1],size[2]);local de=d.api
    de.IsPlayerHost=function() return false end
    de.shared.osp.players[1].host=false;de.shared.osp.players[1].admin=true
    de.shared.osp.players[2].host=true;de.shared.osp.players[2].admin=true
    d:tick('p');d:clickControl('tab_tools');local ds=d:draw()
    eq(ds.toolMode,'player','delegated admin receives temporary mode')
    eq(ds.controls.tool_mode_global.disabled,true,'global policy requires an explicit admin capability')
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
-- A frozen confirmation is cancelled on an entry or namespace change. A click
-- already over the background cannot fall through when draw detects the change.
do
    local w=world(1280,720);local e=w.api;e.OSP.UI.open(true);w:draw();w:clickControl('player_23')
    w:scrollTo('player_action_heal');w:clickControl('player_action_kill')
    local state=e.OSP.UI.getState();eq(state.confirm.action,'kill')
    eq(state.confirm.targetContext.host,e.shared.osp.profileHost);eq(state.confirm.targetContext.targetJoin,2)
    local heal=state.controls.player_action_heal;local sent=#w.sent
    e.shared.osp.players[2].profileChallenge=99
    w.mouse={x=heal.x+heal.w/2,y=heal.y+heal.h/2};w.click=true;w.held=true;w.now=w.now+1/60
    state=w:draw()
    eq(state.confirm,nil,'draw cancels confirmation for a recycled target')
    eq(state.status,e.OSP.L('result_unavailable'),'draw reports unavailable target')
    eq(#w.sent,sent,'old click cannot trigger the underlying heal button')
end
do
    local w=world(1280,720);local e=w.api;e.OSP.UI.open(true);w:draw();w:clickControl('player_23')
    w:clickControl('player_action_kill');local accept=e.OSP.UI.getState().controls.confirm_accept;local sent=#w.sent
    local inputPressed=e.InputPressed;local changed=false
    e.InputPressed=function(key)
        if key=='lmb' and w.click and not changed then e.shared.osp.players[2].profileChallenge=100;changed=true end
        return inputPressed(key)
    end
    w.mouse={x=accept.x+accept.w/2,y=accept.y+accept.h/2};w.click=true;w.held=true;w.now=w.now+1/60
    local state=w:draw()
    eq(changed,true,'entry changes after draw validation and before dispatch')
    eq(state.confirm,nil,'send boundary cancels stale confirmation')
    eq(state.status,e.OSP.L('result_unavailable'));eq(#w.sent,sent,'stale confirmation sends no command')
end
do
    local w=world(1280,720);local e=w.api;e.OSP.UI.open(true);w:draw();w:clickControl('player_23')
    w:clickControl('reset_player');local sent=#w.sent
    e.shared.osp.profileHost=string.rep('b',32);w:tick()
    local state=e.OSP.UI.getState()
    eq(state.confirm,nil,'tick cancels confirmation after host namespace changes')
    eq(state.status,e.OSP.L('result_unavailable'));eq(#w.sent,sent,'namespace change sends no request')
end
do
    local w=world(1280,720);local e=w.api;e.OSP.UI.open(true);w:draw();w:clickControl('player_23')
    w:clickControl('tab_tools');w:clickControl('tool_mode_player');w:clickControl('tools_actions')
    w:clickControl('tools_disable_filtered')
    eq(e.OSP.UI.getState().confirm.action,'tools_selection');local sent=#w.sent
    table.remove(e.shared.osp.players,2);w:tick()
    local state=e.OSP.UI.getState()
    eq(state.confirm,nil,'missing target cancels tools selection confirmation')
    eq(state.status,e.OSP.L('result_unavailable'));eq(#w.sent,sent,'missing target sends no tools request')
end
do
    local w=world(1280,720);local e=w.api;e.OSP.UI.open(true);e.shared.osp.profileHost='';w:draw()
    w:clickControl('player_23');w:clickControl('player_action_kill')
    eq(e.OSP.UI.getState().confirm,nil,'confirmation fails closed without a valid namespace')
    eq(e.OSP.UI.getState().status,e.OSP.L('result_unavailable'));eq(#w.sent,0)
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
    eq(e.OSP.UI.getState().tab,'appearance','disabled tab ignores padding press');eq(#w.sent,count)
end
-- A host must not silently issue a temporary change before identification.
do
    local w=world(1024,768);local e=w.api
    e.shared.osp.players[2].profileReady=false;e.OSP.UI.open(true)
    w:clickControl('player_23')
    for _,id in ipairs({'player_action_god','player_action_fly','player_action_noclip','fly_settings','noclip_settings','player_speed_value','player_action_freeze','speed_up','player_role_manage','reset_player'}) do
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
    w.reg['savegame.mod.osp_beta.language']=language
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
    w.reg['savegame.mod.osp_beta.language']=language
    e.shared.osp.templates=e.OSP.Permissions.list({})
    e.OSP.UI.open(true);w:clickControl('tab_permissions')
    local st=w:draw()
    eq(st.controls.role_editor_name,nil,'assignment view hides editor name')
    eq(st.controls.role_editor_save,nil,'assignment view hides editor save')
    eq(st.controls.role_scope_heal,nil,'assignment view hides editable permissions')
    w:clickControl('role_target_next')
    w:chooseRole('self')
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
    w:clickControl('permission_group_players')
    w:clickControl('role_scope_heal_2')
    local editedRequestRect=w:scrollTo('role_editor_save')
    w:pressAt(editedRequestRect.x+2,editedRequestRect.y+2,'c');w:releaseAt(editedRequestRect.x+2,editedRequestRect.y+2)
    local edited=w.sent[#w.sent].args[4]
    eq(w.sent[#w.sent].args[2],'role_save')
    eq(edited.id,'c1');eq(edited.version,1);eq(edited.permissions.heal,2,'scope changes independently')
    e.client.ospResult(false,'conflict',{},w.sent[#w.sent].args[5])
    eq(e.OSP.UI.getState().status,e.OSP.L('role_conflict'))
    st=w:draw()
    eq(w:scrollTo('role_scope_heal_2').disabled,false,'conflict leaves the custom editor and draft active')
    saved.version=2;saved.permissions.heal=0
    for i,entry in ipairs(e.shared.osp.templates) do if entry.id=='c1' then e.shared.osp.templates[i]=saved end end
    w:draw()
    w:clickControl('role_editor_reload')
    w:clickControl('role_scope_heal_1') -- Reloaded blocked value, now allow self only.
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
    eq(st.controls.permission_view_role_select~=nil,true,'deleted role is hidden before shared catches up')
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
    eq(w:scrollTo('tab_permissions').disabled,true,'old presets have no delegated template management')
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
-- Self teleport controls are disabled for hosts and delegates, with localized hints and no RPC.
for _,localId in ipairs({11,23}) do
    for _,language in ipairs({'en','pt'}) do
        local w=world(1920,1080);local e=w.api
        e.GetLocalPlayer=function() return localId end;e.client.init()
        w.reg['savegame.mod.osp_beta.language']=language
        if localId==23 then
            e.shared.osp.players[2].admin=true;e.shared.osp.players[2].role='admin'
            e.shared.osp.players[2].permissions=e.OSP.Permissions.resolve('admin').permissions
        end
        e.OSP.UI.open(true);w:draw()
        local expected=language=='pt' and 'Selecione outro jogador' or 'Select another player'
        eq(e.OSP.L('tip_select_another_player'),expected,'self teleport hint translation')
        for _,id in ipairs({'player_action_goto','player_action_bring'}) do
            local r=w:scrollTo(id)
            eq(r.disabled,true,'self teleport control is disabled for local player')
            w.mouse={x=r.x+r.w/2,y=r.y+r.h/2};w:draw();w.now=w.now+.61
            eq(w:draw().tooltip.text,expected,'disabled self teleport has localized hint')
            local before=#w.sent
            w:pressAt(r.x+r.w/2,r.y+r.h/2);w:releaseAt(r.x+r.w/2,r.y+r.h/2)
            eq(#w.sent,before,'disabled self teleport does not send RPC')
        end
    end
end
-- Numeric edits use the same permission/command path as the +/- controls.
for _,size in ipairs({{1024,768},{1920,1080}}) do
 for _,language in ipairs({'en','pt'}) do
    local w=world(unpack(size));local e=w.api
    w.reg['savegame.mod.osp_beta.language']=language;e.OSP.UI.open(true)
    local function edit(id,text,action,value,key)
        w:editControl(id);check(e.OSP.NumberInput.active(id),'number field takes focus')
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
    w:editControl('player_speed_value');w:tick('2');w:tick('esc')
    eq(#w.sent,before,'Escape discards a numeric edit')
    eq(e.OSP.NumberInput.active(),false)
    w:editControl('player_speed_value');w:tick('2');w:clickControl('close')
    eq(#w.sent,before+1,'Close confirms a valid number before closing')
    eq(w.sent[#w.sent].args[4],2);w:ack();before=#w.sent
    eq(e.OSP.NumberInput.active(),false)
    e.OSP.UI.open(true);w:editControl('player_speed_value')
    local r=w:scrollTo('speed_up');w:pressAt(r.x+2,r.y+2,'9');w:releaseAt(r.x+2,r.y+2)
    eq(#w.sent,before+1,'simultaneous typing and mouse confirms only one value')
    eq(w.sent[#w.sent].args[4],3,'outside click includes the last digit and clamps it');w:ack()
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
    before=#w.sent;w:editControl('rule_fog_value');w:tick('5');w:clickControl('tab_players');w:tick('return')
    eq(#w.sent,before+1,'changing tabs confirms a valid number once')
    eq(w.sent[#w.sent].args[4].value,10);w:ack();before=#w.sent
    w.reg['savegame.mod.osp_beta.settings.collapsed.palette']='1';w:clickControl('tab_appearance');w:clickControl('settings_section_palette');w:clickControl('palette_custom')
    local color=e.OSP.Theme.colors().back
    local green,blue=math.floor(color[2]*255+.5)/255,math.floor(color[3]*255+.5)/255
    w:editControl('palette_R_value');w:tick('9');w:tick('9');w:tick('9');w:tick('return')
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
    e.OSP.UI.open(true);w:draw();w:editControl('player_speed_value');w:tick('2')
    p.permissions=e.OSP.Permissions.normalize({})
    local before=#w.sent;w:tick('return')
    eq(#w.sent,before,'revoking speed access also blocks an already-open field')
    p.permissions=e.OSP.Permissions.resolve('self').permissions
    w:clickControl('player_11');eq(w:scrollTo('player_speed_value').disabled,true,'self-only scope protects other numeric targets')
    w:clickControl('player_23');w:editControl('player_speed_value');w:tick('2')
    p.profileChallenge=99;w:tick('return')
    eq(#w.sent,before,'a reused session player cannot receive an old numeric edit')
end
do
    local w=world(1024,768);local e=w.api
    e.GetLocalPlayer=function() return 23 end;e.client.init()
    local p=e.shared.osp.players[2];p.admin=true;p.permissions=e.OSP.Permissions.normalize({fly=1})
    e.OSP.UI.open(true);w:draw()
    eq(w:scrollTo('noclip_settings').disabled,true,'Fly grants cannot edit Noclip')
    w:clickControl('fly_settings');w:editControl('fly_speed_value');w:tick('2')
    p.permissions=e.OSP.Permissions.normalize({})
    local before=#w.sent;w:tick('return');eq(#w.sent,before,'revocation blocks an open movement editor')
    p.permissions=e.OSP.Permissions.normalize({noclip=1});w:draw()
    eq(w:scrollTo('fly_settings').disabled,true,'Noclip grants cannot edit Fly')
    w:clickControl('noclip_settings');w:editControl('noclip_boost_value');w:tick('4')
    p.profileChallenge=77;w:tick('return');eq(#w.sent,before,'movement tuning checks the target join before sending')
    w:clickControl('noclip_settings');w:editControl('noclip_speed_value');w:tick('5')
    w:clickControl('movement_popup_close')
    eq(#w.sent,before+1,'explicit close confirms the old target before switching')
    eq(w.sent[#w.sent].args[3],23);w:ack();before=#w.sent
    w:clickControl('player_11');w:tick('return')
    eq(#w.sent,before,'switching target cannot replay the old edit')
    eq(w:scrollTo('noclip_settings').disabled,true,'self-only Noclip cannot edit host settings')
end
for _,size in ipairs({{640,480},{1024,768},{1920,1080}}) do
 for _,language in ipairs({'en','pt'}) do
    local w=world(unpack(size));local e=w.api
    w.reg['savegame.mod.osp_beta.language']=language;e.OSP.UI.open(true)
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
        w:editControl(mode..'_speed_value');w:tick('2')
        local close=e.OSP.UI.getState().controls.close
        local outside=e.OSP.UI.getState().layout
        w:pressAt(outside.ox+2,outside.oy+2);w:releaseAt(outside.ox+2,outside.oy+2)
        st=w:draw();eq(st.movementPopup,nil,'outside press closes popup')
        eq(st.open,true,'outside press does not click the main Close button underneath')
        eq(#w.sent,before+1,'outside press confirms the number before closing')
        w:ack();before=#w.sent
        eq(e.OSP.NumberInput.active(),false)
        w:clickControl(mode..'_settings');w:editControl(mode..'_boost_value');w:tick('3');w:tick('esc')
        check(w:draw().movementPopup~=nil,'first Escape cancels only numeric editing')
        eq(e.OSP.UI.getState().open,true);eq(#w.sent,before,'Escape cannot save the draft')
        w:tick('esc');eq(w:draw().movementPopup,nil,'second Escape closes the popup')
        w:clickControl(mode..'_settings');w:editControl(mode..'_speed_value');w:tick('4')
        w:clickControl('movement_popup_close');eq(w:draw().movementPopup,nil,'X closes popup')
        eq(#w.sent,before+1,'X confirms a valid number before closing')
        w:ack()
        w:clickControl(mode..'_settings');e.OSP.UI.open(false)
        eq(w:draw().movementPopup,nil,'closing panel clears popup')
        e.OSP.UI.open(true)
    end
 end
end
for _,size in ipairs({{1024,768},{1920,1080}}) do
 for _,language in ipairs({'en','pt'}) do
    local w=world(unpack(size));local e=w.api;e.OSP.UI.open(true)
    w.reg['savegame.mod.osp_beta.language']=language
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
    w.reg['savegame.mod.osp_beta.language']=language
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
  for _,palette in ipairs({'classic','ocean','forest','violet','light','graphite','custom'}) do
    local w=world(unpack(size));local e=w.api;w.capturePaint=true
    w.reg['savegame.mod.osp_beta.language']=language;w.reg['savegame.mod.osp_beta.theme.mode']=palette
    if palette=='custom' then w.reg['savegame.mod.osp_beta.theme.custom.surface']='334155';w.reg['savegame.mod.osp_beta.theme.custom.line']='94a3b8' end
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
    w:pressAt(r.x+2,r.y+2);eq(e.OSP.UI.getState().tab,'appearance','disabled navigation cannot change tabs')
  end
 end
end
-- Hiding tabs reflows navigation and survives new client contexts.
for _,size in ipairs({{640,480},{1024,768},{1920,1080}}) do
 for _,language in ipairs({'en','pt'}) do
    local w=world(unpack(size));local e=w.api;w.reg['savegame.mod.osp_beta.language']=language;e.OSP.UI.open(true)
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
    w:clickControl('tab_players');w:clickControl('fly_settings');w:editControl('fly_speed_value');w:tick('4')
    e.OSP.Navigation.setVisible('players',false);w:tick('return')
    eq(e.OSP.UI.getState().movementPopup,nil);eq(e.OSP.NumberInput.active(),false);eq(#w.sent,0,'hidden page draft never dispatches')
    e.IsPlayerHost=function() return false end;e.shared.osp.players[1].admin=false
    e.OSP.Navigation.setVisible('settings',false);e.OSP.Navigation.setVisible('about',false);w:tick();st=w:draw()
    eq(st.tab,'appearance','guest fallback stays accessible');eq(st.controls.tab_session.disabled,true,'showing tabs never grants permissions')
 end
end
-- Tooltips use visible hit rectangles, time and player context, never input capture.
for _,size in ipairs({{640,480},{1024,768},{1920,1080}}) do
 for _,language in ipairs({'en','pt'}) do
    local w=world(unpack(size));local e=w.api;e.OSP.UI.open(true);w.reg['savegame.mod.osp_beta.language']=language
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
    hover('player_speed_value');wait();w:editControl('player_speed_value');w.now=w.now+1;eq(w:draw().tooltip,nil,'numeric editor suppresses hints')
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
-- Tool availability is independent of gameplay input: holding an object or
-- using Plank must not block an otherwise valid personal shortcut.
for _,binding in ipairs({{'god','f8'},{'fly','f9'},{'noclip','f10'}}) do
    local w=world(1024,768);local e=w.api;local own=e.shared.osp.players[1]
    own.profileReady=true;w.canUseTool=false
    check(e.OSP.Shortcuts.assign(binding[1],binding[2]))
    eq(e.GetPlayerCanUseTool(11),false,'tool is unavailable in the regression scenario')
    w:tick(binding[2]);eq(#w.sent,1,'tool use does not block the shortcut')
    local request=w.sent[1]
    eq(request.args[2],binding[1]);eq(request.args[3],11)
    eq(request.args[4].expected,false);eq(request.args[4].value,true)
    eq(request.args[6].host,e.shared.osp.profileHost);eq(request.args[6].targetJoin,own.profileChallenge)
    w:ack();own[binding[1]]=true
    w.mods={[binding[2]]=true}
    for _=1,3 do w:tick() end
    eq(#w.sent,1,'held input does not repeat or queue a shortcut')
    w.mods={};w:tick(binding[2]);eq(#w.sent,2,'a new press can turn the option off')
    eq(w.sent[2].args[4].expected,true);eq(w.sent[2].args[4].value,false)
end
-- Keep native state independent of the published snapshot so stale data
-- cannot accidentally make these protections pass.
for _,scenario in ipairs({
    {'pause',function(w) w.reg['game.paused']=true end},
    {'map',function(w) w.reg['game.map.enabled']=true end},
    {'other interactive UI',function(w) w.reg['game.player.interactive']=false end},
    {'current death despite living snapshot',function(w) w.hp=0 end},
    {'current vehicle despite walking snapshot',function(w) w.vehicle=99 end},
    {'interactive screen',function(w) w.screen=42 end},
    {'invalid player',function(w,e)
        e.IsPlayerValid=function() return false end
        e.GetPlayerHealth=function() error('invalid player must not reach native state queries') end
    end},
    {'pause pressed with shortcut',function(w,e)
        local pressed=e.InputPressed;e.InputPressed=function(key) return key=='pause' or pressed(key) end
    end},
    {'Escape pressed with shortcut',function(w,e)
        local pressed=e.InputPressed;e.InputPressed=function(key) return key=='esc' or pressed(key) end
    end},
}) do
    local w=world(1024,768);local e=w.api
    e.shared.osp.players[1].profileReady=true;w.canUseTool=false
    check(e.OSP.Shortcuts.assign('god','f8'))
    scenario[2](w,e);w:tick('f8');eq(#w.sent,0,scenario[1]..' blocks the shortcut')
end
-- Physical shortcuts target self, guard the observed state and never queue input.
for _,size in ipairs({{640,480},{1024,768},{1920,1080}}) do
 for _,language in ipairs({'en','pt'}) do
    local w=world(unpack(size));local e=w.api;w.reg['savegame.mod.osp_beta.language']=language
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
    w.reg['game.player.interactive']=false;w:tick('f9');eq(#w.sent,count,'interactive UI blocks');w.reg['game.player.interactive']=true
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
    e.InputDown=down;w.reg['savegame.mod.osp_beta.shortcuts.noclip']='f8';w:tick('f8');eq(#w.sent,count,'stored duplicates are inactive')
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
    local w=world(unpack(size));local e=w.api;w.reg['savegame.mod.osp_beta.language']=language;e.OSP.UI.open(true)
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
    local w=world(unpack(size));local e=w.api;e.OSP.UI.open(false);e.shared.osp.players[1].profileReady=true;w.reg['savegame.mod.osp_beta.language']=language
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
-- Fly steering uses the local gameplay context, not tool availability.
do
    local w=world(1024,768);local e=w.api
    e.shared.osp.profileHost='test-host'
    local own=e.shared.osp.players[1]
    w:tick();eq(#w.flightReports,0,'no flight reports without the ability')
    own.fly=true;w.canUseTool=false;w:tick()
    local function report() return w.flightReports[#w.flightReports].args end
    eq(#w.flightReports,1);eq(report()[1],11);eq(report()[2],'test-host')
    eq(report()[3],1);eq(report()[5],true,'grabbing or Plank cannot suppress gameplay input')
    local sequence=report()[4]
    w:tick();eq(#w.flightReports,1,'unchanged context is not sent every frame')
    w.now=w.now+.21;w:tick();eq(#w.flightReports,2);check(report()[4]>sequence)
    w:tick('p');eq(report()[5],false,'panel opening immediately blocks steering')
    w:tick('p');eq(report()[5],true,'panel closing restores gameplay')
    w.reg['game.paused']=true;w:tick();eq(report()[5],false,'personal pause blocks steering')
    w.reg['game.paused']=false;w:tick();eq(report()[5],true)
    w.reg['game.map.enabled']=true;w:tick();eq(report()[5],false,'map overlay blocks steering')
    w.reg['game.map.enabled']=false;w:tick();eq(report()[5],true)
    w.reg['game.player.interactive']=false;w:tick();eq(report()[5],false,'other UI blocks steering')
    w.reg['game.player.interactive']=true;w:tick();eq(report()[5],true)
    own.profileChallenge=2;w:tick();eq(report()[3],2,'reused player ID reports the new join')
    e.shared.osp.profileHost='new-host';w:tick();eq(report()[2],'new-host')
    own.fly=false;local n=#w.flightReports;w.now=w.now+1;w:tick();eq(#w.flightReports,n)
end

-- The presentation adapts to the native session, not the participant count.
for _,size in ipairs({{640,480},{1024,768},{1920,1080}}) do
 for _,language in ipairs({"en","pt"}) do
    local w=world(unpack(size));local e=w.api
    w.reg["savegame.mod.osp_beta.language"]=language
    e.IsMultiplayer=function() return false end
    w:tick("p");local st=w:draw()
    eq(st.viewMode,"single");eq(st.selected,11)
    check(not st.controls.tab_permissions,"solo hides Permissions")
    check(not st.controls.player_11 and not st.controls.player_23,"solo omits roster")
    check(not st.controls.player_action_goto and not st.controls.player_action_bring,"solo omits player teleports")
    w:scrollTo("reset_player");st=w:draw()
    check(not st.controls.heal_all and not st.controls.bring_all,"solo omits collective actions")
    w:clickControl("tab_tools");st=w:draw()
    eq(st.toolMode,"global");check(not st.controls.tool_mode_player and not st.controls.tool_mode_global,"only one tools scope")
    check(not st.controls.tool_player_next,"no tool target selector")
    -- A global enabled policy can still have an old personal restriction.
    e.IsToolEnabled=function() return false end
    for _=1,3 do if w:draw().controls.tool_sledge then break end;w:clickControl("tools_next") end
    w:clickControl("tool_sledge")
    eq(w.sent[#w.sent].args[2],"tool_policy");eq(w.sent[#w.sent].args[4].mode,"enabled","solo primary action follows effective availability")
    local id=w.sent[#w.sent].args[5]
    e.OSP.ViewMode.set("multi");w:tick();st=w:draw()
    check(st.requestPending and st.pendingId==id,"switch preserves an in-flight request")
    check(st.controls.tab_permissions,"manual multiplayer exposes full navigation")
    w:ack()
    e.OSP.ViewMode.set("auto");e.IsMultiplayer=function() return true end
    e.shared.osp.players={e.shared.osp.players[1]};w:tick();st=w:draw()
    eq(st.viewMode,"multi","multiplayer host alone keeps full interface")
    e.OSP.ViewMode.set("single");w:tick();w:clickControl("tab_session");st=w:draw()
    check(not st.controls.announcement_field and not st.controls.announcement_send,"no announcements in solo")
    w:clickControl("tab_players");w:clickControl("player_action_kill");check(w:draw().confirm,"confirmation opened")
    e.OSP.ViewMode.set("multi");w:tick();check(not w:draw().confirm,"switch discards unsent confirmation")
    eq(#w.sent,1,"mode changes never send gameplay commands")
    w:clickControl("tab_settings");w:clickControl("view_mode_single");w:tick();eq(w:draw().viewMode,"single","live Settings mode selector")
    local again=world(size[1],size[2],w.reg);again:tick("p");eq(again:draw().viewMode,"single","local preference persists")
 end
end
-- Context filtering does not rewrite hidden tabs or saved gameplay rules.
do
    local w=world(1920,1080);local e=w.api
    w.reg["savegame.mod.osp_beta.navigation.hidden.activity"]="1"
    w.reg["savegame.mod.osp_beta.players.test.tools.abc"]="2"
    w:tick("p");w:clickControl("player_23");w:clickControl("fly_settings")
    check(w:draw().movementPopup,"movement editor for another player")
    e.OSP.ViewMode.set("single");w:tick();local st=w:draw()
    eq(st.selected,11,"switch targets self");check(not st.movementPopup,"switch closes editor")
    check(not st.controls.tab_activity and not st.controls.tab_permissions,"both visibility filters apply")
    e.OSP.ViewMode.set("multi");w:tick();st=w:draw()
    check(st.controls.tab_permissions and not st.controls.tab_activity,"only context-hidden tabs return")
    eq(w.reg["savegame.mod.osp_beta.players.test.tools.abc"],"2","presentation preserves saved rules")
    eq(#w.sent,0,"switching modes has no gameplay effects")
    w:clickControl("tab_tools");w:clickControl("tools_actions");check(w:draw().toolsPopup,"tools popup opens")
    e.OSP.ViewMode.set("single");w:tick();check(not w:draw().toolsPopup,"switch closes tools popup")
end
-- A guest cannot gain global tool access by forcing Singleplayer.
do
    local w=world(1920,1080);local e=w.api
    e.IsPlayerHost=function() return false end
    local own=e.shared.osp.players[1];own.host=false;own.admin=true
    e.OSP.ViewMode.set("single");w:tick("p");w:clickControl("tab_tools")
    check(w:scrollTo("tool_sledge").disabled,"global tool action remains host-only")
    check(w:scrollTo("tool_more_sledge").disabled,"global tool popup remains host-only")
    eq(#w.sent,0,"presentation cannot grant authority")
end

-- Settings sections reflow and persist without hiding interactive controls.
for _,size in ipairs({{640,480},{1024,768},{1920,1080}}) do
 for _,language in ipairs({"en","pt"}) do
    local w=world(unpack(size));local e=w.api;local sections=e.OSP.SettingsSections
    w.reg["savegame.mod.osp_beta.language"]=language
    w:tick("p");w:clickControl("tab_settings")
    for _,id in ipairs(sections.ids) do check(sections.expanded(id),"all sections start open") end
    w:scrollTo("settings_section_language");local before=w:draw()
    local initialMax=before.maxScroll
    local r=before.controls.settings_section_language
    -- The far edge works independently of title text; hold/release do not repeat.
    w:pressAt(r.x+r.w-2,r.y+r.h/2)
    check(not sections.expanded("language"),"header padding collapses")
    w:holdAt(r.x+r.w-2,r.y+r.h/2);w:releaseAt(r.x+r.w-2,r.y+r.h/2)
    check(not sections.expanded("language"),"hold/release keeps state")
    local st=w:draw();check(not st.controls.language_en and not st.controls.language_pt,"hidden language controls removed")
    check(st.maxScroll<initialMax,"collapse shrinks content")
    w:clickControl("rebind");check(e.OSP.Shortcuts.capture=="menu","capture starts")
    w:clickControl("settings_section_shortcut");check(not e.OSP.Shortcuts.capture,"collapse cancels capture")
    eq(w.reg["savegame.mod.osp_beta.menu_key"],"p","collapse does not change binding")
    for _,id in ipairs({"view_mode","navigation"}) do w:clickControl("settings_section_"..id) end
    w:clickControl("tab_appearance")
    for _,id in ipairs({"palette","background"}) do w:clickControl("settings_section_"..id) end
    for _,id in ipairs(sections.ids) do check(not sections.expanded(id),"all sections collapsed") end
    st=w:draw()
    for _,id in ipairs({"rebind","view_mode_auto","navigation_restore","palette_classic"}) do check(not st.controls[id],"collapsed body omitted: "..id) end
    check(st.scroll<=st.maxScroll,"scroll remains bounded after collapse at bottom")
    w:tick("p");w:tick("p");w:clickControl("tab_settings")
    check(not sections.expanded("palette"),"reopening panel retains state")
    local again=world(size[1],size[2],w.reg)
    for _,id in ipairs(sections.ids) do check(not again.api.OSP.SettingsSections.expanded(id),"new Lua instance retains state") end
    w:clickControl("tab_appearance");w:clickControl("settings_section_palette");w:clickControl("palette_custom")
    local original=e.OSP.Theme.hex(e.OSP.Theme.colors().back)
    w:editControl("palette_R_value");w:tick("5")
    check(e.OSP.NumberInput.active("palette_R_value"),"custom field editing")
    local header=w:scrollTo("settings_section_palette")
    local stillVisible=e.OSP.NumberInput.active()
    w:pressAt(header.x+header.w/2,header.y+header.h/2);w:releaseAt(header.x+header.w/2,header.y+header.h/2)
    check(not e.OSP.NumberInput.active(),"collapse ends numeric editing")
    if stillVisible then eq(e.OSP.Theme.hex(e.OSP.Theme.colors().back):sub(1,2),"05","collapse applies a visible valid edit")
    else eq(e.OSP.Theme.hex(e.OSP.Theme.colors().back),original,"scrolling the field out of view cancels its draft") end
    w:clickControl("settings_section_palette");w:editControl("palette_R_value");w:tick("5");w:tick("0");w:tick("return")
    local applied=e.OSP.Theme.hex(e.OSP.Theme.colors().back)
    check(applied~=original,"confirmed color applied")
    w:clickControl("settings_section_palette")
    eq(e.OSP.Theme.hex(e.OSP.Theme.colors().back),applied,"collapse preserves confirmed color")
    eq(#w.sent,0,"section interaction never sends gameplay commands")
 end
end
-- New users start with closed sections and real icons, independent of text.
do
    local w=world(1920,1080,{});local e=w.api
    w:tick("p");w:clickControl("tab_settings");local st=w:draw()
    for _,id in ipairs(e.OSP.SettingsSections.ids) do check(not e.OSP.SettingsSections.expanded(id),"first-run collapsed") end
    check(not st.controls.language_en and not st.controls.palette_classic,"first-run bodies hidden")
    eq(#w.images,4,"one graphical icon per Settings heading")
    for _,id in ipairs({"language","shortcut","view_mode","navigation"}) do
        local found=false;for _,value in ipairs(w.texts) do if value==e.OSP.L("settings_help_"..id) then found=true end end
        check(found,"description visible while collapsed: "..id)
    end
    for _,path in ipairs(w.images) do eq(path,"MOD/ui/section-right.png","closed icon") end
    w:clickControl("settings_section_language");w:draw()
    eq(w.images[1],"MOD/ui/section-down.png","expanded icon")
    eq(w.reg["savegame.mod.osp_beta.settings.collapsed.language"],"0","explicit expanded state stored")
    local again=world(1920,1080,w.reg);check(again.api.OSP.SettingsSections.expanded("language"),"expanded choice survives restart")
end
-- Appearance controls are personal, persistent and accessible to guests.
for _,size in ipairs({{640,480},{1024,768},{1920,1080}}) do
 for _,language in ipairs({"en","pt"}) do
    local w=world(unpack(size));local e=w.api
    w.reg["savegame.mod.osp_beta.language"]=language
    e.IsPlayerHost=function() return false end;e.shared.osp.players[1].admin=false
    w:tick("p");w:clickControl("tab_appearance")
    w:clickControl("palette_graphite");eq(e.OSP.Theme.mode(),"graphite")
    check(not w:draw().controls.settings_section_button_style,"disliked button styling removed")
    w:editControl("appearance_opacity_value");w:tick("1");w:tick("return")
    eq(e.OSP.Theme.backgroundOpacity(),65,"opacity clamps below minimum")
    w:clickControl("appearance_opacity_plus");eq(e.OSP.Theme.backgroundOpacity(),66)
    local other=world(size[1],size[2],w.reg)
    eq(other.api.OSP.Theme.backgroundOpacity(),66)
    w:clickControl("palette_restore");eq(e.OSP.Theme.mode(),"classic");eq(e.OSP.Theme.backgroundOpacity(),66,"palette recovery preserves opacity")
    w:clickControl("appearance_restore");eq(e.OSP.Theme.backgroundOpacity(),98)
    eq(#w.sent,0,"personal appearance has no gameplay commands")
    e.OSP.Navigation.setVisible("appearance",false);w:tick();eq(w:draw().tab,"settings","hidden personal page falls back safely")
 end
end
-- Super strength uses the existing movement popup, keeps Fly and Noclip paired,
-- and exposes personal shortcuts only while editing the local player.
for _,size in ipairs({{640,480},{1024,768},{1920,1080}}) do
 for _,language in ipairs({'en','pt'}) do
    local w=world(unpack(size));local e=w.api;w.reg['savegame.mod.osp_beta.language']=language
    w:tick('p');local st=w:draw()
    w:scrollTo('player_action_fly');st=w:draw()
    eq(st.controls.player_action_fly.y,st.controls.player_action_noclip.y,'Fly and Noclip remain on the same row')
    local strength=w:scrollTo('player_action_strength');st=w:draw()
    check(strength~=nil,'Super strength action is present')
    check(table.concat(w.texts,'|'):find(e.OSP.L('strength'),1,true)~=nil,'localized strength label is visible')
    w:clickControl('strength_settings');st=w:draw()
    eq(st.movementPopup.mode,'strength','settings reuse movement popup')
    check(st.controls.player_action_strength and st.controls.player_action_strength.disabled,'the underlying action is blocked while popup is open')
    for _,id in ipairs({'strength_force_value','strength_mass_value','strength_throw_on','strength_throw_off',
        'shortcut_strength','shortcut_clear_strength'}) do
        local r=st.controls[id];check(r~=nil,'strength popup control is visible: '..id)
        check(r.x>=st.layout.ox and r.x+r.w<=st.layout.ox+st.layout.w and r.y>=st.layout.oy and r.y+r.h<=st.layout.oy+st.layout.h,
            'strength popup control fits '..size[1]..'x'..size[2]..': '..id)
    end
    eq(st.controls.strength_throw_speed_value,nil,'throw speed is hidden while throw is off')
    check(table.concat(w.texts,'|'):find('5000',1,true)~=nil,'default maximum mass is shown')
    w:editControl('strength_force_value');w:tick('9');w:tick('9');w:tick('return')
    eq(w.sent[#w.sent].args[2],'strength_force');eq(w.sent[#w.sent].args[3],11);eq(w.sent[#w.sent].args[4],20,'force input clamps to 20')
    eq(w.sent[#w.sent].args[6].targetJoin,1,'numeric setting keeps target join context')
    eq(e.shared.osp.players[1].strength,false,'editing force never activates strength')
    local sent=#w.sent
    local blocked=w:draw().controls.strength_mass_value
    check(blocked.disabled,'pending request disables a second setting')
    w:pressAt(blocked.x+blocked.w/2,blocked.y+blocked.h/2);w:releaseAt(blocked.x+blocked.w/2,blocked.y+blocked.h/2)
    w:tick('1');w:tick('return')
    eq(#w.sent,sent,'pending request blocks a second setting change');w:ack()
    w:editControl('strength_mass_value');w:tick('0');w:tick('return')
    eq(w.sent[#w.sent].args[2],'strength_mass');eq(w.sent[#w.sent].args[4],1,'mass input clamps to 1');w:ack()
    w:clickControl('strength_throw_on');eq(w.sent[#w.sent].args[2],'strength_throw');eq(w.sent[#w.sent].args[4],true)
    eq(e.shared.osp.players[1].strength,false,'throw configuration never activates strength');w:ack()
    e.shared.osp.players[1].strengthThrow=true;st=w:draw()
    check(st.controls.strength_throw_speed_value~=nil,'throw speed appears when throw is enabled')
    for _,id in ipairs({'strength_force_value','strength_mass_value','strength_throw_on','strength_throw_off',
        'strength_throw_speed_value','shortcut_strength','shortcut_clear_strength'}) do
        local r=st.controls[id];check(r~=nil,'throw-enabled popup control is visible: '..id)
        check(r.x>=st.layout.ox and r.x+r.w<=st.layout.ox+st.layout.w and r.y>=st.layout.oy and r.y+r.h<=st.layout.oy+st.layout.h,
            'throw-enabled popup control fits '..size[1]..'x'..size[2]..': '..id)
    end
    w:editControl('strength_throw_speed_value');w:tick('9');w:tick('9');w:tick('9');w:tick('return')
    eq(w.sent[#w.sent].args[2],'strength_throw_speed');eq(w.sent[#w.sent].args[4],100,'throw speed input clamps to 100');w:ack()
    w:clickControl('strength_throw_off');eq(w.sent[#w.sent].args[2],'strength_throw');eq(w.sent[#w.sent].args[4],false,'throw can be disabled');w:ack()
    w:clickControl('shortcut_strength');eq(e.OSP.Shortcuts.capture,'strength','strength shortcut capture is available for self')
    w:tick('f6');eq(e.OSP.Shortcuts.binding('strength'),'f6','strength shortcut is stored locally')
    eq(#w.sent,5,'popup edits and shortcut capture do not issue an activation command')
    w:clickControl('movement_popup_close');st=w:draw()
    local action=st.controls.player_action_strength;local config=st.controls.strength_settings
    check(action and config and action.y==config.y,'strength action and settings stay on the same row')
    local ammo=w:scrollTo('player_action_ammo')
    check(ammo~=nil,'Infinite ammo sits beside or below Super strength')
    if ammo.x>action.x then eq(ammo.y,action.y,'paired abilities share a row')
    else check(ammo.y>=action.y+37,'stacked abilities do not overlap') end
    w:clickControl('player_action_strength')
    local args=w.sent[#w.sent].args;eq(args[2],'strength');eq(args[3],11)
    eq(args[4].expected,false);eq(args[4].value,true,'button sends a guarded state toggle')
    eq(args[6].targetJoin,1,'toggle sends the target challenge');w:ack()
    e.shared.osp.players[1].strength=true
    w:clickControl('strength_settings');w:editControl('strength_mass_value')
    local count=#w.sent;e.shared.osp.players[1].profileChallenge=2;w:tick();st=w:draw()
    eq(st.movementPopup,nil,'popup closes when the target join changes')
    eq(e.OSP.NumberInput.active(),false,'target change cancels an unsent field')
    eq(#w.sent,count,'target change cannot send stale configuration')
 end
end

-- Delegated self scope governs the action, settings and popup fields.
do
    local w=world(1920,1080);local e=w.api;local own=e.shared.osp.players[1]
    e.IsPlayerHost=function() return false end;own.host=false;own.admin=true
    own.permissions=e.OSP.Permissions.resolve('self').permissions;own.profileReady=true
    w:tick('p');local st=w:scrollTo('player_action_strength')
    check(not st.disabled,'self role may use Super strength on self')
    w:clickControl('player_23');st=w:scrollTo('player_action_strength')
    check(st.disabled,'self role cannot target another player with Super strength')
    check(w:scrollTo('strength_settings').disabled,'self role cannot open another player strength settings')
    eq(#w.sent,0,'denied strength controls send nothing')
    w:clickControl('player_11');w:clickControl('strength_settings');st=w:draw()
    check(st.controls.shortcut_strength~=nil,'self popup shows the local binding')
    w:editControl('strength_mass_value');check(e.OSP.NumberInput.active(),'settings field begins editing')
    own.permissions=e.OSP.Permissions.normalize({});w:tick();st=w:draw()
    eq(st.movementPopup,nil,'permission revocation closes strength settings')
    check(not e.OSP.NumberInput.active(),'permission revocation discards field editing')
end

-- Host profile loading keeps strength controls and settings unavailable.
do
    local w=world(1920,1080);local e=w.api
    e.shared.osp.players[1].profileReady=false;w:tick('p')
    local action=w:scrollTo('player_action_strength');local settings=w:scrollTo('strength_settings')
    check(action.disabled and settings.disabled,'strength waits for the host profile')
    eq(#w.sent,0,'profile wait sends no strength change')
end

-- Closing strength settings confirms valid drafts and consumes the outside click.
for _,closeMode in ipairs({'outside','x'}) do
    local w=world(640,480);local e=w.api;w:tick('p');w:clickControl('strength_settings')
    w:editControl('strength_force_value');w:tick('8');local before=#w.sent
    if closeMode=='x' then w:clickControl('movement_popup_close')
    else
        local layout=e.OSP.UI.getState().layout
        w:pressAt(layout.ox+2,layout.oy+2);w:releaseAt(layout.ox+2,layout.oy+2)
    end
    eq(e.OSP.UI.getState().movementPopup,nil,closeMode..' closes strength settings')
    eq(e.OSP.NumberInput.active(),false,closeMode..' ends numeric input')
    eq(#w.sent,before+1,closeMode..' confirms once without clicking through')
    eq(w.sent[#w.sent].args[4],8)
end

-- Strength input reports are heartbeat-only context and stay separate from commands and Fly.
do
    local w=world(1024,768);local e=w.api;local own=e.shared.osp.players[1]
    e.shared.osp.profileHost='test-host';own.strength=true;w.canUseTool=false
    w:tick();eq(#w.strengthReports,1);eq(#w.sent,0)
    local function report() return w.strengthReports[#w.strengthReports].args end
    eq(report()[1],11);eq(report()[2],'test-host');eq(report()[3],1);eq(report()[5],true)
    local sequence=report()[4];w:tick();eq(#w.strengthReports,1,'unchanged context waits for heartbeat')
    w.now=w.now+.21;w:tick();eq(#w.strengthReports,2);check(report()[4]>sequence,'heartbeat sequence increases')
    w:tick('p');eq(report()[5],false,'opening the panel blocks strength input')
    w:tick('p');eq(report()[5],true,'closing the panel restores strength input')
    w:tick('pause');eq(report()[5],false,'pause input blocks strength input')
    w:tick();eq(report()[5],true,'unpaused context renews strength input')
    w.reg['game.paused']=true;w:tick();eq(report()[5],false,'pause state blocks strength input')
    w.reg['game.paused']=false;w:tick();eq(report()[5],true)
    w.reg['game.map.enabled']=true;w:tick();eq(report()[5],false,'map blocks strength input')
    w.reg['game.map.enabled']=false;w:tick();eq(report()[5],true)
    w.reg['game.player.interactive']=false;w:tick();eq(report()[5],false,'other interactive UI blocks strength input')
    w.reg['game.player.interactive']=true;w:tick();eq(report()[5],true)
    w.hp=0;w:tick();eq(report()[5],false,'dead player blocks strength input');w.hp=1;w:tick();eq(report()[5],true)
    w.vehicle=1;w:tick();eq(report()[5],false,'vehicle blocks strength input');w.vehicle=0;w:tick();eq(report()[5],true)
    w.screen=1;w:tick();eq(report()[5],false,'screen blocks strength input');w.screen=0;w:tick();eq(report()[5],true)
    own.profileChallenge=2;w:tick();eq(report()[3],2,'new player join is reported')
    e.shared.osp.profileHost='new-host';w:tick();eq(report()[2],'new-host','new profile host is reported')
    own.strength=false;local count=#w.strengthReports;w.now=w.now+1;w:tick();eq(#w.strengthReports,count,'disabled strength sends no more input')
end

-- Activity names for the new action and every setting remain localized.
for _,language in ipairs({'en','pt'}) do
    local w=world(1024,768);local e=w.api;w.reg['savegame.mod.osp_beta.language']=language
    e.shared.osp.log={{actor='Host',action='strength_force',argument=3,target='',result='ok',affected=1,skipped=0}}
    e.OSP.UI.open(true);w:clickControl('tab_activity')
    check(table.concat(w.texts,'|'):find(e.OSP.L('strength_force_label')..' · 3',1,true)~=nil,'strength setting action is localized in Activity')
end

-- Permission copy exists in both supported languages.
do
    local w=world(1024,768);local e=w.api
    for _,language in ipairs({'en','pt'}) do
        w.reg['savegame.mod.osp_beta.language']=language
        local value=e.OSP.L('permission_strength')
        check(value~=nil and value~='permission_strength','strength permission has a translation')
    end
end
-- Only self toggles use expected/value; the server rejects those for remote targets.
do
    local w=world(1920,1080);local e=w.api
    w:tick('p');w:clickControl('player_23');w:clickControl('player_action_strength')
    eq(w.sent[#w.sent].args[2],'strength');eq(w.sent[#w.sent].args[3],23)
    eq(w.sent[#w.sent].args[4],true,'host uses a boolean when changing another player')
    w:ack();e.shared.osp.players[2].strength=true
    w:clickControl('player_action_strength');eq(w.sent[#w.sent].args[4],false,'remote strength can be disabled')
    w:ack();w:clickControl('strength_settings');w:editControl('strength_force_value')
    w:tick('2');w:tick(',');w:tick('5');w:tick('return')
    eq(w.sent[#w.sent].args[4],2.5,'force accepts fractional intensities');w:ack()
    e.shared.osp.players[2].strengthThrow=true;w:draw();w:editControl('strength_throw_speed_value')
    w:tick('1');w:tick('2');w:tick('.');w:tick('5');w:tick('return')
    eq(w.sent[#w.sent].args[4],12.5,'throw speed accepts fractional values')
end
-- Expanded Permissions draws outside the normal panel and preserves local work.
for _,size in ipairs({{640,480},{1024,768},{1920,1080}}) do
 for _,language in ipairs({'en','pt'}) do
    local w=world(unpack(size));local e=w.api;w.reg['savegame.mod.osp_beta.language']=language
    e.shared.osp.templates=e.OSP.Permissions.list({})
    w:tick('p');w:clickControl('tab_permissions');w:clickControl('role_create_custom')
    w:clickControl('permission_view_expand');local st=w:draw();local b=st.layout.permissionModalBounds
    check(st.permissionExpanded,'Expand opens the larger editor')
    check(b and b.x>=0 and b.y>=0 and b.x+b.w<=size[1] and b.y+b.h<=size[2],'expanded editor fits canvas')
    check(b.w<=1320 and b.h<=900 and b.w<=size[1]*.94 and b.h<=size[2]*.90,'expanded editor respects size limits')
    check(st.controls.close.disabled,'background Close is blocked by expanded editor')
    local before=e.OSP.PermissionUI.getState().draft.name
    w:clickControl('role_editor_name');w:tick('x')
    eq(e.OSP.PermissionUI.getState().draft.name,before..'x','expanded name input uses the same draft')
    w:clickControl('permission_view_search');w:tick('a');w:tick('m');w:tick('m');w:tick('o')
    eq(e.OSP.PermissionUI.getState().query,'ammo','permission search captures independently')
    eq(e.OSP.ToolSearch.query,'','tool search is untouched')
    w:clickControl('permission_view_close')
    check(not w:draw().permissionExpanded,'X closes enlarged editor')
    eq(e.OSP.PermissionUI.getState().draft.name,before..'x','X preserves unsaved draft')
    w:clickControl('permission_view_expand');w:pressAt(1,1);w:releaseAt(1,1)
    check(not w:draw().permissionExpanded,'outside press closes enlarged editor')
    eq(e.OSP.PermissionUI.getState().query,'ammo','outside press preserves query')
    w:clickControl('permission_view_expand');w:tick('esc')
    check(not w:draw().permissionExpanded,'Escape closes enlarged editor without text focus')
    check(e.OSP.UI.getState().open,'Escape leaves the normal panel open')
    w:clickControl('permission_view_expand');w:clickControl('permission_view_search_clear')
    w:clickControl('role_editor_save');check(w:draw().requestPending,'save waits for server ACK')
    w:clickControl('permission_view_search');for c in ('heal'):gmatch('.') do w:tick(c) end
    w:clickControl('permission_group_players')
    local r=w:draw().controls.role_scope_heal_2
    check(r and r.disabled,'pending save blocks permission mutations but allows search/groups')
    local req=w.sent[#w.sent]
    e.client.ospResult(false,'conflict',{},req.args[5])
    check(w:draw().permissionExpanded,'conflict keeps the expanded draft open')
    w:clickControl('role_scope_heal_2');w:clickControl('role_editor_save');req=w.sent[#w.sent]
    local saved=e.OSP.copy(req.args[4]);saved.id='c1';saved.version=1;saved.builtin=false
    e.client.ospResult(true,'ok',{template=saved},req.args[5])
    check(not w:draw().permissionExpanded,'save ACK closes enlarged editor')
    eq(e.OSP.PermissionUI.getState().view,'assign','save ACK returns to role assignment')
    eq(saved.permissions.heal,2,'explicit scope reaches the save request')
 end
end
-- The enlarged list owns wheel input; header/actions remain fixed.
do
    local w=world(640,480);local e=w.api
    w:tick('p');w:clickControl('tab_permissions');w:clickControl('role_create_custom');w:clickControl('permission_view_expand')
    w:clickControl('permission_view_search');for c in ('movement'):gmatch('.') do w:tick(c) end
    w:clickControl('permission_group_movement');local st=w:draw()
    local searchTop=st.controls.permission_view_search.y;local saveTop=st.controls.role_editor_save.y
    local group=st.controls.permission_group_movement
    w.mouse={x=group.x+20,y=group.y+90};w:tick(nil,-2);st=w:draw()
    local offset=e.OSP.PermissionUI.getState().scroll
    check(offset>0,'wheel scrolls inside the enlarged list')
    eq(st.controls.permission_view_search.y,searchTop,'search remains fixed while list scrolls')
    eq(st.controls.role_editor_save.y,saveTop,'actions remain fixed while list scrolls')
    w:draw();eq(e.OSP.PermissionUI.getState().scroll,offset,'a second draw does not repeat the wheel event')
    w.mouse={x=st.controls.permission_view_search.x+5,y=searchTop+5};w:tick(nil,-2);w:draw()
    eq(e.OSP.PermissionUI.getState().scroll,offset,'wheel outside list does not scroll it')
    e.OSP.UI.selectTab('settings');check(not e.OSP.PermissionUI.isExpanded(),'leaving Permissions closes enlarged view')
    check(e.OSP.PermissionUI.getState().draft~=nil,'context exit retains unsaved draft')
end
-- Deletion confirmation is above the expanded editor and blocks its controls.
do
    local w=world(1024,768);local e=w.api
    local role={id='c1',name='Custom',builtin=false,version=1,permissions=e.OSP.Permissions.normalize({heal=1})}
    e.shared.osp.templates=e.OSP.Permissions.list({c1=role})
    w:tick('p');w:clickControl('tab_permissions')
    w:chooseRole('c1')
    w:clickControl('permission_view_expand');w:clickControl('role_edit_custom');w:clickControl('role_editor_delete')
    local st=w:draw();check(st.permissionExpanded and st.confirm,'delete keeps editor behind confirmation')
    check(st.controls.permission_view_close.disabled,'confirmation blocks expanded X')
    check(st.controls.role_editor_save.disabled,'confirmation blocks Save')
    w:clickControl('confirm_cancel');check(w:draw().permissionExpanded,'cancel returns to expanded draft')
    w:clickControl('role_editor_delete');w:clickControl('confirm_accept')
    local req=w.sent[#w.sent];eq(req.args[2],'role_delete')
    e.client.ospResult(true,'ok',{deleted='c1'},req.args[5])
    check(not w:draw().permissionExpanded,'delete ACK closes enlarged editor')
end
-- Role dropdowns keep all entries reachable and consume outside/keyboard input.
for _,size in ipairs({{640,480},{1024,768},{1920,1080}}) do
 for _,expanded in ipairs({false,true}) do
    local w=world(unpack(size));local e=w.api;local custom={}
    for n=1,16 do custom['c'..n]={id='c'..n,name='Custom role '..n,builtin=false,version=1,permissions=e.OSP.Permissions.normalize({heal=1})} end
    e.shared.osp.templates=e.OSP.Permissions.list(custom)
    w:tick('p');w:clickControl('tab_permissions')
    if expanded then w:clickControl('permission_view_expand') end
    w:chooseRole('c16');eq(e.OSP.PermissionUI.getState().selected,'c16','dropdown reaches roles beyond first screen')
    eq(#w.sent,0,'selecting a role does not assign or modify it')
    w:clickControl('permission_view_role_select');local st=w:draw();local b=st.roleDropdown.bounds
    local l=expanded and st.layout.permissionModalBounds or {x=st.layout.ox,y=st.layout.oy,w=st.layout.w,h=st.layout.h}
    check(b.x>=l.x and b.y>=l.y and b.x+b.w<=l.x+l.w and b.y+b.h<=l.y+l.h,'dropdown fits enclosing window')
    w:pressAt(1,1);w:releaseAt(1,1);st=w:draw()
    eq(st.roleDropdown,nil,'outside click dismisses dropdown');eq(st.permissionExpanded,expanded,'outside click closes only the dropdown layer')
    w:clickControl('permission_view_role_select');w:tick('esc');st=w:draw()
    eq(st.roleDropdown,nil,'Escape dismisses dropdown');eq(st.permissionExpanded,expanded,'Escape leaves containing view open')
    w:clickControl('permission_view_role_select');w:tick('uparrow');w:tick('return');w:draw()
    check(e.OSP.PermissionUI.getState().selected~='c16','keyboard selection updates role')
    eq(#w.sent,0,'dropdown keyboard input has no gameplay RPC')
 end
end
-- Independent delete authority is reachable without edit/create authority.
do
    local w=world(1024,768);local e=w.api
    e.IsPlayerHost=function() return false end
    local own=e.shared.osp.players[1];own.host=false;own.admin=true
    own.permissions=e.OSP.Permissions.normalize({role_delete=2,heal=1})
    e.shared.osp.templates=e.OSP.Permissions.list({c1={id='c1',name='Weak',version=1,builtin=false,permissions=e.OSP.Permissions.normalize({heal=1})}})
    w:tick('p');w:clickControl('tab_permissions');w:chooseRole('c1')
    check(w:scrollTo('role_edit_custom').disabled,'delete-only role cannot edit')
    check(w:scrollTo('role_create_custom').disabled,'delete-only role cannot create')
    w:clickControl('role_delete');w:clickControl('confirm_accept')
    eq(w.sent[#w.sent].args[2],'role_delete','delete is available directly from preview');w:ack(false,'conflict')
    w:clickControl('permission_view_role_select');own.permissions={};w:tick()
    check(not w:draw().roleDropdown,'revoking management closes its dropdown')
    check(e.OSP.UI.getState().tab~='permissions','revoking management leaves Permissions')
end
-- Delegated role management crosses the real UI/server boundary.
do
    local factory=assert(loadfile('tests/test_server.lua'))
    setfenv(factory,setmetatable({arg={arg[1],'fixture'}},{__index=_G}))
    local backend=factory()()
    local ok,_,details=backend.command(11,'role_save',0,{id='',name='Delegate',version=0,
        permissions={role_assign=2,role_create=2,role_edit=2,role_delete=2,heal=1}})
    check(ok);backend.command(11,'role_assign',23,{id=details.template.id})
    local w=world(1024,768);local e=w.api;e.GetLocalPlayer=function() return 23 end
    e.IsPlayerHost=backend.api.IsPlayerHost;e.shared=backend.api.shared;e.client.init()
    backend.api.ClientCall=function(actor,fn,...) if actor==23 and fn=='client.ospResult' then e.client.ospResult(...) end end
    e.ServerCall=function(fn,...)
        if fn=='server.ospCommand' then
            local a={...};w.sent[#w.sent+1]={fn=fn,args=a};backend.now=backend.now+.1;backend.api.server.ospCommand(unpack(a))
        end
    end
    w:tick('p');w:clickControl('player_47');w:clickControl('player_role_manage')
    eq(w:draw().tab,'permissions','Manage role opens Permissions for selected player')
    eq(e.OSP.PermissionUI.getState().selected,'guest','Manage role selects the current target role')
    w:clickControl('permission_view_expand');w:clickControl('role_create_custom')
    w:clickControl('permission_group_players');w:clickControl('role_scope_heal_1')
    check(w:draw().controls.role_scope_heal_2.disabled,'UI blocks a scope above delegate authority')
    w:clickControl('role_editor_save');w:draw()
    eq(e.OSP.UI.getState().requestPending,false,'synchronous create ACK finishes pending state')
    check(not e.OSP.PermissionUI.isExpanded(),'create ACK closes enlarged editor')
    local created=e.OSP.PermissionUI.getState().selected
    check(created:match('^c%d+$')~=nil)
    w:clickControl('role_apply');w:clickControl('confirm_accept')
    local target
    for _,p in ipairs(e.shared.osp.players) do if p.id==47 then target=p end end
    eq(target.role,created,'UI assignment is accepted for delegate')
    eq(target.permissions.heal,1,'assigned permissions match the saved draft')
    eq(backend.api.GetString('savegame.mod.osp_beta.players.'..backend.identities[47]..'.role'),created,'UI assignment is persisted')
end
-- Ammo has a separate restoration preference and personal shortcut.
for _,size in ipairs({{640,480},{1024,768},{1920,1080}}) do
 for _,language in ipairs({'en','pt'}) do
    local w=world(unpack(size));local e=w.api;w.reg['savegame.mod.osp_beta.language']=language
    w:tick('p');w:clickControl('ammo_settings');local st=w:draw()
    eq(st.movementPopup.mode,'ammo');eq(#w.sent,0,'opening ammo settings does not enable the ability')
    for _,id in ipairs({'ammo_restore_on','ammo_restore_off','shortcut_ammo','shortcut_clear_ammo'}) do
        local r=st.controls[id];check(r~=nil,'ammo popup control exists: '..id)
        check(r.x>=st.layout.ox and r.x+r.w<=st.layout.ox+st.layout.w and r.y>=st.layout.oy and r.y+r.h<=st.layout.oy+st.layout.h,'ammo control fits canvas: '..id)
    end
    w:clickControl('ammo_restore_off');local a=w.sent[#w.sent].args
    eq(a[2],'ammo_restore');eq(a[3],11);eq(a[4],false);eq(a[6].targetJoin,1)
    check(w:draw().controls.ammo_restore_on.disabled,'pending ammo preference cannot be sent twice')
    w:ack();e.shared.osp.players[1].ammoRestore=false
    w:clickControl('shortcut_ammo');w:tick('f12')
    eq(e.OSP.Shortcuts.binding('ammo'),'f12');eq(#w.sent,1,'binding does not activate ammo')
    w:clickControl('movement_popup_close');w:clickControl('player_action_ammo');a=w.sent[#w.sent].args
    eq(a[2],'ammo');eq(a[4].expected,false);eq(a[4].value,true);w:ack()
    e.shared.osp.players[1].ammo=true;e.shared.osp.players[1].profileReady=true
    w:tick('p');w:tick('f12');a=w.sent[#w.sent].args
    eq(a[2],'ammo');eq(a[3],11);eq(a[4].expected,true);eq(a[4].value,false);w:ack()
    w:tick('p');w:clickControl('player_23');w:clickControl('ammo_settings');st=w:draw()
    eq(st.controls.shortcut_ammo,nil,'another player never shows the host shortcut')
    w:clickControl('movement_popup_close');w:clickControl('player_action_ammo');a=w.sent[#w.sent].args
    eq(a[2],'ammo');eq(a[3],23);eq(a[4],true,'host remote toggle uses boolean');w:ack()
 end
end
do
    local w=world(1920,1080);local e=w.api
    e.IsPlayerHost=function() return false end
    e.shared.osp.players[1].host=false;e.shared.osp.players[1].permissions=e.OSP.Permissions.resolve('self').permissions
    w:tick('p');w:clickControl('ammo_settings')
    check(w:draw().controls.shortcut_ammo~=nil,'self role can configure own ammo')
    e.shared.osp.players[1].permissions={};w:tick()
    eq(w:draw().movementPopup,nil,'losing ammo permission closes its settings')
    e.shared.osp.players[1].permissions=e.OSP.Permissions.resolve('self').permissions
    w:clickControl('player_23')
    check(w:scrollTo('player_action_ammo').disabled,'self scope cannot change others ammo')
    check(w:scrollTo('ammo_settings').disabled,'self scope cannot configure others ammo')
    eq(#w.sent,0,'denied actions do not reach the server')
end
-- Numeric gestures cross the real UI/server boundary, including synchronous replies.
do
    local factory=assert(loadfile('tests/test_server.lua'))
    setfenv(factory,setmetatable({arg={arg[1],'fixture'}},{__index=_G}))
    local backend=factory()()
    local w=world(1920,1080);local e=w.api
    e.shared=backend.api.shared
    local replies={}
    backend.api.ClientCall=function(actor,fn,...)
        if actor==11 and fn=='client.ospResult' then
            replies[#replies+1]={...};e.client.ospResult(...)
        end
    end
    e.ServerCall=function(fn,...)
        if fn=='server.ospCommand' then
            local args={...};w.sent[#w.sent+1]={fn=fn,args=args}
            backend.now=backend.now+.1
            backend.api.server.ospCommand(unpack(args))
        end
    end
    local function speed()
        for _,p in ipairs(e.shared.osp.players) do if p.id==23 then return p.speed end end
    end
    e.OSP.UI.open(true);w:clickControl('player_23');w:editControl('player_speed_value')
    for c in ('2.25'):gmatch('.') do w:tick(c) end
    w:tick('return')
    eq(speed(),2.25,'typed UI payload is accepted by the real server')
    check(replies[#replies][1],'server acknowledges numeric edit')
    eq(e.OSP.UI.getState().requestPending,false,'synchronous numeric reply completes the pending request')

    w:editControl('player_speed_value');w:tick('2');w:tick('.');w:tick('5')
    local before=#w.sent
    w:clickControl('speed_up')
    eq(#w.sent,before+1,'blur and another action never send two commands even with synchronous ACK')
    eq(speed(),2.5,'outside click applies the typed value before another command')

    local r=w:scrollTo('player_speed_value');before=#w.sent
    w:pressAt(r.x+5,r.y+r.h/2);w:holdAt(r.x+r.w-2,r.y+r.h/2)
    eq(#w.sent,before,'slider sends no intermediate RPC')
    w:releaseAt(r.x+r.w+50,r.y+r.h/2)
    eq(#w.sent,before+1,'slider release sends one RPC')
    eq(speed(),3,'slider final value reaches the server and respects bounds')
    check(replies[#replies][1],'server accepts the slider value')

    -- The actual ammo payload and ACK cross the same UI/server boundary.
    backend.players[23].ammo.gun=37
    w:clickControl('player_action_ammo')
    check(replies[#replies][1],'server accepts UI ammo toggle')
    backend.tick();eq(backend.players[23].ammo.gun,9999,'server refills after UI activation')
    w:clickControl('ammo_settings');w:clickControl('ammo_restore_off')
    check(replies[#replies][1],'server accepts UI restoration preference')
    w:clickControl('movement_popup_close');w:clickControl('player_action_ammo')
    eq(backend.players[23].ammo.gun,9999,'UI preference leaves supplied stock after disabling')
    w:clickControl('ammo_settings');w:clickControl('ammo_restore_on');w:clickControl('movement_popup_close')
    backend.players[23].ammo.gun=41
    w:clickControl('player_action_ammo');backend.tick()
    eq(backend.players[23].ammo.gun,9999)
    w:clickControl('player_action_ammo');eq(backend.players[23].ammo.gun,41,'UI disable restores captured stock')

    r=w:scrollTo('player_speed_value');before=#w.sent
    w:pressAt(r.x+5,r.y+r.h/2)
    backend.players[23]=nil;backend.tick()
    w:holdAt(r.x+r.w-2,r.y+r.h/2);w:releaseAt(r.x+r.w-2,r.y+r.h/2)
    eq(#w.sent,before,'target leaving cancels the drag without affecting a replacement selection')
    eq(e.OSP.NumberInput.active(),false,'obsolete numeric interaction is gone')
end
print('PASS client interaction, viewport and translation contracts: '..assertions..' assertions (mock UI)')
