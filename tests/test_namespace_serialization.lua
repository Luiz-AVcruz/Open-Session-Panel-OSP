-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Models function omission and the documented nonserializable marker only;
-- this is not a simulation of Teardown's full Quickload behavior.
local assertions=0
local function check(value,message) assert(value,message);assertions=assertions+1 end
local function eq(a,b,message) check(a==b,(message or "equality")..": "..tostring(a).." ~= "..tostring(b)) end

local chunk=assert(loadfile("tests/test_client.lua"))
setfenv(chunk,setmetatable({arg={arg[1],"fixture"}},{__index=_G}))
local world=chunk()

local function restoreNamespace(value,seen)
    if type(value)~="table" or value.nonserializable==true then return value end
    seen=seen or {}
    if seen[value] then return seen[value] end
    local restored={};seen[value]=restored
    for key,child in pairs(value) do
        if type(child)~="function" then restored[key]=restoreNamespace(child,seen) end
    end
    return restored
end

-- Control: a restorer that drops function members leaves the observed tick/draw methods absent.
do
    local w=world(1280,720);local e=w.api;local original=e.OSP
    eq(original.nonserializable,true,"entry point marks OSP nonserializable")
    original.nonserializable=nil
    e.OSP=restoreNamespace(original)
    check(e.OSP~=original,"serializable table is replaced during the model restore")
    check(e.OSP.NumberInput and e.OSP.NumberInput.sample==nil,"restoration omits OSP.NumberInput.sample")
    check(e.OSP.Theme and e.OSP.Theme.colors==nil,"restoration omits OSP.Theme.colors")
    local ok,err=pcall(function() w:tick() end)
    eq(ok,false,"client.tick fails under the negative control")
    check(tostring(err):find("sample",1,true) and tostring(err):find("nil value",1,true),"negative control matches the observed sample failure")
    ok,err=pcall(function() w:draw() end)
    eq(ok,false,"client.draw fails under the negative control")
    check(tostring(err):find("colors",1,true) and tostring(err):find("nil value",1,true),"negative control matches the observed colors failure")
end

-- Positive control: the marked root survives repeated modeled restore cycles with aliases intact.
do
    local w=world(1280,720);local e=w.api;local root=e.OSP
    local numberInput=root.NumberInput;local sample=numberInput.sample
    local theme=root.Theme;local colors=theme.colors
    local shortcuts=root.Shortcuts;local shortcutBinding=shortcuts.binding
    local clientTick=e.client.tick;local clientDraw=e.client.draw
    local shared=e.shared;local sharedOsp=shared.osp;local players=sharedOsp.players
    local profile=players[1];local challenge=profile.profileChallenge
    w.reg["savegame.mod.osp_beta.players.host.role"]="helper"
    w.reg["savegame.mod.osp_beta.rules.rain"]=0.5
    check(root.shared==nil and root.players==nil and root.rules==nil,"shared and persistent data are outside OSP")
    for i=1,4 do
        e.OSP=restoreNamespace(e.OSP)
        eq(e.OSP,root,"nonserializable root identity survives restore cycle "..i)
        eq(e.OSP.NumberInput,numberInput,"module table alias survives cycle "..i)
        eq(e.OSP.NumberInput.sample,sample,"NumberInput method survives cycle "..i)
        eq(e.OSP.Theme.colors,colors,"Theme method survives cycle "..i)
        eq(e.OSP.Shortcuts,shortcuts,"captured Shortcuts alias survives cycle "..i)
        eq(e.OSP.Shortcuts.binding,shortcutBinding,"captured shortcut method survives cycle "..i)
        eq(e.client.tick,clientTick,"client.tick callback stays installed")
        eq(e.client.draw,clientDraw,"client.draw callback stays installed")
        eq(e.shared,shared,"shared root is not replaced")
        eq(e.shared.osp,sharedOsp,"shared session state stays outside OSP restore")
        eq(e.shared.osp.players,players,"shared player profiles stay outside OSP restore")
        eq(e.shared.osp.players[1].profileChallenge,challenge,"player profile remains intact")
        eq(w.reg["savegame.mod.osp_beta.players.host.role"],"helper","saved role remains intact")
        eq(w.reg["savegame.mod.osp_beta.rules.rain"],0.5,"saved rules remain intact")
        w:tick()
        w:draw()
    end
    local pauseButton=e.PauseMenuButton
    e.PauseMenuButton=function() return true end
    w:tick()
    check(e.OSP.UI.getState().open,"PauseMenuButton still opens the panel after restore cycles")
    e.PauseMenuButton=pauseButton
    w:draw()
    w:clickControl("tab_tools")
    eq(e.OSP.UI.getState().tab,"tools","normal UI navigation continues after restore cycles")
end

print("PASS OSP namespace serialization boundary (mock Quickload restore only): "..assertions.." assertions")
