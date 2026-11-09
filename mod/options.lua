-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- The Mod Manager runs this legacy draw entry point without a map or server.
#include "scripts/common.lua"
#include "scripts/strings.lua"
#include "scripts/navigation.lua"
#include "scripts/view_mode.lua"
#include "scripts/settings_sections.lua"
#include "scripts/shortcuts.lua"
#include "scripts/number_input.lua"
#include "scripts/theme.lua"
#include "scripts/number_control.lua"

local root = "savegame.mod.osp."
local capturing = false
local appearance = false
local appearanceScroll,appearanceHeight=0,0
local appearanceHit=nil
local navigation = false
local navigationScroll,navigationHeight,navigationHit=0,0,nil
local personalShortcuts = false
local shortcuts = OSP.Shortcuts
local colors = OSP.Theme.colors()
local confirming = false
local message = nil
local pressed, consumed = false, false
local numericFrame={time=0}

OSP.getLanguage = function()
    return GetString(root .. "language") == "pt" and "pt" or "en"
end
local function text(key, ...)
    return OSP.L(key, ...)
end
local function label(x, y, value, size, width, color, clipped)
    UiPush()
    UiTranslate(x, y)
    UiAlign("left top")
    UiFont("regular.ttf", size or 20)
    color = color or colors.text
    UiColor(unpack(color))
    UiTextDisableWildcards(true)
    if width then
        if clipped then UiWindow(width, (size or 20) * 1.35, true)
        else UiWordWrap(width) end
    end
    UiText(value)
    UiPop()
end
local function button(x, y, width, caption, selected, modal, recovery, clipCaption, disabled, height, kind)
    height=height or 40
    UiPush()
    UiTranslate(x, y)
    local mx, my = UiGetMousePos()
    local enabled = not disabled and appearanceHit~=false and navigationHit~=false and (not confirming or modal)
    local hovered = enabled and mx >= 0 and my >= 0 and mx < width and my < height
    local clicked = hovered and pressed and not consumed
    if clicked then
        consumed = true
        OSP.NumberControl.beforeAction()
        shortcuts.cancel();capturing=false
    end
    local color,edge=OSP.Theme.buttonPaint(colors,recovery and "recovery" or selected and "active" or kind,hovered,clicked)
    if color then UiColor(unpack(color));UiRect(width,height) end
    if edge then
        UiColor(unpack(edge));UiRect(width,1)
        UiPush();UiTranslate(0,height-1);UiRect(width,1);UiPop()
        UiRect(1,height);UiPush();UiTranslate(width-1,0);UiRect(1,height);UiPop()
    end
    label(12, 9, caption, 20, clipCaption and math.max(0, width-24) or nil,
        recovery and {1,1,1,1} or disabled and colors.disabled or colors.text, clipCaption)
    UiPop()
    return clicked
end
local function readKey()
    local key = GetString(root .. "menu_key")
    return OSP.validKey(key) and key or "p"
end
local function captureKey()
    if not shortcuts.capture then return end
    shortcuts.key();capturing=shortcuts.capture=="menu"
    if shortcuts.message then message=text(shortcuts.message) end
end

function draw()
    colors = OSP.Theme.colors()
    numericFrame=OSP.NumberInput.sample()
    pressed, consumed = numericFrame.mousePressed, false
    if OSP.NumberInput.active() then OSP.NumberInput.key(numericFrame) else captureKey() end
    OSP.NumberControl.beginFrame(numericFrame)
    local width, height = 800, 720
    local scale = math.min(1, UiWidth() / 840, UiHeight() / 760)
    UiPush()
    UiTranslate((UiWidth() - width * scale) / 2, (UiHeight() - height * scale) / 2)
    UiScale(scale)
    UiAlign("left top")
    UiColor(unpack(colors.back))
    UiRect(width, height)
    label(28, 22, text("app_title"), 30)
    if personalShortcuts then
        shortcuts.draw({label=label,button=function(id,x,y,width,height,value,kind,disabled)
            return button(x,y,width,value,kind=="active",false,false,true,disabled)
        end},28,90,744)
        if button(28,658,220,text("back")) then personalShortcuts=false;shortcuts.cancel() end
        OSP.NumberControl.endFrame(consumed);UiPop();return
    end
    if navigation then
        local mx,my=UiGetMousePos()
        navigationHit=mx>=28 and mx<772 and my>=90 and my<640 and not confirming
        local wheel=InputValue("mousewheel")
        if navigationHit and wheel~=0 then
            navigationScroll=math.max(0,math.min(math.max(0,navigationHeight-550),navigationScroll-wheel*40))
        end
        local api={label=label,button=function(id,x,y,w,h,value,kind)
            return button(x,y,w,value,kind=="active",false,false,false,false,h)
        end}
        UiPush();UiTranslate(28,90);UiWindow(744,550,true,true);UiTranslate(0,-navigationScroll)
        local y=OSP.ViewMode.draw(api,0,0,744)+12
        y=y+OSP.Navigation.drawBehavior(api,0,y,744)+12
        navigationHeight=y+OSP.Navigation.draw(api,0,y,744)
        UiPop();navigationHit=nil
        navigationScroll=math.max(0,math.min(math.max(0,navigationHeight-550),navigationScroll))
        if navigationHeight>550 then
            UiPush();UiTranslate(778,90);UiColor(unpack(colors.line));UiRect(3,550)
            local h=550*550/navigationHeight
            UiTranslate(0,(550-h)*navigationScroll/(navigationHeight-550));UiColor(unpack(colors.muted));UiRect(3,h);UiPop()
        end
        if button(28,658,220,text("back")) then navigation=false end
        OSP.NumberControl.endFrame(consumed);UiPop();return
    end
    if appearance then
        label(28,64,text("appearance"),20)
        local mx,my=UiGetMousePos()
        appearanceHit=mx>=28 and mx<772 and my>=90 and my<640 and not confirming
        local wheel=InputValue("mousewheel")
        if appearanceHit and wheel~=0 and not OSP.NumberControl.dragging() then
            appearanceScroll=math.max(0,math.min(math.max(0,appearanceHeight-550),appearanceScroll-wheel*40))
            OSP.Theme.cancelDrag()
        end
        UiPush();UiTranslate(28,90);UiWindow(744,550,true,true);UiTranslate(0,-appearanceScroll)
        appearanceHeight=OSP.Theme.drawAppearance({
            label=label,
            button=function(id,x,y,width,height,value,kind)
                return button(x,y,width,value,kind=="active",false,kind=="recovery",false,false,height,kind)
            end,
            image=function(x,y,path) UiPush();UiTranslate(x,y);UiColor(unpack(colors.muted));UiImage(path);UiPop() end,
            number=function(id,x,y,width,height,value,minimum,maximum,decimals,onCommit,disabled,caption,modal,extra)
                UiPush();UiTranslate(x,y)
                OSP.NumberControl.draw({id=id,w=width,h=height,value=value,minimum=minimum,maximum=maximum,
                    decimals=decimals,onCommit=onCommit,colors=colors,disabled=disabled,caption=caption,
                    gradient=extra and extra.gradient,visible=y+height>appearanceScroll and y<appearanceScroll+550,
                    pointerAllowed=appearanceHit,consumed=consumed,
                    valid=function() return appearance and not confirming end,
                    consume=function() consumed=true end,
                    focus=function() capturing=false;shortcuts.cancel() end})
                UiPop()
            end,
            rect=function(x,y,width,height,color)
                UiPush();UiTranslate(x,y);UiColor(unpack(color));UiRect(width,height);UiPop()
            end,
            mouse=function() return UiGetMousePos() end,
            visible=function() return appearanceHit end,
            pressed=function() return pressed and not consumed end,
            down=function() return InputDown("lmb") end,
            consume=function() consumed=true end,
        },0,0,744)
        UiPop();appearanceHit=nil
        appearanceScroll=math.max(0,math.min(math.max(0,appearanceHeight-550),appearanceScroll))
        if appearanceHeight>550 then
            UiPush();UiTranslate(778,90);UiColor(unpack(colors.line));UiRect(3,550)
            local h=550*550/appearanceHeight
            UiTranslate(0,(550-h)*appearanceScroll/(appearanceHeight-550));UiColor(unpack(colors.muted));UiRect(3,h);UiPop()
        end
        if button(28,658,220,text("back")) then appearance=false;OSP.Theme.cancelDrag() end
        OSP.NumberControl.endFrame(consumed);UiPop();return
    end
    OSP.Theme.cancelDrag()
    label(28, 67, text("main_options_help"), 17, 744)
    label(28, 115, text("language"), 20)
    if button(28, 146, 230, text("english"), OSP.getLanguage() == "en") then
        SetString(root .. "language", "en")
    end
    if button(270, 146, 230, text("portuguese"), OSP.getLanguage() == "pt") then
        SetString(root .. "language", "pt")
    end
    label(28, 210, text("menu_key") .. ": " .. string.upper(readKey()), 20)
    local menuCapture=shortcuts.capture=="menu"
    if button(28, 243, 350, text(menuCapture and "cancel" or "change_key")) then
        if menuCapture then shortcuts.cancel() else shortcuts.begin("menu") end
        capturing=shortcuts.capture=="menu";message=nil
    end
    if capturing then label(390, 251, text("press_key"), 16, 375) end
    if button(28, 313, 744, text("reset_personal"), false, false, true) then
        SetString(root .. "language", "en")
        SetString(root .. "menu_key", "p")
        capturing = false
        OSP.Theme.resetAppearance()
        OSP.Navigation.reset()
        OSP.Navigation.resetBehavior()
        OSP.ViewMode.set("auto")
        OSP.SettingsSections.reset()
        shortcuts.reset()
        message = text("preferences_reset")
    end
    if button(28, 374, 744, text("reset_saved_host")) then
        shortcuts.cancel()
        confirming = true
        capturing = false
        message = nil
    end
    label(28, 428, text("reset_saved_host_help"), 17, 744)
    if message then label(28, 508, message, 17, 744) end
    if button(408, 568, 364, text("personal_shortcuts")) then personalShortcuts=true;capturing=false;shortcuts.cancel();OSP.NumberInput.cancel() end
    if button(28, 568, 368, text("interface_settings")) then shortcuts.cancel();navigation=true;navigationScroll=0;capturing=false;OSP.NumberInput.cancel() end
    if button(28, 658, 170, text("back")) then shortcuts.cancel();Menu() end
    if button(210,658,350,text("appearance")) then shortcuts.cancel();appearance=true;appearanceScroll=0;capturing=false end
    label(610, 668, text("version", OSP.version), 16)
    if confirming then
        UiColor(0, 0, 0, 0.82)
        UiRect(width, height)
        UiPush()
        UiTranslate(30, 200)
        UiColor(unpack(colors.side))
        UiRect(740, 280)
        label(22, 20, text("confirmation"), 26)
        label(22, 68, text("reset_saved_host_confirm"), 20, 696)
        if button(22, 216, 330, text("cancel"), false, true) then confirming = false end
        if button(366, 216, 350, text("confirm"), false, true) then
            -- Never clear the whole mod namespace: identity references must survive.
            local profiles = ListKeys(root .. "players")
            for _,key in ipairs({"rules", "tools", "players", "effects_off_on_load"}) do ClearKey(root .. key) end
            for _,id in ipairs(profiles) do
                if id:match("^p%d+$") then SetBool(root .. "players." .. id .. ".exists", true) end
            end
            confirming = false
            message = text("host_options_reset")
        end
        UiPop()
    end
    OSP.NumberControl.endFrame(consumed);UiPop()
end
