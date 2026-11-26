extends Node2D

const Math = preload('res://scripts/Math.gd')
const Enemy = preload("res://scenes/Enemy.tscn")
const TilesGenerator = preload("res://scripts/TilesGenerator.gd")

signal gameover
signal player_step
signal level_up(level: int)

var tiles_gen = TilesGenerator.new()

@onready var player = $Player
@onready var path = $Path2D
@onready var path_follow = $Path2D/PathFollow2D
@onready var tileMap = $GroundTileMap
@onready var hud = $HUD

var isStarted = false		# False until the first Jump or Dash: nothing moves before that
var isGameover = false
var canRetry = false		# True once the game over panel is shown
var isInvicible = false

var moving = false		# True while the player is in the air (from takeoff to landing)
var cached_inputs = {
	jump = false,
	dash = false
}

# Crab tuning
@export var crab_patrol_range := 2		# Tiles a crab can walk on each side of its spawn tile
@export var crab_grace_time := 0.1		# Time to escape when a crab steps onto the player's tile

# Timer: the game is over when it runs out. Each safe landing gives some time back
@export_group("Timer")
@export var max_time := 5.0				# Full timer bar, in seconds
@export var start_time := 3.0			# Timer at the start of a run
@export var time_bonus_easy := 0.5		# Time given back per landing at difficulty 0
@export var time_bonus_hard := 0.4		# Time given back per landing at difficulty 1
@export var time_drain_easy := 1.0		# Timer speed at difficulty 0 (1 = real time)
@export var time_drain_hard := 1.1		# Timer speed at difficulty 1
@export var level_up_time_bonus := 1.0	# Time given back on level up

# Levels: the difficulty goes from 0 (level 1) to 1 (max_difficulty_level)
@export_group("Levels")
@export var tiles_per_level := 20
@export var max_difficulty_level := 10
@export var gap_chance_easy := 0.4		# Chance of a hole/empty tile after a ground tile
@export var gap_chance_hard := 0.55
@export var crab_chance_easy := 0.1		# Chance of a crab on each tile allowed by the spawn rules
@export var crab_chance_hard := 0.35
@export var crab_step_interval_easy := 0.6	# Time between two crab hops
@export var crab_step_interval_hard := 0.4

var time_left := 0.0
var level := 1
var difficulty := 0.0

var player_tile := Vector2.ZERO			# Tile the player stands on (grid coords)
var enemies = []
var crab_grace_timer: Timer

func _enter_tree():
	randomize()
	initialize_level_parameters()

func _ready():
	initialize_crab_grace_timer()
	initialize_tiles_generator()
	update_difficulty()
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
	global.score = 0
	level = 1
	time_left = start_time

func start_game():
	isGameover = false
	tiles_gen.start_generating_tiles()
	tiles_gen.pop() # skip the start position cell
	get_tree().paused = false
	set_player_look_at(tiles_gen.front())

# Called on the first Jump or Dash: start the timer and the crabs
func begin_play():
	isStarted = true
	for enemy in enemies:
		enemy.autostart = true
		if enemy.is_inside_tree():
			enemy.start_patrol()

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
	enemy.step_interval = lerp(crab_step_interval_easy, crab_step_interval_hard, difficulty)
	enemy.autostart = isStarted
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

func _process(delta):
	if isGameover:
		# Keyboard retry (touch/mouse uses the game over panel)
		if canRetry and (Input.is_action_just_pressed('Jump') or Input.is_action_just_pressed('Dash')):
			retry()
		return

	if isStarted:
		update_timer(delta)
		if isGameover:
			return

	var steps = process_inputs()
	if steps.size() > 0:
		if not isStarted:
			begin_play()
		start_moving_player_along_path(steps)

func update_timer(delta):
	var drain = lerp(time_drain_easy, time_drain_hard, difficulty)
	time_left = max(time_left - delta * drain, 0.0)
	if time_left <= 0.0:
		game_over()

func add_time(time):
	time_left = min(time_left + time, max_time)

func process_inputs() -> Array:
	var steps = []

	# We cache the inputs while moving so we only process
	# them when the player has stopped on a tile
	if Input.is_action_just_pressed('Jump') or cached_inputs.jump:
		if moving:
			cached_inputs.jump = true
			return steps
		steps.append(tiles_gen.pop())

	elif Input.is_action_just_pressed('Dash') or cached_inputs.dash:
		if moving:
			cached_inputs.dash = true
			return steps
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
	tween.tween_callback(_on_moving_along_path_finished.bind(steps.back(), steps.size()))

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

func _on_moving_along_path_finished(destination, step_count):
	moving = false
	player_tile = destination
	set_player_look_at(tiles_gen.front())
	check_player_position_on_map(destination)
	# Landing on a crab (or on a tile a crab is hopping onto) is game over
	if is_enemy_on_tile(destination):
		game_over()
	# Only a safe landing scores
	if not isGameover:
		acknowledge_step(step_count)

func acknowledge_step(step_count):
	global.score += step_count
	add_time(lerp(time_bonus_easy, time_bonus_hard, difficulty))
	emit_signal("player_step", step_count)
	check_level_up()

	if global.high < global.score:
		# New high score
		global.high = global.score

# Level N + 1 starts once the score reaches N * tiles_per_level.
# Comparing with >= (instead of score % 20 == 0) means a dash (+2) can't skip a level
func check_level_up():
	while global.score >= level * tiles_per_level:
		level += 1
		update_difficulty()
		add_time(level_up_time_bonus)
		level_up.emit(level)

# Difficulty goes from 0 at level 1 to 1 at max_difficulty_level
func update_difficulty():
	difficulty = clamp(float(level - 1) / (max_difficulty_level - 1), 0.0, 1.0)
	# Only affects the tiles generated from now on (about 20 tiles ahead)
	tiles_gen.gap_chance = lerp(gap_chance_easy, gap_chance_hard, difficulty)
	tiles_gen.enemy_chance = lerp(crab_chance_easy, crab_chance_hard, difficulty)

func retry():
	respawn()

func respawn():
	# The Curve2D is a sub-resource of Game.tscn and is shared with the
	# reloaded scene, so clear it to avoid carrying old points over
	path.curve.clear_points()
	var _err := get_tree().reload_current_scene()

func game_over():
	if isGameover or isInvicible:
		return
	isGameover = true
	crab_grace_timer.stop()
	# Freeze the crabs so the player can see what happened
	for enemy in enemies:
		if enemy.is_inside_tree():
			enemy.freeze()
	global.save_high_score()
	emit_signal("gameover")
	# Wait a moment before showing the game over panel
	await get_tree().create_timer(1.0).timeout
	canRetry = true
	hud.show_game_over(global.score, global.high)
