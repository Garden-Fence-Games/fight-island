class_name Economy
extends RefCounted
## What an upgrade costs. Arithmetic and nothing else — the balance itself lives on `GameState`,
## and a wave's reward lives on `WaveConfig` with the rest of that wave's figures.
##
## **The curve is the design, not the numbers.** Rewards rise by a flat twelve a wave while costs
## rise by three fifths a level, so the gap widens on purpose: a fifteen-wave run earns a little
## over two thousand and maxing one track costs 795, which buys two tracks and change out of five.
## What the player gives up is the subject of the game, and it is this ratio that decides it.

const BASE_COST: float = 50.0
const GROWTH: float = 1.6
## Money is read at a glance in the middle of a fight. Prices land on fives so they can be.
const ROUNDING: int = 5
const LEVEL_CAP: int = 5


## What it costs to buy the next level of a track, given how many of it are already owned.
static func upgrade_cost(owned: int) -> int:
	if owned < 0 or owned >= LEVEL_CAP:
		return 0
	var raw := BASE_COST * pow(GROWTH, float(owned))
	return int(roundf(raw / float(ROUNDING))) * ROUNDING


## Every level of one track, which is the figure the whole economy is balanced against.
static func track_cost() -> int:
	var total := 0
	for owned: int in LEVEL_CAP:
		total += upgrade_cost(owned)
	return total


## Thousands separated the way every screen that prints money shows them. Here rather than on each
## of them: the purse, the HUD and the feed all print the same balance, and three copies of one
## rule is three places for a comma to go missing from.
static func grouped(amount: int) -> String:
	var digits := str(absi(amount))
	var out := ""
	for index: int in digits.length():
		if index > 0 and (digits.length() - index) % 3 == 0:
			out += ","
		out += digits[index]
	return ("-" if amount < 0 else "") + out
