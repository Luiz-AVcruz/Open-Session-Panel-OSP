-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Shared numeric field painting and pointer handling. NumberInput owns editing.
OSP.NumberControl = {}
local W=OSP.NumberControl
local N=OSP.NumberInput
local frame,guard,capture,lastClick={time=0},nil,nil,nil
local seen,insideActive=false,false

local function state() return N.state() end
local function valid()
    if N.active() and guard and not guard() then N.cancel();capture=nil end
    if not N.active() then guard=nil;capture=nil end
end
local function color(c,alpha)
    UiColor(c[1],c[2],c[3],alpha or c[4] or 1)
end
local function rect(x,y,w,h,c,alpha)
    if w<=0 or h<=0 then return end
    UiPush();UiTranslate(x,y);color(c,alpha);UiRect(w,h);UiPop()
end
local function measure(text) return UiGetTextSize(text) end
local function indexAt(text,x)
    local previous=0
    for i=1,#text do
        local nextWidth=measure(text:sub(1,i))
        if x<(previous+nextWidth)/2 then return i-1 end
        previous=nextWidth
    end
    return #text
end

function W.beginFrame(input)
    frame=input or {time=0}
    seen,insideActive=false,false
    valid()
end

function W.beforeAction()
    valid()
    if not N.active() then return false end
    local current=state()
    capture=nil;guard=nil
    if current.mode=="drag" then N.cancel();return false end
    return N.blur()
end

function W.endFrame(consumed)
    valid()
    if N.active() then
        if not seen then N.cancel();capture=nil;guard=nil
        elseif frame.mousePressed and not consumed and not insideActive then W.beforeAction() end
    end
    frame.mousePressed=false;frame.mouseReleased=false
end

function W.dragging()
    local current=state()
    return current and current.mode=="drag" or false
end

function W.draw(spec)
    local id,w,h=spec.id,spec.w,spec.h
    if not spec.visible then
        if N.active(id) then N.cancel();capture=nil;guard=nil end
        return
    end
    local enabled=not spec.disabled and (not spec.valid or spec.valid())
    if N.active(id) and not enabled then N.cancel();capture=nil;guard=nil end
    local mx,my=UiGetMousePos()
    local inside=mx>=0 and my>=0 and mx<w and my<h and spec.pointerAllowed~=false
    local current=N.state(id)
    local text=current and current.buffer or spec.caption or tostring(spec.value)
    UiPush();UiAlign("left top");UiFont("regular.ttf",17)
    local textWidth=measure(text)
    local editWidth=math.min(w-16,math.max(48,textWidth+20))
    local editLeft=(w-editWidth)/2
    local function consume() if spec.consume then spec.consume() end end
    local function begin(drag)
        if N.active() and not N.active(id) then W.beforeAction() end
        if spec.valid and not spec.valid() then return false end
        local original=spec.value
        local function commit(value)
            if spec.valid and not spec.valid() then return end
            if value~=original or spec.unset then spec.onCommit(value) end
        end
        local started=(drag and N.beginDrag or N.begin)(id,original,spec.minimum,spec.maximum,spec.decimals,commit)
        if started then guard=spec.valid end
        return started
    end
    local function textOrigin(view)
        local width=measure(view.buffer)
        if width<=w-20 then return (w-width)/2 end
        local caret=measure(view.buffer:sub(1,view.cursor))
        return 10-math.max(0,math.min(width-(w-20),caret-(w-24)))
    end
    if enabled and inside and frame.mousePressed and not spec.consumed then
        local wasActive=N.active(id)
        if mx>=editLeft and mx<editLeft+editWidth then
            if wasActive or begin(false) then
                current=N.state(id)
                local double=lastClick and lastClick.id==id and frame.time-lastClick.time<=.3
                    and math.abs(mx-lastClick.x)<6 and math.abs(my-lastClick.y)<6
                if double then N.selectAll()
                else N.placeCursor(indexAt(current.buffer,mx-textOrigin(current)),wasActive and frame.shift or false) end
                lastClick={id=id,time=frame.time,x=mx,y=my}
                capture={id=id,kind=double and "all" or "selection"}
                if spec.focus then spec.focus() end
                consume()
            end
        elseif begin(true) then
            lastClick=nil;capture={id=id,kind="drag"}
            if spec.focus then spec.focus() end
            consume()
        end
    end
    current=N.state(id)
    if current then
        seen=true;insideActive=inside
        if capture and capture.id==id then
            if capture.kind=="drag" then
                local value=spec.minimum+math.max(0,math.min(1,mx/w))*(spec.maximum-spec.minimum)
                if frame.mouseDown or frame.mousePressed then N.dragTo(value)
                else
                    N.dragTo(value);N.commit();capture=nil;guard=nil
                end
            elseif frame.mouseDown and capture.kind=="selection" and not frame.mousePressed then
                N.placeCursor(indexAt(current.buffer,mx-textOrigin(current)),true)
            elseif not frame.mouseDown and not frame.mousePressed then capture=nil end
        end
    end
    current=N.state(id)
    text=current and current.buffer or spec.caption or tostring(spec.value)
    local value=current and current.value or spec.value
    local ratio=spec.maximum>spec.minimum and (value-spec.minimum)/(spec.maximum-spec.minimum) or 0
    ratio=math.max(0,math.min(1,ratio))
    local C=spec.colors
    local edge=current and C.accent or inside and enabled and C.muted or C.line
    rect(0,0,w,h,C.surface)
    if not spec.unset or current then
        if spec.gradient then
            for part=0,15 do rect(w*part/16,0,w/16+1,h,spec.gradient(part/15),.35) end
        else rect(0,0,w*ratio,h,C.selected) end
        rect(0,h-3,w*ratio,3,enabled and C.accent or C.disabled)
        rect(math.max(0,math.min(w-2,w*ratio-1)),0,2,h,enabled and C.accent or C.disabled,.6)
    end
    rect(0,0,w,1,edge);rect(0,h-1,w,1,edge);rect(0,0,1,h,edge);rect(w-1,0,1,h,edge)
    local tx=current and textOrigin(current) or math.max(10,(w-measure(text))/2)
    UiPush();UiTranslate(10,(h-22)/2);UiWindow(w-20,24,true,true);UiTranslate(tx-10,0)
    if current and current.mode=="text" then
        local first,last=math.min(current.cursor,current.anchor),math.max(current.cursor,current.anchor)
        rect(measure(text:sub(1,first)),0,measure(text:sub(1,last))-measure(text:sub(1,first)),22,C.accent,.35)
    end
    color(enabled and C.text or C.disabled);UiTextDisableWildcards(true);UiText(text)
    if current and current.mode=="text" and (frame.mouseDown or math.floor((frame.time or 0)*2)%2==0) then
        rect(measure(text:sub(1,current.cursor)),0,1,22,C.text)
    end
    UiPop();UiPop()
    return {textX=editLeft,textW=editWidth}
end
