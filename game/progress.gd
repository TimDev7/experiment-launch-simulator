class_name Progress
extends Node
## Сохраняемый прогресс игрока. Живёт под GameData (SaveManager находит serialize/deserialize по детям GameData).

var coins: int = 0
var level: int = 0            # куплено апгрейдов
var best_distance: float = 0.0
var attempts: int = 0
var won: bool = false         # хоть раз добрался до финиша
var attempts_since_free: int = 99  # бесплатный апгрейд за рекламу доступен не чаще раза в 2 полёта


func serialize() -> Dictionary:
	return {"coins": coins, "level": level, "best": best_distance, "attempts": attempts, "won": won, "asf": attempts_since_free}


func deserialize(d: Dictionary) -> void:
	coins = int(d.get("coins", 0))
	level = clampi(int(d.get("level", 0)), 0, Upgrades.count())
	best_distance = float(d.get("best", 0.0))
	attempts = int(d.get("attempts", 0))
	won = bool(d.get("won", false))
	attempts_since_free = int(d.get("asf", 99))


func load_default_data() -> void:
	deserialize({})
