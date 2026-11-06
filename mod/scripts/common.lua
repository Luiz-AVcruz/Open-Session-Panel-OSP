-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; additional Teardown permission: see ADDITIONAL-PERMISSION.
OSP = { version = "1.5.0" }

function OSP.finite(n)
    return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end

function OSP.copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = OSP.copy(v) end
    return result
end

function OSP.validKey(key)
    if type(key) ~= "string" then return false end
    local forbidden = { w=true,a=true,s=true,d=true,q=true,z=true,e=true,r=true,
        space=true,esc=true,tab=true,returnkey=true,shift=true,ctrl=true,alt=true,
        lmb=true,rmb=true,mmb=true }
    if forbidden[key] then return false end
    if key:match("^[a-z]$") or key:match("^[0-9]$") then return true end
    for i=1,12 do if key == "f" .. i then return true end end
    return key == "insert" or key == "home" or key == "end" or key == "delete"
end

-- IDs confirmed against the installed game's catalog and mission tools.
-- Inventory groups are not provenance: custom tools may use any group.
function OSP.toolOrigin(id)
    local vanilla={sledge=true,spraycan=true,extinguisher=true,blowtorch=true,
        shotgun=true,plank=true,pipebomb=true,gun=true,bomb=true,wire=true,
        rocket=true,booster=true,leafblower=true,turbo=true,explosive=true,
        rifle=true,steroid=true,camera=true,minigunmall=true,snowball=true}
    return vanilla[id] and "vanilla" or "mod"
end
