extends Node
## Прогон игры с автопилотом и скриншотами: godot --path . res://tools/sim/shots.tscn -- <level>
var main: Node
var t := 0.0
var step := 0
var out_dir := "user://shots/"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var args := OS.get_cmdline_user_args()
	var lvl := int(args[0]) if args.size() > 0 else 0
	get_node("/root/Game").progress.level = lvl
	get_node("/root/Game").progress.coins = 0
	get_node("/root/Game").progress.attempts = 3
	get_node("/root/Game").progress.attempts_since_free = 5
	main = load("res://game/main/main.tscn").instantiate()
	add_child(main)

func shot(n: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(out_dir + n + ".png"))
	print("shot ", n)

func _process(delta: float) -> void:
	t += delta
	match step:
		0:
			if t > 0.6: shot("1_hangar"); main._on_launch_pressed(); step = 1; t = 0
		1:
			if t > 0.45: shot("2_aim"); step = 2; t = 0
		2:
			if t > 0.01 and main._power > 0.9 or t > 1.4: main._start_flight(); step = 3; t = 0
		3:
			main._holding = main.model.vy < -1.0 and main.model.y > 4.0
			if t > 2.0: shot("3_flight"); step = 4; t = 0
		4:
			main._holding = main.model.vy < -1.0 and main.model.y > 4.0
			if main.state == main.State.RESULT or main.state == main.State.WIN or t > 90.0:
				step = 5; t = 0
		5:
			if t > 0.4: shot("4_result"); print("dist ", main.model.distance(), " state ", main.state); get_tree().quit(); return
