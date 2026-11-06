-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Shared permission vocabulary. The server owns assignments and templates.
OSP.Permissions = {}
local P = OSP.Permissions
P.spec = {
    {id="heal",target=true},{id="respawn",target=true},{id="goto",target=true},
    {id="bring",target=true},{id="kill",target=true},{id="eject",target=true},
    {id="god",target=true},{id="fly",target=true},{id="freeze",target=true},
    {id="speed",target=true},{id="tools",target=true},
    {id="heal_all"},{id="bring_all"},{id="tools_all"},{id="announce"},
    {id="rule_time"},{id="rule_rain"},{id="rule_fog"},{id="rule_regen"},{id="reset_rules"},
}
P.reserved = {admin=true,reset_player=true,restart=true,tool_policy=true,tool_policy_bulk=true,
    role_assign=true,role_save=true,role_delete=true}
local aliases = {tool="tools",tools_filtered="tools",tool_all="tools_all",tools_filtered_all="tools_all"}
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
for _,spec in ipairs(P.spec) do all[spec.id]=2 end
P.builtins={
    preset("guest",{}),
    preset("self",{heal=1,respawn=1,["goto"]=2,eject=1,god=1,fly=1,speed=1,tools=1}),
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
    if action=="rule" then
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
