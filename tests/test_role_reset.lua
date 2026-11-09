-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
local count=0
local function check(v,m) assert(v,m);count=count+1 end
local function eq(a,b,m) check(a==b,(m or 'equality')..': '..tostring(a)..' ~= '..tostring(b)) end
local function fresh()
    local chunk=assert(loadfile('tests/test_server.lua'))
    setfenv(chunk,setmetatable({arg={arg[1],'fixture'}},{__index=_G}))
    local make=chunk();return make(),make
end
local function role(w,id)
    for _,r in ipairs(w.api.shared.osp.templates) do if r.id==id then return r end end
end
local function player(w,id)
    for _,p in ipairs(w.api.shared.osp.players) do if p.id==id then return p end end
end
local function save(w,id,name,version,permissions,actor,initial)
    return w.command(actor or 11,'role_save',0,{id=id,name=name,version=version,permissions=permissions,initial=initial})
end
local function reset(w,r,actor) return w.command(actor or 11,'role_reset',0,{id=r.id,version=r.version}) end
local function create(w,name,permissions)
    local ok,code,d=save(w,'',name,0,permissions);eq(ok,true,code);return d.template
end
-- Presets are editable under stable IDs; reset revisions never move backwards.
do
    local w,make=fresh();local P=w.api.OSP.Permissions
    w.command(11,'role_assign',23,{id='self'})
    local ok,code,d=save(w,'self','Personal',0,{heal=1})
    eq(ok,true,code);eq(d.template.id,'self');eq(d.template.version,1);check(d.template.builtin)
    eq(player(w,23).role,'self');eq(player(w,23).permissions.kill,0,'preset edits update existing assignments')
    eq(d.template.initial.permissions.kill,1,'preset reset keeps its canonical baseline')
    eq(P.default('self').permissions.kill,1,'an override cannot mutate canonical defaults')
    local cloned=P.default('self');cloned.permissions.kill=0;eq(P.default('self').permissions.kill,1,'defaults are copied')
    local nextMap=make({identities=w.identities})
    eq(role(nextMap,'self').name,'Personal');eq(player(nextMap,23).permissions.kill,0)
    ok,code,d=reset(nextMap,role(nextMap,'self'));eq(ok,true,code)
    eq(d.template.version,2);eq(d.template.nameKey,'role_self');eq(d.template.permissions.kill,1)
    eq(player(nextMap,23).role,'self');eq(player(nextMap,23).permissions.kill,1)
    for _,version in ipairs({0,1}) do
        ok,code=save(nextMap,'self','Stale',version,{});eq(ok,false);eq(code,'conflict')
    end
    local after=make({identities=w.identities})
    eq(role(after,'self').version,2,'reset revision survives reload')
    eq(role(after,'self').nameKey,'role_self','reset restores translated default name')
    local found=0;for _,r in ipairs(after.api.shared.osp.templates) do if r.id=='self' then found=found+1 end end
    eq(found,1,'an edited preset appears only once')
    ok,code=after.command(11,'role_delete',0,{id='self',version=2});eq(ok,false);eq(code,'invalid','presets cannot be deleted')
end
-- Administrator defaults include all capabilities, and edited access remains authoritative.
do
    local w=fresh();local P=w.api.OSP.Permissions
    for _,s in ipairs(P.spec) do eq(P.default('admin').permissions[s.id],2,'complete Administrator: '..s.id) end
    w.command(11,'role_assign',23,{id='admin'})
    eq(save(w,'admin','Support',0,{heal=1}),true)
    eq(player(w,23).permissions.role_edit,0)
    local ok,code=reset(w,role(w,'admin'),23);eq(ok,false);eq(code,'denied','cannot restore revoked own authority')
    eq(reset(w,role(w,'admin')),true)
    eq(player(w,23).permissions.role_edit,2)
    eq(role(w,'admin').version,2)
end
-- The creation snapshot is server-owned and survives edits, reset and reconnection.
do
    local w,make=fresh();local base=create(w,'Original',{heal=1,tools=1})
    eq(base.initial.name,'Original');eq(base.initial.permissions.heal,1)
    w.command(11,'role_assign',47,{id=base.id})
    local ok,code,d=save(w,base.id,'Changed',1,{god=1},nil,{name='Forged',permissions={role_edit=2}})
    eq(ok,true,code);eq(d.template.initial.name,'Original');eq(d.template.initial.permissions.role_edit,0)
    eq(player(w,47).permissions.god,1)
    local native=w.players[47];w.players[47]=nil;w.removed={47};w.tick()
    eq(reset(w,role(w,base.id)),true)
    eq(role(w,base.id).name,'Original');eq(role(w,base.id).permissions.god,0)
    eq(role(w,base.id).permissions.heal,1);eq(role(w,base.id).version,3)
    local again=make({identities=w.identities})
    eq(player(again,47).role,base.id);eq(player(again,47).permissions.heal,1)
    eq(role(again,base.id).initial.name,'Original')
    local stale,why=again.command(11,'role_reset',0,{id=base.id,version=2})
    eq(stale,false);eq(why,'conflict');eq(role(again,base.id).version,3)
end
-- Legacy custom roles get a single stable baseline before the first new edit.
do
    local w,make=fresh();local path='savegame.mod.osp_beta.templates.c91.'
    w.api.SetString(path..'name','Legacy');w.api.SetInt(path..'version',5)
    w.api.SetInt(path..'permissions.heal',1)
    local migrated=make({identities=w.identities})
    eq(role(migrated,'c91').initial.name,'Legacy')
    eq(migrated.api.GetBool(path..'initial.exists'),true)
    eq(save(migrated,'c91','Edited legacy',5,{kill=1}),true)
    local reloaded=make({identities=w.identities})
    eq(role(reloaded,'c91').initial.name,'Legacy')
    eq(role(reloaded,'c91').initial.permissions.heal,1)
    eq(reset(reloaded,role(reloaded,'c91')),true)
    eq(role(reloaded,'c91').name,'Legacy');eq(role(reloaded,'c91').permissions.heal,1)
    eq(role(reloaded,'c91').permissions.kill,0)
end
-- Invalid creation-history data must not silently overwrite a recoverable role.
do
    local w,make=fresh();local r=create(w,'Recoverable',{heal=1})
    local path='savegame.mod.osp_beta.templates.'..r.id..'.initial.'
    w.api.SetString(path..'name',' padded')
    local loaded=make({identities=w.identities});eq(role(loaded,r.id).initial,nil)
    local ok,code=reset(loaded,role(loaded,r.id));eq(ok,false);eq(code,'unavailable')
    eq(save(loaded,r.id,'Still editable',1,{heal=2}),true)
    local again=make({identities=w.identities})
    eq(role(again,r.id).name,'Still editable');eq(role(again,r.id).initial,nil)
end
-- Reset uses the edit capability and checks both present and baseline authority.
do
    local w=fresh()
    local actor=create(w,'Limited editor',{role_edit=2,heal=1})
    w.command(11,'role_assign',23,{id=actor.id})
    local strongerBase=create(w,'Stronger baseline',{heal=2})
    eq(save(w,strongerBase.id,'Reduced target',1,{heal=1}),true)
    local ok,code=reset(w,role(w,strongerBase.id),23)
    eq(ok,false);eq(code,'denied','baseline cannot exceed the delegate')
    eq(role(w,strongerBase.id).version,2)
    local weak=create(w,'Weak baseline',{heal=1})
    eq(save(w,weak.id,'Stronger current',1,{heal=2}),true)
    ok,code=reset(w,role(w,weak.id),23);eq(ok,false);eq(code,'denied','current role must also fit the delegate')
    eq(save(w,actor.id,'Own reduced',1,{role_edit=2}),true)
    ok,code=reset(w,role(w,actor.id),23);eq(ok,false);eq(code,'denied','cannot gain own lost grant through reset')
    local onlyDelete=create(w,'Delete only',{role_delete=2,heal=2});w.command(11,'role_assign',23,{id=onlyDelete.id})
    ok,code=reset(w,role(w,weak.id),23);eq(ok,false);eq(code,'denied','delete authority does not include reset')
end
-- Deletion and player reset fall back to the editable Guest role, so that
-- resulting role must also fit the caller's ceiling.
do
    local w=fresh();eq(save(w,'guest','Powerful Guest',0,{restart=2}),true)
    for _,action in ipairs({'role_delete','reset_player'}) do
        local grants=action=='role_delete' and {role_delete=2,heal=1} or {reset_player=1,heal=1}
        local r=create(w,'Delegate '..action,grants)
        eq(w.command(11,'role_assign',23,{id=r.id}),true)
        local ok,code
        if action=='role_delete' then ok,code=w.command(23,action,0,{id=r.id,version=r.version})
        else ok,code=w.command(23,action,23) end
        eq(ok,false);eq(code,'denied','Guest fallback cannot elevate a delegate')
        eq(player(w,23).role,r.id);eq(player(w,23).permissions.restart,0)
        eq(w.command(23,'restart',0),false)
        -- Reducing Guest makes the same operation safe and usable.
        local guest=role(w,'guest');eq(save(w,'guest','Limited Guest',guest.version,{}),true)
        if action=='role_delete' then ok=w.command(23,action,0,{id=r.id,version=r.version})
        else ok=w.command(23,action,23) end
        eq(ok,true);eq(player(w,23).role,'guest')
        guest=role(w,'guest');eq(save(w,'guest','Powerful Guest',guest.version,{restart=2}),true)
    end
end
-- Preset overrides and resets do not consume the custom-role limit.
do
    local w=fresh();eq(save(w,'self','Edited preset',0,{heal=1}),true)
    eq(reset(w,role(w,'self')),true)
    for n=1,16 do create(w,'Custom '..n,{}) end
    local ok,code=save(w,'','Overflow',0,{});eq(ok,false);eq(code,'template_limit')
end
print('PASS editable preset roles, creation history and reset: '..count..' assertions')
