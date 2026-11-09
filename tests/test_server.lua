-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Stateful engine boundary: immediate values expire, persistent flags survive
-- respawn only when reapplied, player IDs can be reused, registry survives maps.
local count=0
local function check(v,message) assert(v,message); count=count+1 end
local function eq(a,b,message) check(a==b,(message or "equality")..": "..tostring(a).." ~= "..tostring(b)) end
local registry={}
local function multiply(a,b)
    return {a[4]*b[1]+a[1]*b[4]+a[2]*b[3]-a[3]*b[2],
        a[4]*b[2]-a[1]*b[3]+a[2]*b[4]+a[3]*b[1],
        a[4]*b[3]+a[1]*b[2]-a[2]*b[1]+a[3]*b[4],
        a[4]*b[4]-a[1]*b[1]-a[2]*b[2]-a[3]*b[3]}
end
local function world(options)
    options=options or {}
    local w={catalog=options.catalog or {'sledge','gun'},now=0,players={},calls={},ammoWrites={},removed={},time=1,restarted=false,identities={},
        env={rain=0.15,fogparams={80,300,0.8,2}}}
    for _,id in ipairs({11,23,47}) do
        w.players[id]={id=id,name="Player "..id,health=1,host=id==11,
            params={godMode=options.baseGod==true,flyMode=options.baseFly==true,healthRegeneration=true},speed=7,
            tools={sledge=true,gun=true},tool="gun",ammo={sledge=0,gun=options.gunAmmo or 50},
            vehicle=99,position={pos={0,0,0},rot={0,0,0,1}},velocity={0,0,0}}
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
        local q=w.players[p]; q.respawnAmmo={sledge=q.ammo.sledge,gun=q.ammo.gun}
        q.health=1; q.params.godMode=false;q.params.flyMode=false;q.speed=7
        q.tools={sledge=true,gun=true}; q.tool="gun"
    end
    env.GetPlayerTool=function(p) return w.players[p].tool end
    env.GetToolAmmo=function(id,p) return w.players[p].ammo[id] end
    env.SetToolAmmo=function(id,ammo,p)
        local found=false;for _,tool in ipairs(w.catalog) do if tool==id then found=true end end
        assert(found,'unregistered ammo tool '..id)
        w.players[p].ammo[id]=ammo
        w.ammoWrites[#w.ammoWrites+1]={player=p,tool=id,ammo=ammo}
    end
    env.IsToolEnabled=function(id,p) return w.players[p].tools[id] or false end
    env.SetToolEnabled=function(id,on,p) local found=false;for _,tool in ipairs(w.catalog) do if tool==id then found=true end end;assert(found,'unregistered tool '..id);w.players[p].tools[id]=on end
    env.SetPlayerTool=function(id,p) assert(id=='' or id=='none' or w.players[p].tools[id]); w.players[p].tool=id end
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
    env.InputPressed=function(k,p) return w.players[p].pressed and w.players[p].pressed[k] or false end
    env.GetPlayerCanUseTool=function(p)
        local q=w.players[p]
        return not q.interactive and not q.toolBusy and q.vehicle==0 and q.health>0
    end
    env.GetPlayerScreen=function(p) return w.players[p].screen or 0 end
    env.IsPlayerDisabled=function(p) return w.players[p].disabled==true end
    env.GetGravity=function() return w.gravity or {0,-10,0} end
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
    env.SetString=function(k,v) assert(k:sub(1,22)=="savegame.mod.osp_beta.");registry[k]=v end
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
    env.SetInt=function(k,v) assert(k:sub(1,22)=="savegame.mod.osp_beta.","writes must stay in mod namespace");registry[k]=v end
    env.GetFloat=function(k) return registry[k] or 0 end
    env.GetBool=function(k) return registry[k] or false end
    env.SetFloat=function(k,v) assert(k:sub(1,22)=="savegame.mod.osp_beta.","writes must stay in mod namespace");registry[k]=v end
    env.SetBool=env.SetFloat
    env.ClearKey=function(k)
        for key in pairs(registry) do if key==k or key:sub(1,#k+1)==k..'.' then registry[key]=nil end end
    end
    -- Physics objects are only used by the strength integration cases.
    w.bodies={};w.constraints={};w.orientations={};w.impulses={};w.queryRejects={}
    env.IsHandleValid=function(id) return w.bodies[id]~=nil or (id==1001 and w.rayBody~=nil) end
    env.IsBodyDynamic=function(id) return w.bodies[id].dynamic~=false end
    env.IsBodyJointedToStatic=function(id) return w.bodies[id].jointed==true end
    env.GetBodyPlayer=function(id) return w.bodies[id].player or 0 end
    env.GetBodyVehicle=function(id) return w.bodies[id].vehicle or 0 end
    env.GetBodyMass=function(id) return w.bodies[id].mass end
    env.GetBodyVelocity=function(id) return w.bodies[id].velocity or {0,0,0} end
    env.GetBodyTransform=function(id) return env.OSP.copy(w.bodies[id].transform) end
    env.GetBodyCenterOfMass=function(id) return w.bodies[id].com or {0,0,0} end
    env.GetPlayerBodies=function(id) return {10000+id} end
    env.GetPlayerGrabBody=function(id) return w.players[id].nativeGrab or 0 end
    env.ReleasePlayerGrab=function(id) w.players[id].nativeGrab=nil end
    env.QueryRequire=function(value) assert(value=='physical');w.queryRejects={} end
    env.QueryRejectBody=function(id) w.queryRejects[id]=true end
    env.QueryRaycast=function(origin,direction,reach)
        eq(reach,env.OSP.strength.reach,'server owns pickup reach')
        if w.rayBody then return true,w.rayDistance or 2,{0,0,1},1001 end
        return false,0,{0,0,0},0
    end
    env.GetShapeBody=function(shape) assert(shape==1001);return w.rayBody end
    env.VecSub=function(a,b) return {a[1]-b[1],a[2]-b[2],a[3]-b[3]} end
    env.TransformToLocalPoint=function(t,v) return env.VecSub(v,t.pos) end
    env.TransformToLocalTransform=function(parent,child)
        local q=parent.rot
        return {pos=env.TransformToLocalPoint(parent,child.pos),rot=multiply({-q[1],-q[2],-q[3],q[4]},child.rot)}
    end
    env.QuatRotateQuat=multiply
    env.ConstrainPosition=function(a,b,point,target,speed,impulse)
        w.constraints[#w.constraints+1]={body=a,other=b,point=point,target=target,speed=speed,impulse=impulse}
    end
    env.ConstrainOrientation=function(a,b,rotation,target,speed,impulse)
        w.orientations[#w.orientations+1]={body=a,other=b,rotation=rotation,target=target,speed=speed,impulse=impulse}
    end
    env.ApplyBodyImpulse=function(body,point,impulse) w.impulses[#w.impulses+1]={body=body,point=point,impulse=impulse} end
    env.GetTime=function() return w.inUpdate and w.physicsNow or w.now end
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
    function w.context(target)
        for _,p in ipairs(env.shared.osp.players) do
            if p.id==target then return {host=env.shared.osp.profileHost,targetJoin=p.profileChallenge} end
        end
    end
    function w.command(actor,action,target,value,contextOverride)
        for _,p in ipairs(env.shared.osp.players) do if not p.profileReady then w.identify(p.id) end end
        w.now=w.now+0.1
        local context
        if target and target~=0 then
            if contextOverride~=false then
                context=contextOverride
                if context==nil then context=w.context(target) end
            end
        end
        env.server.ospCommand(actor,action,target,value,nil,context)
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
if arg[2]=="fixture" then return world end
local w=world()
-- Directed requests require a well-formed namespace and current join marker.
do
    local t=world();local current=t.context(23);local before=#t.api.shared.osp.log
    local ok,code=t.command(11,'kill',23,nil,false);eq(ok,false);eq(code,'unavailable','missing target context')
    ok,code=t.command(11,'kill',23,nil,'malformed');eq(ok,false);eq(code,'unavailable','malformed target context')
    ok,code=t.command(11,'kill',23,nil,{host=string.rep('b',32),targetJoin=current.targetJoin})
    eq(ok,false);eq(code,'unavailable','different namespace')
    ok,code=t.command(11,'kill',23,nil,{host=current.host,targetJoin='2'})
    eq(ok,false);eq(code,'unavailable','malformed join marker')
    eq(t.players[23].health,1,'rejected contexts do not kill the target')
    eq(#t.api.shared.osp.log,before,'rejected contexts do not enter activity history')
    eq(t.command(11,'rule',0,{key='rain',value=.4}),true,'global request needs no target context')
end
-- A recycled session ID requires a new join marker even when the same saved
-- profile returns. The stale command is rejected before effects or cooldown.
do
    registry={}
    local t=world();local stale=t.context(23);local identity=t.identities[23]
    local root='savegame.mod.osp_beta.players.'..identity..'.'
    local before=#t.api.shared.osp.log
    t.removed={23};t.now=t.now+1;t.api.server.tick();t.removed={}
    local current=t.context(23);check(current.targetJoin~=stale.targetJoin,'reentry receives a new join marker')
    t.api.server.ospIdentify(23,current.host,current.targetJoin,identity)
    eq(t.calls[#t.calls].args[3],identity,'same profile may return for the new entry')
    current=t.context(23)
    t.api.server.ospCommand(11,'speed',23,2,701,stale)
    eq(t.calls[#t.calls].args[1],false,'stale request is rejected');eq(t.calls[#t.calls].args[2],'unavailable')
    eq(t.api.shared.osp.players[2].speed,1,'stale request leaves new entry unchanged')
    eq(registry[root..'speed'],nil,'stale request does not save a setting')
    eq(#t.api.shared.osp.log,before,'stale request does not enter activity history')
    t.api.server.ospCommand(11,'speed',23,2,702,current)
    eq(t.calls[#t.calls].args[1],true,'new entry accepts a current-context request')
    eq(t.calls[#t.calls].args[4],702,'request ID remains in its original RPC position')
    eq(t.api.shared.osp.players[2].speed,2,'current-context request changes the target')
    eq(registry[root..'speed'],2,'current-context request saves the setting')
end
-- Teleports require a different target, enforced before the accepted-request throttle.
do
    local t=world()
    t.command(11,'admin',23,true)
    local function direct(actor,action,target)
        t.api.server.ospCommand(actor,action,target,nil,nil,t.context(target))
        local response=t.calls[#t.calls]
        eq(response.fn,'client.ospResult','direct command reply')
        return response.args[1],response.args[2],response.args[3]
    end
    local function prime(p)
        t.players[p].position={pos={p,p+1,p+2},rot={0,0,0,1}}
        t.players[p].vehicle=700+p
        t.players[p].velocity={1,2,3}
        t.players[p].speed=4
        return {position=t.api.OSP.copy(t.players[p].position),vehicle=t.players[p].vehicle,
            velocity=t.api.OSP.copy(t.players[p].velocity),speed=t.players[p].speed}
    end
    local function unchanged(p,before)
        local after=t.players[p]
        eq(after.vehicle,before.vehicle,'rejected self teleport preserves vehicle')
        eq(after.speed,before.speed,'rejected self teleport preserves speed')
        for i=1,3 do
            eq(after.position.pos[i],before.position.pos[i],'rejected self teleport preserves position')
            eq(after.velocity[i],before.velocity[i],'rejected self teleport preserves velocity')
        end
        for i=1,4 do eq(after.position.rot[i],before.position.rot[i],'rejected self teleport preserves rotation') end
    end
    for _,case in ipairs({
        {actor=11,action='goto',other=23},
        {actor=11,action='bring',other=23},
        {actor=23,action='goto',other=11}, -- delegated Go there to the host remains allowed
        {actor=23,action='bring',other=47},
    }) do
        t.now=t.now+1
        local before=prime(case.actor)
        local logCount=#t.api.shared.osp.log
        local ok,code=direct(case.actor,case.action,case.actor)
        eq(ok,false,'self teleport is refused')
        eq(code,'invalid','self teleport has invalid result')
        unchanged(case.actor,before)
        eq(#t.api.shared.osp.log,logCount,'rejected self teleport does not log success')
        -- A valid command from the same actor at the same instant proves the
        -- rejected request did not consume the accepted-request throttle.
        ok,code=direct(case.actor,case.action,case.other)
        eq(ok,true,'teleport to another player remains allowed')
        eq(code,'ok')
    end
    t.players[47].health=0
    local ownPosition=t.api.OSP.copy(t.players[11].position)
    local beforeLog=#t.api.shared.osp.log
    local ok,code,details=t.command(11,'bring_all',0)
    eq(ok,true);eq(details.affected,1);eq(details.skipped,2,'Bring all still excludes caller and skips dead target')
    eq(t.players[11].position.pos[1],ownPosition.pos[1],'Bring all does not move its caller')
    check(#t.api.shared.osp.log>beforeLog,'Bring all keeps its accepted history entry')
end
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
w.players[47].vehicle=0
w.command(11,'god',47,true);w.command(11,'noclip',47,true);w.command(11,'speed',47,2)
w.players[47].inputs={up=true,jump=true};w.tick();check(w.players[47].velocity[3]<0,'noclip logical forward');check(w.players[47].velocity[2]>0,'noclip logical jump');eq(w.players[47].speed,7)
w.command(11,'freeze',47,true);w.tick();eq(w.players[47].disabled,true);eq(w.players[47].velocity[3],0)
w.command(11,'freeze',47,false);w.tick();eq(w.players[47].disabled,false)
w.command(11,'kill',47);w.tick();w.command(11,'respawn',47);w.tick();eq(w.players[47].params.godMode,true);eq(w.players[47].params.flyMode,true);eq(w.players[47].speed,7)
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
w.api.server.ospCommand(11,'admin',47,true,nil,w.context(47))
w.api.server.ospCommand(47,'heal',47,nil,nil,w.context(47))
eq(w.calls[#w.calls].args[1],true,'same-frame removal processed once')
w.removed={}
-- Late join and persistence across a new Lua context/map.
w.command(11,'rule',0,{key='rain',value=.8});w.command(11,'rule',0,{key='fog',value=20});check(w.env.fogparams[1]<20,'fog start below end');eq(w.env.fogparams[3],.8)
w.command(11,'rule',0,{key='time',value=.4});w.command(11,'rule',0,{key='regen',value=false});w.tick();eq(w.time,.4);eq(w.players[47].params.healthRegeneration,false)
local w2=world();eq(w2.env.rain,.8);eq(w2.api.shared.osp.rules.regen,false);eq(w2.api.shared.osp.players[2].admin,false)
w2.command(11,'reset_rules',0);eq(w2.env.rain,.15);eq(w2.env.fogparams[1],80);eq(w2.env.fogparams[2],300);eq(w2.players[23].params.healthRegeneration,true)
eq(w2.api.HasKey('savegame.mod.osp_beta.rules'),false,'reset rules preserves unrelated saved profiles')
w2.tick();eq(w2.time,1)
-- Dead teleport destinations cannot report a successful move.
w2.players[23].health=0
ok,code=w2.command(11,'goto',23);eq(ok,false);eq(code,'unavailable')
ok,code,details=w2.command(11,'bring_all',0);eq(ok,true);eq(details.affected,1);eq(details.skipped,2)
w2.players[11].health=0;ok,code=w2.command(11,'bring_all',0);eq(ok,false);eq(code,'unavailable');w2.players[11].health=1
-- Tool delegates without the restart capability cannot restart.
w2.command(11,'role_assign',23,{id='moderator'})
w2.command(23,'tool_all',0,{id='sledge',enabled=false})
eq(w2.players[11].tools.sledge,true);eq(w2.players[47].tools.sledge,false)
ok,code=w2.command(23,'restart',0);eq(ok,false);eq(w2.restarted,false)
eq(w2.command(11,'restart',0),true);eq(w2.restarted,true)
-- Replies carry the exact request ID; sending a request is not completion.
w2.now=w2.now+1;w2.api.server.ospCommand(11,'heal',47,nil,1234,w2.context(47))
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
pworld.command(11,'role_assign',23,{id='moderator'})
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
for _,effect in ipairs({'god','noclip','freeze','admin'}) do eq(saved.command(11,effect,23,true),true) end
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
eq(restored.players[47].speed,7);eq(restored.api.shared.osp.players[3].admin,true)
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
restored.now=restored.now+.1;restored.api.server.ospCommand(11,'god',99,true,900,restored.context(99))
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
local _,_,playerControls=restored.command(11,'role_save',0,{id='',name='Player controls',version=0,permissions={god=2,speed=2,tools=2}})
restored.command(11,'role_assign',23,{id=playerControls.template.id})
restored.command(23,'god',47,false);restored.command(23,'speed',47,1)
restored.command(23,'tool',47,{id='gun',enabled=true})
restored.command(11,'admin',47,false)
local again=world({catalog={'sledge','gun','modlaser'},identities={[47]=identity}})
again.tick();eq(again.players[47].params.godMode,true);eq(again.players[47].speed,7)
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
denied(23,'kill',47)
ok,code=access.command(23,'kill',11);eq(ok,false);eq(code,'protected')
eq(access.command(23,'kill',23),true,'Self role allows suicide')
eq(access.players[23].health,0,'self kill reaches the server')
eq(access.command(23,'respawn',23),true,'Self can respawn after suicide')
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
    {id='unknown',name='Unknown role',version=0,permissions={heal=2}},
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
eq(registry['savegame.mod.osp_beta.players.'..ids[47]..'.role'],'guest','deletion revokes offline assignments')
local afterDelete=world({identities=ids})
eq(afterDelete.api.shared.osp.players[2].admin,false)
eq(afterDelete.api.shared.osp.players[3].admin,false)
registry['savegame.mod.osp_beta.players.'..ids[23]..'.role']='deleted_or_corrupt'
registry['savegame.mod.osp_beta.players.'..ids[23]..'.admin']=true
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
eq(access.command(23,'tool_policy',0,{id='gun',mode='enabled'}),true,'Administrator includes global tool policy')
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
-- Colliding flight is a saved ability; the live flying state is transient.
registry={}
local flight=world();local pilot=flight.players[23];pilot.vehicle=0
eq(flight.command(11,'fly',23,true),true)
eq(flight.api.shared.osp.players[2].fly,true)
eq(flight.api.shared.osp.players[2].flying,false,'enabling the ability does not immediately fly')
eq(pilot.params.flyMode,false,'colliding flight must never enable native noclip')
eq(flight.api.shared.osp.players[2].admin,false,'host may grant the ability to an ordinary guest')
local transforms=0
flight.api.SetPlayerTransform=function() transforms=transforms+1 end
local function frame(pressed,dt)
    flight.now=flight.now+(dt or .05)
    pilot.pressed={jump=pressed};pilot.speed=7;pilot.params.jumpSpeed=5
    flight.api.server.tick(dt or .05)
    flight.inUpdate=true;flight.api.server.update(1/60);flight.inUpdate=false
    pilot.pressed={}
end
pilot.inputs={jump=true};frame(true)
eq(pilot.speed,7,'single jump retains normal movement')
frame(false);frame(true)
eq(pilot.speed,0,'double jump starts colliding flight')
eq(pilot.params.jumpSpeed,0,'native jump impulse is suppressed only while flying')
check(pilot.velocity[2]>0,'hold jump ascends')
frame(false,.4);eq(pilot.speed,0,'holding jump cannot repeatedly toggle flight')
pilot.inputs={};frame(false)
eq(pilot.velocity[1],0);eq(pilot.velocity[3],0)
check(math.abs(pilot.velocity[2]-10/60)<.00001,'hover compensates this physics step gravity')
local hovered=pilot.velocity[2]-10/60
check(math.abs(hovered)<.00001,'gravity cancellation produces zero vertical velocity in a physics step')
flight.gravity={2,-4,0};flight.api.server.update(.02)
eq(pilot.velocity[1],-.04);eq(pilot.velocity[2],.08)
flight.gravity=nil;pilot.inputs={up=true,right=true,jump=true};frame(false)
local v=pilot.velocity;local speed=math.sqrt(v[1]^2+(v[2]-10/60)^2+v[3]^2)
check(math.abs(speed-9)<.00001,'diagonal flight speed stays bounded')
pilot.inputs={up=true,shift=true};frame(false)
eq(pilot.velocity[3],-18,'Shift uses the default boosted flight speed')
pilot.inputs={up=true};frame(false);eq(pilot.velocity[3],-9,'releasing Shift restores normal speed')
eq(flight.command(11,'fly_speed',23,12.5),true)
eq(flight.command(11,'fly_boost',23,31),true)
frame(false);eq(pilot.velocity[3],-12.5,'custom normal speed applies while flying')
pilot.inputs.shift=true;frame(false);eq(pilot.velocity[3],-31,'custom Shift speed applies')
flight.command(11,'speed',23,2);frame(false);eq(pilot.velocity[3],-31,'Fly Shift speed is independent of the general multiplier')
pilot.inputs.shift=false;frame(false);eq(pilot.velocity[3],-12.5,'normal Fly speed is also final')
pilot.inputs={shift=true};frame(false);eq(pilot.velocity[3],0,'Shift alone does not move the player')
check(math.abs(pilot.velocity[2]-10/60)<.00001,'boost never changes gravity compensation')
flight.command(11,'speed',23,1);flight.command(11,'fly_speed',23,9);flight.command(11,'fly_boost',23,18)
eq(transforms,0,'flight uses the normal collider, never position teleportation')
eq(pilot.params.CollisionMask,nil,'collision mask is not disabled')
eq(pilot.params.flyMode,false)
-- Native trace: grabbing (and Plank use) makes canusetool false even though
-- movement inputs arrive. A fresh, player-specific gameplay report permits it.
local inputSequence=0
local function flightInput(allowed,options)
    options=options or {};inputSequence=inputSequence+1
    flight.api.server.ospFlightInput(23,options.host or flight.api.shared.osp.profileHost,
        options.challenge or flight.api.shared.osp.players[2].profileChallenge,
        options.sequence or inputSequence,allowed)
end
pilot.toolBusy=true;pilot.inputs={up=true};frame(false)
eq(pilot.velocity[3],0,'unknown tool-busy context fails closed')
flightInput(true);frame(false);eq(pilot.velocity[3],-9,'grabbing/Plank does not stop Fly')
-- GetTime uses simulation time in update, but wall time in tick/callbacks.
-- Pausing or changing time scale can make these clocks diverge permanently.
flight.physicsNow=flight.now-30
frame(false);eq(pilot.velocity[3],-9,'held-object flight survives simulation time behind wall time')
flight.physicsNow=flight.now+30
frame(false);eq(pilot.velocity[3],-9,'held-object flight survives simulation time ahead of wall time')
frame(false,.51);eq(pilot.velocity[3],0,'wall-time expiry still blocks movement with a frozen simulation clock')
flightInput(true);frame(false);eq(pilot.velocity[3],-9,'new report restores movement despite divergent clocks')
flightInput(false);frame(false);eq(pilot.velocity[3],0,'UI denial remains effective with divergent clocks')
flightInput(true);flight.physicsNow=nil

pilot.inputs={jump=true,shift=true};frame(false)
check(math.abs(pilot.velocity[2]-10/60-18)<.00001,'grabbing retains rise and Shift speed')
pilot.inputs={up=true};flightInput(false);frame(false)
eq(pilot.velocity[3],0,'opening an interface while holding an object suspends movement')
flightInput(true,{sequence=inputSequence-1});frame(false)
eq(pilot.velocity[3],0,'late gameplay report cannot undo a newer UI report')
flightInput(true,{host='another-host'});frame(false);eq(pilot.velocity[3],0)
flightInput(true,{challenge=-1});frame(false);eq(pilot.velocity[3],0)
flightInput('yes');frame(false);eq(pilot.velocity[3],0,'non-boolean reports cannot enable movement')
flightInput(true,{sequence=math.huge});frame(false);eq(pilot.velocity[3],0,'non-finite sequences are rejected')
flightInput(true,{sequence=0.5});frame(false);eq(pilot.velocity[3],0,'fractional sequences are rejected')
flightInput(true);pilot.screen=42;frame(false);eq(pilot.velocity[3],0,'screen interaction blocks fallback')
pilot.screen=nil;pilot.disabled=true;frame(false);eq(pilot.velocity[3],0,'disabled player blocks fallback')
pilot.disabled=false;frame(false);eq(pilot.velocity[3],-9)
frame(false,.51);eq(pilot.velocity[3],0,'lost context reports expire instead of leaving steering enabled')
flightInput(true);frame(false);eq(pilot.velocity[3],-9,'fresh heartbeat resumes valid gameplay')
local beforeLog=#flight.api.shared.osp.log
flightInput('yes');frame(false)
eq(#flight.api.shared.osp.log,beforeLog,'movement reports are not administrative commands')
pilot.toolBusy=false;pilot.inputs={};frame(false)
flightInput(false);pilot.interactive=true;pilot.inputs={jump=true,right=true};frame(true)
eq(pilot.velocity[1],0,'interactive UI suspends steering')
flightInput(true);pilot.interactive=false;frame(true);frame(false);frame(true)
eq(pilot.speed,7,'the two taps after closing UI can stop flight')
-- Slow taps and UI transitions cannot be combined into a double jump.
frame(true,.5);frame(false,.4);frame(true,.4);eq(pilot.speed,7)
pilot.interactive=true;frame(false);pilot.interactive=false;frame(true);eq(pilot.speed,7)
frame(false);frame(true);eq(pilot.speed,0)
pilot.vehicle=123;frame(false);eq(pilot.vehicle,123,'entering a vehicle ends flight without ejecting it')
eq(pilot.speed,7)
pilot.vehicle=0;frame(true);frame(false);frame(true);eq(pilot.speed,0)
flight.command(11,'freeze',23,true);frame(false);eq(pilot.speed,7,'freeze cancels active flight')
flight.command(11,'freeze',23,false)
frame(true);frame(false);frame(true);eq(pilot.speed,0)
flight.command(11,'respawn',23);frame(false);eq(pilot.speed,7,'explicit respawn ends flight without waiting to observe death')
frame(true);frame(false);frame(true);eq(pilot.speed,0)
flight.command(11,'kill',23);flight.command(11,'heal',23);frame(false)
eq(pilot.speed,7,'kill and heal in one frame cannot preserve active flight')
frame(true);frame(false);frame(true);eq(pilot.speed,0)
pilot.health=0;frame(false);pilot.health=1;frame(false);eq(pilot.speed,7,'respawn does not reactivate flight')
flight.command(11,'noclip',23,true);eq(pilot.params.flyMode,true)
eq(flight.api.shared.osp.players[2].fly,false,'noclip disables the colliding-flight ability')
flight.command(11,'fly',23,true);eq(pilot.params.flyMode,false)
eq(flight.api.shared.osp.players[2].noclip,false,'enabling colliding flight turns noclip off')
local flyingMap=world({identities=flight.identities});flyingMap.players[23].vehicle=0;flyingMap.tick()
eq(flyingMap.api.shared.osp.players[2].fly,true,'flight ability persists between maps')
eq(flyingMap.api.shared.osp.players[2].flying,false,'active flight is not saved')
eq(flyingMap.players[23].params.flyMode,false)
local flightRoot='savegame.mod.osp_beta.players.'..flight.identities[23]..'.'
eq(registry[flightRoot..'fly'],false,'older builds cannot turn the new ability into noclip')
registry[flightRoot..'noclip']=nil;registry[flightRoot..'flight']=nil;registry[flightRoot..'fly']=true
local oldFlight=world({identities=flight.identities});oldFlight.tick()
eq(oldFlight.api.shared.osp.players[2].noclip,true,'legacy Fly choices retain noclip behavior')
eq(oldFlight.api.shared.osp.players[2].fly,false)
-- Existing custom-role Fly grants retain their old meaning, independently of
-- the new capability. Storage remains safe when returning to an older build.
registry={}
registry['savegame.mod.osp_beta.templates.c7.name']='Legacy flyer'
registry['savegame.mod.osp_beta.templates.c7.version']=1
registry['savegame.mod.osp_beta.templates.c7.permissions.fly']=2
registry['savegame.mod.osp_beta.templates_next']=7
local legacy=world()
eq(legacy.command(11,'role_assign',23,{id='c7'}),true)
eq(legacy.command(23,'noclip',47,true),true)
ok,code=legacy.command(23,'fly',47,true);eq(ok,false);eq(code,'denied')
eq(legacy.command(11,'role_save',0,{id='c7',name='New flyer',version=1,permissions={fly=1,noclip=0}}),true)
eq(registry['savegame.mod.osp_beta.templates.c7.permissions.fly'],0,'legacy grant mirrors only noclip')
eq(registry['savegame.mod.osp_beta.templates.c7.permissions.flight'],1)
local modern=world({identities=legacy.identities})
eq(modern.command(23,'fly',23,true),true)
ok,code=modern.command(23,'fly',47,true);eq(ok,false);eq(code,'denied')
ok,code=modern.command(23,'noclip',23,true);eq(ok,false);eq(code,'denied')
registry={}
local tuning=world();local tuningId=tuning.identities[23]
tuning.command(11,'fly_speed',23,14.75);tuning.command(11,'fly_boost',23,37.5)
local tunedMap=world({identities={[47]=tuningId}})
eq(tunedMap.api.shared.osp.players[3].flySpeed,14.75,'normal flight speed follows saved identity')
eq(tunedMap.api.shared.osp.players[3].flyBoost,37.5,'Shift speed persists between missions')
tunedMap.command(11,'role_assign',47,{id='self'})
eq(tunedMap.command(47,'fly_speed',47,20),true,'Fly scope grants its speed configuration')
ok,code=tunedMap.command(47,'fly_boost',23,30);eq(ok,false);eq(code,'denied')
ok,code=tunedMap.command(47,'fly_speed',11,30);eq(ok,false);eq(code,'protected')
local stillSaved=world({identities={[47]=tuningId}})
eq(stillSaved.api.shared.osp.players[3].flySpeed,14.75,'delegate tuning stays temporary')
for _,bad in ipairs({0,101,0/0,math.huge,'9'}) do
    ok,code=tunedMap.command(11,'fly_boost',47,bad);eq(ok,false);eq(code,'invalid')
end
tunedMap.command(11,'reset_player',47)
eq(tunedMap.api.shared.osp.players[3].flySpeed,9);eq(tunedMap.api.shared.osp.players[3].flyBoost,18)
registry['savegame.mod.osp_beta.players.'..tuningId..'.flight_speed']=-100
registry['savegame.mod.osp_beta.players.'..tuningId..'.flight_boost']=math.huge
local invalidTuning=world({identities={[47]=tuningId}})
eq(invalidTuning.api.shared.osp.players[3].flySpeed,9,'invalid saved tuning falls back')
eq(invalidTuning.api.shared.osp.players[3].flyBoost,18)
-- Modes have independent final speeds; neither inherits the walking multiplier.
registry={}
local modes=world();local modeId=modes.identities[23]
eq(modes.api.shared.osp.players[2].noclipSpeed,9,'older profiles get normal defaults')
eq(modes.api.shared.osp.players[2].noclipBoost,18)
for _,setting in ipairs({{'fly_speed',14.75},{'fly_boost',37.5},{'noclip_speed',5.25},{'noclip_boost',11}}) do
    eq(modes.command(11,setting[1],23,setting[2]),true)
end
eq(modes.api.shared.osp.players[2].fly,false,'tuning cannot activate Fly')
eq(modes.api.shared.osp.players[2].noclip,false,'tuning cannot activate Noclip')
modes.players[23].vehicle=0
modes.command(11,'speed',23,3);modes.command(11,'noclip',23,true)
modes.players[23].inputs={up=true};modes.tick()
eq(modes.players[23].velocity[3],-5.25);eq(modes.players[23].speed,7,'native walking multiplier is not applied to Noclip')
modes.players[23].inputs.shift=true;modes.tick();eq(modes.players[23].velocity[3],-11)
modes.players[23].inputs.shift=false;modes.tick();eq(modes.players[23].velocity[3],-5.25,'releasing Shift restores normal Noclip')
modes.players[23].inputs={up=true,right=true,jump=true};modes.tick()
check(math.abs(modes.api.VecLength(modes.players[23].velocity)-5.25)<.00001,'Noclip diagonals stay normalized')
modes.players[23].inputs={shift=true};modes.tick();eq(modes.api.VecLength(modes.players[23].velocity),0,'Shift alone does not move Noclip')
modes.command(11,'noclip_boost',23,2);modes.players[23].inputs={up=true,shift=true};modes.tick()
eq(modes.players[23].velocity[3],-2,'Shift may deliberately be configured slower')
modes.command(11,'noclip',23,false);modes.tick();eq(modes.players[23].speed,21,'walking multiplier works again after Noclip')
modes.command(11,'fly',23,true);modes.players[23].inputs={up=true}
for _,pressed in ipairs({true,false,true}) do
    modes.now=modes.now+.1;modes.players[23].pressed={jump=pressed};modes.api.server.tick(.1)
end
modes.players[23].pressed={};modes.api.server.update(1/60)
eq(modes.players[23].velocity[3],-14.75,'normal Fly is final with walking multiplier 3x')
modes.players[23].inputs.shift=true;modes.api.server.update(1/60)
eq(modes.players[23].velocity[3],-37.5,'Shift Fly is final with walking multiplier 3x')
modes.command(11,'fly',23,false);modes.tick();eq(modes.players[23].speed,21,'walking multiplier works again after Fly')
local migrated=world({identities={[47]=modeId}})
local state=migrated.api.shared.osp.players[3]
eq(state.flySpeed,14.75);eq(state.flyBoost,37.5);eq(state.noclipSpeed,5.25);eq(state.noclipBoost,2)
local _,_,role=migrated.command(11,'role_save',0,{id='',name='Fly only',version=0,permissions={fly=1}})
migrated.command(11,'role_assign',47,{id=role.template.id})
eq(migrated.command(47,'fly_speed',47,20),true)
ok,code=migrated.command(47,'noclip_speed',47,20);eq(ok,false);eq(code,'denied')
_,_,role=migrated.command(11,'role_save',0,{id='',name='Noclip only',version=0,permissions={noclip=1}})
migrated.command(11,'role_assign',47,{id=role.template.id})
eq(migrated.command(47,'noclip_speed',47,22),true)
ok,code=migrated.command(47,'fly_speed',47,20);eq(ok,false);eq(code,'denied')
ok,code=migrated.command(47,'noclip_boost',23,20);eq(ok,false);eq(code,'denied')
ok,code=migrated.command(47,'noclip_speed',11,20);eq(ok,false);eq(code,'protected')
local preserved=world({identities={[47]=modeId}})
eq(preserved.api.shared.osp.players[3].noclipSpeed,5.25,'delegated Noclip tuning stays temporary')
for _,action in ipairs({'fly_speed','fly_boost','noclip_speed','noclip_boost'}) do
    for _,bad in ipairs({0,101,0/0,math.huge,'9'}) do
        ok,code=migrated.command(11,action,47,bad);eq(ok,false);eq(code,'invalid')
    end
end
migrated.command(11,'reset_player',47)
state=migrated.api.shared.osp.players[3]
eq(state.flySpeed,9);eq(state.flyBoost,18);eq(state.noclipSpeed,9);eq(state.noclipBoost,18)
registry['savegame.mod.osp_beta.players.'..modeId..'.noclip_speed']=-4
registry['savegame.mod.osp_beta.players.'..modeId..'.noclip_boost']=math.huge
local corruptModes=world({identities={[47]=modeId}})
eq(corruptModes.api.shared.osp.players[3].noclipSpeed,9);eq(corruptModes.api.shared.osp.players[3].noclipBoost,18)
-- Selection commands accept an exact cross-page subset and preserve unrelated
-- tools, while the host's selected-player choices persist between missions.
registry={}
local selectionIds={}
for i=1,20 do selectionIds[i]=string.format('tool%02d',i) end
local selection=world({catalog=selectionIds})
for _,p in ipairs({11,23,47}) do
    for _,id in ipairs(selectionIds) do selection.players[p].tools[id]=true end
    selection.players[p].tool='tool01'
end
local chosenTools={'tool01','tool12','tool20'}
local chosenSet={tool01=true,tool12=true,tool20=true}
local selectionPayload={category='all',ids=chosenTools,enabled=false}
ok,code,details=selection.command(11,'tools_selection',23,selectionPayload)
eq(ok,true);eq(details.tools,3);eq(details.affected,1);eq(details.skipped,0)
for _,id in ipairs(selectionIds) do
    eq(selection.players[23].tools[id],not chosenSet[id],'only captured selection changes: '..id)
end
local selectionLog=selection.api.shared.osp.log[#selection.api.shared.osp.log]
eq(selectionLog.action,'tools_selection')
eq(selectionLog.argument.category,'all');eq(selectionLog.argument.tools,3)
eq(selectionLog.argument.ids,nil,'selection log does not expose raw IDs')
eq(selectionLog.argument.query,nil,'selection log does not expose local search text')
local persistedSelection=world({catalog=selectionIds,identities={[23]=selection.identities[23]}})
for _,id in ipairs(selectionIds) do persistedSelection.players[23].tools[id]=true end
persistedSelection.tick()
for _,id in ipairs(selectionIds) do
    eq(persistedSelection.players[23].tools[id],not chosenSet[id],'host selection persists only selected tools')
end
-- Shape errors and category mismatches are rejected before any selected tool
-- changes. Unknown and recently removed IDs report unavailable, atomically.
local badSelections={
    {category='all',ids={},enabled=false},
    {category='all',ids={[1]='tool03',[3]='tool04'},enabled=false},
    {category='all',ids={'tool03','tool03'},enabled=false},
    {category='vanilla',ids={'tool03'},enabled=false},
    {category='all',ids={'tool03'},enabled=false,query='not an RPC field'},
}
for _,badSelection in ipairs(badSelections) do
    ok,code=selection.command(11,'tools_selection',23,badSelection)
    eq(ok,false);eq(code,'invalid');eq(selection.players[23].tools.tool03,true,'invalid selection is atomic')
end
ok,code=selection.command(11,'tools_selection',23,{category='all',ids={'tool03','missing_tool'},enabled=false})
eq(ok,false);eq(code,'unavailable');eq(selection.players[23].tools.tool03,true,'unknown ID cannot partially apply')
selection.catalog={}
for _,id in ipairs(selectionIds) do if id~='tool12' then selection.catalog[#selection.catalog+1]=id end end
ok,code=selection.command(11,'tools_selection',23,{category='all',ids={'tool03','tool12'},enabled=false})
eq(ok,false);eq(code,'unavailable','removed ID is detected from the refreshed catalog')
eq(selection.players[23].tools.tool03,true,'removed ID cannot partially apply')
-- A newly registered ID is accepted immediately, even before the periodic
-- catalog refresh, and the request still affects only its explicit IDs.
selection.catalog[#selection.catalog+1]='newly_registered'
selection.players[23].tools.newly_registered=true
ok,code,details=selection.command(11,'tools_selection',23,{category='all',ids={'tool03','newly_registered'},enabled=false})
eq(ok,true);eq(details.tools,2);eq(selection.players[23].tools.tool03,false)
eq(selection.players[23].tools.newly_registered,false);eq(selection.players[23].tools.tool04,true)
-- Capability aliases preserve targeted self scope and the separate all-player
-- capability; host-only policy selection remains reserved.
local _,_,selectionRole=selection.command(11,'role_save',0,{id='',name='Tool self',version=0,permissions={tools=1}})
selection.command(11,'role_assign',23,{id=selectionRole.template.id})
ok,code=selection.command(23,'tools_selection',23,{category='all',ids={'tool04'},enabled=false})
eq(ok,true,'tools_selection maps to tools')
ok,code=selection.command(23,'tools_selection',47,{category='all',ids={'tool04'},enabled=false})
eq(ok,false);eq(code,'denied','self-scoped tool role cannot target others')
ok,code=selection.command(23,'tools_selection_all',0,{category='all',ids={'tool05'},enabled=false})
eq(ok,false);eq(code,'denied','targeted tools capability does not grant tools_all')
local _,_,allToolsRole=selection.command(11,'role_save',0,{id='',name='Tool session',version=0,permissions={tools_all=2}})
selection.command(11,'role_assign',47,{id=allToolsRole.template.id})
ok,code,details=selection.command(47,'tools_selection_all',0,{category='all',ids={'tool05'},enabled=false})
eq(ok,true);eq(details.tools,1);eq(details.affected,2);eq(details.skipped,1)
eq(selection.players[11].tools.tool05,true,'delegated all-player selection protects host')
ok,code=selection.command(47,'tool_policy_selection',0,{category='all',ids={'tool05'},mode='disabled'})
eq(ok,false);eq(code,'denied','policy selection is host-only')
local nextSelectionCatalog={}
for _,id in ipairs(selectionIds) do nextSelectionCatalog[#nextSelectionCatalog+1]=id end
nextSelectionCatalog[#nextSelectionCatalog+1]='newly_registered'
local nextSelection=world({catalog=nextSelectionCatalog,identities=selection.identities})
for _,p in ipairs({11,23,47}) do
    for _,id in ipairs(nextSelectionCatalog) do nextSelection.players[p].tools[id]=true end
end
nextSelection.tick()
eq(nextSelection.players[23].tools.tool01,false,'host choice survives map transition')
eq(nextSelection.players[23].tools.tool12,false,'host subset survives map transition')
eq(nextSelection.players[23].tools.tool20,false,'host subset reaches later page')
eq(nextSelection.players[23].tools.tool04,true,'delegate target changes are temporary')
eq(nextSelection.players[23].tools.tool05,true,'delegated all-player changes are temporary')
eq(nextSelection.players[47].tools.tool05,true,'all-player delegate changes do not persist')
-- Global policy changes clear saved overrides for the selected IDs only, even
-- when their profiles are offline; other tools' overrides remain intact.
registry={}
local selectionPolicy=world({catalog={'tool01','tool02','tool03'}})
selectionPolicy.command(11,'tool',23,{id='tool01',enabled=false})
selectionPolicy.command(11,'tool',47,{id='tool02',enabled=false})
local profile23=selectionPolicy.identities[23]
local profile47=selectionPolicy.identities[47]
local encodedTool01=('tool01'):gsub('.',function(c) return string.format('%02x',c:byte()) end)
local encodedTool02=('tool02'):gsub('.',function(c) return string.format('%02x',c:byte()) end)
local profileRoot='savegame.mod.osp_beta.players.'
eq(registry[profileRoot..profile23..'.tools.'..encodedTool01],2)
eq(registry[profileRoot..profile47..'.tools.'..encodedTool02],2)
selectionPolicy.players[47]=nil;selectionPolicy.removed={47};selectionPolicy.tick()
ok,code,details=selectionPolicy.command(11,'tool_policy_selection',0,
    {category='all',ids={'tool01'},mode='enabled'})
eq(ok,true);eq(details.tools,1)
eq(registry[profileRoot..profile23..'.tools.'..encodedTool01],nil,'selected policy clears matching online override')
eq(registry[profileRoot..profile47..'.tools.'..encodedTool01],nil,'selected policy clears matching offline override')
eq(registry[profileRoot..profile47..'.tools.'..encodedTool02],2,'unselected offline override is preserved')
local selectionPolicyMap=world({catalog={'tool01','tool02','tool03'},identities={[23]=profile23,[47]=profile47}})
for _,p in ipairs({11,23,47}) do
    for _,id in ipairs({'tool01','tool02','tool03'}) do selectionPolicyMap.players[p].tools[id]=true end
end
selectionPolicyMap.tick()
eq(selectionPolicyMap.players[23].tools.tool01,true,'selected global policy takes effect')
eq(selectionPolicyMap.players[23].tools.tool02,true,'other profile keeps its own default')
eq(selectionPolicyMap.players[47].tools.tool02,false,'unselected offline override survives')
-- A globally blocked ID stays blocked when a later explicit selection requests
-- enable; the server never falls back to applying the whole category.
selectionPolicyMap.command(11,'tool_policy_selection',0,
    {category='all',ids={'tool03'},mode='disabled'})
ok,code=selectionPolicyMap.command(11,'tools_selection',23,
    {category='all',ids={'tool03'},enabled=true})
eq(ok,true);eq(selectionPolicyMap.players[23].tools.tool03,false,'global block dominates explicit enable')
-- Conditional self toggles reject stale expectations before any gameplay write.
for _,action in ipairs({'god','fly','noclip'}) do
    registry={}
    local conditional=world({baseGod=true,baseFly=true});local e=conditional.api
    local function current(id)
        for _,entry in ipairs(e.shared.osp.players) do if entry.id==id then return entry[action] end end
    end
    local expected=current(11);local position=e.OSP.copy(conditional.players[11].position)
    conditional.players[11].vehicle=77;conditional.players[11].velocity={4,5,6}
    local before=e.shared.osp.log[#e.shared.osp.log]
    ok,code=conditional.command(11,action,11,{expected=not expected,value=expected})
    eq(ok,false);eq(code,'state_changed');eq(current(11),expected)
    eq(conditional.players[11].vehicle,77,'stale request does not eject')
    eq(conditional.players[11].velocity[1],4,'stale request does not stop movement')
    eq(conditional.players[11].position.pos[1],position.pos[1])
    eq(e.shared.osp.log[#e.shared.osp.log],before,'rejected request does not log success')
    for _,arg in ipairs({{expected=expected,value=expected},{expected=expected,value='true'},{value=true},{expected=expected,value=not expected,extra=1}}) do
        ok,code=conditional.command(11,action,11,arg);eq(ok,false);eq(code,'invalid')
    end
    ok,code=conditional.command(11,action,23,{expected=current(23),value=not current(23)})
    eq(ok,false);eq(code,'invalid','conditional form is self-only')
    eq(conditional.command(11,action,11,{expected=expected,value=not expected}),true)
    eq(current(11),not expected,'matching state applies once')
    eq(e.shared.osp.log[#e.shared.osp.log].argument,not expected,'history keeps boolean argument')
    local reload=world({baseGod=true,baseFly=true})
    for _,entry in ipairs(reload.api.shared.osp.players) do if entry.id==11 then eq(entry[action],not expected,'host choice persists') end end
    eq(conditional.command(11,action,23,true),true,'legacy boolean still targets other players')
    ok,code=conditional.command(47,action,47,{expected=current(47),value=not current(47)})
    eq(ok,false);eq(code,'denied','guest cannot use conditional form')
    eq(conditional.command(11,'admin',23,true),true)
    local own=current(23);eq(conditional.command(23,action,23,{expected=own,value=not own}),true,'delegate can use own permitted toggle')
end

-- Strength uses the same authorization/profile boundary as other player effects.
registry={}
local strong=world();local ids=strong.identities;local se=strong.api
local function strongState(who,wld)
    for _,p in ipairs((wld or strong).api.shared.osp.players) do if p.id==who then return p end end
end
local root='savegame.mod.osp_beta.players.'..ids[23]..'.'
eq(strongState(23).strength,false);eq(strongState(23).strengthForce,1)
eq(strongState(23).strengthMass,5000);eq(strongState(23).strengthThrow,false);eq(strongState(23).strengthThrowSpeed,20)
for _,spec in ipairs({{'strength_force',4.5},{'strength_mass',12000},{'strength_throw_speed',37.5},{'strength_throw',true}}) do
    eq(strong.command(11,spec[1],23,spec[2]),true,'host tunes player strength')
    eq(registry[root..spec[1]],spec[2],'host configuration saved')
end
eq(strongState(23).strength,false,'configuration never enables strength')
eq(strong.command(11,'strength',23,true),true)
local invalidToggle,invalidCode=strong.command(11,'strength',23,{expected=true,value=false})
eq(invalidToggle,false);eq(invalidCode,'invalid','conditional payload is reserved for self toggles')
local remembered=world({identities=ids})
eq(strongState(23,remembered).strength,true);eq(strongState(23,remembered).strengthForce,4.5)
eq(strongState(23,remembered).strengthMass,12000);eq(strongState(23,remembered).strengthThrowSpeed,37.5)
eq(strongState(23,remembered).strengthHolding,false,'held objects are never saved')
for _,bad in ipairs({0,21,'2',{},math.huge,0/0}) do
    local ok,code=strong.command(11,'strength_force',23,bad);eq(ok,false);eq(code,'invalid')
end
for _,bad in ipairs({0,100001,1.5}) do eq(strong.command(11,'strength_mass',23,bad),false) end
for _,bad in ipairs({0,101,'20'}) do eq(strong.command(11,'strength_throw_speed',23,bad),false) end
eq(strong.command(11,'strength_throw',23,1),false)
local P=se.OSP.Permissions
eq(P.resolve('guest').permissions.strength,0)
eq(P.resolve('self').permissions.strength,1)
eq(P.resolve('helper').permissions.strength,0);eq(P.resolve('moderator').permissions.strength,0)
eq(P.resolve('admin').permissions.strength,2)
local _,_,role=strong.command(11,'role_save',0,{id='',name='Personal strength',version=0,permissions={strength=1}})
eq(strong.command(11,'role_assign',23,{id=role.template.id}),true)
eq(strong.command(23,'strength_force',23,2),true,'delegate may tune self')
local ok,code=strong.command(23,'strength_mass',47,100);eq(ok,false);eq(code,'denied')
ok,code=strong.command(23,'strength',11,true);eq(ok,false);eq(code,'protected')
eq(registry[root..'strength_force'],4.5,'delegated changes remain temporary')
local own=strongState(23).strength
eq(strong.command(23,'strength',23,{expected=not own,value=own}),false,'stale shortcut never flips state')
eq(strong.command(23,'strength',23,{expected=own,value=not own}),true)
eq(strong.command(11,'strength',23,true),true)
strong.players[23].vehicle=0;strong.tick()
strong.bodies[101]={mass=500,transform={pos={1,0,-2},rot={0,0,0,1}},com={1,0,0}}
strong.rayBody=101
local seq=0
local function context(allowed,overrides)
    seq=seq+1;overrides=overrides or {}
    se.server.ospStrengthInput(23,overrides.host or se.shared.osp.profileHost,
        overrides.join or strongState(23).profileChallenge,overrides.seq or seq,allowed)
end
local function step(pressed,dt)
    strong.now=strong.now+(dt or .21);strong.players[23].pressed=pressed or {}
    se.server.tick();strong.inUpdate=true;se.server.update(1/60);strong.inUpdate=false
    strong.players[23].pressed={}
end
local q=strong.players[23]
context(true);step() -- a valid report alone cannot pick objects
q.inputs={grab=true};step({grab=true})
check(#strong.constraints>0,'server calls controller after a valid context report')
eq(strong.constraints[#strong.constraints].body,101)
check(#strong.orientations>0,'server applies orientation control to a free held body')
eq(strong.orientations[#strong.orientations].body,101)
eq(q.tool,'none','native empty-tool sentinel suppresses tool while carrying')
q.inputs={grab=true,up=true};q.toolBusy=true
-- Both abilities can drive the same player without consuming movement input.
eq(strong.command(11,'fly',23,true),true)
context(true)
se.server.ospFlightInput(23,se.shared.osp.profileHost,strongState(23).profileChallenge,1,true)
step({jump=true},.05);step({},.025);step({jump=true},.05)
eq(q.velocity[3],-9,'Fly movement remains active while Super strength carries a body')
-- A deliberately divergent simulation clock must not invalidate the heartbeat.
strong.physicsNow=strong.now-30;context(true);step()
eq(strongState(23).strengthHolding,true,'Fly-compatible gameplay while holding')
local before=#strong.constraints
local orientationsBefore=#strong.orientations
context(false);step();eq(#strong.constraints,before,'opening UI releases the object before physics')
eq(#strong.orientations,orientationsBefore,'opening UI also stops angular control')
eq(strongState(23).strengthHolding,false)
q.inputs={grab=true};context(true);step({grab=true})
eq(#strong.constraints,before,'held grab after interruption requires release first')
q.inputs={};step();q.inputs={grab=true};context(true);step({grab=true})
check(#strong.constraints>before,'new grab press can resume')
before=#strong.constraints
context(true,{host='wrong-host'});step(nil,.51)
eq(#strong.constraints,before,'invalid heartbeat never refreshes expired context')
context(true,{join=strongState(23).profileChallenge+100});step()
eq(#strong.constraints,before,'another player entry cannot refresh the context')
context('yes');step();eq(#strong.constraints,before,'non-boolean context rejected')
context(true,{seq=.5});step();eq(#strong.constraints,before,'fractional sequence rejected')

q.inputs={};step();context(true);q.inputs={grab=true};step({grab=true})
check(strongState(23).strengthHolding,'fresh context can pick again')
before=#strong.constraints
context(true,{seq=seq-1});context(false);context(true,{seq=seq-2});step()
eq(#strong.constraints,before,'late context cannot undo newer UI denial')
q.inputs={};step();context(true);q.inputs={grab=true};step({grab=true})
eq(strong.command(11,'reset_player',23),true)
step();eq(strongState(23).strength,false);eq(strongState(23).strengthHolding,false)
eq(strongState(23).strengthForce,1);eq(strongState(23).strengthMass,5000)
eq(strongState(23).strengthThrow,false);eq(strongState(23).strengthThrowSpeed,20)
local resetMap=world({identities=ids});eq(strongState(23,resetMap).strength,false)
registry[root..'strength_force']=math.huge
registry[root..'strength_mass']=2.5
registry[root..'strength_throw_speed']=-1
local corruptStrength=world({identities=ids})
eq(strongState(23,corruptStrength).strengthForce,1,'invalid saved force falls back')
eq(strongState(23,corruptStrength).strengthMass,5000,'invalid saved mass falls back')
eq(strongState(23,corruptStrength).strengthThrowSpeed,20,'invalid saved throw speed falls back')

-- Stored custom roles predating strength receive no implicit new grant.
registry['savegame.mod.osp_beta.templates.c8.name']='Legacy helper'
registry['savegame.mod.osp_beta.templates.c8.version']=1
registry['savegame.mod.osp_beta.templates.c8.permissions.heal']=2
registry['savegame.mod.osp_beta.templates.c8.permissions.noclip']=0
local legacyStrength=world();local template
for _,r in ipairs(legacyStrength.api.shared.osp.templates) do if r.id=='c8' then template=r end end
check(template~=nil);eq(template.permissions.strength,0)

-- Infinite ammo follows the same per-profile, permission and entry lifecycle
-- boundaries as other player abilities, with transient stock snapshots.
registry={}
local ammoMap=world({gunAmmo=60});local ammoIds=ammoMap.identities;local ammoApi=ammoMap.api
local function ammoState(who,wld)
    for _,p in ipairs((wld or ammoMap).api.shared.osp.players) do if p.id==who then return p end end
end
local ammoRoot='savegame.mod.osp_beta.players.'..ammoIds[23]..'.'
eq(ammoState(23).ammo,false,'ammo is off by default')
eq(ammoState(23).ammoRestore,false,'restoration is suspended')
eq(ammoMap.command(11,'ammo',23,true),true)
eq(registry[ammoRoot..'ammo'],true,'host saves ammo by profile')
eq(ammoMap.players[23].ammo.gun,9999,'activation supplies ammo before its ACK')
ammoMap.players[23].ammo.gun=4;ammoMap.tick();eq(ammoMap.players[23].ammo.gun,9999,'depletion still replenishes')
local ammoWriteCount=#ammoMap.ammoWrites
local restoreOk,restoreCode=ammoMap.command(11,'ammo_restore',23,true)
eq(restoreOk,false);eq(restoreCode,'unavailable','old clients cannot re-enable restoration')
eq(#ammoMap.ammoWrites,ammoWriteCount,'rejected restore command writes no ammo')
eq(registry[ammoRoot..'ammo_restore'],nil,'rejected restore command saves no preference')
ammoMap.players[23].ammo.gun=7
eq(ammoMap.command(11,'ammo',23,false),true)
eq(ammoMap.players[23].ammo.gun,7,'disable neither restores nor grants another reserve')
eq(#ammoMap.ammoWrites,ammoWriteCount,'disable does not call the ammo setter')

-- Old preferences remain on disk but cannot activate the suspended behavior.
registry[ammoRoot..'ammo_restore']=true
local ammoRemembered=world({identities=ammoIds,gunAmmo=33})
eq(ammoState(23,ammoRemembered).ammo,false,'disabled ability loads in another mission')
eq(ammoState(23,ammoRemembered).ammoRestore,false,'legacy true preference is ignored')
eq(registry[ammoRoot..'ammo_restore'],true,'loading does not erase an old preference')
ammoRemembered.tick();eq(ammoRemembered.players[23].ammo.gun,33,'inactive ability does not supply ammunition')
eq(ammoRemembered.command(11,'ammo',23,true),true)
local trueAmmoRemembered=world({identities=ammoIds,gunAmmo=33})
eq(ammoState(23,trueAmmoRemembered).ammo,true,'enabled ability still persists')
eq(ammoState(23,trueAmmoRemembered).ammoRestore,false)
trueAmmoRemembered.tick();eq(trueAmmoRemembered.players[23].ammo.gun,9999)

-- Death, OSP respawn, heal and reset also avoid every restoration write.
eq(ammoMap.command(11,'ammo',23,true),true)
ammoMap.players[23].ammo.gun=5;ammoMap.players[23].health=0
ammoMap.api.server.tick()
eq(ammoMap.players[23].ammo.gun,5,'death leaves current stock unchanged')
check(ammoState(23).ammo,'death keeps the ability grant')
ammoMap.players[23].health=1;ammoMap.players[23].ammo.gun=25;ammoMap.tick()
eq(ammoMap.players[23].ammo.gun,9999,'live respawn resumes supplying ammo')
ammoMap.players[23].ammo.gun=4
eq(ammoMap.command(11,'respawn',23),true)
eq(ammoMap.players[23].respawnAmmo.gun,4,'respawn does not receive restored stock')
check(ammoState(23).ammo,'respawn keeps the ability')
ammoMap.tick();eq(ammoMap.players[23].ammo.gun,9999)
ammoMap.players[23].ammo.gun=2;ammoMap.players[23].health=0
eq(ammoMap.command(11,'heal',23),true)
eq(ammoMap.players[23].respawnAmmo.gun,2,'dead-player heal performs no restoration')
ammoMap.tick();eq(ammoMap.players[23].ammo.gun,9999)
ammoMap.players[23].ammo.gun=6
eq(ammoMap.command(11,'rule',0,{key='rain',value=.4}),true)
eq(ammoMap.command(11,'reset_player',23),true)
eq(ammoMap.players[23].ammo.gun,6,'reset leaves current stock unchanged')
eq(ammoState(23).ammo,false);eq(ammoState(23).ammoRestore,false)
eq(registry[ammoRoot..'exists'],true,'reset keeps profile identity')
eq(registry['savegame.mod.osp_beta.hostid'],ammoApi.shared.osp.profileHost,'reset keeps host namespace')
eq(registry['savegame.mod.osp_beta.rules.rain'],.4,'player reset keeps global rules')
local resetAmmoMap=world({identities=ammoIds})
eq(ammoState(23,resetAmmoMap).ammo,false);eq(ammoState(23,resetAmmoMap).ammoRestore,false)

-- Permission scopes remain enforced even for the suspended legacy command.
local P=ammoApi.OSP.Permissions
eq(P.resolve('guest').permissions.ammo,0)
eq(P.resolve('self').permissions.ammo,1)
eq(P.resolve('helper').permissions.ammo,0);eq(P.resolve('moderator').permissions.ammo,0)
eq(P.resolve('admin').permissions.ammo,2)
registry['savegame.mod.osp_beta.templates.c9.name']='Legacy ammo role'
registry['savegame.mod.osp_beta.templates.c9.version']=1
registry['savegame.mod.osp_beta.templates.c9.permissions.heal']=2
registry['savegame.mod.osp_beta.templates.c9.permissions.noclip']=0
local oldAmmoRole=world();local oldTemplate
for _,r in ipairs(oldAmmoRole.api.shared.osp.templates) do if r.id=='c9' then oldTemplate=r end end
check(oldTemplate~=nil);eq(oldTemplate.permissions.ammo,0,'legacy template gets no new ammo grant')
local delegatedAmmo=world();local _,_,ammoRole=delegatedAmmo.command(11,'role_save',0,
    {id='',name='Ammo self',version=0,permissions={ammo=1}})
eq(delegatedAmmo.command(11,'role_assign',23,{id=ammoRole.template.id}),true)
local delegatedRoot='savegame.mod.osp_beta.players.'..delegatedAmmo.identities[23]..'.'
eq(delegatedAmmo.command(23,'ammo',23,{expected=false,value=true}),true,'self role may use conditional ammo toggle')
eq(delegatedAmmo.command(23,'ammo_restore',23,false),false,'legacy restore command is suspended')
eq(registry[delegatedRoot..'ammo'],nil,'delegated ammo change is temporary')
eq(registry[delegatedRoot..'ammo_restore'],nil,'suspended restore command saves no preference')
local delegatedOk,delegatedCode=delegatedAmmo.command(23,'ammo',47,true)
eq(delegatedOk,false);eq(delegatedCode,'denied','self ammo grant cannot target another player')
delegatedOk,delegatedCode=delegatedAmmo.command(23,'ammo_restore',47,false)
eq(delegatedOk,false);eq(delegatedCode,'denied','ammo restore alias keeps target scope')
delegatedOk,delegatedCode=delegatedAmmo.command(23,'ammo',47,{expected=false,value=true})
eq(delegatedOk,false);eq(delegatedCode,'invalid','conditional ammo payload remains self-only')
eq(P.resolve('guest').permissions.ammo,0,'guest receives no implicit ammo grant')

-- Empty, unselected mod tools become selectable through the real tool-command
-- boundary. Role grants alone do not enable an otherwise blocked tool.
do
    local t=world({catalog={'sledge','gun','osp_empty_mod'}});local p=t.players[23]
    p.tools.osp_empty_mod=false;p.ammo.osp_empty_mod=0;p.tool='none'
    eq(t.command(11,'role_assign',23,{id='self'}),true)
    eq(p.tools.osp_empty_mod,false,'permission grant does not unlock mod tools')
    eq(t.command(11,'ammo',23,true),true)
    eq(p.ammo.osp_empty_mod,0,'infinite ammo leaves blocked tools alone')
    eq(t.command(11,'tool',23,{id='osp_empty_mod',enabled=true}),true)
    eq(p.tools.osp_empty_mod,true)
    eq(p.ammo.osp_empty_mod,9999,'tool enable supplies empty unselected tool before ACK')
    eq(p.tool,'none','priming does not force a selection')
    eq(t.command(11,'ammo',23,false),true)
    eq(p.ammo.osp_empty_mod,9999,'originally empty tool keeps supplied stock while restoration is suspended')
    eq(t.command(11,'ammo_restore',23,false),false)
    p.ammo.osp_empty_mod=0;eq(t.command(11,'ammo',23,true),true)
    eq(t.command(11,'ammo',23,false),true)
    eq(p.ammo.osp_empty_mod,9999,'restoration disabled keeps supplied stock for an empty tool')
end
-- Noclip yields to vehicles and resumes on foot without changing the grant.
do
    local t=world();local p=t.players[23];p.vehicle=0
    eq(t.command(11,'noclip',23,true),true)
    p.vehicle=333;p.velocity={4,0,2};p.inputs={up=true,shift=true};t.tick()
    eq(p.vehicle,333,'Noclip does not eject a driver every tick')
    eq(p.params.flyMode,false,'native Noclip is suspended inside a vehicle')
    eq(p.velocity[1],4,'Noclip does not overwrite seated movement');eq(p.velocity[3],2)
    eq(t.api.shared.osp.players[2].noclip,true,'the Noclip grant is kept while driving')
    eq(t.command(11,'noclip',23,false),true)
    eq(p.vehicle,333,'disabling Noclip does not eject a driver')
    eq(t.command(11,'noclip',23,true),true)
    eq(p.vehicle,333,'granting Noclip while seated keeps the vehicle')
    eq(p.params.flyMode,false)
    p.vehicle=0;p.inputs={up=true};t.tick()
    eq(p.params.flyMode,true,'native Noclip resumes after leaving the vehicle')
    eq(p.velocity[3],-t.api.shared.osp.players[2].noclipSpeed,'configured Noclip movement resumes')
end
print('PASS server boundary: '..count..' assertions')
