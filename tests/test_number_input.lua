-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Clipboard functions exist in the engine but are forbidden in mod contexts.
local checks=0
local function check(value,message) assert(value,message);checks=checks+1 end
local function eq(actual,expected,message)
    check(actual==expected,(message or "value")..": "..tostring(actual).." ~= "..tostring(expected))
end
local input={key="",time=0,down={},mousePressed=false,mouseDown=false,cleared=0,clipboardCalls=0}
local env=setmetatable({
    InputLastPressedKey=function() return input.key end,
    InputDown=function(key) return input.down[key]==true end,
    InputPressed=function(key) return key=="lmb" and input.mousePressed or false end,
    GetTime=function() return input.time end,
    InputClear=function()
        input.cleared=input.cleared+1
        input.key="";input.down={};input.mousePressed=false;input.mouseDown=false
    end,
    GetClipboardText=function() input.clipboardCalls=input.clipboardCalls+1;error('GetClipboardText function is only for internal usage') end,
    SetClipboardText=function() input.clipboardCalls=input.clipboardCalls+1;error('SetClipboardText function is only for internal usage') end,
},{__index=_G})
local chunk=assert(loadfile("mod/scripts/number_input.lua"));setfenv(chunk,env);chunk()
local N=env.OSP.NumberInput
local result,calls=nil,0
local function capture(id,value,minimum,maximum,decimals)
    return N.begin(id,value,minimum,maximum,decimals,function(v)
        result=v;calls=calls+1
    end)
end
local function frame(key,options)
    options=options or {}
    local down={}
    for name,value in pairs(options.down or {}) do down[name]=value end
    return {key=key or "",time=options.time or input.time,ctrl=options.ctrl==true,
        shift=options.shift==true,down=down}
end
local function press(key,options)
    input.time=(options and options.time) or input.time+0.016
    return N.key(frame(key,options))
end
local function held(key,time,shift)
    local down={[key]=true}
    return N.key(frame("",{time=time,shift=shift,down=down}))
end

eq(N.active(),false,"inactive on load")
eq(N.key(frame("1")),false,"inactive editor does not consume input")
eq(capture("rgb",123,0,255,0),true,"valid field starts")
eq(N.active(),true)
eq(N.active("rgb"),true)
eq(N.active("other"),false)
eq(N.caption("rgb",123),"123","caption has no synthetic cursor")
local state=N.state("rgb")
eq(state.mode,"text")
eq(state.cursor,3,"begin places cursor at end")
eq(state.anchor,0,"begin selects all")
eq(state.value,123)
state.buffer="changed"
eq(N.state("rgb").buffer,"123","state returns a copy")
press("4");press("2")
eq(N.caption("rgb",123),"42","first digit replaces selection")
eq(N.state().cursor,2)
eq(N.state().anchor,2)
press("return")
eq(result,42,"integer entered")
eq(calls,1,"one callback")
eq(N.active(),false)
press("return")
eq(calls,1,"inactive field cannot commit twice")

capture("home-end",123,0,999,0)
press("home")
eq(N.state().cursor,0,"Home moves to the start")
press("end",{shift=true})
eq(N.state().cursor,3,"End moves to the end")
eq(N.state().anchor,0,"Shift+End selects from current anchor")
press("right")
eq(N.state().cursor,3,"Right collapses selection to its end")
press("left")
eq(N.state().cursor,2,"Left moves one character")
N.cancel()

capture("partial",12345,0,99999,0)
N.placeCursor(4)
N.placeCursor(2,true)
state=N.state()
eq(state.cursor,2,"shifted cursor position")
eq(state.anchor,4,"shift keeps the original anchor")
press("9")
eq(N.caption("partial",12345),"1295","insertion replaces a partial selection")
N.placeCursor(1)
press("right",{shift=true})
state=N.state()
eq(state.cursor,2,"right moves cursor")
eq(state.anchor,1,"shift-right extends selection")
press("backspace")
eq(N.caption("partial",12345),"195","backspace removes selected middle text")
N.placeCursor(1)
press("backspace")
eq(N.caption("partial",12345),"95","backspace removes before cursor")
N.placeCursor(0)
press("delete")
eq(N.caption("partial",12345),"5","delete removes after cursor")
N.cancel()

capture("clipboard-disabled",2468,0,9999,2)
N.placeCursor(3)
N.placeCursor(1,true)
local before=N.state()
for _,key in ipairs({"c","x","v"}) do
    press(key,{ctrl=true})
    state=N.state()
    eq(state.buffer,before.buffer,"unsupported Ctrl+"..key.." preserves text")
    eq(state.cursor,before.cursor,"unsupported shortcut preserves cursor")
    eq(state.anchor,before.anchor,"unsupported shortcut preserves selection")
end
eq(input.clipboardCalls,0,"internal-only clipboard functions are never called")
N.cancel()

capture("speed",1.25,.5,3,2)
press(",")
eq(N.caption("speed",1.25),"0,","comma starts a fresh numeric value")
press("5");press("enter")
eq(result,.5,"comma decimal accepted and clamped")
capture("speed",1.25,.5,3,2)
press("period")
eq(N.caption("speed",1.25),"0.","period starts a fresh numeric value")
press("5");press("enter")
eq(result,.5,"period decimal accepted")
capture("speed",1,0,10,2)
press("period");press("2");press("period")
eq(N.caption("speed",1),"0.2","second decimal separator is ignored")
press("3");press("6");press("enter")
eq(result,.24,"entered decimals round on commit")
capture("speed",1,0,10,2)
N.selectAll()
press("delete")
local beforeInvalid=calls
press("enter")
eq(N.active("speed"),true,"invalid Enter preserves focus")
eq(calls,beforeInvalid,"invalid Enter does not call callback")
eq(N.blur(),false,"invalid blur cancels without confirming")
eq(N.active(),false)

capture("negative",1,0,255,0)
press("minus");press("9");press("enter")
eq(result,0,"negative integer clamps to minimum")
capture("negative-speed",1,.5,3,2)
press("minus");press("9");press("enter")
eq(result,.5,"negative decimal clamps to minimum")
capture("large",0,0,255,0)
for _=1,64 do press("9") end
eq(#N.state().buffer,64,"buffer accepts at most 64 ASCII characters")
press("9")
eq(#N.state().buffer,64,"buffer rejects insertion beyond 64 characters")
press("enter")
eq(result,255,"large decimal input clamps to the maximum")
check(result~=math.huge,"committed number is finite")

local callsBefore=calls
capture("invalid",10,0,255,0)
press("minus");press("enter")
eq(calls,callsBefore,"incomplete sign cannot commit")
eq(N.active("invalid"),true,"invalid value can still be corrected")
eq(N.state().value,10,"invalid preview falls back to the original value")
eq(N.commit(),false,"invalid direct commit is rejected")
eq(N.active("invalid"),true,"invalid direct commit preserves focus")
N.selectAll();press("delete");press("enter")
eq(calls,callsBefore,"empty text cannot commit")
eq(N.cancel(),true,"cancel clears capture")
eq(calls,callsBefore,"cancel discards without callback")
eq(N.active(),false)
eq(N.cancel(),false,"cancelling twice is harmless")
capture("escape-cancel",3,0,9,0)
eq(N.key(frame("esc")),true,"Escape is handled by the active editor")
eq(N.active(),false,"Escape cancels text entry")

capture("repeat-digit",0,0,999999,0)
N.placeCursor(1)
local repeated=frame("1",{time=1,down={['1']=true}})
N.key(repeated)
eq(N.caption("repeat-digit",0),"01","initial key press acts immediately")
held("1",1.399)
eq(N.caption("repeat-digit",0),"01","repeat waits 400 ms")
held("1",1.4)
eq(N.caption("repeat-digit",0),"011","first repeat starts at 400 ms")
held("1",1.449)
eq(N.caption("repeat-digit",0),"011","repeat interval is 50 ms")
held("1",1.45)
eq(N.caption("repeat-digit",0),"0111","number repeats every 50 ms")
N.key(frame("",{time=1.5}))
eq(N.caption("repeat-digit",0),"0111","release stops key repeats")
N.cancel()

capture("repeat-delete",123456,0,999999,0)
N.placeCursor(6)
N.key(frame("backspace",{time=2,down={backspace=true}}))
eq(N.caption("repeat-delete",0),"12345","backspace acts on press")
held("backspace",2.4)
eq(N.caption("repeat-delete",0),"1234","backspace repeats after delay")
held("backspace",2.45)
eq(N.caption("repeat-delete",0),"123","backspace repeats at interval")
N.cancel()

capture("repeat-forward-delete",12345,0,99999,0)
N.placeCursor(0)
N.key(frame("delete",{time=2.5,down={delete=true}}))
eq(N.caption("repeat-forward-delete",0),"2345","Delete acts on press")
held("delete",2.9)
eq(N.caption("repeat-forward-delete",0),"345","Delete repeats after delay")
held("delete",2.95)
eq(N.caption("repeat-forward-delete",0),"45","Delete repeats at interval")
N.cancel()

capture("repeat-arrow",12345,0,99999,0)
N.placeCursor(3)
N.key(frame("leftarrow",{time=2.95,down={left=true}}))
eq(N.state().cursor,2,"Left arrow acts on press")
held("left",3.349)
eq(N.state().cursor,2,"arrow repeat waits 400 ms")
held("left",3.35)
eq(N.state().cursor,1,"arrow repeats after delay")
held("left",3.4)
eq(N.state().cursor,0,"arrow repeats at 50 ms interval")
N.cancel()

capture("ctrl-repeat",123,0,999,0)
N.placeCursor(1)
press("a",{ctrl=true})
eq(N.state().cursor,3,"Ctrl+A moves the cursor to the end")
eq(N.state().anchor,0,"Ctrl+A selects all")
local clearCount=input.cleared
N.key(frame("",{time=3,ctrl=true,down={a=true}}))
eq(N.state().cursor,3,"held Ctrl+A preserves cursor")
eq(N.state().anchor,0,"held Ctrl+A preserves selection")
eq(input.cleared,clearCount,"held shortcut without key press is not consumed again")
N.cancel()

capture("sample",12,0,255,0)
input.time=4
input.key="7"
input.down={['7']=true,ctrl=true,shift=true,lmb=true}
input.mousePressed=true
input.mouseDown=true
local beforeClear=input.cleared
local sampled=N.sample()
eq(input.cleared,beforeClear,"sample never consumes inputs")
eq(sampled.key,"7")
eq(sampled.time,4)
eq(sampled.ctrl,true)
eq(sampled.shift,true)
eq(sampled.down["7"],true)
eq(sampled.mousePressed,true)
eq(sampled.mouseDown,true)
eq(sampled.mouseReleased,false)
N.key(sampled)
eq(input.cleared,beforeClear+1,"keyboard event consumes inputs after sampling")
eq(sampled.key,"7","snapshot survives InputClear")
eq(sampled.mousePressed,true,"mouse press survives InputClear")
eq(sampled.mouseDown,true,"mouse hold survives InputClear")
N.cancel()

capture("direct-sample",0,0,9,0)
input.key="6";input.time=4.5;input.down={['6']=true}
local directClear=input.cleared
eq(N.key(),true,"key without frame samples current input")
eq(N.caption("direct-sample",0),"6","direct key uses sampled keyboard input")
eq(input.cleared,directClear+1,"direct key clears after sampling")
N.cancel()

capture("mouse",128,0,255,0)
local clearCountMouse=input.cleared
input.key="lmb";input.down={lmb=true};input.mousePressed=true;input.mouseDown=true
local mouseFrame=N.sample()
N.key(mouseFrame)
eq(input.cleared,clearCountMouse,"mouse key never calls InputClear")
eq(mouseFrame.mousePressed,true)
eq(mouseFrame.mouseDown,true)
N.cancel()

capture("derived-release",0,0,1,0)
input.key="";input.down={lmb=true};input.mouseDown=true
eq(N.sample().mouseReleased,false,"mouse release has not happened")
input.down={};input.mouseDown=false
eq(N.sample().mouseReleased,true,"mouse release derives from previous sampled down state")
N.cancel()

capture("drag",2,0,5,1)
N.cancel()
eq(N.beginDrag("drag",2,0,5,1,function(v) result=v;calls=calls+1 end),true,"drag capture starts")
eq(N.state().mode,"drag")
eq(N.state().value,2)
eq(N.dragTo(4.26),true)
eq(N.state().value,4.3,"drag preview clamps and rounds")
eq(N.dragTo(math.huge),false,"drag rejects non-finite values")
eq(N.state().value,4.3,"rejected drag input preserves preview")
local beforeDragCalls=calls
eq(N.key(frame("9")),true,"drag owns keyboard event")
eq(N.caption("drag",2),"4.3","digits do not edit during drag")
eq(calls,beforeDragCalls,"drag preview does not call commit")
eq(N.commit(),true,"drag commits once")
eq(result,4.3)
eq(calls,beforeDragCalls+1)
eq(N.commit(),false,"drag cannot commit twice")
eq(calls,beforeDragCalls+1)
N.beginDrag("drag-cancel",1,0,5,0,function(v) result=v;calls=calls+1 end)
N.dragTo(4)
eq(N.key(frame("esc")),true)
eq(N.active(),false,"Escape cancels drag")
eq(calls,beforeDragCalls+1,"cancelled drag never calls commit")

capture("valid-blur",8,0,10,0)
eq(N.blur(),true,"valid blur confirms")
eq(result,8)
eq(calls,beforeDragCalls+2,"valid blur invokes callback once even when unchanged")
eq(capture("infinite-origin",math.huge,0,10,0),true,"non-finite initial values use the minimum")
eq(N.state().value,0)
eq(N.commit(),true)
eq(result,0)
check(result~=math.huge,"non-finite origin never reaches callback")
capture("replace",1,0,10,0)
capture("replacement",2,0,10,0)
eq(N.active("replace"),false,"new field replaces prior capture")
press("delete");press("9");press("enter")
eq(result,9,"callback belongs to active field")

print("PASS numeric input contract: "..checks.." assertions")
