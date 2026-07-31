# Operations Guide

## 1. Choose an installation source

The recommended public GitHub installer needs no disk:

```text
wget run https://raw.githubusercontent.com/Harvey12432/mc-casino/main/bootstrap.lua server
```

Replace `server` with a terminal role when installing a client. HTTP must be
enabled in the CC:Tweaked server configuration. A failed download stops before
changing `/casino` and leaves `/.mc-casino-download` available for inspection.
Successful installation removes that staging directory.

For an offline installation, copy the repository folder to a ComputerCraft disk
so the installer is located at `/disk/casino/installer`.

All computers need an attached modem. Advanced computers are recommended for
clients. Run `id` on the cashier and admin computers and record their numeric
ComputerCraft IDs.

## 2. Install the central server

Using GitHub, run:

```text
wget run https://raw.githubusercontent.com/Harvey12432/mc-casino/main/bootstrap.lua server
```

Or, using the offline disk, run:

```text
disk/casino/installer/install_server.lua
```

On a new computer, the server setup wizard opens automatically. It detects the
attached modem and guides you through:

- shared casino identity and server hostname;
- trusted cashier and administrator computer IDs;
- currency item and credits-per-item conversion;
- minimum bet, maximum bet, and maximum player balance; and
- Blackjack shoe size and the soft-17 rule.

Every screen validates its answer and shows the current value. Review the final
summary, save, and run `/casino/dev/preflight.lua server`. Reopen the wizard at
any time with `/casino/setup.lua`; it preserves the previous configuration at
`/casino/config.before-setup.lua`. Reboot only after preflight passes. The
server should then print that it is online.

`blackjackDecks` may be 1–8. Bets and all balances are whole credits. If a win
would raise an account above `maximumBalance`, only the available capacity is
credited and the terminal reports both the credited and gross payout. Any
uncredited progressive-jackpot portion is returned to the jackpot rather than
being lost.

Live state is stored in:

- `/casino/data/players.json`
- `/casino/data/transactions.json`
- `/casino/data/jackpots.json`
- `/casino/data/games.json`
- `/casino/data/system.json`

Each file also gains a `.bak` previous snapshot after updates. Back up the whole
`/casino/data` directory before changing rules or updating the server.

On startup, a missing or invalid live file is restored from its valid `.bak`
snapshot. If neither copy passes its schema, the server stops instead of
silently replacing financial data. Preserve both files and investigate the
reported path.

## 3. Install clients

On each computer, run the GitHub command with the matching role:

```text
wget run https://raw.githubusercontent.com/Harvey12432/mc-casino/main/bootstrap.lua blackjack
wget run https://raw.githubusercontent.com/Harvey12432/mc-casino/main/bootstrap.lua slots
```

Alternatively, insert the offline package disk and run:

```text
disk/casino/installer/install_terminal.lua blackjack
disk/casino/installer/install_terminal.lua slots
disk/casino/installer/install_terminal.lua roulette
disk/casino/installer/install_terminal.lua crash
disk/casino/installer/install_terminal.lua mines
disk/casino/installer/install_terminal.lua plinko
disk/casino/installer/install_terminal.lua horse_racing
disk/casino/installer/install_terminal.lua poker
disk/casino/installer/install_terminal.lua craps
disk/casino/installer/install_terminal.lua coin_flip
disk/casino/installer/install_terminal.lua cashier
disk/casino/installer/install_terminal.lua leaderboard
disk/casino/installer/install_terminal.lua admin
```

Use only the command matching that computer's role. The first terminal
installation downloads the pinned Basalt 2.5 bundle, so HTTP must be enabled
temporarily. Rerunning the installer upgrades an older Basalt installation and
records the installed revision in `/casino/basalt.version`.

Each new role opens its own setup wizard. Game and admin terminals ask only for
casino identity, server hostname, and a detected modem. Cashier and leaderboard
roles add their relevant peripherals. Run `/casino/setup.lua` later to review
or change that computer without editing Lua.

On first boot, player, cashier, and admin clients ask for a name and store it in
the CC:Tweaked settings file. Game terminals include **CHANGE PLAYER**, which
closes the current session, clears the saved name, and returns to the login
prompt. The public leaderboard starts unattended and does not create a player
account.

Clients automatically open a replacement session when the server has restarted
or an old session expires. A terminal reboot should not normally be required
after a server restart.

## 4. Configure cashier inventories

The cashier needs three inventories visible as peripherals:

- Input: players place currency items here.
- Vault: deposited items are stored here.
- Output: withdrawn prizes appear here.

The cashier setup wizard lists compatible attached inventories. Select a
different detected peripheral for input, vault, and output, then confirm the
currency item and conversion rate. It rejects duplicate or incompatible
choices before saving.

The server and cashier must use the same currency item and conversion rate.
The cashier refuses to start when either value differs, and its preflight
reports the exact server-side currency settings.

The cashier stores one unresolved transfer in the `casino.cashier.pending`
setting. If the screen reports a pending operation, press **RECONCILE**. Never
move items manually while reconciliation is running.

If power was lost during the physical inventory movement, automatic recovery
stops with an operator-review message because neither Rednet nor Minecraft
inventories provide a transaction spanning both systems. Inspect the input,
vault, output, player balance, and transaction log. After correcting them,
clear the marker with `unset casino.cashier.pending`.

## 5. Acceptance test

Use disposable items for this test.

1. On every installed computer, run
   `/casino/dev/preflight.lua <role>` using its actual role. For an offline
   disk install, use `disk/casino/dev/preflight.lua <role>`. Resolve every
   failure before continuing.
2. From the installed, authorised admin computer, run
   `/casino/dev/acceptance.lua` after a GitHub installation, or
   `disk/casino/dev/acceptance.lua` from the offline disk. It plays all ten
   games and restores its
   test balance; confirm every check passes. Acceptance games use isolated
   transaction kinds, do not move the live progressive jackpot, do not change
   house-profit reporting, and do not appear in recent wins or the public
   leaderboard.
3. Deposit 20 items for a new player and confirm a 20-credit balance.
4. Restart the server and confirm the same balance.
5. Play a 5-credit Slots spin and confirm exactly one bet and any payout.
6. Play Blackjack through hit/stand and confirm settlement.
7. Start another Blackjack hand and test double-down.
8. Play Roulette, Crash, Mines, Plinko, Horse Racing, Video Poker, Craps, and
   Coin Flip once each. For interactive games, finish or cash out the round.
   During a second pass, restart a terminal during Blackjack, Crash, Mines,
   Video Poker, and after a Craps point is established; confirm each unfinished
   round returns instead of charging a second bet.
9. Withdraw five credits and confirm five items arrive in output.
10. Confirm the admin can view balances and transactions.
11. Enable maintenance and confirm new games are rejected.
12. Disable maintenance and confirm games resume.
13. Disable the Slots computer by ID and confirm it is rejected; re-enable it
    and confirm it reconnects.
14. Confirm the public monitor updates jackpot and leaderboard within five
    seconds.
15. Restart all computers and confirm balances and completed games persist.
16. Copy the data directory, corrupt one live JSON file, reboot, and confirm the
    previous `.bak` snapshot is recovered. Restore the copied data afterward.
17. Disconnect the cashier modem during a disposable deposit and withdrawal.
    Reconnect it, press **RECONCILE**, and confirm neither items nor credits are
    duplicated.

Do not open the casino until every step passes with the actual modpack and
peripheral layout.

Keep `docs/GAME_RULES.md` available to players and operators. Its payout table
matches the rules enforced by this release.

## 6. Updates

The GitHub bootstrap also performs preservation-safe updates. Rerun the same
role command:

```text
wget run https://raw.githubusercontent.com/Harvey12432/mc-casino/main/bootstrap.lua server
wget run https://raw.githubusercontent.com/Harvey12432/mc-casino/main/bootstrap.lua blackjack
```

For an offline update with the package disk inserted:

```text
disk/casino/installer/update.lua server
disk/casino/installer/update.lua blackjack
```

Use the correct role. Updates preserve `/casino/config.lua`,
`/casino/basalt.lua`, and `/casino/data`.

The first installation also preserves any pre-existing `/startup.lua` as
`/startup.before-mc-casino.lua`. The backup is not overwritten by later casino
updates.

The hardened data schema accepts Minecraft-style player names containing only
letters, digits, and underscores. Before upgrading an older deployment that
allowed other names, make a full data backup and migrate those account IDs and
their matching transaction/game references while the server is offline.
