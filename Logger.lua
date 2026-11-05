local _, addon = ...
local config = addon.Config.Logging

local Logger = {}
Logger.__index = Logger

function Logger:New()
    return setmetatable({}, self)
end

function Logger:Write(level, message)
    if level == "DEBUG" and not config.Debug then
        return
    end

    local colors = config.Colors
    local colorName = level:sub(1, 1) .. level:sub(2):lower()
    local color = colors[colorName] or colors.Info

    local prefix = ("|cff%s[%s]|r"):format(colors.Prefix, config.Prefix)

    if config.Debug then
        local label = ("|cff%s[%s]|r"):format(color, level)

        print(prefix .. " " .. label .. " " .. tostring(message))
    else
        print(prefix .. " " .. tostring(message))
    end
end

function Logger:Debug(message)
    self:Write("DEBUG", message)
end

function Logger:Info(message)
    self:Write("INFO", message)
end

function Logger:Warn(message)
    self:Write("WARN", message)
end

function Logger:Error(message)
    self:Write("ERROR", message)
end

addon.Logger = Logger:New()
