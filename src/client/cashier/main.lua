local Client = require("client.shared.client")
local bootstrap = require("client.shared.bootstrap")
local ui = require("client.cashier.ui")

local client = Client.new()
bootstrap.connectAndLogin(client, "cashier")
ui.run(client)
