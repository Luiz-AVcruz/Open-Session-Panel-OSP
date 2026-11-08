-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Pointer/keyboard contracts for the real shared widget, without a game renderer.
local count=0
local function check(v,message) assert(v,message);count=count+1 end
local function eq(a,b,message) check(a==b,(message or "value")..": "..tostring(a).." ~= "..tostring(b)) end
local function world(value,maximum)
    local w={value=value or 50,maximum=maximum or 100,now=0,mouseX=90,mouseY=17,pressed=false,down=false,
        keys={},key="",calls={},visible=true,allowed=true,enabled=true,stack=0,font=17}
    local env=setmetatable({server=false,client=false},{__index=_G})
    env.GetString=function() return "" end
    env.GetTime=function() return w.now end
    env.InputLastPressedKey=function() return w.key end
    env.InputPressed=function(k) return k=="lmb" and w.pressed or k==w.key end
    env.InputDown=function(k) return k=="lmb" and w.down or w.keys[k] or false end
    env.InputClear=function() w.key="";w.pressed=false;w.down=false;w.keys={} end
    env.UiGetMousePos=function() return w.mouseX,w.mouseY end
    env.UiPush=function() w.stack=w.stack+1 end
    env.UiPop=function() w.stack=w.stack-1 end
    env.UiFont=function(_,size) w.font=size end
    env.UiGetTextSize=function(text) return #text*w.font*.55,w.font end
    for _,name in ipairs({"UiTranslate","UiColor","UiRect","UiAlign","UiWindow","UiTextDisableWildcards","UiText"}) do env[name]=function() end end
    local chunk=assert(loadfile(arg[1]));setfenv(chunk,env);chunk()
    local N,W=env.OSP.NumberInput,env.OSP.NumberControl
    function w.draw()
        w.now=w.now+.02
        local input=N.sample();local consumed=false
        if N.active() then N.key(input) end
        W.beginFrame(input)
        local geometry=W.draw({id="test",w=180,h=34,value=w.value,minimum=0,maximum=w.maximum,decimals=0,
            colors=env.OSP.Theme.colors(),visible=w.visible,pointerAllowed=w.allowed,disabled=not w.enabled,
            valid=function() return w.enabled end,consume=function() consumed=true end,
            onCommit=function(v) w.calls[#w.calls+1]=v;w.value=v end})
        W.endFrame(consumed);eq(w.stack,0,"balanced widget drawing")
        w.pressed=false;w.key=""
        return geometry
    end
    function w.press(x) w.mouseX=x;w.pressed=true;w.down=true;return w.draw() end
    function w.hold(x) w.mouseX=x;w.down=true;return w.draw() end
    function w.release(x) w.mouseX=x;w.down=false;return w.draw() end
    function w.type(key,mods) w.key=key;w.keys=mods or {};w.draw();w.keys={} end
    w.N=N;w.W=W
    return w
end

do
    local w=world()
    w.press(90);w.release(90)
    check(w.N.active("test"),"number takes text focus")
    w.type("a",{ctrl=true});w.type("4");w.type("2")
    eq(#w.calls,0,"typing stays local")
    w.type("return");eq(w.value,42,"typed value commits");eq(#w.calls,1)
    w.draw();eq(#w.calls,1,"redraw never repeats a confirmation")
end

do
    local w=world(12345,100000)
    local left=(180-5*17*.55)/2
    w.press(left+17*.55);w.hold(left+3*17*.55);w.release(left+3*17*.55)
    local view=w.N.state()
    eq(math.min(view.anchor,view.cursor),1,"mouse selection begins after first digit")
    eq(math.max(view.anchor,view.cursor),3,"mouse selection ends after third digit")
    w.type("9");w.type("return");eq(w.value,1945,"typing replaces only the selected digits")
end

do
    local w=world()
    w.press(10);check(w.W.dragging(),"bar starts slider mode")
    eq(w.value,50);eq(#w.calls,0,"slider press never applies")
    w.hold(250);eq(w.N.state().value,100,"captured drag clamps beyond the field")
    eq(w.value,50,"dragging does not persist preview")
    w.release(250);eq(w.value,100);eq(#w.calls,1,"release applies once")
    w.draw();eq(#w.calls,1)
end

for _,reason in ipairs({"escape","disabled","hidden"}) do
    local w=world()
    w.press(10);w.hold(170)
    if reason=="escape" then w.type("esc")
    elseif reason=="disabled" then w.enabled=false;w.draw()
    else w.visible=false;w.draw() end
    w.release(170)
    eq(w.value,50,reason.." cancels slider preview")
    eq(#w.calls,0,reason.." cannot confirm an obsolete interaction")
end

do
    local w=world()
    w.press(10);w.type("enter")
    eq(#w.calls,0,"Enter cannot apply a slider before mouse release")
    check(w.W.dragging(),"slider stays captured until release")
    w.hold(170);w.release(170)
    eq(#w.calls,1,"release still applies exactly once after an ignored Enter")
end

do
    local w=world()
    w.allowed=false;w.press(90);w.release(90)
    eq(w.N.active(),false,"clipped pointer cannot focus a visible field")
    w.allowed=true;w.press(90);w.release(90)
    w.type("a",{ctrl=true});w.type("7")
    w.mouseX=220;w.pressed=true;w.down=true;w.key="5"
    w.draw()
    eq(w.value,75,"outside click includes the simultaneous last digit despite InputClear")
    eq(#w.calls,1,"outside click confirms once")
end

do
    local w=world()
    w.press(90);w.release(90);w.type("a",{ctrl=true});w.type("minus")
    w.type("return");check(w.N.active(),"incomplete number remains editable on Enter")
    w.press(220);w.release(220)
    eq(w.value,50,"invalid blur restores the prior value");eq(#w.calls,0)
end

print("PASS integrated number control: "..count.." assertions (mock UI)")
