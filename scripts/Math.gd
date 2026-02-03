# Math.gd

# Isometric cell size in pixels
const CELL_SIZE = 32

# Convert from Cartesian to Isometric space 
static func to_iso(point: Vector2):
	return Vector2(point.x - point.y, (point.x + point.y) / 2) * CELL_SIZE

# Convert from Isometric to Cartesian space 
static func to_cart(point: Vector2):
	return Vector2(point.x / 2 + point.y, point.y - point.x / 2)

# Return the Isometric cell center from Cartesian space
static func to_iso_center(point: Vector2):
	return  to_iso(point) + Vector2(0, CELL_SIZE / 2.0)
