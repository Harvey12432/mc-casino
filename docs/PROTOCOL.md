# Rednet Protocol

## Transport

- Rednet protocol name: `mc-casino.v1`
- Message encoding: ordinary Lua tables supported by Rednet
- Request/response correlation: `requestId`
- State-changing requests are idempotent
- Server discovery uses `rednet.host` and `rednet.lookup`

The protocol version in the Rednet name covers breaking envelope changes.
Individual game views also carry their own state revision.

## Request envelope

```lua
{
  type = "game.action",
  requestId = "req:<opaque-id>",
  casinoId = "main-floor",
  sessionToken = "<opaque-token>",
  payload = {
    gameId = "hand:<opaque-id>",
    action = "hit",
    expectedRevision = 3
  }
}
```

Required fields depend on the message type, but `type`, `requestId`, and
`casinoId` are always required for requests.

## Success response

```lua
{
  type = "response.ok",
  requestId = "req:<same-id>",
  payload = {}
}
```

## Error response

```lua
{
  type = "response.error",
  requestId = "req:<same-id>",
  error = {
    code = "STALE_STATE",
    message = "The game changed; your screen has been refreshed.",
    retryable = true
  }
}
```

Error messages are safe to display to a player. Server logs may contain more
detail, but must not leak it to clients.

## Initial message types

| Type | Direction | Purpose |
|---|---|---|
| `system.hello` | Client → Server | Check compatibility and server status |
| `session.open` | Terminal → Server | Begin or restore a player session |
| `session.close` | Terminal → Server | End a terminal session |
| `account.view` | Terminal → Server | Fetch the player's available balance |
| `game.create` | Terminal → Server | Reserve a bet and create a game |
| `game.action` | Terminal → Server | Submit an action for an active game |
| `game.view` | Terminal → Server | Refresh authoritative game state |
| `cashier.deposit` | Cashier → Server | Credit a confirmed item deposit |
| `cashier.withdraw` | Cashier → Server | Reserve/debit a withdrawal |
| `cashier.refund` | Cashier → Server | Refund an undelivered withdrawal |
| `cashier.status` | Cashier → Server | Reconcile a cashier operation after interruption |
| `display.subscribe` | Display → Server | Request sanitized public events without a player session |
| `admin.command` | Admin → Server | Inspect or operate the casino |

## Validation order

For every request, the server should:

1. Check the Rednet protocol and envelope shape.
2. Check `casinoId`.
3. Check that `requestId` is well formed and bounded in length.
4. Return a cached result if this request was already processed.
5. Authenticate the session and bind it to the sender computer ID.
6. Validate and bound every payload field.
7. Check permissions and current game revision.
8. Apply the operation, persist it, and cache the response.
9. Send the response.

## Standard error codes

- `BAD_REQUEST`
- `WRONG_CASINO`
- `UNAUTHORIZED`
- `SESSION_EXPIRED`
- `FORBIDDEN`
- `MAINTENANCE`
- `INSUFFICIENT_FUNDS`
- `GAME_NOT_FOUND`
- `INVALID_BET`
- `UNKNOWN_GAME`
- `INVALID_ACTION`
- `INVALID_OPTIONS`
- `STALE_STATE`
- `REQUEST_CONFLICT`
- `INTERNAL_ERROR`

Clients should branch on the code, not the English message.
The bundled clients transparently open a replacement session and retry once for
`UNAUTHORIZED` and `SESSION_EXPIRED`. Interactive game clients refresh their
authoritative view after `STALE_STATE`.

## Hello payload

`system.hello` is available before login. Alongside server status and supported
games, it returns `currencyItem`, `creditsPerItem`, `minimumBet`, and
`maximumBet`, plus `maximumBalance`. Cashier terminals must match the server
currency fields before moving an item.

## Blackjack public view

The server returns only what the player is allowed to know:

```lua
{
  gameId = "hand:<opaque-id>",
  revision = 4,
  phase = "player_turn",
  bet = 50,
  playerCards = {
    { rank = "A", suit = "spades" },
    { rank = "7", suit = "hearts" }
  },
  dealerCards = {
    { rank = "K", suit = "clubs" },
    { hidden = true }
  },
  actions = { "hit", "stand", "double" },
  message = "Your hand is 18."
}
```

The full dealer hand, shoe order, and settlement internals stay on the server.

## Game creation and actions

All games use one creation shape:

```lua
payload = {
  game = "roulette",
  bet = 25,
  options = { choice = "red" }
}
```

Options are `choice` for Roulette/Coin Flip, `horse` for Horse Racing, and
`mines` for Mines. Games without a pre-game choice use an empty table.

Interactive actions include Blackjack `hit`/`stand`/`double`, Crash `cashout`,
Mines `reveal` with `position` or `cashout`, Video Poker `draw` with a `held`
index list, and Craps `roll`. Every action includes `gameId` and
`expectedRevision`.

## Cashier operation identity

Deposits and withdrawals include a stable `operationId` generated before any
item or credit movement. The server uses this ID for financial idempotency and
rejects reuse with a different player, amount, kind, or cashier.

After a timeout or reboot, `cashier.status` reports `unknown`, `committed`, or
`refunded`. The cashier resends an unknown operation with the same ID. It never
automatically reverses an ambiguous timeout.

Refund requests identify the original withdrawal and report only the amount
successfully delivered. The server looks up the original debit and calculates
the bounded refund itself.
