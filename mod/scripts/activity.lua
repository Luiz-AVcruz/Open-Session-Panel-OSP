-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Session activity formatting and local filtering. This module never writes
-- shared state or sends gameplay commands.
OSP.Activity = {}

local A = OSP.Activity

A.actionKeys = {
    heal="heal",kill="kill",respawn="respawn",["goto"]="go_to",bring="bring",eject="eject",
    god="god_mode",fly="fly",fly_speed="fly_normal_action",fly_boost="fly_shift_action",
    noclip_speed="noclip_normal_action",noclip_boost="noclip_shift_action",noclip="noclip",
    freeze="freeze",strength="strength",ammo="ammo",ammo_restore="ammo_restore",
    strength_force="strength_force_label",strength_mass="strength_mass_label",strength_throw="strength_throw",
    strength_throw_speed="strength_throw_speed_label",speed="speed",effects_off_on_load="effects_on_load",
    collective_future="collective_actions",players_group="collective_actions",
    roles_assign_many="role_assignment_title",admin="admin_access",role_assign="permissions",
    role_save="permissions",role_delete="permissions",role_reset="permissions",reset_player="reset_player",
    heal_all="heal_all",bring_all="bring_all",rule="session_rules",reset_rules="reset_rules",
    restart="restart",announce="announcement",tool="tools",tool_all="tools",tools="tools",
    tools_all="tools",tool_policy="global_rules",tool_policy_bulk="global_rules",
    tool_policy_selection="global_rules",tool_conflict_mode="compatibility_title",
    tools_selection="tools",tools_selection_all="tools",tools_filtered="tools",tools_filtered_all="tools",
}

A.actionOrder = {
    "heal","kill","respawn","go_to","bring","eject","god_mode","fly","fly_normal_action",
    "fly_shift_action","noclip_normal_action","noclip_shift_action","noclip","freeze","strength",
    "ammo","ammo_restore","strength_force_label","strength_mass_label","strength_throw",
    "strength_throw_speed_label","speed","effects_on_load","collective_actions","role_assignment_title",
    "admin_access","permissions","reset_player","heal_all","bring_all","session_rules","reset_rules",
    "restart","announcement","tools","global_rules","compatibility_title","status",
}

function A.resultKey(result)
    if result == "ok" then return "done" end
    if result == "partial" then return "result_partial" end
    return "error_short"
end

function A.actionKey(action)
    return A.actionKeys[action] or "status"
end

function A.namedRole(templates, id)
    for _, role in ipairs(templates or {}) do
        if role.id == id then return OSP.Permissions.name(role) end
    end
    return id
end

function A.detailText(e, s, T, toolName, clip)
    local key = A.actionKey(e.action)
    local detail = T(key)
    if type(e.argument) == "table" then
        local a = e.argument
        if e.action == "players_group" then
            local action = T(a.action == "god" and "god_short" or a.action or "collective_actions")
            local scope = T("group_scope_" .. tostring(a.scope or "all"))
            detail = T("group_activity", action) .. " · " .. scope
            if a.role then detail = detail .. " · " .. A.namedRole(s and s.templates, a.role) end
            if type(a.enabled) == "boolean" then detail = detail .. " · " .. T(a.enabled and "group_state_on" or "group_state_off") end
        elseif e.action == "roles_assign_many" then
            detail = T("role_batch_activity", A.namedRole(s and s.templates, a.role or "?"))
        elseif a.key then
            local ruleNames = {time="time_scale",rain="rain",fog="fog",regen="regeneration"}
            detail = T(ruleNames[a.key] or "session_rules")
            local value = a.value
            if type(value) == "boolean" then value = T(value and "on" or "off")
            elseif OSP.finite(value) then
                if a.key == "rain" then value = tostring(math.floor(value * 100 + .5)) .. "%"
                elseif a.key == "fog" then value = tostring(value) .. " m"
                elseif a.key == "time" then value = tostring(value) .. "×" end
            end
            detail = detail .. " · " .. tostring(value)
        else
            if a.enabled ~= nil then detail = detail .. " · " .. T(a.enabled and "on" or "off") end
            if a.mode then
                detail = e.action == "tool_conflict_mode" and T("compatibility_title") .. " · " .. T("compatibility_mode_" .. a.mode)
                    or T("policy_" .. a.mode)
            end
            if a.id then
                local name = a.id
                for _, tool in ipairs(s and s.tools or {}) do
                    if tool.id == a.id then name = toolName(tool); break end
                end
                detail = detail .. " · " .. name
            end
            if a.category then detail = detail .. " · " .. T("filter_" .. a.category) end
            if a.tools then detail = detail .. " · " .. T("tools_selection_count", a.tools) end
        end
    elseif type(e.argument) == "boolean" then detail = detail .. " · " .. T(e.argument and "on" or "off")
    elseif type(e.argument) == "number" then detail = detail .. " · " .. tostring(e.argument)
    elseif type(e.argument) == "string" then detail = detail .. " · " .. (clip and clip(e.argument, 64) or e.argument) end
    return detail
end

function A.actionOptions(log, selected, T)
    local items, seen = {{id="all", label=T("activity_all_actions")}}, {all=true}
    local present={}
    for i=1,#(type(log)=="table" and log or {}) do
        local entry=log[i]
        if type(entry)=="table" then present[A.actionKey(entry.action)]=true end
    end
    if type(selected)=="string" and selected~="all" then present[selected]=true end
    for _, key in ipairs(A.actionOrder) do
        if present[key] and not seen[key] then
            items[#items + 1] = {id=key, label=T(key)}
            seen[key] = true
        end
    end
    for key in pairs(present) do
        if not seen[key] then items[#items+1]={id=key,label=T(key)};seen[key]=true end
    end
    return items
end

function A.addPlayerName(names, seen, value)
    if type(value) ~= "string" or value == "" or value == "?" or value == "—" or seen[value] then return end
    seen[value] = true
    names[#names + 1] = value
end

function A.playerOptionId(name)
    return "player:" .. tostring(name or "")
end

function A.playerFromOptionId(id)
    if type(id) ~= "string" or id:sub(1, 7) ~= "player:" then return nil end
    return id:sub(8)
end

function A.playerOptions(log, selected, T)
    local names, seen = {}, {}
    for i = 1, #(type(log) == "table" and log or {}) do
        local e = log[i]
        if type(e) == "table" then
            A.addPlayerName(names, seen, e.actor)
            A.addPlayerName(names, seen, e.target)
        end
    end
    if type(selected) == "string" and selected ~= "" and not seen[selected] then
        A.addPlayerName(names, seen, selected)
    end
    table.sort(names, function(a, b)
        local fa, fb = OSP.SearchInput.fold(a), OSP.SearchInput.fold(b)
        if fa == fb then return a < b end
        return fa < fb
    end)
    local items = {{id="all", label=T("activity_all_players")}}
    for _, name in ipairs(names) do items[#items + 1] = {id=A.playerOptionId(name), label=name} end
    return items
end

function A.new()
    local search = OSP.SearchInput.new()
    local state = {search=search, action="all", player=nil, order="desc"}
    function state.setAction(id)
        if id ~= "all" and type(id) ~= "string" then return false end
        if state.action == id then return false end
        state.action = id
        return true
    end
    function state.setPlayer(name)
        if name == "" then name = nil end
        if name ~= nil and type(name) ~= "string" then return false end
        if state.player == name then return false end
        state.player = name
        return true
    end
    function state.toggleOrder()
        state.order = state.order == "desc" and "asc" or "desc"
        return state.order
    end
    function state.isDefault()
        return state.search.query == "" and state.action == "all" and state.player == nil and state.order == "desc"
    end
    function state.reset()
        local changed = not state.isDefault() or state.search.focused
        state.search.clear(); state.search.blur()
        state.action="all";state.player=nil;state.order="desc"
        return changed
    end
    function state.snapshot()
        return {query=state.search.query,focused=state.search.focused,action=state.action,player=state.player,order=state.order}
    end
    return state
end

function A.filtered(log, state, s, T, toolName, clip)
    local rows, ordered = {}, {}
    log = type(log) == "table" and log or {}
    for i = 1, #log do
        local entry = log[i]
        if type(entry) == "table" then
            local sequence=entry.seq
            if not OSP.finite(sequence) then sequence=i end
            ordered[#ordered + 1] = {entry=entry,index=i,sequence=sequence}
        end
    end
    table.sort(ordered, function(a, b)
        if a.sequence == b.sequence then return a.index < b.index end
        if state.order == "asc" then return a.sequence < b.sequence end
        return a.sequence > b.sequence
    end)
    local query=OSP.SearchInput.fold(state.search.query)
    for _, item in ipairs(ordered) do
        local e = item.entry
        local key = A.actionKey(e.action)
        local actor = tostring(e.actor or "?")
        local target = type(e.target) == "string" and e.target ~= "" and e.target or "—"
        local matches = (state.action == "all" or state.action == key)
            and (state.player == nil or actor == state.player or target == state.player)
        if matches then
            local detail = A.detailText(e, s, T, toolName, clip)
            local outcomeKey = A.resultKey(e.result)
            local outcome = T(outcomeKey)
            local counts = T("counts_short", e.affected or 0, e.skipped or 0)
            local conflicts = tonumber(e.inventoryConflicts) or 0
            if conflicts > 0 then counts = counts .. " · " .. T("tool_inventory_count", conflicts) end
            local sequence = tostring(e.seq or "?")
            if query~="" then
                local idText=T("activity_id",sequence)
                local searchable = table.concat({actor, target, detail, outcome, counts, idText, sequence, tostring(e.action or "")}, " ")
                matches=state.search.matches(searchable,"",query)
            end
            if matches then
                rows[#rows + 1] = {entry=e,actor=actor,target=target,actionKey=key,detail=detail,
                    outcomeKey=outcomeKey,outcome=outcome,counts=counts,sequence=sequence,index=item.index}
            end
        end
    end
    return rows
end
