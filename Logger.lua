local _, addon = ...
local config = addon.Config.Logging

local Logger = {}
Logger.__index = Logger

function Logger:New()
    return setmetatable({}, self)
end

function Logger:Write(level, message)
    if (level == "DEBUG" or level == "INFO") and not config.Debug then
        return
    end

    local colors = config.Colors
    local color = colors[level:sub(1, 1) .. level:sub(2):lower()] or colors.Info

    print(("|cff%s[%s]|r |cff%s%s|r %s"):format(colors.Prefix, config.Prefix,
        color, level, tostring(message)))
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
