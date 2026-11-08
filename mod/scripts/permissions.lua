-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Shared permission vocabulary. The server owns assignments and templates.
OSP.Permissions = {}
local P = OSP.Permissions
P.categories = {{id="players"},{id="movement"},{id="abilities"},{id="tools"},{id="session"},{id="admin"}}
P.spec = {
    {id="heal",target=true,category="players"},{id="respawn",target=true,category="players"},
    {id="goto",target=true,category="movement"},{id="bring",target=true,category="movement"},
    {id="kill",target=true,category="players"},{id="eject",target=true,category="players"},
    {id="god",target=true,category="abilities"},{id="fly",target=true,category="movement"},
    {id="noclip",target=true,category="movement"},{id="freeze",target=true,category="players"},
    {id="speed",target=true,category="movement"},{id="strength",target=true,category="abilities"},
    {id="tools",target=true,category="tools"},{id="ammo",target=true,category="tools"},
    {id="heal_all",category="players"},{id="bring_all",category="movement"},
    {id="tools_all",category="tools"},{id="announce",category="session"},
    {id="rule_time",category="session"},{id="rule_rain",category="session"},
    {id="rule_fog",category="session"},{id="rule_regen",category="session"},{id="reset_rules",category="session"},
    {id="role_assign",category="admin"},{id="role_create",category="admin"},
    {id="role_edit",category="admin"},{id="role_delete",category="admin"},
    {id="tool_policy",category="admin"},{id="reset_player",target=true,category="admin"},{id="restart",category="admin"},
}
-- Legacy all-or-nothing assignment remains host-only for older clients.
P.reserved = {admin=true}
local aliases = {tool_policy_bulk="tool_policy",tool_policy_selection="tool_policy",ammo_restore="ammo",tool="tools",tools_filtered="tools",tool_all="tools_all",tools_filtered_all="tools_all",
    tools_selection="tools",tools_selection_all="tools_all",
    fly_speed="fly",fly_boost="fly",noclip_speed="noclip",noclip_boost="noclip",
    strength_force="strength",strength_mass="strength",strength_throw="strength",strength_throw_speed="strength"}
function P.normalize(values)
    if type(values)~="table" then return nil end
    local result,known={},{}
    for _,spec in ipairs(P.spec) do
        known[spec.id]=true
        local v=values[spec.id]
        if v==nil then v=0 end
        if type(v)~="number" or (v~=0 and v~=2 and not (v==1 and spec.target)) then return nil end
        result[spec.id]=v
    end
    for key in pairs(values) do if not known[key] then return nil end end
    return result
end
local function preset(id,values)
    return {id=id,nameKey="role_"..id,builtin=true,version=0,permissions=P.normalize(values)}
end
local all={}
for _,spec in ipairs(P.spec) do all[spec.id]=spec.category=="admin" and 0 or 2 end
P.builtins={
    preset("guest",{}),
    preset("self",{heal=1,respawn=1,["goto"]=2,eject=1,god=1,fly=1,noclip=1,speed=1,strength=1,ammo=1,tools=1}),
    preset("helper",{heal=2,respawn=2,["goto"]=2,bring=2,announce=2}),
    preset("moderator",{heal=2,respawn=2,["goto"]=2,bring=2,eject=2,freeze=2,speed=2,tools=2,heal_all=2,bring_all=2,tools_all=2,announce=2}),
    preset("admin",all),
}
function P.resolve(id,custom)
    for _,role in ipairs(P.builtins) do if role.id==id then return role end end
    return (custom and custom[id]) or P.builtins[1]
end
function P.list(custom)
    local out=OSP.copy(P.builtins)
    local ids={}
    for id in pairs(custom or {}) do ids[#ids+1]=id end
    table.sort(ids)
    for _,id in ipairs(ids) do out[#out+1]=OSP.copy(custom[id]) end
    return out
end
function P.name(role)
    return role.nameKey and OSP.L(role.nameKey) or role.name
end
function P.hasAccess(values)
    for _,spec in ipairs(P.spec) do if values and (values[spec.id] or 0)>0 then return true end end
    return false
end
function P.allows(values,action,target,arg,actor)
    if P.reserved[action] then return false end
    local key=aliases[action] or action
    if action=="role_save" then
        if type(arg)~="table" or type(arg.id)~="string" then return false end
        key=arg.id=="" and "role_create" or "role_edit"
    elseif action=="rule" then
        if type(arg)~="table" or type(arg.key)~="string" then return false end
        key="rule_"..arg.key
    end
    local value=values and values[key] or 0
    return value==2 or (value==1 and target==actor)
end
function P.validName(name)
    return type(name)=="string" and #name>=1 and #name<=40 and name:find("%S")~=nil
        and not name:find("[^ -~]") and name==name:match("^%s*(.-)%s*$")
end

-- Scope values are ordered: blocked < self < any. Missing new grants stay off.
function P.within(grants,ceiling)
    if type(grants)~="table" or type(ceiling)~="table" then return false end
    for _,spec in ipairs(P.spec) do
        if (grants[spec.id] or 0)>(ceiling[spec.id] or 0) then return false end
    end
    return true
end
function P.canManageRoles(values)
    for _,id in ipairs({"role_assign","role_create","role_edit","role_delete"}) do
        if values and values[id]==2 then return true end
    end
    return false
end
