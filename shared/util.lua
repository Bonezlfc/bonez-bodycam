-- ─────────────────────────────────────────────────────────────
--  shared/util.lua  —  helpers available to all client modules
-- ─────────────────────────────────────────────────────────────

--- Returns two formatted strings: date ("YYYY-MM-DD") and time ("HH:MM:SS")
--- Uses GetLocalTime() — the FiveM-safe way to read the client's system clock.
--- (os.date is not available in FiveM's Lua sandbox)
function GetDateTimeStrings()
    local hour, minute, second, day, month, year = GetLocalTime()
    local date = string.format('%04d-%02d-%02d', year, month, day)
    local time = string.format('%02d:%02d:%02d', hour, minute, second)
    return date, time
end

--- Find the 1-based index of a value in an array, or return 1 if not found.
function IndexOf(tbl, value)
    for i, v in ipairs(tbl) do
        if v == value then return i end
    end
    return 1
end

--- Clamp a number between lo and hi.
function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

--- Returns the active service type string, or nil if none.
--- Prefers ERS state; falls back to the player's manual setting.
function GetActiveServiceType()
    if ERSState and ERSState.serviceType then return ERSState.serviceType end
    if Settings and Settings.manualServiceType and Settings.manualServiceType ~= '' then
        return Settings.manualServiceType
    end
    return nil
end

--- Returns the callsign from ERS/MDT if available, otherwise the raw unit ID.
function GetUnitLabel(uid)
    if ERSState and ERSState.callsign and ERSState.callsign ~= '' then
        return ERSState.callsign
    end
    return uid
end

--- Returns true when the bodycam should be in the recording state.
--- Respects manualRecording mode and ERS on-shift state.
function IsRecording()
    if not Settings or not Settings.enabled then return false end
    if Settings.manualRecording then
        if ERSState and ERSState.available then
            return ERSState.onShift and Settings.recording
        else
            return Settings.recording == true
        end
    else
        return ERSState and ERSState.onShift or false
    end
end
