# Architecture

## System overview

```text
 Player             Cashier                Public display
   │                   │                         │
   ▼                   ▼                         ▼
Terminal ────────── Rednet network ───────── Display client
   │                   │                         ▲
   └───────────────────┼─────────────────────────┘
                       ▼
                 Casino server
             ┌─────────┼─────────┐
             │         │         │
           Games     Ledger    Sessions
             │         │         │
             └─────────┼─────────┘
                       ▼
              Snapshots + audit log
```

The Rednet network is transport, not security. Any computer may attempt to send
a valid-looking packet. The server validates the message type, schema, session,
game phase, requested amount, and request ID before changing state.

## Runtime roles

```text
Central server computer
├── Owns player balances
├── Stores transactions
├── Validates bets
├── Calculates outcomes
├── Controls jackpots
└── Rejects invalid requests

Cashier computer
├── Deposits items
├── Withdraws prizes
└── Shows balances

Slot computers
├── Show animations
├── Accept bet input
└── Ask server for outcome

Blackjack computer
├── Shows cards
├── Sends player actions
└── Gets authorised results

Other game computers
├── Render their dedicated Basalt interface
├── Send bets, choices, and actions
└── Receive only public, server-authorised state

Display computer
├── Leaderboard
├── Jackpot total
└── Recent wins

Admin computer
├── Adjust balances
├── Disable machines
├── Inspect transactions
└── View house profit
```

### Casino server

The only trusted runtime. It:

- Opens Rednet and advertises the casino service
- Authenticates sessions
- Routes validated requests
- Owns player balances
- Owns card shoes and active game state
- Persists snapshots and transactions
- Publishes sanitized events for displays
- Exposes operator-only maintenance commands locally

### Game terminal

A thin client. It:

- Discovers or connects to a configured server ID
- Starts a player session
- Renders the current server-provided view
- Sends player intents such as `bet`, `hit`, or `stand`
- Retries requests with the same request ID after a timeout
- Never computes authoritative outcomes

Terminal interfaces use Basalt 2.5. Basalt owns their render and event loop;
Rednet requests launched by UI controls run as scheduled work. The framework is
stored at `/casino/basalt.lua` and is intentionally not required by the headless
casino server.

### Cashier

A privileged client with a narrow protocol. It verifies an inventory transfer
through a peripheral adapter, then asks the server to apply an idempotent
deposit or withdrawal. Cashier authorization must be configured server-side.
The client persists its current operation ID in ComputerCraft settings. After a
timeout or restart it queries the server and resumes the same operation instead
of guessing whether the ledger changed. Refund amounts are derived from the
original withdrawal and cannot exceed it.

### Public display

A read-only subscriber. It receives redacted events and never sees private
balances, session tokens, or the hidden card shoe.

## Server modules

```text
src/server/
├── startup.lua
├── main.lua
├── games/                       Engines and persisted-state validation
├── services/
│   ├── account_service.lua
│   ├── transaction_service.lua
│   ├── game_service.lua
│   └── jackpot_service.lua
├── repositories/
│   ├── json_repository.lua
│   ├── player_repository.lua
│   ├── transaction_repository.lua
│   ├── game_repository.lua
│   ├── jackpot_repository.lua
│   └── system_repository.lua
└── handlers/
    ├── account_handler.lua
    ├── game_handler.lua
    └── admin_handler.lua
```

The exact files may change, but the boundaries should remain. In particular,
game modules may request ledger operations; they must not edit balances or
write persistence files themselves.

## Data model

### Account

```lua
{
  id = "example",
  displayName = "Example",
  balance = 1000,
  revision = 12
}
```

Bets are debited when a game is created and payouts are credited at settlement.
Amounts remain non-negative integers; an account mutation that would overdraw
is rejected.

### Ledger transaction

```lua
{
  id = "txn:<opaque-id>",
  requestId = "req:<opaque-id>",
  playerId = "example",
  kind = "game_payout",
  amount = 75,
  balanceAfter = 1025,
  referenceId = "hand:<opaque-id>",
  timestamp = 123456.0
}
```

`requestId` is unique for a state-changing client intent. If the request is
retried, the server returns the original result rather than applying it again.

### Game record

```lua
{
  id = "game:<opaque-id>",
  type = "blackjack",
  playerId = "example",
  senderId = 17,
  revision = 4,
  state = {
    phase = "player_turn",
    bet = 50
  }
}
```

`state` is owned by the game module. The surrounding fields support routing,
authorization, optimistic revision checks, and recovery.

## Persistence

CC:Tweaked has no transactional database, so persistence must be deliberately
small and defensive.

1. Mutate a private copy of the current in-memory store.
2. Serialize that candidate to a temporary JSON file.
3. Read it back and validate its store- and game-specific schema.
4. Rotate the previous valid file to `.bak`.
5. Move the temporary file into the live path.
6. Publish the candidate in memory only if the disk commit succeeds.
7. Persist every balance mutation as a transaction record.

On startup, each store validates its live file and restores its previous backup
if needed, including when power failed after moving the live file to `.bak` but
before promoting the temporary file. If both copies are invalid, startup stops
rather than silently creating a fresh ledger. Financial and game mutations save
immediately.

## Game transaction flow

```text
Terminal             Server game             Ledger
   │  bet(req-1, 50)      │                      │
   ├─────────────────────►│ validate phase       │
   │                      ├── reserve 50 ───────►│
   │                      │◄──── success ────────┤
   │◄── hand state ───────┤                      │
   │  hit(req-2)          │                      │
   ├─────────────────────►│ draw + persist       │
   │◄── hand state ───────┤                      │
   │  stand(req-3)        │                      │
   ├─────────────────────►│ dealer + outcome     │
   │                      ├── settle once ──────►│
   │                      │◄──── transaction ────┤
   │◄── result + balance ─┤                      │
```

If a response is lost, the terminal repeats the same request ID. The server
returns the stored response for that ID.

## Event loop

The server uses a small Rednet request dispatcher. Handlers complete quickly,
persist changes before responding, and session expiry is checked whenever a
request authenticates.

## Security boundaries

Practical CC:Tweaked security is limited, but the design should still resist
accidents and casual packet forgery:

- Configure a fixed protocol name and casino ID.
- Bind a session to a ComputerCraft sender ID.
- Use random opaque session tokens where possible.
- Allow cashier operations only from configured computer IDs.
- Authorise remote admin operations only from configured computer IDs.
- Never transmit the shoe, server RNG state, or other players' private state.
- Treat `os.getComputerID()` as an address, not proof of a human identity.

## Recovery policy

- Settled game: return the recorded result.
- Active game with fully persisted state: resume it.
- Active persisted Blackjack hand: restore its ID from terminal settings and
  request the authoritative view.
- Active Crash, Mines, Video Poker, and Craps rounds: resume from the
  persisted server record; hidden state is never reconstructed by the client.
- Cashier transfer with uncertain peripheral outcome: enter operator review;
  do not guess.
