# Game Rules and Payouts

All payouts below include the returned stake. For example, a `2x` payout on a
10-credit bet credits 20 after the original 10 was debited. A push credits the
original bet and has zero net effect.

Accounts cannot exceed the server's configured `maximumBalance`. If a payout
would cross that ceiling, the terminal shows that it was capped and reports
both the gross win and the amount actually credited. Any capped progressive
jackpot remainder returns to the progressive pool.

## Slots

The reels use weighted symbols, so lower-paying symbols appear more often.

| Result | Payout |
|---|---:|
| Any pair | Bet returned |
| Three cherries | 2x |
| Three lemons | 3x |
| Three bells | 5x |
| Three diamonds | 8x |
| Three sevens | 15x plus the progressive jackpot |

Up to 20% of each wager feeds the progressive pool. The exact base return is
about 74.53%; including jackpot contributions, every default legal wager stays
below a 95% aggregate expected return. Completed games from the original
paytable remain readable after an update.

## Blackjack

- Six-deck shoe by default.
- Dealer stands on soft 17 unless the server configuration changes it.
- Hit, stand, or double on the first two cards.
- Normal win: `2x`.
- Natural Blackjack: stake plus `3:2` profit.
- Push: bet returned.

## Roulette

European single-zero wheel:

- Exact number, including zero: `36x`.
- Red/black, odd/even, 1–18, or 19–36: `2x`.
- Zero loses every outside bet.

## Crash

The multiplier rises from `1.00x`. Cash out before the hidden crash point to
receive `bet × multiplier`, rounded down to whole credits. The generated curve
has approximately a 1% long-run edge and is capped at `1000x`.

## Mines

Choose 3, 5, or 8 mines on a 5×5 board. Every safe reveal increases the shown
multiplier. Cash out at any time after one safe tile. Hitting a mine loses the
bet. The multiplier includes approximately a 5% long-run edge.

## Plinko

The server generates eight left/right bounces. Bin multipliers from left to
right are:

```text
10x, 3x, 1.5x, 0.7x, 0.3x, 0.7x, 1.5x, 3x, 10x
```

The exact expected return is approximately 98.20%.

## Horse Racing

Pick one of five equally likely horses. The winner pays `5x`, making this a
fair even-return carnival game before variance. Completed races from the
original `4x` paytable remain readable after an update.

## Video Poker

Jacks or Better with one draw:

| Hand | Payout |
|---|---:|
| Royal flush | 250x |
| Straight flush | 50x |
| Four of a kind | 25x |
| Full house | 9x |
| Flush | 6x |
| Straight | 4x |
| Three of a kind | 3x |
| Two pair | 2x |
| Jacks or better | 1x |

Select any cards to hold, then draw once.

## Craps

Pass-line rules:

- Come-out 7 or 11: `2x`.
- Come-out 2, 3, or 12: loss.
- Any other total establishes the point.
- Roll the point again before a 7 to receive `2x`.

## Coin Flip

Call heads or tails. A correct call pays `2x`; this is an even-return game
before variance.
