local bankAPI = require("bankAPI")
local protocol = "bank"

local function logRequest(atmNumber, requestType, acc, targetAcc, startBalance, endBalance)
    local logFile = fs.open("bank_log.txt", "a")
    local time = textutils.formatTime(os.time(), true)

    local parts = {
        string.format("[%s] ATM: %s, Request: %s, Account: %s", time, atmNumber, requestType, acc)
    }

    if targetAcc then
        table.insert(parts, string.format("Target Account: %s", targetAcc))
    end
    if startBalance then
        table.insert(parts, string.format("Start Balance: %s", startBalance))
    end
    if endBalance then
        table.insert(parts, string.format("End Balance: %s", endBalance))
    end

    local message = table.concat(parts, ", ")

    logFile.writeLine(message)
    print(message)
    logFile.close()
end

local function StartBankingSystem()
    local modems = {}
    print("Searching for wireless modem...")
    while not modems[1] do
        modems = { peripheral.find("modem", function(name, modem)
            return modem.isWireless() -- Check this modem is wireless.
        end) }
        if not modems[1] then
            print("No wireless modem found")
            print("Please connect a wireless modem to continue")
            sleep(5)
        end
    end

    print("Modem Found.")
    rednet.open(peripheral.getName(modems[1]))
    rednet.host("bank", "bankController")

    -- message balance = {atmNumber, type, acc, pin} -> balance
    -- message deposit = {atmNumber, type, acc, digitalIDs, pin} -> balance
    -- message withdraw = {atmNumber, type, acc, amount, pin} -> digitalIDs, balance
    -- message transfer = {atmNumber, type, acc, amount, targetAcc, pin} -> balance
    while true do
        ::continue::
        local computer_id, message = rednet.receive(protocol)

        -- Checks if the message is valid
        if not message.type or not message.acc or (not message.pin and not message.type == "checkCard") then
            rednet.send(computer_id, {success = false, error = "Invalid Request"}, protocol)
            goto continue
        end

        -- Checks the type of message
        if message.type == "balance" then
            local success, balance = bankAPI.getBalance(message.acc, message.pin)
            if not success then
                rednet.send(computer_id, {success = false, error = balance}, protocol)
            else
                rednet.send(computer_id, {success = true, balance = balance}, protocol)
                logRequest(message.atmNumber, "balance", message.acc, nil, balance, balance)
            end
        elseif message.type == "deposit" then
            local success, newBalance, oldBalance = bankAPI.deposit(message.acc, message.ids, message.pin)
            if not success then
                rednet.send(computer_id, {success = false, error = newBalance}, protocol)
            else
                rednet.send(computer_id, {success = true, balance = newBalance}, protocol)
                logRequest(message.atmNumber, "deposit", message.acc, nil, oldBalance, newBalance)
            end
        elseif message.type == "withdraw" then
            local success, digitalIDs, newBalance = bankAPI.withdraw(message.acc, message.amount, message.pin)
            if not success then
                rednet.send(computer_id, {success = false, error = digitalIDs}, protocol)
            else
                rednet.send(computer_id, {success = true, ids = digitalIDs}, protocol)
                logRequest(message.atmNumber, "withdraw", message.acc, nil, newBalance + message.amount, newBalance)
            end
        elseif message.type == "transfer" then
            if not message.targetAcc then
                rednet.send(computer_id, {success = false, error = "Invalid Request"}, protocol)
                goto continue
            end

            if message.acc == message.targetAcc then
                rednet.send(computer_id, {success = false, error = "Cannot transfer to the same account"}, protocol)
                goto continue
            end

            local success, newBalance = bankAPI.transfer(message.acc, message.amount, message.targetAcc, message.pin)
            if not success then
                rednet.send(computer_id, {success = false, error = newBalance}, protocol)
            else
                rednet.send(computer_id, {success = true, balance = newBalance}, protocol)
                logRequest(message.atmNumber, "transfer", message.acc, message.targetAcc, newBalance + message.amount, newBalance)
            end
        elseif message.type == "checkPin" then
            rednet.send(computer_id, {success = true, status = bankAPI.checkPin(message.acc, message.pin)}, protocol)
            logRequest(message.atmNumber, message.type, message.acc)   
        elseif message.type == "checkCard" then
            rednet.send(computer_id, {success = true, status = bankAPI.checkCard(message.acc)}, protocol)
            logRequest(message.atmNumber, message.type, message.acc)
        elseif message.type == "confirmTransaction" then
            bankAPI.confirmTransaction(message.acc)
        end
    end
end


return {StartBankingSystem = StartBankingSystem}