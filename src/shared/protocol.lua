local protocol = {
  NAME = "mc-casino.v1",
  types = {
    HELLO = "system.hello",
    SESSION_OPEN = "session.open",
    SESSION_CLOSE = "session.close",
    ACCOUNT_VIEW = "account.view",
    GAME_CREATE = "game.create",
    GAME_ACTION = "game.action",
    GAME_VIEW = "game.view",
    CASHIER_DEPOSIT = "cashier.deposit",
    CASHIER_WITHDRAW = "cashier.withdraw",
    CASHIER_REFUND = "cashier.refund",
    CASHIER_STATUS = "cashier.status",
    ADMIN_COMMAND = "admin.command",
    DISPLAY_SUBSCRIBE = "display.subscribe",
  },
  responses = {
    OK = "response.ok",
    ERROR = "response.error",
  },
}

return protocol
