local _, addon = ...
local logger = addon.Logger
local L = addon.L
local equipment = addon.Equipment

local function OnPlayerLogin()
    FishingToggleDB = FishingToggleDB or {}
    equipment:Initialize(FishingToggleDB)
end

local function OnEquipmentChanged(slot)
    equipment:OnEquipmentChanged(slot)
end

local EventHandlers = {
    PLAYER_LOGIN = OnPlayerLogin,
    PLAYER_EQUIPMENT_CHANGED = OnEquipmentChanged
}

local function OnEvent(_, event, ...)
    local handler = EventHandlers[event]
    if handler then
        handler(...)
    else
        logger:Warn(L.UNHANDLED_EVENT:format(tostring(event)))
    end
end

local function OnSlashCommand(command)
    command = (command or ""):match("^%s*(.-)%s*$")

    if command == "" then
        equipment:Toggle()
        return
    end

    local action, argument = command:match("^(%S+)%s*(.-)$")

    if action:lower() == "macro" then
        local isGeneral = true

        local scope, name = argument:match("^(%S+)%s*(.-)$")

        if scope and scope:lower() == "character" then
            isGeneral = false
            argument = name
        end

        addon.Macro:Create(argument ~= "" and argument or nil, isGeneral)

    elseif action:lower() == "reset" then
        equipment:Reset()

    else
        logger:Warn(L.UNKNOWN_COMMAND:format(command))
    end
end

local function Initialize()
    local frame = CreateFrame("Frame")

    for event in pairs(EventHandlers) do
        frame:RegisterEvent(event)
    end

    frame:SetScript("OnEvent", OnEvent)

    FishingToggle = {
        Toggle = function()
            equipment:Toggle()
        end
    }

    SLASH_FISHINGTOGGLE1 = "/fishingtoggle"
    SlashCmdList["FISHINGTOGGLE"] = OnSlashCommand
end

Initialize()
