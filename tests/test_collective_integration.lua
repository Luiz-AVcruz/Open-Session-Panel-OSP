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
    c:clickControl('permission_view_batch_mode')
    c:clickControl('permission_view_target_23');c:clickControl('permission_view_target_47')
    local before=#c.sent
    c:clickControl('permission_view_batch_apply')
    eq(#c.sent,before,'batch assignment waits for confirmation')
    c:clickControl('confirm_accept');ok,code,d=deliver();eq(ok,true,code);eq(d.affected,2)
    for _,p in ipairs(s.api.shared.osp.players) do
        if not p.host then eq(p.role,'self','checked players receive the chosen Role') end
    end
    c:clickControl('tab_players')
    eq(c.api.OSP.PermissionUI.getState().batchSelected,0,'leaving Permissions clears batch targets immediately')
    eq(c.api.OSP.PermissionUI.getState().batchMode,false,'Players does not inherit a hidden role batch')
end
print('PASS client/server group payloads and correlated results: '..count..' assertions (mock UI)')
