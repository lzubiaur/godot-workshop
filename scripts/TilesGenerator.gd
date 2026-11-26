# TilesGenerator.gd
extends Node

signal new_tile
signal spawn_enemy

enum TileType { Empty = -1, Ground = 0, Hole = 1 }
const MAX_POOL_SIZE = 20

var pool = []

func roll_dice(odds) -> bool:
	return randf_range(0, 1) > odds

func choose(odds, value1, value2):
	return value1 if roll_dice(odds) else value2

func front() -> Vector2:
	return pool.front()

func push(direction: Vector2):
	pool.append(direction)

func pop() -> Vector2:
	return pool.pop_front()

func add_new_tile_to_map(position, tileType):
	if tileType != TileType.Empty:
		emit_signal("new_tile", position, tileType)

# Chances set by the Game from the difficulty (0 to 1)
var gap_chance = 0.4		# Chance that a tile after a ground tile is a gap (hole or empty)
var enemy_chance = 0.1		# Chance of a crab on each tile that passes the spawn rules

# Crab spawn rules
const SAFE_START_TILES = 5			# No crab on the first tiles of the run
const MIN_ENEMY_SPACING = 4			# Minimum number of tiles between two crabs

var last_enemy_progress = -MIN_ENEMY_SPACING

# A crab can only spawn on a ground tile surrounded by ground tiles
# (no hole right before or after it), far enough from the start and the previous crab
func can_spawn_enemy(progress, prevType, tileType, nextType) -> bool:
	return progress >= SAFE_START_TILES \
		and progress - last_enemy_progress >= MIN_ENEMY_SPACING \
		and prevType == TileType.Ground \
		and tileType == TileType.Ground \
		and nextType == TileType.Ground

func spawn_new_enemy(position, progress, prevType, tileType, nextType):
	if can_spawn_enemy(progress, prevType, tileType, nextType) and randf() < enemy_chance:
		last_enemy_progress = progress
		emit_signal("spawn_enemy", position)

func generate_next_tile_type(_pos, prevType):
	if prevType != TileType.Hole and prevType != TileType.Empty and randf() < gap_chance:
		return choose(0.7, TileType.Hole, TileType.Empty)
	else:
		return TileType.Ground

func start_generating_tiles():
	var position = Vector2(0, 0)
	var left = Vector2(1, 0)
	var right = Vector2(0, 1)
	var prevType = TileType.Ground
	var tileType = TileType.Ground
	var progress = 0

	while true:
		# Sleep until we need to create a new tile
		if pool.size() > MAX_POOL_SIZE:
			await global.get_game().player_step

		push(position)
		add_new_tile_to_map(position, tileType)

		# Pick the next tile type first so the spawn rules can look ahead
		var nextType = generate_next_tile_type(position, tileType)
		spawn_new_enemy(position, progress, prevType, tileType, nextType)

		prevType = tileType
		tileType = nextType
		position = position + choose(0.5, left, right)
		progress += 1
