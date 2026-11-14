-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
local count=0
local function check(value,message) assert(value,message);count=count+1 end
local function eq(a,b,message) check(a==b,(message or 'equality')..': '..tostring(a)..' ~= '..tostring(b)) end
local chunk=assert(loadfile('tests/test_client.lua'))
setfenv(chunk,setmetatable({arg={arg[1],'fixture'}},{__index=_G}))
local world=chunk()
local root='savegame.mod.osp_beta.'
for _,language in ipairs({'en','pt'}) do
    for _,size in ipairs({{640,480},{1920,1080}}) do
        local reg={[root..'language']=language,
            [root..'identity.test']='keep-identity',[root..'players.host.role']='keep-role',
            [root..'rules.rain']=.5,[root..'tools.67756e']=2,[root..'theme.mode']='ocean',
            [root..'compatibility.seen.67756e']='1',[root..'compatibility.seen.absent']='1',
            ['savegame.mod.osp.compatibility.seen.67756e']='1'}
        local w=world(size[1],size[2],reg);local e=w.api
        e.ClearKey=function(key)
            eq(key,root..'compatibility.seen','reset is restricted to local first-time notices')
            for k in pairs(reg) do if k==key or k:sub(1,#key+1)==key..'.' then reg[k]=nil end end
        end
        w:tick('p');local st=w:draw()
        eq(st.controls.tab_debug,nil,'Debug is absent by default')
        e.OSP.UI.selectTab('debug');check(e.OSP.UI.getState().tab~='debug','hidden Debug cannot be opened indirectly')
        w:clickControl('tab_settings');w:clickControl('settings_section_navigation')
        w:clickControl('navigation_debug');w:clickControl('tab_debug')
        st=w:draw();eq(st.tab,'debug','enabled through existing tab settings')
        check(st.controls.debug_reset_first_entry,'first option is reset first entry')
        w:clickControl('debug_preview_notice');st=w:draw()
        check(st.confirm and st.confirm.info and st.confirm.sample,'preview opens the inert sample notice renderer')
        eq(st.confirm.toolName,e.OSP.L('debug_sample_tool'),'preview is clearly a sample')
        eq(st.controls.compatibility_choice_suspend,nil,'sample has no real-tool choice')
        eq(st.controls.compatibility_choice_attempt,nil,'sample cannot send a compatibility mode')
        eq(reg[root..'compatibility.seen.67756e'],'1','preview leaves seen notices alone')
        w:clickControl('compatibility_notice_close')
        w:clickControl('debug_reset_first_entry')
        eq(reg[root..'compatibility.seen.67756e'],nil,'reset clears present tool notices')
        eq(reg[root..'compatibility.seen.absent'],nil,'reset clears notices for absent tools')
        eq(reg[root..'identity.test'],'keep-identity');eq(reg[root..'players.host.role'],'keep-role')
        eq(reg[root..'rules.rain'],.5);eq(reg[root..'tools.67756e'],2);eq(reg[root..'theme.mode'],'ocean')
        eq(reg['savegame.mod.osp.compatibility.seen.67756e'],'1','stable notices are untouched')
        eq(#w.sent,0,'Debug sends no gameplay commands')
        e.shared.osp.players[1].toolConflicts={gun=true}
        w:clickControl('tab_tools');st=w:draw();check(st.confirm and st.confirm.info,'reset re-arms actual first encounter')
        w:clickControl('compatibility_notice_x');w:clickControl('tab_debug')
        -- Guests have access to these local actions, even in Singleplayer
        -- presentation. They gain no host permissions by enabling Debug.
        e.IsPlayerHost=function() return false end
        e.shared.osp.players[1].admin=false;e.shared.osp.players[1].host=false
        e.shared.osp.players[1].permissions={};e.OSP.ViewMode.set('single');w:tick()
        eq(w:draw().tab,'debug','local Debug remains available without administration rights')
        e.shared.osp.ready=false
        st=w:draw();check(st.controls.debug_preview_notice,'Debug works while OSP server is not ready')
        check(table.concat(w.texts,'|'):find(e.OSP.L('debug_server',e.OSP.L('debug_waiting')),1,true),'diagnostic reports unready server')
        local current=e.shared.osp;e.shared.osp=nil
        check(w:draw().controls.debug_preview_notice,'local Debug survives missing shared server state')
        e.shared.osp=current
        e.shared.osp.ready=true
        w:clickControl('debug_hide');st=w:draw()
        eq(st.tab,'settings','disabling Debug returns to Settings')
        eq(st.controls.tab_debug,nil,'disabling removes tab immediately')
        eq(#w.sent,0,'guest Debug also sends no gameplay commands')
        local again=world(size[1],size[2],reg)
        again:tick('p');eq(again:draw().controls.tab_debug,nil,'disabled state persists across client restart')
        e.OSP.Navigation.setVisible('debug',true)
        again=world(size[1],size[2],reg);again:tick('p')
        check(again:draw().controls.tab_debug,'explicit opt-in persists across client restart')
    end
end
print('PASS opt-in Debug, notices, diagnostics and local data boundaries: '..count..' assertions')
