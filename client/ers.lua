-- ─────────────────────────────────────────────────────────────
--  client/ers.lua  —  ERS export wrappers + polling thread
-- ─────────────────────────────────────────────────────────────
--  Exposes a single global table: ERSState
--    .available       (bool) — night_ers resource is running
--    .onShift         (bool) — player is currently on shift
--    .serviceType     (str|nil) — active service ("FIRE", "EMS", etc.)
--    .attachedCallout (bool) — player is attached to a callout
--    .trackingUnit    (bool) — player is tracking a unit
--
--  The table is updated every Config.ERSPollInterval ms.
--  All export calls are pcall-wrapped so a bad export never
--  crashes the resource.
-- ─────────────────────────────────────────────────────────────

ERSState = {
    available       = false,
    onShift         = false,
    serviceType     = nil,
    attachedCallout = false,
    trackingUnit    = false,
}

-- ── helpers ──────────────────────────────────────────────────

-- Safe wrapper: calls fn, logs any error, returns (ok, result).  Never throws.
local function SafeExport(exportName, fn)
    local ok, result = pcall(fn)
    if not ok then
        ErrorPrint('ERS', 'Export call failed [' .. exportName .. ']: ' .. tostring(result))
    end
    return ok, result
end

-- ── change-tracking (for debug prints) ───────────────────────

local _prevAvail    = nil
local _prevShift    = nil
local _prevCallout  = nil
local _prevTracking = nil

-- ── poll ─────────────────────────────────────────────────────

local function PollERS()
    -- Bail immediately if the ERS resource isn't running
    if GetResourceState('night_ers') ~= 'started' then
        if ERSState.available ~= false then
            DebugPrint('ERS', 'night_ers stopped — ERS state cleared')
        end
        ERSState.available       = false
        ERSState.onShift         = false
        ERSState.serviceType     = nil
        ERSState.attachedCallout = false
        ERSState.trackingUnit    = false
        return
    end

    if not ERSState.available then
        DebugPrint('ERS', 'night_ers detected — starting polls')
    end
    ERSState.available = true

    local ok, val

    ok, val = SafeExport('getIsPlayerOnShift', function()
        return exports['night_ers']:getIsPlayerOnShift()
    end)
    ERSState.onShift = ok and (val == true) or false

    -- Only pull the detailed state when on shift — skip unnecessary calls
    if ERSState.onShift then
        ok, val = SafeExport('getPlayerActiveServiceType', function()
            return exports['night_ers']:getPlayerActiveServiceType()
        end)
        ERSState.serviceType = (ok and type(val) == 'string') and val or nil

        ok, val = SafeExport('getIsPlayerAttachedToCallout', function()
            return exports['night_ers']:getIsPlayerAttachedToCallout()
        end)
        ERSState.attachedCallout = ok and (val == true) or false

        ok, val = SafeExport('getIsPlayerTrackingUnit', function()
            return exports['night_ers']:getIsPlayerTrackingUnit()
        end)
        ERSState.trackingUnit = ok and (val == true) or false
    else
        ERSState.serviceType     = nil
        ERSState.attachedCallout = false
        ERSState.trackingUnit    = false
    end

    -- Debug: print only when state changes
    if ERSState.available ~= _prevAvail then
        DebugPrint('ERS', 'available → ' .. tostring(ERSState.available))
        _prevAvail = ERSState.available
    end
    if ERSState.onShift ~= _prevShift then
        DebugPrint('ERS', 'onShift → ' .. tostring(ERSState.onShift)
            .. (ERSState.serviceType and (' | service: ' .. ERSState.serviceType) or ''))
        _prevShift = ERSState.onShift
    end
    if ERSState.attachedCallout ~= _prevCallout then
        DebugPrint('ERS', 'attachedCallout → ' .. tostring(ERSState.attachedCallout))
        _prevCallout = ERSState.attachedCallout
    end
    if ERSState.trackingUnit ~= _prevTracking then
        DebugPrint('ERS', 'trackingUnit → ' .. tostring(ERSState.trackingUnit))
        _prevTracking = ERSState.trackingUnit
    end
end

-- ── polling thread ────────────────────────────────────────────

Citizen.CreateThread(function()
    while true do
        PollERS()
        Citizen.Wait(Config.ERSPollInterval)
    end
end)

-- ── Global helpers (used by main.lua and the NUI sync thread) ──────────────

-- Returns true when bonez-bodycam_evidence is actively recording.
-- Queries the evidence resource export; returns false if the evidence
-- resource is not running (overlay stays hidden when standalone).
function IsRecording()
    local ok, val = pcall(function()
        return exports['bonez-bodycam_evidence']:isRecording()
    end)
    return ok and val == true
end

-- Returns the player's server ID as the unit label.
function GetUnitLabel(uid)
    return tostring(uid)
end

-- Returns the active service-type label for overlay display.
-- Prefers the live ERS service type; falls back to the player's
-- manually-selected service type from the settings menu.
function GetActiveServiceType()
    if ERSState.serviceType and ERSState.serviceType ~= '' then
        return ERSState.serviceType
    end
    if Settings and Settings.manualServiceType and Settings.manualServiceType ~= '' then
        return Settings.manualServiceType
    end
    return nil
end
