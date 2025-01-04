require(settings.get("ghu.base") .. "core/apis/ghu")
local bankController = require("bankController")
local bankAPI = require("bankAPI")
require("config")

term.clear()
term.setCursorPos(1, 1)
print("Welcome to BankOS")
-- Start the banking system and check for pending transactions
-- Pending Transactions is an infinite loop that checks for transactions that have not been confirmed and will not finish 
parallel.waitForAny(bankController.StartBankingSystem, bankAPI.checkPendingTransactions)