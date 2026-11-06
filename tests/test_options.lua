-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Run the real legacy options entry without client/server/player APIs.
local assertions = 0
local function check(value, message)
    assert(value, message)
    assertions = assertions + 1
end
local function world(width, height)
    local root = 'savegame.mod.osp.'
    local w = {registry={}, key='', pressed=false, mouse={0,0}, back=false, stack={}, x=0,y=0,scale=1}
    local env = setmetatable({}, {__index=_G})
    env.GetString=function(k) return w.registry[k] or '' end
    env.GetBool=function(k) return w.registry[k] or false end
    local function write(k,v)
        check(k:sub(1,#root)==root,'write outside own namespace')
        w.registry[k]=v
    end
    env.SetString=write;env.SetBool=write
    env.ClearKey=function(k)
        check(k==root..'rules' or k==root..'tools' or k==root..'players','unbounded reset')
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
    for _,name in ipairs({'UiColor','UiRect','UiAlign','UiFont','UiText','UiWordWrap','UiTextDisableWildcards'}) do env[name]=function() end end
    env.InputPressed=function(k) return k=='lmb' and w.pressed end
    env.InputLastPressedKey=function() return w.key end
    env.InputDown=function(k) return k=='lmb' and w.pressed end
    env.InputClear=function() w.key='';w.pressed=false end
    env.Menu=function() w.back=true end
    env.GetLocalPlayer=function() error('Options must not need a loaded map') end
    env.ServerCall=function() error('Options must not call the server') end
    local chunk=assert(loadfile(arg[1]));setfenv(chunk,env);chunk()
    function w.draw() env.draw();check(#w.stack==0,'UI stack') end
    function w.click(x,y)
        local s=math.min(1,width/840,height/760)
        w.mouse={(width-800*s)/2+x*s,(height-720*s)/2+y*s};w.pressed=true;w.draw();w.pressed=false;w.draw()
    end
    function w.type(k) w.key=k;w.draw();w.key='' end
    return w,root
end
for _,size in ipairs({{840,760},{1280,720},{1024,768},{1920,1080}}) do
    local w,r=world(unpack(size))
    w.registry[r..'health_hud']=true -- Legacy key is ignored, including on reset.
    w.draw()
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
    w.registry['savegame.tool.gun.enabled']=true
    w.click(30,315)
    check(w.registry[r..'menu_key']=='p' and w.registry[r..'language']=='en' and w.registry[r..'health_hud']==true,'personal defaults leave unused legacy key untouched')
    check(w.registry[r..'rules.rain']==1 and w.registry[r..'players.p3.admin']==true,'personal reset preserves host rules')
    w.click(30,376);check(w.registry[r..'rules.rain']==1,'opening reset cannot erase anything')
    w.click(55,418);check(w.registry[r..'rules.rain']==1,'cancel preserves rules')
    w.click(30,376);w.click(399,418)
    check(w.registry[r..'rules.rain']==nil and w.registry[r..'tools.67756e']==nil,'host reset clears policies')
    check(w.registry[r..'players.p3.admin']==nil and w.registry[r..'players.p3.tools.67756e']==nil,'host reset clears player choices')
    check(w.registry[r..'players.p3.role']==nil,'host recovery removes granular assignments')
    check(w.registry[r..'templates.c1.name']=='Helper' and w.registry[r..'templates.c1.version']==1 and w.registry[r..'templates.c1.permissions.heal']==1 and w.registry[r..'templates_next']==1,'host recovery keeps the custom template library and allocator')
    check(w.registry[r..'players.p3.exists']==true and w.registry[r..'identity.host']=='p3','identities survive recovery')
    check(w.registry[r..'hostid']=='keep' and w.registry[r..'nextprofile']==3,'host identity and allocator survive')
    check(w.registry['savegame.tool.gun.enabled']==true,'native unlock data untouched')
    w.click(212,660);w.click(282,126)
    check(w.registry[r..'theme.mode']=='ocean','preset from main-menu options')
    w.click(532,170);w.click(694,272)
    check(w.registry[r..'theme.mode']=='custom','custom from main-menu options')
    check(w.registry[r..'theme.custom.back']~=nil,'RGB control without a map')
    w.click(30,660)
    w.click(30,315);check(w.registry[r..'theme.mode']=='classic','personal reset restores palette')
    w.click(30,660);check(w.back,'back to Mod Manager')
end
print('PASS main-menu options without a map: '..assertions..' assertions')
