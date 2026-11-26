extends Node2D

func _ready():
	# Lets Enter/Space press the button on desktop
	$StartButton.grab_focus()

func _on_start_button_pressed():
	get_tree().change_scene_to_file("res://scenes/Game.tscn")
