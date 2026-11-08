-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
local count=0
local function check(value,message) assert(value,message);count=count+1 end
local function eq(actual,expected,message)
    check(actual==expected,(message or "equality")..": "..tostring(actual).." ~= "..tostring(expected))
end
local function near(actual,expected,message)
    check(math.abs(actual-expected)<0.0001,(message or "near")..": "..tostring(actual).." ~= "..tostring(expected))
end
local function copy(value)
    if type(value)~="table" then return value end
    local result={}
    for key,item in pairs(value) do result[key]=copy(item) end
    return result
end
local function add(a,b) return {a[1]+b[1],a[2]+b[2],a[3]+b[3]} end
local function sub(a,b) return {a[1]-b[1],a[2]-b[2],a[3]-b[3]} end
local function scale(a,s) return {a[1]*s,a[2]*s,a[3]*s} end
local function rotate(q,v)
    local x,y,z,w=q[1],q[2],q[3],q[4]
    local tx=2*(y*v[3]-z*v[2])
    local ty=2*(z*v[1]-x*v[3])
    local tz=2*(x*v[2]-y*v[1])
    return {v[1]+w*tx+(y*tz-z*ty),v[2]+w*ty+(z*tx-x*tz),v[3]+w*tz+(x*ty-y*tx)}
end
local function multiply(a,b)
    return {a[4]*b[1]+a[1]*b[4]+a[2]*b[3]-a[3]*b[2],
        a[4]*b[2]-a[1]*b[3]+a[2]*b[4]+a[3]*b[1],
        a[4]*b[3]+a[1]*b[2]-a[2]*b[1]+a[3]*b[4],
        a[4]*b[4]-a[1]*b[1]-a[2]*b[2]-a[3]*b[3]}
end
local function world()
    local w={players={},bodies={},shapes={},hits={},calls={constraints={},orientations={},impulses={}},raycasts=0}
    for _,id in ipairs({1,2}) do
        local playerBody=9000+id
        w.bodies[playerBody]={mass=80,dynamic=true,player=id,transform={pos={0,0,0},rot={0,0,0,1}},velocity={0,0,0}}
        w.players[id]={id=id,valid=true,health=1,vehicle=0,screen=0,disabled=false,
            tool="gun",tools={gun=true,sledge=true},inputs={},pressed={},nativeGrab=0,
            camera={pos={0,0,0},rot={0,0,0,1}},bodies={playerBody}}
    end
    local env=setmetatable({server=false,client=false,math=math,table=table,string=string,type=type,
        pairs=pairs,ipairs=ipairs,unpack=unpack,assert=assert,tostring=tostring,tonumber=tonumber,
        select=select,next=next},{__index=_G})
    env.Vec=function(x,y,z) return {x or 0,y or 0,z or 0} end
    env.VecAdd=add;env.VecSub=sub;env.VecScale=scale
    env.VecLength=function(a) return math.sqrt(a[1]^2+a[2]^2+a[3]^2) end
    env.TransformToParentVec=function(t,v) return rotate(t.rot,v) end
    env.TransformToParentPoint=function(t,v) return add(t.pos,rotate(t.rot,v)) end
    env.TransformToLocalPoint=function(t,v)
        local localRotation={-t.rot[1],-t.rot[2],-t.rot[3],t.rot[4]}
        return rotate(localRotation,sub(v,t.pos))
    end
    env.TransformToLocalTransform=function(parent,child)
        local q=parent.rot
        return {pos=env.TransformToLocalPoint(parent,child.pos),rot=multiply({-q[1],-q[2],-q[3],q[4]},child.rot)}
    end
    env.QuatRotateQuat=multiply
    env.IsPlayerValid=function(p) return w.players[p]~=nil and w.players[p].valid end
    env.GetAllPlayers=function() return {1,2} end
    env.GetPlayerBodies=function(p) return w.players[p].bodies end
    env.GetPlayerHealth=function(p) return w.players[p].health end
    env.GetPlayerVehicle=function(p) return w.players[p].vehicle end
    env.GetPlayerScreen=function(p) return w.players[p].screen end
    env.IsPlayerDisabled=function(p) return w.players[p].disabled end
    env.GetPlayerCameraTransform=function(p) return copy(w.players[p].camera) end
    env.InputDown=function(input,p) return w.players[p].inputs[input]==true end
    env.InputPressed=function(input,p) return w.players[p].pressed[input]==true end
    env.GetPlayerTool=function(p) return w.players[p].tool end
    env.SetPlayerTool=function(tool,p)
        assert(tool=="none" or w.players[p].tools[tool],"cannot select disabled tool")
        w.players[p].tool=tool
    end
    env.IsToolEnabled=function(tool,p) return w.players[p].tools[tool]==true end
    env.QueryRequire=function(layers)
        w.required=layers;w.rejected={}
    end
    env.QueryRejectBody=function(body) w.rejected[body]=true end
    env.QueryRaycast=function(origin,direction,reach)
        w.raycasts=w.raycasts+1
        eq(w.required,"physical","query keeps physical geometry in ray")
        eq(reach,env.OSP.strength.reach,"ray is bounded by configured reach")
        w.lastRejects=copy(w.rejected)
        local hit
        for _,candidate in ipairs(w.hits) do
            local shape=candidate.shape
            local body=w.shapes[shape] and w.shapes[shape].body
            if not body or not w.rejected[body] then hit=candidate;break end
        end
        w.required=nil;w.rejected={}
        if not hit then return false,0,{0,0,0},0 end
        -- Engine order is hit, distance, world normal, then shape handle.
        return true,hit.distance,hit.normal or {0,0,1},hit.shape
    end
    env.IsHandleValid=function(handle) return w.bodies[handle]~=nil or w.shapes[handle]~=nil end
    env.GetShapeBody=function(shape) return w.shapes[shape].body end
    env.GetBodyMass=function(body) return w.bodies[body].mass end
    env.IsBodyDynamic=function(body) return w.bodies[body].dynamic end
    env.IsBodyJointedToStatic=function(body) return w.bodies[body].jointed==true end
    env.GetBodyPlayer=function(body) return w.bodies[body].player or 0 end
    env.GetBodyVehicle=function(body) return w.bodies[body].vehicle or 0 end
    env.GetBodyTransform=function(body) return copy(w.bodies[body].transform) end
    env.GetBodyCenterOfMass=function(body) return copy(w.bodies[body].com or {0,0,0}) end
    env.GetBodyVelocity=function(body) return copy(w.bodies[body].velocity or {0,0,0}) end
    env.GetPlayerGrabBody=function(p) return w.players[p].nativeGrab or 0 end
    env.ReleasePlayerGrab=function(p) w.players[p].nativeGrab=0;w.nativeReleases=(w.nativeReleases or 0)+1 end
    env.ConstrainPosition=function(bodyA,bodyB,pointA,pointB,maxVelocity,maxImpulse)
        w.calls.constraints[#w.calls.constraints+1]={bodyA=bodyA,bodyB=bodyB,pointA=copy(pointA),pointB=copy(pointB),
            maxVelocity=maxVelocity,maxImpulse=maxImpulse}
    end
    env.ConstrainOrientation=function(bodyA,bodyB,quatA,quatB,maxAngularVelocity,maxAngularImpulse)
        w.calls.orientations[#w.calls.orientations+1]={bodyA=bodyA,bodyB=bodyB,
            quatA=copy(quatA),quatB=copy(quatB),maxAngularVelocity=maxAngularVelocity,maxAngularImpulse=maxAngularImpulse}
    end
    env.ApplyBodyImpulse=function(body,position,impulse)
        w.calls.impulses[#w.calls.impulses+1]={body=body,position=copy(position),impulse=copy(impulse)}
    end
    env.SetPlayerTransform=function() error("strength must not teleport players") end
    env.SetBodyTransform=function() error("strength must not teleport bodies") end
    env.SetBodyDynamic=function() error("strength must not change dynamic state") end
    env.SetBodyGravityScale=function() error("strength must preserve gravity") end
    env.SetBodyMass=function() error("strength must preserve mass") end
    env.SetShapeCollisionFilter=function() error("strength must preserve collision masks") end
    env.DisablePlayerInput=function() error("strength must not mutate player input") end
    env.InputClear=function() error("strength must not clear player input") end
    local chunk=assert(loadfile(arg[1]));setfenv(chunk,env);chunk()
    w.api=env
    function w.addBody(body,shape,options)
        options=options or {}
        w.bodies[body]={mass=options.mass or 500,dynamic=options.dynamic~=false,jointed=options.jointed==true,
            player=options.player or 0,vehicle=options.vehicle or 0,
            transform=copy(options.transform or {pos={0,0,-2},rot={0,0,0,1}}),
            com=copy(options.com or {0,0,0}),velocity=copy(options.velocity or {0,0,0})}
        w.shapes[shape]={body=body}
        w.hits={{shape=shape,distance=options.distance or 2}}
    end
    function w.input(p,down,pressed)
        w.players[p].inputs=down or {};w.players[p].pressed=pressed or {}
    end
    function w.clearPressed(p) w.players[p].pressed={} end
    return w
end

local function ability(overrides)
    local e={strength=true,strengthForce=2,strengthMass=5000,strengthThrow=false,strengthThrowSpeed=20,freeze=false}
    for key,value in pairs(overrides or {}) do e[key]=value end
    return e
end

local function arm(controller,w,p,e)
    w.input(p,{},{});controller:tick(p,e,true)
end

local function grab(controller,w,p,e)
    w.input(p,{grab=true},{grab=true});controller:tick(p,e,true);w.clearPressed(p)
end

-- Loading the full expanded entry point must not need game APIs until active.
do
    local w=world();local controller=w.api.OSP.Strength.new()
    w.api.InputDown=nil;w.api.InputPressed=nil;w.api.ReleasePlayerGrab=nil;w.api.QueryRaycast=nil
    controller:tick(1,{strength=false},false)
    controller:update(1,{strength=false},1/60,false)
    controller:release(1,true);controller:remove(1);controller:reset()
    eq(controller:heldBody(1),0,"empty lifecycle calls tolerate legacy mocks")
end

-- A held grab on first activation is ignored until release and a fresh press.
do
    local w=world();local controller=w.api.OSP.Strength.new();local e=ability()
    w.addBody(101,201)
    w.players[1].nativeGrab=101
    w.input(1,{grab=true},{})
    controller:tick(1,e,true)
    eq(controller:heldBody(1),0,"enable while held cannot acquire")
    eq(w.nativeReleases,1,"enabled grab cancels the native controller")
    eq(w.raycasts,0,"held activation does not raycast")
    w.input(1,{},{});controller:tick(1,e,true)
    grab(controller,w,1,e)
    eq(controller:heldBody(1),101,"fresh press acquires the hit body")
    eq(w.lastRejects[9001],true,"ray rejects current player body")
    eq(w.lastRejects[9002],true,"ray rejects every other player body")
    eq(w.players[1].tool,"none","tool selection is suppressed while carrying")
end

-- Hit point is stored in body-local coordinates; constraint is bounded by dt, force and mass.
do
    local w=world();local controller=w.api.OSP.Strength.new();local e=ability({strengthMass=1000,strengthForce=3})
    local yaw={0,math.sin(math.pi/4),0,math.cos(math.pi/4)}
    w.addBody(110,210,{mass=900,transform={pos={0,0,-2},rot=yaw}})
    arm(controller,w,1,e);grab(controller,w,1,e)
    eq(controller:heldBody(1),110)
    near(w.api.TransformToParentPoint(w.bodies[110].transform,{0,0,0})[3],-2,"captured local point is exact ray hit")
    controller:update(1,e,.01,true)
    eq(#w.calls.constraints,1,"one physics constraint is issued")
    local c=w.calls.constraints[1]
    eq(c.bodyA,110);eq(c.bodyB,0);near(c.pointA[1],0);near(c.pointA[3],-2)
    near(c.pointB[1],0);near(c.pointB[2],0);near(c.pointB[3],-2)
    near(c.maxVelocity,24);near(c.maxImpulse,900*180*3*.01,"free-body impulse supports responsive following")
    w.bodies[110].transform.pos={.5,0,-2}
    controller:update(1,e,.02,true)
    near(w.calls.constraints[2].pointA[1],.5,"constraint tracks the captured local point")
    near(w.calls.constraints[2].maxImpulse,900*180*3*.02,"physics dt changes impulse cap")
    eq(w.players[1].tool,"none","tool stays suppressed during physics updates")
end

-- Static geometry remains the nearest hit and blocks a valid object behind it.
do
    local w=world();local controller=w.api.OSP.Strength.new();local e=ability()
    w.addBody(120,220,{mass=0,dynamic=false})
    w.bodies[121]={mass=50,dynamic=true,player=0,vehicle=0,transform={pos={0,0,-3},rot={0,0,0,1}},com={0,0,0}}
    w.shapes[221]={body=121}
    w.hits={{shape=220,distance=1},{shape=221,distance=2}}
    arm(controller,w,1,e);grab(controller,w,1,e)
    eq(w.raycasts,1,"one server ray determines occlusion")
    eq(controller:heldBody(1),0,"static wall rejects hit without seeing through it")
    eq(w.players[1].nativeGrab,0,"native grab is released when hit is rejected")
end

-- Mass, static bodies, player ownership and occupied vehicles reject safely.
for _,case in ipairs({
    {name="over mass",options={mass=6000},limit=5000},
    {name="static body with positive mass",options={mass=20,dynamic=false}},
    {name="jointed over mass",options={mass=6000,jointed=true},limit=5000},
    {name="player body",options={mass=80,player=2}},
    {name="occupied vehicle",options={mass=500,vehicle=77},occupant=2},
}) do
    local w=world();local controller=w.api.OSP.Strength.new();local e=ability({strengthMass=case.limit or 5000})
    w.addBody(130,230,case.options)
    if case.occupant then w.players[case.occupant].vehicle=77 end
    arm(controller,w,1,e);grab(controller,w,1,e)
    eq(controller:heldBody(1),0,case.name.." cannot be acquired")
end

-- Doors may move on their existing joints, without a competing orientation lock.
do
    local w=world();local controller=w.api.OSP.Strength.new();local e=ability()
    w.addBody(135,235,{mass=80,jointed=true,com={1,0,0}})
    arm(controller,w,1,e);grab(controller,w,1,e)
    eq(controller:heldBody(1),135,"dynamic door attached to the scenery can be grabbed")
    controller:update(1,e,1/60,true)
    eq(#w.calls.constraints,1,"door receives a positional constraint")
    near(w.calls.constraints[1].pointA[1],0,"door still uses the grip rather than its center of mass")
    near(w.calls.constraints[1].maxVelocity,6,"door keeps its approved speed limit")
    near(w.calls.constraints[1].maxImpulse,80*30*2/60,"door keeps its approved force budget")
    eq(#w.calls.orientations,0,"door joint controls its own rotation")
    w.bodies[135].transform.rot={0,math.sin(math.pi/4),0,math.cos(math.pi/4)}
    controller:tick(1,e,true);controller:update(1,e,1/60,true)
    eq(controller:heldBody(1),135,"rotation on the hinge does not end the grab")
    eq(#w.calls.orientations,0,"hinged door never receives a camera orientation lock")
    eq(w.bodies[135].jointed,true,"grab leaves the joint intact")
    w.bodies[135].dynamic=false
    controller:update(1,e,1/60,true)
    eq(controller:heldBody(1),0,"body becoming static ends the grab")
    eq(w.players[1].tool,"gun","door release restores the selected tool")
end

-- Free bodies keep their captured orientation relative to the camera, even at an off-center grip.
do
    local w=world();local controller=w.api.OSP.Strength.new();local e=ability({strengthForce=3})
    local s=math.sqrt(.5)
    w.players[1].camera.rot={0,s,0,s}
    w.addBody(136,236,{mass=80,transform={pos={-2,2,0},rot={0,0,s,s}}})
    arm(controller,w,1,e);grab(controller,w,1,e)
    eq(#w.calls.orientations,0,"tick never submits angular physics constraints")
    controller:update(1,e,.01,true)
    eq(#w.calls.orientations,1,"free body receives orientation control")
    local a=w.calls.orientations[1]
    eq(a.bodyA,136);eq(a.bodyB,0)
    local x=rotate(a.quatB,{1,0,0})
    near(x[1],0);near(x[2],1);near(x[3],0,"initial target preserves the body pose")
    near(a.maxAngularVelocity,18,"angular velocity is bounded")
    near(a.maxAngularImpulse,80*180*3*.01*4,"off-center lever scales the bounded angular impulse")

    w.players[1].camera.rot={0,0,0,1}
    controller:update(1,e,.02,true)
    a=w.calls.orientations[2]
    local y=rotate(a.quatB,{0,1,0});local z=rotate(a.quatB,{0,0,1})
    x=rotate(a.quatB,{1,0,0})
    near(x[1],0);near(x[2],1);near(x[3],0)
    near(y[1],0);near(y[2],0);near(y[3],-1)
    near(z[1],-1);near(z[2],0);near(z[3],0,"target follows camera with the original relative orientation")
    near(a.maxAngularImpulse,80*180*3*.02*4,"angular impulse follows the physics timestep")
    w.bodies[136].jointed=true
    controller:update(1,e,.02,true)
    eq(#w.calls.orientations,2,"joining static geometry stops the orientation lock")
    w.bodies[136].jointed=false
    w.input(1,{},{});controller:tick(1,e,true);controller:update(1,e,.02,true)
    eq(#w.calls.orientations,2,"release removes angular control")
    eq(w.players[1].tool,"gun","orientation control preserves tool restoration")
end

-- Translation acts at the COM without changing the pose implied by the off-center grip.
do
    local w=world();local controller=w.api.OSP.Strength.new();local e=ability()
    local s=math.sqrt(.5)
    w.addBody(137,237,{mass=1,com={1,0,0},transform={pos={.5,0,-2},rot={0,s,0,s}}})
    arm(controller,w,1,e);grab(controller,w,1,e)
    controller:update(1,e,1/60,true)
    local c=w.calls.constraints[1]
    near(c.pointA[1],.5);near(c.pointA[3],-3,"force acts at the world-space COM")
    near(c.pointB[1],.5);near(c.pointB[3],-3,"initial target preserves the original grip pose")

    w.players[1].camera.rot={0,math.sin(math.pi/12),0,math.cos(math.pi/12)}
    controller:update(1,e,1/60,true)
    c=w.calls.constraints[2]
    near(c.pointB[1],.5*math.sqrt(3)/2-1.5)
    near(c.pointB[3],-.25-3*math.sqrt(3)/2,"COM target follows the captured off-center pose")
    check(c.maxVelocity*.15>=2*math.sqrt(2),"speed budget allows a 90-degree turn at 2m within 150ms")
    check(w.calls.orientations[2].maxAngularVelocity*.1>=math.pi/2,"angular budget allows a 90-degree turn within 100ms")
end

-- A large turn must not command a shortcut through the camera, even if the body stays blocked.
for _,case in ipairs({
    {origin={0,0,0},position={0,0,-2},initial={0,0,0,1},target={0,1,0,0},radius=2},
    {origin={5,2,-3},position={5,2,-5},initial={0,0,0,1},target={0,1,0,0},radius=2},
    {origin={0,0,0},position={0,-2,0},initial={-math.sqrt(.5),0,0,math.sqrt(.5)},
        target={math.sqrt(.5),0,0,math.sqrt(.5)},radius=2},
    {origin={0,0,0},position={0,0,-2},initial={0,0,0,1},target={0,1,0,0},blocked={0,0,-3},radius=2.75},
}) do
    local w=world();local controller=w.api.OSP.Strength.new();local e=ability()
    w.players[1].camera={pos=case.origin,rot=case.initial}
    w.addBody(138,238,{mass=1,transform={pos=case.position,rot={0,0,0,1}}})
    arm(controller,w,1,e);grab(controller,w,1,e)
    if case.blocked then w.bodies[138].transform.pos=case.blocked end
    w.players[1].camera.rot=case.target
    for _=1,20 do
        controller:update(1,e,1/60,true)
        local c=w.calls.constraints[#w.calls.constraints]
        local start,goal=sub(c.pointA,case.origin),sub(c.pointB,case.origin)
        local delta=sub(goal,start)
        local lengthSquared=delta[1]^2+delta[2]^2+delta[3]^2
        local projection=-(start[1]*delta[1]+start[2]*delta[2]+start[3]*delta[3])/lengthSquared
        projection=math.max(0,math.min(1,projection))
        local closest=add(start,scale(delta,projection))
        check(w.api.VecLength(closest)>1.8,"commanded segment stays outside the camera region while body is blocked")
        near(w.api.VecLength(goal),case.radius,"turn waypoint interpolates the carrying radius without crossing zero")
    end
end

-- Native grabs by another player and custom ownership locks are exclusive.
do
    local w=world();local controller=w.api.OSP.Strength.new();local e1=ability();local e2=ability()
    w.addBody(140,240)
    arm(controller,w,1,e1);arm(controller,w,2,e2)
    w.players[2].nativeGrab=140
    grab(controller,w,1,e1)
    eq(controller:heldBody(1),0,"another player's native grab locks the body")
    w.players[2].nativeGrab=0;grab(controller,w,1,e1)
    eq(controller:heldBody(1),140,"first custom holder owns the body")
    grab(controller,w,2,e2)
    eq(controller:heldBody(2),0,"second custom holder cannot acquire the same body")
    eq(controller:heldBody(1),140,"second attempt does not steal the owner lock")
end

-- Tool restoration waits out use-tool and respects policy/current selection changes.
do
    local w=world();local controller=w.api.OSP.Strength.new();local e=ability()
    w.addBody(150,250)
    arm(controller,w,1,e);grab(controller,w,1,e)
    w.input(1,{usetool=true},{})
    controller:tick(1,e,true)
    eq(w.players[1].tool,"none","holding never selects a firing tool")
    w.input(1,{usetool=true},{})
    controller:tick(1,e,true)
    eq(w.players[1].tool,"none","release waits while use-tool is held")
    w.input(1,{},{});controller:tick(1,e,true)
    eq(w.players[1].tool,"gun","previous enabled tool restores after use release")

    w.players[1].tool="gun";w.players[1].tools.gun=true
    grab(controller,w,1,e)
    w.players[1].tools.gun=false
    w.input(1,{},{});controller:tick(1,e,true)
    eq(w.players[1].tool,"none","disabled previous tool is never restored")

    w.players[1].tools.gun=true;w.players[1].tool="gun"
    grab(controller,w,1,e)
    w.players[1].tool="sledge"
    w.input(1,{grab=true},{})
    controller:tick(1,e,true)
    eq(w.players[1].tool,"none","carry keeps all tool firing suppressed")
    w.input(1,{},{});controller:tick(1,e,true)
    eq(w.players[1].tool,"sledge","latest selection is restored instead of the stale original")
end

-- Regrabbing while use-tool is held preserves deferred restoration without firing.
for _,case in ipairs({
    {name="previous tool",expected="gun"},
    {name="blocked tool",blocked=true,expected="none"},
    {name="new selection",selection="sledge",expected="sledge"},
    {name="initially empty",initial="none",expected="none"},
    {name="after throw",throw=true,expected="gun"},
}) do
    local w=world();local controller=w.api.OSP.Strength.new();local e=ability({strengthThrow=case.throw==true})
    if case.initial then w.players[1].tool=case.initial end
    w.addBody(151,251)
    arm(controller,w,1,e);grab(controller,w,1,e)
    if case.throw then
        w.input(1,{grab=true,usetool=true},{usetool=true});controller:tick(1,e,true)
        eq(#w.calls.impulses,1,"first use throws once")
    end
    w.input(1,{usetool=true},{});controller:tick(1,e,true)
    eq(controller:heldBody(1),0,"first object releases before regrabbing")
    eq(w.players[1].tool,"none","tool waits for use release")
    if case.blocked then w.players[1].tools.gun=false end
    if case.selection then w.players[1].tool=case.selection end

    w.addBody(152,252)
    w.input(1,{grab=true,usetool=true},{grab=true});controller:tick(1,e,true)
    eq(controller:heldBody(1),152,"new object can be grabbed while use is held")
    controller:update(1,e,1/60,true)
    eq(w.players[1].tool,"none","regrab keeps the selected tool suppressed")
    if case.throw then eq(#w.calls.impulses,1,"held use does not throw the new object") end

    w.input(1,{usetool=true},{});controller:tick(1,e,true)
    controller:update(1,e,1/60,true)
    eq(controller:heldBody(1),0,"second object releases")
    eq(w.players[1].tool,"none","second release still waits for held use")
    w.input(1,{},{usetool=true});controller:tick(1,e,true)
    eq(w.players[1].tool,"none","pressed use without down also defers restoration")
    w.input(1,{},{});controller:tick(1,e,true)
    eq(w.players[1].tool,case.expected,case.name.." restores correctly after regrab")
end

-- Throw speed is a desired world velocity; impulse cancels existing velocity and uses world COM.
do
    local w=world();local controller=w.api.OSP.Strength.new()
    local e=ability({strengthMass=100,strengthThrow=true,strengthThrowSpeed=5})
    local yaw={0,math.sin(math.pi/4),0,math.cos(math.pi/4)}
    w.addBody(160,260,{mass=10,transform={pos={0,0,-2},rot=yaw},com={1,0,0},velocity={1,2,3}})
    arm(controller,w,1,e);grab(controller,w,1,e)
    w.input(1,{grab=true,usetool=true},{usetool=true})
    controller:tick(1,e,true)
    eq(#w.calls.impulses,1,"throw applies exactly one impulse")
    local impulse=w.calls.impulses[1]
    eq(impulse.body,160)
    near(impulse.position[1],0);near(impulse.position[2],0);near(impulse.position[3],-3,"local COM is transformed to world position")
    near(impulse.impulse[1],-10);near(impulse.impulse[2],-20);near(impulse.impulse[3],-80,"launch reaches camera-forward velocity despite initial motion")
    eq(controller:heldBody(1),0,"throw drops custom ownership")
    controller:tick(1,e,true)
    eq(#w.calls.impulses,1,"continuous use-tool hold cannot throw twice")
    eq(w.players[1].tool,"none","weapon stays suppressed until use release")

    w.input(1,{},{});controller:tick(1,e,true)
    eq(w.players[1].tool,"gun","tool restores after throw input is released")
end

-- Throw disabled, deletion, tether break, death and UI interruption never preserve a stale hold.
do
    local w=world();local controller=w.api.OSP.Strength.new();local e=ability()
    w.addBody(170,270)
    arm(controller,w,1,e);grab(controller,w,1,e)
    w.input(1,{grab=true,usetool=true},{usetool=true});controller:tick(1,e,true)
    eq(#w.calls.impulses,0,"use-tool does not throw when throw is disabled")
    eq(controller:heldBody(1),170,"non-throw use leaves the body held")
    w.input(1,{grab=true},{});w.bodies[170]=nil
    controller:update(1,e,1/60,true)
    eq(controller:heldBody(1),0,"deleted body releases ownership before physics")
    eq(w.players[1].tool,"gun","valid current player restores the still-enabled tool")

    w.addBody(171,271)
    grab(controller,w,1,e)
    w.bodies[171].transform.pos={8,0,-2}
    controller:update(1,e,1/60,true)
    eq(controller:heldBody(1),0,"tether error above break distance releases body")

    w.addBody(172,272)
    w.input(1,{},{});controller:tick(1,e,true);grab(controller,w,1,e)
    w.players[1].health=0;w.input(1,{grab=true},{})
    controller:tick(1,e,true)
    eq(controller:heldBody(1),0,"death releases body even if caller allowed context")
    w.players[1].health=1;controller:tick(1,e,true)
    eq(controller:heldBody(1),0,"held grab after death must be released first")
    w.input(1,{},{});controller:tick(1,e,true);grab(controller,w,1,e)
    controller:tick(1,e,false)
    eq(controller:heldBody(1),0,"UI/context loss releases custom ownership")
    controller:tick(1,e,true)
    eq(controller:heldBody(1),0,"context restoration requires releasing and pressing again")
    w.input(1,{},{});controller:tick(1,e,true);grab(controller,w,1,e)
    eq(controller:heldBody(1),172,"fresh press reacquires after interruption")
end

-- remove drops lock state without writing a tool to a recycled player ID.
do
    local w=world();local controller=w.api.OSP.Strength.new();local e=ability()
    w.addBody(180,280)
    arm(controller,w,1,e);grab(controller,w,1,e)
    eq(controller:heldBody(1),180)
    controller:remove(1)
    eq(controller:heldBody(1),0,"remove drops ownership")
    w.players[1]={id=1,valid=true,health=1,vehicle=0,screen=0,disabled=false,tool="sledge",
        tools={gun=true,sledge=true},inputs={},pressed={},nativeGrab=0,camera={pos={0,0,0},rot={0,0,0,1}},bodies={9001}}
    controller:remove(1)
    eq(w.players[1].tool,"sledge","recycled ID never receives the previous occupant's tool")
end

print("PASS strength controller behavior: "..count.." assertions")
