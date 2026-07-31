-- Fallback defaults for the installer. Use /casino/setup.lua to configure each computer.
return {
  casinoId = "main-floor",
  serverHostname = "mc-casino-main",

  -- Server only: add the ComputerCraft IDs of trusted machines.
  authorizedCashierIds = {},
  authorizedAdminIds = {},

  -- Cashier only: use peripheral network names, not side names.
  cashierInput = nil,
  cashierVault = nil,
  cashierOutput = nil,

  currencyItem = "minecraft:emerald",
  creditsPerItem = 1,
  minimumBet = 5,
  maximumBet = 500,
  maximumBalance = 1000000000,

  -- Server game rules.
  blackjackDecks = 6,
  dealerHitsSoft17 = false,

  -- Reserved test account, excluded from the public leaderboard.
  acceptancePlayerId = "casino_test",
}
