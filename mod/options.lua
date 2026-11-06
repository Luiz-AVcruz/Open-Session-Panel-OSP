-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- The Mod Manager runs this legacy draw entry point without a map or server.
#include "scripts/common.lua"
#include "scripts/strings.lua"

local root = "savegame.mod.osp."
local capturing = false
local confirming = false
local message = nil
local pressed, consumed = false, false

OSP.getLanguage = function()
    return GetString(root .. "language") == "pt" and "pt" or "en"
end
local function text(key, ...)
    return OSP.L(key, ...)
end
local function label(x, y, value, size, width)
    UiPush()
    UiTranslate(x, y)
    UiAlign("left top")
    UiFont("regular.ttf", size or 20)
    UiColor(0.94, 0.93, 0.90)
    UiTextDisableWildcards(true)
    if width then UiWordWrap(width) end
    UiText(value)
    UiPop()
end
local function button(x, y, width, caption, selected, modal)
    UiPush()
    UiTranslate(x, y)
    local mx, my = UiGetMousePos()
    local enabled = not confirming or modal
    local hovered = enabled and mx >= 0 and my >= 0 and mx < width and my < 40
    local clicked = hovered and pressed and not consumed
    if clicked then consumed = true end
    if selected then UiColor(0.24, 0.22, 0.16)
    elseif hovered then UiColor(0.23, 0.23, 0.21)
    else UiColor(0.16, 0.16, 0.15) end
    UiRect(width, 40)
    label(12, 9, caption, 20)
    UiPop()
    return clicked
end
local function readKey()
    local key = GetString(root .. "menu_key")
    return OSP.validKey(key) and key or "p"
end
local function captureKey()
    if not capturing then return end
    local key = string.lower(InputLastPressedKey() or "")
    if key == "" or key == "lmb" or key == "rmb" or key == "mmb" then return end
    if key == "esc" then
        capturing = false
    elseif OSP.validKey(key) then
        SetString(root .. "menu_key", key)
        capturing = false
        message = text("shortcut_saved")
    else
        message = text("invalid_key")
    end
    InputClear()
end
function draw()
    pressed, consumed = InputPressed("lmb"), false
    captureKey()
    local width, height = 800, 720
    local scale = math.min(1, UiWidth() / 840, UiHeight() / 760)
    UiPush()
    UiTranslate((UiWidth() - width * scale) / 2, (UiHeight() - height * scale) / 2)
    UiScale(scale)
    UiAlign("left top")
    UiColor(0.075, 0.075, 0.072, 0.98)
    UiRect(width, height)
    label(28, 22, text("app_title"), 30)
    label(28, 67, text("main_options_help"), 17, 744)
    label(28, 115, text("language"), 20)
    if button(28, 146, 230, text("english"), OSP.getLanguage() == "en") then
        SetString(root .. "language", "en")
    end
    if button(270, 146, 230, text("portuguese"), OSP.getLanguage() == "pt") then
        SetString(root .. "language", "pt")
    end
    label(28, 210, text("menu_key") .. ": " .. string.upper(readKey()), 20)
    if button(28, 243, 350, text(capturing and "cancel" or "change_key")) then
        capturing = not capturing
        message = nil
    end
    if capturing then label(390, 251, text("press_key"), 16, 375) end
    local health = GetBool(root .. "health_hud")
    label(28, 310, text("health_indicator"), 20)
    if button(582, 300, 190, text(health and "on" or "off"), health) then
        SetBool(root .. "health_hud", not health)
    end
    label(28, 349, text("health_indicator_description"), 17, 744)
    if button(28, 403, 744, text("reset_personal")) then
        SetString(root .. "language", "en")
        SetString(root .. "menu_key", "p")
        SetBool(root .. "health_hud", false)
        capturing = false
        message = text("preferences_reset")
    end
    if button(28, 464, 744, text("reset_saved_host")) then
        confirming = true
        capturing = false
        message = nil
    end
    label(28, 518, text("reset_saved_host_help"), 17, 744)
    if message then label(28, 598, message, 17, 744) end
    if button(28, 658, 170, text("back")) then Menu() end
    label(610, 668, text("version", OSP.version), 16)
    if confirming then
        UiColor(0, 0, 0, 0.82)
        UiRect(width, height)
        UiPush()
        UiTranslate(30, 200)
        UiColor(0.105, 0.105, 0.099)
        UiRect(740, 280)
        label(22, 20, text("confirmation"), 26)
        label(22, 68, text("reset_saved_host_confirm"), 20, 696)
        if button(22, 216, 330, text("cancel"), false, true) then confirming = false end
        if button(366, 216, 350, text("confirm"), false, true) then
            -- Never clear the whole mod namespace: identity references must survive.
            local profiles = ListKeys(root .. "players")
            for _,key in ipairs({"rules", "tools", "players"}) do ClearKey(root .. key) end
            for _,id in ipairs(profiles) do
                if id:match("^p%d+$") then SetBool(root .. "players." .. id .. ".exists", true) end
            end
            confirming = false
            message = text("host_options_reset")
        end
        UiPop()
    end
    UiPop()
end
