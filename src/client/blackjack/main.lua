local Client = require("client.shared.client")
local bootstrap = require("client.shared.bootstrap")
local game = require("client.blackjack.game")
local ui = require("client.blackjack.ui")

local client = Client.new()
bootstrap.connectAndLogin(client)
ui.run(client, game.new())
