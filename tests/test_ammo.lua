-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
local count=0
local function check(value,message) assert(value,message);count=count+1 end
local function eq(actual,expected,message)
    check(actual==expected,(message or "equality")..": "..tostring(actual).." ~= "..tostring(expected))
end

local function world()
    local w={catalog={"gun","sledge"},players={},writes={},apiCalls=0}
    for _,id in ipairs({1,2}) do
        w.players[id]={health=1,tool=id==1 and "gun" or "sledge",
            enabled={gun=true,sledge=true},ammo={gun=40,sledge=25}}
    end
    local env=setmetatable({server=false,client=false},{__index=_G})
    env.HasKey=function(key)
        w.apiCalls=w.apiCalls+1
        if key:sub(1,10)~="game.tool." then return false end
        local id=key:sub(11)
        for _,tool in ipairs(w.catalog) do if tool==id then return true end end
        return false
    end
    env.GetPlayerHealth=function(p) w.apiCalls=w.apiCalls+1;return w.players[p].health end
    env.GetPlayerTool=function(p) w.apiCalls=w.apiCalls+1;return w.players[p].tool end
    env.IsToolEnabled=function(tool,p) w.apiCalls=w.apiCalls+1;return w.players[p].enabled[tool]==true end
    env.GetToolAmmo=function(tool,p) w.apiCalls=w.apiCalls+1;return w.players[p].ammo[tool] end
    env.SetToolAmmo=function(tool,ammo,p)
        w.apiCalls=w.apiCalls+1
        w.players[p].ammo[tool]=ammo
        w.writes[#w.writes+1]={player=p,tool=tool,ammo=ammo}
    end
    local chunk=assert(loadfile(arg[1]));setfenv(chunk,env);chunk()
    w.api=env
    return w
end

-- Construction owns no engine calls, so the controller can be initialized at
-- script load without depending on a live player or gameplay API.
do
    local w=world();local before=w.apiCalls
    local controller=w.api.OSP.Ammo.new()
    eq(w.apiCalls,before,"controller construction does not call game APIs")
    controller:tick(1,{ammo=false,ammoRestore=true,challenge=1})
    controller:stop(1,true);controller:remove(1);controller:reset()
    eq(w.apiCalls,before,"inactive lifecycle calls need no engine state")
end

-- Refill only the equipped, registered, enabled tool, preserving its first
-- observed reserve and restoring all refilled tools from that same entry.
do
    local w=world();local controller=w.api.OSP.Ammo.new()
    local one={ammo=true,ammoRestore=true,challenge=11}
    local two={ammo=true,ammoRestore=true,challenge=22}
    w.players[1].ammo.gun=8;w.players[2].ammo.sledge=12000
    controller:tick(1,one);eq(w.players[1].ammo.gun,9999)
    eq(w.players[2].ammo.sledge,12000,"larger reserves are not reduced")
    eq(#w.writes,1,"only depleted equipped tools are written")
    w.players[1].ammo.gun=3;controller:tick(1,one);eq(w.players[1].ammo.gun,9999)
    w.players[1].tool="sledge";w.players[1].ammo.sledge=100
    controller:tick(1,one);eq(w.players[1].ammo.sledge,9999,"second equipped tool gets its own reserve")
    w.players[1].tool="gun";w.players[1].ammo.gun=9000
    controller:tick(1,one);eq(w.players[1].ammo.gun,9999)
    w.players[1].ammo.gun=11000;controller:tick(1,one)
    eq(w.players[1].ammo.gun,11000,"ammo above the reserve is never reduced")
    controller:stop(1,true)
    eq(w.players[1].ammo.gun,8,"stop restores original gun stock")
    eq(w.players[1].ammo.sledge,100,"stop restores every touched tool")
    eq(w.players[2].ammo.sledge,12000,"stopping another player leaves their baseline alone")
end

-- A baseline is retained even while restoration is disabled; the preference is
-- read only when the effect ends, not when it changes.
do
    local w=world();local controller=w.api.OSP.Ammo.new()
    local e={ammo=true,ammoRestore=false,challenge=4}
    w.players[1].ammo.gun=12
    controller:tick(1,e);eq(w.players[1].ammo.gun,9999)
    w.players[1].ammo.gun=200;controller:tick(1,e);eq(w.players[1].ammo.gun,9999)
    local writes=#w.writes
    e.ammoRestore=true
    eq(#w.writes,writes,"changing restoration preference has no immediate effect")
    controller:stop(1,e.ammoRestore)
    eq(w.players[1].ammo.gun,12,"latest restoration preference restores captured baseline")

    e={ammo=true,ammoRestore=false,challenge=5};w.players[1].ammo.gun=6
    controller:tick(1,e);w.players[1].ammo.gun=7000
    controller:stop(1,e.ammoRestore)
    eq(w.players[1].ammo.gun,7000,"restore false conserves current stock")
end

-- Tool availability and the native infinite-ammo sentinel are fail-closed.
do
    local w=world();local controller=w.api.OSP.Ammo.new()
    local e={ammo=true,ammoRestore=true,challenge=1}
    w.players[1].ammo.gun=-1
    controller:tick(1,e);eq(#w.writes,0,"negative infinite-ammo sentinel is untouched")
    w.players[1].ammo.gun=math.huge;controller:tick(1,e)
    eq(#w.writes,0,"non-finite ammo is untouched")
    w.players[1].ammo.gun=5;w.players[1].enabled.gun=false
    controller:tick(1,e);eq(#w.writes,0,"disabled tools are not refilled")
    w.players[1].enabled.gun=true;controller:tick(1,e)
    eq(w.players[1].ammo.gun,9999,"enabled equipped tool can be captured later")
    w.players[1].enabled.gun=false;controller:stop(1,true)
    eq(w.players[1].ammo.gun,5,"a disabled but registered tool can be restored")

    w.players[1].enabled.gun=true;w.players[1].ammo.gun=2
    controller:tick(1,e);eq(w.players[1].ammo.gun,9999)
    local before=#w.writes
    w.catalog={"sledge"};controller:tick(1,e)
    eq(#w.writes,before,"a tool removed from the registry is discarded")
    controller:stop(1,true);eq(#w.writes,before,"absent tool never receives restoration")

    w.players[1].tool="none";controller:tick(1,e)
    eq(#w.writes,before,"empty tool sentinel is ignored")
end

-- Removal and challenge changes discard the old occupant's state without a
-- setter, then capture a clean baseline for the new join using the same ID.
do
    local w=world();local controller=w.api.OSP.Ammo.new()
    local e={ammo=true,ammoRestore=true,challenge=1}
    w.players[1].ammo.gun=15;controller:tick(1,e)
    local before=#w.writes
    w.players[1].ammo.gun=70;e.challenge=2
    controller:tick(1,e)
    eq(w.players[1].ammo.gun,9999,"changed join captures a fresh stock")
    eq(#w.writes,before+1,"old join snapshot is not restored onto the new occupant")
    controller:stop(1,true)
    eq(w.players[1].ammo.gun,70,"new join restores its own baseline")

    e.challenge=3;w.players[1].ammo.gun=20;controller:tick(1,e)
    before=#w.writes;controller:remove(1)
    eq(#w.writes,before,"removal never writes to a possibly recycled ID")
    w.players[1].ammo.gun=30;e.challenge=4;controller:tick(1,e)
    controller:stop(1,true);eq(w.players[1].ammo.gun,30,"reused ID does not inherit prior baseline")

    e.challenge=5;e.ammo=true;w.players[1].ammo.gun=14;controller:tick(1,e)
    before=#w.writes;w.players[1].ammo.gun=42;e.challenge=6;e.ammo=false
    controller:tick(1,e)
    eq(w.players[1].ammo.gun,42,"inactive new join does not receive previous occupant stock")
    eq(#w.writes,before,"inactive challenge change discards without a setter")

    e.challenge=7;e.ammo=true;w.players[1].ammo.gun=18;controller:tick(1,e)
    before=#w.writes;w.players[1].ammo.gun=64;e.challenge=8;w.players[1].health=0
    controller:tick(1,e)
    eq(w.players[1].ammo.gun,64,"dead new join does not receive previous occupant stock")
    eq(#w.writes,before,"dead challenge change discards without a setter")
end

-- Death ends the active snapshot and keeps the ability flag available for a
-- fresh baseline after native respawn.
do
    local w=world();local controller=w.api.OSP.Ammo.new()
    local e={ammo=true,ammoRestore=true,challenge=8}
    w.players[1].ammo.gun=9;controller:tick(1,e)
    w.players[1].health=0;controller:tick(1,e)
    eq(w.players[1].ammo.gun,9,"death restores when the current preference allows it")
    check(e.ammo,"death does not revoke the saved ability flag")
    w.players[1].health=1;w.players[1].ammo.gun=22;controller:tick(1,e)
    eq(w.players[1].ammo.gun,9999,"living respawn begins with a new baseline")
    controller:stop(1,false);eq(w.players[1].ammo.gun,9999)
end

print("PASS ammo controller behavior: "..count.." assertions")
