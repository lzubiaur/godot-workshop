# Enemy.gd
# A crab that patrols back and forth between two tiles, hopping one tile per beat.
# Its position is tracked in grid (cartesian) coordinates so hits are decided
# per tile by the Game, not by collision shapes.
extends Area2D

# Emitted when the crab starts a hop: the target tile is occupied from that moment
signal tile_entered(enemy: Node, tile: Vector2)

const Math = preload('res://scripts/Math.gd')

@export var start: Vector2 = Vector2.ZERO	# First patrol tile (grid coords)
@export var end: Vector2 = Vector2.ZERO		# Last patrol tile (grid coords)
@export var step_interval: float = 0.6		# Time between two hops, in seconds
@export var hop_duration: float = 0.15		# Duration of the hop animation, in seconds
@export var delay: float = 0.0				# Extra wait before the first hop, in seconds

var tile: Vector2				# Tile currently occupied (grid coords)

var _patrol: Array[Vector2] = []	# All the tiles between start and end
var _index := 0						# Index of the current tile in _patrol
var _direction := 1					# 1 = towards end, -1 = towards start
var _step_timer: Timer
var _hop_tween: Tween

func _ready():
	_build_patrol()
	# Start somewhere random on the patrol so crabs don't all look the same
	_index = randi() % _patrol.size()
	_direction = 1 if randf() < 0.5 else -1
	tile = _patrol[_index]
	# Set the position now, or the crab is drawn at (0, 0) for one frame
	position = Math.to_iso(tile)

	_step_timer = Timer.new()
	_step_timer.timeout.connect(_hop)
	add_child(_step_timer)
	_step_timer.start(step_interval + delay)

func _build_patrol():
	_patrol.clear()
	var offset := end - start
	var count := int(max(abs(offset.x), abs(offset.y)))
	var direction: Vector2 = offset / count if count > 0 else Vector2.ZERO
	for i in count + 1:
		_patrol.append(start + direction * i)

func _hop():
	# After the first (possibly delayed) hop, keep a regular beat
	_step_timer.wait_time = step_interval
	if _patrol.size() < 2:
		return

	# Turn around at both ends of the patrol
	var next_index := _index + _direction
	if next_index < 0 or next_index >= _patrol.size():
		_direction = -_direction
		next_index = _index + _direction
	_index = next_index
	tile = _patrol[_index]
	tile_entered.emit(self, tile)

	_hop_tween = create_tween()
	_hop_tween.tween_property(self, 'position', Math.to_iso(tile), hop_duration) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)

# Stop moving, e.g. on game over so the player can see what hit them
func freeze():
	_step_timer.stop()
	if _hop_tween:
		_hop_tween.kill()
	$AnimatedSprite2D.pause()
