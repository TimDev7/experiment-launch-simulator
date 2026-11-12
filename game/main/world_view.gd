class_name WorldView
extends Node2D
## Рисует весь мир кодом: небо, параллакс, облака, землю с метками, самолёт, частицы.

const SCREEN_W := 1280.0
const SCREEN_H := 720.0
const GROUND_Y := 640.0
const PLANE_SCREEN_X := 360.0

var model: FlightModel            # null в ангаре
var level: int = 0
var stats: Dictionary = Upgrades.stats(0)
var cam_x := 0.0
var scale_px := 14.0              # пикселей на метр
var idle_time := 0.0
var shake := 0.0
var goal := Economy.GOAL_DISTANCE
var _particles: Array[Dictionary] = []
var _font: Font = ThemeDB.fallback_font
var _rng := RandomNumberGenerator.new()
var _plane_pos := Vector2.ZERO    # метры
var _plane_pitch := FlightModel.RAMP_ANGLE
var _thrusting := false


func _ready() -> void:
	_rng.randomize()
	z_index = -5
	reset_to_ramp()


func set_build(p_level: int) -> void:
	level = p_level
	stats = Upgrades.stats(p_level)


func reset_to_ramp() -> void:
	model = null
	cam_x = -(PLANE_SCREEN_X / 14.0)
	scale_px = 14.0
	_plane_pos = Vector2(0.0, FlightModel.RAMP_HEIGHT)
	_plane_pitch = FlightModel.RAMP_ANGLE
	_thrusting = false
	_particles.clear()


func _process(delta: float) -> void:
	idle_time += delta
	var target_scale := 14.0
	if model:
		_plane_pos = Vector2(model.x, model.y)
		_plane_pitch = model.pitch
		_thrusting = model.thrusting
		target_scale = clampf(520.0 / (model.y + 36.0), 1.0, 14.0)
		cam_x = model.x - (PLANE_SCREEN_X / scale_px)
		var tail := _plane_pos - Vector2(cos(_plane_pitch), sin(_plane_pitch)) * 2.4
		if _thrusting:
			_emit(tail, true)
		elif model.speed() > 25.0 and not model.landed and _rng.randf() < 0.3:
			_emit(tail, false)
		if model.y <= 0.05 and model.speed() > 6.0 and _rng.randf() < 0.8:
			_emit_dust(Vector2(model.x, 0.0))
	else:
		cam_x = -(PLANE_SCREEN_X / scale_px)
		_plane_pos = Vector2(0.0, FlightModel.RAMP_HEIGHT + sin(idle_time * 3.0) * 0.06)
		_plane_pitch = FlightModel.RAMP_ANGLE
		_thrusting = false
	scale_px = lerpf(scale_px, target_scale, minf(delta * 4.0, 1.0))
	shake = maxf(shake - delta * 2.5, 0.0)
	for p in _particles:
		p["life"] = float(p["life"]) - delta
		p["pos"] = Vector2(p["pos"]) + Vector2(p["vel"]) * delta
	_particles = _particles.filter(func(p): return float(p["life"]) > 0.0)
	queue_redraw()


func _emit(world: Vector2, fire: bool) -> void:
	_particles.append({
		"pos": world, "vel": Vector2(_rng.randf_range(-3, 3), _rng.randf_range(-3, 3)),
		"life": 0.6 if fire else 1.0, "max": 0.6 if fire else 1.0, "fire": fire,
		"size": _rng.randf_range(0.6, 1.3)})


func _emit_dust(world: Vector2) -> void:
	_particles.append({
		"pos": world, "vel": Vector2(_rng.randf_range(2, 10), _rng.randf_range(2, 8)),
		"life": 0.7, "max": 0.7, "fire": false, "dust": true, "size": _rng.randf_range(0.6, 1.4)})


## мир (метры) -> экран (пиксели)
func w2s(wx: float, wy: float) -> Vector2:
	return Vector2((wx - cam_x) * scale_px, GROUND_Y - wy * scale_px)


func _draw() -> void:
	var off := Vector2.ZERO
	if shake > 0.0:
		off = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * shake * 10.0
	draw_set_transform(off)
	_draw_sky()
	_draw_hills(0.05, Color("#7fb5d9"), 330.0, 60.0, 0.004)
	_draw_clouds()
	_draw_hills(0.15, Color("#5f9fb8"), 400.0, 80.0, 0.006)
	_draw_hills(0.35, Color("#4f9a6e"), 500.0, 50.0, 0.012)
	_draw_ground()
	_draw_markers()
	_draw_particles()
	_draw_plane()
	draw_set_transform(Vector2.ZERO)


func _altitude_t() -> float:
	return clampf(_plane_pos.y / 600.0, 0.0, 1.0)


func _draw_sky() -> void:
	var t := _altitude_t()
	var top := Color("#5ec1ff").lerp(Color("#0b1740"), t)
	var bottom := Color("#c9ecff").lerp(Color("#3b6fb0"), t)
	var pts := PackedVector2Array([Vector2(-20, -20), Vector2(SCREEN_W + 20, -20), Vector2(SCREEN_W + 20, SCREEN_H + 20), Vector2(-20, SCREEN_H + 20)])
	var cols := PackedColorArray([top, top, bottom, bottom])
	draw_polygon(pts, cols)
	if t > 0.5:
		for i in 40:
			var h: int = hash(i * 7919)
			var sx := float(h % 1280)
			var sy := float((h / 1280) % 500)
			draw_circle(Vector2(sx, sy), 1.2, Color(1, 1, 1, (t - 0.5) * 1.6))


func _draw_hills(factor: float, col: Color, base_y: float, amp: float, freq: float) -> void:
	var shift := -cam_x * 14.0 * factor
	var drop := _plane_pos.y * 14.0 * factor * 0.3 * (scale_px / 14.0)
	var pts := PackedVector2Array()
	var step := 40.0
	var x := -step
	while x <= SCREEN_W + step:
		var wx := x - shift
		var y := base_y + drop + sin(wx * freq) * amp + sin(wx * freq * 2.3 + 1.7) * amp * 0.4
		pts.append(Vector2(x, y))
		x += step
	pts.append(Vector2(SCREEN_W + step, SCREEN_H + 50))
	pts.append(Vector2(-step, SCREEN_H + 50))
	draw_colored_polygon(pts, col)


func _draw_clouds() -> void:
	var shift := -cam_x * 14.0 * 0.25
	var cell := 380.0
	var first := int(floor((-shift) / cell)) - 1
	for i in range(first, first + 5):
		var h: int = hash(i * 15485863)
		var cx := i * cell + float(h % 200) + shift
		var cy := 100.0 + float((h / 200) % 260) + _plane_pos.y * scale_px * 0.15
		var r := 28.0 + float(h % 23)
		var col := Color(1, 1, 1, 0.85)
		draw_circle(Vector2(cx, cy), r, col)
		draw_circle(Vector2(cx + r * 0.9, cy + 6), r * 0.8, col)
		draw_circle(Vector2(cx - r * 0.9, cy + 8), r * 0.7, col)


func _draw_ground() -> void:
	var gy := w2s(0, 0).y
	draw_rect(Rect2(-20, gy, SCREEN_W + 40, SCREEN_H - gy + 40), Color("#6b4a2f"))
	draw_rect(Rect2(-20, gy, SCREEN_W + 40, 14), Color("#58b45a"))
	draw_rect(Rect2(-20, gy + 14, SCREEN_W + 40, 6), Color("#3f8a46"))
	if cam_x < 12.0:
		var a := w2s(-12, 0)
		var b := w2s(0.0, FlightModel.RAMP_HEIGHT - 0.4)
		var c := w2s(0.0, 0)
		draw_colored_polygon(PackedVector2Array([a, b, c]), Color("#8a8f98"))
		draw_line(a, b, Color("#c3c8d0"), 4.0)
		draw_line(w2s(-5.0, 0), w2s(-5.0, FlightModel.RAMP_HEIGHT * 0.5), Color("#5c6068"), 3.0)


func _draw_markers() -> void:
	var step_m := 100.0
	while step_m * scale_px < 170.0:
		step_m *= 5.0 if step_m < 500.0 else 2.0
	var left_m := cam_x
	var right_m := cam_x + SCREEN_W / scale_px
	var m := ceilf(left_m / step_m) * step_m
	while m <= right_m:
		if m > 0.0:
			var p := w2s(m, 0)
			draw_rect(Rect2(p.x - 2, p.y - 46, 4, 46), Color.WHITE)
			draw_rect(Rect2(p.x - 34, p.y - 70, 68, 28), Color("#f5c842"))
			draw_string(_font, Vector2(p.x - 32, p.y - 50), "%d m" % int(m), HORIZONTAL_ALIGNMENT_CENTER, 64, 18, Color("#3b2a05"))
		m += step_m
	if goal > left_m and goal < right_m:
		var g := w2s(goal, 0)
		for i in 10:
			var col := Color.WHITE if (i % 2 + (i / 2) % 2) % 2 == 0 else Color.BLACK
			draw_rect(Rect2(g.x - 20 + (i % 2) * 20, g.y - 200 + (i / 2) * 20, 20, 20), col)
		draw_rect(Rect2(g.x - 22, g.y - 220, 6, 220), Color("#d33"))
		draw_string(_font, Vector2(g.x - 60, g.y - 230), "FINISH", HORIZONTAL_ALIGNMENT_CENTER, 120, 28, Color("#ffeb3b"))


func _draw_particles() -> void:
	for p in _particles:
		var k := float(p["life"]) / float(p["max"])
		var pp: Vector2 = p["pos"]
		var sp := w2s(pp.x, pp.y)
		var r := maxf(float(p["size"]) * scale_px * 0.5, 3.0)
		var col: Color
		if p["fire"]:
			col = Color("#ffd23f").lerp(Color("#ff5a1f"), 1.0 - k)
			col.a = 0.9 * k
			r *= k + 0.3
		elif p.has("dust"):
			col = Color(0.8, 0.7, 0.5, 0.6 * k)
			r *= 1.5 - k
		else:
			col = Color(1, 1, 1, 0.35 * k)
			r *= 1.5 - k
		draw_circle(sp, r, col)


func _pt(local: Vector2, mul: float) -> Vector2:
	var c := cos(_plane_pitch)
	var s := sin(_plane_pitch)
	var r := Vector2(local.x * c - local.y * s, local.x * s + local.y * c) * mul
	return w2s(_plane_pos.x + r.x, _plane_pos.y + r.y)


func _poly(pts: Array, mul: float, col: Color) -> void:
	var out := PackedVector2Array()
	for p in pts:
		out.append(_pt(p, mul))
	draw_colored_polygon(out, col)
	out.append(out[0])
	draw_polyline(out, col.darkened(0.45), 2.0)


func _draw_plane() -> void:
	var mul := maxf(1.5, 9.0 / scale_px)
	var body_col := Color("#e8553d") if level < 5 else (Color("#3d8be8") if level < 9 else Color("#f5c842"))
	_poly([Vector2(-2, 0.25), Vector2(-2.8, 1.3), Vector2(-1.5, 0.3)], mul, body_col.darkened(0.2))
	if float(stats["wing"]) > 0.0:
		var w: float = 0.7 + float(stats["wing"]) * 0.55
		_poly([Vector2(0.9, 0.15), Vector2(-0.9, 0.15), Vector2(-1.6, 0.15 + w), Vector2(-0.4, 0.15 + w)], mul, Color("#f2f2f2"))
		_poly([Vector2(0.9, -0.05), Vector2(-0.9, -0.05), Vector2(-1.6, -0.05 - w * 0.5), Vector2(-0.4, -0.05 - w * 0.5)], mul, Color("#d6dbe0"))
	if float(stats["fuel"]) > 3.5:
		_poly([Vector2(-1.4, -0.35), Vector2(0.3, -0.35), Vector2(0.3, -0.75), Vector2(-1.4, -0.75)], mul, Color("#5c6068"))
	_poly([Vector2(-2.1, -0.4), Vector2(1.3, -0.4), Vector2(2.4, 0.0), Vector2(1.3, 0.5), Vector2(-2.1, 0.4)], mul, body_col)
	_poly([Vector2(0.2, 0.3), Vector2(1.2, 0.3), Vector2(1.5, 0.05), Vector2(0.2, 0.05)], mul, Color("#aee6ff"))
	if float(stats["thrust"]) > 0.0:
		_poly([Vector2(-2.1, -0.3), Vector2(-2.6, -0.4), Vector2(-2.6, 0.4), Vector2(-2.1, 0.3)], mul, Color("#444444"))
		if _thrusting:
			var fl := 1.0 + _rng.randf() * 0.6
			_poly([Vector2(-2.6, -0.3), Vector2(-2.6 - 1.8 * fl, 0.0), Vector2(-2.6, 0.3)], mul, Color("#ffb52e"))
			_poly([Vector2(-2.6, -0.15), Vector2(-2.6 - 1.0 * fl, 0.0), Vector2(-2.6, 0.15)], mul, Color("#fff3a0"))
