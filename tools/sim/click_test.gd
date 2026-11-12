extends Node
## Проверка реальных кликов: godot --path . res://tools/sim/click_test.tscn
var main: Node
var t := 0.0
var step := 0

func _ready() -> void:
	main = load("res://game/main/main.tscn").instantiate()
	add_child(main)
	main.launch_btn.button_down.connect(func(): print("btn down"))
	main.launch_btn.pressed.connect(func(): print("btn pressed"))

func click(pos: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	Input.parse_input_event(m)
	await get_tree().process_frame
	for pressed in [true, false]:
		await get_tree().process_frame
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		Input.parse_input_event(e)

func _process(delta: float) -> void:
	t += delta
	if step == 0 and t > 0.5:
		print("state before: ", main.state, " hovered: ", get_viewport().gui_get_hovered_control()); click(main.launch_btn.get_global_rect().get_center()); step = 1; t = 0
	elif step == 1 and t > 0.3:
		print("hover now: ", get_viewport().gui_get_hovered_control(), " btnrect ", main.launch_btn.get_global_rect(), " vis ", main.launch_btn.is_visible_in_tree()); print("after launch click: ", main.state, " (1=AIM)"); click(Vector2(400, 300)); step = 2; t = 0
	elif step == 2 and t > 0.3:
		print("after tap: ", main.state, " (2=FLIGHT)"); get_tree().quit()
