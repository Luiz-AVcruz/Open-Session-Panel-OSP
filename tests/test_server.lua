-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Stateful engine boundary: immediate values expire, persistent flags survive
-- respawn only when reapplied, player IDs can be reused, registry survives maps.
local count=0
local function check(v,message) assert(v,message); count=count+1 end
local function eq(a,b,message) check(a==b,(message or "equality")..": "..tostring(a).." ~= "..tostring(b)) end
local registry={}
local function world(options)
    options=options or {}
    local w={catalog=options.catalog or {'sledge','gun'},now=0,players={},calls={},removed={},time=1,restarted=false,identities={},
        env={rain=0.15,fogparams={80,300,0.8,2}}}
    for _,id in ipairs({11,23,47}) do
        w.players[id]={id=id,name="Player "..id,health=1,host=id==11,
            params={godMode=options.baseGod==true,flyMode=false,healthRegeneration=true},speed=7,
            tools={sledge=true,gun=true},tool="gun",vehicle=99,position={pos={0,0,0},rot={0,0,0,1}},velocity={0,0,0}}
    end
    local env={server={},shared={},math=math,table=table,string=string,type=type,pairs=pairs,
        ipairs=ipairs,unpack=unpack,tostring=tostring,pcall=pcall,assert=assert,tonumber=tonumber,
        select=select,next=next}
    env.GetAllPlayers=function() local r={} for id in pairs(w.players) do r[#r+1]=id end table.sort(r); return r end
    env.GetRemovedPlayers=function() return w.removed end
    env.IsPlayerValid=function(p) return w.players[p]~=nil end
    env.IsPlayerHost=function(p) return w.players[p].host end
    env.GetPlayerName=function(p) return w.players[p].name end
    env.GetPlayerHealth=function(p) return w.players[p].health end
    env.GetPlayerWalkingSpeed=function(p) return w.players[p].speed end
    env.SetPlayerWalkingSpeed=function(v,p) w.players[p].speed=v end
    env.GetPlayerParam=function(k,p) return w.players[p].params[k] end
    env.SetPlayerParam=function(k,v,p) w.players[p].params[k]=v; if k=="walkingSpeed" then w.players[p].speed=v end end
    env.SetPlayerRegenerationState=function(v,p) w.players[p].params.healthRegeneration=v end
    env.SetPlayerHealth=function(v,p)
        assert(v>=0 and v<=1); w.players[p].health=v
    end
    env.RespawnPlayer=function(p)
        local q=w.players[p]; q.health=1; q.params.godMode=false;q.params.flyMode=false;q.speed=7
        q.tools={sledge=true,gun=true}; q.tool="gun"
    end
    env.GetPlayerTool=function(p) return w.players[p].tool end
    env.IsToolEnabled=function(id,p) return w.players[p].tools[id] or false end
    env.SetToolEnabled=function(id,on,p) local found=false;for _,tool in ipairs(w.catalog) do if tool==id then found=true end end;assert(found,'unregistered tool '..id);w.players[p].tools[id]=on end
    env.SetPlayerTool=function(id,p) assert(id=='' or w.players[p].tools[id]); w.players[p].tool=id end
    env.GetPlayerVehicle=function(p) return w.players[p].vehicle end
    env.SetPlayerVehicle=function(v,p) w.players[p].vehicle=v end
    env.GetPlayerTransform=function(p) return env.OSP.copy(w.players[p].position) end
    env.SetPlayerTransform=function(t,p) w.players[p].position=env.OSP.copy(t) end
    env.GetPlayerCameraTransform=env.GetPlayerTransform
    env.Vec=function(x,y,z) return {x or 0,y or 0,z or 0} end
    env.VecAdd=function(a,b) return {a[1]+b[1],a[2]+b[2],a[3]+b[3]} end
    env.VecScale=function(a,s) return {a[1]*s,a[2]*s,a[3]*s} end
    env.VecLength=function(a) return math.sqrt(a[1]^2+a[2]^2+a[3]^2) end
    env.Transform=function(pos,rot) return {pos=pos,rot=rot} end
    env.TransformToParentVec=function(_,v) return v end
    env.TransformToParentPoint=function(t,v) return env.VecAdd(t.pos,v) end
    env.SetPlayerVelocity=function(v,p) w.players[p].velocity=v end
    env.DisablePlayerInput=function(p) w.players[p].disabled=true end
    env.InputDown=function(k,p) return w.players[p].inputs and w.players[p].inputs[k] or false end
    env.GetEnvironmentProperty=function(k)
        local v=w.env[k]; if type(v)=='table' then return unpack(v) else return v end
    end
    env.SetEnvironmentProperty=function(k,...) local v={...}; w.env[k]=#v==1 and v[1] or v end
    env.SetTimeScale=function(v) assert(v>=0 and v<=2);w.time=v end
    env.ListKeys=function(k)
        if k=='game.tool' then return env.OSP and env.OSP.copy(w.catalog) or w.catalog end
        local result,seen={},{}
        for key in pairs(registry) do
            if key:sub(1,#k+1)==k..'.' then
                local child=key:sub(#k+2):match('^[^.]+')
                if not seen[child] then result[#result+1]=child;seen[child]=true end
            end
        end
        return result
    end
    env.GetString=function(k) return registry[k] or '' end
    env.SetString=function(k,v) assert(k:sub(1,17)=="savegame.mod.osp.");registry[k]=v end
    local randomValue=100
    env.GetRandomInt=function() randomValue=randomValue+1;return randomValue end
    env.HasKey=function(k)
        if k:sub(1,10)=='game.tool.' then
            for _,id in ipairs(w.catalog) do if k=='game.tool.'..id then return true end end
            return false
        end
        if registry[k]~=nil then return true end
        for key in pairs(registry) do if key:sub(1,#k+1)==k..'.' then return true end end
        return false
    end
    env.GetInt=function(k) return registry[k] or 0 end
    env.SetInt=function(k,v) assert(k:sub(1,17)=="savegame.mod.osp.","writes must stay in mod namespace");registry[k]=v end
    env.GetFloat=function(k) return registry[k] or 0 end
    env.GetBool=function(k) return registry[k] or false end
    env.SetFloat=function(k,v) assert(k:sub(1,17)=="savegame.mod.osp.","writes must stay in mod namespace");registry[k]=v end
    env.SetBool=env.SetFloat
    env.ClearKey=function(k)
        for key in pairs(registry) do if key==k or key:sub(1,#k+1)==k..'.' then registry[key]=nil end end
    end
    env.GetTime=function() return w.now end
    env.Restart=function() w.restarted=true end
    env.ClientCall=function(p,fn,...) w.calls[#w.calls+1]={p=p,fn=fn,args={...}} end
    env.DebugPrint=function(s) error('Unexpected engine failure: '..s) end
    local chunk=assert(loadfile(arg[1])); setfenv(chunk,env);chunk();env.server.init()
    w.api=env
    function w.identify(p,id)
        w.now=w.now+.21;env.server.tick()
        local challenge
        for _,entry in ipairs(env.shared.osp.players) do if entry.id==p then challenge=entry.profileChallenge end end
        env.server.ospIdentify(p,env.shared.osp.profileHost,challenge,id or '')
        local reply=w.calls[#w.calls]
        assert(reply.fn=='client.ospIdentity')
        w.identities[p]=reply.args[3]
        return reply.args[3]
    end
    if not options.unidentified then
        for _,p in ipairs({23,47}) do w.identify(p,options.identities and options.identities[p]) end
    end
    function w.command(actor,action,target,value)
        for _,p in ipairs(env.shared.osp.players) do if not p.profileReady then w.identify(p.id) end end
        w.now=w.now+0.1
        env.server.ospCommand(actor,action,target,value)
        local c=w.calls[#w.calls]
        assert(c.fn=='client.ospResult')
        return c.args[1],c.args[2],c.args[3]
    end
    function w.tick()
        w.now=w.now+0.25
        for _,p in pairs(w.players) do p.speed=7;p.disabled=false end
        w.time=1 -- SetTimeScale affects only the following frame
        env.server.tick(0.25)
        w.removed={}
    end
    return w
end
local w=world()
local ok,code=w.command(23,'kill',11)
eq(ok,false);eq(code,'denied');eq(w.players[11].health,1)
eq(w.command(11,'admin',23,true),true)
ok,code=w.command(23,'admin',47,true);eq(ok,false);eq(code,'denied')
ok,code=w.command(11,'admin',11,false);eq(ok,false);eq(code,'protected')
for _,action in ipairs({'kill','heal','bring','eject','respawn'}) do
    ok,code=w.command(23,action,11);eq(ok,false,action);eq(code,'protected')
end
eq(w.command(23,'goto',11),true)
ok,code=w.command(23,'speed',47,0/0);eq(ok,false);eq(code,'invalid')
ok,code=w.command(23,'speed',47,math.huge);eq(ok,false);eq(code,'invalid')
ok,code=w.command(23,'rule',0,{key='rain',value=2});eq(ok,false);eq(code,'invalid')
ok,code=w.command(23,'rule',0,{key='arbitrary.property',value=1});eq(ok,false)
ok,code=w.command(23,'tool',47,{id='missing',enabled=true});eq(ok,false)
ok,code=w.command(23,'god',47,1);eq(ok,false)
ok,code=w.command(23,'heal',999);eq(ok,false);eq(code,'unavailable')
ok,code=w.command(23,'_G.os.execute',0);eq(ok,false);eq(code,'invalid')
-- Bulk protection is enforced on every recipient, including tool commands.
w.players[11].health=.2;w.players[47].health=.3
ok,code,details=w.command(23,'heal_all',0);eq(ok,true);eq(details.skipped,1);eq(w.players[11].health,.2);eq(w.players[47].health,1)
w.command(23,'tools_all',0,false);eq(w.players[11].tools.gun,true);eq(w.players[47].tools.gun,false);eq(w.players[47].tool,'')
w.command(11,'tools',47,true);eq(w.players[47].tools.gun,true)
-- Tool pickup/respawn cannot silently lift a session restriction.
w.command(11,'tool',47,{id='gun',enabled=false});w.api.RespawnPlayer(47);w.tick();eq(w.players[47].tools.gun,false);eq(w.players[47].tool,'sledge')
-- Restrictions must apply between 5 Hz catalog/replication refreshes too.
w.players[47].tools.gun=true;w.now=w.now+1/60;w.api.server.tick(1/60)
eq(w.players[47].tools.gun,false,'no 200 ms pickup window')
-- Effects are immediate/frame based; movement stops only while frozen.
w.command(11,'god',47,true);w.command(11,'fly',47,true);w.command(11,'speed',47,2)
w.players[47].inputs={up=true,jump=true};w.tick();check(w.players[47].velocity[3]<0,'fly logical forward');check(w.players[47].velocity[2]>0,'fly logical jump');eq(w.players[47].speed,14)
w.command(11,'freeze',47,true);w.tick();eq(w.players[47].disabled,true);eq(w.players[47].velocity[3],0)
w.command(11,'freeze',47,false);w.tick();eq(w.players[47].disabled,false)
w.command(11,'kill',47);w.tick();w.command(11,'respawn',47);w.tick();eq(w.players[47].params.godMode,true);eq(w.players[47].params.flyMode,true);eq(w.players[47].speed,14)
w.command(11,'speed',47,1);w.tick();eq(w.players[47].speed,7)
-- Revocation checked at invocation, including requests queued by transport.
w.command(11,'admin',23,false);ok,code=w.command(23,'kill',47);eq(ok,false);eq(code,'denied')
-- Same player id must not inherit roles/effects after leaving.
w.command(11,'admin',47,true)
local replacement=w.players[47];w.players[47]=nil;w.removed={47};w.tick()
replacement.params.godMode=false;replacement.params.flyMode=false;replacement.speed=7
w.players[47]=replacement;w.tick();eq(w.api.shared.osp.players[3].admin,false);eq(w.api.shared.osp.players[3].god,false)
-- The removal list is constant during a frame (not a consumable queue).
w.removed={47};w.now=w.now+1
w.identify(47)
w.api.server.ospCommand(11,'admin',47,true)
w.api.server.ospCommand(47,'heal',47)
eq(w.calls[#w.calls].args[1],true,'same-frame removal processed once')
w.removed={}
-- Late join and persistence across a new Lua context/map.
w.command(11,'rule',0,{key='rain',value=.8});w.command(11,'rule',0,{key='fog',value=20});check(w.env.fogparams[1]<20,'fog start below end');eq(w.env.fogparams[3],.8)
w.command(11,'rule',0,{key='time',value=.4});w.command(11,'rule',0,{key='regen',value=false});w.tick();eq(w.time,.4);eq(w.players[47].params.healthRegeneration,false)
local w2=world();eq(w2.env.rain,.8);eq(w2.api.shared.osp.rules.regen,false);eq(w2.api.shared.osp.players[2].admin,false)
w2.command(11,'reset_rules',0);eq(w2.env.rain,.15);eq(w2.env.fogparams[1],80);eq(w2.env.fogparams[2],300);eq(w2.players[23].params.healthRegeneration,true)
eq(w2.api.HasKey('savegame.mod.osp.rules'),false,'reset rules preserves unrelated saved profiles')
w2.tick();eq(w2.time,1)
-- Dead teleport destinations cannot report a successful move.
w2.players[23].health=0
ok,code=w2.command(11,'goto',23);eq(ok,false);eq(code,'unavailable')
ok,code,details=w2.command(11,'bring_all',0);eq(ok,true);eq(details.affected,1);eq(details.skipped,2)
w2.players[11].health=0;ok,code=w2.command(11,'bring_all',0);eq(ok,false);eq(code,'unavailable');w2.players[11].health=1
-- Specific tool bulk operations and host-only restart.
w2.command(11,'admin',23,true)
w2.command(23,'tool_all',0,{id='sledge',enabled=false})
eq(w2.players[11].tools.sledge,true);eq(w2.players[47].tools.sledge,false)
ok,code=w2.command(23,'restart',0);eq(ok,false);eq(w2.restarted,false)
eq(w2.command(11,'restart',0),true);eq(w2.restarted,true)
-- Replies carry the exact request ID; sending a request is not completion.
w2.now=w2.now+1;w2.api.server.ospCommand(11,'heal',47,nil,1234)
eq(w2.calls[#w2.calls].args[4],1234)
w2.now=w2.now+1;w2.api.server.ospCommand(23,'restart',0,nil,1235)
eq(w2.calls[#w2.calls].args[4],1235);eq(w2.calls[#w2.calls].args[1],false)
-- Text validation and bounded log.
ok,code=w2.command(11,'announce',0,'hello\nworld');eq(ok,false)
ok,code=w2.command(11,'announce',0,string.rep('a',241));eq(ok,false)
eq(w2.command(11,'announce',0,'Hello players'),true)
for i=1,110 do w2.command(11,'heal',47) end
eq(#w2.api.shared.osp.log,100);check(w2.api.shared.osp.log[1].seq<w2.api.shared.osp.log[100].seq,'ordered log')
eq(w2.api.OSP.validKey('w'),false);eq(w2.api.OSP.validKey('f8'),true);eq(w2.api.OSP.validKey('mousewheel'),false)
-- Host policies survive a new mission, not a player's recycled runtime ID.
local pworld=world({catalog={'sledge','gun','modlaser'}})
pworld.command(11,'admin',23,true)
ok,code=pworld.command(23,'tool_policy',0,{id='gun',mode='disabled'})
eq(ok,false);eq(code,'denied')
ok,code=pworld.command(11,'tool_policy',0,{id='gun',mode='wat'});eq(ok,false)
ok,code=pworld.command(11,'tool_policy_bulk',0,{category='any',mode='disabled'});eq(ok,false)
eq(pworld.command(11,'tool_policy',0,{id='gun',mode='disabled'}),true)
eq(pworld.players[11].tools.gun,false,'global includes host')
eq(pworld.players[47].tools.gun,false)
ok,code=pworld.command(11,'tool',47,{id='gun',enabled=true});eq(ok,false);eq(code,'protected')
pworld.command(23,'tools',47,true);eq(pworld.players[47].tools.gun,false,'bulk cannot lift host block')
pworld.api.RespawnPlayer(47);pworld.tick();eq(pworld.players[47].tools.gun,false)
pworld.command(11,'tool_policy',0,{id='modlaser',mode='disabled'})
local mission=world({catalog={'sledge','gun'}})
eq(mission.players[11].tools.gun,false,'persist across maps')
local newcomer=mission.api.OSP.copy(mission.players[23]);newcomer.id=99;newcomer.tools.gun=true
mission.players[99]=newcomer;mission.tick();eq(mission.players[99].tools.gun,false,'late join')
mission.catalog[#mission.catalog+1]='modlaser';mission.players[11].tools.modlaser=true
mission.players[11].tool='modlaser';mission.now=mission.now+1/60;mission.api.server.tick(1/60)
eq(mission.players[11].tools.modlaser,false,'late registration between catalog refreshes')
check(mission.players[11].tool~='modlaser','late registered blocked tool deselected immediately')
mission.tick()
eq(mission.players[11].tools.modlaser,false,'late registration restores absent policy')
local rows=mission.api.shared.osp.tools
for _,t in ipairs(rows) do
 eq(t.origin,t.id=='modlaser' and 'mod' or 'vanilla')
end
mission.command(11,'tool_policy_bulk',0,{category='vanilla',mode='enabled'})
eq(mission.players[11].tools.gun,true);eq(mission.players[11].tools.modlaser,false,'filtered policy preserves hidden category')
mission.command(11,'tool_policy',0,{id='gun',mode='default'})
eq(mission.players[11].tools.gun,true,'restore pre-intervention native state')
mission.command(11,'tool',47,{id='sledge',enabled=false})
mission.command(11,'tool_policy',0,{id='sledge',mode='enabled'})
eq(mission.players[47].tools.sledge,true,'new global policy clears personal override')
mission.command(11,'tool',47,{id='sledge',enabled=false})
mission.tick();eq(mission.players[47].tools.sledge,false,'personal restriction on global enabled remains')
local nextMap=world({catalog={'sledge','gun','modlaser'}})
eq(nextMap.players[47].tools.sledge,true,'a new identity at the same ID does not inherit a saved restriction')
nextMap.command(11,'tools_filtered',47,{category='vanilla',enabled=false})
eq(nextMap.players[47].tools.sledge,false)
ok,code,details=nextMap.command(11,'tools_filtered',47,{category='mod',enabled=true})
eq(details.affected,0,'blocked category affects nobody');eq(details.skipped,1)
eq(nextMap.api.IsToolEnabled('modlaser',47),false,'filtered cannot lift global block')
nextMap.command(11,'tool_policy_bulk',0,{category='all',mode='default'})
local fresh=world();eq(fresh.api.shared.osp.toolPolicies.gun,nil)
eq(fresh.players[11].tools.gun,true,'reset policies releases next mission defaults')
ok,code,details=fresh.command(11,'tools_filtered',47,{category='mod',enabled=true})
eq(details.affected,0,'empty category affects nobody');eq(details.skipped,1)
fresh.command(11,'tool_policy_bulk',0,{category='all',mode='disabled'})
ok,code,details=fresh.command(11,'tools',47,true);eq(details.affected,0);eq(details.skipped,1)
eq(fresh.api.OSP.toolOrigin('camera'),'vanilla');eq(fresh.api.OSP.toolOrigin('snowball'),'vanilla')
eq(fresh.api.OSP.toolOrigin('minigunmall'),'vanilla');eq(fresh.api.OSP.toolOrigin('modlaser'),'mod')
registry={}
local offworld=world({catalog={'sledge','gun','modlaser'}})
offworld.command(11,'tool_policy',0,{id='modlaser',mode='enabled'})
eq(offworld.players[11].tools.modlaser,true)
offworld.command(11,'tool_policy',0,{id='modlaser',mode='default'})
eq(offworld.api.IsToolEnabled('modlaser',11),false,'false baseline is restored, not mistaken for absent')
-- Host-owned profiles follow a mod-issued identity across maps and runtime IDs.
registry={}
local saved=world({catalog={'sledge','gun','modlaser'}})
local identity=saved.identities[23]
local previousJoin=saved.api.shared.osp.players[2].profileChallenge
for _,effect in ipairs({'god','fly','freeze','admin'}) do eq(saved.command(11,effect,23,true),true) end
saved.command(11,'speed',23,2.25)
saved.players[23].tools.modlaser=true
saved.command(11,'tools_filtered',23,{category='mod',enabled=false})
eq(saved.players[23].tools.gun,true,'mod block preserves vanilla')
saved.command(11,'tool',23,{id='gun',enabled=false})
saved.command(11,'god',11,true)
local restored=world({catalog={'sledge','gun','modlaser'},identities={[47]=identity}})
restored.tick()
eq(restored.players[47].params.godMode,true,'god follows identity, not name or runtime ID')
eq(restored.players[47].params.flyMode,true);eq(restored.players[47].disabled,true)
eq(restored.players[47].speed,15.75);eq(restored.api.shared.osp.players[3].admin,true)
eq(restored.players[47].tools.gun,false);eq(restored.api.IsToolEnabled('modlaser',47),false)
eq(restored.api.shared.osp.players[2].admin,false,'different identity at old ID receives no role')
eq(restored.players[23].params.godMode,false,'old ID receives no effects')
eq(restored.players[11].params.godMode,true,'host profile persists too')
local loading=world({unidentified=true})
local beforeStale=#loading.calls
loading.api.server.ospIdentify(23,loading.api.shared.osp.profileHost,previousJoin,identity)
eq(#loading.calls,beforeStale,'old mission identity request is ignored')
eq(loading.api.shared.osp.players[2].profileReady,false,'stale request cannot bind a saved role')
loading.identify(23,identity)
eq(loading.api.shared.osp.players[2].admin,true,'current join can restore the profile')
local clone=restored.api.OSP.copy(restored.players[23]);clone.id=99
restored.players[99]=clone;restored.tick()
restored.now=restored.now+.1;restored.api.server.ospCommand(11,'god',99,true,900)
eq(restored.calls[#restored.calls].args[2],'unavailable','host waits for a persistent profile')
eq(restored.players[99].params.godMode,false,'unidentified target is unchanged')
local allocated=restored.identify(99,identity)
check(allocated~=identity,'concurrently claimed identity gets a separate profile')
eq(restored.identify(99),allocated,'retry after a lost reply keeps the assigned profile')
eq(restored.api.shared.osp.players[4].admin,false,'duplicate profile cannot inherit role')
local calls=#restored.calls
restored.api.server.ospIdentify(99,'wrong-host',0,identity)
eq(#restored.calls,calls,'wrong host namespace ignored')
-- Delegates can make temporary changes without overwriting the host's profile.
restored.command(11,'admin',23,true)
restored.command(23,'god',47,false);restored.command(23,'speed',47,1)
restored.command(23,'tool',47,{id='gun',enabled=true})
restored.command(11,'admin',47,false)
local again=world({catalog={'sledge','gun','modlaser'},identities={[47]=identity}})
again.tick();eq(again.players[47].params.godMode,true);eq(again.players[47].speed,15.75)
eq(again.players[47].tools.gun,false,'delegate changes remain temporary')
eq(again.api.shared.osp.players[3].admin,false,'explicit admin revocation persists')
ok,code=restored.command(23,'reset_player',47);eq(ok,false);eq(code,'denied')
restored.command(11,'tool_policy',0,{id='sledge',mode='disabled'})
eq(restored.command(11,'reset_player',47),true)
restored.tick();eq(restored.players[47].params.godMode,false);eq(restored.players[47].params.flyMode,false)
eq(restored.players[47].disabled,false);eq(restored.players[47].speed,7)
eq(restored.players[47].tools.gun,true,'reset restores pre-intervention tool state')
eq(restored.players[47].tools.sledge,false,'reset preserves global block')
local resetMap=world({identities={[23]=identity}})
resetMap.tick();eq(resetMap.api.shared.osp.players[2].admin,false,'reset clears saved admin')
eq(resetMap.players[23].params.godMode,false);eq(resetMap.players[23].params.flyMode,false)
eq(resetMap.players[23].speed,7);eq(resetMap.players[23].tools.gun,true)
-- Policies clear matching saved overrides even when the player is offline.
resetMap.command(11,'tool',23,{id='gun',enabled=false})
resetMap.players[23]=nil;resetMap.removed={23};resetMap.tick()
resetMap.command(11,'tool_policy',0,{id='gun',mode='enabled'})
local offline=world({identities={[47]=identity}})
offline.tick();eq(offline.players[47].tools.gun,true,'global change clears offline override')
-- Saved personal rules also catch registration between catalog refreshes.
offline.command(11,'tool_policy',0,{id='gun',mode='default'})
offline.catalog[#offline.catalog+1]='modlaser';offline.tick()
offline.command(11,'tool',47,{id='modlaser',enabled=false})
local late=world({identities={[47]=identity}})
late.catalog[#late.catalog+1]='modlaser';late.players[47].tools.modlaser=true
late.now=late.now+1/60;late.api.server.tick(1/60)
eq(late.players[47].tools.modlaser,false,'saved personal rule applies without 200 ms window')
registry={}
local explicit=world();explicit.command(11,'god',23,false)
explicit.command(11,'speed',23,.5)
local changedDefaults=world({baseGod=true,identities={[47]=explicit.identities[23]}})
changedDefaults.tick()
eq(changedDefaults.players[47].params.godMode,false,'saved false overrides a true map default')
eq(changedDefaults.players[47].speed,3.5,'saved fractional speed survives map')
-- Granular templates are checked on the server, including aliases and lifecycle.
registry={}
local access=world({catalog={'sledge','gun','modlaser'}})
local P=access.api.OSP.Permissions
local function denied(actor,action,target,value)
    local success,result=access.command(actor,action,target,value)
    eq(success,false,action);eq(result,'denied',action)
end
local function saveRole(id,name,version,permissions)
    local success,result,details=access.command(11,'role_save',0,{id=id,name=name,version=version,permissions=permissions})
    eq(success,true,'save template '..name)
    return details.template
end
local function assign(player,id) eq(access.command(11,'role_assign',player,{id=id}),true) end
assign(23,'self')
eq(access.api.shared.osp.players[2].role,'self')
eq(access.command(23,'heal',23),true)
denied(23,'heal',47)
denied(23,'kill',23)
for _,action in ipairs({'tool','tools','tools_filtered'}) do
    local value=action=='tool' and {id='gun',enabled=false} or action=='tools' and false or {category='vanilla',enabled=false}
    if action=='tools' then value=false end
    eq(access.command(23,action,23,value),true,action..' self')
    denied(23,action,47,value)
end
for _,action in ipairs({'tool_all','tools_all','tools_filtered_all'}) do
    local value=action=='tool_all' and {id='gun',enabled=false} or action=='tools_all' and false or {category='all',enabled=false}
    if action=='tools_all' then value=false end
    denied(23,action,0,value)
end
eq(access.command(23,'god',23,true),true)
ok,code=access.command(23,'god',11,true);eq(ok,false);eq(code,'protected')
eq(access.command(23,'goto',11),true,'self-service can move itself to a destination')
denied(23,'rule',0,{key='rain',value=.8})
denied(23,'restart',0)
for _,action in ipairs({'admin','role_assign','role_save','role_delete','reset_player','tool_policy','tool_policy_bulk'}) do denied(23,action,47,{}) end
ok,code=access.command(11,'role_assign',11,{id='guest'});eq(ok,false);eq(code,'protected')
local custom=saveRole('','Rain helper',0,{rule_rain=2,heal=2})
assign(23,custom.id)
eq(access.command(23,'rule',0,{key='rain',value=.7}),true)
denied(23,'rule',0,{key='fog',value=20})
denied(23,'reset_rules',0)
eq(access.command(23,'heal',47),true)
custom=saveRole(custom.id,custom.name,custom.version,{rule_rain=2,heal=1})
denied(23,'heal',47)
eq(access.command(23,'heal',23),true,'editing a template changes the next command')
ok,code=access.command(11,'role_save',0,{id=custom.id,name=custom.name,version=1,permissions={heal=2}})
eq(ok,false);eq(code,'conflict','stale save must not restore old grants')
local ids=access.api.OSP.copy(access.identities)
local nextSession=world({catalog={'sledge','gun','modlaser'},identities=ids})
eq(nextSession.api.shared.osp.players[2].role,custom.id,'assignment survives a new map')
ok,code=nextSession.command(23,'heal',47);eq(ok,false);eq(code,'denied')
eq(nextSession.command(23,'rule',0,{key='rain',value=.4}),true,'custom rule grant survives a new map')
local bad={
    {id='admin',name='Overwrite builtin',version=0,permissions={heal=2}},
    {id='',name='  padded',version=0,permissions={heal=2}},
    {id='',name=string.rep('x',41),version=0,permissions={heal=2}},
    {id='',name='Bad key',version=0,permissions={admin=2}},
    {id='',name='Bad scope',version=0,permissions={heal_all=1}},
    {id='',name='Bad type',version=0,permissions={heal=false}},
    {id='',name='Bad number',version=0,permissions={heal=0/0}},
}
for _,arg in ipairs(bad) do ok,code=access.command(11,'role_save',0,arg);eq(ok,false);eq(code,'invalid') end
ok,code=access.command(11,'role_assign',47,{id='not_a_role'});eq(ok,false);eq(code,'invalid')
assign(47,custom.id)
access.players[47]=nil;access.removed={47};access.tick()
eq(access.command(11,'role_delete',0,{id=custom.id,version=custom.version}),true)
denied(23,'heal',23)
eq(registry['savegame.mod.osp.players.'..ids[47]..'.role'],'guest','deletion revokes offline assignments')
local afterDelete=world({identities=ids})
eq(afterDelete.api.shared.osp.players[2].admin,false)
eq(afterDelete.api.shared.osp.players[3].admin,false)
registry['savegame.mod.osp.players.'..ids[23]..'.role']='deleted_or_corrupt'
registry['savegame.mod.osp.players.'..ids[23]..'.admin']=true
local corrupt=world({identities=ids})
eq(corrupt.api.shared.osp.players[2].admin,false,'unknown explicit role never resurrects legacy admin')
local replacement=saveRole('','New role',0,{heal=2})
check(replacement.id~=custom.id,'deleted template IDs are not reused')
assign(23,replacement.id)
replacement=saveRole(replacement.id,replacement.name,replacement.version,{})
denied(23,'heal',23)
eq(access.api.shared.osp.players[2].admin,false,'all-zero permissions remove panel access')
-- Built-in administrator preserves the former delegated-admin behavior.
assign(23,'admin')
eq(access.command(23,'heal_all',0),true)
eq(access.command(23,'rule',0,{key='fog',value=200}),true)
denied(23,'tool_policy',0,{id='gun',mode='enabled'})
access.command(11,'admin',23,false)
denied(23,'heal',23)
-- Bounded custom library and exact target scope rules.
for n=2,16 do saveRole('','Role '..n,0,{heal=1}) end
ok,code=access.command(11,'role_save',0,{id='',name='Overflow',version=0,permissions={heal=2}})
eq(ok,false);eq(code,'template_limit')
for _,spec in ipairs(P.spec) do
    local grants=P.normalize({[spec.id]=spec.target and 1 or 2})
    if spec.target and spec.id~='tools' then
        check(P.allows(grants,spec.id,23,nil,23),'self scope '..spec.id)
        check(not P.allows(grants,spec.id,47,nil,23),'other target blocked '..spec.id)
    end
end
print('PASS server boundary: '..count..' assertions')
