
local _, addon = ...

local config = addon.Config
local logger = addon.Logger

local MAIN_HAND = config.Slots.MainHand
local OFF_HAND = config.Slots.OffHand

local Equipment = {}
Equipment.__index = Equipment

function Equipment:New()
    return setmetatable({
        Database = nil,
        IsRestoring = false,
        IsEquippingPole = false,
        PendingSlot = nil,
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

function Equipment:IsPoleEquipped()
    return GetInventoryItemID("player", MAIN_HAND) ==
        config.FishingPoleItemID
end

function Equipment:GetSavedEquipment()
    return self.Database and self.Database.SavedEquipment
end

function Equipment:RememberEquipment()
    if not self.Database or self:IsPoleEquipped() then
        return
    end

    self.Database.LastEquipment = self:GetCurrentEquipment()
end

function Equipment:Initialize(database)
    self.Database = database
    self.IsRestoring = false
    self.IsEquippingPole = false
    self.PendingSlot = nil
    self.ReconcileScheduled = false

    if not self:IsPoleEquipped() then
        database.SavedEquipment = nil
        self:RememberEquipment()
    end
end

function Equipment:Reset()
    if not self.Database then
        logger:Warn("Addon has not initialized yet.")
        return
    end

    self.Database.SavedEquipment = nil
    self.Database.LastEquipment = nil

    self.IsRestoring = false
    self.IsEquippingPole = false
    self.PendingSlot = nil

    logger:Info("Saved equipment has been reset.")

    if not self:IsPoleEquipped() then
        self:RememberEquipment()
    end
end

function Equipment:CanEquip()
    if InCombatLockdown and InCombatLockdown() then
        logger:Warn("Cannot switch equipment in combat.")
        return false
    end

    return true
end

function Equipment:RequestEquip(item, slot)
    if not item then
        return false
    end

    self.PendingSlot = slot
    C_Item.EquipItemByName(item, slot)

    return true
end

function Equipment:UnequipItem(slot)
    if not self:GetItem(slot) then
        return true
    end

    if CursorHasItem() then
        logger:Warn("Clear your cursor before unequipping.")
        return false
    end

    if C_Container.GetContainerNumFreeSlots(0) == 0 then
        logger:Warn("Your backpack is full.")
        return false
    end

    self.PendingSlot = slot

    PickupInventoryItem(slot)
    PutItemInBackpack()

    if CursorHasItem() then
        logger:Warn("Could not move the item into your backpack.")
        self.PendingSlot = nil
        return false
    end

    return true
end

function Equipment:IsRestored(saved)
    return saved.MainHand == self:GetItem(MAIN_HAND)
        and saved.OffHand == self:GetItem(OFF_HAND)
end

function Equipment:FinishRestoration()
    self.Database.SavedEquipment = nil

    self.IsRestoring = false
    self.IsEquippingPole = false
    self.PendingSlot = nil

    self:RememberEquipment()

    logger:Info("Equipment restored.")
end

function Equipment:ContinueRestoration()
    local saved = self:GetSavedEquipment()

    if not self.IsRestoring or not saved then
        return
    end

    if self:IsRestored(saved) then
        self:FinishRestoration()
        return
    end

    -- Wait for an outstanding equipment change.
    if self.PendingSlot then
        return
    end

    local mainHand = self:GetItem(MAIN_HAND)

    -- Restore the main hand first.
    if mainHand ~= saved.MainHand then
        if saved.MainHand then
            self:RequestEquip(saved.MainHand, MAIN_HAND)
        else
            self:UnequipItem(MAIN_HAND)
        end

        return
    end

    -- Restore the off hand only after the main hand matches.
    local offHand = self:GetItem(OFF_HAND)

    if offHand ~= saved.OffHand then
        if saved.OffHand then
            self:RequestEquip(saved.OffHand, OFF_HAND)
        else
            self:UnequipItem(OFF_HAND)
        end

        return
    end

    self:FinishRestoration()
end

function Equipment:RestoreEquipment()
    local saved = self:GetSavedEquipment()

    if not saved then
        return
    end

    self.IsRestoring = true
    self.IsEquippingPole = false

    -- A second toggle can retry a stalled request.
    self.PendingSlot = nil

    self:ContinueRestoration()
end

function Equipment:EquipFishingPole()
    if self:IsPoleEquipped() then
        logger:Info("Fishing Pole is already equipped.")
        return
    end

    self:RememberEquipment()

    self.Database.SavedEquipment =
        self:GetCurrentEquipment()

    self.IsEquippingPole = true
    self.PendingSlot = MAIN_HAND

    C_Item.EquipItemByName(
        config.FishingPoleItemID,
        MAIN_HAND
    )

    logger:Info("Equipping Fishing Pole.")
end

function Equipment:ReconcileEquipment()
    if not self.Database then
        return
    end

    if self.IsRestoring then
        self:ContinueRestoration()
        return
    end

    local saved = self:GetSavedEquipment()

    if self:IsPoleEquipped() then
        self.IsEquippingPole = false
        self.PendingSlot = nil

        -- The player may have equipped the pole manually.
        if not saved and self.Database.LastEquipment then
            local last = self.Database.LastEquipment

            self.Database.SavedEquipment = {
                MainHand = last.MainHand,
                OffHand = last.OffHand
            }
        end

        return
    end

    -- Don't interpret an intermediate equipment state
    -- as a manual weapon change while equipping the pole.
    if self.IsEquippingPole then
        return
    end

    -- A manually equipped weapon replaces the old loadout.
    if saved then
        self.Database.SavedEquipment = nil
        logger:Info("Equipment changed manually.")
    end

    self:RememberEquipment()
end

function Equipment:ScheduleReconciliation()
    if self.ReconcileScheduled then
        return
    end

    self.ReconcileScheduled = true

    -- Allow both equipment slots to settle before inspection.
    C_Timer.After(0.1, function()
        self.ReconcileScheduled = false
        self:ReconcileEquipment()
    end)
end

function Equipment:OnEquipmentChanged(slot)
    if slot ~= MAIN_HAND and slot ~= OFF_HAND then
        return
    end

    if slot == self.PendingSlot then
        self.PendingSlot = nil
    end

    self:ScheduleReconciliation()
end

function Equipment:Toggle()
    if not self.Database then
        logger:Warn("Addon has not initialized yet.")
        return
    end

    if not self:CanEquip() then
        return
    end

    -- Recover if an earlier pole-equip request did not complete.
    if self.IsEquippingPole and not self:IsPoleEquipped() then
        self.IsEquippingPole = false
        self.PendingSlot = nil
        self.Database.SavedEquipment = nil
    end

    if self:GetSavedEquipment() then
        self:RestoreEquipment()
    elseif self:IsPoleEquipped() then
        -- Recover a manually equipped pole when possible.
        self:ReconcileEquipment()

        if self:GetSavedEquipment() then
            self:RestoreEquipment()
        else
            logger:Warn("No previous equipment is available.")
        end
    else
        self:EquipFishingPole()
    end
end

addon.Equipment = Equipment:New()
