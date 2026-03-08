-- Bonez-Bodycam | server/discord.lua
-- Discord API helpers for role-based permission checks.
-- Requires configS.bot_token and configS.server_id (set in server/svConfig.lua).

local FormattedToken = "Bot " .. configS.bot_token

local function DiscordRequest(method, endpoint, jsondata)
    local data = nil
    PerformHttpRequest(
        "https://discordapp.com/api/" .. endpoint,
        function(errorCode, resultData, resultHeaders)
            data = { data = resultData, code = errorCode, headers = resultHeaders }
        end,
        method,
        #jsondata > 0 and json.encode(jsondata) or "",
        { ["Content-Type"] = "application/json", ["Authorization"] = FormattedToken }
    )
    while data == nil do Citizen.Wait(0) end
    return data
end

function GetDiscordId(player)
    for _, id in ipairs(GetPlayerIdentifiers(player)) do
        local match = string.match(id, "discord:(.+)")
        if match then return match end
    end
    return nil
end

function GetPlayerRoles(player)
    local discordId = GetDiscordId(player)
    if not discordId then return false end

    local endpoint = ("guilds/%s/members/%s"):format(configS.server_id, discordId)
    local member   = DiscordRequest("GET", endpoint, {})
    Citizen.Wait(100)

    if member.code == 200 then
        local data = json.decode(member.data)
        return data and data.roles or false
    end
    return false
end

-- Verify the bot can reach the guild on startup
Citizen.CreateThread(function()
    local guild = DiscordRequest("GET", "guilds/" .. configS.server_id, {})
    if guild.code == 200 then
        local data = json.decode(guild.data)
        print(("^2[Bonez-Bodycam]^7 Discord connected — guild: %s (%s)"):format(data.name, data.id))
    else
        print(("^1[Bonez-Bodycam]^7 Discord connection failed (code %s). Check svConfig.lua."):format(tostring(guild.code)))
    end
end)
