local _, addon = ...

addon.Config = {
    Fishing = {
        WeaponClassID = 2,
        FishingPoleSubclassID = 20
    },

    Slots = {
        MainHand = 16,
        OffHand = 17
    },

    Equipment = {
        SettleDelay = 0.15,
        OperationTimeout = 2.0
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
