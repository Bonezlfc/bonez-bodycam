---@diagnostic disable: undefined-global, duplicate-set-field, need-check-nil, undefined-field, lowercase-global
-- Bonez-Bodycam | client/menu.lua
-- Bodycam settings menu using the bundled FrazzIe NativeUI (client/NativeUI.lua).
-- Role-gated: only players whose Discord roles match Config.AdminRoles may open it.

-- ── Permissions ────────────────────────────────────────────────
playerPerms = {}   -- populated server-side via bodycam:perms event

Citizen.CreateThread(function()
    Citizen.Wait(500)
    if NetworkIsSessionStarted() then
        TriggerServerEvent('bodycam:checkPerms')
    end
end)

RegisterNetEvent('bodycam:perms')
AddEventHandler('bodycam:perms', function(roles)
    playerPerms = roles or {}
end)

-- ── Labels / keys ──────────────────────────────────────────────
BodycamMenu = {}

local STYLE_LABELS = { 'Axon', 'Motorola', 'Generic' }
local STYLE_KEYS   = { 'axon', 'motorola', 'generic' }
local POS_LABELS   = { 'Top Left', 'Top Right', 'Bottom Left', 'Bottom Right' }
local POS_KEYS     = { 'topleft',  'topright',  'bottomleft',  'bottomright'  }
local SCALE_LABELS = { 'Small', 'Medium', 'Large' }
local SCALE_KEYS   = { 'small', 'medium', 'large' }

local menuPool, mainMenu
local itErsStatus

-- ── Rebuild — clears and repopulates the menu with fresh items ──
-- Called on every Open() so list item indices are always correct.
-- (EUP-Menu pattern: menu:Clear() then re-add items)

local function Rebuild()
    mainMenu:Clear()

    -- Create items with current settings as initial index
    itErsStatus      = NativeUI.CreateItem('ERS Status', 'Shows whether night_ers is active.')
    local itEnabled  = NativeUI.CreateCheckboxItem('Enable Overlay',       Settings.enabled,      'Toggle the bodycam overlay.')
    local itStyle    = NativeUI.CreateListItem('Style',    STYLE_LABELS, IndexOf(STYLE_KEYS, Settings.style),    'Visual style of the overlay.')
    local itPosition = NativeUI.CreateListItem('Position', POS_LABELS,   IndexOf(POS_KEYS,   Settings.position), 'Screen corner for the overlay.')
    local itScale    = NativeUI.CreateListItem('Scale',    SCALE_LABELS, IndexOf(SCALE_KEYS, Settings.scale),    'Overlay text size.')
    local itShowSvc  = NativeUI.CreateCheckboxItem('Show Service Type',    Settings.showService,  'Show ERS service on overlay.')
    local itShowCO   = NativeUI.CreateCheckboxItem('Show Callout Status',  Settings.showCallout,  'Show CALLOUT badge.')
    local itShowTR   = NativeUI.CreateCheckboxItem('Show Tracking Status', Settings.showTracking, 'Show TRACKING badge.')
    local itShowUnit = NativeUI.CreateCheckboxItem('Show Unit ID',         Settings.showUnit,     'Show server ID as UNIT: X.')
    local itReset    = NativeUI.CreateItem('Reset to Defaults',            'Restore all settings to defaults.')
    local itClose    = NativeUI.CreateItem('Close',                        'Close this menu.')

    for _, it in ipairs({
        itErsStatus, itEnabled, itStyle, itPosition, itScale,
        itShowSvc, itShowCO, itShowTR, itShowUnit,
        itReset, itClose,
    }) do
        mainMenu:AddItem(it)
    end

    -- ── Per-item callbacks ──────────────────────────────────────

    itEnabled.CheckboxEvent  = function(_, _, v) Settings.enabled      = v  Settings.Save() end
    itShowSvc.CheckboxEvent  = function(_, _, v) Settings.showService  = v  Settings.Save() end
    itShowCO.CheckboxEvent   = function(_, _, v) Settings.showCallout  = v  Settings.Save() end
    itShowTR.CheckboxEvent   = function(_, _, v) Settings.showTracking = v  Settings.Save() end
    itShowUnit.CheckboxEvent = function(_, _, v) Settings.showUnit     = v  Settings.Save() end

    itStyle.OnListChanged    = function(_, _, i) Settings.style    = STYLE_KEYS[i]  Settings.Save() end
    itPosition.OnListChanged = function(_, _, i) Settings.position = POS_KEYS[i]   Settings.Save() end
    itScale.OnListChanged    = function(_, _, i) Settings.scale    = SCALE_KEYS[i] Settings.Save() end

    itReset.Activated = function()
        Settings.Reset()
        Rebuild()
    end

    itClose.Activated = function()
        mainMenu:Visible(false)
    end

    menuPool:RefreshIndex()
end

-- ── Menu init — runs once to create the pool + menu shell ──────

local initialized = false

local function Init()
    menuPool = NativeUI.CreatePool()
    mainMenu = NativeUI.CreateMenu('BODYCAM', 'Configure overlay settings')
    menuPool:Add(mainMenu)
    initialized = true

    -- Single render thread — created once, runs forever, cheap when menu is closed
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)
            if mainMenu:Visible() then
                if itErsStatus then
                    itErsStatus:RightLabel(ERSState.available and 'Active' or 'Not Detected')
                end
                menuPool:ProcessMenus()
            end
        end
    end)
end

-- ── Permission helper ──────────────────────────────────────────

local function HasAccess()
    if not Config.AdminRoles or #Config.AdminRoles == 0 then return true end
    for _, required in ipairs(Config.AdminRoles) do
        for _, role in ipairs(playerPerms) do
            if role == required then return true end
        end
    end
    return false
end

-- ── Public API ─────────────────────────────────────────────────

function BodycamMenu.Open()
    if not HasAccess() then
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName('~r~BODYCAM~s~: You do not have permission to access settings.')
        EndTextCommandThefeedPostTicker(false, true)
        return
    end

    if not initialized then Init() end
    Rebuild()
    mainMenu:Visible(true)
end
