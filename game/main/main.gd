extends Node
## Контроллер игры: состояния ANGAR -> AIM -> FLIGHT -> RESULT (-> WIN). Весь UI строится кодом.

enum State { HANGAR, AIM, FLIGHT, RESULT, WIN }

const BOOST_SECONDS := 2.5
const INTERSTITIAL_EVERY := 2          # раз в N полётов
const INTERSTITIAL_MIN_GAP_MS := 75000 # не чаще, чем раз в 75 с
const METER_PERIOD := 1.15

var state: State = State.HANGAR
var progress: Progress
var world: WorldView
var model: FlightModel

# UI
var ui: CanvasLayer
var coins_label: Label
var best_label: Label
var hangar_panel: PanelContainer
var up_name: Label
var up_desc: Label
var up_dots: HBoxContainer
var buy_btn: Button
var free_btn: Button
var launch_btn: Button
var aim_box: Control
var meter_fill: ColorRect
var meter_bar: Control
var meter_hint: Label
var hud: Control
var dist_label: Label
var info_label: Label
var fuel_bar: ProgressBar
var boost_btn: Button
var hold_hint: Label
var result_panel: PanelContainer
var result_title: Label
var result_body: Label
var double_btn: Button
var continue_btn: Button
var win_panel: PanelContainer
var toast: Label

var _meter_t := 0.0
var _power := 0.0
var _boost_used := false
var _holding := false
var _earned := 0
var _doubled := false
var _last_ad_ms := 0
var _hint_time := 0.0
var _toast_tween: Tween


func _ready() -> void:
	progress = Game.progress
	# BackgroundManager из шаблона содержит Control-ы со STOP-фильтром мыши: они глотали клики до _unhandled_input
	# (тап по шкале силы и удержание в полёте не работали). Нам нужны клики, а не их фон.
	_ignore_mouse_in(Game.game_data.background_manager)
	world = WorldView.new()
	add_child(world)
	_build_ui()
	_enter_hangar()
	SDK.notify_loading_finished()


func _ignore_mouse_in(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in node.get_children():
		_ignore_mouse_in(c)


# ------------------------------------------------------------------ UI build
func _style(col: Color, radius: int = 14, border: Color = Color(0, 0, 0, 0.35)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(0)
	sb.border_width_bottom = 5
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	return sb


func _label(text: String, size: int, col: Color = Color.WHITE, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("outline_size", maxi(size / 8, 2))
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, col: Color, size: int = 28) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	b.add_theme_constant_override("outline_size", 4)
	b.add_theme_stylebox_override("normal", _style(col))
	b.add_theme_stylebox_override("hover", _style(col.lightened(0.12)))
	b.add_theme_stylebox_override("pressed", _style(col.darkened(0.15)))
	b.add_theme_stylebox_override("disabled", _style(col.darkened(0.5).lerp(Color.GRAY, 0.4)))
	b.pivot_offset_ratio = Vector2(0.5, 0.5)
	b.pressed.connect(func(): Sfx.play("click", 0.5))
	b.add_child(_make_juice())
	return b


func _make_juice() -> Node:
	var scene: PackedScene = load("res://template/ui/components/juicy_button_component.tscn")
	return scene.instantiate()


func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)

	# верхняя панель
	coins_label = _label("", 34, Color("#ffd23f"))
	coins_label.position = Vector2(24, 14)
	root.add_child(coins_label)
	best_label = _label("", 24, Color("#ffffff"), HORIZONTAL_ALIGNMENT_RIGHT)
	best_label.position = Vector2(880, 20)
	best_label.size = Vector2(376, 40)
	root.add_child(best_label)

	_build_hangar(root)
	_build_aim(root)
	_build_hud(root)
	_build_result(root)
	_build_win(root)

	toast = _label("", 30, Color("#fff176"), HORIZONTAL_ALIGNMENT_CENTER)
	toast.position = Vector2(240, 150)
	toast.size = Vector2(800, 50)
	toast.modulate.a = 0.0
	root.add_child(toast)


func _build_hangar(root: Control) -> void:
	hangar_panel = PanelContainer.new()
	hangar_panel.add_theme_stylebox_override("panel", _style(Color(0.08, 0.12, 0.22, 0.88), 20))
	hangar_panel.position = Vector2(700, 96)
	hangar_panel.custom_minimum_size = Vector2(540, 0)
	root.add_child(hangar_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	hangar_panel.add_child(v)
	v.add_child(_label("HANGAR", 22, Color("#8fc9ff")))
	up_name = _label("", 40, Color.WHITE)
	v.add_child(up_name)
	up_desc = _label("", 22, Color("#cfd8e3"))
	up_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	up_desc.custom_minimum_size = Vector2(500, 60)
	v.add_child(up_desc)
	up_dots = HBoxContainer.new()
	up_dots.add_theme_constant_override("separation", 6)
	v.add_child(up_dots)
	buy_btn = _button("", Color("#2e9e5b"), 30)
	buy_btn.pressed.connect(_on_buy)
	v.add_child(buy_btn)
	free_btn = _button("FREE UPGRADE  (watch ad)", Color("#8a4fd8"), 24)
	free_btn.pressed.connect(_on_free_upgrade)
	v.add_child(free_btn)
	launch_btn = _button("LAUNCH!", Color("#e8553d"), 44)
	launch_btn.custom_minimum_size = Vector2(0, 90)
	launch_btn.pressed.connect(_on_launch_pressed)
	v.add_child(launch_btn)


func _build_aim(root: Control) -> void:
	aim_box = Control.new()
	aim_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	aim_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(aim_box)
	meter_bar = Panel.new()
	meter_bar.position = Vector2(340, 560)
	meter_bar.size = Vector2(600, 48)
	meter_bar.add_theme_stylebox_override("panel", _style(Color(0.05, 0.05, 0.1, 0.9), 12))
	meter_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aim_box.add_child(meter_bar)
	var zone := ColorRect.new()
	zone.color = Color("#3ddc84")
	zone.position = Vector2(340 + 6 + (588.0 * 0.86), 566)
	zone.size = Vector2(588.0 * 0.14, 36)
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aim_box.add_child(zone)
	meter_fill = ColorRect.new()
	meter_fill.color = Color("#ffd23f")
	meter_fill.position = Vector2(346, 566)
	meter_fill.size = Vector2(10, 36)
	meter_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aim_box.add_child(meter_fill)
	meter_hint = _label("TAP / CLICK / SPACE at the green zone for max power!", 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	meter_hint.position = Vector2(240, 500)
	meter_hint.size = Vector2(800, 40)
	aim_box.add_child(meter_hint)


func _build_hud(root: Control) -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	dist_label = _label("0 m", 64, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	dist_label.position = Vector2(440, 8)
	dist_label.size = Vector2(400, 80)
	hud.add_child(dist_label)
	info_label = _label("", 22, Color("#e6f3ff"), HORIZONTAL_ALIGNMENT_CENTER)
	info_label.position = Vector2(440, 88)
	info_label.size = Vector2(400, 30)
	hud.add_child(info_label)
	fuel_bar = ProgressBar.new()
	fuel_bar.position = Vector2(24, 96)
	fuel_bar.size = Vector2(240, 22)
	fuel_bar.show_percentage = false
	fuel_bar.add_theme_stylebox_override("background", _style(Color(0, 0, 0, 0.5), 8, Color(0, 0, 0, 0)))
	fuel_bar.add_theme_stylebox_override("fill", _style(Color("#ff9a2e"), 8, Color(0, 0, 0, 0)))
	fuel_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(fuel_bar)
	var fl := _label("FUEL", 18, Color("#ffd9a8"))
	fl.position = Vector2(24, 68)
	hud.add_child(fl)
	boost_btn = _button("BOOST  (watch ad)", Color("#8a4fd8"), 26)
	boost_btn.position = Vector2(960, 590)
	boost_btn.size = Vector2(290, 70)
	boost_btn.pressed.connect(_on_boost_pressed)
	hud.add_child(boost_btn)
	hold_hint = _label("HOLD to pull up  |  RELEASE to dive", 26, Color("#ffffff"), HORIZONTAL_ALIGNMENT_CENTER)
	hold_hint.position = Vector2(290, 640)
	hold_hint.size = Vector2(700, 40)
	hud.add_child(hold_hint)


func _build_result(root: Control) -> void:
	result_panel = PanelContainer.new()
	result_panel.add_theme_stylebox_override("panel", _style(Color(0.08, 0.12, 0.22, 0.92), 22))
	result_panel.custom_minimum_size = Vector2(560, 0)
	result_panel.position = Vector2(360, 120)
	root.add_child(result_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	result_panel.add_child(v)
	result_title = _label("LANDED!", 46, Color("#ffd23f"), HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(result_title)
	result_body = _label("", 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(result_body)
	double_btn = _button("x2 COINS  (watch ad)", Color("#8a4fd8"), 28)
	double_btn.pressed.connect(_on_double_pressed)
	v.add_child(double_btn)
	continue_btn = _button("CONTINUE", Color("#2e9e5b"), 36)
	continue_btn.custom_minimum_size = Vector2(0, 76)
	continue_btn.pressed.connect(_on_continue_pressed)
	v.add_child(continue_btn)


func _build_win(root: Control) -> void:
	win_panel = PanelContainer.new()
	win_panel.add_theme_stylebox_override("panel", _style(Color(0.2, 0.12, 0.04, 0.95), 22, Color("#ffd23f")))
	win_panel.custom_minimum_size = Vector2(640, 0)
	win_panel.position = Vector2(320, 150)
	root.add_child(win_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	win_panel.add_child(v)
	v.add_child(_label("YOU MADE IT!", 60, Color("#ffd23f"), HORIZONTAL_ALIGNMENT_CENTER))
	var t := _label("You crossed the finish line with a fully upgraded plane. Legend!", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(600, 70)
	v.add_child(t)
	var b := _button("KEEP FLYING", Color("#2e9e5b"), 36)
	b.custom_minimum_size = Vector2(0, 76)
	b.pressed.connect(func():
		_enter_hangar())
	v.add_child(b)


# ------------------------------------------------------------------ состояния
func _hide_all() -> void:
	hangar_panel.visible = false
	aim_box.visible = false
	hud.visible = false
	result_panel.visible = false
	win_panel.visible = false


func _refresh_top() -> void:
	coins_label.text = "$ %d" % progress.coins
	best_label.text = "BEST  %d m   |   GOAL  %d m" % [int(progress.best_distance), int(Economy.GOAL_DISTANCE)]


func _enter_hangar() -> void:
	state = State.HANGAR
	_hide_all()
	hangar_panel.visible = true
	world.model = null
	world.reset_to_ramp()
	world.set_build(progress.level)
	_refresh_hangar()


func _refresh_hangar() -> void:
	_refresh_top()
	for c in up_dots.get_children():
		c.queue_free()
	for i in range(Upgrades.count()):
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(44, 12)
		d.color = Color("#3ddc84") if i < progress.level else Color(1, 1, 1, 0.2)
		up_dots.add_child(d)
	if progress.level >= Upgrades.count():
		up_name.text = "Fully upgraded!"
		up_desc.text = "Nothing left to buy. Go for the record distance!"
		buy_btn.visible = false
		free_btn.visible = false
	else:
		var u: Dictionary = Upgrades.LIST[progress.level]
		var cost := Upgrades.cost(progress.level)
		up_name.text = "%d/%d  %s" % [progress.level + 1, Upgrades.count(), u["name"]]
		up_desc.text = u["desc"]
		buy_btn.visible = true
		buy_btn.text = "BUY  -  $ %d" % cost
		buy_btn.disabled = progress.coins < cost
		free_btn.visible = progress.attempts_since_free >= 2 and progress.attempts > 0
	launch_btn.disabled = false


func _on_buy() -> void:
	if progress.level >= Upgrades.count():
		return
	var cost := Upgrades.cost(progress.level)
	if progress.coins < cost:
		return
	progress.coins -= cost
	_apply_upgrade()


func _apply_upgrade() -> void:
	progress.level += 1
	Sfx.play("buy", 0.7)
	world.set_build(progress.level)
	_refresh_hangar()
	_show_toast("UPGRADED!")
	Core.save_manager.save_data()


func _on_free_upgrade() -> void:
	SDK.show_rewarded(func():
		progress.attempts_since_free = 0
		if progress.level < Upgrades.count():
			_apply_upgrade())


func _on_launch_pressed() -> void:
	state = State.AIM
	_hide_all()
	aim_box.visible = true
	_meter_t = 0.0
	_hint_time = 0.0


func _start_flight() -> void:
	state = State.FLIGHT
	_hide_all()
	hud.visible = true
	model = FlightModel.new(Upgrades.stats(progress.level), _power)
	world.model = model
	_boost_used = false
	_holding = false
	boost_btn.disabled = false
	boost_btn.visible = true
	fuel_bar.max_value = maxf(float(model.stats["fuel"]), 0.01)
	fuel_bar.visible = float(model.stats["fuel"]) > 0.0
	hold_hint.visible = true
	_hint_time = 0.0
	Sfx.play("launch", 0.8)
	world.shake = 0.5
	SDK.notify_level_started()
	SDK.notify_gameplay_started()
	if _power >= 0.86:
		_show_toast("PERFECT LAUNCH!")


func _land() -> void:
	state = State.RESULT
	SDK.notify_gameplay_stopped()
	var dist := model.distance()
	var reached_goal := dist >= Economy.GOAL_DISTANCE
	progress.attempts += 1
	progress.attempts_since_free += 1
	var new_record := dist > progress.best_distance and progress.attempts > 1
	progress.best_distance = maxf(progress.best_distance, dist)
	_earned = Economy.coins_for(dist)
	progress.coins += _earned
	_doubled = false
	Sfx.play("thump", 0.8)
	SDK.notify_level_completed(int(dist))
	Core.save_manager.save_data()
	_hide_all()
	if reached_goal and not progress.won:
		progress.won = true
		Sfx.play("win", 0.9)
		win_panel.visible = true
		_refresh_top()
		return
	result_panel.visible = true
	result_title.text = "NEW RECORD!" if new_record else "LANDED!"
	_update_result_text()
	double_btn.visible = true
	double_btn.disabled = false
	_refresh_top()


func _update_result_text() -> void:
	result_body.text = "Distance:  %d m\nTop speed:  %d m/s   Max altitude:  %d m\nEarned:  $ %d%s" % [
		int(model.distance()), int(model.max_speed * 1.0), int(model.max_altitude), _earned, "  (x2!)" if _doubled else ""]
	_refresh_top()


func _on_double_pressed() -> void:
	SDK.show_rewarded(func():
		if _doubled:
			return
		_doubled = true
		progress.coins += _earned
		_earned *= 2
		Sfx.play("coin", 0.8)
		double_btn.disabled = true
		_update_result_text()
		Core.save_manager.save_data())


func _on_continue_pressed() -> void:
	var now := Time.get_ticks_msec()
	var due := progress.attempts % INTERSTITIAL_EVERY == 0 and (now - _last_ad_ms) > INTERSTITIAL_MIN_GAP_MS and progress.attempts > 0
	if due:
		continue_btn.disabled = true
		_last_ad_ms = now
		SDK.show_interstitial(func():
			continue_btn.disabled = false
			_enter_hangar())
	else:
		_enter_hangar()


func _on_boost_pressed() -> void:
	if state != State.FLIGHT or _boost_used:
		return
	SDK.notify_gameplay_stopped()
	SDK.show_rewarded(func():
		_boost_used = true
		boost_btn.disabled = true
		if model and not model.finished:
			model.add_boost(BOOST_SECONDS)
			Sfx.play("boost", 0.8)
			world.shake = 0.4
		SDK.notify_gameplay_started(),
		func():
		SDK.notify_gameplay_started())


# ------------------------------------------------------------------ цикл и ввод
func _process(delta: float) -> void:
	match state:
		State.AIM:
			_meter_t += delta
			var ph := fmod(_meter_t / METER_PERIOD, 2.0)
			_power = ph if ph <= 1.0 else 2.0 - ph
			meter_fill.size.x = maxf(_power * 588.0, 6.0)
			meter_fill.color = Color("#ffd23f").lerp(Color("#3ddc84"), clampf((_power - 0.7) / 0.3, 0.0, 1.0))
		State.FLIGHT:
			_hint_time += delta
			if _hint_time > 6.0:
				hold_hint.visible = false
			var dt := minf(delta, 1.0 / 30.0)
			model.pitch_up_input = _holding
			# фиксированный шаг для стабильности
			var steps := maxi(1, int(ceil(dt / (1.0 / 120.0))))
			for i in steps:
				model.step(dt / steps)
			if model.bounced:
				model.bounced = false
				world.shake = 0.7
				Sfx.play("thump", 0.7)
			dist_label.text = "%d m" % int(model.distance())
			info_label.text = "speed %d m/s    altitude %d m" % [int(model.speed()), int(model.y)]
			fuel_bar.value = model.fuel
			boost_btn.visible = not _boost_used and not model.landed
			if model.finished:
				_land()
	_refresh_top_if_needed()


func _refresh_top_if_needed() -> void:
	if state == State.FLIGHT:
		coins_label.text = "$ %d" % progress.coins


func _unhandled_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed = true
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_UP, KEY_W]:
		pressed = true
	if state == State.AIM and pressed:
		_start_flight()
		return
	if state == State.HANGAR and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_SPACE]:
		_on_launch_pressed()
		return
	if state == State.FLIGHT:
		if pressed:
			_holding = true
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_B, KEY_SHIFT]:
			_on_boost_pressed()


func _input(event: InputEvent) -> void:
	# отпускание ловим всегда, даже если его перехватил GUI
	if state != State.FLIGHT:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_holding = false
	elif event is InputEventScreenTouch and not event.pressed:
		_holding = false
	elif event is InputEventKey and not event.pressed and event.keycode in [KEY_SPACE, KEY_UP, KEY_W]:
		_holding = false


func _show_toast(text: String) -> void:
	toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(0.8)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.5)
