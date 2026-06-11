extends Node2D
## 100×56 开放世界地形生成器 (2D)
## v12: 三阵营领地 + 三野外缓冲区 + 中央巨龙山体 + 周围资源带 + 无尽之海
## 2.5D 渲染：_draw() + draw_rect() —— 无独立节点，性能最优

const GRID_SIZE := 56    # 陆地网格（6阶段管线使用）
const GRID_COLS := 100   # 总网格宽（陆地+左右海洋）
const GRID_ROWS := 56    # 总网格高
const LAND_OFFSET_X := 22  # 陆地左偏移，居中放置
const TILE_SIZE := 32.0  # 像素

var center := Vector2(27.5, 27.5)          # 陆地中心（管线使用）
var grid_center := Vector2((GRID_COLS - 1) * 0.5, (GRID_ROWS - 1) * 0.5)  # 全网格中心

# ========== 巨龙山体参数 ==========
const NEST_RADIUS := 1.5
const MOUNT_RADIUS := 5.3
const RESOURCE_OUTER := 9.5

# ========== 阵营种子点 ==========
const ELF_SEED   := Vector2(13, 13)
const DWARF_SEED := Vector2(13, 43)
const ORC_SEED   := Vector2(43, 43)

# 出生点十字簇（每阵营 5 格，陆地坐标，渲染时自动偏移）
const ELF_SPAWN: Array[Vector2i] = [
	Vector2i(12, 13), Vector2i(13, 12), Vector2i(13, 13), Vector2i(13, 14), Vector2i(14, 13),
]
const DWARF_SPAWN: Array[Vector2i] = [
	Vector2i(12, 43), Vector2i(13, 42), Vector2i(13, 43), Vector2i(13, 44), Vector2i(14, 43),
]
const ORC_SPAWN: Array[Vector2i] = [
	Vector2i(39, 35), Vector2i(40, 34), Vector2i(40, 35), Vector2i(40, 36), Vector2i(41, 35),
]

# ========== 区域分类阈值 ==========
const COMPETITION_THRESHOLD := 0.78
const BLEND_LOW := 0.65

# ========== 山径参数 ==========
const CORRIDOR_ANGLES: Array[float] = [
	deg_to_rad(30.0),
	deg_to_rad(150.0),
	deg_to_rad(270.0),
]

const BAY_ANGLES: Array[float] = [
	deg_to_rad(135.0), deg_to_rad(200.0), deg_to_rad(310.0), deg_to_rad(15.0),
]
const PENINSULA_ANGLES: Array[float] = [
	deg_to_rad(90.0), deg_to_rad(180.0), deg_to_rad(270.0), deg_to_rad(0.0),
]
const BAY_PENINSULA_INTENSITY := 0.7

enum ZoneTag {
	UNASSIGNED,
	MOUNTAIN_NEST,
	MOUNTAIN_BODY,
	MOUNTAIN_PATH,
	RESOURCE_RING,
	OCEAN,
	SCATTERED_IMPASSABLE,
	ELF_TERRITORY,
	DWARF_TERRITORY,
	ORC_TERRITORY,
	EMERALD_WOODLANDS,
	RIFT_HIGHLANDS,
	SCORCHED_BADLANDS,
}

var terrain_grid: Array = []
var zone_grid: Array = []


func _ready() -> void:
	print("[Grid2D] 生成 v12 开放世界地图 (100x56)...")
	_generate_terrain()
	queue_redraw()
	_print_stats()


# ============================================================
# 生成管线 —— 6 阶段分层掩码 + 扩展
# ============================================================

func _generate_terrain() -> void:
	terrain_grid = []
	zone_grid = []
	for y in range(GRID_SIZE):
		var trow: Array = []
		var zrow: Array = []
		for x in range(GRID_SIZE):
			trow.append(TerrainData.Terrain.VOID)
			zrow.append(ZoneTag.UNASSIGNED)
		terrain_grid.append(trow)
		zone_grid.append(zrow)

	_phase1_mountain()
	_phase2_resource_ring()
	_phase3_ocean()
	_phase4_territories()
	_phase5_impassable()
	_phase6_assign_terrain()

	# Step 7: 扩展至 100x56，居中放置，左右填海洋
	var expanded_terrain: Array = []
	var expanded_zone: Array = []
	for y in range(GRID_ROWS):
		var trow: Array = []
		var zrow: Array = []
		for x in range(GRID_COLS):
			trow.append(TerrainData.Terrain.WATER)
			zrow.append(ZoneTag.OCEAN)
		expanded_terrain.append(trow)
		expanded_zone.append(zrow)

	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			expanded_terrain[y][x + LAND_OFFSET_X] = terrain_grid[y][x]
			expanded_zone[y][x + LAND_OFFSET_X] = zone_grid[y][x]

	terrain_grid = expanded_terrain
	zone_grid = expanded_zone


# ============================================================
# Phase 1: 巨龙山体
# ============================================================

func _phase1_mountain() -> void:
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var pos := Vector2(x, y)
			var dist := pos.distance_to(center)

			if dist <= NEST_RADIUS:
				terrain_grid[y][x] = TerrainData.Terrain.DRAGON_NEST
				zone_grid[y][x] = ZoneTag.MOUNTAIN_NEST
			elif dist <= MOUNT_RADIUS:
				if _is_corridor_path(pos, dist):
					terrain_grid[y][x] = TerrainData.Terrain.CORRIDOR
					zone_grid[y][x] = ZoneTag.MOUNTAIN_PATH
				elif _simple_hash(x, y, 100) < 0.06:
					terrain_grid[y][x] = TerrainData.Terrain.RUINS
					zone_grid[y][x] = ZoneTag.MOUNTAIN_BODY
				else:
					terrain_grid[y][x] = TerrainData.Terrain.DRAGON_MOUNT
					zone_grid[y][x] = ZoneTag.MOUNTAIN_BODY


func _is_corridor_path(pos: Vector2, dist: float) -> bool:
	var angle := atan2(pos.y - center.y, pos.x - center.x)
	var t := (dist - NEST_RADIUS) / maxf(MOUNT_RADIUS - NEST_RADIUS, 0.01)
	var half_width := deg_to_rad(lerpf(10.0, 2.5, t))
	for ca in CORRIDOR_ANGLES:
		if _angle_diff(angle, ca) <= half_width:
			return true
	return false


# ============================================================
# Phase 2: 巨龙山周围资源带
# ============================================================

func _phase2_resource_ring() -> void:
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			if terrain_grid[y][x] != TerrainData.Terrain.VOID:
				continue
			var pos := Vector2(x, y)
			var dist := pos.distance_to(center)
			if dist >= MOUNT_RADIUS and dist < RESOURCE_OUTER:
				zone_grid[y][x] = ZoneTag.RESOURCE_RING


# ============================================================
# Phase 3: 无尽之海边界
# ============================================================

func _phase3_ocean() -> void:
	const BASE_THRESHOLD := 5.0
	const NE_BOOST := 3.5
	const NOISE_AMPLITUDE := 2.0
	const SHELF_BAND := 2.0
	const CORNER_ROUNDING := 4.0
	const ROUNDING_POWER := 1.5
	const ROUNDING_NOISE := 0.3

	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			if terrain_grid[y][x] != TerrainData.Terrain.VOID:
				continue
			if zone_grid[y][x] != ZoneTag.UNASSIGNED:
				continue

			var edge := float(min(min(x, y), min(GRID_SIZE - 1 - x, GRID_SIZE - 1 - y)))
			var angle := atan2(y - center.y, x - center.x)

			# 椭圆化：沿对角方向加深切割，使陆地近似椭圆
			var diagonal_factor := pow(abs(sin(angle * 2.0)), ROUNDING_POWER)
			var rounding_noise := _simple_hash(x, y, 999) * ROUNDING_NOISE * diagonal_factor
			edge -= (diagonal_factor + rounding_noise) * CORNER_ROUNDING

			# NE bulge
			var ne_factor := _angular_proximity(angle, deg_to_rad(45.0), deg_to_rad(40.0))

			# Multi-octave continental noise
			var continental_noise := _continental_noise(float(x), float(y), 10) * NOISE_AMPLITUDE

			# Angular bay/peninsula features
			var angular_feature := 0.0
			for ba in BAY_ANGLES:
				angular_feature -= _angular_proximity(angle, ba, deg_to_rad(25.0)) * BAY_PENINSULA_INTENSITY
			for pa in PENINSULA_ANGLES:
				angular_feature += _angular_proximity(angle, pa, deg_to_rad(25.0)) * BAY_PENINSULA_INTENSITY

			# Organic noise as detail
			var organic_detail := _organic_noise(x, y) * 0.3

			var threshold := BASE_THRESHOLD + ne_factor * NE_BOOST + continental_noise + angular_feature + organic_detail

			# Continental shelf: fuzzy transition
			var shelf_dist := edge - threshold
			if shelf_dist < -SHELF_BAND:
				terrain_grid[y][x] = TerrainData.Terrain.WATER
				zone_grid[y][x] = ZoneTag.OCEAN
			elif shelf_dist < 0.0:
				var shelf_factor := (shelf_dist + SHELF_BAND) / SHELF_BAND
				if _simple_hash(x, y, 20) > shelf_factor * 0.6 + 0.1:
					terrain_grid[y][x] = TerrainData.Terrain.WATER
					zone_grid[y][x] = ZoneTag.OCEAN


# ============================================================
# Phase 4: 阵营领地 + 缓冲区（Voronoi + competition ratio）
# ============================================================

func _phase4_territories() -> void:
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			if terrain_grid[y][x] != TerrainData.Terrain.VOID:
				continue
			if zone_grid[y][x] == ZoneTag.RESOURCE_RING:
				continue

			var pos := Vector2(x, y)
			var d_elf := pos.distance_to(ELF_SEED)
			var d_dwarf := pos.distance_to(DWARF_SEED)
			var d_orc := pos.distance_to(ORC_SEED)

			var d1: float
			var f1: int
			var d2: float
			var f2: int

			if d_elf <= d_dwarf and d_elf <= d_orc:
				d1 = d_elf; f1 = 0
				if d_dwarf <= d_orc: d2 = d_dwarf; f2 = 1
				else: d2 = d_orc; f2 = 2
			elif d_dwarf <= d_elf and d_dwarf <= d_orc:
				d1 = d_dwarf; f1 = 1
				if d_elf <= d_orc: d2 = d_elf; f2 = 0
				else: d2 = d_orc; f2 = 2
			else:
				d1 = d_orc; f1 = 2
				if d_elf <= d_dwarf: d2 = d_elf; f2 = 0
				else: d2 = d_dwarf; f2 = 1

			var ratio := d1 / maxf(d2, 0.001)

			if ratio > COMPETITION_THRESHOLD:
				zone_grid[y][x] = _buffer_tag(f1, f2)
			else:
				match f1:
					0: zone_grid[y][x] = ZoneTag.ELF_TERRITORY
					1: zone_grid[y][x] = ZoneTag.DWARF_TERRITORY
					2: zone_grid[y][x] = ZoneTag.ORC_TERRITORY


func _buffer_tag(f1: int, f2: int) -> int:
	var a := mini(f1, f2)
	var b := maxi(f1, f2)
	if a == 0 and b == 1: return ZoneTag.EMERALD_WOODLANDS
	if a == 0 and b == 2: return ZoneTag.RIFT_HIGHLANDS
	return ZoneTag.SCORCHED_BADLANDS


# ============================================================
# Phase 5: 散落不可到达区（~120格）
# ============================================================

func _phase5_impassable() -> void:
	var placed := 0
	var target := 120

	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			if placed >= target: return
			var zt: int = zone_grid[y][x]
			if zt != ZoneTag.EMERALD_WOODLANDS and zt != ZoneTag.RIFT_HIGHLANDS and zt != ZoneTag.SCORCHED_BADLANDS:
				continue
			if terrain_grid[y][x] != TerrainData.Terrain.VOID:
				continue
			if _simple_hash(x, y, 500) < 0.12:
				terrain_grid[y][x] = TerrainData.Terrain.DRAGON_MOUNT if _simple_hash(x, y, 501) < 0.5 else TerrainData.Terrain.VOID
				zone_grid[y][x] = ZoneTag.SCATTERED_IMPASSABLE
				placed += 1

	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			if placed >= target: return
			var zt: int = zone_grid[y][x]
			if zt != ZoneTag.ELF_TERRITORY and zt != ZoneTag.DWARF_TERRITORY and zt != ZoneTag.ORC_TERRITORY and zt != ZoneTag.RESOURCE_RING:
				continue
			if terrain_grid[y][x] != TerrainData.Terrain.VOID:
				continue
			var pos := Vector2(x, y)
			var min_d := minf(minf(pos.distance_to(ELF_SEED), pos.distance_to(DWARF_SEED)), pos.distance_to(ORC_SEED))
			if min_d > 13.0 and _simple_hash(x, y, 502) < 0.10:
				terrain_grid[y][x] = TerrainData.Terrain.VOID
				zone_grid[y][x] = ZoneTag.SCATTERED_IMPASSABLE
				placed += 1

	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			if placed >= target: return
			if zone_grid[y][x] == ZoneTag.UNASSIGNED and terrain_grid[y][x] == TerrainData.Terrain.VOID:
				terrain_grid[y][x] = TerrainData.Terrain.VOID
				zone_grid[y][x] = ZoneTag.SCATTERED_IMPASSABLE
				placed += 1


# ============================================================
# Phase 6: 最终地形赋值
# ============================================================

func _phase6_assign_terrain() -> void:
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var zt: int = zone_grid[y][x]
			if terrain_grid[y][x] != TerrainData.Terrain.VOID:
				continue

			var pos := Vector2(x, y)
			var d_elf := pos.distance_to(ELF_SEED)
			var d_dwarf := pos.distance_to(DWARF_SEED)
			var d_orc := pos.distance_to(ORC_SEED)

			var d1: float
			var f1: int
			var d2: float
			var f2: int
			if d_elf <= d_dwarf and d_elf <= d_orc:
				d1 = d_elf; f1 = 0
				if d_dwarf <= d_orc: d2 = d_dwarf; f2 = 1
				else: d2 = d_orc; f2 = 2
			elif d_dwarf <= d_elf and d_dwarf <= d_orc:
				d1 = d_dwarf; f1 = 1
				if d_elf <= d_orc: d2 = d_elf; f2 = 0
				else: d2 = d_orc; f2 = 2
			else:
				d1 = d_orc; f1 = 2
				if d_elf <= d_dwarf: d2 = d_elf; f2 = 0
				else: d2 = d_dwarf; f2 = 1

			var ratio := d1 / maxf(d2, 0.001)
			var blend: float = 0.0
			var sec_faction := f2
			if ratio > BLEND_LOW and ratio <= COMPETITION_THRESHOLD:
				blend = (ratio - BLEND_LOW) / (COMPETITION_THRESHOLD - BLEND_LOW)

			match zt:
				ZoneTag.RESOURCE_RING:
					terrain_grid[y][x] = _resource_ring_terrain(x, y)
				ZoneTag.ELF_TERRITORY:
					terrain_grid[y][x] = _faction_terrain(1, x, y, 300, blend, sec_faction)
				ZoneTag.DWARF_TERRITORY:
					terrain_grid[y][x] = _faction_terrain(0, x, y, 310, blend, sec_faction)
				ZoneTag.ORC_TERRITORY:
					terrain_grid[y][x] = _faction_terrain(2, x, y, 320, blend, sec_faction)
				ZoneTag.EMERALD_WOODLANDS:
					terrain_grid[y][x] = _emerald_terrain(x, y)
				ZoneTag.RIFT_HIGHLANDS:
					terrain_grid[y][x] = _rift_terrain(x, y)
				ZoneTag.SCORCHED_BADLANDS:
					terrain_grid[y][x] = _scorched_terrain(x, y)
				_:
					terrain_grid[y][x] = _faction_terrain_raw(f1, x, y, 900 + f1 * 10)


func _resource_ring_terrain(x: int, y: int) -> int:
	var angle := atan2(y - center.y, x - center.x)
	var a := _normalize_angle(angle)
	var h := _simple_hash(x, y, 200)

	if a >= deg_to_rad(60.0) and a < deg_to_rad(180.0):
		if h < 0.40: return TerrainData.Terrain.FOREST_ELF
		if h < 0.60: return TerrainData.Terrain.GLADE_ELF
		if h < 0.85: return TerrainData.Terrain.RUINS
		return TerrainData.Terrain.CORRIDOR
	elif a >= deg_to_rad(180.0) and a < deg_to_rad(300.0):
		if h < 0.35: return TerrainData.Terrain.PLAIN_DWARF
		if h < 0.60: return TerrainData.Terrain.MOUNTAIN_DWARF
		if h < 0.85: return TerrainData.Terrain.RUINS
		return TerrainData.Terrain.CORRIDOR
	else:
		if h < 0.35: return TerrainData.Terrain.WASTELAND_ORC
		if h < 0.55: return TerrainData.Terrain.SWAMP_ORC
		if h < 0.80: return TerrainData.Terrain.RUINS
		return TerrainData.Terrain.CORRIDOR


func _faction_terrain(faction: int, x: int, y: int, seed: int, blend: float, sec_faction: int) -> int:
	if blend > 0.0 and _simple_hash(x, y, 700) < blend:
		return _faction_terrain_raw(sec_faction, x, y, seed + 100)
	return _faction_terrain_raw(faction, x, y, seed)


func _faction_terrain_raw(faction: int, x: int, y: int, seed: int) -> int:
	var h := _simple_hash(x, y, seed)
	match faction:
		0: return TerrainData.Terrain.MOUNTAIN_DWARF if h < 0.25 else TerrainData.Terrain.PLAIN_DWARF
		1: return TerrainData.Terrain.GLADE_ELF if h < 0.15 else TerrainData.Terrain.FOREST_ELF
		2: return TerrainData.Terrain.SWAMP_ORC if h < 0.20 else TerrainData.Terrain.WASTELAND_ORC
	return TerrainData.Terrain.VOID


func _emerald_terrain(x: int, y: int) -> int:
	var h := _simple_hash(x, y, 400)
	if h < 0.30: return TerrainData.Terrain.FOREST_ELF
	if h < 0.50: return TerrainData.Terrain.GLADE_ELF
	if h < 0.75: return TerrainData.Terrain.PLAIN_DWARF
	if h < 0.90: return TerrainData.Terrain.MOUNTAIN_DWARF
	return TerrainData.Terrain.WATER


func _rift_terrain(x: int, y: int) -> int:
	var h := _simple_hash(x, y, 410)
	if h < 0.40: return TerrainData.Terrain.MOUNTAIN_DWARF
	if h < 0.65: return TerrainData.Terrain.PLAIN_DWARF
	if h < 0.90: return TerrainData.Terrain.RUINS
	return TerrainData.Terrain.DRAGON_MOUNT


func _scorched_terrain(x: int, y: int) -> int:
	var h := _simple_hash(x, y, 420)
	if h < 0.30: return TerrainData.Terrain.SWAMP_ORC
	if h < 0.55: return TerrainData.Terrain.MOUNTAIN_DWARF
	if h < 0.80: return TerrainData.Terrain.PLAIN_DWARF
	if h < 0.90: return TerrainData.Terrain.WASTELAND_ORC
	return TerrainData.Terrain.RUINS


# ============================================================
# 噪声/哈希
# ============================================================

func _simple_hash(x: int, y: int, seed: int = 12345) -> float:
	var val := (x * 374761393 + y * 668265263 + seed) & 0x7FFFFFFF
	val = ((val ^ (val >> 13)) * 1274126177) & 0x7FFFFFFF
	return float(val % 1000) / 1000.0


func _organic_noise(x: int, y: int) -> float:
	return (
		sin(float(x) * 0.7 + 1.3) * cos(float(y) * 0.5 + 2.1) +
		sin(float(x) * 0.3 - 0.7) * cos(float(y) * 0.9 + 0.4)
	) * 0.5


func _angle_diff(a: float, b: float) -> float:
	var d := fmod(abs(a - b), TAU)
	if d > PI: d = TAU - d
	return d


func _normalize_angle(a: float) -> float:
	var n := fmod(a, TAU)
	if n < 0.0: n += TAU
	return n


func _angular_proximity(angle: float, target: float, half_width: float) -> float:
	var diff := _angle_diff(angle, target)
	var t := diff / maxf(half_width, 0.001)
	return maxf(0.0, 1.0 - t * t)


func _continental_noise(fx: float, fy: float, base_seed: int = 1) -> float:
	const OCTAVES := 4
	const PERSISTENCE := 0.55
	const LACUNARITY := 2.3
	var amplitude := 1.0
	var frequency := 1.0
	var total := 0.0
	var max_val := 0.0
	for i in range(OCTAVES):
		var sx := int(round(fx * frequency))
		var sy := int(round(fy * frequency))
		var h := _simple_hash(sx, sy, base_seed + i * 7) * 2.0 - 1.0
		total += h * amplitude
		max_val += amplitude
		amplitude *= PERSISTENCE
		frequency *= LACUNARITY
	return total / max_val


# ============================================================
# 2D 渲染 —— _draw() 直接绘制 ColorRect
# ============================================================

func _draw() -> void:
	if terrain_grid.is_empty():
		return

	var ts := TILE_SIZE - 2.0
	var half := ts / 2.0

	for y in range(GRID_ROWS):
		for x in range(GRID_COLS):
			var t: int = terrain_grid[y][x]
			if t == TerrainData.Terrain.VOID:
				continue

			var color := TerrainData.get_color(t as TerrainData.Terrain)

			# 水域深度渐变（基于距海洋边缘距离）
			if t == TerrainData.Terrain.WATER:
				var edge_dist := float(min(min(x, y), min(GRID_COLS - 1 - x, GRID_ROWS - 1 - y)))
				var depth_factor := clampf(1.0 - edge_dist / 12.0, 0.0, 1.0)
				var deep_blue := Color(0.04, 0.15, 0.35, 1.0)
				color = color.lerp(deep_blue, depth_factor * 0.7)
			var world_pos := grid_to_world(x, y)
			var rect := Rect2(world_pos.x - half, world_pos.y - half, ts, ts)
			draw_rect(rect, color)

			# 巨龙巢穴发光效果
			if t == TerrainData.Terrain.DRAGON_NEST:
				var glow := Rect2(world_pos.x - ts * 0.6, world_pos.y - ts * 0.6, ts * 1.2, ts * 1.2)
				draw_rect(glow, Color(1.0, 0.2, 0.05, 0.35), false, 2.0)

	# 出生点红色标记
	_draw_spawn_markers()


func _draw_spawn_markers() -> void:
	const SPAWN_RADIUS := 6.0
	const SPAWN_COLOR := Color(1.0, 0.15, 0.15, 0.9)

	for cell in ELF_SPAWN:
		var pos := grid_to_world(cell.x + LAND_OFFSET_X, cell.y)
		draw_circle(pos, SPAWN_RADIUS, SPAWN_COLOR)

	for cell in DWARF_SPAWN:
		var pos := grid_to_world(cell.x + LAND_OFFSET_X, cell.y)
		draw_circle(pos, SPAWN_RADIUS, SPAWN_COLOR)

	for cell in ORC_SPAWN:
		var pos := grid_to_world(cell.x + LAND_OFFSET_X, cell.y)
		draw_circle(pos, SPAWN_RADIUS, SPAWN_COLOR)


# ============================================================
# 统计输出
# ============================================================

func _print_stats() -> void:
	var counts: Dictionary = {}
	var zone_counts: Dictionary = {}
	for y in range(GRID_ROWS):
		for x in range(GRID_COLS):
			var t: int = terrain_grid[y][x]
			counts[t] = counts.get(t, 0) + 1
			var z: int = zone_grid[y][x]
			zone_counts[z] = zone_counts.get(z, 0) + 1

	print("\n========== v12 开放世界地形统计 (100x56) ==========")
	for t: int in counts:
		var name: String = TerrainData.get_terrain_name(t as TerrainData.Terrain)
		print("  %s: %d 格" % [name, counts[t]])

	print("\n  --- 区域分布 ---")
	var zone_names: Dictionary = {
		ZoneTag.MOUNTAIN_NEST: "龙神峰",
		ZoneTag.MOUNTAIN_BODY: "高山绝壁",
		ZoneTag.MOUNTAIN_PATH: "蜿蜒山径",
		ZoneTag.RESOURCE_RING: "巨龙山周围资源带",
		ZoneTag.OCEAN: "无尽之海",
		ZoneTag.ELF_TERRITORY: "精灵领地",
		ZoneTag.DWARF_TERRITORY: "矮人领地",
		ZoneTag.ORC_TERRITORY: "兽人领地",
		ZoneTag.EMERALD_WOODLANDS: "翡翠林地(缓冲区)",
		ZoneTag.RIFT_HIGHLANDS: "裂谷高原(缓冲区)",
		ZoneTag.SCORCHED_BADLANDS: "灼热荒原(缓冲区)",
		ZoneTag.SCATTERED_IMPASSABLE: "散落不可到达区",
	}

	var mountain_total := 0
	var buffer_total := 0
	var territory_total := 0
	for z: int in zone_counts:
		var zname: String = zone_names.get(z, "未知(%d)" % z)
		var zcount: int = zone_counts[z]
		print("  %s: %d 格" % [zname, zcount])
		if z == ZoneTag.MOUNTAIN_NEST or z == ZoneTag.MOUNTAIN_BODY or z == ZoneTag.MOUNTAIN_PATH:
			mountain_total += zcount
		if z == ZoneTag.EMERALD_WOODLANDS or z == ZoneTag.RIFT_HIGHLANDS or z == ZoneTag.SCORCHED_BADLANDS:
			buffer_total += zcount
		if z == ZoneTag.ELF_TERRITORY or z == ZoneTag.DWARF_TERRITORY or z == ZoneTag.ORC_TERRITORY:
			territory_total += zcount

	var dwarf_total: int = int(counts.get(TerrainData.Terrain.PLAIN_DWARF, 0)) + int(counts.get(TerrainData.Terrain.MOUNTAIN_DWARF, 0))
	var elf_total: int = int(counts.get(TerrainData.Terrain.FOREST_ELF, 0)) + int(counts.get(TerrainData.Terrain.GLADE_ELF, 0))
	var orc_total: int = int(counts.get(TerrainData.Terrain.WASTELAND_ORC, 0)) + int(counts.get(TerrainData.Terrain.SWAMP_ORC, 0))
	var water_total: int = counts.get(TerrainData.Terrain.WATER, 0)
	var void_total: int = counts.get(TerrainData.Terrain.VOID, 0)
	var impassable_total: int = zone_counts.get(ZoneTag.SCATTERED_IMPASSABLE, 0)

	print("\n  --- 汇总 ---")
	print("  阵营地形: 矮人 %d | 精灵 %d | 兽人 %d" % [dwarf_total, elf_total, orc_total])
	print("  山体合计: %d 格" % mountain_total)
	print("  资源带: %d 格" % zone_counts.get(ZoneTag.RESOURCE_RING, 0))
	print("  阵营领地合计: %d 格" % territory_total)
	print("  缓冲区合计: %d 格" % buffer_total)
	print("  陆地海洋: %d 格" % water_total)
	print("  不可到达(VOID+散落): %d 格" % (void_total + impassable_total))
	var total_rendered := GRID_COLS * GRID_ROWS - void_total
	print("  渲染格数: %d / %d" % [total_rendered, GRID_COLS * GRID_ROWS])
	print("============================================\n")


# ============================================================
# 公共接口 (2D 版本)
# ============================================================

func get_terrain_at(x: int, y: int) -> int:
	if x < 0 or x >= GRID_COLS or y < 0 or y >= GRID_ROWS:
		return TerrainData.Terrain.VOID
	return terrain_grid[y][x]


func grid_to_world(grid_x: int, grid_y: int) -> Vector2:
	var world_offset := Vector2(-grid_center.x * TILE_SIZE, -grid_center.y * TILE_SIZE)
	return Vector2(
		grid_x * TILE_SIZE + world_offset.x,
		grid_y * TILE_SIZE + world_offset.y
	)


func get_rendered_count() -> int:
	var count := 0
	for y in range(GRID_ROWS):
		for x in range(GRID_COLS):
			if terrain_grid[y][x] != TerrainData.Terrain.VOID:
				count += 1
	return count


func world_to_grid(world_pos: Vector2) -> Vector2i:
	var world_offset := Vector2(-grid_center.x * TILE_SIZE, -grid_center.y * TILE_SIZE)
	var gx := int(roundf((world_pos.x - world_offset.x) / TILE_SIZE))
	var gy := int(roundf((world_pos.y - world_offset.y) / TILE_SIZE))
	return Vector2i(gx, gy)
