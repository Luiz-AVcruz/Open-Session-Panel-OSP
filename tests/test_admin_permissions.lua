-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Exercise delegated administration through the actual server command boundary.
local assertions=0
local function check(v,m) assert(v,m);assertions=assertions+1 end
local function eq(a,b,m) check(a==b,(m or 'equality')..': '..tostring(a)..' ~= '..tostring(b)) end
local function fresh()
    local factory=assert(loadfile('tests/test_server.lua'))
    setfenv(factory,setmetatable({arg={arg[1],'fixture'}},{__index=_G}))
    local make=factory()
    return make(),make
end
local function entry(w,id)
    for _,p in ipairs(w.api.shared.osp.players) do if p.id==id then return p end end
end
local serial=0
local function save(w,actor,grants,id,version,name)
    serial=serial+1
    return w.command(actor,'role_save',0,{id=id or '',version=version or 0,name=name or ('Role '..serial),permissions=grants})
end
local function create(w,grants)
    local ok,code,details=save(w,11,grants)
    eq(ok,true,code);return details.template
end
local function grant(w,values)
    local role=create(w,values)
    eq(w.command(11,'role_assign',23,{id=role.id}),true)
    return role
end
local function denied(w,action,target,arg,reason)
    local ok,code=w.command(23,action,target,arg)
    eq(ok,false,action);eq(code,reason or 'denied',action)
end

-- Administrator is complete; legacy custom templates keep their stored grants.
do
    local w,make=fresh();local P=w.api.OSP.Permissions
    local admin=P.resolve('admin').permissions
    local count=0
    for _,spec in ipairs(P.spec) do
        if spec.category=='admin' then eq(admin[spec.id],2,'Administrator includes every administrative capability');count=count+1 end
    end
    eq(count,7,'administrative actions are independent')
    eq(P.normalize({role_create=1}),nil,'global authority cannot use self scope')
    check(P.normalize({reset_player=1})~=nil,'player reset supports self scope')
    w.api.SetString('savegame.mod.osp.templates.c91.name','Legacy')
    w.api.SetInt('savegame.mod.osp.templates.c91.version',1)
    w.api.SetInt('savegame.mod.osp.templates.c91.permissions.heal',1)
    local nextMap=make({identities=w.identities})
    for _,role in ipairs(nextMap.api.shared.osp.templates) do
        if role.id=='c91' then
            for _,spec in ipairs(P.spec) do if spec.category=='admin' then eq(role.permissions[spec.id],0,'legacy grant defaults off') end end
        end
    end
    grant(w,P.resolve('admin').permissions)
    eq(w.command(23,'restart',0),true)
    eq(w.command(23,'tool_policy',0,{id='gun',mode='disabled'}),true)
    eq(save(w,23,{}),true,'Administrator can create roles')
end

-- Assignment is persistent but cannot change the host or exceed the delegate.
do
    local w,make=fresh();grant(w,{role_assign=2,heal=1})
    local weak=create(w,{heal=1});local strong=create(w,{heal=2})
    denied(w,'role_assign',11,{id='guest'},'protected')
    denied(w,'role_assign',47,{id=strong.id})
    denied(w,'role_assign',23,{id='admin'})
    denied(w,'admin',47,true) -- Old all-or-nothing RPC stays host-only.
    eq(w.command(23,'role_assign',47,{id=weak.id}),true)
    eq(entry(w,47).role,weak.id)
    local nextMap=make({identities=w.identities})
    eq(entry(nextMap,47).role,weak.id,'delegated assignment survives a new map')
    eq(nextMap.api.GetBool('savegame.mod.osp.players.'..w.identities[47]..'.admin'),false,'legacy bit follows role assignment')
    w.command(11,'role_assign',47,{id=strong.id})
    denied(w,'role_assign',47,{id='guest'})
    eq(entry(w,47).role,strong.id,'a stronger assignment is not stripped')
    denied(w,'role_save',0,{id='',name='No create',version=0,permissions={heal=1}})
end

-- Raw RPCs do not get the fixture helper's automatic identity handshake.
do
    local w=fresh();grant(w,{role_assign=2})
    local previous=w.context(47);local native=w.players[47]
    w.players[47]=nil;w.removed={47};w.tick();w.players[47]=native;w.tick()
    eq(entry(w,47).profileReady,false)
    for n,context in ipairs({previous,w.context(47)}) do
        w.api.server.ospCommand(23,'role_assign',47,{id='guest'},180+n,context)
        eq(w.calls[#w.calls].args[1],false)
        eq(w.calls[#w.calls].args[2],'unavailable','assignment needs a current, identified target')
        eq(entry(w,47).profileReady,false,'denial does not create or modify a profile')
    end
end
-- A restored host role cannot be edited indirectly through its template.
do
    local w,make=fresh();grant(w,{role_edit=2,role_delete=2,heal=1})
    local hostRole=create(w,{heal=1})
    w.api.SetString('savegame.mod.osp.players.host.role',hostRole.id)
    local restored=make({identities=w.identities})
    denied(restored,'role_save',0,{id=hostRole.id,name='Changed host',version=1,permissions={}},'protected')
    denied(restored,'role_delete',0,{id=hostRole.id,version=1},'protected')
    eq(entry(restored,11).role,hostRole.id)
end
-- Creation, editing and deletion each need their own capability.
do
    local w=fresh();grant(w,{role_create=2,heal=1})
    local ok,_,details=save(w,23,{heal=1})
    eq(ok,true,'creation can be delegated alone');local role=details.template
    local count=#w.api.shared.osp.templates
    local bad={id='',name='Too much',version=0,permissions={heal=2}}
    denied(w,'role_save',0,bad)
    bad.permissions={role_assign=2};denied(w,'role_save',0,bad)
    eq(#w.api.shared.osp.templates,count,'denied creation has no partial template')
    denied(w,'role_save',0,{id=role.id,name='No editing',version=1,permissions={heal=1}})
    denied(w,'role_delete',0,{id=role.id,version=1})
end
do
    local w=fresh();local own=grant(w,{role_edit=2,heal=1})
    local weak=create(w,{heal=1});w.command(11,'role_assign',47,{id=weak.id})
    local strong=create(w,{heal=2})
    denied(w,'role_save',0,{id=strong.id,name='Cannot demote stronger',version=1,permissions={}})
    denied(w,'role_save',0,{id=own.id,name='No self promotion',version=1,permissions={role_edit=2,heal=2}})
    eq(entry(w,23).permissions.heal,1)
    local ok,_,details=save(w,23,{heal=0},weak.id,1,'Reduced')
    eq(ok,true,'editing can be delegated alone');eq(details.template.version,2)
    eq(entry(w,47).permissions.heal,0,'template edit updates assigned players')
    denied(w,'role_save',0,{id=weak.id,name='Stale',version=1,permissions={}},'conflict')
    denied(w,'role_delete',0,{id=weak.id,version=2})
    denied(w,'role_save',0,{id='',name='No creation',version=0,permissions={}})
    -- A reduction of the actor's own grants is safe and applies immediately.
    eq(save(w,23,{heal=1},own.id,1,'Reduced own access'),true)
    denied(w,'role_save',0,{id=own.id,name='Cannot restore edit',version=2,permissions={role_edit=2,heal=1}})
end
do
    local w,make=fresh();grant(w,{role_delete=2,heal=1})
    local weak=create(w,{heal=1});local strong=create(w,{heal=2})
    w.command(11,'role_assign',47,{id=weak.id})
    local id=w.identities[47]
    w.players[47]=nil;w.removed={47};w.tick()
    denied(w,'role_delete',0,{id=strong.id,version=1})
    eq(w.command(23,'role_delete',0,{id=weak.id,version=1}),true,'delete does not require create or edit')
    eq(w.api.GetString('savegame.mod.osp.players.'..id..'.role'),'guest','offline assignment is revoked')
    local nextMap=make({identities=w.identities})
    eq(entry(nextMap,47).role,'guest','offline revocation survives reconnection')
end

-- Global policy aliases share a single explicit capability and persist.
do
    local w,make=fresh();grant(w,{tool_policy=2})
    eq(w.command(23,'tool_policy',0,{id='gun',mode='disabled'}),true)
    eq(w.players[11].tools.gun,false,'global policies include the host')
    eq(w.command(23,'tool_policy_bulk',0,{category='all',mode='enabled'}),true)
    eq(w.players[47].tools.gun,true)
    eq(w.command(23,'tool_policy_selection',0,{category='all',ids={'gun'},mode='disabled'}),true)
    local nextMap=make({identities=w.identities})
    eq(nextMap.players[47].tools.gun,false,'delegated global rule survives a new map')
    denied(w,'restart',0)
    denied(w,'reset_player',47)
end

-- Player reset requires a ready identity and cannot remove stronger roles.
do
    local w=fresh();grant(w,{reset_player=2,heal=1})
    w.command(11,'speed',47,2.5)
    denied(w,'reset_player',11,nil,'protected')
    eq(w.command(23,'reset_player',47),true);eq(entry(w,47).speed,1)
    local stronger=create(w,{heal=2});w.command(11,'role_assign',47,{id=stronger.id})
    denied(w,'reset_player',47)
    eq(entry(w,47).role,stronger.id,'reset cannot strip stronger access')
    local native=w.players[47];w.players[47]=nil;w.removed={47};w.tick()
    w.players[47]=native;w.tick()
    eq(entry(w,47).profileReady,false)
    w.api.server.ospCommand(23,'reset_player',47,nil,91,w.context(47))
    eq(w.calls[#w.calls].args[1],false);eq(w.calls[#w.calls].args[2],'unavailable','unidentified reset never constructs a nil profile path')
end
do
    local w=fresh();grant(w,{reset_player=1})
    denied(w,'reset_player',47)
    eq(w.command(23,'reset_player',23),true,'self reset scope is honored')
    eq(entry(w,23).role,'guest','reset clears own saved role')
end

-- Restart is independent, and revocation is evaluated at execution time.
do
    local w=fresh();local own=grant(w,{restart=2})
    eq(w.command(23,'restart',0),true);eq(w.restarted,true)
    w.restarted=false
    eq(save(w,11,{},own.id,1,'Revoked'),true)
    denied(w,'restart',0);eq(w.restarted,false,'revoked command has no side effects')
end
print('PASS delegated administration and authority ceilings: '..assertions..' assertions')
