class_name Economy
extends RefCounted

const COINS_PER_METER := 1.0
const FLAT_BONUS := 5.0
## Дистанция финиша (м): добежать с полной прокачкой.
const GOAL_DISTANCE := 5000.0


static func coins_for(distance: float) -> int:
	return int(floor(distance * COINS_PER_METER + FLAT_BONUS))
