# HeadupDisplay.gd
# Gameplay timeout and extra time is handle here for convenience
extends CanvasLayer

signal gameplay_timeout

@onready var idle = global.gameplay.idle
@onready var extra_time = global.gameplay.extra_time
@onready var min_extra_time = global.gameplay.min_extra_time

func _ready():
	global.get_game().connect("gameover", Callable(self, "_on_gameover"))
	global.get_game().connect("player_step", Callable(self, "_on_player_step"))
	set_timeout(global.gameplay.idle)

func set_timeout(time):
	# TODO
	#$Tween.stop_all()
	#$Tween.interpolate_property($TextureProgressBar, 'value', (time / global.MAX_IDLE_TIMEOUT) * 100, 0, time, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	#$Tween.start()
	null
	
func get_remaining_time():
	return global.MAX_IDLE_TIMEOUT * ($TextureProgressBar.value / 100)

func add_extra_time(time):
	var new_timeout = min(get_remaining_time() + time, global.MAX_IDLE_TIMEOUT)
	set_timeout(new_timeout)
	
func _on_player_step(_step_count):
	var new_extra_time = extra_time + ((extra_time - min_extra_time) * (1 - global.gameplay.difficulty))
	add_extra_time(new_extra_time)

# TODO move to Game.gd
# func _on_level_up(_level):
#	difficulty = min(1, difficulty + 0.05)

func _on_gameover():
	# TODO
	null

func _on_TextureProgress_value_changed(value):
	if value <= 0:
		emit_signal("gameplay_timeout")
