local _, addon = ...

addon.Config = {
    FishingPoleItemID = 6256,

    Slots = {
        MainHand = 16,
        OffHand = 17
    },

    Logging = {
        Debug = false,
        Prefix = "FishingToggle",
        Colors = {
            Prefix = "66ccff",
            Debug = "aaaaaa",
            Info = "ffffff",
            Warn = "ffcc66",
            Error = "ff6666"
        }
    }
}
