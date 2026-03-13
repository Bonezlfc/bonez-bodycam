-- ─────────────────────────────────────────────────────────────
--  shared/util.lua  —  helpers available to all scripts
-- ─────────────────────────────────────────────────────────────

--- Debug print — outputs to the F8 / txAdmin console when Config.Debug is true.
--- tag  : short label shown in brackets, e.g. 'ERS', 'MAIN', 'MENU'
--- msg  : message string (or any value — tostring is applied)
function DebugPrint(tag, msg)
    if not Config or not Config.Debug then return end
    print(string.format('^5[BC:%s] %s^7', tostring(tag), tostring(msg)))
end

--- Always-on error print — shown regardless of Config.Debug.
--- Use for genuine unexpected failures (export crashes, nil where not expected).
function ErrorPrint(tag, msg)
    print(string.format('^1[BC:%s] ERROR: %s^7', tostring(tag), tostring(msg)))
end

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
