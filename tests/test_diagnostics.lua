-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
local assertions=0
local function check(value,message) assert(value,message);assertions=assertions+1 end
local function eq(a,b,message) check(a==b,(message or "equality")..": "..tostring(a).." ~= "..tostring(b)) end
local root="savegame.mod.osp_beta.diagnostics"
local enabledKey=root..".enabled"

local function world(reg,side,withHandler)
    reg=reg or {["savegame.mod.osp_beta.identity.keep"]="identity",["savegame.mod.osp_beta.players.host.role"]="admin"}
    local w={reg=reg,now=0,writes=0,clientCalls=0,serverCalls=0,quickloads=0,updateError=nil,clientError=nil,failDisable=false}
    local env={OSP={},shared={}}
    if side=="client" or side=="both" then
        env.client={
            init=function() w.clientCalls=w.clientCalls+1;return "client-init",nil,"tail" end,
            tick=function(dt) w.clientCalls=w.clientCalls+1;if w.clientError then error(w.clientError,0) end;return "client-tick",nil,dt end,
            draw=function() w.clientCalls=w.clientCalls+1;return "client-draw",nil,"tail" end,
        }
    end
    if side=="server" or side=="both" then
        env.server={
            init=function() w.serverCalls=w.serverCalls+1;return "server-init",nil,"tail" end,
            tick=function(dt) w.serverCalls=w.serverCalls+1;return "server-tick",nil,dt end,
            update=function(dt) w.serverCalls=w.serverCalls+1;if w.updateError then error(w.updateError,0) end;return "server-update",nil,dt end,
        }
        if withHandler then
            env.server.handleCommand=function(command,arg)
                if command=="quickload" then w.quickloads=w.quickloads+1 end
                w.lastCommand={command,arg}
                return "handled",nil,arg
            end
        end
    end
    setmetatable(env,{__index=_G})
    env.GetBool=function(key) return reg[key]==true end
    env.SetBool=function(key,value)
        check(key==enabledKey,"only the explicit diagnostics toggle writes a boolean")
        if w.failDisable and value==false then error("storage unavailable",0) end
        w.writes=w.writes+1;reg[key]=value
    end
    env.GetInt=function(key) return reg[key] or 0 end
    env.SetInt=function(key,value)
        check(key:find(root,1,true)==1,"diagnostic sequence stays in its namespace")
        w.writes=w.writes+1;reg[key]=value
    end
    env.GetString=function(key) return reg[key] or "" end
    env.SetString=function(key,value)
        check(key:find(root,1,true)==1,"diagnostic records stay in their namespace")
        w.writes=w.writes+1;reg[key]=value
    end
    env.GetTime=function() return w.now end
    local chunk=assert(loadfile("mod/scripts/diagnostics.lua"));setfenv(chunk,env);chunk()
    env.OSP.Diagnostics.install()
    w.api=env
    return w
end

local function eventValue(reg,side)
    local seq=reg[root.."."..side..".event_sequence"] or 0
    if seq==0 then return nil end
    return reg[root.."."..side..".event."..(((seq-1)%96)+1)]
end

-- Default off has no callback replacement and writes nothing.
do
    local w=world(nil,"both",false);local e=w.api
    local originalClientTick=e.client.tick;local originalServerTick=e.server.tick
    eq(e.OSP.Diagnostics.isEnabled(),false,"diagnostics default off")
    eq(e.server.handleCommand,nil,"quickload handler is not created while diagnostics are off")
    eq(w.writes,0,"loading and installing while off writes nothing")
    local a,b,c=e.client.tick(.25);eq(a,"client-tick");eq(b,nil);eq(c,.25)
    a,b,c=e.server.tick(.5);eq(a,"server-tick");eq(b,nil);eq(c,.5)
    eq(e.client.tick,originalClientTick,"off mode leaves the client callback untouched")
    eq(e.server.tick,originalServerTick,"off mode leaves the server callback untouched")
    eq(w.writes,0,"callbacks while off do not write diagnostic storage")
end

-- Enabling wraps both namespaces once, chains an existing handler, and records each side separately.
do
    local w=world(nil,"both",true);local e=w.api;local original=e.server.handleCommand
    local originalClientTick=e.client.tick;local originalServerTick=e.server.tick
    check(e.OSP.Diagnostics.setEnabled(true),"enable persists before instrumentation starts")
    check(e.client.tick~=originalClientTick,"client callback is wrapped only after opt-in")
    check(e.server.tick~=originalServerTick,"server callback is wrapped only after opt-in")
    check(e.server.handleCommand~=original,"existing quickload callback is chained")
    local a,b,c=e.client.tick(.25);eq(a,"client-tick");eq(b,nil);eq(c,.25)
    e.server.tick(.25);e.server.update(.25);e.client.draw()
    check(w.reg[root..".client.heartbeat.client_tick"]:find("|exit|",1,true),"client tick heartbeat uses client store")
    check(w.reg[root..".server.heartbeat.server_tick"]:find("|exit|",1,true),"server tick heartbeat uses server store")
    local clientEventSequence=w.reg[root..".client.event_sequence"]
    local before=w.writes;e.client.tick(.25);eq(w.writes,before,"same-time calls do not write per frame")
    a,b,c=e.server.handleCommand("ordinary","arg");eq(a,"handled");eq(b,nil);eq(c,"arg")
    eq(w.quickloads,0,"other commands still chain without quickload markers")
    a,b,c=e.server.handleCommand("quickload","slot");eq(a,"handled");eq(b,nil);eq(c,"slot")
    eq(w.quickloads,1,"existing handler receives quickload exactly once")
    check(w.reg[root..".server.last_quickload"]:find("|exit|quickload",1,true),"quickload result is fixed outside heartbeat fields")
    check(eventValue(w.reg,"server"):find("|exit|quickload",1,true),"quickload appears in bounded event ring")
    eq(w.reg[root..".client.event_sequence"],clientEventSequence,"server quickload does not share the client event sequence")

    w.now=1.2;e.client.tick(.25)
    local writes=w.writes;e.client.tick(.25);eq(w.writes,writes,"heartbeat remains limited to once per second")
    w.now=.5;e.client.tick(.25)
    check(eventValue(w.reg,"client"):find("|clock_regressed|",1,true),"GetTime rollback is recorded and triggers a heartbeat")

    local sentinel={}
    w.updateError=sentinel;w.now=2
    local ok,err=pcall(e.server.update,.1);eq(ok,false);eq(err,sentinel,"callback error value is rethrown unchanged")
    check(w.reg[root..".server.last_error"]:find("server.update|error|",1,true),"server exception is retained separately")
    w.updateError=string.rep("path/",90).."distinct-cause-marker";w.now=3
    ok,err=pcall(e.server.update,.1);eq(ok,false);eq(err,w.updateError,"long exception is rethrown unchanged")
    check(w.reg[root..".server.last_error"]:find("distinct%-cause%-marker"),"last error keeps the cause beyond the old short limit")
    local longServerError=w.reg[root..".server.last_error"]
    w.updateError=nil;w.now=4;e.server.update(.1);eq(w.reg[root..".server.last_error"],longServerError,"successful callbacks do not clear last error")
    w.clientError="client-side sentinel";w.now=4
    ok,err=pcall(e.client.tick,.1);eq(ok,false);eq(err,"client-side sentinel")
    check(w.reg[root..".client.last_error"]:find("client.tick|error|client%-side sentinel"),"client exception has its own last-error slot")
    eq(w.reg[root..".server.last_error"],longServerError,"client error does not overwrite server error")
    local reload=world(w.reg,"server",true)
    eq(reload.reg[root..".server.last_error"],longServerError,"module reload keeps last error across maps")

    -- A bounded ring retains at most 96 records while the fixed last-quickload slot stays current.
    w.clientError=nil
    for i=1,130 do e.server.handleCommand("quickload",i) end
    local sequence=w.reg[root..".server.event_sequence"]
    check(sequence>96,"quickload sequence advances beyond ring capacity")
    local populated=0
    for i=1,96 do if w.reg[root..".server.event."..i] then populated=populated+1 end end
    eq(populated,96,"event ring storage is bounded to its fixed slots")
    check(w.reg[root..".server.last_quickload"]:find("|exit|quickload",1,true),"latest quickload survives heartbeat updates")

    local writesBeforeDisable=w.writes
    check(e.OSP.Diagnostics.setEnabled(false),"disable saves successfully")
    check(w.writes>writesBeforeDisable,"explicit disable is persisted")
    local afterDisable=w.writes;local calls=w.clientCalls
    e.client.tick(.2);eq(w.clientCalls,calls+1,"disabled wrapper still runs the original callback")
    eq(w.writes,afterDisable,"disabled callbacks stop diagnostic writes")
    eq(w.reg["savegame.mod.osp_beta.identity.keep"],"identity","identity is untouched")
    eq(w.reg["savegame.mod.osp_beta.players.host.role"],"admin","roles are untouched")
end

-- If the engine context has no command callback, opt-in adds a recorder-only one.
do
    local w=world(nil,"server",false);local e=w.api
    eq(e.server.handleCommand,nil,"missing engine handler stays absent while off")
    check(e.OSP.Diagnostics.setEnabled(true),"diagnostics can be enabled without an existing handler")
    check(type(e.server.handleCommand)=="function","opt-in installs a quickload observer when missing")
    eq(e.server.handleCommand("ordinary"),nil,"recorder-only handler is inert for other commands")
    eq(e.server.handleCommand("quickload"),nil,"recorder-only quickload has no game effect or return value")
    check(w.reg[root..".server.last_quickload"]:find("|exit|quickload",1,true),"missing-handler quickload is recorded")
    eq(w.serverCalls,0,"quickload observer does not create gameplay behavior")
end

-- Separate client/server contexts share only the persisted opt-in; off is observed before server collection.
do
    local reg={[enabledKey]=true,["savegame.mod.osp_beta.identity.keep"]="identity",["savegame.mod.osp_beta.players.host.role"]="admin"}
    local clientWorld=world(reg,"client",false)
    local serverWorld=world(reg,"server",true)
    check(clientWorld.api.client.tick~=nil and serverWorld.api.server.tick~=nil,"both contexts install their own wrappers")
    check(clientWorld.api.OSP.Diagnostics.setEnabled(false),"client can persist opt-out")
    local writes=serverWorld.writes;local calls=serverWorld.serverCalls
    serverWorld.api.server.tick(.1)
    eq(serverWorld.serverCalls,calls+1,"server callback continues after remote opt-out")
    eq(serverWorld.writes,writes,"server sees persisted opt-out before writing any heartbeat")
    eq(serverWorld.reg[root..".server.heartbeat.server_tick"],nil,"server does not collect after opt-out")
    eq(reg["savegame.mod.osp_beta.identity.keep"],"identity");eq(reg["savegame.mod.osp_beta.players.host.role"],"admin")
end

-- A failed disable write must leave the running state enabled and report failure.
do
    local w=world({[enabledKey]=true},"client",false)
    w.failDisable=true
    check(not w.api.OSP.Diagnostics.setEnabled(false),"failed setting write is reported")
    eq(w.api.OSP.Diagnostics.isEnabled(),true,"local state stays enabled when disable was not saved")
end

print("PASS opt-in diagnostics, bounded events, callback chaining and error preservation: "..assertions.." assertions")
