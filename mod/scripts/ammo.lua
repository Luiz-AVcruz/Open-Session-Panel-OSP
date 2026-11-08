-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Infinite-ammo state is transient and belongs to one player entry and tool.
OSP.Ammo = {}

local function finite(value)
    return type(value)=="number" and value==value and value>-math.huge and value<math.huge
end

local function registered(tool)
    return type(tool)=="string" and tool~="" and tool~="none"
        and type(HasKey)=="function" and HasKey("game.tool."..tool)
end

function OSP.Ammo.new()
    local entries={}

    local function entryFor(p,e)
        local entry=entries[p]
        if not entry or entry.challenge~=e.challenge then
            -- Player IDs can be reused. Never apply an old occupant's baseline
            -- to a new join, even if the server has not reported removal yet.
            entry={challenge=e.challenge,tools={}}
            entries[p]=entry
        end
        return entry
    end

    local function discardMissing(entry)
        for tool in pairs(entry.tools) do
            if not registered(tool) then entry.tools[tool]=nil end
        end
    end

    local function restore(p,entry,shouldRestore)
        if shouldRestore and type(GetToolAmmo)=="function" and type(SetToolAmmo)=="function" then
            for tool,snapshot in pairs(entry.tools) do
                if snapshot.touched and registered(tool) then
                    local current=GetToolAmmo(tool,p)
                    -- Negative and non-finite values are native sentinels (or
                    -- invalid data); do not overwrite them.
                    if finite(current) and current>=0 then
                        SetToolAmmo(tool,snapshot.original,p)
                    end
                end
            end
        end
        entries[p]=nil
    end

    local controller={}

    function controller:tick(p,e)
        if type(e)~="table" then self:remove(p);return end
        local previous=entries[p]
        if previous and previous.challenge~=e.challenge then
            -- Do this before inactive/death cleanup too: those paths must not
            -- restore an old occupant's baseline onto a reused player ID.
            entries[p]=nil
        end
        if e.ammo~=true then self:stop(p,e.ammoRestore==true);return end
        if type(GetPlayerHealth)~="function" or GetPlayerHealth(p)<=0 then
            self:stop(p,e.ammoRestore==true)
            return
        end

        local entry=entryFor(p,e)
        discardMissing(entry)
        if type(GetPlayerTool)~="function" or type(IsToolEnabled)~="function"
            or type(GetToolAmmo)~="function" or type(SetToolAmmo)~="function" then return end

        local tool=GetPlayerTool(p)
        if not registered(tool) or not IsToolEnabled(tool,p) then return end
        local ammo=GetToolAmmo(tool,p)
        if not finite(ammo) or ammo<0 then return end

        local snapshot=entry.tools[tool]
        if not snapshot then
            -- Capture at first eligible observation, before a later depletion
            -- can make the original reserve impossible to infer.
            snapshot={original=ammo,touched=false}
            entry.tools[tool]=snapshot
        end
        local reserve=math.max(snapshot.original,9999)
        if ammo<reserve then
            SetToolAmmo(tool,reserve,p)
            snapshot.touched=true
        end
    end

    function controller:stop(p,shouldRestore)
        local entry=entries[p]
        if entry then restore(p,entry,shouldRestore==true) end
    end

    function controller:remove(p)
        -- Removal can mean that the numeric player ID already belongs to a new
        -- occupant. Drop snapshots without calling any game setter.
        entries[p]=nil
    end

    function controller:reset()
        entries={}
    end

    return controller
end
