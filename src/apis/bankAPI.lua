local bankAPI = {}
local itemManager = require("itemManager")

local function overwriteFile(acc, newBalance, pin)
    fs.delete("account/" ..acc)
    local file = fs.open("account/"..acc, "w")
    file.writeLine(newBalance)
    file.writeLine(pin)
    file.close()
end

-- When withdrawing, we store the transactions for a while and revert them if not confirmed
local pendingTransactions = {}

local function storePendingTransaction(acc, digitalIDs)
    local timestamp = os.time(os.date("*t"))
    if not pendingTransactions[acc] then
        pendingTransactions[acc] = {} -- Initialize a list for the account if it doesn't exist
    end
    table.insert(pendingTransactions[acc], {digitalIDs = digitalIDs, timestamp = timestamp})
    return #pendingTransactions[acc]
end

local function revertTransaction(acc, transactionIndex)
    if pendingTransactions[acc] and pendingTransactions[acc][transactionIndex] then
        local transaction = pendingTransactions[acc][transactionIndex]
        local file = fs.open("account/"..acc, "r")
        local balance = tonumber(file.readLine())
        local correctPin = file.readLine()
        file.close()
        local amount = itemManager.materializeItems(transaction.digitalIDs)
        if not tonumber(amount) then
            return false, string.format("Error while reverting transaction #%d for account %s", transactionIndex, acc)
        end
        local oldBalance = balance
        balance = balance + amount * CONFIG.EXCHANGERATE
        overwriteFile(acc, balance, correctPin)

        -- Remove the reverted transaction from the list
        table.remove(pendingTransactions[acc], transactionIndex)

        -- Clean up the account if no more transactions are pending
        if #pendingTransactions[acc] == 0 then
            pendingTransactions[acc] = nil
        end

        print(string.format("Transaction #%d for account %s reverted from balance %s to %s", transactionIndex, acc, oldBalance, balance))
        return true, "Transaction reverted"
    else
        return false, string.format("No pending transaction #%d found for account %s", transactionIndex, acc)
    end
end

function bankAPI.checkPendingTransactions()
    while true do
        local currentTime = os.time(os.date("*t"))
        for acc, transactions in pairs(pendingTransactions) do
            for i = #transactions, 1, -1 do -- Iterate backward to safely remove items
                local transaction = transactions[i]
                if currentTime - transaction.timestamp > CONFIG.TRANSACTION_TIMEOUT then
                    -- Revert the expired transaction
                    local success, result = revertTransaction(acc, i)
                    if not success then
                        print(result)
                    end
                end
            end
        end
        sleep(5) -- Check every 5 seconds
    end
end

function bankAPI.confirmTransaction(acc, transactionIndex)
    if pendingTransactions[acc] and pendingTransactions[acc][transactionIndex] then
        -- Confirm and remove the specific transaction
        table.remove(pendingTransactions[acc], transactionIndex)

        -- Clean up the account if no more transactions are pending
        if #pendingTransactions[acc] == 0 then
            pendingTransactions[acc] = nil
        end

        return true, "Transaction confirmed"
    else
        return false, string.format("No pending transaction #%d found for account %s", transactionIndex, acc)
    end
end

-- API 

function bankAPI.deposit(acc, digitalIDs, pin)
    local file = fs.open("account/"..acc, "r")

    if file ~= nil then
        local oldbalance = tonumber(file.readLine())
        local balance = oldbalance
        local correctPin = file.readLine()
        file.close()

        if pin == correctPin then
            local success, result = pcall(function() return itemManager.materializeItems(digitalIDs) end)

            if not success then
                local errorMessage = result:match(":%d+: (.+)") or result
                if errorMessage == "Bank is full!" then
                    return false, errorMessage
                else
                    print(result)
                    return false, "Unknown Server Error"
                end
            else
                balance = balance + result * CONFIG.EXCHANGERATE
                overwriteFile(acc, balance, correctPin)
                return true, balance, oldbalance
            end
        else
            return false, "Incorrect Pin"
        end
    end
end

function bankAPI.withdraw(acc, amount, pin)
    local file = fs.open("account/"..acc, "r")

    if file ~= nil then
        local balance = tonumber(file.readLine())
        local correctPin = file.readLine()
        file.close()

        -- correctPin
        if pin == correctPin then
            -- Enough Funds
            if balance >= amount then
                local success, result = pcall(function() return itemManager.digitizeAmount(amount) end)

                -- Able to Digitize
                if not success then
                    local errorMessage = result:match(":%d+: (.+)") or result
                    if errorMessage == "Bank is too poor!" then
                        return false, errorMessage
                    else
                        print(result)
                        return false, "Unknown Server Error"
                    end
                else
                    balance = balance - amount * CONFIG.EXCHANGERATE
                    overwriteFile(acc, balance, correctPin)
                    local transactionIndex = storePendingTransaction(acc, result)

                    return true, result, balance, transactionIndex
                end
            else
                return false, "Insufficient Funds"
            end
        else
            return false, "Incorrect Pin"
        end
    end
end

function bankAPI.getBalance(acc, pin)
    local file = fs.open("account/"..acc, "r")
    
    if file ~= nil then
        local balance = tonumber(file.readLine())
        local correctPin = file.readLine()
        file.close()

        if pin == correctPin then
            return true, balance
        else
            return false, "Incorrect Pin"
        end
    end
end

function bankAPI.transfer(acc, amount, targetAcc, pin)
    if acc == targetAcc then
        return false, "Cannot transfer to the same account"
    end

    local file = fs.open("account/"..acc, "r+")
    local targetFile = fs.open("account/"..targetAcc, "r+")

    if file ~= nil and targetFile ~= nil then
        local balance = tonumber(file.readLine())
        local correctPin = file.readLine()

        local targetBalance = tonumber(targetFile.readLine())
        local targetCorrectPin = targetFile.readLine()

        if pin == correctPin then
            if balance >= amount then
                balance = balance - amount
                targetBalance = targetBalance + amount
                overwriteFile(acc, balance, correctPin)
                overwriteFile(acc, targetBalance, targetCorrectPin)

                file.close()
                targetFile.close()
                return true, balance
            else
                return false, "Insufficient Funds"
            end
        else
            return false, "Incorrect Pin"
        end
    end
end

function bankAPI.checkPin(acc, pin)
    local status = false
    if not acc or not pin then return status end
    
    local file = fs.open("account/"..acc, "r+")

    if file ~= nil then
        local balance = tonumber(file.readLine())
        local correctPin = file.readLine()

        if pin == correctPin then status = true end
        file.close()

        return status
    else
        return false
    end
end

function bankAPI.checkCard(acc)
    local status = false
    if not acc then return status end

    local file = fs.open("account/"..acc, "r")

    if file ~= nil then
        status = true
        file.close()
    end

    return status
end

function bankAPI.createAccount(acc, pin)
    if not acc or not pin then
        return false, "Account number and PIN are required"
    end

    local file = nil
    file = fs.open("account/" .. acc, "r")
    if file ~= nil then
        file.close()
        return false, "Account already exists"
    end

    local newBalance = 0
    file = fs.open("account/" .. acc, "w")
    file.writeLine(newBalance)
    file.writeLine(pin)
    file.close()

    return true, "Account created successfully"
end

return bankAPI