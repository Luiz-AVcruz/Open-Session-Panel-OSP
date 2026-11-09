-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Run the real legacy options entry without client/server/player APIs.
local assertions = 0
local function check(value, message)
    assert(value, message)
    assertions = assertions + 1
end
local function world(width, height)
    local root = 'savegame.mod.osp_beta.'
    local w = {registry={}, key='', pressed=false, held=false, mouse={0,0}, back=false, stack={}, windows={}, x=0,y=0,scale=1,now=0,font=20}
    local env = setmetatable({}, {__index=_G})
    env.GetString=function(k) return w.registry[k] or '' end
    env.GetBool=function(k) return w.registry[k] or false end
    local function write(k,v)
        check(k:sub(1,#root)==root,'write outside own namespace')
        w.registry[k]=v
    end
    env.SetString=write;env.SetBool=write
    env.ClearKey=function(k)
        check(k==root..'rules' or k==root..'tools' or k==root..'players' or k==root..'effects_off_on_load','unbounded reset')
        for key in pairs(w.registry) do if key==k or key:sub(1,#k+1)==k..'.' then w.registry[key]=nil end end
    end
    env.ListKeys=function(k)
        local out,seen={},{}
        for key in pairs(w.registry) do
            if key:sub(1,#k+1)==k..'.' then
                local id=key:sub(#k+2):match('^[^.]+')
                if not seen[id] then out[#out+1]=id;seen[id]=true end
            end
        end
        return out
    end
    env.UiWidth=function() return width end;env.UiHeight=function() return height end
    env.UiPush=function() w.stack[#w.stack+1]={w.x,w.y,w.scale} end
    env.UiPop=function() local s=table.remove(w.stack);w.x,w.y,w.scale=unpack(s) end
    env.UiTranslate=function(x,y) w.x=w.x+x*w.scale;w.y=w.y+y*w.scale end
    env.UiScale=function(s) w.scale=w.scale*s end
    env.UiGetMousePos=function() return (w.mouse[1]-w.x)/w.scale,(w.mouse[2]-w.y)/w.scale end
    env.UiWindow=function(windowWidth,windowHeight,clip,inherit)
        w.windows[#w.windows+1]={x=w.x,y=w.y,width=windowWidth,height=windowHeight,scale=w.scale,clip=clip,inherit=inherit}
    end
    for _,name in ipairs({'UiColor','UiRect','UiAlign','UiFont','UiText','UiWordWrap','UiTextDisableWildcards'}) do env[name]=function() end end
    env.UiFont=function(_,size) w.font=size end
    env.UiText=function(value) w.labels[#w.labels+1]={text=value,x=w.x,y=w.y} end
    env.UiGetTextSize=function(text) return #text*w.font*.55,w.font end
    env.GetTime=function() return w.now end
    env.InputPressed=function(k) return (k=='lmb' and w.pressed) or (w.physical and w.physical[k]) or false end
    env.InputLastPressedKey=function() return w.key end
    env.InputDown=function(k) return (k=='lmb' and (w.pressed or w.held)) or (w.mods and w.mods[k]) or false end
    env.InputValue=function(k) assert(k=='mousewheel');return w.wheel or 0 end
    env.UiImage=function(path) check(path=='MOD/ui/section-down.png' or path=='MOD/ui/section-right.png','known Appearance disclosure icon');return 16,16 end
    env.InputClear=function() w.key='';w.pressed=false;w.held=false end
    env.Menu=function() w.back=true end
    env.GetLocalPlayer=function() error('Options must not need a loaded map') end
    env.ServerCall=function() error('Options must not call the server') end
    local chunk=assert(loadfile(arg[1]));setfenv(chunk,env);chunk()
    function w.draw() w.labels={};w.now=w.now+.02;env.draw();check(#w.stack==0,'UI stack') end
    function w.click(x,y)
        local s=math.min(1,width/840,height/760)
        w.mouse={(width-800*s)/2+x*s,(height-720*s)/2+y*s};w.pressed=true;w.draw();w.pressed=false;w.draw()
    end
    function w.clickText(value)
        local scale=math.min(1,width/840,height/760)
        local ox,oy=(width-800*scale)/2,(height-720*scale)/2
        for _=1,30 do
            w.draw();local found
            for _,label in ipairs(w.labels) do if label.text==value then found=label;break end end
            assert(found,'label not found: '..value)
            local x,y=(found.x-ox)/scale,(found.y-oy)/scale
            if y>=99 and y<=613 then w.click(x+3,y+3);return end
            w.mouse={ox+400*scale,oy+300*scale};w.wheel=y<99 and 2 or -2;w.draw();w.wheel=0
        end
        error('label not reachable: '..value)
    end
    function w.type(k) w.key=k;w.draw();w.key='' end
    function w.selectAll() w.mods={ctrl=true};w.type('a');w.mods=nil end
    function w.drag(x,y,phase)
        local s=math.min(1,width/840,height/760)
        w.mouse={(width-800*s)/2+x*s,(height-720*s)/2+y*s}
        w.pressed=phase=='press';w.held=phase~='release';w.draw();w.pressed=false
    end
    return w,root,env
end
-- The real Options/Theme path applies RGB slider changes only on release.
for _,size in ipairs({{840,760},{1280,720}}) do
    local w,r,env=world(unpack(size))
    w.click(210,658);w.click(78,119);w.click(400,264)
    local before=w.registry[r..'theme.custom.back']
    w.drag(60,364,'press');w.drag(810,364,'hold')
    check(env.OSP.NumberInput.active('palette_R_value'),'Options captures the integrated slider')
    check(w.registry[r..'theme.custom.back']==before,'Options does not persist drag previews')
    w.drag(810,364,'release')
    check(w.registry[r..'theme.custom.back']:sub(1,2)=='FF','release beyond viewport clamps and applies red')
    check(not w.back and not env.OSP.NumberInput.active(),'release cannot activate another Options button')
    env.OSP.Theme.setColor('back',{10/255,20/255,30/255})
    w.click(362,364);w.selectAll();w.type('1');w.type('0');w.type('0')
    w.click(754,408)
    check(w.registry[r..'theme.custom.back']=='64151E','G+ preserves the red value confirmed by blur')
    w.click(362,364);w.selectAll();w.type('1');w.type('5');w.type('0')
    w.click(754,364)
    check(w.registry[r..'theme.custom.back']=='97151E','R+ increments the value just confirmed by blur')
end
for _,size in ipairs({{840,760},{1280,720},{1024,768},{1920,1080}}) do
    local w,r,env=world(unpack(size))
    w.registry[r..'health_hud']=true -- Legacy key is ignored, including on reset.
    w.draw()
    check(#w.windows==0,'ordinary Options labels and buttons do not create clipped fields')
    w.click(272,148);check(w.registry[r..'language']=='pt','language padding hit')
    w.click(30,245);w.type('w');check(w.registry[r..'menu_key']==nil,'reject movement key')
    w.type('f8');check(w.registry[r..'menu_key']=='f8','save shortcut without map')
    w.registry[r..'identity.host']='p3';w.registry[r..'hostid']='keep';w.registry[r..'nextprofile']=3
    w.registry[r..'players.p3.exists']=true;w.registry[r..'players.p3.admin']=true
    w.registry[r..'players.p3.role']='c1'
    w.registry[r..'templates.c1.name']='Helper';w.registry[r..'templates.c1.version']=1
    w.registry[r..'templates.c1.permissions.heal']=1;w.registry[r..'templates_next']=1
    w.registry[r..'players.p3.tools.67756e']=2
    w.registry[r..'tools.67756e']=2;w.registry[r..'rules.rain']=1
    w.registry[r..'effects_off_on_load']=true
    w.registry['savegame.tool.gun.enabled']=true
    w.click(30,315)
    check(w.registry[r..'menu_key']=='p' and w.registry[r..'language']=='en' and w.registry[r..'health_hud']==true,'personal defaults leave unused legacy key untouched')
    check(w.registry[r..'rules.rain']==1 and w.registry[r..'players.p3.admin']==true,'personal reset preserves host rules')
    check(w.registry[r..'effects_off_on_load']==true,'personal reset preserves map-load policy')
    w.click(30,376);check(w.registry[r..'rules.rain']==1,'opening reset cannot erase anything')
    w.click(55,418);check(w.registry[r..'rules.rain']==1,'cancel preserves rules')
    w.click(30,376);w.click(399,418)
    check(w.registry[r..'rules.rain']==nil and w.registry[r..'tools.67756e']==nil,'host reset clears policies')
    check(w.registry[r..'effects_off_on_load']==nil,'host recovery restores the default-off map-load policy')
    check(w.registry[r..'players.p3.admin']==nil and w.registry[r..'players.p3.tools.67756e']==nil,'host reset clears player choices')
    check(w.registry[r..'players.p3.role']==nil,'host recovery removes granular assignments')
    check(w.registry[r..'templates.c1.name']=='Helper' and w.registry[r..'templates.c1.version']==1 and w.registry[r..'templates.c1.permissions.heal']==1 and w.registry[r..'templates_next']==1,'host recovery keeps the custom template library and allocator')
    check(w.registry[r..'players.p3.exists']==true and w.registry[r..'identity.host']=='p3','identities survive recovery')
    check(w.registry[r..'hostid']=='keep' and w.registry[r..'nextprofile']==3,'host identity and allocator survive')
    check(w.registry['savegame.tool.gun.enabled']==true,'native unlock data untouched')
    w.click(210,658) -- Options → Appearance
    check(env.OSP.Theme.mode()=='classic','Appearance starts with OSP colors')
    w.click(78,119) -- Open palette section
    w.click(670,220) -- Graphite preset in the third position of row two
    check(w.registry[r..'theme.mode']=='graphite','graphite preset from main-menu appearance')
    w.click(400,264) -- Open Custom, centered in the short final preset row
    w.windows={};w.draw()
    check(#w.windows==4,'appearance viewport and three RGB caption windows are clipped')
    local scale=math.min(1,size[1]/840,size[2]/760)
    local viewport=false;local rgb=0
    for _,window in ipairs(w.windows) do
        if math.abs(window.width*window.scale-744*scale)<.001 then viewport=window.clip==true and window.inherit==true
        else
            rgb=rgb+1
            check(window.clip==true and window.inherit==true,'RGB text inherits the viewport clip')
            check(math.abs(window.width*window.scale-608*scale)<.001,'RGB text uses the integrated slider width')
        end
    end
    check(viewport and rgb==3,'Options keeps the appearance viewport and fields distinct')
    w.click(362,364);w.selectAll()
    check(env.OSP.NumberInput.active('palette_R_value'),'RGB entry opens without a map')
    w.type('2');w.type('0');w.type('0');w.type('enter')
    check(w.registry[r..'theme.custom.back']:sub(1,2)=='C8','numeric red channel saves as 200')
    w.click(362,364);w.selectAll();w.type('5')
    local beforeCancel=w.registry[r..'theme.custom.back']
    w.type('esc')
    check(w.registry[r..'theme.custom.back']==beforeCancel and not env.OSP.NumberInput.active(),'Escape cancels without changing saved RGB')
    -- Exercise the fixed appearance recovery after scrolling the clipped page.
    w.registry[r..'theme.button_style']='outline';env.OSP.Theme.setBackgroundOpacity(80)
    for _,id in ipairs({'palette','background'}) do env.OSP.SettingsSections.setExpanded(id,true) end
    w.mouse={(size[1]-800*scale)/2+400*scale,(size[2]-720*scale)/2+300*scale}
    w.draw() -- Let the viewport measure the expanded content before scrolling.
    w.wheel=-100;w.draw();w.wheel=0;w.draw()
    w.click(400,635);check(not w.back,'viewport content does not invoke Mod Manager Back')
    w.click(400,610)
    check(env.OSP.Theme.mode()=='classic' and env.OSP.Theme.backgroundOpacity()==98,
        'appearance recovery restores colors and opacity from the scrolled viewport')
    w.click(30,660);check(not w.back,'Appearance Back returns to main Options')
    w.click(30,660);check(w.back,'main Options Back returns to the Mod Manager')
    w.click(30,315);check(w.registry[r..'theme.mode']=='classic','personal reset restores palette')
    w.click(30,660);check(w.back,'back to Mod Manager')
end
for _,size in ipairs({{640,480},{1024,768},{1920,1080}}) do
 for _,language in ipairs({'en','pt'}) do
    local w,r,env=world(unpack(size));w.registry[r..'language']=language
    w.registry[r..'identity.host']='keep';w.registry[r..'tools.abc']=2
    w.click(30,570);w.clickText(env.OSP.L('players')..' · '..env.OSP.L('navigation_shown'))
    check(w.registry[r..'navigation.hidden.players']=='1','Options hides tab without map')
    check(not env.OSP.Navigation.visible('players'),'Options uses shared preference contract')
    local other,_,otherEnv=world(unpack(size));other.registry=w.registry
    check(not otherEnv.OSP.Navigation.visible('players'),'new Options context keeps visibility')
    env.OSP.Navigation.setSelectionMode('leave');env.OSP.Navigation.setOpeningMode('players');env.OSP.Navigation.rememberTab('tools')
    w.clickText(env.OSP.L('navigation_restore'));check(env.OSP.Navigation.visible('players'),'show all from Options')
    check(env.OSP.Navigation.selectionMode()=='leave' and env.OSP.Navigation.lastTab()=='tools','show all keeps behavior preferences')
    w.clickText(env.OSP.L('players')..' · '..env.OSP.L('navigation_shown'));w.click(30,660);w.click(30,315)
    check(env.OSP.Navigation.visible('players'),'personal reset includes navigation')
    check(env.OSP.Navigation.selectionMode()=='keep' and env.OSP.Navigation.openingMode()=='last' and env.OSP.Navigation.lastTab()=='players','personal reset includes behavior')
    check(w.registry[r..'identity.host']=='keep' and w.registry[r..'tools.abc']==2,'navigation reset preserves host data')
 end
end
-- A hidden scrolled control cannot consume the fixed Back button's click.
do
 local w,r,e=world(840,760);w.click(30,570)
 local before=e.OSP.Navigation.selectionMode();w.click(30,690)
 check(not w.back,'fixed Back leaves Interface before leaving Options')
 check(e.OSP.Navigation.selectionMode()==before,'fixed Back does not activate clipped preferences')
 w.click(30,690);check(w.back,'fixed Back is reachable without scrolling')
end
-- Shared behavior controls work without a map and stay inside the viewport.
for _,size in ipairs({{640,480},{1024,768},{1920,1080}}) do
 for _,language in ipairs({'en','pt'}) do
    local w,r,e=world(unpack(size));w.registry[r..'language']=language
    w.click(30,570)
    for _,mode in ipairs({'keep','close','leave'}) do
        w.clickText(e.OSP.L('behavior_selection_'..mode))
        check(e.OSP.Navigation.selectionMode()==mode,'Options selection mode uses shared settings')
    end
    w.clickText(e.OSP.L('behavior_opening_players'));check(e.OSP.Navigation.openingMode()=='players','Options fixed opening tab')
    w.clickText(e.OSP.L('behavior_opening_last'));check(e.OSP.Navigation.openingMode()=='last','Options last opening tab')
    local before=e.OSP.Navigation.selectionMode()
    w.mouse={0,0};w.wheel=-100;w.draw();w.wheel=0
    w.click(30,70);check(e.OSP.Navigation.selectionMode()==before,'off-viewport clicks cannot change behavior')
    w.clickText(e.OSP.L('navigation_restore'))
    w.click(30,660);check(not w.back,'Interface Back returns to Options')
    w.click(30,660);check(w.back,'main Back remains accessible after scrolling')
 end
end
-- The real Options entry shares binding/capture/conflict rules without a map.
for _,size in ipairs({{640,480},{1024,768},{1920,1080}}) do
 for _,language in ipairs({'en','pt'}) do
    local w,r,e=world(unpack(size));w.registry[r..'language']=language
    w.registry[r..'identity.host']='keep';w.registry[r..'tools.abc']=2
    w.click(410,570);w.click(327,149);check(e.OSP.Shortcuts.capture=='god','Options starts personal capture')
    w.draw();check(e.OSP.Shortcuts.capture=='god','idle frame keeps capture')
    w.type('w');check(e.OSP.Shortcuts.capture=='god','invalid key permits retry')
    w.physical={f8=true};w.draw();w.physical={};check(e.OSP.Shortcuts.binding('god')=='f8','physical-only capture works in real Options')
    w.click(327,193);w.type('f8');check(e.OSP.Shortcuts.capture=='fly' and e.OSP.Shortcuts.message=='shortcut_conflict','Options duplicate refused')
    w.type('f9');check(e.OSP.Shortcuts.binding('fly')=='f9')
    w.click(327,237);w.mods={ctrl=true};w.type('f10');w.mods={}
    check(e.OSP.Shortcuts.capture=='noclip' and e.OSP.Shortcuts.binding('noclip')=='','Options modifier rejected')
    w.click(327,237);check(e.OSP.Shortcuts.capture==nil,'binding button cancels explicitly')
    w.click(327,281);w.type('f11');check(e.OSP.Shortcuts.binding('strength')=='f11','strength shortcut available without map')
    w.click(327,325);w.type('f12');check(e.OSP.Shortcuts.binding('ammo')=='f12','ammo shortcut available without map')

    w.click(625,149);check(e.OSP.Shortcuts.binding('god')=='','clear one binding')
    w.click(30,660);w.click(30,245);w.type('f9');check(e.OSP.Shortcuts.capture=='menu','menu collision keeps capture')
    w.click(30,245);check(e.OSP.Shortcuts.capture==nil,'menu cancel preserves prior key')
    local other,_,oe=world(unpack(size));other.registry=w.registry;check(oe.OSP.Shortcuts.binding('fly')=='f9' and oe.OSP.Shortcuts.binding('strength')=='f11' and oe.OSP.Shortcuts.binding('ammo')=='f12','bindings survive new Options context')
    w.click(30,315);check(e.OSP.Shortcuts.binding('fly')=='' and e.OSP.Shortcuts.binding('strength')=='' and e.OSP.Shortcuts.binding('ammo')=='','personal reset clears action bindings')
    check(w.registry[r..'identity.host']=='keep' and w.registry[r..'tools.abc']==2,'personal reset preserves session data')
 end
end

-- Mode can be changed before loading a map; detection must not run here.
do
    local w,r,e=world(840,760)
    e.IsMultiplayer=function() error("Options must not detect a live session") end
    w.click(30,570);w.click(290,124)
    check(e.OSP.ViewMode.get()=="single","Options sets Singleplayer")
    w.click(540,124);check(e.OSP.ViewMode.get()=="multi","Options sets Multiplayer")
    local other,_,oe=world(840,760);other.registry=w.registry
    check(oe.OSP.ViewMode.get()=="multi","mode survives new Options instance")
    w.click(30,660);w.click(30,315)
    check(e.OSP.ViewMode.get()=="auto","personal reset restores automatic")
end

-- The existing personal reset also collapses the in-game Settings sections.
do
    local w,r,e=world(840,760)
    for _,id in ipairs(e.OSP.SettingsSections.ids) do e.OSP.SettingsSections.setExpanded(id,true) end
    w.registry[r.."players.test.tools.abc"]="2"
    w.click(30,315)
    for _,id in ipairs(e.OSP.SettingsSections.ids) do check(not e.OSP.SettingsSections.expanded(id),"personal reset collapses section") end
    check(w.registry[r.."players.test.tools.abc"]=="2","reset preserves player profile")
end
print('PASS main-menu options without a map: '..assertions..' assertions')
