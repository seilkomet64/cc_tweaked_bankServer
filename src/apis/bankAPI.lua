local bankAPI = {}
local itemManager = require("itemManager")

local function overwriteFile(acc, newBalance, pin)
    fs.delete("account/" ..acc)
    local file = fs.open("account/"..acc, "w")
    file.writeLine(newBalance)
    file.writeLine(pin)
    file.close()
end

-- When withrdawing we store the transaction for a while and revert it if not confirmed	
local pendingTransactions = {}

local function storePendingTransaction(acc, digitalIDs)
    local timestamp = os.time()
    pendingTransactions[acc] = {digitalIDs = digitalIDs, timestamp = timestamp}
end

local function revertTransaction(acc)
    if pendingTransactions[acc] then
        local transaction = pendingTransactions[acc]
        local file = fs.open("account/"..acc, "r")
        local balance = tonumber(file.readLine())
        local correctPin = file.readLine()
        file.close()
        local amount = itemManager.materializeItems(transaction.digitalIDs)
        if not tonumber(amount) then return false, "Error while reverting transaction" end
        balance = balance + amount
        overwriteFile(acc, balance, correctPin)
        pendingTransactions[acc] = nil
        return true, "Transaction reverted"
    else
        return false, "No pending transaction found"
    end
end

function bankAPI.checkPendingTransactions()
    while true do
        local currentTime = os.time()
        for acc, transaction in pairs(pendingTransactions) do
            if currentTime - transaction.timestamp > CONFIG.TRANSACTION_TIMEOUT then
                local success, result = revertTransaction(acc)
                if not success then
                    print(result)
                else
                    print("Withdraw for account "..acc.." reverted")
                end
            end
        end
        sleep(5) -- Check every 5 second
    end
end

function bankAPI.confirmTransaction(acc)
    if pendingTransactions[acc] then
        pendingTransactions[acc] = nil
    end
end

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
                    balance = balance - amount
                    overwriteFile(acc, balance, correctPin)
                    storePendingTransaction(acc, result)

                    return true, result, balance
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