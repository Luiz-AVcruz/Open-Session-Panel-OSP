-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Personal presentation only. Store RGB as validated hex strings, never game state.
OSP.Theme = {}
local Theme = OSP.Theme
local root = "savegame.mod.osp_beta.theme."
local classic = {
    back={0.075,0.075,0.072,0.98}, side={0.105,0.105,0.099,1},
    line={0.27,0.27,0.25,1}, surface={0.16,0.16,0.15,1}, hover={0.21,0.21,0.19,1},
    selected={0.24,0.22,0.16,1}, text={0.95,0.94,0.91,1}, muted={0.69,0.69,0.65,1},
    accent={0.96,0.78,0.37,1}, danger={0.96,0.62,0.55,1}, disabled={0.39,0.39,0.36,1},
    success={0.59,0.80,0.61,1},
}
Theme.roles = {"back","side","surface","hover","selected","line","text","muted","accent","danger","disabled","success"}
Theme.presets = {"classic","ocean","forest","violet","light","graphite","custom"}
local variants = {
    graphite={back="14181E",side="1C2027",surface="272C33",hover="343C47",selected="253F50",accent="75C5E8",text="EEF1F4",muted="A7B2BE",line="44505E",danger="E6988C",success="9BC49D",disabled="77828D"},
    ocean={back="101923",side="162330",surface="203446",hover="29475c",selected="234e68",accent="6ad5ff"},
    forest={back="131b16",side="1a261d",surface="29392d",hover="354b3a",selected="31513b",accent="a3db88"},
    violet={back="191420",side="241c2e",surface="34283f",hover="483655",selected="503360",accent="d5a3ff"},
    light={back="f3f3ef",side="e5e7e2",surface="d4d8d1",hover="c4ccc0",selected="bfd5b4",line="9aa294",text="172014",muted="4a5545",accent="315f22",danger="a12525",disabled="6a7365",success="235f36"},
}
local selectedRole = 1
local function cancelColorInput()
    local number=OSP.NumberInput
    if not number then return end
    for _,letter in ipairs({"R","G","B"}) do
        if number.active("palette_"..letter.."_value") then number.cancel();return end
    end
end
local function decode(value, fallback)
    if type(value) ~= "string" or #value ~= 6 or value:find("[^%x]") then return OSP.copy(fallback) end
    return {tonumber(value:sub(1,2),16)/255, tonumber(value:sub(3,4),16)/255, tonumber(value:sub(5,6),16)/255, 1}
end
function Theme.hex(color)
    return string.format("%02X%02X%02X", math.floor(color[1]*255+.5), math.floor(color[2]*255+.5), math.floor(color[3]*255+.5))
end
function Theme.mode()
    local id = GetString(root .. "mode")
    for _,name in ipairs(Theme.presets) do if id == name then return name end end
    return "classic"
end
function Theme.select(id)
    for _,name in ipairs(Theme.presets) do
        if id == name then
            SetString(root .. "mode", id)
            cancelColorInput()
            return true
        end
    end
    return false
end
function Theme.backgroundOpacity()
    local value=tonumber(GetString(root.."background_opacity"))
    return OSP.finite(value) and value>=65 and value<=100 and value%1==0 and value or 98
end
function Theme.setBackgroundOpacity(value)
    if not OSP.finite(value) or value<65 or value>100 or value%1~=0 then return false end
    SetString(root.."background_opacity",tostring(value));return true
end
-- Shared paint policy; each entry point still owns geometry and input.
function Theme.buttonPaint(colors,kind,hover,clicked)
    if kind=="recovery" then return {.08,.08,.08,1},nil end
    local active=kind=="active" or clicked
    local fill=active and colors.selected or hover and colors.hover or kind=="plain" and colors.side or colors.surface
    local edge=kind=="outlined" and ((hover or active) and colors.accent or colors.line) or nil
    return fill,edge
end
function Theme.resetAppearance()
    Theme.reset();Theme.setBackgroundOpacity(98)
end
function Theme.colors()
    local colors = OSP.copy(classic)
    local mode = Theme.mode()
    if mode == "custom" then
        for _,role in ipairs(Theme.roles) do colors[role]=decode(GetString(root .. "custom." .. role),classic[role]) end
    else
        for role,hex in pairs(variants[mode] or {}) do colors[role]=decode(hex,classic[role]) end
    end
    colors.back[4]=Theme.backgroundOpacity()/100
    return colors
end
function Theme.setColor(role, color)
    local found=false
    for _,key in ipairs(Theme.roles) do if key==role then found=true end end
    if not found or type(color)~="table" then return false end
    for i=1,3 do if not OSP.finite(color[i]) or color[i]<0 or color[i]>1 then return false end end
    local key = root .. "custom." .. role
    local hex = Theme.hex(color)
    if GetString(key) ~= hex then SetString(key, hex) end
    return true
end
function Theme.reset() Theme.select("classic") end
function Theme.cancelDrag()
    cancelColorInput()
end
function Theme.contrast(a,b)
    local function luminance(c)
        local out=0
        for i,weight in ipairs({.2126,.7152,.0722}) do
            local v=c[i];v=v<=.04045 and v/12.92 or ((v+.055)/1.055)^2.4
            out=out+v*weight
        end
        return out
    end
    local x,y=luminance(a),luminance(b)
    return (math.max(x,y)+.05)/(math.min(x,y)+.05)
end
-- The caller owns input consumption, clipping and coordinate conversion.
function Theme.draw(api,x,y,width,bodyOnly)
    local start=y
    if not bodyOnly then api.label(x,y,OSP.L("palette"),20,width);y=y+34 end
    local cell=(width-16)/3
    for i,name in ipairs(Theme.presets) do
        local rowStart=math.floor((i-1)/3)*3
        local rowCount=math.min(3,#Theme.presets-rowStart)
        local bx=x+(3-rowCount)*(cell+8)/2+((i-1)%3)*(cell+8)
        local by=y+math.floor((i-1)/3)*44
        if api.button("palette_"..name,bx,by,cell,36,OSP.L("palette_"..name),Theme.mode()==name and "active" or "plain") then Theme.select(name) end
    end
    y=y+math.ceil(#Theme.presets/3)*44+8
    if Theme.mode()=="custom" then
        local role=Theme.roles[selectedRole]
        if api.button("palette_role_prev",x,y,40,36,"<","plain") then
            selectedRole=selectedRole==1 and #Theme.roles or selectedRole-1;Theme.cancelDrag()
        end
        if api.button("palette_role_next",x+width-40,y,40,36,">","plain") then
            selectedRole=selectedRole%#Theme.roles+1;Theme.cancelDrag()
        end
        role=Theme.roles[selectedRole]
        local color=Theme.colors()[role]
        api.rect(x+52,y+4,28,28,color)
        api.label(x+92,y+8,OSP.L("color_"..role).."  #"..Theme.hex(color),16,width-148)
        y=y+48
        for channel,letter in ipairs({"R","G","B"}) do
            api.label(x,y+8,letter,16,20)
            api.number("palette_"..letter.."_value",x+20,y,width-116,36,math.floor(color[channel]*255+.5),0,255,0,function(value)
                local nextColor=Theme.colors()[role]
                nextColor[channel]=value/255
                Theme.setColor(role,nextColor)
            end,false,nil,false,{gradient=function(fraction)
                local tint=OSP.copy(color);tint[channel]=fraction;return tint
            end})
            for _,step in ipairs({-1,1}) do
                local bx=x+width-(step<0 and 80 or 36)
                if api.button("palette_"..letter..(step<0 and "_minus" or "_plus"),bx,y,36,36,step<0 and "-" or "+","plain") then
                    color=Theme.colors()[role]
                    color[channel]=math.max(0,math.min(255,math.floor(color[channel]*255+.5)+step))/255
                    Theme.setColor(role,color)
                end
            end
            y=y+44
        end
        if OSP.NumberInput and (OSP.NumberInput.active("palette_R_value") or OSP.NumberInput.active("palette_G_value") or OSP.NumberInput.active("palette_B_value")) then
            api.label(x,y,OSP.L("number_help"),14,width)
            y=y+22
        end
        local colors=Theme.colors()
        if Theme.contrast(colors.text,colors.back)<4.5 or Theme.contrast(colors.text,colors.surface)<4.5 then
            api.rect(x,y,width,42,{.05,.05,.05,1})
            api.label(x+8,y+8,OSP.L("palette_contrast"),15,width-16,{1,.8,.35,1})
            y=y+50
        end
    end
    if api.button("palette_restore",x,y,width,36,OSP.L("palette_restore"),"recovery") then Theme.reset() end
    return y+48-start
end

function Theme.drawAppearance(api,x,y,width)
    local start=y
    local function section(id,key)
        local expanded=OSP.SettingsSections.expanded(id)
        if api.button("settings_section_"..id,x,y,width,58,"","outlined") then
            expanded=not expanded;OSP.SettingsSections.setExpanded(id,expanded);Theme.cancelDrag()
        end
        api.label(x+10,y+9,OSP.L(key),17,width-48)
        api.image(x+width-28,y+21,expanded and "MOD/ui/section-down.png" or "MOD/ui/section-right.png")
        api.label(x+10,y+33,OSP.L("settings_help_"..id),13,width-48)
        y=y+68;return expanded
    end
    if section("palette","appearance_colors") then y=y+Theme.draw(api,x,y,width,true)+12 end
    if section("background","background") then
        api.label(x,y,OSP.L("appearance_opacity"),16,width);y=y+30
        api.number("appearance_opacity_value",x,y,width-104,36,Theme.backgroundOpacity(),65,100,0,Theme.setBackgroundOpacity)
        for i,step in ipairs({-1,1}) do
            if api.button("appearance_opacity_"..(step<0 and "minus" or "plus"),x+width-104+(i-1)*56,y,48,36,step<0 and "-" or "+","plain") then Theme.setBackgroundOpacity(math.max(65,math.min(100,Theme.backgroundOpacity()+step))) end
        end
        y=y+52
    end
    if api.button("appearance_restore",x,y,width,36,OSP.L("appearance_restore"),"recovery") then Theme.resetAppearance() end
    return y+48-start
end
