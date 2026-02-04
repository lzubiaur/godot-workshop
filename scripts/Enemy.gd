# Enemy.gd
extends Area2D

signal finished

const Math = preload('res://scripts/Math.gd')

@export var start: Vector2 = Vector2(0, 0): get = _get_start, set = _set_start
@export var end: Vector2 = Vector2(0, 0): get = _get_end, set = _set_end
@export var velocity: int = 10: get = _get_velocity, set = _set_velocity
@export var delay: int = 0: get = _get_delay, set = _set_delay

func _ready():
	move_along_path()

func move_along_path():
	var p_start = Math.to_iso(start)
	var p_end = Math.to_iso(end)
	var length = p_start.distance_to(p_end)
	var duration = length / velocity
	var tween = create_tween()
	# don't defer setting the position to the next update (tween) or it will enter the scene at 0,0
	position = p_start
	tween.tween_property(self, 'position', p_end, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(on_move_along_path_callback).set_delay(duration)
	tween.play()

func on_move_along_path_callback():
	emit_signal('finished')

func _set_start(value):
	start = value

func _get_start():
	return start

func _set_end(value):
	end = value

func _get_end():
	return end

func _set_velocity(value):
	velocity = value

func _get_velocity():
	return velocity

func _set_delay(value):
	delay = value

func _get_delay():
	return delay
