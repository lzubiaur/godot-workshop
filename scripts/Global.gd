# Global.gd
# Singleton are autoloaded and can be used to handle global game systems and data (settings, player's info...)
# http://docs.godotengine.org/en/3.0/getting_started/step_by_step/singletons_autoload.html

extends Node

const SAVE_PATH = "user://save.cfg"

# Current scene
var current_scene = null

# Player state (kept here because the Game scene is reloaded on retry)
var gold = 0
var score = 0
var high = 0
var total = 0

# Game settings
var settings = {
	sound_on = true,
	music_on = true
}

const STEP_DURATION = 0.3	# Time to animate a full jump/dash

func get_game():
	return $"/root/Game"

func _ready():
	var root = get_tree().get_root()
	current_scene = root.get_child(root.get_child_count() -1)
	load_high_score()

func load_high_score():
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		high = config.get_value("scores", "high", 0)

func save_high_score():
	var config = ConfigFile.new()
	config.load(SAVE_PATH)	# Keep any other saved values
	config.set_value("scores", "high", high)
	config.save(SAVE_PATH)
