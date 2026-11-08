-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
OSP.Strength = {}
local noTool="none"
local function emptyTool(value) return value==nil or value=="" or value==noTool end

local function finite(value)
    return type(value)=="number" and value==value and value>-math.huge and value<math.huge
end

local function vector(value)
    return type(value)=="table" and finite(value[1]) and finite(value[2]) and finite(value[3])
end

local function distance(a,b)
    local x,y,z=a[1]-b[1],a[2]-b[2],a[3]-b[3]
    return math.sqrt(x*x+y*y+z*z)
end

local function bounded(value,default,minimum,maximum)
    if not finite(value) then value=default end
    if value<minimum then return minimum end
    if value>maximum then return maximum end
    return value
end

local function strengthConfig()
    return OSP.strength or {reach=3,maxVelocity=24,maxAngularVelocity=18,acceleration=180,
        jointedMaxVelocity=6,jointedAcceleration=30,breakDistance=6,
        minForce=1,maxForce=20,minMass=1,maxMass=100000,minThrowSpeed=1,maxThrowSpeed=100}
end

local function down(input,p)
    return type(InputDown)=="function" and InputDown(input,p)==true
end

local function pressed(input,p)
    return type(InputPressed)=="function" and InputPressed(input,p)==true
end

local function allPlayers()
    if type(GetAllPlayers)~="function" then return nil end
    local players=GetAllPlayers()
    return type(players)=="table" and players or nil
end

local function playerBodies(p)
    if type(GetPlayerBodies)~="function" then return nil end
    local bodies=GetPlayerBodies(p)
    return type(bodies)=="table" and bodies or nil
end

local function rejectPlayerBodies()
    local players=allPlayers()
    if not players or type(QueryRejectBody)~="function" or type(GetPlayerBodies)~="function" then return false end
    for _,p in ipairs(players) do
        local bodies=playerBodies(p)
        if not bodies then return false end
        for _,body in ipairs(bodies) do
            if type(body)=="number" and body~=0 then QueryRejectBody(body) end
        end
    end
    return true
end

local function contextAllowed(p,e)
    if e.freeze==true then return false end
    if type(GetPlayerHealth)=="function" and GetPlayerHealth(p)<=0 then return false end
    if type(GetPlayerVehicle)=="function" and GetPlayerVehicle(p)~=0 then return false end
    if type(GetPlayerScreen)=="function" and GetPlayerScreen(p)~=0 then return false end
    if type(IsPlayerDisabled)=="function" and IsPlayerDisabled(p) then return false end
    return true
end

local function occupiedVehicle(body,players)
    local vehicle=GetBodyVehicle(body)
    if vehicle==0 then return false end
    for _,p in ipairs(players) do
        if GetPlayerVehicle(p)==vehicle then return true end
    end
    return false
end

local function heldByOtherPlayer(body,players,current)
    if type(GetPlayerGrabBody)~="function" then return nil end
    for _,p in ipairs(players) do
        if p~=current and GetPlayerGrabBody(p)==body then return true end
    end
    return false
end

function OSP.Strength.new()
    local controller={}
    local states,owners={},{}

    local function stateFor(p,create)
        local state=states[p]
        if not state and create then
            state={enabled=false,waitGrabRelease=false,body=0}
            states[p]=state
        end
        return state
    end

    local function clearBody(p,state)
        if state.body~=0 then
            if owners[state.body]==p then owners[state.body]=nil end
            state.body=0
            state.localPoint=nil
            state.localRotation=nil
            state.distance=nil
            state.throwDone=false
        end
    end

    local function tryRestore(p,state)
        if not state.restorePending then return false end
        if down("usetool",p) or pressed("usetool",p) then return true end
        state.waitUseRelease=false
        if emptyTool(GetPlayerTool(p)) and not emptyTool(state.savedTool)
            and IsToolEnabled(state.savedTool,p) then
            SetPlayerTool(state.savedTool,p)
        end
        state.savedTool=nil
        state.restorePending=false
        return false
    end

    local function discardEmpty(p,state)
        if state.body==0 and not state.restorePending and not state.waitGrabRelease and not state.enabled then states[p]=nil end
    end

    local function release(p,waitUseRelease,restore)
        local state=stateFor(p,false)
        if not state then return end
        clearBody(p,state)
        if down("grab",p) then state.waitGrabRelease=true else state.waitGrabRelease=false end
        if not emptyTool(state.savedTool) then
            state.restorePending=true
            -- The edge counts too: some input contexts report InputPressed
            -- before InputDown has become visible to the server.
            state.waitUseRelease=down("usetool",p)
                or (waitUseRelease==true and pressed("usetool",p))
        end
        if restore~=false then tryRestore(p,state) end
        discardEmpty(p,state)
    end

    local function validBody(body,p,e,players)
        if type(body)~="number" or body==0 or type(IsHandleValid)~="function" or not IsHandleValid(body) then return false end
        if type(GetBodyMass)~="function" then return false end
        if type(IsBodyDynamic)~="function" or not IsBodyDynamic(body) then return false end
        local mass=GetBodyMass(body)
        local cfg=strengthConfig()
        local maxMass=bounded(e.strengthMass,5000,cfg.minMass or 1,cfg.maxMass or 100000)
        if not finite(mass) or mass<=0 or mass>maxMass then return false end
        if type(GetBodyPlayer)~="function" or GetBodyPlayer(body)~=0 then return false end
        if type(GetBodyVehicle)~="function" or type(GetPlayerVehicle)~="function" then return false end
        if occupiedVehicle(body,players) then return false end
        if owners[body] and owners[body]~=p then return false end
        if heldByOtherPlayer(body,players,p)~=false then return false end
        return true,mass
    end

    local function targetAtDistance(camera,distanceValue)
        if type(camera)~="table" or not vector(camera.pos) or type(TransformToParentVec)~="function" then return nil,nil end
        local direction=TransformToParentVec(camera,Vec(0,0,-1))
        if not vector(direction) then return nil,nil end
        local length=math.sqrt(direction[1]^2+direction[2]^2+direction[3]^2)
        if not finite(length) or length<0.000001 then return nil,nil end
        direction=VecScale(direction,1/length)
        local target=VecAdd(camera.pos,VecScale(direction,distanceValue))
        return target,direction
    end

    local function carryWaypoint(origin,current,target)
        local from,to=VecSub(current,origin),VecSub(target,origin)
        local fromRadius,toRadius=distance(current,origin),distance(target,origin)
        if toRadius<0.001 then return current end
        if fromRadius<0.001 then return target end
        from,to=VecScale(from,1/fromRadius),VecScale(to,1/toRadius)
        local cosine=math.max(-1,math.min(1,from[1]*to[1]+from[2]*to[2]+from[3]*to[3]))
        local step=math.pi/4
        if cosine>=math.cos(step) then return target end
        local tangent=VecSub(to,VecScale(from,cosine))
        local length=math.sqrt(tangent[1]^2+tangent[2]^2+tangent[3]^2)
        if length<0.000001 then
            -- Opposite directions have two equally short routes; choose a stable side.
            tangent=Vec(-from[3],0,from[1])
            length=math.sqrt(tangent[1]^2+tangent[3]^2)
            if length<0.000001 then
                tangent=Vec(0,-from[3],from[2])
                length=math.sqrt(tangent[2]^2+tangent[3]^2)
            end
        end
        local direction=VecAdd(VecScale(from,math.cos(step)),VecScale(tangent,math.sin(step)/length))
        local radius=fromRadius+(toRadius-fromRadius)*step/math.acos(cosine)
        -- Start from the physical body every step, so an obstruction cannot advance the route.
        return VecAdd(origin,VecScale(direction,radius))
    end

    local function tetherValid(state,p)
        if state.body==0 then return false end
        if type(GetBodyTransform)~="function" or type(TransformToParentPoint)~="function" then return false end
        local camera=GetPlayerCameraTransform(p)
        local target=targetAtDistance(camera,state.distance)
        local transform=GetBodyTransform(state.body)
        if not target or type(transform)~="table" then return false end
        local heldPoint=TransformToParentPoint(transform,state.localPoint)
        if not vector(heldPoint) then return false end
        return distance(heldPoint,target)<=((strengthConfig().breakDistance) or 6)
    end

    local function acquire(p,e,state)
        local players=allPlayers()
        if not players or type(QueryRequire)~="function" or type(QueryRaycast)~="function"
            or type(GetPlayerCameraTransform)~="function" or type(GetShapeBody)~="function"
            or type(TransformToLocalPoint)~="function" or type(TransformToLocalTransform)~="function"
            or type(QuatRotateQuat)~="function" or type(ConstrainOrientation)~="function"
            or type(IsBodyJointedToStatic)~="function" or type(GetBodyCenterOfMass)~="function" then return end
        local camera=GetPlayerCameraTransform(p)
        local origin=type(camera)=="table" and camera.pos or nil
        local reach=strengthConfig().reach or 3
        local target,direction=targetAtDistance(camera,reach)
        if not target or not direction or not vector(origin) then return end
        QueryRequire("physical")
        if not rejectPlayerBodies() then return end
        -- Keep static geometry in the query so it blocks objects behind it.
        local hit,hitDistance,_,shape=QueryRaycast(origin,direction,reach)
        if not hit or not finite(hitDistance) or hitDistance<0 or hitDistance>reach
            or type(shape)~="number" or shape==0 or type(IsHandleValid)~="function" or not IsHandleValid(shape) then return end
        local body=GetShapeBody(shape)
        local valid,mass=validBody(body,p,e,players)
        if not valid then return end
        if owners[body] and owners[body]~=p then return end
        local hitPoint=VecAdd(origin,VecScale(direction,hitDistance))
        local bodyTransform=GetBodyTransform(body)
        local localPoint=TransformToLocalPoint(bodyTransform,hitPoint)
        if not vector(localPoint) then return end
        state.body=body
        state.localPoint=localPoint
        state.localRotation=TransformToLocalTransform(camera,bodyTransform).rot
        state.distance=hitDistance
        state.mass=mass
        state.throwDone=false
        owners[body]=p
        local selected=GetPlayerTool(p)
        -- Regrabbing must preserve a tool still waiting for use-tool release.
        if not emptyTool(selected) or not state.restorePending then state.savedTool=selected end
        state.restorePending=not emptyTool(state.savedTool)
        state.waitUseRelease=false
        SetPlayerTool(noTool,p)
    end

    local function validateHeld(p,e,state)
        if state.body==0 then return false end
        local players=allPlayers()
        if not players then return false end
        local valid,mass=validBody(state.body,p,e,players)
        if not valid then return false end
        state.mass=mass
        return tetherValid(state,p)
    end

    local function suppressTool(p,state)
        if state.body==0 or type(GetPlayerTool)~="function" or type(SetPlayerTool)~="function" then return end
        local selected=GetPlayerTool(p)
        if not emptyTool(selected) and selected~=state.savedTool then
            -- Preserve the latest player/policy selection, while keeping it
            -- inactive until the object and use-tool input are released.
            state.savedTool=selected
            state.restorePending=true
        end
        SetPlayerTool(noTool,p)
    end

    function controller:tick(p,e,allowed)
        local state=stateFor(p,false)
        if not e or e.strength~=true then
            if state then
                state.enabled=false
                release(p,false)
            end
            return
        end
        if type(IsPlayerValid)=="function" and not IsPlayerValid(p) then
            controller:remove(p)
            return
        end
        state=stateFor(p,true)
        local grabDown=down("grab",p)
        if not state.enabled then
            state.enabled=true
            if grabDown then state.waitGrabRelease=true end
        end
        local contextOK=contextAllowed(p,e)
        if allowed==true and contextOK and grabDown and type(ReleasePlayerGrab)=="function" then
            -- Cancel native grabbing even when our mass or target filters reject the hit.
            ReleasePlayerGrab(p)
        end
        if allowed~=true or not contextOK then
            release(p,true)
            state=stateFor(p,false)
            if state then
                state.enabled=true
                if grabDown then state.waitGrabRelease=true end
            end
            return
        end
        if state.waitGrabRelease then
            if not grabDown then state.waitGrabRelease=false
            else tryRestore(p,state,false);return end
        end
        if state.body~=0 then
            if not grabDown then release(p,false);return end
            if not validateHeld(p,e,state) then release(p,true);return end
            suppressTool(p,state)
            if not state.throwDone and e.strengthThrow==true and pressed("usetool",p) then
                state.throwDone=true
                local cfg=strengthConfig()
                local speed=bounded(e.strengthThrowSpeed,cfg.throwSpeed or 20,cfg.minThrowSpeed or 1,cfg.maxThrowSpeed or 100)
                local camera=GetPlayerCameraTransform(p)
                local _,direction=targetAtDistance(camera,1)
                local transform=GetBodyTransform(state.body)
                local center=GetBodyCenterOfMass(state.body)
                if direction and vector(center) and type(transform)=="table" then
                    local worldCenter=TransformToParentPoint(transform,center)
                    local velocity=GetBodyVelocity(state.body)
                    if vector(worldCenter) and vector(velocity) then
                        local impulse=VecScale(VecSub(VecScale(direction,speed),velocity),state.mass)
                        ApplyBodyImpulse(state.body,worldCenter,impulse)
                    end
                end
                release(p,true)
            end
            return
        end
        tryRestore(p,state,false)
        if not state.waitGrabRelease and grabDown and pressed("grab",p) then acquire(p,e,state) end
        discardEmpty(p,state)
    end

    function controller:update(p,e,dt,allowed)
        local state=stateFor(p,false)
        if not state then return end
        if type(IsPlayerValid)=="function" and not IsPlayerValid(p) then
            controller:remove(p)
            return
        end
        if not e or e.strength~=true or allowed~=true then
            release(p,true)
            return
        end
        if not contextAllowed(p,e) then
            release(p,true)
            return
        end
        local grabDown=down("grab",p)
        if grabDown and type(ReleasePlayerGrab)=="function" then ReleasePlayerGrab(p) end
        if state.body==0 then
            tryRestore(p,state,false)
            discardEmpty(p,state)
            return
        end
        if not grabDown then release(p,false);return end
        if not validateHeld(p,e,state) then release(p,true);return end
        suppressTool(p,state)
        if not finite(dt) or dt<=0 or type(ConstrainPosition)~="function" then return end
        local bodyTransform=GetBodyTransform(state.body)
        local camera=GetPlayerCameraTransform(p)
        local target=targetAtDistance(camera,state.distance)
        if not target or type(bodyTransform)~="table" then release(p,true);return end
        local bodyPoint=TransformToParentPoint(bodyTransform,state.localPoint)
        if distance(bodyPoint,target)>((strengthConfig().breakDistance) or 6) then release(p,true);return end
        local cfg=strengthConfig()
        local force=bounded(e.strengthForce,cfg.force or 1,cfg.minForce or 1,cfg.maxForce or 20)
        if IsBodyJointedToStatic(state.body) then
            -- Preserve the grip and force budget already used for doors and scenery joints.
            local impulse=state.mass*(cfg.jointedAcceleration or 30)*force*dt
            ConstrainPosition(state.body,0,bodyPoint,target,cfg.jointedMaxVelocity or 6,impulse)
        else
            local center=GetBodyCenterOfMass(state.body)
            if not vector(center) then release(p,true);return end
            local rotation=QuatRotateQuat(camera.rot,state.localRotation)
            local bodyCenter=TransformToParentPoint(bodyTransform,center)
            local desiredCenter=TransformToParentPoint({pos=target,rot=rotation},VecSub(center,state.localPoint))
            local waypoint=carryWaypoint(camera.pos,bodyCenter,desiredCenter)
            local impulse=state.mass*(cfg.acceleration or 180)*force*dt
            ConstrainPosition(state.body,0,bodyCenter,waypoint,cfg.maxVelocity or 24,impulse)
            local lever=distance(state.localPoint,center)
            local angularImpulse=impulse*math.max(1,lever*lever)
            ConstrainOrientation(state.body,0,bodyTransform.rot,rotation,cfg.maxAngularVelocity or 18,angularImpulse)
        end
    end

    function controller:release(p,waitUseRelease)
        release(p,waitUseRelease)
    end

    function controller:remove(p)
        local state=stateFor(p,false)
        if state then clearBody(p,state) end
        states[p]=nil
    end

    function controller:reset()
        local ids={}
        for p in pairs(states) do ids[#ids+1]=p end
        for _,p in ipairs(ids) do
            if type(IsPlayerValid)=="function" and IsPlayerValid(p) then release(p,true)
            else controller:remove(p) end
        end
    end

    function controller:heldBody(p)
        local state=stateFor(p,false)
        return state and state.body or 0
    end

    return controller
end
