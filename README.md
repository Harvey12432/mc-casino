# MC Casino

A networked casino system for Minecraft, built for
[CC:Tweaked](https://tweaked.cc/) computers.

The goal is to run several casino games from one trusted house computer. Player
terminals, cashier computers, and large monitor displays communicate over
Rednet. The house owns balances, validates bets, settles games, and keeps an
audit trail.

## Project status

The playable v0.1 release candidate is implemented for a private CC:Tweaked
world. It must pass the in-world acceptance gate before valuable items are
loaded:

- Persistent central player balances and transaction history
- Ten server-authoritative games: Slots, Blackjack, Roulette, Crash, Mines,
  Plinko, Horse Racing, Video Poker, Craps, and Coin Flip
- Progressive Slots jackpot
- Basalt game, cashier, leaderboard, and administration clients
- Direct-play Mines grid, holdable Video Poker cards, and live Crash multiplier
- One-click player switching and automatic session recovery after server restarts
- Automatic recovery of unfinished Blackjack, Crash, Mines, Poker, and Craps rounds
- Item-backed cashier deposits and prize withdrawals
- Server-verified cashier currency and conversion rate
- Restart-safe cashier operation IDs, status reconciliation, and bounded refunds
- Sender-bound sessions and trusted cashier/admin computer IDs
- Copy-on-write JSON commits with schema validation and backup recovery
- Game-specific saved-state and payout-integrity checks
- Idempotent financial and game requests

The automated audit and remaining operational caveats are recorded in
[System audit](docs/SYSTEM_AUDIT.md).

## MVP

- One central casino server
- Persistent player accounts and balances
- Player login using a Minecraft username
- Dedicated terminal roles for all ten games
- Server-authoritative bets, random outcomes, hidden state, and payouts
- Cashier operations for deposits and withdrawals
- A monitor showing game status and recent wins
- An append-only transaction/audit log
- Recovery after a computer restart

Loyalty rewards and multi-casino networking are possible later additions.

## Design principles

1. **The server is authoritative.** Terminals display state and submit actions;
   they never decide cards, balances, or payouts.
2. **Money moves through a ledger.** Every credit change records a reason,
   player, amount, and transaction ID.
3. **Games are state machines.** A game can be restored or safely refunded
   after a restart.
4. **Messages are validated.** Never trust a terminal-provided balance, payout,
   card, or player identity.
5. **Peripherals stay behind adapters.** Game code should not care whether
   currency comes from a chest, command computer, or an administrator.
6. **Shared foundations.** Every game uses the same ledger, recovery, protocol,
   and settlement path.

## System responsibilities

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
├── Roulette, Crash, Mines, and Plinko
├── Horse Racing, Video Poker, and Craps
├── Coin Flip
└── Submit choices/actions; the server decides outcomes

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

## Repository layout

```text
casino/
├── src/
│   ├── shared/                  Common config, protocol, and utilities
│   ├── server/
│   │   ├── services/            Business logic
│   │   ├── repositories/        Persistent data access
│   │   └── handlers/            Network request handlers
│   └── client/
│       ├── shared/              Common Basalt client and UI code
│       ├── cashier/
│       ├── slots/
│       ├── blackjack/
│       ├── roulette/
│       ├── crash/
│       ├── mines/
│       ├── plinko/
│       ├── horse_racing/
│       ├── poker/
│       ├── craps/
│       ├── coin_flip/
│       ├── leaderboard/
│       └── admin/
├── data/                        Initial server data; runtime data is mutable
├── installer/                   Role-based installation and updates
├── dev/                         Local development helpers
└── docs/                        Architecture and project context
```

`src` is a repository boundary, not part of the deployed path. Each
ComputerCraft computer gets only the files needed for its role: installers copy
`src/shared` to `/casino/shared`, `src/server` to `/casino/server`, or selected
`src/client` folders to `/casino/client`.

The repository `data/` directory contains new-installation seed files. A live
server uses `/casino/data`, which installers and updates must never overwrite.

## Suggested in-game hardware

For a small casino floor:

- 1 advanced computer as the casino server
- 1 advanced computer as a Blackjack terminal
- 1 advanced computer as a Slots terminal
- 1 advanced computer as the cashier
- 1 advanced computer as the administrator
- 1 modem on each computer
- 1 advanced monitor for the public display
- 3 networked inventories for cashier input, vault, and output

Advanced computers are recommended for colour, mouse support, and a better UI.
Wireless modems are convenient; wired modems make the physical network easier
to control.

## User interface: Basalt

All interactive terminals use
[Basalt 2.5](https://basalt.madefor.cc/2.5/). The terminal installer downloads
the pinned 2.5 bundle to `/casino/basalt.lua`; programs load it with
`require("basalt")`.

The installer pins the Basalt `basalt2.5` branch at commit
`a01ea6d577c92fcf76b5689f89eaf2920d011b82` for repeatable deployments and
stores the installed identifier in `/casino/basalt.version`.

Basalt owns rendering, mouse/keyboard events, components, and the UI event loop.
Terminal UI code should not call `os.pullEvent` directly once `basalt.run()` has
started. Network work initiated by a control is scheduled through Basalt so the
screen can continue to render.

## Currency model

The MVP stores virtual credits in the server ledger. Cashier adapters convert
between credits and an in-world item at a configured rate. A sensible first
currency is a renamed, otherwise unused item supplied by the casino.

Game terminals never modify inventories. The authorised cashier moves configured
currency items between its input, vault, and output inventories. New accounts
start at zero credits; players deposit items or receive an administrator
adjustment before betting.

## Running in Minecraft

Put this complete repository on a ComputerCraft disk at `/disk/casino`, then:

1. On the central computer, run
   `disk/casino/installer/install_server.lua`.
2. Edit `/casino/config.lua`, including trusted cashier and admin computer IDs.
3. On each client computer, run one of:
   - `disk/casino/installer/install_terminal.lua blackjack`
   - `disk/casino/installer/install_terminal.lua slots`
   - `disk/casino/installer/install_terminal.lua roulette`
   - `disk/casino/installer/install_terminal.lua crash`
   - `disk/casino/installer/install_terminal.lua mines`
   - `disk/casino/installer/install_terminal.lua plinko`
   - `disk/casino/installer/install_terminal.lua horse_racing`
   - `disk/casino/installer/install_terminal.lua poker`
   - `disk/casino/installer/install_terminal.lua craps`
   - `disk/casino/installer/install_terminal.lua coin_flip`
   - `disk/casino/installer/install_terminal.lua cashier`
   - `disk/casino/installer/install_terminal.lua leaderboard`
   - `disk/casino/installer/install_terminal.lua admin`
4. Configure the three cashier peripheral names in its `/casino/config.lua`.
5. Attach modems, label every computer, and reboot the server before clients.

The installers copy the correct role, create `/startup.lua`, preserve local
configuration and live server data, and install the pinned Basalt 2.5 bundle
on clients.
If a computer already has `/startup.lua`, the first casino installation keeps
it at `/startup.before-mc-casino.lua`.
CC:Tweaked HTTP must be enabled during a first client installation.

See [Operations guide](docs/OPERATIONS.md) for the complete setup and acceptance
test.

See [Project context](docs/PROJECT_CONTEXT.md),
[Architecture](docs/ARCHITECTURE.md), and
[Network protocol](docs/PROTOCOL.md) for design details. The complete player
paytable is in [Game rules and payouts](docs/GAME_RULES.md).

## Development conventions

- Lua files use two-space indentation.
- Modules return a table; avoid writable globals.
- Business logic should be pure Lua where practical.
- Peripheral and filesystem access belongs at the edge of the system.
- All amounts are integer credits. Never use floating-point currency.
- IDs are opaque strings, not array indexes.
- User-visible errors are friendly; detailed errors go to server logs.

## Safety note

This is an in-game entertainment project. It must not involve real money,
cryptocurrency, paid server-store items, or anything redeemable outside the
Minecraft world.
