local addonName, addon = ...

local Macro = {}
addon.Macro = Macro

local DEFAULT_MACRO_NAME = "FishingToggle"
local MACRO_ICON = "INV_Fishingpole_02"

local MACRO_BODY = table.concat({"#showtooltip 6256",
                                 "/run FishingToggle.Toggle()"}, "\n")

function Macro:Create(name, isGeneral)
    name = name or DEFAULT_MACRO_NAME

    if isGeneral == nil then
        isGeneral = true
    end

    if InCombatLockdown() then
        addon.Logger:Warn("Cannot create macros in combat.")
        return
    end

    if GetMacroIndexByName(name) > 0 then
        addon.Logger:Warn("A macro named " .. name .. " already exists.")
        return
    end

    local macroID = CreateMacro(name, MACRO_ICON, MACRO_BODY, not isGeneral)

    if macroID then
        addon.Logger:Info("Macro created! Open /macro to find it.")
    else
        addon.Logger:Error("Could not create the macro.")
    end
end
