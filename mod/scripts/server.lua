-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Gameplay changes belong here. Actor IDs in ServerCall are NOT authenticated
-- by the documented engine API: role checks support normal, unmodified clients.
function OSP.installServer()
    local players, rules, logs, tools, known = {}, {}, {}, {}, {}
    local original, sequence, refreshAt = {}, 0, 0
    local save = "savegame.mod.osp.rules."
    local lastRequest, removalSeen = {}, {}
    local policies = {}
    local toolSave = "savegame.mod.osp.tools"
    local profileSave = "savegame.mod.osp.players."
    local profileHost
    local effectsOffOnLoad,resetEffectsOnEntry=false,false
    local effectsOnLoadKey="savegame.mod.osp.effects_off_on_load"
    local collectiveRoot="savegame.mod.osp.collective."
    local collectiveFuture=false
    local collectiveDefaults={all={},roles={}}
    local C=OSP.Collective
    local flightInputClock=0
    local strengthController=OSP.Strength.new()
    local ammoController=OSP.Ammo.new()
    local actions = {}
    local templates = {}
    local P=OSP.Permissions
    local templateSave="savegame.mod.osp.templates"
    local function roster() return GetAllPlayers() end
    local function isHost(p) return IsPlayerValid(p) and IsPlayerHost(p) end
    local function playerRole(p)
        local e=players[p]
        return P.resolve(e and (e.role or (e.admin and "admin" or "guest")),templates)
    end
    local function isAdmin(p) return isHost(p) or P.hasAccess(playerRole(p).permissions) end
    local function encoded(id)
        return id:gsub(".",function(c) return string.format("%02x",c:byte()) end)
    end
    local effectKeys=C.effects
    local function selfDisableKey(actor,target,action,value)
        -- Match the explicit command, not incidental changes inside its handler
        -- (for example, enabling Fly temporarily suspends Noclip).
        if actor~=target then return end
        if value==false then return effectKeys[action] end
        if action=="speed" and value==1 then return "speed" end
    end
    local function storeDisabledEffect(e,key)
        local path=profileSave..e.profile.."."
        if key=="speed" then SetFloat(path..key,1)
        else SetBool(path..key,false) end
        if key=="noclip" then SetBool(path.."fly",false) end
    end
    local function clearEntryEffects(e)
        for field in pairs(effectKeys) do e[field]=false end
        e.speed=1;e.anchor=nil
    end
    local function loadProfile(p,e,id)
        e.profile=id
        local root=profileSave..id.."."
        for _,key in ipairs({"admin","god","freeze"}) do
            if HasKey(root..key) then e[key]=GetBool(root..key) end
        end
        -- The old fly flag meant native noclip. New colliding flight has its
        -- own storage key, so older builds never turn flight grants into noclip.
        if HasKey(root.."noclip") then e.noclip=GetBool(root.."noclip")
        elseif HasKey(root.."fly") then e.noclip=GetBool(root.."fly") end
        e.fly=GetBool(root.."flight")
        e.strength=GetBool(root.."strength")
        e.ammo=GetBool(root.."ammo")
        -- Old saved preferences remain untouched while restoration is suspended.
        e.ammoRestore=false
        e.strengthThrow=GetBool(root.."strength_throw")
        for _,spec in ipairs({{"strength_force","strengthForce",OSP.strength.minForce,OSP.strength.maxForce},
            {"strength_mass","strengthMass",OSP.strength.minMass,OSP.strength.maxMass},
            {"strength_throw_speed","strengthThrowSpeed",OSP.strength.minThrowSpeed,OSP.strength.maxThrowSpeed}}) do
            if HasKey(root..spec[1]) then
                local value=GetFloat(root..spec[1])
                if OSP.finite(value) and value>=spec[3] and value<=spec[4]
                    and (spec[1]~="strength_mass" or value%1==0) then e[spec[2]]=value end
            end
        end
        for key,field in pairs({flight_speed="flySpeed",flight_boost="flyBoost",noclip_speed="noclipSpeed",noclip_boost="noclipBoost"}) do
            if HasKey(root..key) then
                local value=GetFloat(root..key)
                if OSP.finite(value) and value>=OSP.flight.min and value<=OSP.flight.max then e[field]=value end
            end
        end
        if HasKey(root.."role") then e.role=GetString(root.."role");e.admin=false
        else e.role=e.admin and "admin" or "guest" end
        if HasKey(root.."speed") then
            local value=GetFloat(root.."speed")
            if OSP.finite(value) and value>=.5 and value<=3 then e.speed=value end
        end
        if collectiveFuture and not resetEffectsOnEntry and not GetBool(root.."collective_optout") then
            C.inherit(collectiveDefaults,e,isHost(p),function(key) return HasKey(root..key) end,P.resolve(e.role,templates).id)
        end
        if e.freeze then e.anchor=GetPlayerTransform(p) end
        for _,key in ipairs(ListKeys(root.."tools")) do
            if #key>0 and #key%2==0 and not key:find("[^0-9a-f]") then
                local tool=key:gsub("..",function(hex) return string.char(tonumber(hex,16)) end)
                local value=GetInt(root.."tools."..key)
                if value==1 then e.toolRules[tool]=true elseif value==2 then e.toolRules[tool]=false end
            end
        end
        if resetEffectsOnEntry then
            clearEntryEffects(e)
            for _,key in pairs(effectKeys) do storeDisabledEffect(e,key) end
            storeDisabledEffect(e,"speed")
        end
    end
    local function saveField(actor,p,key,value)
        local e=players[p]
        if not isHost(actor) or not e.profile then return end
        local path=profileSave..e.profile.."."..key
        if type(value)=="boolean" then SetBool(path,value) else SetFloat(path,value) end
    end
    local function snapshot(p)
        local join=GetInt("savegame.mod.osp.nextjoin")+1
        if join<1 or join>2147483647 then join=1 end
        SetInt("savegame.mod.osp.nextjoin",join)
        local e={
            admin=false, god=nil, fly=false, noclip=nil, flying=false, freeze=false, speed=1,
            flySpeed=OSP.flight.normal,flyBoost=OSP.flight.shift,
            noclipSpeed=OSP.flight.normal,noclipBoost=OSP.flight.shift,
            strength=false,strengthForce=OSP.strength.force,strengthMass=OSP.strength.mass,
            strengthThrow=false,strengthThrowSpeed=OSP.strength.throwSpeed,
            ammo=false,ammoRestore=false,
            baseSpeed=GetPlayerWalkingSpeed(p),
            baseGod=GetPlayerParam("godMode", p),
            baseFly=GetPlayerParam("flyMode", p),
            baseRegen=GetPlayerParam("healthRegeneration", p),
            toolRules={}, toolBase={}, toolProbes={}, toolConflicts={}, alive=GetPlayerHealth(p)>0,challenge=join,
        }
        if resetEffectsOnEntry then clearEntryEffects(e) end
        if isHost(p) then loadProfile(p,e,"host") end
        return e
    end
    local function setFog(distance)
        local f=original.fog
        -- Preserve map scattering/exponent, but move the start below the end.
        SetEnvironmentProperty("fogparams", math.min(f[1], distance*0.5), distance, f[3], f[4])
    end
    local function publish()
        local view={version=OSP.version,ready=true,players={},tools=OSP.copy(tools),
            rules=OSP.copy(rules),log=OSP.copy(logs),toolPolicies=OSP.copy(policies),profileHost=profileHost,templates=P.list(templates),
            effectsOffOnLoad=effectsOffOnLoad,collectiveFuture=collectiveFuture}
        for _, p in ipairs(roster()) do
            local e=players[p]
            if e then
                view.players[#view.players+1]={id=p,name=GetPlayerName(p),health=GetPlayerHealth(p),
                    vehicle=GetPlayerVehicle(p)~=0,host=isHost(p),admin=isAdmin(p),god=e.god==true or (e.god==nil and e.baseGod==true),
                    fly=e.fly==true,flying=e.flying==true,flySpeed=e.flySpeed,flyBoost=e.flyBoost,
                    noclip=e.noclip==true or (e.noclip==nil and e.baseFly==true),noclipSpeed=e.noclipSpeed,noclipBoost=e.noclipBoost,
                    strength=e.strength,strengthForce=e.strengthForce,strengthMass=e.strengthMass,
                    strengthThrow=e.strengthThrow,strengthThrowSpeed=e.strengthThrowSpeed,
                    strengthHolding=strengthController:heldBody(p)~=0,
                    ammo=e.ammo,ammoRestore=e.ammoRestore,toolRules=OSP.copy(e.toolRules),toolConflicts=OSP.copy(e.toolConflicts),
                    freeze=e.freeze,speed=e.speed,role=playerRole(p).id,permissions=OSP.copy(playerRole(p).permissions),profileReady=e.profile~=nil,profileChallenge=e.challenge}
            end
        end
        shared.osp=view
    end
    local function record(actor,action,target,result,details,arg)
        sequence=sequence+1
        -- Log only the validated part, never arbitrary extra fields from RPC.
        if action=="rule" then arg={key=arg.key,value=arg.value}
        elseif action=="tool" or action=="tool_all" then arg={id=arg.id,enabled=arg.enabled}
        elseif action=="tool_policy" then arg={id=arg.id,mode=arg.mode}
        elseif action=="tool_policy_bulk" then arg={category=arg.category,mode=arg.mode}
        elseif action=="tools_filtered" or action=="tools_filtered_all" then arg={category=arg.category,enabled=arg.enabled}
        elseif action=="tools_selection" or action=="tools_selection_all" then
            arg={category=arg.category,tools=#arg.ids,enabled=arg.enabled}
        elseif action=="tool_policy_selection" then
            arg={category=arg.category,tools=#arg.ids,mode=arg.mode}
        elseif action=="players_group" then
            arg={action=arg.action,scope=arg.scope,role=arg.role,enabled=arg.value}
        elseif action=="roles_assign_many" then arg={role=arg.role}
        elseif type(arg)=="table" then arg=nil end
        logs[#logs+1]={seq=sequence,actor=IsPlayerValid(actor) and GetPlayerName(actor) or "?",
            action=action,target=type(target)=="number" and IsPlayerValid(target) and GetPlayerName(target) or "",
            result=result,affected=details and details.affected or 0,skipped=details and details.skipped or 0,failed=details and details.failed or 0,
            inventoryConflicts=details and details.inventoryConflicts or 0,argument=OSP.copy(arg)}
        if #logs>100 then table.remove(logs,1) end
    end
    local function reply(actor,ok,code,details,requestId)
        ClientCall(actor,"client.ospResult",ok,code,details or {},requestId)
    end
    local function clearPlayer(p)
        strengthController:remove(p)
        ammoController:remove(p)
        players[p]=nil
        lastRequest[p]=nil
    end
    local function syncPlayers()
        for _, p in ipairs(GetRemovedPlayers()) do
            if removalSeen[p] ~= GetTime() then
                clearPlayer(p)
                removalSeen[p] = GetTime()
            end
        end
        local present={}
        for _,p in ipairs(roster()) do
            present[p]=true
            if not players[p] then players[p]=snapshot(p) end
        end
        for p in pairs(players) do if not present[p] then clearPlayer(p) end end
    end
    local function refreshTools()
        tools,known={},{}
        local ids=ListKeys("game.tool")
        table.sort(ids)
        for _,id in ipairs(ids) do
            local name=GetString("game.tool."..id..".name")
            if name=="" then name=id end
            local nameKey
            if name:sub(1,4)=="loc@" then
                nameKey=name:sub(5)
                name=id
            end
            local mode="default"
            if policies[id]~=nil then mode=policies[id] and "enabled" or "disabled" end
            tools[#tools+1]={id=id,name=name,nameKey=nameKey,origin=OSP.toolOrigin(id),policy=mode}
            known[id]=true
        end
        for _,e in pairs(players) do
            for id in pairs(e.toolProbes) do if not known[id] then e.toolProbes[id]=nil end end
            for id in pairs(e.toolConflicts) do if not known[id] then e.toolConflicts[id]=nil end end
        end
    end
    local function desiredTool(e,id)
        local want=e.toolRules[id]
        if policies[id]==false then want=false
        elseif want==nil then want=policies[id] end
        return want
    end
    local function deselectTool(p,id)
        if GetPlayerTool(p)~=id then return end
        local replacement=""
        for _,tool in ipairs(tools) do
            if tool.id~=id and desiredTool(players[p],tool.id)~=false and IsToolEnabled(tool.id,p) then
                replacement=tool.id;break
            end
        end
        SetPlayerTool(replacement,p)
    end
    local function canHideTool(p,id)
        local e=players[p]
        if e.toolConflicts[id] then return false end
        -- Only count reversals of our own OFF writes. Do not accumulate
        -- isolated resets or tool restoration on death/respawn.
        if not e.alive or GetPlayerHealth(p)<=0 then e.toolProbes[id]=nil;return true end
        local probe=e.toolProbes[id];local now=GetTime()
        if probe and probe.writtenAt and now>probe.writtenAt and IsToolEnabled(id,p) then
            if not probe.firstAt or now-probe.firstAt>1 then probe.firstAt=now;probe.reversals=0 end
            probe.reversals=probe.reversals+1;probe.writtenAt=nil
            if probe.reversals>=4 then e.toolConflicts[id]=true;e.toolProbes[id]=nil;return false end
        end
        return true
    end
    local function applyTool(p,id,on)
        local e=players[p]
        if e.toolBase[id]==nil then e.toolBase[id]=IsToolEnabled(id,p) end
        if on or canHideTool(p,id) then
            SetToolEnabled(id,on,p)
            if on then e.toolProbes[id]=nil
            elseif e.alive and GetPlayerHealth(p)>0 then
                local probe=e.toolProbes[id] or {reversals=0}
                probe.writtenAt=GetTime();e.toolProbes[id]=probe
            end
        end
        -- An external writer may keep the inventory entry visible. Preserve
        -- the usage restriction without fighting its enabled flag every frame.
        if not on then deselectTool(p,id) end
        return not on and e.toolConflicts[id]==true
    end
    local function setTool(actor,p,id,on)
        local conflict=applyTool(p,id,on)
        local e=players[p]
        e.toolRules[id]=on
        if isHost(actor) and e.profile then
            SetInt(profileSave..e.profile..".tools."..encoded(id),on and 1 or 2)
        end
        return conflict and 1 or 0
    end
    local function enforceTools(p)
        local e=players[p]
        for id in pairs(known) do
            local want=desiredTool(e,id)
            if want~=nil then
                -- Capture before the first intervention even if already equal.
                if e.toolBase[id]==nil then e.toolBase[id]=IsToolEnabled(id,p) end
                if IsToolEnabled(id,p)~=want then applyTool(p,id,want)
                elseif not want then deselectTool(p,id) end
            end
        end
    end
    local function policyKey(id)
        return toolSave.."."..encoded(id)
    end
    local function loadPolicies()
        policies={}
        for _,encoded in ipairs(ListKeys(toolSave)) do
            if #encoded>0 and #encoded%2==0 and not encoded:find("[^0-9a-f]") then
                local id=encoded:gsub("..",function(hex) return string.char(tonumber(hex,16)) end)
                local value=GetInt(toolSave.."."..encoded)
                if value==1 then policies[id]=true elseif value==2 then policies[id]=false end
            end
        end
    end
    local function chooseCategory(category)
        local ids={}
        for _,tool in ipairs(tools) do
            if category=="all" or tool.origin==category then ids[#ids+1]=tool.id end
        end
        return ids
    end
    local function setPolicy(id,mode)
        local value,conflicts=nil,0
        if mode=="enabled" then value=true elseif mode=="disabled" then value=false end
        policies[id]=value
        if value==nil then ClearKey(policyKey(id)) else SetInt(policyKey(id),value and 1 or 2) end
        for _,profile in ipairs(ListKeys(profileSave:sub(1,-2))) do
            ClearKey(profileSave..profile..".tools."..encoded(id))
        end
        for _,p in ipairs(roster()) do
            local e=players[p]
            e.toolRules[id]=nil
            local conflict=false
            if value~=nil then conflict=applyTool(p,id,value)
            elseif e.toolBase[id]~=nil then conflict=applyTool(p,id,e.toolBase[id]) end
            if conflict then conflicts=conflicts+1 end
        end
        for _,tool in ipairs(tools) do if tool.id==id then tool.policy=mode end end
        return conflicts
    end
    local function policySelection(ids,mode)
        local conflicts=0
        for _,id in ipairs(ids) do conflicts=conflicts+setPolicy(id,mode) end
        return {affected=#ids>0 and #roster() or 0,skipped=0,tools=#ids,inventoryConflicts=conflicts}
    end
    local function moveTo(p,anchor)
        strengthController:release(p,true)
        local t=GetPlayerTransform(anchor)
        local dest=Transform(TransformToParentPoint(t,Vec(0,0.2,-2.5)),t.rot)
        SetPlayerVehicle(0,p)
        SetPlayerTransform(dest,p)
        SetPlayerVelocity(Vec(0,0,0),p)
        if players[p].freeze then players[p].anchor=dest end
    end
    local function boolean(v) return type(v)=="boolean" end
    local function numberIn(v,lo,hi) return OSP.finite(v) and v>=lo and v<=hi end
    local function cleanText(s)
        return type(s)=="string" and #s>0 and #s<=240 and s:find("%S") and not s:find("[%z\1-\31\127]")
    end
    local function toolArg(v) return type(v)=="table" and type(v.id)=="string" and known[v.id] and boolean(v.enabled) end
    local function add(name,validate,run,opts)
        opts=opts or {}; opts.validate=validate; opts.run=run; actions[name]=opts
    end
    local function stopFlight(e)
        e.flying=false;e.jumpAt=nil;e.flightInput=nil;e.flightInputAt=nil
    end
    local function heal(p)
        if GetPlayerHealth(p)<=0 then ammoController:stop(p,players[p].ammoRestore==true);strengthController:release(p,true);stopFlight(players[p]);RespawnPlayer(p); players[p].alive=false; enforceTools(p) else SetPlayerHealth(1,p) end
    end
    add("heal",nil,function(_,p) heal(p) end,{target=true})
    add("kill",nil,function(_,p) ammoController:stop(p,players[p].ammoRestore==true);strengthController:release(p,true);stopFlight(players[p]);SetPlayerHealth(0,p) end,{target=true})
    add("respawn",nil,function(_,p) ammoController:stop(p,players[p].ammoRestore==true);strengthController:release(p,true);stopFlight(players[p]);RespawnPlayer(p); players[p].alive=false; enforceTools(p) end,{target=true})
    add("goto",nil,function(c,p) moveTo(c,p) end,{target=true,readTarget=true,aliveCaller=true,aliveTarget=true,noSelf=true})
    add("bring",nil,function(c,p) moveTo(p,c) end,{target=true,aliveCaller=true,aliveTarget=true,noSelf=true})
    add("eject",nil,function(_,p) SetPlayerVehicle(0,p) end,{target=true})
    add("god",boolean,function(c,p,v)
        SetPlayerParam("godMode",v,p); players[p].god=v
        saveField(c,p,"god",v)
    end,{target=true,persistent=true})
    local function saveNoclip(c,p,v)
        saveField(c,p,"noclip",v)
        saveField(c,p,"fly",v) -- Compatibility with the old native-fly setting.
    end
    add("noclip",boolean,function(c,p,v)
        local seated=GetPlayerVehicle(p)~=0
        SetPlayerParam("flyMode",v and not seated,p)
        local e=players[p]
        if not seated then SetPlayerVelocity(Vec(0,0,0),p) end
        e.noclip=v;stopFlight(e)
        saveNoclip(c,p,v)
        if v then e.fly=false;saveField(c,p,"flight",false) end
    end,{target=true,persistent=true})
    add("fly",boolean,function(c,p,v)
        local e=players[p]
        if e.flying then SetPlayerVelocity(Vec(0,0,0),p) end
        stopFlight(e);e.fly=v;saveField(c,p,"flight",v)
        if v then
            e.noclip=false;SetPlayerParam("flyMode",false,p);saveNoclip(c,p,false)
        end
    end,{target=true,persistent=true})
    add("fly_speed",function(v) return numberIn(v,OSP.flight.min,OSP.flight.max) end,function(c,p,v)
        players[p].flySpeed=v;saveField(c,p,"flight_speed",v)
    end,{target=true,persistent=true})
    add("fly_boost",function(v) return numberIn(v,OSP.flight.min,OSP.flight.max) end,function(c,p,v)
        players[p].flyBoost=v;saveField(c,p,"flight_boost",v)
    end,{target=true,persistent=true})
    add("noclip_speed",function(v) return numberIn(v,OSP.flight.min,OSP.flight.max) end,function(c,p,v)
        players[p].noclipSpeed=v;saveField(c,p,"noclip_speed",v)
    end,{target=true,persistent=true})
    add("noclip_boost",function(v) return numberIn(v,OSP.flight.min,OSP.flight.max) end,function(c,p,v)
        players[p].noclipBoost=v;saveField(c,p,"noclip_boost",v)
    end,{target=true,persistent=true})
    add("strength",boolean,function(c,p,v)
        local e=players[p]
        e.strength=v;e.strengthInput=nil;e.strengthInputAt=nil
        if not v then strengthController:release(p,true) end
        saveField(c,p,"strength",v)
    end,{target=true,persistent=true})
    for _,spec in ipairs({{"strength_force","strengthForce",OSP.strength.minForce,OSP.strength.maxForce},
        {"strength_mass","strengthMass",OSP.strength.minMass,OSP.strength.maxMass},
        {"strength_throw_speed","strengthThrowSpeed",OSP.strength.minThrowSpeed,OSP.strength.maxThrowSpeed}}) do
        local action,field,lo,hi=unpack(spec)
        add(action,function(v) return numberIn(v,lo,hi) and (action~="strength_mass" or v%1==0) end,function(c,p,v)
            players[p][field]=v;saveField(c,p,action,v)
        end,{target=true,persistent=true})
    end
    add("strength_throw",boolean,function(c,p,v)
        players[p].strengthThrow=v;saveField(c,p,"strength_throw",v)
    end,{target=true,persistent=true})
    add("ammo",boolean,function(c,p,v)
        local e=players[p]
        e.ammo=v
        if v then ammoController:tick(p,e,true) else ammoController:stop(p,e.ammoRestore==true) end
        saveField(c,p,"ammo",v)
    end,{target=true,persistent=true})
    add("ammo_restore",boolean,function() end,
        {target=true,guard=function() return "unavailable" end})
    add("freeze",boolean,function(c,p,v)
        players[p].freeze=v
        stopFlight(players[p])
        if v then
            strengthController:release(p,true)
            SetPlayerVehicle(0,p); players[p].anchor=GetPlayerTransform(p)
            SetPlayerVelocity(Vec(0,0,0),p)
        else players[p].anchor=nil end
        saveField(c,p,"freeze",v)
    end,{target=true,persistent=true})
    add("speed",function(v) return numberIn(v,0.5,3) end,function(c,p,v)
        players[p].speed=v;saveField(c,p,"speed",v)
    end,{target=true,persistent=true})
    local function assignRole(c,p,id)
        players[p].role=id;players[p].admin=id=="admin"
        SetBool(profileSave..players[p].profile..".admin",id=="admin")
        SetString(profileSave..players[p].profile..".role",id)
    end
    add("admin",boolean,function(c,p,v) assignRole(c,p,v and "admin" or "guest") end,{target=true,host=true,noHost=true,persistent=true,profileRequired=true})
    add("role_assign",function(v) return type(v)=="table" and type(v.id)=="string" and P.resolve(v.id,templates).id==v.id end,
        function(c,p,v) assignRole(c,p,v.id) end,{target=true,noHost=true,persistent=true,profileRequired=true})
    local function storedRole(id) return templates[id] or P.default(id) end
    local function readPermissions(path)
        local values={}
        for _,spec in ipairs(P.spec) do values[spec.id]=GetInt(path..spec.id) end
        if HasKey(path.."noclip") then values.fly=GetInt(path.."flight")
        else values.noclip=values.fly;values.fly=0 end
        return P.normalize(values)
    end
    local function writePermissions(path,values)
        for _,spec in ipairs(P.spec) do
            SetInt(path..(spec.id=="fly" and "flight" or spec.id),values[spec.id])
        end
        SetInt(path.."fly",values.noclip)
    end
    local function writeInitial(path,initial)
        SetString(path.."name",initial.name)
        writePermissions(path.."permissions.",initial.permissions)
        SetBool(path.."exists",true)
    end
    local function writeRole(role,useDefault)
        local path=templateSave.."."..role.id.."."
        ClearKey(path:sub(1,-2))
        if useDefault then SetBool(path.."use_default",true)
        else
            SetString(path.."name",role.name)
            writePermissions(path.."permissions.",role.permissions)
        end
        if not role.builtin then
            if role.initial then writeInitial(path.."initial.",role.initial)
            else SetBool(path.."initial.exists",false) end
        end
        SetInt(path.."version",role.version)
    end
    local function loadTemplates()
        templates={}
        for _,id in ipairs(ListKeys(templateSave)) do
            if id:match("^c%d+$") or P.isPreset(id) then
                local path=templateSave.."."..id.."."
                local version=GetInt(path.."version")
                local role
                if P.isPreset(id) and GetBool(path.."use_default") and version>=1 then
                    role=P.default(id);role.version=version
                else
                    local name,permissions=GetString(path.."name"),readPermissions(path.."permissions.")
                    if P.validName(name) and version>=1 and permissions then
                        role={id=id,name=name,version=version,permissions=permissions,builtin=P.isPreset(id)}
                        if role.builtin then role.initial=P.default(id).initial
                        elseif not HasKey(path.."initial.exists") then
                            role.initial={name=name,permissions=OSP.copy(permissions)}
                            writeInitial(path.."initial.",role.initial)
                        elseif GetBool(path.."initial.exists") then
                            local baseName=GetString(path.."initial.name")
                            local basePermissions=readPermissions(path.."initial.permissions.")
                            if P.validName(baseName) and basePermissions then role.initial={name=baseName,permissions=basePermissions} end
                        end
                    end
                end
                if role then templates[id]=role end
            end
        end
    end
    local function templateArg(v)
        return type(v)=="table" and type(v.id)=="string" and (v.id=="" or storedRole(v.id)~=nil)
            and P.validName(v.name) and P.normalize(v.permissions)~=nil and OSP.finite(v.version) and v.version%1==0
    end
    add("role_save",templateArg,function(_,_,v)
        local id=v.id
        local initial=id~="" and storedRole(id).initial or nil
        if id=="" then
            local nextId=GetInt(templateSave.."_next")+1
            id="c"..nextId;SetInt(templateSave.."_next",nextId)
            initial={name=v.name,permissions=P.normalize(v.permissions)}
        end
        local role={id=id,name=v.name,version=v.version+1,permissions=P.normalize(v.permissions),builtin=P.isPreset(id),initial=OSP.copy(initial)}
        templates[id]=role;writeRole(role,false)
        return {affected=1,skipped=0,template=OSP.copy(role)}
    end,{guard=function(v)
        if (v.id=="" and v.version~=0) or (v.id~="" and storedRole(v.id).version~=v.version) then return "conflict" end
        local count=0
        for id,role in pairs(templates) do
            if not P.isPreset(id) then count=count+1 end
            if id~=v.id and role.name and role.name:lower()==v.name:lower() then return "invalid" end
        end
        if v.id=="" and count>=16 then return "template_limit" end
    end})
    local function roleVersionArg(v)
        return type(v)=="table" and type(v.id)=="string" and storedRole(v.id)~=nil
            and OSP.finite(v.version) and v.version>=0 and v.version%1==0
    end
    add("role_reset",roleVersionArg,function(_,_,v)
        local current=storedRole(v.id)
        local role=P.default(v.id) or {id=v.id,builtin=false,name=current.initial.name,
            permissions=OSP.copy(current.initial.permissions),initial=OSP.copy(current.initial)}
        role.version=current.version+1
        templates[v.id]=role;writeRole(role,role.builtin)
        return {affected=1,skipped=0,template=OSP.copy(role)}
    end,{guard=function(v)
        local role=storedRole(v.id)
        if role.version~=v.version then return "conflict" end
        if not role.initial then return "unavailable" end
    end})
    add("role_delete",function(v) return roleVersionArg(v) and not P.isPreset(v.id) end,
        function(_,_,v)
            templates[v.id]=nil;ClearKey(templateSave.."."..v.id)
            collectiveDefaults.roles[v.id]=nil;C.write(collectiveRoot.."defaults.",collectiveDefaults)
            for _,e in pairs(players) do if e.role==v.id then e.role="guest";e.admin=false end end
            for _,id in ipairs(ListKeys(profileSave:sub(1,-2))) do
                local path=profileSave..id.."."
                if GetString(path.."role")==v.id then SetString(path.."role","guest");SetBool(path.."admin",false) end
            end
            return {affected=1,skipped=0,deleted=v.id}
        end,
        {guard=function(v) if storedRole(v.id).version~=v.version then return "conflict" end end})
    add("reset_player",nil,function(_,p)
        ammoController:stop(p,players[p].ammoRestore==true)
        strengthController:release(p,true)
        local e=players[p]
        ClearKey(profileSave..e.profile)
        -- Keep the assigned identity, so reconnecting does not allocate a new one.
        SetBool(profileSave..e.profile..".exists",true)
        -- Restoring is an explicit choice; future defaults must not undo it.
        SetBool(profileSave..e.profile..".collective_optout",true)
        e.admin=false;e.role="guest";e.god=nil;e.fly=false;e.noclip=nil;stopFlight(e);e.freeze=false;e.anchor=nil;e.speed=1;e.toolRules={}
        e.flySpeed=OSP.flight.normal;e.flyBoost=OSP.flight.shift
        e.noclipSpeed=OSP.flight.normal;e.noclipBoost=OSP.flight.shift
        e.strength=false;e.strengthForce=OSP.strength.force;e.strengthMass=OSP.strength.mass
        e.strengthThrow=false;e.strengthThrowSpeed=OSP.strength.throwSpeed
        e.ammo=false;e.ammoRestore=false
        e.strengthInput=nil;e.strengthInputAt=nil
        SetPlayerParam("godMode",e.baseGod,p);SetPlayerParam("flyMode",e.baseFly,p)
        for id,on in pairs(e.toolBase) do if known[id] then applyTool(p,id,on) end end
        enforceTools(p)
    end,{target=true,persistent=true,profileRequired=true})
    local function each(c,fn)
        local d={affected=0,skipped=0}
        for _,p in ipairs(roster()) do
            if not isHost(c) and isHost(p) then d.skipped=d.skipped+1
            elseif fn(p)==false then d.skipped=d.skipped+1
            else d.affected=d.affected+1 end
        end
        return d
    end
    add("heal_all",nil,function(c) return each(c,heal) end)
    add("bring_all",nil,function(c)
        return each(c,function(p)
            if p==c or GetPlayerHealth(p)<=0 then return false end
            moveTo(p,c)
        end)
    end,{aliveCaller=true})
    local function toolGuard(v)
        if v.enabled and policies[v.id]==false then return "protected" end
    end
    local function toolDetails(applied,conflicts)
        return {affected=applied and 1 or 0,skipped=applied and 0 or 1,inventoryConflicts=conflicts or 0}
    end
    local function toolEach(c,fn)
        local conflicts=0
        local details=each(c,function(p)
            local applied,n=fn(p);conflicts=conflicts+(n or 0);return applied
        end)
        details.inventoryConflicts=conflicts;return details
    end
    add("tool",toolArg,function(c,p,v) return toolDetails(true,setTool(c,p,v.id,v.enabled)) end,{target=true,guard=toolGuard,persistent=true})
    local function allTools(c,p,on,category,selectedIds)
        if isHost(c) and not players[p].profile then return false end
        local applied,conflicts=0,0
        for _,id in ipairs(selectedIds or chooseCategory(category or "all")) do
            if not on or policies[id]~=false then conflicts=conflicts+setTool(c,p,id,on);applied=applied+1 end
        end
        return applied>0,conflicts
    end
    add("tools",boolean,function(c,p,v)
        return toolDetails(allTools(c,p,v))
    end,{target=true,persistent=true})
    add("tool_all",toolArg,function(c,_,v) return toolEach(c,function(p)
        if isHost(c) and not players[p].profile then return false end
        return true,setTool(c,p,v.id,v.enabled)
    end) end,{guard=toolGuard})
    add("tools_all",boolean,function(c,_,v) return toolEach(c,function(p) return allTools(c,p,v) end) end)
    local function category(v) return v=="all" or v=="vanilla" or v=="mod" end
    local function filteredArg(v) return type(v)=="table" and category(v.category) and boolean(v.enabled) end
    add("tools_filtered",filteredArg,function(c,p,v)
        return toolDetails(allTools(c,p,v.enabled,v.category))
    end,{target=true,persistent=true})
    add("tools_filtered_all",filteredArg,function(c,_,v)
        return toolEach(c,function(p) return allTools(c,p,v.enabled,v.category) end)
    end)
    local function mode(v) return v=="default" or v=="enabled" or v=="disabled" end
    add("tool_policy",function(v) return type(v)=="table" and type(v.id)=="string" and known[v.id] and mode(v.mode) end,
        function(_,_,v)
            return policySelection({v.id},v.mode)
        end)
    add("tool_policy_bulk",function(v) return type(v)=="table" and category(v.category) and mode(v.mode) end,
        function(_,_,v)
            return policySelection(chooseCategory(v.category),v.mode)
        end)
    local function selectionArg(v,policy)
        if type(v)~="table" or not category(v.category) then return false end
        local allowed=policy and {category=true,ids=true,mode=true} or {category=true,ids=true,enabled=true}
        for key in pairs(v) do if not allowed[key] then return false end end
        if policy then
            if not mode(v.mode) then return false end
        elseif not boolean(v.enabled) then return false end
        if type(v.ids)~="table" then return false end
        local count,maxIndex,seen=0,0,{}
        for index,id in pairs(v.ids) do
            if not OSP.finite(index) or index<1 or index%1~=0 then return false end
            count=count+1
            if index>maxIndex then maxIndex=index end
            if type(id)~="string" or id=="" or seen[id] then return false end
            seen[id]=true
        end
        if count==0 or maxIndex~=count then return false end
        -- Re-read the engine catalog before checking bounds, availability, or origin.
        refreshTools()
        for index=1,count do if not known[v.ids[index]] then return false,"unavailable" end end
        if count>#tools then return false end
        if v.category~="all" then
            for index=1,count do
                if OSP.toolOrigin(v.ids[index])~=v.category then return false end
            end
        end
        return true
    end
    add("tools_selection",function(v) return selectionArg(v,false) end,function(c,p,v)
        local details=toolDetails(allTools(c,p,v.enabled,v.category,v.ids));details.tools=#v.ids;return details
    end,{target=true,persistent=true})
    add("tools_selection_all",function(v) return selectionArg(v,false) end,function(c,_,v)
        local details=toolEach(c,function(p) return allTools(c,p,v.enabled,v.category,v.ids) end)
        details.tools=#v.ids
        return details
    end)
    add("tool_policy_selection",function(v) return selectionArg(v,true) end,function(_,_,v)
        return policySelection(v.ids,v.mode)
    end)
    local function ruleArg(v)
        if type(v)~="table" then return false end
        if v.key=="regen" then return boolean(v.value) end
        local limits={time={0.1,2},rain={0,1},fog={10,1000}}
        local range=limits[v.key]
        return range and numberIn(v.value,range[1],range[2])
    end
    local function applyRule(key,value)
        if key=="time" then SetTimeScale(value)
        elseif key=="rain" then SetEnvironmentProperty("rain",value)
        elseif key=="fog" then setFog(value)
        elseif key=="regen" then
            for _,p in ipairs(roster()) do SetPlayerRegenerationState(value,p) end
        end
    end
    add("rule",ruleArg,function(_,_,v)
        applyRule(v.key,v.value)
        rules[v.key]=v.value
        if v.key=="regen" then SetBool(save..v.key,v.value) else SetFloat(save..v.key,v.value) end
    end)
    local function restoreRules()
        SetEnvironmentProperty("rain",original.rain)
        SetEnvironmentProperty("fogparams",unpack(original.fog))
        SetTimeScale(1)
        for _,p in ipairs(roster()) do
            if players[p] then SetPlayerRegenerationState(players[p].baseRegen,p) end
        end
        rules={}
    end
    add("reset_rules",nil,function()
        restoreRules()
        for _,key in ipairs({"time","rain","fog","regen"}) do ClearKey(save..key) end
    end)
    add("restart",nil,function() Restart() end)
    add("announce",cleanText,function(c,_,v) ClientCall(0,"client.ospAnnouncement",GetPlayerName(c),v) end)
    add("effects_off_on_load",boolean,function(_,_,value)
        effectsOffOnLoad=value;SetBool(effectsOnLoadKey,value)
    end,{host=true})
    add("collective_future",boolean,function(_,_,value)
        collectiveFuture=value;SetBool(collectiveRoot.."future",value)
        if not value then
            collectiveDefaults={all={},roles={}}
            ClearKey(collectiveRoot.."defaults")
        end
    end,{host=true})

    function server.init()
        players,rules,logs,lastRequest,removalSeen={},{},{},{},{}
        sequence,refreshAt=0,0
        flightInputClock=GetTime()
        strengthController=OSP.Strength.new()
        ammoController=OSP.Ammo.new()
        effectsOffOnLoad=GetBool(effectsOnLoadKey)
        -- Keep one policy for this map, including players who join later.
        -- Changing the preference only affects the next map load.
        resetEffectsOnEntry=effectsOffOnLoad
        profileHost=GetString("savegame.mod.osp.hostid")
        if not profileHost:match("^[0-9a-f]+$") or #profileHost~=32 then
            profileHost=""
            for _=1,4 do profileHost=profileHost..string.format("%08x",GetRandomInt(0,2147483647)) end
            SetString("savegame.mod.osp.hostid",profileHost)
        end
        original={rain=GetEnvironmentProperty("rain"),fog={GetEnvironmentProperty("fogparams")}}
        loadTemplates(); loadPolicies()
        collectiveFuture=GetBool(collectiveRoot.."future")
        collectiveDefaults=collectiveFuture and C.load(collectiveRoot.."defaults.",P.list(templates)) or {all={},roles={}}
        syncPlayers(); refreshTools()
        for _,p in ipairs(roster()) do enforceTools(p) end
        for _,key in ipairs({"time","rain","fog","regen"}) do
            if HasKey(save..key) then
                local value
                if key=="regen" then value=GetBool(save..key) else value=GetFloat(save..key) end
                if ruleArg({key=key,value=value}) then rules[key]=value; applyRule(key,value) end
            end
        end
        publish()
    end
    local administrative={role_assign=true,role_save=true,role_reset=true,role_delete=true,reset_player=true,
        tool_policy=true,tool_policy_bulk=true,tool_policy_selection=true,restart=true}
    local function administrationGuard(actor,action,target,arg)
        if isHost(actor) then return end
        local ceiling=playerRole(actor).permissions
        local current,proposed,templateId
        if action=="role_assign" then
            current=playerRole(target).permissions
            proposed=P.resolve(arg.id,templates).permissions
        elseif action=="role_save" then
            proposed=P.normalize(arg.permissions)
            if arg.id~="" then current=storedRole(arg.id).permissions;templateId=arg.id end
        elseif action=="role_delete" or action=="role_reset" then
            local role=storedRole(arg.id)
            current=role.permissions;templateId=arg.id
            if action=="role_reset" then
                if not role.initial then return "unavailable" end
                proposed=role.initial.permissions
            else proposed=P.resolve("guest",templates).permissions end
        elseif action=="reset_player" then
            current=playerRole(target).permissions
            proposed=P.resolve("guest",templates).permissions
        end
        if templateId then
            for _,p in ipairs(roster()) do
                if isHost(p) and playerRole(p).id==templateId then return "protected" end
            end
        end
        if current and not P.within(current,ceiling) or proposed and not P.within(proposed,ceiling) then return "denied" end
    end
    local function prepareCollective(actor,arg,assignment)
        if arg.host~=profileHost or arg.actorJoin~=players[actor].challenge then return nil,"unavailable" end
        if (assignment or arg.scope=="role") and not storedRole(arg.role) then return nil,"unavailable" end
        local action=assignment and "role_assign" or arg.action
        local value=assignment and {id=arg.role} or arg.value
        local def=actions[action]
        local global=action=="heal" and "heal_all" or action=="bring" and "bring_all" or nil
        if def.aliveCaller and GetPlayerHealth(actor)<=0 then return nil,"unavailable" end
        if not isHost(actor) then
            local permission=assignment and "role_assign" or global or action
            if global or assignment then
                if not P.allows(playerRole(actor).permissions,permission,0,value,actor) then return nil,"denied" end
            elseif not P.allows(playerRole(actor).permissions,permission,actor,value,actor) then return nil,"denied" end
            if assignment and not P.within(P.resolve(arg.role,templates).permissions,playerRole(actor).permissions) then return nil,"denied" end
        end
        local batch={targets={},details={affected=0,skipped=0,failed=0},
            future=not assignment and isHost(actor) and collectiveFuture and C.effects[action]~=nil and arg.scope~="manual"}
        local denied=false
        for _,target in ipairs(arg.targets) do
            local p=target.id;local e=players[p]
            local skip=not IsPlayerValid(p) or not e or e.challenge~=target.join
            if not skip and not assignment then
                skip=not C.matches({id=p,host=isHost(p),role=playerRole(p).id},arg.scope,arg.role,arg.excludeSelf,actor)
            end
            if not skip then
                skip=(isHost(p) and (assignment or not isHost(actor)))
                    or def.noSelf and p==actor or def.aliveTarget and GetPlayerHealth(p)<=0
                    or (def.profileRequired or def.persistent and isHost(actor)) and not e.profile
            end
            local disabledKey=not assignment and not isHost(actor) and selfDisableKey(actor,p,action,value)
            if not skip and disabledKey and not e.profile then skip=true end
            if not skip and not isHost(actor) then
                if not global and not P.allows(playerRole(actor).permissions,action,p,value,actor)
                    or administrationGuard(actor,action,p,value) then skip=true;denied=true end
            end
            if not skip and assignment and playerRole(p).id==arg.role then skip=true end
            if skip then batch.details.skipped=batch.details.skipped+1
            else batch.targets[#batch.targets+1]={id=p,disabledKey=disabledKey} end
        end
        if #batch.targets==0 and denied and not batch.future then return nil,"denied" end
        return batch
    end
    local function runCollective(actor,_,arg,batch)
        local assignment=arg.action==nil
        local action=assignment and "role_assign" or arg.action
        local value=assignment and {id=arg.role} or arg.value
        for _,target in ipairs(batch.targets) do
            local ok,err=pcall(function()
                actions[action].run(actor,target.id,value)
                if target.disabledKey then storeDisabledEffect(players[target.id],target.disabledKey) end
            end)
            if ok then batch.details.affected=batch.details.affected+1
            else
                batch.details.failed=batch.details.failed+1
                DebugPrint("[Open Session Panel] collective "..action..": "..tostring(err))
            end
        end
        if batch.future then
            C.setDefault(collectiveDefaults,arg.scope,arg.role,arg.action,arg.value,arg.excludeSelf)
            C.write(collectiveRoot.."defaults.",collectiveDefaults)
            batch.details.defaultsSaved=true
        end
        return batch.details
    end
    add("players_group",C.validRequest,runCollective,{prepare=function(actor,arg) return prepareCollective(actor,arg,false) end})
    add("roles_assign_many",C.validAssignment,runCollective,{prepare=function(actor,arg) return prepareCollective(actor,arg,true) end})
    function server.ospCommand(actor,action,target,arg,requestId,targetContext)
        if not OSP.finite(actor) or not IsPlayerValid(actor) then return end
        syncPlayers()
        local def=type(action)=="string" and actions[action] or nil
        local function deny(code)
            -- Don't fill the activity ring with malformed or denied traffic.
            reply(actor,false,code,nil,requestId)
        end
        if requestId~=nil and (not OSP.finite(requestId) or requestId<1 or requestId%1~=0) then
            requestId=nil; deny("invalid"); return
        end
        if not isAdmin(actor) then deny("denied"); return end
        if not def then deny("invalid"); return end
        if def.prepare and target~=0 then deny("invalid");return end
        if def.host and not isHost(actor) then deny("denied"); return end
        if administrative[action] and not isHost(actor) and not P.allows(playerRole(actor).permissions,action,target,arg,actor) then
            deny("denied");return
        end
        if def.aliveCaller and GetPlayerHealth(actor)<=0 then deny("unavailable"); return end
        if def.target then
            if not OSP.finite(target) or not IsPlayerValid(target) or not players[target] then deny("unavailable"); return end
            local contextValid=type(targetContext)=="table"
                and type(targetContext.host)=="string" and #targetContext.host==32
                and targetContext.host:match("^[0-9a-f]+$")
                and OSP.finite(targetContext.targetJoin) and targetContext.targetJoin>=1
                and targetContext.targetJoin%1==0
            if contextValid then
                for key in pairs(targetContext) do
                    if key~="host" and key~="targetJoin" then contextValid=false;break end
                end
            end
            if not contextValid or targetContext.host~=profileHost
                or targetContext.targetJoin~=players[target].challenge then deny("unavailable");return end
            if def.aliveTarget and GetPlayerHealth(target)<=0 then deny("unavailable"); return end
            if isHost(target) and (def.noHost or (not isHost(actor) and not def.readTarget)) then deny("protected"); return end
            if (def.profileRequired or def.persistent and isHost(actor)) and not players[target].profile then deny("unavailable"); return end
        end
        local conditional=type(arg)=="table" and (action=="god" or action=="fly" or action=="noclip" or action=="strength" or action=="ammo")
        local expected
        if conditional then
            if actor~=target or type(arg.expected)~="boolean" or type(arg.value)~="boolean" or arg.expected==arg.value then deny("invalid");return end
            for key in pairs(arg) do if key~="expected" and key~="value" then deny("invalid");return end end
            expected=arg.expected;arg=arg.value
        end
        if def.validate then
            local valid,validationCode=def.validate(arg)
            if not valid then deny(validationCode or "invalid"); return end
        end
        local prepared
        if def.prepare then
            local code
            prepared,code=def.prepare(actor,arg)
            if not prepared then deny(code);return end
        elseif not isHost(actor) and not P.allows(playerRole(actor).permissions,action,target,arg,actor) then deny("denied");return end
        local administrationCode=administrationGuard(actor,action,target,arg)
        if administrationCode then deny(administrationCode);return end
        if def.noSelf and actor==target then deny("invalid");return end
        if def.guard then local code=def.guard(arg); if code then deny(code);return end end
        if conditional then
            local e=players[target]
            local current
            if action=="god" then current=e.god==true or (e.god==nil and e.baseGod==true)
            elseif action=="noclip" then current=e.noclip==true or (e.noclip==nil and e.baseFly==true)
            elseif action=="strength" then current=e.strength==true
            elseif action=="ammo" then current=e.ammo==true
            else current=e.fly==true end
            if current~=expected then deny("state_changed");return end
        end
        local disabledKey=not isHost(actor) and selfDisableKey(actor,target,action,arg)
        if disabledKey and not players[target].profile then deny("unavailable");return end
        -- Throttle accepted requests, not permission revocations (which must win immediately).
        local now=GetTime()
        if action~="admin" and action~="role_assign" and action~="roles_assign_many" and action~="role_save" and action~="role_reset" and action~="role_delete" and lastRequest[actor] and now-lastRequest[actor]<0.05 then deny("rate_limited"); return end
        lastRequest[actor]=now
        local ok,details=pcall(function()
            local result=def.run(actor,target,arg,prepared)
            if disabledKey then storeDisabledEffect(players[target],disabledKey) end
            return result
        end)
        local code=ok and "ok" or "error"
        if not ok then DebugPrint("[Open Session Panel] "..action..": "..tostring(details)); details={} end
        details=details or {affected=1,skipped=0}
        if ok and details.failed and details.failed>0 then
            code=(details.affected>0 or details.defaultsSaved) and "partial" or "error"
            ok=code=="partial"
        end
        if ok and (action=="tool" or action=="tools" or action=="tool_all" or action=="tools_all"
            or action=="tools_filtered" or action=="tools_filtered_all" or action=="tools_selection" or action=="tools_selection_all"
            or action=="tool_policy" or action=="tool_policy_bulk" or action=="tool_policy_selection") then
            for _,p in ipairs(roster()) do if players[p].ammo then ammoController:tick(p,players[p],true) end end
        end
        record(actor,action,target,code,details,arg)
        publish(); reply(actor,ok,code,details,requestId)
    end
    local function flightInputAllowed(p,e)
        -- GetTime is wall time in tick but simulation time in update.
        -- Use the tick clock for both receipt and expiry, including physics steps.
        local age=e.flightInputAt and flightInputClock-e.flightInputAt
        local fresh=age~=nil and age>=0 and age<=0.5
        if fresh and e.flightInput==false then return false end
        if GetPlayerCanUseTool(p) then return true end
        -- Tool availability also becomes false while grabbing or using Plank.
        -- Only a fresh report of this player's gameplay context can override it.
        return e.flightInput==true and fresh
            and GetPlayerScreen(p)==0 and not IsPlayerDisabled(p)
    end
    function server.ospFlightInput(actor,namespace,challenge,sequence,allowed)
        if not OSP.finite(actor) or not IsPlayerValid(actor) or namespace~=profileHost
            or type(allowed)~="boolean" or not OSP.finite(sequence)
            or sequence<1 or sequence>2147483647 or sequence%1~=0 then return end
        local e=players[actor]
        if not e or challenge~=e.challenge or not e.fly
            or sequence<=(e.flightInputSequence or 0) then return end
        -- This transient input report grants no ability, role or saved setting.
        e.flightInputSequence=sequence;e.flightInput=allowed;e.flightInputAt=flightInputClock
    end
    local function strengthInputAllowed(p,e)
        local age=e.strengthInputAt and flightInputClock-e.strengthInputAt
        return e.strengthInput==true and age~=nil and age>=0 and age<=0.5
            and GetPlayerScreen(p)==0 and not IsPlayerDisabled(p)
    end
    function server.ospStrengthInput(actor,namespace,challenge,sequence,allowed)
        if not OSP.finite(actor) or not IsPlayerValid(actor) or namespace~=profileHost
            or type(allowed)~="boolean" or not OSP.finite(sequence)
            or sequence<1 or sequence>2147483647 or sequence%1~=0 then return end
        local e=players[actor]
        if not e or challenge~=e.challenge or not e.strength
            or sequence<=(e.strengthInputSequence or 0) then return end
        e.strengthInputSequence=sequence;e.strengthInput=allowed;e.strengthInputAt=flightInputClock
    end
    local function updatePlayer(p,readInput)
        local e=players[p]
        enforceTools(p)
        local alive=GetPlayerHealth(p)>0
        if alive and not e.alive then
            stopFlight(e)
            e.baseSpeed=GetPlayerWalkingSpeed(p)
            if e.freeze then e.anchor=GetPlayerTransform(p) end
        end
        e.alive=alive
        if not alive then ammoController:stop(p,e.ammoRestore==true);stopFlight(e);return end
        if e.god~=nil then SetPlayerParam("godMode",e.god,p) end
        local seated=GetPlayerVehicle(p)~=0
        if e.noclip~=nil then SetPlayerParam("flyMode",e.noclip and not seated,p) end
        if e.speed~=1 and not e.noclip then SetPlayerParam("walkingSpeed",e.baseSpeed*e.speed,p) end
        if rules.regen~=nil then SetPlayerRegenerationState(rules.regen,p) end
        local noclip=e.noclip==true or (e.noclip==nil and e.baseFly==true)
        if not e.fly or noclip or e.freeze or GetPlayerVehicle(p)~=0 then stopFlight(e)
        elseif readInput then
            if not flightInputAllowed(p,e) then e.jumpAt=nil
            elseif InputPressed("jump",p) then
                local now=GetTime()
                if e.jumpAt and now>e.jumpAt and now-e.jumpAt<=0.3 then
                    e.flying=not e.flying;e.jumpAt=nil
                    SetPlayerVelocity(Vec(0,0,0),p)
                else e.jumpAt=now end
            end
        end
        if e.flying then
            -- Keep the normal character collider; suppress only native walking
            -- and jump impulses while the fixed-step flight velocity drives it.
            SetPlayerParam("walkingSpeed",0,p);SetPlayerParam("jumpSpeed",0,p)
        end
        if e.freeze then
            DisablePlayerInput(p)
            SetPlayerVehicle(0,p)
            SetPlayerTransform(e.anchor,p)
            SetPlayerVelocity(Vec(0,0,0),p)
        elseif e.noclip and not seated then
            -- Logical movement inputs honor the player's actual keyboard mapping.
            local x=(InputDown("right",p) and 1 or 0)-(InputDown("left",p) and 1 or 0)
            local z=(InputDown("down",p) and 1 or 0)-(InputDown("up",p) and 1 or 0)
            local y=(InputDown("jump",p) and 1 or 0)-(InputDown("crouch",p) and 1 or 0)
            local direction=TransformToParentVec(GetPlayerCameraTransform(p),Vec(x,0,z))
            direction=VecAdd(direction,Vec(0,y,0))
            local length=VecLength(direction)
            if length>1 then direction=VecScale(direction,1/length) end
            local speed=InputDown("shift",p) and e.noclipBoost or e.noclipSpeed
            SetPlayerVelocity(VecScale(direction,speed),p)
        end
    end
    function server.ospIdentify(actor,namespace,challenge,id)
        -- Mod-local identity, not an authenticated game account. Never match
        -- names or recyclable player IDs to saved roles and restrictions.
        if not OSP.finite(actor) or not IsPlayerValid(actor) or namespace~=profileHost then return end
        syncPlayers()
        local e=players[actor]
        if challenge~=e.challenge then return end
        if not e.profile then
            local valid=type(id)=="string" and #id<=12 and id:match("^p%d+$") and HasKey(profileSave..id..".exists")
            for p,other in pairs(players) do
                if p~=actor and other.profile==id then valid=false end
            end
            if not valid then
                local nextId=GetInt("savegame.mod.osp.nextprofile")+1
                if nextId<1 or nextId>2147483647 then return end
                SetInt("savegame.mod.osp.nextprofile",nextId)
                id="p"..nextId
                SetBool(profileSave..id..".exists",true)
            end
            loadProfile(actor,e,id)
            updatePlayer(actor)
            publish()
        end
        ClientCall(actor,"client.ospIdentity",profileHost,e.challenge,e.profile)
    end
    function server.tick()
        flightInputClock=GetTime()
        syncPlayers()
        local refresh=GetTime()>=refreshAt
        if refresh then refreshAt=GetTime()+0.2;refreshTools() end
        -- Only names/UI publication wait for the 5 Hz catalog refresh.
        -- A saved policy must see its tool as soon as the engine registers it.
        for id in pairs(policies) do
            if not known[id] and HasKey("game.tool."..id) then known[id]=true end
        end
        for _,e in pairs(players) do
            for id in pairs(e.toolRules) do
                if not known[id] and HasKey("game.tool."..id) then known[id]=true end
            end
        end
        if rules.time~=nil then SetTimeScale(rules.time) end
        for _,p in ipairs(roster()) do
            updatePlayer(p,true)
            local e=players[p]
            ammoController:tick(p,e,refresh)
            strengthController:tick(p,e,strengthInputAllowed(p,e))
        end
        if refresh then publish() end
    end
    function server.update(dt)
        for _,p in ipairs(roster()) do
            local e=players[p]
            if e then strengthController:update(p,e,dt,strengthInputAllowed(p,e)) end
            if e and e.flying then
                if not e.fly or e.noclip or e.freeze or GetPlayerHealth(p)<=0 or GetPlayerVehicle(p)~=0 then stopFlight(e)
                else
                    local direction=Vec(0,0,0)
                    if flightInputAllowed(p,e) then
                        -- Flatten the camera direction so looking up/down does
                        -- not turn forward movement into vertical movement.
                        local forward=TransformToParentVec(GetPlayerCameraTransform(p),Vec(0,0,-1))
                        forward[2]=0
                        if VecLength(forward)<0.001 then
                            forward=TransformToParentVec(GetPlayerTransform(p),Vec(0,0,-1));forward[2]=0
                        end
                        local length=VecLength(forward)
                        if length>0 then forward=VecScale(forward,1/length) end
                        local right=Vec(-forward[3],0,forward[1])
                        local x=(InputDown("right",p) and 1 or 0)-(InputDown("left",p) and 1 or 0)
                        local z=(InputDown("up",p) and 1 or 0)-(InputDown("down",p) and 1 or 0)
                        local y=(InputDown("jump",p) and 1 or 0)-(InputDown("crouch",p) and 1 or 0)
                        direction=VecAdd(VecAdd(VecScale(right,x),VecScale(forward,z)),Vec(0,y,0))
                        length=VecLength(direction)
                        if length>1 then direction=VecScale(direction,1/length) end
                    end
                    -- Cancel gravity for this physics step without changing the
                    -- scene's gravity, teleporting or disabling collisions.
                    local speed=InputDown("shift",p) and e.flyBoost or e.flySpeed
                    SetPlayerVelocity(VecAdd(VecScale(direction,speed),VecScale(GetGravity(),-dt)),p)
                end
            end
        end
    end
    function server.destroy()
        -- Engine documents destroy for game modes only; never rely on this for
        -- global-mod unloading. A map reload is the supported full cleanup.
        restoreRules()
        for _,p in ipairs(roster()) do
            local e=players[p]
            if e then
                ammoController:stop(p,e.ammoRestore==true)
                strengthController:release(p,false)
                SetPlayerParam("godMode",e.baseGod,p)
                SetPlayerParam("flyMode",e.baseFly,p)
            end
        end
    end
end
