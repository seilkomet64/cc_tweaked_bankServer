local digitizer = peripheral.find("digitizer")
local inventory = peripheral.find("minecraft:chest")

-- Get Currency in a ID
local function getCurrencyInId(id)
    return digitizer.getIDInfo(id).item.count
end

-- Check how much of an Item is inside the inventory
local function getCurrency(itemName)
    local total = 0
    for slot, item in pairs(inventory.list()) do
        if item.name == itemName then
            total = total + item.count
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
        if digitizer.getItemDetail(1) then
            -- Try pushing it out once
            digitizer.pushItems(peripheral.getName(inventory), 1)

            -- if still there we are FULL
            if digitizer.getItemDetail(1) then
                print("Bank is full! Upgrade Storage!")
                error("Bank is full!")
            end
        end

        local success, item = pcall(function() return digitizer.getIDInfo(id).item end)

        if success then
            digitizer.rematerialize(id)
            digitizer.pushItems(peripheral.getName(inventory), 1)
        end
    end

    return count
end

local function digitizeAmount(amount)
    if getCurrency(CONFIG.CURRENCYITEM) < amount then print("Not enough Currency in Inventory!") error("Bank is too poor!") end

    local digitalIDs = {}
    -- Loop through all slots in the source inventory
    for slot = 1, inventory.size() do
        local stack = inventory.getItemDetail(slot)

        -- Check if the stack contains the item we are looking for
        if stack and stack.name == CONFIG.CURRENCYITEM then                        
            -- Calculate the amount to transfer in this batch (maximum that can fit in the destination)
            local batchSize = math.min(amount, CONFIG.CURRENCYSTACKSIZE)  -- Assuming StackSize is 64 (adjust as needed)

            -- Push the items to the destination, limited to batchSize
            inventory.pushItems(peripheral.getName(digitizer), slot, batchSize)
            digitalIDs[#digitalIDs+1] = digitizer.digitize()

            -- Decrease the amount left to transfer
            amount = amount - batchSize


            -- If all items have been transferred, exit the loop
            if amount == 0 then
                break
            end
        end
    end

    return digitalIDs
end

return {getCurrency = getCurrency, digitizeAmount = digitizeAmount, materializeItems = materializeItems, getCurrencyInId = getCurrencyInId}

