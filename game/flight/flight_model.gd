class_name FlightModel
extends RefCounted
## Чистая 2D-модель полёта (метры, секунды, Y вверх). Без нод — гоняется и в игре, и в headless-симуляции баланса.

const GRAVITY := 9.8
const RAMP_ANGLE := deg_to_rad(38.0)
const RAMP_HEIGHT := 2.5
const PITCH_RATE := 3.2
const AOA_UP := 0.30
const AOA_DOWN := -0.04
const BASE_DRAG := 0.0007
const GROUND_FRICTION := 14.0
const MAX_LIFT := 26.0
const LIFT_SCALE := 0.2

var stats: Dictionary
var x := 0.0
var y := RAMP_HEIGHT
var vx := 0.0
var vy := 0.0
var pitch := RAMP_ANGLE
var fuel := 0.0
var boost_time := 0.0
var flight_time := 0.0
var max_altitude := 0.0
var max_speed := 0.0
var landed := false   # коснулся земли
var finished := false # полностью остановился
var thrusting := false
var pitch_up_input := false
var bounced := false  # событие для звука/эффектов (читать и сбрасывать снаружи)
var boost_thrust := 28.0


func _init(p_stats: Dictionary, power: float) -> void:
	stats = p_stats
	fuel = float(stats["fuel"])
	var v0: float = float(stats["launch"]) * lerpf(0.45, 1.0, clampf(power, 0.0, 1.0))
	vx = cos(RAMP_ANGLE) * v0
	vy = sin(RAMP_ANGLE) * v0


func speed() -> float:
	return Vector2(vx, vy).length()


func distance() -> float:
	return maxf(x, 0.0)


func add_boost(seconds: float) -> void:
	boost_time += seconds


func step(dt: float) -> void:
	if finished:
		return
	flight_time += dt
	var grounded := y <= 0.0 and vy <= 0.0
	var spd := speed()
	var path := atan2(vy, vx) if spd > 0.5 else pitch
	var ax := 0.0
	var ay := -GRAVITY
	thrusting = false
	if not grounded:
		var target := path + (AOA_UP if pitch_up_input else AOA_DOWN)
		var diff := wrapf(target - pitch, -PI, PI)
		pitch += clampf(diff, -PITCH_RATE * dt, PITCH_RATE * dt)
		var aoa := wrapf(pitch - path, -PI, PI)
		# подъёмная сила (перпендикулярно скорости), срыв потока при большом угле атаки
		var lift_k: float = float(stats["wing"]) * clampf(aoa / AOA_UP, -1.0, 1.0)
		if absf(aoa) > 0.5:
			lift_k *= 0.4
		var lift := clampf(lift_k * spd * LIFT_SCALE, -MAX_LIFT, MAX_LIFT)
		if spd > 0.5:
			ax += -vy / spd * lift
			ay += vx / spd * lift
			var drag_k: float = (BASE_DRAG + 0.006 * aoa * aoa) * float(stats["drag"])
			ax -= vx / spd * drag_k * spd * spd
			ay -= vy / spd * drag_k * spd * spd
		var thrust := 0.0
		if fuel > 0.0 and float(stats["thrust"]) > 0.0:
			thrust += float(stats["thrust"])
			fuel = maxf(fuel - dt, 0.0)
			thrusting = true
		if boost_time > 0.0:
			thrust += boost_thrust
			boost_time = maxf(boost_time - dt, 0.0)
			thrusting = true
		ax += cos(pitch) * thrust
		ay += sin(pitch) * thrust
	else:
		# скольжение по земле
		ax = -signf(vx) * GROUND_FRICTION
		ay = 0.0
		pitch = lerpf(pitch, 0.0, minf(dt * 8.0, 1.0))
	vx += ax * dt
	vy += ay * dt
	if grounded and vx < 0.0:
		vx = 0.0
	x += vx * dt
	y += vy * dt
	if y <= 0.0:
		y = 0.0
		if vy < -6.0:
			bounced = true
			vy = -vy * 0.28
			vx *= 0.78
			landed = true
		elif vy < 0.0:
			vy = 0.0
			landed = true
		if y <= 0.0 and vy <= 0.0 and absf(vx) < 1.2:
			vx = 0.0
			finished = true
			landed = true
	max_altitude = maxf(max_altitude, y)
	max_speed = maxf(max_speed, speed())
