-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
local count=0
local function check(v,m) assert(v,m);count=count+1 end
local function eq(a,b,m) check(a==b,(m or 'equality')..': '..tostring(a)..' ~= '..tostring(b)) end
local function fresh()
    local f=assert(loadfile('tests/test_server.lua'))
    setfenv(f,setmetatable({arg={arg[1],'fixture'}},{__index=_G}))
    local make=f();return make(),make
end
local function state(w,id)
    for _,p in ipairs(w.api.shared.osp.players) do if p.id==id then return p end end
end
local effects={god='god',fly='flight',noclip='noclip',strength='strength',ammo='ammo',freeze='freeze'}
local function path(w,id,key)
    return 'savegame.mod.osp_beta.players.'..(id==11 and 'host' or w.identities[id])..'.'..key
end

-- A delegate can remember only an explicit personal disable, never activation
-- or another player's disable. The host can override that saved state later.
for action,key in pairs(effects) do
    local w,make=fresh();eq(w.command(11,'role_assign',23,{id='admin'}),true)
    eq(w.command(11,action,23,true),true)
    eq(w.command(23,action,23,false),true)
    eq(state(w,23)[action],false);check(w.api.HasKey(path(w,23,key)))
    eq(w.api.GetBool(path(w,23,key)),false,'own disable is saved: '..action)
    if action=='noclip' then eq(w.api.GetBool(path(w,23,'fly')),false,'legacy Noclip flag stays off') end
    local nextMap=make({identities=w.identities})
    eq(state(nextMap,23)[action],false,'own disabled effect remains off on another map: '..action)
    eq(nextMap.command(23,action,23,true),true)
    local afterActivation=make({identities=w.identities})
    eq(state(afterActivation,23)[action],false,'self activation remains temporary: '..action)
    eq(afterActivation.command(11,action,23,true),true)
    local overridden=make({identities=w.identities})
    eq(state(overridden,23)[action],true,'host can explicitly enable it again: '..action)
    eq(overridden.command(11,action,47,true),true)
    eq(overridden.command(23,action,47,false),true)
    eq(state(overridden,47)[action],false)
    eq(overridden.api.GetBool(path(overridden,47,key)),true,'other-player disable remains temporary')
    local returned=make({identities=w.identities})
    eq(state(returned,47)[action],true)
end

-- Shortcut payloads use the same persistence path after their expected-state
-- check. Rejecting stale input must leave the saved profile untouched.
do
    local w,make=fresh();w.command(11,'role_assign',23,{id='self'})
    w.command(11,'god',23,true)
    eq(w.command(23,'god',23,{expected=true,value=false}),true)
    eq(w.api.GetBool(path(w,23,'god')),false)
    local n=make({identities=w.identities});eq(state(n,23).god,false)
    local ok,code=n.command(23,'god',23,{expected=true,value=false})
    eq(ok,false);eq(code,'state_changed');eq(n.api.GetBool(path(n,23,'god')),false)
end

-- Normal speed is a personal disable; tuning, restoration and throwing options
-- remain temporary. Mutual exclusion must not persist an incidental disable.
do
    local w,make=fresh();w.command(11,'role_assign',23,{id='admin'})
    eq(w.command(11,'speed',23,2),true);eq(w.command(23,'speed',23,1),true)
    eq(w.api.GetFloat(path(w,23,'speed')),1)
    local n=make({identities=w.identities});eq(state(n,23).speed,1)
    eq(n.command(23,'speed',23,2.5),true)
    eq(make({identities=w.identities}).api.GetFloat(path(w,23,'speed')),1)
    eq(n.command(11,'noclip',23,true),true);eq(n.command(23,'fly',23,true),true)
    eq(state(n,23).noclip,false,'Fly still suspends Noclip for this map')
    eq(n.api.GetBool(path(n,23,'noclip')),true,'incidental Noclip disable does not overwrite host state')
    local again=make({identities=w.identities});eq(state(again,23).noclip,true);eq(state(again,23).fly,false)
    eq(again.command(23,'ammo_restore',23,false),false,'restoration is suspended')
    eq(again.api.HasKey(path(again,23,'ammo_restore')),false)
    eq(again.command(11,'strength_throw',23,true),true)
    eq(again.command(23,'strength_throw',23,false),true)
    eq(again.api.GetBool(path(again,23,'strength_throw')),true,'throw configuration is outside personal disable persistence')
end

-- An unidentified caller cannot receive a successful but unsaved self-disable.
-- Permission and target-entry checks still run before any profile write.
do
    local _,make=fresh();local w=make({unidentified=true,baseGod=true})
    w.api.server.ospCommand(11,'role_save',0,{id='guest',name='Personal',version=0,permissions={god=1}})
    w.api.server.ospCommand(23,'god',23,false,nil,w.context(23))
    local reply=w.calls[#w.calls];eq(reply.args[1],false);eq(reply.args[2],'unavailable')
    eq(w.players[23].params.godMode,true,'unidentified disable has no gameplay effect')
    eq(state(w,23).profileReady,false)
    w.identify(23)
    eq(w.command(23,'god',23,false),true)
    eq(w.api.GetBool(path(w,23,'god')),false)
    w.command(11,'role_save',0,{id='guest',name='No powers',version=1,permissions={}})
    w.command(11,'god',23,true)
    local ok,code=w.command(23,'god',23,false)
    eq(ok,false);eq(code,'denied');eq(w.api.GetBool(path(w,23,'god')),true,'denial preserves the saved effect')
end

-- The host's default-off preference is latched per map. It clears only effect
-- activations and speed, before ammo/strength controllers get a live entry.
do
    local w,make=fresh();eq(w.api.shared.osp.effectsOffOnLoad,false)
    w.command(11,'role_assign',23,{id='admin'})
    for _,p in ipairs({11,23,47}) do
        for _,action in ipairs({'god','fly','strength','ammo','freeze'}) do eq(w.command(11,action,p,true),true) end
        eq(w.command(11,'speed',p,2),true)
        eq(w.command(11,'fly_speed',p,12),true);eq(w.command(11,'fly_boost',p,24),true)
        eq(w.command(11,'noclip_speed',p,11),true);eq(w.command(11,'noclip_boost',p,23),true)
        eq(w.command(11,'strength_force',p,3),true);eq(w.command(11,'strength_mass',p,8000),true)
        eq(w.command(11,'strength_throw',p,true),true);eq(w.command(11,'ammo_restore',p,false),false)
    end
    w.command(11,'tool_policy',0,{id='gun',mode='disabled'})
    w.command(11,'tool',23,{id='sledge',enabled=false})
    local existing=make({identities=w.identities})
    eq(state(existing,23).god,true,'default policy preserves previous persistence')
    eq(existing.command(11,'effects_off_on_load',0,true),true)
    eq(existing.api.shared.osp.effectsOffOnLoad,true)
    eq(state(existing,23).god,true,'changing preference leaves this map unchanged')
    local n=make({identities=w.identities})
    eq(n.api.shared.osp.effectsOffOnLoad,true)
    for _,p in ipairs({11,23,47}) do
        for field,key in pairs(effects) do
            eq(state(n,p)[field],false,'effect starts off for '..p..': '..field)
            eq(n.api.GetBool(path(n,p,key)),false)
        end
        eq(state(n,p).speed,1);eq(n.api.GetFloat(path(n,p,'speed')),1)
        eq(state(n,p).flySpeed,12);eq(state(n,p).flyBoost,24)
        eq(state(n,p).noclipSpeed,11);eq(state(n,p).noclipBoost,23)
        eq(state(n,p).strengthForce,3);eq(state(n,p).strengthMass,8000)
        eq(state(n,p).strengthThrow,true);eq(state(n,p).ammoRestore,false)
        eq(n.players[p].ammo.gun,50,'loading off does not prime ammunition')
        eq(n.players[p].tools.gun,false,'global tool policy is preserved')
    end
    eq(state(n,23).role,'admin');eq(n.players[23].tools.sledge,false,'personal tools are preserved')
    eq(n.command(11,'god',23,true),true);n.tick();eq(state(n,23).god,true,'manual activation remains possible')
    n.identify(23,n.identities[23]);eq(state(n,23).god,true,'repeated identity handshake does not clear an active effect')
    eq(n.command(11,'respawn',23),true);n.tick();eq(state(n,23).god,true,'respawn does not apply the map policy again')
    eq(n.command(11,'reset_rules',0),true);eq(n.api.shared.osp.effectsOffOnLoad,true,'reset session rules does not change this preference')
    eq(n.command(11,'effects_off_on_load',0,false),true)
    eq(state(n,23).god,true,'turning off preference leaves current effects alone')
    local after=make({identities=w.identities})
    eq(after.api.shared.osp.effectsOffOnLoad,false);eq(state(after,23).god,true,'next load follows the updated preference')
    for _,value in ipairs({'true',1,{value=true}}) do
        local ok,code=after.command(11,'effects_off_on_load',0,value)
        eq(ok,false);eq(code,'invalid');eq(after.api.shared.osp.effectsOffOnLoad,false)
    end
    local ok,code=after.command(23,'effects_off_on_load',0,true)
    eq(ok,false);eq(code,'denied','even Administrator cannot change the host preference')
    eq(after.api.shared.osp.effectsOffOnLoad,false)
end

-- Late/reconnecting players get the same policy selected at map load. Changing
-- it while playing does not make entrants follow a different rule mid-map.
do
    local w,make=fresh();w.command(11,'effects_off_on_load',0,true)
    local n=make({identities=w.identities});local id=n.identities[47]
    eq(n.command(11,'strength',47,true),true)
    eq(n.command(11,'effects_off_on_load',0,false),true)
    local native=n.players[47];n.players[47]=nil;n.removed={47};n.tick()
    n.players[47]=native;n.tick();n.identify(47,id)
    eq(state(n,47).strength,false,'entry still follows the policy captured at map load')
    eq(n.api.shared.osp.effectsOffOnLoad,false,'next map preference is separately visible')
end
-- Runtime defaults are cleared before a guest identifies; profile writes wait
-- for the existing handshake instead of creating anonymous saved choices.
do
    local w,make=fresh();w.command(11,'god',23,true);w.command(11,'noclip',23,true)
    w.command(11,'effects_off_on_load',0,true)
    local n=make({unidentified=true,baseGod=true,baseFly=true})
    eq(state(n,23).profileReady,false)
    eq(state(n,23).god,false);eq(state(n,23).noclip,false)
    n.tick()
    eq(n.players[23].params.godMode,false);eq(n.players[23].params.flyMode,false)
    eq(n.api.GetBool(path(w,23,'god')),true,'unidentified entry leaves the saved profile alone')
    n.identify(23,w.identities[23])
    eq(state(n,23).profileReady,true)
    eq(state(n,23).god,false);eq(state(n,23).noclip,false)
    eq(n.api.GetBool(path(w,23,'god')),false,'identified entry saves its cleared state')
end
print('PASS own-effect disable and map-load policy: '..count..' assertions')
