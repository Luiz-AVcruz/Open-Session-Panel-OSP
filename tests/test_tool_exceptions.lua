-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Global tool blocks can contain host-managed, profile-backed exceptions.
local function fixture(name)
    local chunk=assert(loadfile('tests/test_'..name..'.lua'))
    setfenv(chunk,setmetatable({arg={arg[1],'fixture'}},{__index=_G}))
    return chunk()
end
local count=0
local function check(value,message) assert(value,message);count=count+1 end
local function eq(a,b,message) check(a==b,(message or 'equality')..': '..tostring(a)..' ~= '..tostring(b)) end
local function encoded(id) return id:gsub('.',function(c) return string.format('%02x',c:byte()) end) end
local make=fixture('server')
local w=make({catalog={'sledge','gun'}})
local function profileTool(player,id)
    return 'savegame.mod.osp_beta.players.'..w.identities[player]..'.tools.'..encoded(id)
end

eq(w.command(11,'tool_policy',0,{id='gun',mode='disabled'}),true)
for _,player in ipairs({11,23,47}) do eq(w.players[player].tools.gun,false,'global block applies to all') end

-- Host-granted exceptions use the distinct saved value 3 and survive normal
-- enforcement, respawn, a new mission, and reconnecting the same profile.
eq(w.command(11,'tool',23,{id='gun',enabled=true}),true,'host opens a personal exception')
eq(w.players[23].tools.gun,true)
eq(w.api.shared.osp.players[2].toolGrants.gun,true)
eq(w.api.GetInt(profileTool(23,'gun')),3,'exception has a dedicated saved value')
w.tick();eq(w.players[23].tools.gun,true,'tick preserves the grant')
eq(w.players[47].tools.gun,false,'other players stay blocked')
eq(w.command(11,'respawn',23),true);w.tick()
eq(w.players[23].tools.gun,true,'respawn reapplies the grant')
local identity23=w.identities[23]
w.removed={23};w.tick();w.identify(23,identity23)
eq(w.api.shared.osp.players[2].toolGrants.gun,true,'same profile reloads its grant')
local nextMap=make({catalog={'sledge','gun'},identities={[23]=identity23}})
eq(nextMap.players[23].tools.gun,true,'grant survives a new map')
eq(nextMap.players[47].tools.gun,false,'new profile receives no grant')

-- A delegated player can pause and restore an existing exception, but this
-- temporary state does not rewrite the host's saved grant.
eq(w.command(11,'role_assign',23,{id='self'}),true)
eq(w.command(23,'tool',23,{id='gun',enabled=false}),true,'self may temporarily pause a granted tool')
eq(w.api.shared.osp.players[2].toolGrants.gun,true,'pausing does not revoke the exception')
eq(w.command(23,'tool',23,{id='gun',enabled=true}),true,'self may restore an existing grant')
eq(w.api.GetInt(profileTool(23,'gun')),3,'delegated toggles do not change saved state')

-- Revocation is an explicit host disable and saves an ordinary personal block.
eq(w.command(11,'tool',23,{id='gun',enabled=false}),true)
eq(w.players[23].tools.gun,false)
eq(w.api.shared.osp.players[2].toolGrants.gun,nil,'host revocation removes the grant')
eq(w.api.GetInt(profileTool(23,'gun')),2,'revocation is persisted as a disable')
w.tick();eq(w.players[23].tools.gun,false)

-- Built-in Self and Moderator roles cannot create exceptions. Their bulk paths
-- still apply safe tools and report blocked-only changes as skipped.
eq(w.command(11,'role_assign',23,{id='self'}),true)
local ok,code=w.command(23,'tool',23,{id='gun',enabled=true})
eq(ok,false);eq(code,'protected','Self cannot create a grant')
eq(w.players[23].tools.gun,false)
eq(w.command(11,'role_assign',23,{id='moderator'}),true)
ok,code=w.command(23,'tool',23,{id='gun',enabled=true})
eq(ok,false);eq(code,'protected','Moderator cannot create a grant')
local _,_,details=w.command(23,'tools',23,true)
eq(details.affected,1,'bulk still changes unblocked tools')
eq(w.players[23].tools.gun,false,'bulk does not lift the global block')
local result,_,all=w.command(23,'tool_all',0,{id='gun',enabled=true})
eq(result,true);eq(all.affected,0);eq(all.skipped,3,'everyone skips host and ungranted blocked tools')
eq(w.players[47].tools.gun,false)
-- A role with tool_policy but no tools permission still cannot issue a targeted
-- grant; the action's ordinary target permission is checked first.
local noTools=w.api.OSP.Permissions.normalize({tool_policy=2})
local role,roleCode,roleDetails=w.command(11,'role_save',0,{id='',name='Policy only',version=0,permissions=noTools})
eq(role,true);eq(roleCode,'ok')
local roleId=roleDetails.template and roleDetails.template.id
check(type(roleId)=='string','custom role id is logged')
eq(w.command(11,'role_assign',23,{id=roleId}),true)
eq(w.command(23,'tool_conflict_mode',0,{id='gun',mode='attempt'}),true,'global policy delegate may choose compatibility handling')
ok,code=w.command(23,'tool',47,{id='gun',enabled=true})
eq(ok,false);eq(code,'denied','tool_policy alone does not grant tools target scope')
ok,code=w.command(23,'tool_all',0,{id='gun',enabled=true})
eq(ok,false);eq(code,'denied','tool_policy alone does not grant bulk tool scope')
eq(w.command(11,'role_assign',47,{id='self'}),true)
ok,code=w.command(47,'tool_conflict_mode',0,{id='gun',mode='suspend'})
eq(ok,false);eq(code,'denied','Self and tools-only roles cannot change session compatibility handling')

-- Ordinary Moderator bulk actions may enable an existing exception, but do
-- not create grants for other tools. All direct and everyone variants share
-- this per-player, per-tool decision.
local bulkMake=fixture('server')
local bulk=bulkMake({catalog={'sledge','gun','modlaser'}})
eq(bulk.command(11,'tool_policy_bulk',0,{category='all',mode='disabled'}),true)
eq(bulk.command(11,'tool',47,{id='gun',enabled=true}),true)
eq(bulk.command(11,'role_assign',23,{id='moderator'}),true)
for _,action in ipairs({'tools','tools_filtered','tools_selection'}) do
    local targetValue=action=='tools' and true
        or action=='tools_filtered' and {category='all',enabled=true}
        or {category='all',ids={'gun','sledge','modlaser'},enabled=true}
    local _,_,details=bulk.command(23,action,47,targetValue)
    eq(details.affected,1,action..' applies the existing grant')
    eq(bulk.players[47].tools.gun,true,action..' keeps the granted tool enabled')
    eq(bulk.players[47].tools.sledge,false,action..' cannot create a sledge grant')
    eq(bulk.players[47].tools.modlaser,false,action..' cannot create a mod tool grant')
end
local _,_,filtered=bulk.command(23,'tools_filtered',47,{category='mod',enabled=true})
eq(filtered.affected,0);eq(filtered.skipped,1,'filtered activation skips a missing grant')
local _,_,selected=bulk.command(23,'tools_selection',47,{category='all',ids={'sledge'},enabled=true})
eq(selected.affected,0);eq(selected.skipped,1,'selection activation skips a missing grant')
local _,_,singleAll=bulk.command(23,'tool_all',0,{id='gun',enabled=true})
eq(singleAll.affected,1);eq(singleAll.skipped,2,'tool_all only reaches a granted target')
local everyoneCases={
    {'tools_all',true},
    {'tools_filtered_all',{category='all',enabled=true}},
    {'tools_selection_all',{category='all',ids={'gun','sledge','modlaser'},enabled=true}},
}
for _,case in ipairs(everyoneCases) do
    local _,_,details=bulk.command(23,case[1],0,case[2])
    eq(details.affected,1,case[1]..' affects only the target with a grant')
    eq(details.skipped,2,case[1]..' skips host and player without a grant')
    eq(bulk.players[11].tools.gun,false,'delegated bulk cannot change the host')
    eq(bulk.players[23].tools.gun,false,case[1]..' cannot grant the actor')
    eq(bulk.players[47].tools.gun,true,case[1]..' enables the existing grant')
    eq(bulk.players[47].tools.sledge,false,case[1]..' does not create another grant')
    eq(bulk.players[47].tools.modlaser,false,case[1]..' does not create a mod grant')
end
local _,_,missingSingle=bulk.command(23,'tool_all',0,{id='sledge',enabled=true})
eq(missingSingle.affected,0);eq(missingSingle.skipped,3,'tool_all skips every ungranted target and the host')
local _,_,missingFiltered=bulk.command(23,'tools_filtered_all',0,{category='mod',enabled=true})
eq(missingFiltered.affected,0);eq(missingFiltered.skipped,3,'filtered everyone cannot create grants')
local _,_,missingSelected=bulk.command(23,'tools_selection_all',0,{category='all',ids={'sledge'},enabled=true})
eq(missingSelected.affected,0);eq(missingSelected.skipped,3,'selection everyone cannot create grants')

-- A policy admin with ordinary target and bulk tool scopes may open exceptions,
-- but only temporarily; host remains the only writer of profile .tools values.
local grants=w.api.OSP.Permissions.normalize({tool_policy=2,tools=2,tools_all=2})
local savedRole,savedRoleCode,savedRoleDetails=w.command(11,'role_save',0,{id='',name='Temporary policy admin',version=0,permissions=grants})
eq(savedRole,true);eq(savedRoleCode,'ok')
roleId=savedRoleDetails.template and savedRoleDetails.template.id
check(type(roleId)=='string')
eq(w.command(11,'role_assign',23,{id=roleId}),true)
eq(w.command(23,'tool',47,{id='gun',enabled=true}),true,'delegated policy admin grants within tools target scope')
eq(w.players[47].tools.gun,true)
eq(w.api.shared.osp.players[3].toolGrants.gun,true)
eq(w.api.GetInt(profileTool(47,'gun')),0,'delegated grant is not persisted')
eq(w.command(23,'tool',23,{id='gun',enabled=true}),true,'delegated policy admin may grant itself within tools scope')
eq(w.api.shared.osp.players[2].toolGrants.gun,true)
eq(w.command(23,'tool_all',0,{id='gun',enabled=true}),true,'bulk policy admin may manage allowed targets')
eq(w.players[11].tools.gun,false,'host is excluded from delegated everyone actions')

-- Reapplying even the same global policy clears online and offline grants and
-- their host profile values; fresh numeric-ID occupants do not inherit grants.
eq(w.command(11,'tool',47,{id='gun',enabled=true}),true)
eq(w.api.GetInt(profileTool(47,'gun')),3)
local identity47=w.identities[47]
w.players[47]=nil;w.removed={47};w.tick()
eq(w.command(11,'tool_policy',0,{id='gun',mode='disabled'}),true)
eq(w.api.shared.osp.players[2].toolGrants.gun,nil)
check(not w.api.HasKey(profileTool(47,'gun')),'reapplying policy clears offline exception')
local freshId=make({catalog={'sledge','gun'}})
eq(freshId.players[23].tools.gun,false,'recycled runtime ID gets no old grant')
check(freshId.identities[23]~=identity23,'fresh occupant has a new profile')

-- Legacy value 1 is only a personal enable; it never becomes an exception.
w.api.SetInt(profileTool(23,'gun'),1)
local legacy=make({catalog={'sledge','gun'},identities={[23]=identity23}})
eq(legacy.api.shared.osp.players[2].toolRules.gun,true,'legacy enable remains readable')
eq(legacy.api.shared.osp.players[2].toolGrants.gun,nil,'legacy enable is not a grant')
eq(legacy.players[23].tools.gun,false,'global block still dominates legacy value 1')

-- Player reset removes both the live grant and saved profile data.
eq(legacy.command(11,'tool',23,{id='gun',enabled=true}),true)
eq(legacy.api.GetInt(profileTool(23,'gun')),3)
eq(legacy.command(11,'reset_player',23),true)
eq(legacy.api.shared.osp.players[2].toolGrants.gun,nil)
check(not legacy.api.HasKey(profileTool(23,'gun')),'reset clears saved exceptions')
eq(legacy.players[23].tools.gun,false,'global block remains after player reset')

print('PASS: '..count..' tool exception assertions')
