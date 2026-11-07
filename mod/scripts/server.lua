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
        if e.freeze then e.anchor=GetPlayerTransform(p) end
        for _,key in ipairs(ListKeys(root.."tools")) do
            if #key>0 and #key%2==0 and not key:find("[^0-9a-f]") then
                local tool=key:gsub("..",function(hex) return string.char(tonumber(hex,16)) end)
                local value=GetInt(root.."tools."..key)
                if value==1 then e.toolRules[tool]=true elseif value==2 then e.toolRules[tool]=false end
            end
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
            baseSpeed=GetPlayerWalkingSpeed(p),
            baseGod=GetPlayerParam("godMode", p),
            baseFly=GetPlayerParam("flyMode", p),
            baseRegen=GetPlayerParam("healthRegeneration", p),
            toolRules={}, toolBase={}, alive=GetPlayerHealth(p)>0,challenge=join,
        }
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
            rules=OSP.copy(rules),log=OSP.copy(logs),toolPolicies=OSP.copy(policies),profileHost=profileHost,templates=P.list(templates)}
        for _, p in ipairs(roster()) do
            local e=players[p]
            if e then
                view.players[#view.players+1]={id=p,name=GetPlayerName(p),health=GetPlayerHealth(p),
                    vehicle=GetPlayerVehicle(p)~=0,host=isHost(p),admin=isAdmin(p),god=e.god==true or (e.god==nil and e.baseGod==true),
                    fly=e.fly==true,flying=e.flying==true,flySpeed=e.flySpeed,flyBoost=e.flyBoost,
                    noclip=e.noclip==true or (e.noclip==nil and e.baseFly==true),noclipSpeed=e.noclipSpeed,noclipBoost=e.noclipBoost,
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
        elseif type(arg)=="table" then arg=nil end
        logs[#logs+1]={seq=sequence,actor=IsPlayerValid(actor) and GetPlayerName(actor) or "?",
            action=action,target=type(target)=="number" and IsPlayerValid(target) and GetPlayerName(target) or "",
            result=result,affected=details and details.affected or 0,skipped=details and details.skipped or 0,
            argument=OSP.copy(arg)}
        if #logs>100 then table.remove(logs,1) end
    end
    local function reply(actor,ok,code,details,requestId)
        ClientCall(actor,"client.ospResult",ok,code,details or {},requestId)
    end
    local function clearPlayer(p)
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
    end
    local function applyTool(p,id,on)
        local e=players[p]
        if e.toolBase[id]==nil then e.toolBase[id]=IsToolEnabled(id,p) end
        SetToolEnabled(id,on,p)
        if not on and GetPlayerTool(p)==id then
            local replacement=""
            for _,tool in ipairs(tools) do
                if IsToolEnabled(tool.id,p) then replacement=tool.id; break end
            end
            SetPlayerTool(replacement,p)
        end
    end
    local function setTool(actor,p,id,on)
        applyTool(p,id,on)
        players[p].toolRules[id]=on
        local e=players[p]
        if isHost(actor) and e.profile then
            SetInt(profileSave..e.profile..".tools."..encoded(id),on and 1 or 2)
        end
    end
    local function enforceTools(p)
        local e=players[p]
        for id in pairs(known) do
            local want=e.toolRules[id]
            if policies[id]==false then want=false
            elseif want==nil then want=policies[id] end
            if want~=nil then
                -- Capture before the first intervention even if already equal.
                if e.toolBase[id]==nil then e.toolBase[id]=IsToolEnabled(id,p) end
                if IsToolEnabled(id,p)~=want then applyTool(p,id,want) end
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
        local value
        if mode=="enabled" then value=true elseif mode=="disabled" then value=false end
        policies[id]=value
        if value==nil then ClearKey(policyKey(id)) else SetInt(policyKey(id),value and 1 or 2) end
        for _,profile in ipairs(ListKeys(profileSave:sub(1,-2))) do
            ClearKey(profileSave..profile..".tools."..encoded(id))
        end
        for _,p in ipairs(roster()) do
            local e=players[p]
            e.toolRules[id]=nil
            if value~=nil then applyTool(p,id,value)
            elseif e.toolBase[id]~=nil then applyTool(p,id,e.toolBase[id]) end
        end
        for _,tool in ipairs(tools) do if tool.id==id then tool.policy=mode end end
    end
    local function moveTo(p,anchor)
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
        if GetPlayerHealth(p)<=0 then stopFlight(players[p]);RespawnPlayer(p); players[p].alive=false; enforceTools(p) else SetPlayerHealth(1,p) end
    end
    add("heal",nil,function(_,p) heal(p) end,{target=true})
    add("kill",nil,function(_,p) stopFlight(players[p]);SetPlayerHealth(0,p) end,{target=true})
    add("respawn",nil,function(_,p) stopFlight(players[p]);RespawnPlayer(p); players[p].alive=false; enforceTools(p) end,{target=true})
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
        SetPlayerVehicle(0,p); SetPlayerParam("flyMode",v,p)
        local e=players[p]
        SetPlayerVelocity(Vec(0,0,0),p);e.noclip=v;stopFlight(e)
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
    add("freeze",boolean,function(c,p,v)
        players[p].freeze=v
        stopFlight(players[p])
        if v then
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
        saveField(c,p,"admin",id=="admin")
        SetString(profileSave..players[p].profile..".role",id)
    end
    add("admin",boolean,function(c,p,v) assignRole(c,p,v and "admin" or "guest") end,{target=true,host=true,noHost=true,persistent=true})
    add("role_assign",function(v) return type(v)=="table" and type(v.id)=="string" and P.resolve(v.id,templates).id==v.id end,
        function(c,p,v) assignRole(c,p,v.id) end,{target=true,host=true,noHost=true,persistent=true})
    local function loadTemplates()
        templates={}
        for _,id in ipairs(ListKeys(templateSave)) do
            if id:match("^c%d+$") then
                local path=templateSave.."."..id.."."
                local name,version=GetString(path.."name"),GetInt(path.."version")
                local values={}
                for _,spec in ipairs(P.spec) do values[spec.id]=GetInt(path.."permissions."..spec.id) end
                if HasKey(path.."permissions.noclip") then values.fly=GetInt(path.."permissions.flight")
                else values.noclip=values.fly;values.fly=0 end
                local permissions=P.normalize(values)
                if P.validName(name) and version>=1 and permissions then
                    templates[id]={id=id,name=name,version=version,permissions=permissions,builtin=false}
                end
            end
        end
    end
    local function templateArg(v)
        return type(v)=="table" and type(v.id)=="string" and (v.id=="" or templates[v.id]~=nil)
            and P.validName(v.name) and P.normalize(v.permissions)~=nil and OSP.finite(v.version) and v.version%1==0
    end
    add("role_save",templateArg,function(_,_,v)
        local id=v.id
        if id=="" then
            local nextId=GetInt(templateSave.."_next")+1
            id="c"..nextId;SetInt(templateSave.."_next",nextId)
        end
        local role={id=id,name=v.name,version=v.version+1,permissions=P.normalize(v.permissions),builtin=false}
        templates[id]=role
        local path=templateSave.."."..id.."."
        SetString(path.."name",role.name);SetInt(path.."version",role.version)
        for _,spec in ipairs(P.spec) do
            local key=spec.id=="fly" and "flight" or spec.id
            SetInt(path.."permissions."..key,role.permissions[spec.id])
        end
        SetInt(path.."permissions.fly",role.permissions.noclip)
        return {affected=1,skipped=0,template=OSP.copy(role)}
    end,{host=true,guard=function(v)
        if (v.id=="" and v.version~=0) or (v.id~="" and templates[v.id].version~=v.version) then return "conflict" end
        local count=0
        for id,role in pairs(templates) do
            count=count+1
            if id~=v.id and role.name:lower()==v.name:lower() then return "invalid" end
        end
        if v.id=="" and count>=16 then return "template_limit" end
    end})
    add("role_delete",function(v) return type(v)=="table" and type(v.id)=="string" and templates[v.id]~=nil and OSP.finite(v.version) end,
        function(_,_,v)
            templates[v.id]=nil;ClearKey(templateSave.."."..v.id)
            for _,e in pairs(players) do if e.role==v.id then e.role="guest";e.admin=false end end
            for _,id in ipairs(ListKeys(profileSave:sub(1,-2))) do
                local path=profileSave..id.."."
                if GetString(path.."role")==v.id then SetString(path.."role","guest");SetBool(path.."admin",false) end
            end
            return {affected=1,skipped=0,deleted=v.id}
        end,
        {host=true,guard=function(v) if templates[v.id].version~=v.version then return "conflict" end end})
    add("reset_player",nil,function(_,p)
        local e=players[p]
        ClearKey(profileSave..e.profile)
        -- Keep the assigned identity, so reconnecting does not allocate a new one.
        SetBool(profileSave..e.profile..".exists",true)
        e.admin=false;e.role="guest";e.god=nil;e.fly=false;e.noclip=nil;stopFlight(e);e.freeze=false;e.anchor=nil;e.speed=1;e.toolRules={}
        e.flySpeed=OSP.flight.normal;e.flyBoost=OSP.flight.shift
        e.noclipSpeed=OSP.flight.normal;e.noclipBoost=OSP.flight.shift
        SetPlayerParam("godMode",e.baseGod,p);SetPlayerParam("flyMode",e.baseFly,p)
        for id,on in pairs(e.toolBase) do if known[id] then applyTool(p,id,on) end end
        enforceTools(p)
    end,{target=true,host=true,persistent=true})
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
    add("tool",toolArg,function(c,p,v) setTool(c,p,v.id,v.enabled) end,{target=true,guard=toolGuard,persistent=true})
    local function allTools(c,p,on,category,selectedIds)
        if isHost(c) and not players[p].profile then return false end
        local applied=0
        for _,id in ipairs(selectedIds or chooseCategory(category or "all")) do
            if not on or policies[id]~=false then setTool(c,p,id,on);applied=applied+1 end
        end
        return applied>0
    end
    add("tools",boolean,function(c,p,v)
        local changed=allTools(c,p,v)
        return {affected=changed and 1 or 0,skipped=changed and 0 or 1}
    end,{target=true,persistent=true})
    add("tool_all",toolArg,function(c,_,v) return each(c,function(p)
        if isHost(c) and not players[p].profile then return false end
        setTool(c,p,v.id,v.enabled)
    end) end,{guard=toolGuard})
    add("tools_all",boolean,function(c,_,v) return each(c,function(p) return allTools(c,p,v) end) end)
    local function category(v) return v=="all" or v=="vanilla" or v=="mod" end
    local function filteredArg(v) return type(v)=="table" and category(v.category) and boolean(v.enabled) end
    add("tools_filtered",filteredArg,function(c,p,v)
        local changed=allTools(c,p,v.enabled,v.category)
        return {affected=changed and 1 or 0,skipped=changed and 0 or 1}
    end,{target=true,persistent=true})
    add("tools_filtered_all",filteredArg,function(c,_,v)
        return each(c,function(p) return allTools(c,p,v.enabled,v.category) end)
    end)
    local function mode(v) return v=="default" or v=="enabled" or v=="disabled" end
    add("tool_policy",function(v) return type(v)=="table" and type(v.id)=="string" and known[v.id] and mode(v.mode) end,
        function(_,_,v)
            setPolicy(v.id,v.mode)
            return {affected=#roster(),skipped=0,tools=1}
        end,{host=true})
    add("tool_policy_bulk",function(v) return type(v)=="table" and category(v.category) and mode(v.mode) end,
        function(_,_,v)
            local ids=chooseCategory(v.category)
            for _,id in ipairs(ids) do setPolicy(id,v.mode) end
            return {affected=#ids>0 and #roster() or 0,skipped=0,tools=#ids}
        end,{host=true})
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
        local changed=allTools(c,p,v.enabled,v.category,v.ids)
        return {affected=changed and 1 or 0,skipped=changed and 0 or 1,tools=#v.ids}
    end,{target=true,persistent=true})
    add("tools_selection_all",function(v) return selectionArg(v,false) end,function(c,_,v)
        local details=each(c,function(p) return allTools(c,p,v.enabled,v.category,v.ids) end)
        details.tools=#v.ids
        return details
    end)
    add("tool_policy_selection",function(v) return selectionArg(v,true) end,function(_,_,v)
        for _,id in ipairs(v.ids) do setPolicy(id,v.mode) end
        return {affected=#roster(),skipped=0,tools=#v.ids}
    end,{host=true})
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
    add("restart",nil,function() Restart() end,{host=true})
    add("announce",cleanText,function(c,_,v) ClientCall(0,"client.ospAnnouncement",GetPlayerName(c),v) end)

    function server.init()
        players,rules,logs,lastRequest,removalSeen={},{},{},{},{}
        sequence,refreshAt=0,0
        profileHost=GetString("savegame.mod.osp.hostid")
        if not profileHost:match("^[0-9a-f]+$") or #profileHost~=32 then
            profileHost=""
            for _=1,4 do profileHost=profileHost..string.format("%08x",GetRandomInt(0,2147483647)) end
            SetString("savegame.mod.osp.hostid",profileHost)
        end
        original={rain=GetEnvironmentProperty("rain"),fog={GetEnvironmentProperty("fogparams")}}
        loadTemplates(); loadPolicies(); syncPlayers(); refreshTools()
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
        if def.host and not isHost(actor) then deny("denied"); return end
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
            if def.persistent and isHost(actor) and not players[target].profile then deny("unavailable"); return end
        end
        local conditional=type(arg)=="table" and (action=="god" or action=="fly" or action=="noclip")
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
        if not isHost(actor) and not P.allows(playerRole(actor).permissions,action,target,arg,actor) then deny("denied");return end
        if def.noSelf and actor==target then deny("invalid");return end
        if def.guard then local code=def.guard(arg); if code then deny(code);return end end
        if conditional then
            local e=players[target]
            local current
            if action=="god" then current=e.god==true or (e.god==nil and e.baseGod==true)
            elseif action=="noclip" then current=e.noclip==true or (e.noclip==nil and e.baseFly==true)
            else current=e.fly==true end
            if current~=expected then deny("state_changed");return end
        end
        -- Throttle accepted requests, not permission revocations (which must win immediately).
        local now=GetTime()
        if action~="admin" and action~="role_assign" and action~="role_save" and action~="role_delete" and lastRequest[actor] and now-lastRequest[actor]<0.05 then deny("rate_limited"); return end
        lastRequest[actor]=now
        local ok,details=pcall(def.run,actor,target,arg)
        local code=ok and "ok" or "error"
        if not ok then DebugPrint("[Open Session Panel] "..action..": "..tostring(details)); details={} end
        details=details or {affected=1,skipped=0}
        record(actor,action,target,code,details,arg)
        publish(); reply(actor,ok,code,details,requestId)
    end
    local function flightInputAllowed(p,e)
        local age=e.flightInputAt and GetTime()-e.flightInputAt
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
        e.flightInputSequence=sequence;e.flightInput=allowed;e.flightInputAt=GetTime()
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
        if not alive then stopFlight(e);return end
        if e.god~=nil then SetPlayerParam("godMode",e.god,p) end
        if e.noclip~=nil then SetPlayerParam("flyMode",e.noclip,p) end
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
        elseif e.noclip then
            -- Logical movement inputs honor the player's actual keyboard mapping.
            local x=(InputDown("right",p) and 1 or 0)-(InputDown("left",p) and 1 or 0)
            local z=(InputDown("down",p) and 1 or 0)-(InputDown("up",p) and 1 or 0)
            local y=(InputDown("jump",p) and 1 or 0)-(InputDown("crouch",p) and 1 or 0)
            local direction=TransformToParentVec(GetPlayerCameraTransform(p),Vec(x,0,z))
            direction=VecAdd(direction,Vec(0,y,0))
            local length=VecLength(direction)
            if length>1 then direction=VecScale(direction,1/length) end
            SetPlayerVehicle(0,p)
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
        for _,p in ipairs(roster()) do updatePlayer(p,true) end
        if refresh then publish() end
    end
    function server.update(dt)
        for _,p in ipairs(roster()) do
            local e=players[p]
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
                SetPlayerParam("godMode",e.baseGod,p)
                SetPlayerParam("flyMode",e.baseFly,p)
            end
        end
    end
end
