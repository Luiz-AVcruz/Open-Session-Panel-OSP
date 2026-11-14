-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
OSP.Diagnostics = {}
do
    local root="savegame.mod.osp_beta.diagnostics"
    local enabledKey=root..".enabled"
    local processSide=type(client)=="table" and "client" or type(server)=="table" and "server" or "process"
    local eventCapacity=96
    local enabled=false
    local hooksInstalled=false
    local wrapped={}
    local heartbeatAt={}

    local function safeGetBool(key)
        local ok,value=pcall(GetBool,key)
        return ok and value==true
    end
    local function safeGetInt(key)
        local ok,value=pcall(GetInt,key)
        if not ok or type(value)~="number" or value~=value then return 0 end
        return math.max(0,math.floor(value))
    end
    local function safeSetBool(key,value)
        return pcall(SetBool,key,value)
    end
    local function safeSetInt(key,value)
        return pcall(SetInt,key,value)
    end
    local function safeSetString(key,value)
        return pcall(SetString,key,value)
    end
    local function readTime()
        local ok,value=pcall(GetTime)
        if ok and type(value)=="number" and value==value and value>-math.huge and value<math.huge then return value end
        return nil
    end
    local function timeText(value)
        return type(value)=="number" and string.format("%.3f",value) or "?"
    end
    local function clean(value,limit)
        local ok,text=pcall(tostring,value)
        if not ok then text="<unprintable>" end
        text=text:gsub("[\r\n\t|]"," ")
        return text:sub(1,limit or 160)
    end
    local function keyPart(value)
        return clean(value,48):gsub("[^%w_%-]","_")
    end
    local function sideFor(event)
        if type(event)=="string" and event:match("^client%.") then return "client" end
        if type(event)=="string" and event:match("^server%.") then return "server" end
        return processSide
    end
    local function sideRoot(side)
        return root.."."..side
    end
    local function encode(at,event,state,detail,sequence)
        return table.concat({tostring(sequence or 0),timeText(at),clean(event,48),clean(state,16),clean(detail or "",160)},"|")
    end
    local function appendEvent(event,state,detail,at)
        if not enabled then return nil end
        local eventSide=sideFor(event)
        local eventRoot=sideRoot(eventSide)..".event."
        local sequenceKey=sideRoot(eventSide)..".event_sequence"
        local sequence=safeGetInt(sequenceKey)
        if sequence>=2147483646 then sequence=0 end
        sequence=sequence+1
        local slot=((sequence-1)%eventCapacity)+1
        local key=eventRoot..slot
        if not safeSetString(key,encode(at or readTime(),event,state,detail,sequence)) then return nil end
        if not safeSetInt(sequenceKey,sequence) then return nil end
        return {key=key,sequence=sequence,event=event}
    end
    local function updateEvent(token,state,detail,at)
        if not token or not token.key then return end
        safeSetString(token.key,encode(at or readTime(),token.event,state,detail,token.sequence))
    end
    local function writeLastError(event,err,at)
        if not enabled then return end
        local detail=clean(err,1024)
        local key=sideRoot(sideFor(event))..".last_error"
        safeSetString(key,table.concat({timeText(at or readTime()),clean(event,48),"error",detail},"|"))
        appendEvent(event,"error",detail,at)
    end
    local function heartbeatKey(event)
        return sideRoot(sideFor(event))..".heartbeat."..keyPart(event)
    end
    local function writeHeartbeat(event,state,detail,at)
        if not enabled then return end
        safeSetString(heartbeatKey(event),encode(at or readTime(),event,state,detail))
    end
    local function beginHeartbeat(event)
        if not enabled then return nil end
        local at=readTime()
        local previous=heartbeatAt[event]
        local due=false
        local detail=""
        if at==nil then
            if previous==nil then due=true end
            heartbeatAt[event]=false
            detail="clock-unavailable"
        elseif previous==nil or previous==false then
            due=true
            heartbeatAt[event]=at
        elseif at<previous then
            due=true
            detail="clock-regressed"
            heartbeatAt[event]=at
            appendEvent(event,"clock_regressed","GetTime",at)
        elseif at-previous>=1 then
            due=true
            heartbeatAt[event]=at
        end
        if not due then return nil end
        writeHeartbeat(event,"enter",detail,at)
        return {event=event,at=at}
    end
    local function finishHeartbeat(token,state,detail)
        if not token then return end
        writeHeartbeat(token.event,state,detail,readTime())
    end
    local function pack(...)
        return {n=select("#",...),...}
    end
    local unpackValues=unpack
    local function isActive()
        if not enabled then return false end
        if not safeGetBool(enabledKey) then enabled=false;return false end
        return true
    end
    local function wrapCallback(namespace,name,callbackName)
        if type(namespace)~="table" or type(namespace[name])~="function" then return end
        local hookKey=callbackName or name
        if wrapped[hookKey] then return end
        local original=namespace[name]
        namespace[name]=function(...)
            if not isActive() then return original(...) end
            local marker=beginHeartbeat(hookKey)
            local result=pack(pcall(original,...))
            if not result[1] then
                local err=result[2]
                finishHeartbeat(marker,"error",clean(err,160))
                writeLastError(hookKey,err,readTime())
                error(err,0)
            end
            finishHeartbeat(marker,"exit")
            return unpackValues(result,2,result.n)
        end
        wrapped[hookKey]=true
    end
    local function wrapQuickload()
        if type(server)~="table" or wrapped["server.handleCommand"] then return false end
        local original=type(server.handleCommand)=="function" and server.handleCommand or nil
        server.handleCommand=function(command,...)
            if not isActive() or command~="quickload" then
                if original then return original(command,...) end
                return
            end
            local at=readTime()
            local marker=appendEvent("server.handleCommand","enter","quickload",at)
            local lastQuickloadKey=sideRoot("server")..".last_quickload"
            safeSetString(lastQuickloadKey,encode(at,"server.handleCommand","enter","quickload"))
            local result=original and pack(pcall(original,command,...)) or {n=1,true}
            if not result[1] then
                local err=result[2]
                updateEvent(marker,"error",clean(err,160),readTime())
                safeSetString(lastQuickloadKey,encode(readTime(),"server.handleCommand","error",clean(err,1024)))
                writeLastError("server.handleCommand.quickload",err,readTime())
                error(err,0)
            end
            local ended=readTime()
            updateEvent(marker,"exit","quickload",ended)
            safeSetString(lastQuickloadKey,encode(ended,"server.handleCommand","exit","quickload"))
            return unpackValues(result,2,result.n)
        end
        wrapped["server.handleCommand"]=true
        return true
    end
    local function install()
        if not enabled or hooksInstalled then return end
        local names={}
        local function add(namespace,name,event)
            if type(namespace)=="table" and type(namespace[name])=="function" and not wrapped[event or name] then
                wrapCallback(namespace,name,event)
                names[#names+1]=event or name
            end
        end
        add(client,"init","client.init")
        add(client,"tick","client.tick")
        add(client,"draw","client.draw")
        add(server,"init","server.init")
        add(server,"tick","server.tick")
        add(server,"update","server.update")
        if wrapQuickload() then names[#names+1]="server.handleCommand.quickload" end
        hooksInstalled=true
        appendEvent("diagnostics","hooks_installed",table.concat(names,","))
    end

    enabled=safeGetBool(enabledKey)
    if enabled then appendEvent("diagnostics","module_load",processSide) end
    function OSP.Diagnostics.isEnabled()
        return isActive()
    end
    function OSP.Diagnostics.setEnabled(value)
        value=value==true
        if value==enabled then return true end
        if value then
            if not safeSetBool(enabledKey,true) then return false end
            enabled=true
            appendEvent("diagnostics","enabled",processSide)
            install()
            return true
        end
        if not safeSetBool(enabledKey,false) then return false end
        appendEvent("diagnostics","disabled",processSide)
        enabled=false
        return true
    end
    function OSP.Diagnostics.begin(event)
        return beginHeartbeat(event)
    end
    function OSP.Diagnostics.finish(token)
        finishHeartbeat(token,"exit")
    end
    function OSP.Diagnostics.install()
        install()
    end
end
