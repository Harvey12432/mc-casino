local Client = require("client.shared.client")
local bootstrap = require("client.shared.bootstrap")
local ui = require("client.admin.ui")

local client = Client.new()
bootstrap.connectAndLogin(client, "admin")
ui.run(client)
