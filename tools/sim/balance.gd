extends SceneTree
## Headless-симуляция баланса: godot --headless --path . -s res://tools/sim/balance.gd
## Бот: держит "нос вверх", когда падает; идеальный и средний запуск.

func run(level: int, power: float, bot: bool) -> FlightModel:
	var m := FlightModel.new(Upgrades.stats(level), power)
	var t := 0.0
	while not m.finished and t < 600.0:
		if bot:
			m.pitch_up_input = (m.vy < -1.0 and m.y > 4.0) or (m.y < 1.5 and m.vy < 0.0)
		else:
			m.pitch_up_input = false
		m.step(1.0 / 60.0)
		t += 1.0 / 60.0
	return m

func _init() -> void:
	var bank := 0.0
	for lv in range(Upgrades.count() + 1):
		var good := run(lv, 0.97, true)
		var avg := run(lv, 0.75, true)
		var dumb := run(lv, 0.75, false)
		var cost := Upgrades.cost(lv) if lv < Upgrades.count() else 0
		print("lvl %2d  bot-good %7.0fm  bot-avg %7.0fm  nohold %7.0fm  t=%5.1fs  next cost %d  runs-to-afford(avg) %.1f" % [
			lv, good.distance(), avg.distance(), dumb.distance(), good.flight_time, cost, float(cost) / maxf(avg.distance() * Economy.COINS_PER_METER + Economy.FLAT_BONUS, 1.0)])
	quit()
