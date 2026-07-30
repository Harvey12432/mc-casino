local Client=require("client.shared.client")
local bootstrap=require("client.shared.bootstrap")
local ui=require("client.coin_flip.ui")
local client=Client.new(); bootstrap.connectAndLogin(client); ui.run(client)
