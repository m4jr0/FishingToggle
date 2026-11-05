local _, addon = ...

local L = addon.L
local logger = addon.Logger

local Macro = {}
addon.Macro = Macro

local DEFAULT_MACRO_NAME = "FishingToggle"
local MACRO_ICON = "INV_Fishingpole_02"
local MAX_MACRO_NAME_BYTES = 16

local MACRO_BODY = table.concat({
    "#showtooltip 6256",
    "/run FishingToggle.Toggle()"
}, "\n")

function Macro:Create(name, isGeneral)
    name = name or DEFAULT_MACRO_NAME
    if isGeneral == nil then
        isGeneral = true
    end

    if type(name) ~= "string" or #name == 0
        or #name > MAX_MACRO_NAME_BYTES or name:find("[%c]", 1) then
        logger:Warn(L.MACRO_INVALID_NAME)
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        logger:Warn(L.MACRO_COMBAT)
        return
    end

    if GetMacroIndexByName(name) > 0 then
        logger:Warn(L.MACRO_EXISTS:format(name))
        return
    end

    local globalCount, characterCount = GetNumMacros()
    local limit = isGeneral and MAX_ACCOUNT_MACROS or MAX_CHARACTER_MACROS
    local count = isGeneral and globalCount or characterCount

    if limit and count and count >= limit then
        logger:Warn(L.MACRO_LIMIT_REACHED)
        return
    end

    local success, macroID = pcall(
        CreateMacro, name, MACRO_ICON, MACRO_BODY, not isGeneral
    )

    if success and macroID then
        logger:Info(L.MACRO_CREATED)
    else
        logger:Error(L.MACRO_FAILED)
    end
end
