-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
local count=0
local function check(v,m) assert(v,m);count=count+1 end
local function eq(a,b,m) check(a==b,(m or 'equality')..': '..tostring(a)..' ~= '..tostring(b)) end
local function fresh(options)
    local f=assert(loadfile('tests/test_server.lua'))
    setfenv(f,setmetatable({arg={arg[1],'fixture'}},{__index=_G}))
    local make=f();return make(options),make
end
local function player(w,id)
    for _,p in ipairs(w.api.shared.osp.players) do if p.id==id then return p end end
end
local function request(w,actor,action,scope,value,role,exclude,ids)
    local v={host=w.api.shared.osp.profileHost,actorJoin=player(w,actor).profileChallenge,
        action=action,scope=scope or 'all',excludeSelf=exclude==true,value=value,role=role,targets={}}
    for _,p in ipairs(w.api.shared.osp.players) do
        local include=not ids
        if ids then for _,id in ipairs(ids) do if p.id==id then include=true end end end
        if include and w.api.OSP.Collective.matches(p,v.scope,role,exclude,actor) then
            v.targets[#v.targets+1]={id=p.id,join=p.profileChallenge}
        end
    end
    return v
end
local function apply(w,actor,action,scope,value,role,exclude,ids)
    return w.command(actor,'players_group',0,request(w,actor,action,scope,value,role,exclude,ids))
end
local function assignment(w,actor,role,ids)
    local v=request(w,actor,nil,'manual',nil,nil,false,ids)
    return {host=v.host,actorJoin=v.actorJoin,role=role,targets=v.targets}
end
local function addPlayer(w,id,profile)
    local p=w.api.OSP.copy(w.players[23] or w.players[47]);p.id=id;p.name='New '..id;p.host=false
    p.params.godMode=false;p.params.flyMode=false;p.vehicle=0;p.health=1
    w.players[id]=p;w.tick();w.identify(id,profile)
end
local function profilePath(w,id,key)
    return 'savegame.mod.osp.players.'..(id==11 and 'host' or w.identities[id])..'.'..key
end

-- Uniform values, exclusions and explicit sets: the executor never inverts peers.
for action in pairs(({god=true,freeze=true,fly=true,noclip=true,strength=true,ammo=true})) do
    local w=fresh();eq(w.command(11,action,23,true),true)
    local ok,code,d=apply(w,11,action,'all',true,nil,true)
    eq(ok,true,code);eq(d.affected,2);eq(player(w,23)[action],true);eq(player(w,47)[action],true)
    eq(player(w,11)[action],false,'exclude operator: '..action)
    eq(apply(w,11,action,'manual',false,nil,false,{23}),true)
    eq(player(w,23)[action],false);eq(player(w,47)[action],true)
end

-- Role filtering excludes Host even though its stored role may resolve to Guest.
do
    local w=fresh();w.command(11,'role_assign',23,{id='self'})
    eq(apply(w,11,'god','role',true,'guest'),true)
    eq(player(w,11).god,false);eq(player(w,23).god,false);eq(player(w,47).god,true)
    local old=request(w,11,'freeze','role',true,'guest')
    w.command(11,'role_assign',47,{id='self'})
    local ok,_,d=w.command(11,'players_group',0,old)
    eq(ok,true);eq(d.affected,0);eq(d.skipped,1);eq(player(w,47).freeze,false,'role membership is rechecked')
end

-- Role filtering is checked against independently specified expected members.
do
    local w=fresh();w.command(11,'role_assign',23,{id='self'})
    -- Deliberately supply every entry without using the selection matcher.
    local v=request(w,11,'god','all',true);v.scope='role';v.role='guest'
    local ok,_,d=w.command(11,'players_group',0,v)
    eq(ok,true);eq(d.affected,1);eq(d.skipped,2)
    eq(player(w,11).god,false,'Host is not a Guest group member')
    eq(player(w,23).god,false,'Self is not a Guest group member')
    eq(player(w,47).god,true,'Guest alone is affected')
end

-- No new permissions: per-target effects and pre-existing collective capabilities.
do
    local w=fresh();w.command(11,'role_assign',23,{id='self'})
    local ok,_,d=apply(w,23,'god','all',true)
    eq(ok,true);eq(d.affected,1);eq(d.skipped,2)
    eq(player(w,11).god,false);eq(player(w,23).god,true);eq(player(w,47).god,false)
    eq(apply(w,23,'heal','all'),false,'self healing does not grant collective healing')
    eq(w.command(23,'collective_future',0,true),false,'future rules remain host-only')
    w.command(11,'role_assign',23,{id='moderator'})
    w.players[11].health=.2;w.players[23].health=.3;w.players[47].health=.4
    ok,_,d=apply(w,23,'heal','all')
    eq(ok,true);eq(d.affected,2);eq(d.skipped,1);eq(w.players[11].health,.2)
    eq(w.players[23].health,1);eq(w.players[47].health,1)
    ok,_,d=apply(w,11,'bring','all')
    eq(ok,true);eq(d.affected,2);eq(d.skipped,1,'bring excludes its operator')
end

-- Payloads fail before mutation; stale entries and ID reuse cannot retarget.
do
    local w=fresh();local C=w.api.OSP.Collective
    local valid=request(w,11,'god','all',true)
    for _,change in ipairs({function(v) v.targets[2]=v.targets[1] end,
        function(v) v.targets[2]=nil end,function(v) v.targets[1].extra=true end,
        function(v) v.action='kill' end,function(v) v.value=1 end,
        function(v) v.role='guest' end,function(v) v.extra=true end,
        function(v) v.host='bad' end,function(v) v.actorJoin=0 end}) do
        local v=w.api.OSP.copy(valid);change(v)
        eq(C.validRequest(v),false)
        local ok,code=w.command(11,'players_group',0,v);eq(ok,false);eq(code,'invalid')
        eq(player(w,23).god,false)
    end
    local v=w.api.OSP.copy(valid);v.host=string.rep('b',32)
    local ok,code=w.command(11,'players_group',0,v);eq(ok,false);eq(code,'unavailable')
    v=w.api.OSP.copy(valid);v.actorJoin=v.actorJoin+1
    ok,code=w.command(11,'players_group',0,v);eq(ok,false);eq(code,'unavailable')
    ok,code=w.command(11,'players_group',47,valid);eq(ok,false);eq(code,'invalid','batch RPC requires the global target')
    v=request(w,11,'god','manual',true,nil,false,{23})
    w.players[23]=nil;w.tick();addPlayer(w,23)
    local d;ok,_,d=w.command(11,'players_group',0,v)
    eq(ok,true);eq(d.affected,0);eq(d.skipped,1);eq(player(w,23).god,false)
    local log=w.api.shared.osp.log[#w.api.shared.osp.log]
    eq(log.argument.targets,nil,'activity does not expose target contexts')
end

-- Manual selections never create defaults; false Role values override true globals.
do
    local w,make=fresh();w.command(11,'collective_future',0,true)
    eq(apply(w,11,'ammo','manual',true,nil,false,{23}),true)
    eq(w.api.HasKey('savegame.mod.osp.collective.defaults'),false)
    eq(apply(w,11,'god','all',true,nil,false,{}),true)
    eq(apply(w,11,'god','role',false,'guest',false,{}),true)
    addPlayer(w,91);eq(player(w,91).god,false,'Role false overrides global true')
    local n=make({identities=w.identities});eq(player(n,47).god,false,'false override survives serialization')
    eq(apply(n,11,'god','all',false,nil,false,{}),true)
    eq(apply(n,11,'god','role',true,'guest',false,{}),true)
    addPlayer(n,92);eq(player(n,92).god,true,'Role true overrides global false')
end

-- Defaults apply at entry only; individual choices and restorations win.
do
    local w,make=fresh();eq(w.command(11,'collective_future',0,true),true)
    eq(apply(w,11,'god','all',true,nil,true),true)
    addPlayer(w,91);eq(player(w,91).god,true,'new profile inherits')
    eq(w.api.HasKey(profilePath(w,91,'god')),false,'inheritance is not an individual choice')
    w.command(11,'role_assign',91,{id='self'})
    eq(w.command(91,'god',91,false),true)
    local n=make({identities=w.identities});addPlayer(n,91,w.identities[91]);eq(player(n,91).god,false,'own disable survives entry')
    eq(player(n,11).god,false,'excluded host never inherits')
    eq(n.command(11,'reset_player',47),true)
    local after=make({identities=n.identities});eq(player(after,47).god,false,'reset opts out of future defaults')
    eq(after.command(11,'collective_future',0,false),true)
    eq(after.command(11,'collective_future',0,true),true)
    addPlayer(after,92);eq(player(after,92).god,false,'reenabling never revives cleared defaults')
end

-- Restoration opts out even if future defaults were not yet enabled.
do
    local w,make=fresh();w.command(11,'reset_player',47)
    w.command(11,'collective_future',0,true)
    apply(w,11,'strength','all',true,nil,false,{})
    local n=make({identities=w.identities})
    eq(player(n,47).strength,false,'restoration remains explicit even before future rules were enabled')
end

-- Role defaults are separate from permissions, survive rename and do not follow reassignment.
do
    local w,make=fresh();w.command(11,'collective_future',0,true)
    local ok,_,d=w.command(11,'role_save',0,{id='',name='Visitors',version=0,permissions={heal=1}})
    eq(ok,true);local role=d.template
    eq(apply(w,11,'noclip','role',true,role.id),true,'empty Role can receive future defaults')
    eq(w.command(11,'role_assign',23,{id=role.id}),true)
    eq(player(w,23).noclip,false,'assignment is not an effect grant')
    local n=make({identities=w.identities});eq(player(n,23).noclip,true)
    eq(n.api.HasKey(profilePath(n,23,'noclip')),false)
    eq(n.command(11,'role_assign',23,{id='self'}),true);eq(player(n,23).noclip,true,'changing Role does not revoke an action/default')
    n.command(11,'role_assign',47,{id=role.id})
    eq(n.command(11,'role_save',0,{id=role.id,name='Renamed',version=role.version,permissions={heal=1}}),true)
    local again=make({identities=n.identities});eq(player(again,47).noclip,true)
    eq(apply(again,11,'noclip','all',false),true,'global order clears older Role exceptions')
    eq(again.api.HasKey('savegame.mod.osp.collective.defaults.roles.'..role.id..'.noclip'),false)
    eq(apply(again,11,'fly','role',true,role.id),true)
    local current
    for _,r in ipairs(again.api.shared.osp.templates) do if r.id==role.id then current=r end end
    eq(again.command(11,'role_delete',0,{id=role.id,version=current.version}),true)
    eq(again.api.HasKey('savegame.mod.osp.collective.defaults.roles.'..role.id),false)
end

-- Invalid saved Roles inherit through the effective Guest fallback.
do
    local w,make=fresh();w.command(11,'collective_future',0,true)
    apply(w,11,'god','role',true,'guest',false,{})
    w.api.SetString(profilePath(w,23,'role'),'deleted_or_corrupt')
    w.api.SetBool(profilePath(w,23,'admin'),true)
    local n=make({identities=w.identities})
    eq(player(n,23).role,'guest','unknown saved role resolves to Guest')
    eq(player(n,23).god,true,'defaults follow the effective Role')
    eq(player(n,23).permissions.role_assign,0,'fallback does not resurrect administrator access')
end

-- Future rules never overwrite profile choices; entry-off policy remains highest.
do
    local w,make=fresh();w.command(11,'collective_future',0,true)
    w.command(11,'noclip',23,true)
    w.api.ClearKey(profilePath(w,23,'flight'))
    eq(apply(w,11,'fly','all',true,nil,false,{}),true)
    local n=make({identities=w.identities})
    eq(player(n,23).noclip,true);eq(player(n,23).fly,false,'saved Noclip wins over inherited Fly')
    eq(player(n,47).fly,true);eq(player(n,47).noclip,false)
    n.command(11,'effects_off_on_load',0,true)
    local off=make({identities=n.identities});eq(player(off,23).noclip,false);eq(player(off,47).fly,false)
    addPlayer(off,91);eq(player(off,91).fly,false,'entry-off also suppresses newcomer defaults')
end

-- Batch assignment validates the entire authority snapshot before self-demotion.
do
    local w,make=fresh();w.command(11,'role_assign',23,{id='admin'})
    local ok,code,d=w.command(23,'roles_assign_many',0,assignment(w,23,'self',{11,23,47}))
    eq(ok,true,code);eq(d.affected,2);eq(d.skipped,1)
    eq(player(w,11).host,true);eq(player(w,23).role,'self');eq(player(w,47).role,'self')
    local n=make({identities=w.identities});eq(player(n,47).role,'self')
    eq(n.command(23,'roles_assign_many',0,assignment(n,23,'admin',{47})),false,'no escalation')
    n.command(11,'role_assign',23,{id='moderator'})
    eq(n.command(23,'roles_assign_many',0,assignment(n,23,'self',{47})),false,'moderator lacks assignment capability')
    n.command(11,'role_assign',23,{id='admin'})
    local v=assignment(n,23,'guest',{47});v.targets[1].join=v.targets[1].join+1
    ok,_,d=n.command(23,'roles_assign_many',0,v);eq(ok,true);eq(d.affected,0);eq(d.skipped,1)
end

-- Failures retain successful counts and do not silently report full success.
do
    local w=fresh()
    local ok,_,d=w.command(11,'role_save',0,{id='',name='Assign weak',version=0,permissions={role_assign=2,heal=1}})
    eq(ok,true);local delegate=d.template
    ok,_,d=w.command(11,'role_save',0,{id='',name='Weak',version=0,permissions={heal=1}})
    eq(ok,true);local weak=d.template
    w.command(11,'role_assign',23,{id=delegate.id});w.command(11,'role_assign',47,{id='admin'})
    ok,_,d=w.command(23,'roles_assign_many',0,assignment(w,23,weak.id,{23,47}))
    eq(ok,true);eq(d.affected,1);eq(d.skipped,1);eq(player(w,47).role,'admin','stronger target is protected')
    w.command(11,'role_assign',23,{id=delegate.id})
    eq(w.command(23,'roles_assign_many',0,assignment(w,23,'admin',{23,47})),false,'cannot grant a stronger destination Role')
    eq(player(w,23).role,delegate.id,'rejection happens before mutation')
end

-- The requested twelve-player lobby assigns a Role with one operation.
do
    local w=fresh();local ids={23,47}
    for id=60,68 do addPlayer(w,id);ids[#ids+1]=id end
    local before=#w.api.shared.osp.log
    local ok,_,d=w.command(11,'roles_assign_many',0,assignment(w,11,'self',ids))
    eq(ok,true);eq(d.affected,11);eq(#w.api.shared.osp.log,before+1,'one operation for the full lobby')
    for _,id in ipairs(ids) do eq(player(w,id).role,'self') end
end

-- Delegated group toggles preserve host defaults and ordinary persistence rules.
do
    local w,make=fresh();w.command(11,'collective_future',0,true)
    w.command(11,'role_assign',23,{id='admin'})
    apply(w,11,'god','all',true)
    eq(apply(w,23,'god','all',false),true)
    eq(w.api.GetInt('savegame.mod.osp.collective.defaults.all.god'),1,'delegate cannot rewrite future defaults')
    local n=make({identities=w.identities})
    eq(player(n,23).god,false,'own explicit disable persists')
    eq(player(n,47).god,true,'delegate changes to others remain temporary')
end

-- An engine failure in one target is reported without discarding other results.
do
    local w=fresh();local set=w.api.SetPlayerParam
    w.api.SetPlayerParam=function(key,value,id) if id==23 then error('physics failed') end;return set(key,value,id) end
    w.api.DebugPrint=function() end
    local ok,code,d=apply(w,11,'god','all',true)
    eq(ok,true);eq(code,'partial');eq(d.affected,2);eq(d.failed,1)
    eq(player(w,47).god,true)
end
print('PASS collective actions, entry defaults and batch Role assignment: '..count..' assertions')
