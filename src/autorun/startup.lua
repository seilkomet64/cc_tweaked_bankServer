require(settings.get("ghu.base") .. "core/apis/ghu")
local bankController = require("bankController")
require("config")

term.clear()
print("Welcome to BankOS")
bankController.StartBankingSystem()