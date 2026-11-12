class_name Upgrades
extends RefCounted
## Линейная цепочка апгрейдов (GDD). Порядок фиксирован, выбора "куда вложить" нет.

## Цены подобраны по tools/sim/balance.gd: ~2 полёта на апгрейд.
const COSTS: Array[int] = [60, 250, 500, 1100, 1400, 2100, 3000, 4500, 4500, 8000]

const LIST: Array[Dictionary] = [
	{"name": "Engine Mk1", "desc": "A tiny rocket motor. Thrust + 3s of fuel.", "thrust": 9.0, "fuel": 3.0},
	{"name": "Wings Mk1", "desc": "Stubby wings give real lift.", "wing": 1.3},
	{"name": "Fuel Tank", "desc": "Burn longer.", "fuel": 4.0},
	{"name": "Streamlining", "desc": "Less air drag.", "drag": 0.85},
	{"name": "Engine Mk2", "desc": "More thrust.", "thrust": 3.0},
	{"name": "Wings Mk2", "desc": "Big wings, big glide.", "wing": 0.6},
	{"name": "Big Tank", "desc": "Even longer burn.", "fuel": 5.0},
	{"name": "Catapult", "desc": "Stronger launch.", "launch": 10.0},
	{"name": "Jet Engine", "desc": "Serious thrust + fuel.", "thrust": 8.0, "fuel": 4.0},
	{"name": "Rocket Booster", "desc": "Final upgrade. Reach the finish line!", "thrust": 10.0, "fuel": 6.0, "wing": 0.3, "drag": 0.9},
]

const BASE := {"thrust": 0.0, "fuel": 0.0, "wing": 0.0, "drag": 1.0, "launch": 20.0}


static func count() -> int:
	return LIST.size()


static func cost(index: int) -> int:
	return COSTS[clampi(index, 0, COSTS.size() - 1)]


## Суммарные параметры самолёта при `level` купленных апгрейдах.
static func stats(level: int) -> Dictionary:
	var s: Dictionary = BASE.duplicate()
	for i in range(mini(level, LIST.size())):
		var u: Dictionary = LIST[i]
		for k in ["thrust", "fuel", "wing", "launch"]:
			if u.has(k):
				s[k] += float(u[k])
		if u.has("drag"):
			s["drag"] *= float(u["drag"])
	return s
