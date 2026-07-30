local Client = require("client.shared.client")
local bootstrap = require("client.shared.bootstrap")
local ui = require("client.leaderboard.ui")

local client = Client.new()
bootstrap.connect(client)
ui.run(client)
