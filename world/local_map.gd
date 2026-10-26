extends RefCounted
## Tile grid for a local map. Terrain is static during play; connectivity regions are derived.

enum Terrain { WATER, GRASS, FOREST, FERTILE, ORE, STONE }

const TERRAIN_IDS := {
	"water": Terrain.WATER, "grass": Terrain.GRASS, "forest": Terrain.FOREST,
	"fertile": Terrain.FERTILE, "ore": Terrain.ORE, "stone": Terrain.STONE,
}
const TERRAIN_COLORS := {
	Terrain.WATER: Color("#2f5d8a"), Terrain.GRASS: Color("#6f9a4a"),
	Terrain.FOREST: Color("#2f5e2a"), Terrain.FERTILE: Color("#9aa24a"),
	Terrain.ORE: Color("#8a5a4a"), Terrain.STONE: Color("#8c8c84"),
}
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var width: int
var height: int
var tiles := PackedByteArray()
var regions := PackedInt32Array()   # connected land component id per tile, -1 for water


func _init(w: int = 0, h: int = 0) -> void:
	width = w
	height = h
	tiles.resize(w * h)
	tiles.fill(Terrain.GRASS)


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height


func get_tile(p: Vector2i) -> int:
	return tiles[p.y * width + p.x]


func set_tile(p: Vector2i, t: int) -> void:
	tiles[p.y * width + p.x] = t


func is_passable(p: Vector2i) -> bool:
	return in_bounds(p) and get_tile(p) != Terrain.WATER


func region_of(p: Vector2i) -> int:
	return regions[p.y * width + p.x]


func count_in_radius(center: Vector2i, terrain: int, radius: int) -> int:
	var n := 0
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var p := Vector2i(x, y)
			if in_bounds(p) and get_tile(p) == terrain:
				n += 1
	return n


func compute_regions() -> void:
	regions.resize(width * height)
	regions.fill(-1)
	var next_region := 0
	for i in width * height:
		if tiles[i] == Terrain.WATER or regions[i] != -1:
			continue
		var queue := PackedInt32Array([i])
		regions[i] = next_region
		var head := 0
		while head < queue.size():
			var cur := queue[head]
			head += 1
			var cp := Vector2i(cur % width, cur / width)
			for d in DIRS:
				var np := cp + d
				if is_passable(np):
					var ni := np.y * width + np.x
					if regions[ni] == -1:
						regions[ni] = next_region
						queue.append(ni)
		next_region += 1


func to_dict() -> Dictionary:
	return {"width": width, "height": height, "tiles": Marshalls.raw_to_base64(tiles)}


static func from_dict(d: Dictionary):
	var m = load("res://world/local_map.gd").new(int(d["width"]), int(d["height"]))
	m.tiles = Marshalls.base64_to_raw(d["tiles"])
	m.compute_regions()
	return m
