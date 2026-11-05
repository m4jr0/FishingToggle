local _, addon = ...

local config = addon.Config
local logger = addon.Logger
local L = addon.L

local MAIN_HAND = config.Slots.MainHand
local OFF_HAND = config.Slots.OffHand
local TIMEOUT = config.Equipment.OperationTimeout
local SETTLE_DELAY = config.Equipment.SettleDelay

local Equipment = {}
Equipment.__index = Equipment

function Equipment:New()
    return setmetatable({
        Database = nil,
        IsRestoring = false,
        IsEquippingPole = false,
        PendingOperation = nil,
        OperationSerial = 0,
        ReconcileSerial = 0,
        ReconcileScheduled = false
    }, self)
end

function Equipment:GetItem(slot)
    return GetInventoryItemLink("player", slot)
end

function Equipment:GetCurrentEquipment()
    return {
        MainHand = self:GetItem(MAIN_HAND),
        OffHand = self:GetItem(OFF_HAND)
    }
end

function Equipment:FormatEquipment(equipment)
    local items = {}

    if equipment.MainHand then
        table.insert(items, equipment.MainHand)
    end

    if equipment.OffHand then
        table.insert(items, equipment.OffHand)
    end

    return #items > 0 and table.concat(items, ", ") or nil
end

function Equipment:IsFishingPole(item)
    if not item then
        return false
    end

    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(item)
    return classID == config.Fishing.WeaponClassID
        and subclassID == config.Fishing.FishingPoleSubclassID
end

function Equipment:IsPoleEquipped()
    return self:IsFishingPole(self:GetItem(MAIN_HAND))
end

function Equipment:FindFishingPoleInBags()
    local bestPole, bestLevel, bestID = nil, -1, -1

    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local itemID = C_Container.GetContainerItemID(bag, slot)

            if itemID and self:IsFishingPole(itemID) then
                local link = C_Container.GetContainerItemLink(bag, slot)

                if link then
                    local _, _, _, itemLevel = C_Item.GetItemInfo(itemID)
                    itemLevel = itemLevel or -1

                    if itemLevel > bestLevel
                        or (itemLevel == bestLevel and itemID > bestID) then
                        bestPole, bestLevel, bestID = link, itemLevel, itemID
                    end
                end
            end
        end
    end

    return bestPole
end

function Equipment:GetSavedEquipment()
    return self.Database and self.Database.SavedEquipment
end

function Equipment:RememberEquipment()
    if self.Database and not self:IsPoleEquipped() then
        self.Database.LastEquipment = self:GetCurrentEquipment()
    end
end

function Equipment:CancelPending()
    self.OperationSerial = self.OperationSerial + 1
    self.PendingOperation = nil
end

function Equipment:Reset()
    if not self.Database then
        logger:Warn(L.ADDON_NOT_READY)
        return
    end

    self:CancelPending()
    self.ReconcileSerial = self.ReconcileSerial + 1
    self.ReconcileScheduled = false
    self.IsRestoring = false
    self.IsEquippingPole = false
    self.Database.SavedEquipment = nil
    self.Database.LastEquipment = nil

    if not self:IsPoleEquipped() then
        self:RememberEquipment()
    end

    logger:Info(L.RESET_COMPLETE)
end

function Equipment:Initialize(database)
    self.Database = database
    self:CancelPending()
    self.ReconcileSerial = self.ReconcileSerial + 1
    self.ReconcileScheduled = false
    self.IsRestoring = false
    self.IsEquippingPole = false

    local saved = self:GetSavedEquipment()

    if saved then
        if self:IsRestored(saved) then
            database.SavedEquipment = nil
        else
            -- Never discard a partially restored loadout on login.
            logger:Warn(L.RESTORATION_SAVED)
        end
    end

    if not self:IsPoleEquipped() and not database.SavedEquipment then
        self:RememberEquipment()
    end
end

function Equipment:CanEquip()
    if InCombatLockdown and InCombatLockdown() then
        logger:Warn(L.COMBAT_BLOCKED)
        return false
    end

    return true
end

function Equipment:IsRestored(saved)
    return saved.MainHand == self:GetItem(MAIN_HAND)
        and saved.OffHand == self:GetItem(OFF_HAND)
end

function Equipment:BeginOperation(slot, expected, isPole)
    self:CancelPending()
    local serial = self.OperationSerial

    self.PendingOperation = {
        Slot = slot,
        Expected = expected,
        IsPole = isPole or false
    }

    C_Timer.After(TIMEOUT, function()
        if serial ~= self.OperationSerial or not self.PendingOperation then
            return
        end

        self:CheckPending(true)
    end)
end

function Equipment:PendingMatches(operation)
    if operation.IsPole then
        local expectedID = C_Item.GetItemInfoInstant(operation.Expected)
        return self:IsPoleEquipped()
            and GetInventoryItemID("player", MAIN_HAND) == expectedID
    end

    return self:GetItem(operation.Slot) == operation.Expected
end

function Equipment:StopFailedOperation()
    local wasEquipping = self.IsEquippingPole
    self:CancelPending()
    self.IsRestoring = false
    self.IsEquippingPole = false

    -- If the fishing-pole request left the loadout unchanged, there is
    -- nothing to restore. Otherwise retain the saved state for retry/reset.
    local saved = self:GetSavedEquipment()
    if wasEquipping and saved and self:IsRestored(saved) then
        self.Database.SavedEquipment = nil
    end

    logger:Warn(L.EQUIPMENT_REQUEST_FAILED)
end

function Equipment:CheckPending(timedOut)
    local operation = self.PendingOperation
    if not operation then
        return false
    end

    if self:PendingMatches(operation) then
        self:CancelPending()

        if self.IsRestoring then
            self:ContinueRestoration()
        elseif self.IsEquippingPole then
            self:ReconcileEquipment()
        end

        return true
    end

    if timedOut then
        -- Do not keep forcing an old loadout after an unexpected change.
        self:StopFailedOperation()
    end

    return false
end

function Equipment:RequestEquip(item, slot, isPole)
    if not item or not self:CanEquip() then
        return false
    end

    self:BeginOperation(slot, item, isPole)
    C_Item.EquipItemByName(item, slot)
    return true
end

function Equipment:FindEmptyBagSlot()
    for bag = 0, NUM_BAG_SLOTS do
        local freeSlots, bagFamily = C_Container.GetContainerNumFreeSlots(bag)

        -- Only use ordinary bags, not profession/specialty bags.
        if freeSlots and freeSlots > 0 and (not bagFamily or bagFamily == 0) then
            for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
                if not C_Container.GetContainerItemID(bag, slot) then
                    return bag, slot
                end
            end
        end
    end

    return nil
end

function Equipment:UnequipItem(slot)
    if not self:GetItem(slot) then
        return true
    end

    if CursorHasItem() then
        logger:Warn(L.CLEAR_CURSOR)
        return false
    end

    local bag, bagSlot = self:FindEmptyBagSlot()
    if not bag then
        logger:Warn(L.BACKPACK_FULL)
        return false
    end

    self:BeginOperation(slot, nil, false)
    PickupInventoryItem(slot)

    if not CursorHasItem() then
        self:CancelPending()
        logger:Warn(L.BAG_MOVE_FAILED)
        return false
    end

    C_Container.PickupContainerItem(bag, bagSlot)

    if CursorHasItem() then
        -- Best-effort rollback to avoid leaving equipment on the cursor.
        PickupInventoryItem(slot)
        self:CancelPending()
        logger:Warn(L.BAG_MOVE_FAILED)
        return false
    end

    return true
end

function Equipment:FinishRestoration()
    local saved = self:GetSavedEquipment()
    local description = saved and self:FormatEquipment(saved)

    self:CancelPending()
    self.IsRestoring = false
    self.IsEquippingPole = false
    self.Database.SavedEquipment = nil
    self:RememberEquipment()

    if description then
        logger:Info(L.RESTORED:format(description))
    else
        logger:Info(L.RESTORED_EMPTY)
    end
end

function Equipment:ContinueRestoration()
    local saved = self:GetSavedEquipment()
    if not self.IsRestoring or not saved or self.PendingOperation then
        return
    end

    if self:IsRestored(saved) then
        self:FinishRestoration()
        return
    end

    if self:GetItem(MAIN_HAND) ~= saved.MainHand then
        local success
        if saved.MainHand then
            success = self:RequestEquip(saved.MainHand, MAIN_HAND)
        else
            success = self:UnequipItem(MAIN_HAND)
        end
        if not success then
            self.IsRestoring = false
        end
        return
    end

    if self:GetItem(OFF_HAND) ~= saved.OffHand then
        local success
        if saved.OffHand then
            success = self:RequestEquip(saved.OffHand, OFF_HAND)
        else
            success = self:UnequipItem(OFF_HAND)
        end
        if not success then
            self.IsRestoring = false
        end
        return
    end

    self:FinishRestoration()
end

function Equipment:RestoreEquipment()
    if not self:GetSavedEquipment() then
        return
    end

    self.IsRestoring = true
    self.IsEquippingPole = false
    self:ContinueRestoration()
end

function Equipment:EquipFishingPole()
    if self:IsPoleEquipped() then
        logger:Info(L.POLE_EQUIPPED_ALREADY)
        return
    end

    local fishingPole = self:FindFishingPoleInBags()
    if not fishingPole then
        logger:Warn(L.NO_POLE_IN_BAGS)
        return
    end

    self:RememberEquipment()
    self.Database.SavedEquipment = self:GetCurrentEquipment()
    self.IsEquippingPole = true

    if not self:RequestEquip(fishingPole, MAIN_HAND, true) then
        self.IsEquippingPole = false
        return
    end

    local description = self:FormatEquipment(self.Database.SavedEquipment)
    if description then
        logger:Info(L.EQUIPMENT_SAVED:format(description))
    end
end

function Equipment:ReconcileEquipment()
    if not self.Database then
        return
    end

    if self.PendingOperation then
        self:CheckPending(false)
        return
    end

    if self.IsRestoring then
        self:ContinueRestoration()
        return
    end

    local saved = self:GetSavedEquipment()
    if self:IsPoleEquipped() then
        if self.IsEquippingPole then
            logger:Info(L.POLE_EQUIPPED:format(self:GetItem(MAIN_HAND)))
        end

        self.IsEquippingPole = false
        if not saved and self.Database.LastEquipment then
            local last = self.Database.LastEquipment
            self.Database.SavedEquipment = {
                MainHand = last.MainHand,
                OffHand = last.OffHand
            }
        end
        return
    end

    if self.IsEquippingPole then
        -- An equip request may be in flight; the timeout handles failure.
        return
    end

    if saved then
        -- The player changed away from the pole; don't override the choice.
        self.Database.SavedEquipment = nil
        local description = self:FormatEquipment(self:GetCurrentEquipment())
        if description then
            logger:Info(L.EQUIPMENT_CHANGED_MANUALLY:format(description))
        else
            logger:Info(L.EQUIPMENT_CHANGED_EMPTY)
        end
    end

    self:RememberEquipment()
end

function Equipment:ScheduleReconciliation()
    if self.ReconcileScheduled then
        return
    end

    self.ReconcileScheduled = true
    local serial = self.ReconcileSerial

    C_Timer.After(SETTLE_DELAY, function()
        if serial ~= self.ReconcileSerial then
            return
        end
        self.ReconcileScheduled = false
        self:ReconcileEquipment()
    end)
end

function Equipment:OnEquipmentChanged(slot)
    if slot == MAIN_HAND or slot == OFF_HAND then
        self:ScheduleReconciliation()
    end
end

function Equipment:Toggle()
    if not self.Database then
        logger:Warn(L.ADDON_NOT_READY)
        return
    end

    if not self:CanEquip() then
        return
    end

    if self.PendingOperation then
        logger:Warn(L.EQUIPMENT_BUSY)
        return
    end

    if self.IsRestoring then
        self:ContinueRestoration()
    elseif self:GetSavedEquipment() then
        self:RestoreEquipment()
    elseif self:IsPoleEquipped() then
        self:ReconcileEquipment()
        if self:GetSavedEquipment() then
            self:RestoreEquipment()
        else
            logger:Warn(L.NO_PREVIOUS_EQUIPMENT)
        end
    else
        self:EquipFishingPole()
    end
end

addon.Equipment = Equipment:New()
