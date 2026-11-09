-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Exercise real client payloads against the real server, with simulated UI.
local count=0
local function check(v,m) assert(v,m);count=count+1 end
local function eq(a,b,m) check(a==b,(m or 'equality')..': '..tostring(a)..' ~= '..tostring(b)) end
local function fixture(path)
    local f=assert(loadfile(path));setfenv(f,setmetatable({arg={arg[1],'fixture'}},{__index=_G}));return f()
end
local makeClient=fixture('tests/test_client.lua')
local function connect(width,height)
    local s=fixture('tests/test_server.lua')();local c=makeClient(width,height,{})
    c.api.IsMultiplayer=function() return true end -- The engine reports session type, even when only the host remains.
    local function sync() c.api.shared.osp=c.api.OSP.copy(s.api.shared.osp) end
    sync();c:tick();c:draw()
    local function deliver()
        local request=c.sent[#c.sent];check(request~=nil,'UI emits a request')
        eq(request.fn,'server.ospCommand')
        s.now=s.now+.1;s.api.server.ospCommand(unpack(request.args))
        local reply=s.calls[#s.calls];eq(reply.fn,'client.ospResult')
        sync();c.api.client.ospResult(unpack(reply.args));c:draw()
        check(not c.api.OSP.UI.getState().requestPending,'matching server ACK completes client request')
        return reply.args[1],reply.args[2],reply.args[3]
    end
    return s,c,deliver,sync
end
local function choose(c,id,value)
    c:clickControl(id);c:clickControl(id..'_option_'..value)
end
for _,size in ipairs({{640,480},{1024,768},{1920,1080}}) do
    local s,c,deliver,sync=connect(unpack(size))
    c:tick('p');choose(c,'group_scope','all')
    c:clickControl('group_god')
    local ok,code,d=deliver();eq(ok,true,code);eq(d.affected,3)
    for _,p in ipairs(s.api.shared.osp.players) do eq(p.god,true,'client selection reaches every eligible server target') end
    c:clickControl('group_exclude_self');c:clickControl('group_god')
    ok,code,d=deliver();eq(ok,true,code);eq(d.affected,2)
    eq(s.api.shared.osp.players[1].god,true,'exclude-self survives client serialization')
    eq(s.api.shared.osp.players[2].god,false,'clicking On sends an explicit false value')
    eq(s.api.shared.osp.players[3].god,false,'all other selected peers are disabled')
    -- Create a mixed group, then exercise the frozen popup request.
    eq(s.command(11,'god',23,true),true);sync();c:draw()
    c:clickControl('group_god');check(c:draw().controls.group_popup_off~=nil,'mixed group opens explicit choices')
    c:clickControl('group_popup_off');ok,code,d=deliver();eq(ok,true,code);eq(d.affected,2)
    -- Manual selection sends exactly the checked player and never creates a rule.
    choose(c,'group_scope','manual');c:clickControl('group_manual_23');c:clickControl('group_ammo')
    ok,code,d=deliver();eq(ok,true,code);eq(d.affected,1)
    for _,p in ipairs(s.api.shared.osp.players) do eq(p.ammo,p.id==23,'manual client payload stays limited to checked target') end
    c:clickControl('tab_permissions');c:chooseRole('self')
    c:clickControl('permission_view_mark_all')
    eq(c.api.OSP.PermissionUI.getState().batchSelected,2,'Mark all captures both non-host targets')
    local before=#c.sent
    c:clickControl('permission_view_batch_apply')
    eq(#c.sent,before,'unified assignment waits for confirmation')
    local snapshot=c.api.OSP.UI.getState().confirm.arg
    eq(c.api.OSP.UI.getState().confirm.action,'roles_assign_many','confirmation uses the batch RPC for multiple targets')
    eq(snapshot.role,'self','confirmation freezes the destination Role')
    eq(#snapshot.targets,2,'confirmation freezes both eligible players')
    c:clickControl('confirm_accept');ok,code,d=deliver();eq(ok,true,code);eq(d.affected,2)
    for _,p in ipairs(s.api.shared.osp.players) do
        if not p.host then eq(p.role,'self','checked players receive the chosen Role') end
    end
    c:clickControl('tab_players')
    eq(c.api.OSP.PermissionUI.getState().batchSelected,0,'leaving Permissions clears batch targets immediately')
    eq(c.api.OSP.PermissionUI.getState().batchMode,nil,'unified state has no hidden mode on Players')
end

-- A one-person lobby has no target but still permits role management.
do
    local s,c,deliver,sync=connect(1024,768)
    s.players[23]=nil;s.players[47]=nil;s.tick();sync()
    eq(#c.api.shared.osp.players,1,'one-person integration fixture contains only the host')
    c:tick('p')
    c:clickControl('tab_permissions');c:chooseRole('self')
    local st=c:draw()
    eq(st.controls.permission_view_target_11,nil,'host does not appear in the assignment list')
    check(st.controls.permission_view_batch_apply.disabled,'host-only Apply stays disabled')
    check(table.concat(c.texts,'|'):find(c.api.OSP.L('role_targets_none'),1,true)~=nil,'host-only lobby displays its empty state')
    c:clickControl('permission_view_expand')
    check(c.api.OSP.PermissionUI.isExpanded(),'role management opens in a host-only lobby')
    eq(#c.sent,0,'empty-state and management actions send no assignment')
end

-- In a two-person lobby, Mark all still assigns the sole peer through the same RPC and ACK path.
do
    local s,c,deliver,sync=connect(1024,768)
    s.players[47]=nil;s.tick();sync()
    eq(#c.api.shared.osp.players,2,'two-person integration fixture contains host and one peer')
    c:tick('p')
    c:clickControl('tab_permissions');c:chooseRole('self')
    c:clickControl('permission_view_mark_all')
    eq(c.api.OSP.PermissionUI.getState().batchSelected,1,'Mark all selects the only eligible peer')
    local before=#c.sent
    c:clickControl('permission_view_batch_apply')
    eq(#c.sent,before,'single peer waits for confirmation')
    local snapshot=c.api.OSP.UI.getState().confirm.arg
    eq(c.api.OSP.UI.getState().confirm.action,'roles_assign_many','one peer still uses the collective RPC')
    eq(#snapshot.targets,1,'one-peer confirmation contains one target')
    eq(snapshot.targets[1].id,23,'one-peer confirmation targets the non-host player')
    c:clickControl('confirm_accept')
    local ok,code,d=deliver();eq(ok,true,code);eq(d.affected,1)
    eq(s.api.shared.osp.players[2].role,'self','server applies the one-target assignment')
    eq(s.api.GetString('savegame.mod.osp.players.'..s.identities[23]..'.role'),'self','server persists the one-target assignment')
end

-- A departed navigation selection cannot invalidate a different, independently checked target.
do
    local s,c,deliver,sync=connect(1024,768)
    c:tick('p')
    c:clickControl('player_23');eq(c.api.OSP.UI.getState().selected,23,'Players selects the navigation target')
    c:clickControl('tab_permissions');c:chooseRole('self');c:clickControl('permission_view_target_47')
    eq(c.api.OSP.PermissionUI.getState().batchSelected,1,'Permissions marks player 47 independently')
    c:clickControl('permission_view_batch_apply')
    local snapshot=c.api.OSP.UI.getState().confirm.arg
    eq(snapshot.targets[1].id,47,'confirmation snapshots the checked player')
    s.players[23]=nil;s.tick();sync()
    c.api.IsPlayerValid=function(id) return id==11 or id==47 end
    c:tick();local st=c:draw()
    eq(st.confirm.action,'roles_assign_many','leaving navigation target does not cancel unrelated confirmation')
    eq(st.confirm.arg.targets[1].id,47,'confirmation remains bound to the checked target')
    c:clickControl('confirm_accept')
    eq(c.sent[#c.sent].args[3],0,'batch request uses target zero after navigation target departure')
    local ok,code,d=deliver();eq(ok,true,code);eq(d.affected,1)
    local target;for _,p in ipairs(s.api.shared.osp.players) do if p.id==47 then target=p end end
    eq(target.role,'self','server validates the frozen target join and accepts the current player')
end
print('PASS client/server group payloads and correlated results: '..count..' assertions (mock UI)')
