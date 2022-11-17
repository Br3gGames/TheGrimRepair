-- TODO: Check conventions https://github.com/luarocks/lua-style-guide
-- TODO: Remove unused Ace3 Libs
TheGrimRepair = LibStub("AceAddon-3.0"):NewAddon("TGR", "AceConsole-3.0", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("TGR", true)

local defaults = {
    profile = {
        is_using_guild_repairs = true,
        is_selling_gray_items = true,
        is_showing_sale_details = true,
        is_keeping_transmog_items = true,
    }
}

local options = {
    name = "TheGrimRepair",
    handler = TheGrimRepair,
    type = "group",
    args = {
        desc = {
            order = 1,
            type = "description",
            name = L["MSG_TIP_DISABLE"],
        },
        group_repair = {
            order = 2,
            type = "group",
            inline = true,
            name = L["AUTO_REPAIR_HEADER"],
            args = {
                guild_repairs = {
                    order = 1,
                    type = "toggle",
                    name = L["USE_GUILD_REPAIRS_HEADER"],
                    desc = L["USE_GUILD_REPAIRS_DESC"],
                    get = "is_using_guild_repairs",
                    set = "toggle_guild_repairs",
                },
            },
        },
        group_sell = {
            order = 3,
            type = "group",
            inline = true,
            name = L["AUTO_SELL_HEADER"],
            args = {
                sell_gray_items = {
                    order = 1,
                    type = "toggle",
                    name = L["SELL_GRAY_HEADER"],
                    desc = L["SELL_GRAY_DESC"],
                    get = "is_selling_gray_items",
                    set = "toggle_sell_gray_items",
                },
                moreoptions = {
                    order = 2,
                    type = "group",
                    name = L["SELLING_RESTRICTIONS_HEADER"],
                    disabled = "is_selling_disabled",
                    args = {
                        keep_transmog_items = {
                            order = 1,
                            width = "double",
                            type = "toggle",
                            name = L["KEEP_GRAY_HEADER"],
                            desc = L["KEEP_GRAY_DESC"],
                            get = "is_keeping_transmog_items",
                            set = "toggle_keeping_transmog_items",
                        },
                    },
                },
                show_sale_details = {
                    order = 3,
                    type = "toggle",
                    name = L["SALE_DETAILS_HEADER"],
                    desc = L["SALE_DETAILS_DESC"],
                    disabled = "is_selling_disabled",
                    get = "is_showing_sale_details",
                    set = "toggle_show_sale_details",
                },
            },
        },
    },
}

function TheGrimRepair:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("TheGrimRepairDB", defaults, true)
    LibStub("AceConfig-3.0"):RegisterOptionsTable("TheGrimRepair", options)
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("TheGrimRepair", "TheGrimRepair")

    local profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
    LibStub("AceConfig-3.0"):RegisterOptionsTable("TheGrimRepair_Profiles", profiles)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("TheGrimRepair_Profiles", "Profiles", "TheGrimRepair")

    self:RegisterChatCommand("tgr", "slash_command")
    self:RegisterChatCommand("thegrimrepair", "slash_command")
end

function TheGrimRepair:OnEnable()
    self:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
end

function TheGrimRepair:OnDisable()
    -- Called when the addon is disabled
end

function TheGrimRepair:PLAYER_INTERACTION_MANAGER_FRAME_SHOW(event, typeId)
    -- Hold shift to disable the addon during this interaction
    if IsShiftKeyDown() then
        self:Print(L["MSG_SKIPPED"])
        return
    end

    -- Check for a merchant frame
    if typeId == Enum.PlayerInteractionType.Merchant then
        self:auto_repair()
        self:auto_sell()
    end
end

function TheGrimRepair:is_using_guild_repairs(info)
    return self.db.profile.is_using_guild_repairs
end

function TheGrimRepair:toggle_guild_repairs(info, value)
    self.db.profile.is_using_guild_repairs = value
end

function TheGrimRepair:auto_repair()
    local repair_cost, is_repair_needed = GetRepairAllCost()
    local is_repair_merchant = CanMerchantRepair()
    local is_using_guild_repairs = self:is_using_guild_repairs()
    local is_guild_repairable = CanGuildBankRepair()
    local is_in_guild = IsInGuild()
    local playerMoney = GetMoney()
    local msg_repaired = L["MSG_REPAIRED"]

    -- Auto Repair
    if is_repair_merchant and is_repair_needed then
        if not (is_in_guild and is_guild_repairable) then
            is_using_guild_repairs = false
            self:Print(L["MSG_GUILD_REPAIR_FAIL"])
        end

        if is_using_guild_repairs then
            msg_repaired = L["MSG_GUILD_REPAIR_SUCCESS"]
        end

        if playerMoney > 0 then
            RepairAllItems(is_using_guild_repairs)
            self:Print(msg_repaired .. ":", GetCoinTextureString(repair_cost))
        else
            self:Print(L["MSG_NO_MONEY"])
        end
    end
end

function TheGrimRepair:is_selling_gray_items(info)
    return self.db.profile.is_selling_gray_items
end

function TheGrimRepair:toggle_sell_gray_items(info, value)
    self.db.profile.is_selling_gray_items = value
end

function TheGrimRepair:is_selling_disabled(info)
    return not self.db.profile.is_selling_gray_items
end

function TheGrimRepair:is_keeping_transmog_items(info)
    return self.db.profile.is_keeping_transmog_items
end

function TheGrimRepair:toggle_keeping_transmog_items(info, value)
    self.db.profile.is_keeping_transmog_items = value
end

function TheGrimRepair:is_showing_sale_details(info)
    return self.db.profile.is_showing_sale_details
end

function TheGrimRepair:toggle_show_sale_details(info, value)
    self.db.profile.is_showing_sale_details = value
end

function TheGrimRepair:auto_sell()
    local is_selling_gray_items = self:is_selling_gray_items()
    local is_showing_sale_details = self:is_showing_sale_details()
    local is_keeping_transmog_items = self:is_keeping_transmog_items()
    local item_class_ids = {
        2, --Weapon
        4, --Armor
    }
    local msg_sold_items = L["MSG_SOLD"]

    -- Auto Sell Grays
    if is_selling_gray_items then
        for bag_number = 0, NUM_BAG_SLOTS do

            for slot_number = 1, C_Container.GetContainerNumSlots(bag_number) do
                local item_location = ItemLocation:CreateFromBagAndSlot(bag_number, slot_number)

                if item_location:IsValid() then
                    local item_quality = C_Item.GetItemQuality(item_location)

                    -- Only get details on poor quality items, should also help with caching issue
                    if item_quality == 0 then
                        local item_link = C_Item.GetItemLink(item_location)
                        local item_stack = C_Item.GetStackCount(item_location)
                        local item_sell_price, item_class_id = select(11, GetItemInfo(item_link))
                        local is_skipped_item = false

                        -- Skip the item if it can be used for transmog
                        if is_keeping_transmog_items then
                            for _, value in pairs(item_class_ids) do
                                if value == item_class_id then
                                    is_skipped_item = true
                                    break
                                end
                            end
                        end

                        -- Sell the item
                        if not is_skipped_item then
                            C_Container.UseContainerItem(bag_number, slot_number)

                            if is_showing_sale_details then
                                self:Print(msg_sold_items .. ":", item_link .. UNCOMMON_GREEN_COLOR:WrapTextInColorCode("x" .. item_stack), GetCoinTextureString(item_sell_price))
                            end
                        end
                    end
                end
            end
        end
    end
end

function TheGrimRepair:slash_command()
    InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
end
