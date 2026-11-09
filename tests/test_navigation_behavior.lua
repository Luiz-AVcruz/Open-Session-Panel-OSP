-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
local count=0
local function check(v,m) assert(v,m);count=count+1 end
local function eq(a,b,m) check(a==b,(m or 'equality')..': '..tostring(a)..' ~= '..tostring(b)) end
local f=assert(loadfile('tests/test_client.lua'))
setfenv(f,setmetatable({arg={arg[1],'fixture'}},{__index=_G}))
local world=f()
local function other(w,area)
    local e=w.api;e.OSP.UI.selectTab('players');w:clickControl('player_11');e.OSP.UI.selectTab(area)
    if area=='players' then w:clickControl('player_23')
    elseif area=='tools' then w:clickControl('tool_mode_player');w:clickControl('tool_player_next')
    else w:clickControl('role_target_next') end
    eq(w:draw().selected,23,'other player selected in '..area)
end
for _,size in ipairs({{640,480},{1024,768},{1920,1080}}) do
 for _,lang in ipairs({'en','pt'}) do
  for _,mode in ipairs({'keep','close','leave'}) do
   for _,area in ipairs({'players','tools','permissions'}) do
    local w=world(size[1],size[2],{});local e=w.api
    w.reg['savegame.mod.osp.language']=lang;e.OSP.Navigation.setSelectionMode(mode);e.OSP.UI.open(true)
    other(w,area);w:tick();w:draw();eq(w:draw().selected,23,'redraw does not reset selection')
    if area=='players' then w:clickControl('fly_settings');w:clickControl('movement_popup_close')
    elseif area=='tools' then w:clickControl('tools_actions');w:clickControl('tools_popup_close')
    else w:clickControl('permission_view_expand');w:clickControl('permission_view_close') end
    eq(w:draw().selected,23,'closing an inner window does not reset selection')
    w:clickControl('tab_session');eq(w:draw().selected,mode=='leave' and 11 or 23,'tab-change policy')
    for _,how in ipairs({'button','key','api','esc'}) do
        other(w,area)
        if how=='button' then w:clickControl('close') elseif how=='key' then w:tick('p')
        elseif how=='esc' then w:tick('esc') else e.OSP.UI.open(false) end
        local st=w:draw();eq(st.open,false,'outer panel closes via '..how)
        eq(st.selected,mode=='keep' and 23 or 11,'close policy via '..how)
        if how=='api' then e.OSP.UI.open(true) else w:tick('p') end
        st=w:draw();eq(st.tab,area,'last tab restored');eq(st.selected,mode=='keep' and 23 or 11,'selection on reopen')
    end
    eq(#w.sent,0,'navigation has no gameplay RPC')
   end
  end
  -- Exercise the actual local Settings controls and persistence.
  local w=world(size[1],size[2],{});local e=w.api;w.reg['savegame.mod.osp.language']=lang
  e.OSP.UI.open(true);w:clickControl('tab_settings')
  check(not e.OSP.SettingsSections.expanded('behavior'),'behavior section starts collapsed')
  w:clickControl('settings_section_behavior')
  for _,mode in ipairs({'keep','close','leave'}) do
    local id='behavior_selection_'..mode
    local r=w:scrollTo(id);local l=w:draw().layout
    for _=1,10 do
        if r.y>=l.oy+l.contentY and r.y+r.h<=l.oy+l.contentY+l.contentH then break end
        w.mouse={x=l.ox+l.contentX+5,y=l.oy+l.contentY+l.contentH/2}
        w:tick(nil,r.y<l.oy+l.contentY and 1 or -1);local st=w:draw();l=st.layout;r=st.controls[id]
    end
    check(r.y>=l.oy+l.contentY and r.y+r.h<=l.oy+l.contentY+l.contentH,'selection choice fits viewport')
    w:clickControl('behavior_selection_'..mode);eq(e.OSP.Navigation.selectionMode(),mode)
  end
  w:clickControl('behavior_opening_players');eq(e.OSP.Navigation.openingMode(),'players')
  e.OSP.UI.open(false);e.OSP.UI.open(true);eq(w:draw().tab,'players','fixed opening tab')
  w:clickControl('tab_settings');w:clickControl('behavior_opening_last');w:clickControl('tab_tools')
  local nextMap=world(size[1],size[2],w.reg);nextMap.api.OSP.UI.open(true)
  eq(nextMap:draw().tab,'tools','last tab survives a fresh context');eq(nextMap:draw().selected,11,'player selection does not cross maps')
  eq(nextMap.api.OSP.Navigation.selectionMode(),'leave','selection preference persists')
  eq(#w.sent,0,'settings only write local preferences')
 end
end
-- Pause-menu opening and inaccessible remembered tabs use the same lifecycle.
do
 local w=world(1024,768,{});local e=w.api
 e.OSP.Navigation.setOpeningMode('players');e.OSP.UI.open(true);w:clickControl('tab_tools');e.OSP.UI.open(false)
 e.PauseMenuButton=function() return true end;w:tick();e.PauseMenuButton=function() return false end
 eq(w:draw().open,true);eq(w:draw().tab,'players','pause button honors opening preference')
 e.OSP.UI.open(false);e.OSP.Navigation.setVisible('players',false);e.OSP.UI.open(true)
 eq(w:draw().tab,'session','hidden fixed tab uses existing visible fallback')
 e.OSP.UI.open(false);e.OSP.Navigation.setOpeningMode('last');e.OSP.Navigation.rememberTab('permissions')
 e.IsPlayerHost=function() return false end;e.shared.osp.players[1].host=false;e.shared.osp.players[1].admin=false
 e.OSP.UI.open(true);eq(w:draw().tab,'appearance','inaccessible remembered tab does not grant access')
 w:clickControl('tab_settings');w:clickControl('settings_section_behavior');w:clickControl('behavior_selection_close')
 eq(e.OSP.Navigation.selectionMode(),'close','guests can configure their own navigation');eq(#w.sent,0)
end
do
 local w=world(1024,768,{});local e=w.api
 e.OSP.ViewMode.set('single');e.OSP.Navigation.rememberTab('permissions');e.OSP.UI.open(true)
 eq(w:draw().tab,'players','solo mode filters the remembered multiplayer-only tab')
end
-- Explicit target navigation, draft preservation and pending RPCs remain safe.
do
 local w=world(1920,1080);local e=w.api;e.OSP.Navigation.setSelectionMode('leave');e.OSP.UI.open(true)
 other(w,'players');w:clickControl('player_role_manage')
 eq(w:draw().tab,'permissions');eq(w:draw().selected,23,'Manage Role preserves its explicit target')
 w:clickControl('role_create_custom');local draft=e.OSP.PermissionUI.getState().draft
 w:clickControl('permission_view_close');eq(w:draw().selected,23)
 w:clickControl('tab_session');eq(w:draw().selected,11)
 eq(e.OSP.PermissionUI.getState().draft.name,draft.name,'role draft survives navigation reset')
 other(w,'players');w:clickControl('player_action_god');local request=w.sent[#w.sent]
 eq(request.args[3],23);check(w:draw().requestPending)
 w:clickControl('close');eq(w:draw().selected,11);eq(request.args[3],23,'closing cannot retarget the sent command')
 w:ack();check(not w:draw().requestPending,'reply still completes after closing')
end
-- Unsent text and confirmation are discarded on actual context changes.
for _,action in ipairs({'close','tab_session','player_11'}) do
 local w=world(1024,768);local e=w.api;e.OSP.Navigation.setSelectionMode('close');e.OSP.UI.open(true)
 other(w,'players');w:editControl('player_speed_value');w:tick('2');w:tick('.')
 w:clickControl(action);eq(#w.sent,0,'context change cancels numeric draft: '..action)
 check(not e.OSP.NumberInput.active())
end
do
 local w=world(1024,768);local e=w.api;e.OSP.UI.open(true);other(w,'players');w:clickControl('player_action_kill')
 check(w:draw().confirm~=nil);e.OSP.UI.open(false);eq(w:draw().confirm,nil);eq(#w.sent,0)
end
-- A recycled player ID or changed host namespace cannot keep an old selection
-- or turn a click meant for a popup into a command on its replacement.
for _,change in ipairs({'removed','reused','host'}) do
 local w=world(1024,768);local e=w.api;e.OSP.UI.open(true);other(w,'players');w:clickControl('fly_settings')
 local r=w:draw().controls.fly_speed_value
 if change=='removed' then table.remove(e.shared.osp.players,2)
 elseif change=='reused' then e.shared.osp.players[2].profileChallenge=99
 else e.shared.osp.profileHost=string.rep('b',32) end
 w:pressAt(r.x+r.w/2,r.y+r.h/2);local st=w:draw()
 eq(st.selected,11,'invalid selection falls back to self: '..change);eq(st.movementPopup,nil)
 eq(#w.sent,0,'stale popup input cannot mutate a replacement target');check(not e.OSP.NumberInput.active())
end
print('PASS navigation behavior and selected-player lifecycle: '..count..' assertions (mock UI)')
