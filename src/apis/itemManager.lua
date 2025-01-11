local digitizer = peripheral.find("digitizer")
local inventory = {peripheral.find("minecraft:chest")} -- Table of inventories

-- Get Currency in an ID
local function getCurrencyInId(id)
    local success, info = pcall(function() return digitizer.getIDInfo(id).item.count end)

    if success then return info else return nil end
end

-- Check how much of an Item is inside the inventory
local function getCurrency(itemName)
    local total = 0
    for _, inv in pairs(inventory) do
        local itemList = inv.list() -- Cache the inventory list
        for _, item in pairs(itemList) do
            if item.name == itemName then
                total = total + item.count
            end
        end
    end
    return total
end

-- Materialize Items from a list of IDs
-- @return the total amount of items materialized
local function materializeItems(digitizedIds)
    local count = 0

    for _, id in ipairs(digitizedIds) do
        -- If something is stuck in the digitizer
        local itemInDigitizer = digitizer.getItemDetail(1)
        if itemInDigitizer then
            local counter = itemInDigitizer.count
            -- Try pushing it out once
            for _, inv in pairs(inventory) do
                counter = counter - digitizer.pushItems(peripheral.getName(inv), 1)

                if counter == 0 then break end
            end

            -- if still there we are FULL
            if counter > 0 then
                print("Bank is full! Upgrade Storage!")
                error("Bank is full!")
            end
        end

        local itemCount = getCurrencyInId(id)
        if itemCount then
            digitizer.rematerialize(id)
            count = count + itemCount
            for _, inv in pairs(inventory) do
                itemCount = itemCount - digitizer.pushItems(peripheral.getName(inv), 1)

                if itemCount == 0 then break end
            end
        else
            return "Unable to find id for materialization"
        end
    end

    return count
end

local function digitizeAmount(amount)
    if getCurrency(CONFIG.CURRENCYITEM) < amount then
        print("Not enough Currency in Inventory!")
        error("Bank is too poor!")
    end

    local digitalIDs = {}

    -- Loop through all inventories
    for _, inv in pairs(inventory) do
        local invSize = inv.size() -- Cache the size of the inventory
        for slot = 1, invSize do
            local stack = inv.getItemDetail(slot)

            -- Check if the stack contains the item we are looking for
            if stack and stack.name == CONFIG.CURRENCYITEM then
                -- Calculate the amount to transfer in this batch (maximum that can fit in the destination)
                local batchSize = math.min(amount, CONFIG.CURRENCYSTACKSIZE) -- Assuming StackSize is 64 (adjust as needed)

                -- Push the items to the digitizer, limited to batchSize
                inv.pushItems(peripheral.getName(digitizer), slot, batchSize)
                digitalIDs[#digitalIDs + 1] = digitizer.digitize()

                -- Decrease the amount left to transfer
                amount = amount - batchSize

                -- If all items have been transferred, exit the loop
                if amount == 0 then
                    break
                end
            end
        end

        if amount == 0 then
            break
        end
    end

    return digitalIDs
end

return {
    getCurrency = getCurrency,
    digitizeAmount = digitizeAmount,
    materializeItems = materializeItems,
    getCurrencyInId = getCurrencyInId
}
