# TilesGenerator.gd
extends Node

signal new_tile
signal spawn_enemy

enum TileType { Empty = -1, Ground = 0 }
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

func spawn_new_enemy(position):
	if roll_dice(0.9):
		emit_signal("spawn_enemy", position)

func generate_next_tile_type(_pos, prevType):
	if prevType != TileType.Empty and roll_dice(0.6):
		return TileType.Empty
	else:
		return TileType.Ground

func start_generating_tiles():
	var position = Vector2(0, 0)
	var left = Vector2(1, 0)
	var right = Vector2(0, 1)
	var tileType = TileType.Ground
	var progress = 0
	
	while true:
		# Sleep until we need to create a new tile
		if pool.size() > MAX_POOL_SIZE:
			await global.get_game().player_step
		
		push(position)
		add_new_tile_to_map(position, tileType)
		spawn_new_enemy(position)

		tileType = generate_next_tile_type(position, tileType)
		position = position + choose(0.5, left, right)
		progress += 1
