# Global.gd
# Singleton are autoloaded and can be used to handle global game systems and data (settings, player's info...)
# http://docs.godotengine.org/en/3.0/getting_started/step_by_step/singletons_autoload.html

extends Node

# Current scene
var current_scene = null

# Player state
var gold = 0
var score = 0
var level = 0
var high = 0
var total = 0

# Game settings
var settings = {
	sound_on = true,
	music_on = true
}

const STEP_DURATION = 0.3	# Time to animate a full jump/dash 
const MAX_IDLE_TIMEOUT = 5

# Gameplay parameters
var gameplay = {
	idle = MAX_IDLE_TIMEOUT,	# Max idle timeout in seconds before gameover
	extra_time = 0.4,			# Extra time allowed on each successful step
	min_extra_time = 0.3,		# Should be the same that (or close to) Global.STEP_DURATION
	difficulty = 0				# difficulty ratio (0 = easy, 1 = hard)
}

func get_game():
	return $"/root/Game"

func _ready():
	var root = get_tree().get_root()
	current_scene = root.get_child(root.get_child_count() -1)
