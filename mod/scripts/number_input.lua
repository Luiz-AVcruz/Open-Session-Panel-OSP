-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Small numeric text capture shared by the in-game and Mod Manager palettes.
OSP = OSP or {}
OSP.NumberInput = {}
local N = OSP.NumberInput
local current = nil
local lastMouseDown = false

local MAX_BUFFER = 64
local REPEAT_DELAY = 0.4
local REPEAT_INTERVAL = 0.05

local function finite(value)
    return type(value)=="number" and value==value and value~=math.huge and value~=-math.huge
end

local function clamp(value,minimum,maximum)
    return math.max(minimum,math.min(maximum,value))
end

local function rounded(value,decimals)
    local factor=10^decimals
    return math.floor(value*factor+0.5)/factor
end

local function normalizedNumber(value,minimum,maximum,decimals)
    value=clamp(value,minimum,maximum)
    value=rounded(value,decimals)
    return clamp(value,minimum,maximum)
end

local function formatNumber(value,decimals)
    local result=string.format("%."..decimals.."f",value)
    if #result>MAX_BUFFER then return nil end
    return result
end

local function hasDigit(value)
    return value:match("%d")~=nil
end

local function partialNumber(value)
    return #value<=MAX_BUFFER and value:match("^%-?%d*[%.%,]?%d*$")~=nil
end

local function parseNumber(value)
    if not partialNumber(value) or not hasDigit(value) then return nil end
    local parsed=tonumber((value:gsub(",",".")))
    if parsed==nil or parsed~=parsed then return nil end
    return parsed
end

local function editable(input)
    return input~=nil and input.mode=="text"
end

local function selection(input)
    local first=math.min(input.cursor,input.anchor)
    local last=math.max(input.cursor,input.anchor)
    return first,last
end

local function hasSelection(input)
    return input.cursor~=input.anchor
end

local function moveCursor(input,index,extend)
    index=finite(index) and math.floor(index) or 0
    index=math.max(0,math.min(#input.buffer,index))
    if not extend then input.anchor=index end
    input.cursor=index
end

local function replaceSelection(input,text)
    if not editable(input) then return false end
    local first,last=selection(input)
    local candidate=input.buffer:sub(1,first)..text..input.buffer:sub(last+1)
    if not partialNumber(candidate) then return false end
    input.buffer=candidate
    moveCursor(input,first+#text,false)
    return true
end

local function insertCharacter(input,text)
    if not editable(input) then return false end
    local first,last=selection(input)
    local candidate=input.buffer:sub(1,first)..text..input.buffer:sub(last+1)
    if #candidate>MAX_BUFFER or not partialNumber(candidate) then return false end
    input.buffer=candidate
    moveCursor(input,first+#text,false)
    return true
end

local function clearSelection(input)
    if not hasSelection(input) then return false end
    return replaceSelection(input,"")
end

local function deleteBackward(input)
    if hasSelection(input) then return clearSelection(input) end
    if input.cursor<=0 then return false end
    local first=input.cursor-1
    input.buffer=input.buffer:sub(1,first)..input.buffer:sub(input.cursor+1)
    moveCursor(input,first,false)
    return true
end

local function deleteForward(input)
    if hasSelection(input) then return clearSelection(input) end
    if input.cursor>=#input.buffer then return false end
    input.buffer=input.buffer:sub(1,input.cursor)..input.buffer:sub(input.cursor+2)
    moveCursor(input,input.cursor,false)
    return true
end

local function selectAll(input)
    if not editable(input) then return false end
    input.cursor=#input.buffer
    input.anchor=0
    return true
end

local function commitText(input)
    if current~=input then return false end
    local parsed=parseNumber(input.buffer)
    if parsed==nil then return false end
    if parsed==math.huge then parsed=input.maximum
    elseif parsed==-math.huge then parsed=input.minimum end
    local value=normalizedNumber(parsed,input.minimum,input.maximum,input.decimals)
    current=nil
    input.onCommit(value)
    return true
end

function N.active(id)
    return current~=nil and (id==nil or current.id==id)
end

local function start(id,value,minimum,maximum,decimals,onCommit,mode)
    if type(id)~="string" or id=="" or not finite(minimum) or not finite(maximum) or minimum>maximum
        or type(onCommit)~="function" then return false end
    decimals=finite(decimals) and math.max(0,math.min(6,math.floor(decimals))) or 0
    if not finite(value) then value=minimum end
    local initial=normalizedNumber(value,minimum,maximum,decimals)
    local buffer=formatNumber(initial,decimals)
    if buffer==nil then return false end
    current={id=id,mode=mode,buffer=buffer,cursor=#buffer,anchor=0,minimum=minimum,maximum=maximum,
        decimals=decimals,onCommit=onCommit,originalValue=value,value=initial}
    return true
end

function N.begin(id,value,minimum,maximum,decimals,onCommit)
    return start(id,value,minimum,maximum,decimals,onCommit,"text")
end

function N.beginDrag(id,value,minimum,maximum,decimals,onCommit)
    return start(id,value,minimum,maximum,decimals,onCommit,"drag")
end

function N.caption(id,value)
    if current and current.id==id then return current.buffer end
    return tostring(value)
end

function N.state(id)
    if not current or (id~=nil and current.id~=id) then return nil end
    local value=current.value
    if current.mode=="text" then
        local parsed=parseNumber(current.buffer)
        if parsed==nil then value=current.originalValue
        else
            if parsed==math.huge then parsed=current.maximum
            elseif parsed==-math.huge then parsed=current.minimum end
            value=normalizedNumber(parsed,current.minimum,current.maximum,current.decimals)
        end
    end
    return {id=current.id,mode=current.mode,buffer=current.buffer,cursor=current.cursor,anchor=current.anchor,
        minimum=current.minimum,maximum=current.maximum,decimals=current.decimals,value=value}
end

function N.placeCursor(index,extend)
    if not editable(current) then return false end
    moveCursor(current,index,extend==true)
    return true
end

function N.selectAll()
    return selectAll(current)
end

function N.cancel()
    local wasActive=current~=nil
    current=nil
    return wasActive
end

function N.dragTo(rawValue)
    if not current or current.mode~="drag" or not finite(rawValue) then return false end
    local value=normalizedNumber(rawValue,current.minimum,current.maximum,current.decimals)
    local buffer=formatNumber(value,current.decimals)
    if buffer==nil then return false end
    current.value=value
    current.buffer=buffer
    return true
end

function N.commit()
    if not current then return false end
    local input=current
    if input.mode=="drag" then
        local value=input.value
        current=nil
        input.onCommit(value)
        return true
    end
    return commitText(input)
end

function N.blur()
    if not current then return false end
    if N.commit() then return true end
    N.cancel()
    return false
end

local function safeDown(key)
    return type(InputDown)=="function" and InputDown(key)==true or false
end

local keyInputs={
    ["0"]="0",["1"]="1",["2"]="2",["3"]="3",["4"]="4",["5"]="5",["6"]="6",["7"]="7",["8"]="8",["9"]="9",
    backspace="backspace",delete="delete",left="leftarrow",right="rightarrow",home="home",["end"]="end",
}

function N.sample()
    local key=type(InputLastPressedKey)=="function" and InputLastPressedKey() or ""
    local now=type(GetTime)=="function" and GetTime() or 0
    local frame={key=type(key)=="string" and key:lower() or "",time=finite(now) and now or 0,
        ctrl=safeDown("ctrl"),shift=safeDown("shift"),down={}}
    for normalized,physical in pairs(keyInputs) do
        frame.down[normalized]=safeDown(physical)
    end
    frame.mousePressed=type(InputPressed)=="function" and InputPressed("lmb")==true or false
    frame.mouseDown=safeDown("lmb")
    if type(InputReleased)=="function" then
        frame.mouseReleased=InputReleased("lmb")==true
    else
        frame.mouseReleased=lastMouseDown and not frame.mouseDown
    end
    lastMouseDown=frame.mouseDown
    return frame
end

local aliases={
    esc="escape",["return"]="enter",del="delete",leftarrow="left",rightarrow="right",
    uparrow="up",downarrow="down",period=".",comma=",",decimal=".",subtract="-",minus="-",
    ["end"]="end",
}

local function canonicalKey(key)
    key=type(key)=="string" and key:lower() or ""
    return aliases[key] or key
end

local function isMouseKey(key)
    return key=="lmb" or key=="rmb" or key=="mmb"
end

local function repeatable(key)
    return key:match("^%d$")~=nil or key=="backspace" or key=="delete" or key=="left" or key=="right"
end

local function frameDown(frame,key)
    local down=frame.down
    if type(down)~="table" then return false end
    return down[key]==true
end

local function toggleSign(input)
    if hasSelection(input) then return insertCharacter(input,"-") end
    if input.buffer:sub(1,1)=="-" then
        input.buffer=input.buffer:sub(2)
        moveCursor(input,math.max(0,input.cursor-1),false)
        return true
    end
    if #input.buffer>=MAX_BUFFER then return false end
    input.buffer="-"..input.buffer
    moveCursor(input,input.cursor+1,false)
    return true
end

local function insertSeparator(input,separator)
    local text=separator
    local first,last=selection(input)
    if (first==0 and last==#input.buffer) or (not hasSelection(input) and input.buffer=="") then
        text="0"..separator
    end
    return insertCharacter(input,text)
end

local function moveLeft(input,extend)
    if not extend and hasSelection(input) then
        moveCursor(input,math.min(input.cursor,input.anchor),false)
    else
        moveCursor(input,input.cursor-1,extend)
    end
end

local function moveRight(input,extend)
    if not extend and hasSelection(input) then
        moveCursor(input,math.max(input.cursor,input.anchor),false)
    else
        moveCursor(input,input.cursor+1,extend)
    end
end

local function handleTextKey(input,key,frame)
    local ctrl=frame.ctrl==true
    local shift=frame.shift==true
    if key=="escape" then N.cancel();return end
    if key=="enter" then N.commit();return end
    if ctrl then
        if key=="a" then selectAll(input) end
        return
    end

    if key=="left" then moveLeft(input,shift)
    elseif key=="right" then moveRight(input,shift)
    elseif key=="home" then moveCursor(input,0,shift)
    elseif key=="end" then moveCursor(input,#input.buffer,shift)
    elseif key=="backspace" then deleteBackward(input)
    elseif key=="delete" then deleteForward(input)
    elseif key=="-" then toggleSign(input)
    elseif key=="." or key=="," then insertSeparator(input,key)
    elseif key:match("^%d$") then insertCharacter(input,key) end
end

local function consumeKeyboard()
    if type(InputClear)=="function" then InputClear() end
end

function N.key(frame)
    if not current then return false end
    if type(frame)~="table" then frame=N.sample() end
    local input=current
    local rawKey=type(frame.key)=="string" and frame.key:lower() or ""
    local key=canonicalKey(rawKey)
    if isMouseKey(key) then return true end

    local time=finite(frame.time) and frame.time or 0
    local keyboardEvent=key~=""
    local actionKey=nil
    if keyboardEvent then
        if repeatable(key) then
            if input.repeatKey~=key then
                input.repeatKey=key
                input.repeatAt=time+REPEAT_DELAY
                actionKey=key
            elseif time>=input.repeatAt then
                input.repeatAt=time+REPEAT_INTERVAL
                actionKey=key
            end
            if not frameDown(frame,key) then input.repeatKey=nil;input.repeatAt=nil end
        else
            input.repeatKey=nil
            input.repeatAt=nil
            actionKey=key
        end
    elseif input.repeatKey then
        if frameDown(frame,input.repeatKey) then
            if time>=input.repeatAt then
                actionKey=input.repeatKey
                input.repeatAt=time+REPEAT_INTERVAL
            end
        else
            input.repeatKey=nil
            input.repeatAt=nil
        end
    end

    if actionKey then
        if input.mode=="text" then
            handleTextKey(input,actionKey,frame)
        elseif actionKey=="escape" then
            N.cancel()
        end
    end
    if keyboardEvent or actionKey then consumeKeyboard() end
    return true
end
