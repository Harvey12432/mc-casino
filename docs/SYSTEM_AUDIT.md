# System Audit

Audit date: 2026-07-30

## Verdict

The repository now implements a complete small-world casino flow: a central
computer stores accounts, transactions, games, and jackpots; players can play
all ten game terminals; a cashier converts configured Minecraft items to credits;
a monitor shows the leaderboard and jackpot; and an authorised administrator
can inspect accounts and transactions, adjust balances, and toggle maintenance.

It is a release candidate for an in-world acceptance deployment. It has not
been executed against the user's exact Minecraft, CC:Tweaked, modem, monitor,
and inventory layout, so the acceptance procedure in `docs/OPERATIONS.md`
remains the final environment-specific gate.

The 2026-07-30 stabilization work changed networking, validation, installers,
the persistence layer, every game's saved-state contract, and several Basalt
screens. The expanded suite now contains 67 named tests across 16 suites and
271 static assertion sites. All 67 tests pass on Cobalt 0.9.9 extracted from
the locally installed CC:Tweaked 1.119.0 mod.

## Implemented requirements

- Central non-negative integer player balances
- Configured maximum-balance enforcement that preserves gross game results,
  reports the credited amount, and returns capped progressive winnings to the pool
- Idempotent deposits, withdrawals, bounded refunds, bets, double-downs, and payouts
- Persistent transaction history and house-profit calculation
- Copy-on-write JSON commits with schema validation, in-memory rollback, and
  previous-snapshot recovery, including the interrupted live-to-backup window
- Persistent game state, completed results, request responses, and jackpots
- Game-specific state and public-response schemas for all ten games, including
  card/dice/path/map consistency and payout arithmetic
- Six-deck Blackjack, dealer stands on soft 17, hit, stand, and double
- Weighted three-reel Slots with pair/triple payouts and progressive jackpot
- Versioned, sustainable Slots paytable with pair pushes, approximately 74.53%
  base return, and a progressive contribution bounded below 95% aggregate
  expected return for every default legal wager
- Roulette, Crash, Mines, Plinko, Horse Racing, Video Poker, pass-line Craps,
  and Coin Flip with server-owned random outcomes and hidden state
- Username sessions bound to the sending ComputerCraft ID
- Randomized session-token suffixes and bounded session/request fields
- Server-configured cashier and administrator computer IDs
- Persistent maintenance mode and per-machine disable/enable controls
- Basalt 2.5 interfaces for all client roles
- Clickable Mines board, holdable Poker cards, live Crash display, direct game
  choices, guarded requests, and outcome animations
- On-screen rules/paytables and a live progressive-jackpot readout on Slots
- Player switching and transparent session recovery after server restarts
- Per-player recovery of unfinished Blackjack, Crash, Mines, Poker, and Craps rounds
- Session-free unattended public display
- Currency/rate handshake between server and cashier
- Bounded request payloads, rejection of non-finite nested numbers, and
  sanitized persisted game options
- Confirmation steps for item movement and destructive admin controls
- Cashier input/vault/output inventory adapter
- Role-based disk installer that preserves configuration, live data, and the
  first pre-existing startup program

## Automated and static evidence

- The package contains 105 Lua files. All 105 compile successfully on Cobalt
  0.9.9, and all 195 internal
  `require()` references resolve; `basalt` is the one intentional installed
  dependency.
- The previous thirty-two-test baseline passed before stabilization. Thirty-five
  additional named tests cover session recovery, player-name validation,
  public display access, acceptance isolation, bounded and finite requests,
  option sanitization, startup preservation, finite balance limits,
  game-specific state/view validation, payout-tamper rejection, long Craps
  rounds, copy-on-write rollback, interrupted-file recovery, and fail-closed
  handling of a corrupt lone backup, Slots expected-return bounds, versioned
  paytable compatibility, fair Horse Racing payouts, maximum-balance settlement,
  duplicate persisted identifiers, exact-request recovery after a committed
  response-cache failure, and construction of every client UI. The real
  acceptance program, representative role preflights, and terminal
  installer/update path are also executed against deterministic ComputerCraft
  fixtures. The combined 67-test suite passes.
- Tests cover ace scoring, face-card scoring, double eligibility, Slots wins and
  losses, initial balances, overdraft rejection, duplicate financial requests,
  duplicate game creation, Blackjack settlement, duplicate active-hand
  prevention, crash-resumable game creation, transaction-history repair without
  reapplying a balance, sender binding, trusted roles, and repeated recovery
  from a corrupt live snapshot, idempotent jackpot contribution and claim, and
  persistent disabled-machine state.
- Cashier protocol tests cover operation status, bounded partial refunds,
  duplicate refunds, forged-refund rejection, and conflicting operation IDs.
- Persistence tests reject malformed ready-game records and tampered payouts
  before they can replace a valid snapshot. Fault injection verifies that a
  failed disk move cannot change an in-memory balance or create an audit entry,
  and that the remaining backup is recoverable after restart.
- Game tests cover Roulette validation and colour settlement, hidden Crash and
  Mines state, Plinko paths, Horse selection, Poker hand evaluation, Craps
  come-out settlement, and Coin Flip settlement.
- The complete protocol integration test covers casino mismatch rejection,
  player/cashier/admin sessions, admin funding, central balance reads, a Slots
  settlement and replay, cashier permissions, maintenance, machine controls,
  and the public leaderboard snapshot through the production router.
- The pinned 277,062-byte Basalt 2.5 bundle has SHA-256
  `d34f286f113e416ad0db4ce07b9853c6f1109cac6acb03f5b8783fdbda2e20a4`,
  compiles on Cobalt, and its real frame, label, button, input, scheduling, and
  monitor-binding APIs successfully construct all thirteen casino interfaces.
- Client calls were checked against the versioned Basalt 2.5 API. Inputs use
  the generated `getText()` accessor; frame creation, monitor binding, element
  factories, fluent property setters, click handlers, scheduled work, and the
  event loop remain supported.
- The client transport test covers modem discovery, Rednet server lookup,
  correlated response handling, and session state installation.
- The cashier peripheral test proves only the configured currency item moves
  from input to vault and then to output, leaving other items untouched.
- The in-world preflight checks each role's modem, server discovery, Basalt,
  central data files, trusted IDs, monitor, and cashier inventories before
  acceptance testing.
- The in-world acceptance program creates and settles all ten games and restores
  the acceptance account to its starting balance.

## Known operational limitations

- Rednet is transport, not encryption. Use a private wired network where
  practical and protect the server, admin, and cashier computers physically.
- Player identity is a typed username, suitable for a trusted private world but
  not strong authentication against impersonation.
- Cashier inventory and ledger updates cannot be one atomic operation across
  Minecraft peripherals and files. Stable operation IDs, persisted pending
  state, server status queries, and bounded idempotent refunds handle network
  ambiguity. Power loss during the physical `pushItems` call still requires
  explicit operator review.
- Basalt 2.5 is pinned to a verified upstream commit. First installation still
  depends on GitHub and the CC:Tweaked HTTP API being reachable.
- Idempotency histories grow with financial requests, game actions, and jackpot
  operations. Archive old completed data periodically on a long-running,
  high-volume casino.

## Acceptance gate

Before putting valuable items into the system, complete every check in the
operations guide: deposit, withdrawal and timeout reconciliation, all ten games, duplicate-request
behaviour, restart persistence, backup recovery, permissions, maintenance, and
leaderboard refresh.
