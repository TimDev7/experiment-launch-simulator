class_name Sfx
extends RefCounted
## Процедурные звуки без аудио-ассетов.

const RATE := 22050
static var _cache: Dictionary = {}


static func play(kind: String, volume: float = 0.6, pitch_var: float = 0.05) -> void:
	if not _cache.has(kind):
		_cache[kind] = _make(kind)
	Core.sound_manager.play_sfx(_cache[kind], volume, pitch_var)


static func _tone(freq0: float, freq1: float, dur: float, wave: String = "sine", decay: float = 4.0, noise_mix: float = 0.0) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(n):
		var t := float(i) / n
		var f := lerpf(freq0, freq1, t)
		phase += TAU * f / RATE
		var s := 0.0
		match wave:
			"sine": s = sin(phase)
			"square": s = 1.0 if sin(phase) > 0.0 else -1.0
			"saw": s = fposmod(phase / TAU, 1.0) * 2.0 - 1.0
		s = lerpf(s, rng.randf_range(-1.0, 1.0), noise_mix)
		var env := exp(-decay * t) * minf(1.0, float(i) / 80.0)
		data.encode_s16(i * 2, int(clampf(s * env, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


static func _make(kind: String) -> AudioStreamWAV:
	match kind:
		"click": return _tone(520.0, 700.0, 0.07, "square", 6.0)
		"buy": return _tone(440.0, 1100.0, 0.28, "square", 3.0)
		"coin": return _tone(900.0, 1400.0, 0.12, "sine", 4.0)
		"launch": return _tone(120.0, 600.0, 0.5, "saw", 2.5, 0.35)
		"boost": return _tone(200.0, 900.0, 0.6, "saw", 2.0, 0.3)
		"thump": return _tone(110.0, 40.0, 0.35, "sine", 4.0, 0.25)
		"tick": return _tone(1000.0, 1000.0, 0.03, "square", 8.0)
		"win": return _tone(500.0, 1500.0, 0.8, "square", 1.5)
		"fail": return _tone(300.0, 120.0, 0.4, "saw", 3.0)
	return _tone(440.0, 440.0, 0.1)
