#version 2
#include "scripts/common.lua"
#include "scripts/strings.lua"
#include "scripts/number_input.lua"
#include "scripts/theme.lua"
#include "scripts/permissions.lua"
#include "scripts/permissions_ui.lua"
#include "scripts/server.lua"
#include "scripts/ui.lua"

if server then OSP.installServer() end
if client then OSP.installClient() end
