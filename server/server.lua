-- ─────────────────────────────────────────────────────────────
--  server/server.lua  —  bodycam state tracking + proximity beep
-- ─────────────────────────────────────────────────────────────
--
--  OneSync-safe design:
--    • Server tracks which players have an active bodycam.
--    • When a client requests a beep, the server calculates distance
--      to every other player SERVER-SIDE and only sends the event to
--      players within Config.BeepRange.  This means the beep event
--      is never broadcast across the whole map (no -1 TriggerClientEvent).
--    • GetEntityCoords on the server works for all peds under OneSync
--      (Infinity or Legacy) because the server tracks all entity positions.
-- ─────────────────────────────────────────────────────────────

-- [serverId] = { name = string, callsign = string|nil }
local activeCams = {}

-- ── State sync ───────────────────────────────────────────────

-- Client fires this whenever its active state changes.
-- "active" = overlay enabled AND player is recording.
RegisterNetEvent('bodycam:setActive', function(active)
    local src = source
    if active then
        activeCams[src] = {
            name = GetPlayerName(src) or '',
        }
    else
        activeCams[src] = nil
    end
end)

-- ── Proximity beep ───────────────────────────────────────────

-- Client fires this periodically while the bodycam is active.
-- Server checks the state, calculates distances, and sends the
-- playBeep event ONLY to players within range.
RegisterNetEvent('bodycam:requestBeep', function()
    local src = source

    -- Reject if the server doesn't think this player's cam is active
    -- (guards against spoofed events)
    if not activeCams[src] then return end

    local srcPed    = GetPlayerPed(src)
    local srcCoords = GetEntityCoords(srcPed)

    -- Config.BeepRange is a shared_script value; fall back to 15m if absent
    local range = (Config and Config.BeepRange) or 15.0

    for _, pidStr in ipairs(GetPlayers()) do
        local pid    = tonumber(pidStr) or 0
        local ped    = GetPlayerPed(pid)
        local coords = GetEntityCoords(ped)

        local dx   = srcCoords.x - coords.x
        local dy   = srcCoords.y - coords.y
        local dz   = srcCoords.z - coords.z
        local dist = math.sqrt(dx*dx + dy*dy + dz*dz)

        if dist <= range then
            -- Pass source coords so the client can do its own fade-by-distance
            TriggerClientEvent('bodycam:playBeep', pid,
                               srcCoords.x, srcCoords.y, srcCoords.z, range)
        end
    end
end)

-- ── Discord role permission check ────────────────────────────
--
-- Client fires bodycam:checkPerms on resource start.
-- Server fetches the player's Discord roles and sends them back.
-- Client stores them in playerPerms and gates menu access against
-- Config.AdminRoles.

RegisterNetEvent('bodycam:checkPerms')
AddEventHandler('bodycam:checkPerms', function()
    local src   = source
    local roles = GetPlayerRoles(src)
    TriggerClientEvent('bodycam:perms', src, roles or {})
end)

-- ── Search exports ───────────────────────────────────────────
--
-- Used by bonez-bodycam_evidence (and any external resource) to
-- look up which players currently have an active bodycam.

-- Returns a table of { serverId, name } for all active cams.
exports('getActiveCams', function()
    local result = {}
    for sid, data in pairs(activeCams) do
        table.insert(result, {
            serverId = sid,
            name     = data.name,
        })
    end
    return result
end)

-- Returns the entry for the first active cam whose player name contains
-- the given string (case-insensitive), or nil if not found.
exports('findCamByName', function(nameQuery)
    local q = tostring(nameQuery or ''):lower()
    for sid, data in pairs(activeCams) do
        if data.name:lower():find(q, 1, true) then
            return { serverId = sid, name = data.name }
        end
    end
    return nil
end)

-- ── Server time sync ─────────────────────────────────────────
--
-- Client requests the server's local wall-clock time so the overlay
-- always shows the server machine's time regardless of the client's timezone.
-- We send an adjusted epoch: os.time() shifted by the server's UTC offset
-- so that JS Date.getUTC*() methods return the server's local time.

RegisterNetEvent('bodycam:requestServerTime')
AddEventHandler('bodycam:requestServerTime', function()
    local src     = source
    local t_local = os.date('*t')   -- server local time components
    local t_utc   = os.date('!*t')  -- UTC time components
    local tz_offset = (t_local.hour * 3600 + t_local.min * 60 + t_local.sec)
                    - (t_utc.hour   * 3600 + t_utc.min   * 60 + t_utc.sec)
    -- Clamp across midnight boundaries
    if tz_offset >  43200 then tz_offset = tz_offset - 86400 end
    if tz_offset < -43200 then tz_offset = tz_offset + 86400 end
    -- adjusted_epoch: when read as UTC gives the server's local time
    TriggerClientEvent('bodycam:serverTime', src, os.time() + tz_offset)
end)

-- ── Clean up on disconnect ───────────────────────────────────

AddEventHandler('playerDropped', function()
    activeCams[source] = nil
end)
