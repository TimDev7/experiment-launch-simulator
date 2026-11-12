extends BaseGame

var progress: Progress


func _ready() -> void:
	# Должен существовать ДО super._ready(): тот регистрирует GameData в SaveManager, который сразу читает сохранение.
	progress = Progress.new()
	progress.name = "Progress"
	$GameData.add_child(progress)
	super._ready()
