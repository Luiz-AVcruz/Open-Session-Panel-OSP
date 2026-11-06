-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Small numeric text capture shared by the in-game and Mod Manager palettes.
OSP = OSP or {}
OSP.NumberInput = {}
local N = OSP.NumberInput
local current = nil

local function finite(value)
    return type(value)=="number" and value==value and value~=math.huge and value~=-math.huge
end
local function clamp(value,minimum,maximum)
    return math.max(minimum,math.min(maximum,value))
end
local function digits(value)
    return (value:match("%d") ~= nil)
end
local function rounded(value,decimals)
    local factor=10^decimals
    return math.floor(value*factor+0.5)/factor
end

function N.active(id)
    return current~=nil and (id==nil or current.id==id)
end

function N.begin(id,value,minimum,maximum,decimals,onCommit)
    if type(id)~="string" or id=="" or not finite(minimum) or not finite(maximum) or minimum>maximum
        or type(onCommit)~="function" then return false end
    decimals=finite(decimals) and math.max(0,math.min(6,math.floor(decimals))) or 0
    if not finite(value) then value=minimum end
    value=clamp(value,minimum,maximum)
    current={id=id,buffer=string.format("%."..decimals.."f",value),minimum=minimum,maximum=maximum,
        decimals=decimals,onCommit=onCommit,fresh=true}
    return true
end

function N.caption(id,value)
    if current and current.id==id then return current.buffer.."_" end
    return tostring(value)
end

function N.cancel()
    local wasActive=current~=nil
    current=nil
    return wasActive
end

local function commit()
    local input=current
    if not input or not digits(input.buffer) then return false end
    local parsed=tonumber(input.buffer)
    if parsed==nil or parsed~=parsed then return false end
    if parsed==math.huge then parsed=input.maximum
    elseif parsed==-math.huge then parsed=input.minimum end
    parsed=clamp(parsed,input.minimum,input.maximum)
    parsed=rounded(parsed,input.decimals)
    parsed=clamp(parsed,input.minimum,input.maximum)
    current=nil
    input.onCommit(parsed)
    return true
end

function N.key()
    if not current then return false end
    local key=string.lower(InputLastPressedKey() or "")
    if key=="" then return true end
    if key=="lmb" or key=="rmb" or key=="mmb" then return true end

    local input=current
    if key=="esc" or key=="escape" then
        current=nil
    elseif key=="return" or key=="enter" then
        commit()
    elseif key=="backspace" then
        input.buffer=input.buffer:sub(1,-2)
        input.fresh=false
    elseif key=="delete" or key=="del" then
        input.buffer=""
        input.fresh=false
    elseif key=="-" or key=="minus" or key=="subtract" then
        if input.fresh then input.buffer="-";input.fresh=false
        elseif input.buffer:sub(1,1)~="-" then input.buffer="-"..input.buffer end
    elseif key=="." or key=="," or key=="period" or key=="comma" or key=="decimal" then
        if input.fresh then input.buffer="0.";input.fresh=false
        elseif not input.buffer:find("%.",1,false) then
            if input.buffer=="-" then input.buffer="-0."
            else input.buffer=input.buffer.."." end
        end
    elseif key:match("^%d$") then
        if input.fresh then input.buffer=key;input.fresh=false
        elseif #input.buffer<64 then input.buffer=input.buffer..key end
    end

    -- InputClear forgets every game input, so only call it for a keyboard key.
    InputClear()
    return true
end
