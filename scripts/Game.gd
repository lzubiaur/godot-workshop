extends Node2D

const Math = preload('res://scripts/Math.gd')
const Enemy = preload("res://scenes/Enemy.tscn")
const TilesGenerator = preload("res://scripts/TilesGenerator.gd")

signal gameover
signal player_step
signal level_up

var tiles_gen = TilesGenerator.new()

@onready var player = $Player
@onready var path = $Path2D
@onready var path_follow = $Path2D/PathFollow2D
@onready var tileMap = $GroundTileMap

var isGameover = false
var isInvicible = false

var moving = false		# True while the player is in the air (from takeoff to landing)
var cached_inputs = {
	jump = false,
	dash = false
}

# Crab tuning
@export var crab_patrol_range := 2		# Tiles a crab can walk on each side of its spawn tile
@export var crab_grace_time := 0.1		# Time to escape when a crab steps onto the player's tile

var player_tile := Vector2.ZERO			# Tile the player stands on (grid coords)
var enemies = []
var crab_grace_timer: Timer

func _enter_tree():
	randomize()
	initialize_level_parameters()	

func _ready():
	initialize_crab_grace_timer()
	initialize_tiles_generator()
	start_game()

func initialize_crab_grace_timer():
	crab_grace_timer = Timer.new()
	crab_grace_timer.one_shot = true
	crab_grace_timer.wait_time = crab_grace_time
	crab_grace_timer.timeout.connect(_on_crab_grace_timeout)
	add_child(crab_grace_timer)

func initialize_tiles_generator():
	add_child(tiles_gen)
	tiles_gen.connect("new_tile", Callable(self, "on_new_tile"))
	tiles_gen.connect("spawn_enemy", Callable(self, "on_spawn_enemy"))

func initialize_level_parameters():
	global.gameplay.idle = global.MAX_IDLE_TIMEOUT * 0.6
	global.score = 0
	global.level = 0

func start_game():
	isGameover = false
	tiles_gen.start_generating_tiles()
	tiles_gen.pop() # skip the start position cell
	get_tree().paused = false
	set_player_look_at(tiles_gen.front())

func on_new_tile(position: Vector2, tileType):
	tileMap.call_deferred('set_cell', 0, position, 0, tile_type_to_atlas_coords(tileType))

func tile_type_to_atlas_coords(tileType: int):
	match tileType:
		tiles_gen.TileType.Empty:
			return Vector2i(-1, -1)
		tiles_gen.TileType.Ground:
			return Vector2i(0, 0)
		tiles_gen.TileType.Hole:
			return Vector2i(3, 0)

func atlas_coords_to_tile_type(coords: Vector2i):
	match coords:
		Vector2i(-1, -1):
			return tiles_gen.TileType.Empty 
		Vector2i(0, 0):
			return tiles_gen.TileType.Ground
		Vector2i(3, 0):
			return tiles_gen.TileType.Hole

func set_player_look_at(point):
	player.player_look_at(Math.to_iso(point))

func on_spawn_enemy(position):
	var enemy = Enemy.instantiate()
	enemy.z_index = 10
	enemy.start = position - Vector2(crab_patrol_range, 0)
	enemy.end = position + Vector2(crab_patrol_range, 0)
	enemy.tile_entered.connect(_on_enemy_tile_entered)
	enemies.append(enemy)
	tileMap.call_deferred('add_child', enemy)

func is_enemy_on_tile(tile: Vector2) -> bool:
	for enemy in enemies:
		# A crab that hasn't entered the tree yet has no tile
		if enemy.is_inside_tree() and enemy.tile == tile:
			return true
	return false

# A crab started hopping onto a tile
func _on_enemy_tile_entered(_enemy: Node, tile: Vector2):
	if isGameover or moving or tile != player_tile:
		return
	# The crab walked onto the standing player: give them a short time to escape
	if crab_grace_timer.is_stopped():
		crab_grace_timer.start()

func _on_crab_grace_timeout():
	if not moving and is_enemy_on_tile(player_tile):
		game_over()

func _process(_delta):
	if isGameover:
		return
	var steps = process_inputs()
	if steps.size() > 0:
		start_moving_player_along_path(steps)

func process_inputs() -> Array:
	var steps = []
	
	# We cache the inputs while moving so we only process 
	# them when the player has stopped on a tile
	if Input.is_action_just_pressed('Jump') or cached_inputs.jump:
		if moving:
			cached_inputs.jump = true
			return steps
		acknowledge_step(1)
		steps.append(tiles_gen.pop())
	
	elif Input.is_action_just_pressed('Dash') or cached_inputs.dash:
		if moving:
			cached_inputs.dash = true
			return steps
		acknowledge_step(2)
		steps.append(tiles_gen.pop())
		steps.append(tiles_gen.pop())
		
	elif Input.is_action_just_pressed("respawn"):
		respawn()
	
	cached_inputs.dash = false
	cached_inputs.jump = false

	return steps

func start_moving_player_along_path(steps):
	# The player is in the air from now until landing: crabs can't hit them
	moving = true
	crab_grace_timer.stop()

	var curve = path.curve
	curve.clear_points()
	curve.add_point(player.position)
	for point in steps:
		curve.add_point(Math.to_iso(point))
	
	# Bound to this node so the tween is freed with the scene on respawn
	var tween = create_tween()
	tween.tween_method(_on_moving_along_path, 0.0, 1.0, global.STEP_DURATION) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN_OUT)

	# Tweeners run in sequence: the callback fires as soon as the move ends
	tween.tween_callback(_on_moving_along_path_finished.bind(steps.back()))
	
	set_player_look_at(steps.back())
	player.jump()

func get_next_position_on_path(t: float) -> Vector2:
	var point_count = path.curve.get_point_count()
	var point_index = min((point_count * t) + 1, point_count - 1)
	return path.curve.get_point_position(point_index)

func _on_moving_along_path(value):
	player.player_look_at(get_next_position_on_path(value))
	path_follow.progress_ratio = value

func check_player_position_on_map(position):
	var coords = tileMap.get_cell_atlas_coords(0, position)
	var tile = self.atlas_coords_to_tile_type(coords)
	if tile == tiles_gen.TileType.Empty or tile == tiles_gen.TileType.Hole:
		game_over()

func _on_moving_along_path_finished(destination):
	moving = false
	player_tile = destination
	set_player_look_at(tiles_gen.front())
	check_player_position_on_map(destination)
	# Landing on a crab (or on a tile a crab is hopping onto) is game over
	if is_enemy_on_tile(destination):
		game_over()

func acknowledge_step(step_count):
	global.score += step_count
	emit_signal("player_step", step_count)

	if global.score % 20 == 0:
		global.level += 1
		emit_signal('level_up')

	if global.high < global.score:
		# New high score
		global.high = global.score

func respawn():
	# The Curve2D is a sub-resource of Game.tscn and is shared with the
	# reloaded scene, so clear it to avoid carrying old points over
	path.curve.clear_points()
	var _err := get_tree().reload_current_scene()

func game_over():
	if isGameover or isInvicible:
		return
	isGameover = true
	# Freeze the crabs so the player can see what happened
	for enemy in enemies:
		if enemy.is_inside_tree():
			enemy.freeze()
	emit_signal("gameover")
	# delay the scene respawn for 1 second
	await get_tree().create_timer(1.0).timeout
	respawn()

func _on_HUD_gameplay_timeout():
	game_over()
