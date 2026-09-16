class_name MainMenu
extends Control
## Title screen: pick a level.

const TRAINING_SCENE := "res://levels/training/training.tscn"
const BANK_SCENE := "res://levels/bank/bank.tscn"
const DOCKS_SCENE := "res://levels/docks/docks.tscn"
const BUGLE_SCENE := "res://levels/bugle/bugle.tscn"
const STREETS_SCENE := "res://levels/streets/streets.tscn"
const ROOFS_SCENE := "res://levels/roofs/roofs.tscn"
const THEATER_SCENE := "res://levels/theater/theater.tscn"


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	($Center/Menu/BtnTraining as Button).pressed.connect(_on_training)
	($Center/Menu/BtnBank as Button).pressed.connect(_on_bank)
	($Center/Menu/BtnDocks as Button).pressed.connect(_on_docks)
	($Center/Menu/BtnBugle as Button).pressed.connect(_on_bugle)
	($Center/Menu/BtnStreets as Button).pressed.connect(_on_streets)
	($Center/Menu/BtnRoofs as Button).pressed.connect(_on_roofs)
	($Center/Menu/BtnTheater as Button).pressed.connect(_on_theater)
	($Center/Menu/BtnQuit as Button).pressed.connect(_on_quit)


func _on_training() -> void:
	Sfx.play("click")
	Game.change_level(TRAINING_SCENE)


func _on_bank() -> void:
	Sfx.play("click")
	Game.change_level(BANK_SCENE)


func _on_docks() -> void:
	Sfx.play("click")
	Game.change_level(DOCKS_SCENE)


func _on_bugle() -> void:
	Sfx.play("click")
	Game.change_level(BUGLE_SCENE)


func _on_streets() -> void:
	Sfx.play("click")
	Game.change_level(STREETS_SCENE)


func _on_roofs() -> void:
	Sfx.play("click")
	Game.change_level(ROOFS_SCENE)


func _on_theater() -> void:
	Sfx.play("click")
	Game.change_level(THEATER_SCENE)


func _on_quit() -> void:
	get_tree().quit()
