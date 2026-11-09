-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
local count=0
local function check(value,message) assert(value,message);count=count+1 end
local registry={['savegame.mod.osp.language']='pt',['savegame.mod.osp.health_hud']=true,
    ['savegame.mod.osp.theme.button_style']='outline'}
local function loadTheme()
    local env=setmetatable({GetString=function(k) return registry[k] or '' end}, {__index=_G})
    env.SetString=function(k,v)
        check(k:sub(1,#'savegame.mod.osp.theme.')=='savegame.mod.osp.theme.' or k:match('^savegame%.mod%.osp%.settings%.collapsed%.'),'theme writes outside own preferences')
        registry[k]=v
    end
    local chunk=assert(loadfile(arg[1]));setfenv(chunk,env);chunk()
    return env.OSP.Theme,env.OSP.NumberInput,env.OSP.SettingsSections
end
local t,N,Sections=loadTheme()
check(t.mode()=='classic','default stays unchanged')
check(t.hex(t.colors().accent)=='F5C75E','classic accent')
check(t.buttonStyle==nil and t.setButtonStyle==nil,'button style preference API is removed')
check(t.backgroundOpacity()==98,'background starts at existing opacity')
check(t.setBackgroundOpacity(65) and t.backgroundOpacity()==65,'set minimum background opacity')
check(t.setBackgroundOpacity(100) and t.backgroundOpacity()==100,'set maximum background opacity')
for _,value in ipairs({64,101,1.5,'80',math.huge}) do check(not t.setBackgroundOpacity(value),'reject invalid opacity') end
check(t.setBackgroundOpacity(98),'restore default opacity value')
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
check(t.setBackgroundOpacity(73),'custom opacity saved')
check(t.select('graphite'),'graphite preset added')
local graphite=t.colors()
check(t.hex(graphite.back)=='14181E' and t.hex(graphite.accent)=='75C5E8','graphite has its own OSP palette')
check(t.contrast(graphite.text,graphite.back)>=4.5 and t.contrast(graphite.text,graphite.surface)>=4.5,'graphite text contrast')
local reopened=loadTheme()
check(reopened.mode()=='graphite' and reopened.backgroundOpacity()==73,'appearance settings survive a new Lua context')
reopened.select('custom');reopened.setColor('accent',{.1,.2,.3})
reopened.resetAppearance()
check(reopened.mode()=='classic' and reopened.backgroundOpacity()==98,'appearance recovery restores selected defaults')
check(registry['savegame.mod.osp.theme.custom.accent']=='1A334D','appearance recovery preserves custom RGB')
check(registry['savegame.mod.osp.theme.button_style']=='outline','appearance recovery ignores legacy button style')
reopened.setBackgroundOpacity(75);reopened.select('ocean');reopened.reset()
check(reopened.mode()=='classic' and reopened.backgroundOpacity()==75,'palette recovery only resets palette')
local filled,edge=t.buttonPaint(t.colors(),'plain',false,false)
check(filled~=nil and edge==nil,'legacy outline preference does not alter filled buttons')
filled,edge=t.buttonPaint(t.colors(),'danger',true,false)
check(filled~=nil and edge==nil,'danger buttons keep the filled treatment')
filled,edge=t.buttonPaint(t.colors(),'outlined',false,false)
check(filled~=nil and edge~=nil,'outlined navigation headers keep their border')
filled,edge=t.buttonPaint(t.colors(),'recovery',false,false)
check(filled~=nil and edge==nil,'recovery keeps fixed readable treatment')
registry['savegame.mod.osp.theme.custom.text']='GGGGGG'
check(t.hex(t.colors().text)=='F2F0E8','malformed stored color falls back')
check(math.abs(t.contrast({0,0,0},{1,1,1})-21)<.001,'contrast endpoints')
t.select('custom');t.setColor('back',{19/255,19/255,17/255})
local click,held,mx,my,visible=nil,false,0,0,true
local numberClick,numberValue=nil,nil
local sawRecovery=false
local imagePaths={}
local api={label=function() end,rect=function() end,
    button=function(id,x,y,w,h,value,kind)
        if id=='palette_restore' then sawRecovery=kind=='recovery' end
        return id==click
    end,
    mouse=function() return mx,my end,visible=function() return visible end,
    pressed=function() return click=='slider' end,down=function() return held end,consume=function() end}
api.image=function(x,y,path) imagePaths[#imagePaths+1]=path end
local gradients={}
api.number=function(id,x,y,w,h,value,minimum,maximum,decimals,onCommit,disabled,caption,modal,extra)
    if extra and extra.gradient then
        check(w==584,'RGB number and slider share the available width')
        gradients[id]={extra.gradient(0),extra.gradient(1)}
    end
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
numberClick=nil;click=nil;t.draw(api,0,0,700)
check(gradients.palette_R_value[1][1]==0 and gradients.palette_R_value[2][1]==1,'integrated red slider retains its gradient')
check(gradients.palette_R_value[1][2]==t.colors().back[2],'red gradient preserves other channels')
local customAccent=registry['savegame.mod.osp.theme.custom.accent']
click='palette_restore';held=false;t.draw(api,0,0,700)
check(t.mode()=='classic' and sawRecovery,'fixed-contrast recovery')
check(registry['savegame.mod.osp.theme.custom.accent']==customAccent,'restore keeps custom work')
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

-- Main Appearance groups retain the palette editor and expose only visual controls.
local appearanceClick=nil
local appearanceApi={label=function() end,image=function(x,y,path) imagePaths[#imagePaths+1]=path end,rect=function() end,
    mouse=function() return 0,0 end,visible=function() return true end,pressed=function() return false end,
    down=function() return false end,consume=function() end,
    button=function(id,x,y,w,h,value,kind)
        if id==appearanceClick then appearanceClick=nil;return true end
        return false
    end,
    number=function(id,x,y,w,h,value,minimum,maximum,decimals,onCommit)
        if id=='appearance_opacity_value' then
            check(minimum==65 and maximum==100 and decimals==0,'opacity editor contract')
            if appearanceClick=='opacity_number' then appearanceClick=nil;onCommit(88) end
        end
    end}
for _,id in ipairs({'palette','background'}) do
    check(not Sections.expanded(id),'Appearance section starts collapsed')
    Sections.setExpanded(id,false)
end
imagePaths={};local height=t.drawAppearance(appearanceApi,0,0,600)
check(height>0 and #imagePaths==2,'Appearance draws a visible arrow per section')
check(not Sections.expanded('palette') and not Sections.expanded('background'),'Appearance groups default collapsed')
appearanceClick='settings_section_palette';t.drawAppearance(appearanceApi,0,0,600)
check(Sections.expanded('palette'),'palette group opens')
appearanceClick='palette_graphite';t.drawAppearance(appearanceApi,0,0,600)
check(t.mode()=='graphite','preset selection is available in Appearance')
appearanceClick='settings_section_background';t.drawAppearance(appearanceApi,0,0,600)
appearanceClick='opacity_number';t.drawAppearance(appearanceApi,0,0,600)
check(t.backgroundOpacity()==88,'numeric opacity editing')
appearanceClick='appearance_opacity_plus';t.drawAppearance(appearanceApi,0,0,600)
check(t.backgroundOpacity()==89,'opacity stepper')
local userRGB='336699';t.setColor('accent',{0x33/255,0x66/255,0x99/255});t.select('custom')
appearanceClick='appearance_restore';t.drawAppearance(appearanceApi,0,0,600)
check(t.mode()=='classic' and t.backgroundOpacity()==98,'Appearance restore resets its visual defaults')
check(registry['savegame.mod.osp.theme.custom.accent']==userRGB,'Appearance restore preserves custom color work')
print('PASS Appearance controls, palette and opacity: '..count..' assertions')
