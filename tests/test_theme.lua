-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
local count=0
local function check(value,message) assert(value,message);count=count+1 end
local registry={['savegame.mod.osp.language']='pt',['savegame.mod.osp.health_hud']=true}
local function loadTheme()
    local env=setmetatable({GetString=function(k) return registry[k] or '' end}, {__index=_G})
    env.SetString=function(k,v)
        check(k:sub(1,23)=='savegame.mod.osp.theme.','theme writes outside own preferences')
        registry[k]=v
    end
    local chunk=assert(loadfile(arg[1]));setfenv(chunk,env);chunk()
    return env.OSP.Theme,env.OSP.NumberInput
end
local t,N=loadTheme()
check(t.mode()=='classic','default stays unchanged')
check(t.hex(t.colors().accent)=='F5C75E','classic accent')
for _,id in ipairs(t.presets) do
    if id~='custom' then
        check(t.select(id),'select preset')
        local c=t.colors()
        check(t.contrast(c.text,c.back)>=4.5,'readable preset background '..id)
        check(t.contrast(c.text,c.surface)>=4.5,'readable preset buttons '..id)
    end
end
check(not t.select('unknown'),'reject invalid preset')
registry['savegame.mod.osp.theme.mode']='invalid'
check(t.mode()=='classic','invalid stored preset falls back')
check(not t.setColor('players.p1.admin',{1,0,0}),'reject foreign role')
for _,value in ipairs({-1,2,math.huge,0/0}) do check(not t.setColor('text',{value,0,0}),'reject invalid RGB') end
check(not t.setColor('text',{}),'reject incomplete RGB')
t.select('custom');check(t.setColor('accent',{1,0,.5}),'save color')
check(t.hex(t.colors().accent)=='FF0080','RGB quantized to exact hex')
t.select('ocean');t.select('custom')
check(t.hex(t.colors().accent)=='FF0080','custom survives preset switch')
local another=loadTheme();check(another.mode()=='custom','mode survives new Lua context')
check(another.hex(another.colors().accent)=='FF0080','color survives new map')
registry['savegame.mod.osp.theme.custom.text']='GGGGGG'
check(t.hex(t.colors().text)=='F2F0E8','malformed stored color falls back')
check(math.abs(t.contrast({0,0,0},{1,1,1})-21)<.001,'contrast endpoints')
local click,held,mx,my,visible=nil,false,0,0,true
local numberClick,numberValue=nil,nil
local sawRecovery=false
local api={label=function() end,rect=function() end,
    button=function(id,x,y,w,h,value,kind)
        if id=='palette_restore' then sawRecovery=kind=='recovery' end
        return id==click
    end,
    mouse=function() return mx,my end,visible=function() return visible end,
    pressed=function() return click=='slider' end,down=function() return held end,consume=function() end}
api.number=function(id,x,y,w,h,value,minimum,maximum,decimals,onCommit)
    if numberClick==id then
        check(minimum==0 and maximum==255 and decimals==0,'RGB field contract')
        numberClick=nil;onCommit(numberValue)
    end
end
click='palette_R_plus';t.draw(api,0,0,700)
check(t.hex(t.colors().back):sub(1,2)=='14','single-step RGB adjustment')
click=nil
local old=t.colors().back
numberClick='palette_G_value';numberValue=128;t.draw(api,0,0,700)
local changed=t.colors().back
check(math.floor(changed[2]*255+.5)==128,'numeric callback writes the selected channel')
check(changed[1]==old[1] and changed[3]==old[3],'numeric channel edit preserves the other two channels')
numberClick=nil
click='slider';held=true;mx,my=604,190;t.draw(api,0,0,700)
click=nil;mx=605;t.draw(api,0,0,700)
check(t.colors().back[1]==1,'drag selects maximum RGB')
click=nil;mx=85;t.draw(api,0,0,700)
check(t.colors().back[1]==0,'held drag selects minimum')
visible=false;mx=605;t.draw(api,0,0,700)
check(t.colors().back[1]==0,'clipped viewport blocks edits')
held=false;visible=true;t.draw(api,0,0,700)
held=true;mx=605;t.draw(api,0,0,700)
check(t.colors().back[1]==0,'release ends drag; no stale activation')
click='palette_restore';held=false;t.draw(api,0,0,700)
check(t.mode()=='classic' and sawRecovery,'fixed-contrast recovery')
check(registry['savegame.mod.osp.theme.custom.accent']=='FF0080','restore keeps custom work')
check(registry['savegame.mod.osp.language']=='pt' and registry['savegame.mod.osp.health_hud']==true,'other preferences preserved')
N.begin('player_speed_value',1,.5,3,2,function() end)
t.cancelDrag()
check(N.active('player_speed_value'),'theme drag cancellation preserves gameplay number capture')
N.begin('palette_R_value',10,0,255,0,function() end)
t.cancelDrag()
check(not N.active(),'theme drag cancellation ends RGB number capture')
N.begin('player_speed_value',1,.5,3,2,function() end)
t.select('ocean')
check(N.active('player_speed_value'),'changing the palette preset preserves a gameplay number field')
N.begin('palette_B_value',10,0,255,0,function() end)
t.select('custom')
check(not N.active(),'changing the palette preset cancels an RGB number field')
print('PASS palette persistence, validation and RGB editor: '..count..' assertions')
