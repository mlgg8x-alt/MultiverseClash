extends RefCounted
## Breadth-first grid pathfinding over passable tiles.

const LocalMap = preload("res://world/local_map.gd")


## Returns the steps from `start` (exclusive) to `goal` (inclusive). Empty when start == goal
## or when the goal is unreachable; callers distinguish the two by comparing positions.
static func find_path(map: LocalMap, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if start == goal or not map.is_passable(goal) or not map.is_passable(start):
		return path
	if map.region_of(start) != map.region_of(goal):
		return path
	var w := map.width
	var came := PackedInt32Array()
	came.resize(w * map.height)
	came.fill(-1)
	var start_i := start.y * w + start.x
	var goal_i := goal.y * w + goal.x
	came[start_i] = start_i
	var queue := PackedInt32Array([start_i])
	var head := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		if cur == goal_i:
			break
		var cp := Vector2i(cur % w, cur / w)
		for d in LocalMap.DIRS:
			var np := cp + d
			if map.is_passable(np):
				var ni := np.y * w + np.x
				if came[ni] == -1:
					came[ni] = cur
					queue.append(ni)
	if came[goal_i] == -1:
		return path
	var i := goal_i
	while i != start_i:
		path.append(Vector2i(i % w, i / w))
		i = came[i]
	path.reverse()
	return path
