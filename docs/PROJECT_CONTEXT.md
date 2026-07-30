# Project Context

## Product statement

MC Casino is a reliable, multiplayer casino built from CC:Tweaked computers.
It should feel like a coherent in-world venue rather than a collection of
unrelated programs. Players use dedicated terminals, while a central house
computer protects balances and game integrity.

## Target environment

- Minecraft with CC:Tweaked
- Modern CC:Tweaked Lua (`require`, `settings`, `textutils`, `fs`, `rednet`)
- Advanced computers for interactive clients
- Basalt 2.5 for terminal user interfaces
- A private or trusted multiplayer server
- No dependency on command computers for the core game

The exact Minecraft and CC:Tweaked versions are deployment choices. Record both
for a production floor and run the operations acceptance test after modpack
changes.

## Users

### Player

Logs in, sees a balance, joins a game, places bets, acts during a hand, and sees
clear settlement results.

### Casino operator

Starts and stops the system, funds test accounts, inspects health and logs, and
can safely disable betting.

### Cashier

Converts configured in-world items to credits and credits back to items. This
may be a player-facing kiosk or an operator-controlled station.

## Decisions already made

- CC:Tweaked is the target ComputerCraft implementation.
- One trusted server owns all financial and game state.
- Clients are untrusted, even on a friendly Minecraft server.
- The game set is Slots, Blackjack, Roulette, Crash, Mines, Plinko, Horse
  Racing, Video Poker, Craps, and Coin Flip.
- Currency is represented internally as non-negative integer credits.
- Every balance mutation is an auditable ledger transaction.
- The protocol is versioned from the first implementation.
- Basalt owns rendering and input on all interactive terminals.
- A lost or duplicated network message must not duplicate a bet or payout.
- Real-world value is out of scope.

## Configurable deployment choices

- Minecraft currency item and credits per item
- Casino name and Rednet hostname
- Minimum and maximum bets
- Cashier and administrator computer IDs
- Cashier input, vault, and output inventory names
- Wired or wireless modem topology

Player accounts currently use typed usernames. Blackjack uses six decks, dealer
stands on soft 17, 3:2 natural Blackjack, doubling on the first two cards, and
no split, surrender, or insurance.

## Milestones

### M0 — Foundation (completed)

- Define repository structure and conventions
- Define the server trust model
- Define the versioned Rednet protocol
- Decide persistence and recovery rules

### M1 — Ledger vertical slice (completed)

- Persistent accounts and balances
- Idempotent credit/debit operations
- Operator test-credit command
- Audit log and startup recovery
- Unit tests for balance invariants

### M2 — Playable Blackjack (completed)

- Server-side shuffled shoe
- Blackjack state machine
- One interactive terminal UI
- Immediate bet debit and exactly-once settlement
- Active-hand restart recovery

### M3 — Casino floor (completed)

- Multiple independent terminals
- Cashier adapter
- Public monitor display
- Operator maintenance mode and summary view
- Deployment utility

### M4 — Game expansion (completed)

- Eight additional games as isolated server modules
- Dedicated Basalt terminal roles for all ten games

### M5 — Future expansion

- Player cards or stronger authentication
- Statistics, leaderboards, and loyalty features
- Replicated backups

## Acceptance criteria for the first deployment

- Two terminals can play independent Blackjack hands concurrently.
- A terminal cannot create credits by sending a forged Rednet message.
- Replaying a bet or settlement message does not apply it twice.
- Server restart preserves settled balances and safely handles open hands.
- Corrupt persistence data is detected and does not silently reset balances.
- Operator maintenance mode prevents new bets without destroying active data.
- Every credit change can be explained from the audit log.
- The main flows fit cleanly on an advanced computer screen.

## Non-goals

- Real-money or externally redeemable gambling
- Cryptographic security against a malicious server administrator
- Internet-facing accounts
- Cross-Minecraft-server balances
- A generic banking platform
- Multiplayer table poker and player-versus-player wagering
