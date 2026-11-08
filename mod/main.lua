#version 2
#include "scripts/common.lua"
#include "scripts/strings.lua"
#include "scripts/navigation.lua"
#include "scripts/view_mode.lua"
#include "scripts/settings_sections.lua"
#include "scripts/shortcuts.lua"
#include "scripts/number_input.lua"
#include "scripts/theme.lua"
#include "scripts/number_control.lua"
#include "scripts/permissions.lua"
#include "scripts/search_input.lua"
#include "scripts/permissions_ui.lua"
#include "scripts/strength.lua"
#include "scripts/ammo.lua"
#include "scripts/server.lua"
#include "scripts/tools_search.lua"
#include "scripts/ui.lua"

if server then OSP.installServer() end
if client then OSP.installClient() end
