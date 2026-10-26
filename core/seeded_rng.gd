extends RefCounted
## Deterministic xorshift32 generator. The state always fits exactly in a JSON number,
## so saves reproduce the random stream bit-for-bit.

const MASK := 0xFFFFFFFF

var state: int = 1


func _init(seed_value: int = 1) -> void:
	set_seed(seed_value)


func set_seed(seed_value: int) -> void:
	state = ((seed_value & 0x7FFFFFFF) ^ 0x9E3779B9) & MASK
	if state == 0:
		state = 1
	for i in 8:
		next_u32()


func next_u32() -> int:
	var x := state
	x ^= (x << 13) & MASK
	x ^= x >> 17
	x ^= (x << 5) & MASK
	state = x & MASK
	return state


## Inclusive range.
func range_int(from: int, to: int) -> int:
	if to <= from:
		return from
	return from + next_u32() % (to - from + 1)


func chance_percent(percent: int) -> bool:
	return next_u32() % 100 < percent


## Stateless integer hash in [0, 1). Used by world generation noise.
static func hash_unit(x: int, y: int, seed_value: int) -> float:
	var h := (x * 374761393 + y * 668265263 + (seed_value & 0x7FFFFFFF) * 1442695041) & MASK
	h = ((h ^ (h >> 13)) * 1274126177) & MASK
	h = h ^ (h >> 16)
	return float(h) / 4294967296.0
