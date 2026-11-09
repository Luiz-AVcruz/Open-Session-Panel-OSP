-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Selection and entry defaults are separate from Role permissions and grants.
OSP.Collective = {}
local C=OSP.Collective
C.effects={god="god",fly="flight",noclip="noclip",freeze="freeze",strength="strength",ammo="ammo"}
C.actions={god=true,fly=true,noclip=true,freeze=true,strength=true,ammo=true,heal=true,bring=true}
C.maxTargets=256

local function integer(v,minimum)
    return OSP.finite(v) and v>=minimum and v<=2147483647 and v%1==0
end
local function fields(value,allowed)
    for k in pairs(value) do if not allowed[k] then return false end end
    return true
end
function C.validTargets(targets)
    if type(targets)~="table" or #targets>C.maxTargets then return false end
    local seen,count={},0
    for i,t in pairs(targets) do
        if not integer(i,1) or i>#targets or type(t)~="table"
            or not fields(t,{id=true,join=true}) or not integer(t.id,0) or not integer(t.join,1)
            or seen[t.id] then return false end
        seen[t.id]=true;count=count+1
    end
    return count==#targets
end
local function context(v)
    return type(v)=="table" and type(v.host)=="string" and #v.host==32
        and v.host:match("^[0-9a-f]+$")~=nil and integer(v.actorJoin,1) and C.validTargets(v.targets)
end
function C.validRequest(v)
    if not context(v) or not fields(v,{host=true,actorJoin=true,action=true,scope=true,role=true,excludeSelf=true,targets=true,value=true})
        or not C.actions[v.action] or type(v.excludeSelf)~="boolean" then return false end
    if v.scope~="all" and v.scope~="role" and v.scope~="manual" then return false end
    if v.scope=="role" then
        if type(v.role)~="string" or #v.role==0 or #v.role>80 then return false end
    elseif v.role~=nil then return false end
    if C.effects[v.action] then return type(v.value)=="boolean" end
    return v.value==nil
end
function C.validAssignment(v)
    return context(v) and fields(v,{host=true,actorJoin=true,role=true,targets=true})
        and type(v.role)=="string" and #v.role>0 and #v.role<=80 and #v.targets>0
end
function C.matches(player,scope,role,excludeSelf,actor)
    if excludeSelf and player.id==actor then return false end
    if scope=="role" then return not player.host and player.role==role end
    return scope=="all" or scope=="manual"
end

-- Only explicit profile choices are saved as choices. Entry defaults stay here.
function C.load(root,roles)
    local result={all={},roles={}}
    local function read(path,global)
        local values={}
        for effect in pairs(C.effects) do
            local value=GetInt(path..effect)
            if value==1 or value==2 then
                values[effect]=global and {value=value==1,excludeHost=GetBool(path..effect.."_exclude_host")} or value==1
            end
        end
        return values
    end
    result.all=read(root.."all.",true)
    for _,role in ipairs(roles) do
        local values=read(root.."roles."..role.id..".",false)
        if next(values) then result.roles[role.id]=values end
    end
    return result
end
function C.write(root,defaults)
    ClearKey(root:sub(1,-2))
    for effect,value in pairs(defaults.all) do
        SetInt(root.."all."..effect,value.value and 1 or 2)
        SetBool(root.."all."..effect.."_exclude_host",value.excludeHost)
    end
    for id,values in pairs(defaults.roles) do
        for effect,value in pairs(values) do SetInt(root.."roles."..id.."."..effect,value and 1 or 2) end
    end
end
function C.setDefault(defaults,scope,role,effect,value,excludeSelf)
    local function set(key,on)
        if scope=="all" then
            defaults.all[key]={value=on,excludeHost=excludeSelf}
            for _,values in pairs(defaults.roles) do values[key]=nil end
        else
            defaults.roles[role]=defaults.roles[role] or {}
            defaults.roles[role][key]=on
        end
    end
    set(effect,value)
    if value and effect=="fly" then set("noclip",false)
    elseif value and effect=="noclip" then set("fly",false) end
end
function C.inherit(defaults,e,isHost,hasChoice,role)
    local inherited={}
    for effect,key in pairs(C.effects) do
        if not hasChoice(key) and not (effect=="noclip" and hasChoice("fly")) then
            local value=defaults.roles[role] and defaults.roles[role][effect]
            if isHost then value=nil end
            if value==nil then
                local general=defaults.all[effect]
                if general and not (isHost and general.excludeHost) then value=general.value end
            end
            if value~=nil then e[effect]=value;inherited[effect]=true end
        end
    end
    if e.fly and e.noclip and (inherited.fly or inherited.noclip) then
        if inherited.fly and not inherited.noclip then e.fly=false
        else e.noclip=false end
    end
end
