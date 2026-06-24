extends Node2D
## 建筑管理器 — 放置、绘制、回合产出、交互
##
## 使用 building_grid[y][x] 记录每格所属 building_id（多格建筑多格同 id）
## 绘制在迷雾之下但领土之上，单位之下

const GarrisonServiceScript := preload("res://scripts/services/garrison_service.gd")
const RecruitmentServiceScript := preload("res://scripts/services/recruitment_service.gd")
const BuildingUpgradeServiceScript := preload("res://scripts/services/building_upgrade_service.gd")
const ELF_CAPITAL_TEXTURE: Texture2D = preload("res://assets/texture/Elven Capital.png")

var grid_cols := 100
var grid_rows := 56
var tile_size := 32.0
var grid_center := Vector2(49.5, 27.5)

var building_grid: Array = []         # [y][x] → building_id 或 -1
var _buildings: Array = []            # Array[Dictionary]
var _next_id := 1
var _selected_id := -1
var _hovered_id := -1

var _grid_manager: Node = null
var _turn_manager: Node = null
var _territory_mgr: Node = null
var _fog_mgr: Node = null
var _resource_mgr: Node = null
var _template_registry: Node = null
var _technology_service: Node = null
var _garrison_service = GarrisonServiceScript.new()
var _recruitment_service = RecruitmentServiceScript.new()
var _upgrade_service = BuildingUpgradeServiceScript.new()

var _just_garrisoned: Dictionary = {}  # building_id → true, 本帧刚驻兵

# 放置模式
var _placement_active := false
var _placement_data: BuildingData = null
var _placement_faction := -1
var _placement_hover_pos: Vector2i = Vector2i(-1, -1)
var _placement_valid := false
var _resource_tracker: Node = null

signal building_hovered(text: String)
signal placement_canceled()
signal recruit_panel_requested(building_id: int, building_name: String, options: Array, queue: Array)
signal recruit_panel_closed()
signal recruit_queue_changed(building_id: int, queue: Array)
signal building_placed(player: int, building: Dictionary)
signal building_upgraded(player: int, building: Dictionary, level: int)
signal building_garrisoned(player: int, building: Dictionary, unit: Dictionary)
signal unit_recruited(player: int, unit: Dictionary, unit_template_id: String)

const BUILDING_ALPHA := 0.85
const SELECT_COLOR := Color(1.0, 1.0, 1.0, 0.6)
const EFFECT_RANGE_COLOR := Color(0.35, 0.75, 1.0, 0.18)
const EFFECT_RANGE_BORDER_COLOR := Color(0.6, 0.9, 1.0, 0.35)
const ELF_CAPITAL_TEXTURE_SCALE := 1.45


func _ready() -> void:
	_init_grid()
	_grid_manager = get_parent().get_node("GridManager2D")
	_territory_mgr = get_parent().get_node("TerritoryManager2D")
	_fog_mgr = get_parent().get_node("FogOfWar2D")
	_resource_mgr = get_parent().get_node("ResourceManager2D")
	_template_registry = get_parent().get_node_or_null("TemplateRegistry")
	_technology_service = get_parent().get_node_or_null("TechnologyService")
	_configure_services()


func _init_grid() -> void:
	building_grid = []
	for y in range(grid_rows):
		var row: Array = []
		for x in range(grid_cols):
			row.append(-1)
		building_grid.append(row)


func set_turn_manager(tm: Node) -> void:
	_turn_manager = tm
	if tm:
		tm.player_turn_started.connect(_on_player_turn_started)
		tm.round_ended.connect(_on_round_ended)
	_configure_services()


func set_resource_tracker(rt: Node) -> void:
	_resource_tracker = rt
	_configure_services()


func _configure_services() -> void:
	if _recruitment_service == null:
		return
	var unit_mgr = null
	if is_inside_tree():
		unit_mgr = get_parent().get_node_or_null("UnitManager2D")
	_recruitment_service.setup(
		_buildings,
		building_grid,
		grid_cols,
		grid_rows,
		_template_registry,
		_resource_tracker,
		_turn_manager,
		unit_mgr
	)
	if _upgrade_service:
		_upgrade_service.setup(_buildings, _resource_tracker, _turn_manager)
	if _technology_service == null and is_inside_tree():
		_technology_service = get_parent().get_node_or_null("TechnologyService")
	if _technology_service != null:
		if _recruitment_service != null and _recruitment_service.has_method("set_technology_service"):
			_recruitment_service.set_technology_service(_technology_service)
		if _upgrade_service != null and _upgrade_service.has_method("set_technology_service"):
			_upgrade_service.set_technology_service(_technology_service)


func set_technology_service(service: Node) -> void:
	_technology_service = service
	_configure_services()


func _on_player_turn_started(player: int) -> void:
	_reveal_town_hall_vision(player)
	_process_recruit_queues(player)
	queue_redraw()


func _process(_delta: float) -> void:
	_just_garrisoned.clear()


func reveal_all_town_hall_vision() -> void:
	## 游戏开始时揭示所有主城的视野
	for p in range(3):
		_reveal_town_hall_vision(p)


func _reveal_town_hall_vision(player: int) -> void:
	## 揭示该玩家所有主城周围的迷雾（视野半径 4）
	if not _fog_mgr or not _fog_mgr.has_method("reveal_area"):
		return
	for b in _buildings:
		if b["faction"] == player:
			var data: BuildingData = b["data"]
			if data.category == BuildingData.BuildingCategory.CORE:
				var origin: Vector2i = b["origin"]
				var fp: Vector2i = data.footprint
				var cx: int = origin.x + fp.x / 2
				var cy: int = origin.y + fp.y / 2
				_fog_mgr.reveal_area(player, cx, cy, 4)


# ========== Building 数据 API ==========

func place_building(data: BuildingData, faction: int, origin: Vector2i) -> bool:
	## 在 origin（建筑左下角原点）放置建筑，成功返回 true
	if not _can_place(data, faction, origin):
		return false

	var bid := _next_id
	_next_id += 1

	var tiles := _get_footprint_tiles(origin, data.footprint)
	for t in tiles:
		building_grid[t.y][t.x] = bid

	_buildings.append({
		"id": bid,
		"data": data,
		"faction": faction,
		"origin": origin,
		"hp": data.hp_max,
		"level": maxi(1, data.storage_level),
		"garrison": [],
		"recruit_queue": [],
	})

	if BuildingRules.is_outpost(data) and _territory_mgr:
		var source := Vector2i(origin.x + data.footprint.x / 2, origin.y + data.footprint.y / 2)
		if _territory_mgr.has_method("add_town_hall"):
			_territory_mgr.add_town_hall(faction, source)

	# 放置建筑时揭示该阵营对应区域的迷雾
	if _fog_mgr and _fog_mgr.has_method("reveal_area_immediate"):
		var fp: Vector2i = data.footprint
		var center_x: int = origin.x + fp.x / 2
		var center_y: int = origin.y + fp.y / 2
		_fog_mgr.reveal_area_immediate(faction, center_x, center_y, 3)

	if BuildingRules.is_outpost(data) and _territory_mgr and _territory_mgr.has_method("recalc_territory"):
		_territory_mgr.recalc_territory(faction)

	if data.storage_level > 0 and _resource_tracker and _resource_tracker.has_method("update_display"):
		_resource_tracker.update_display(faction)

	# 金矿矿井消耗金矿资源点
	if data.needs_resource_point:
		if _resource_mgr and _resource_mgr.has_method("remove_resource"):
			_resource_mgr.remove_resource(origin.x, origin.y)

	var placed_building: Dictionary = _get_building_by_id(bid)
	if not placed_building.is_empty():
		building_placed.emit(faction, placed_building.duplicate())
	queue_redraw()
	return true


func get_building_at(grid_pos: Vector2i) -> Dictionary:
	if grid_pos.x < 0 or grid_pos.x >= grid_cols or grid_pos.y < 0 or grid_pos.y >= grid_rows:
		return {}
	var bid: int = building_grid[grid_pos.y][grid_pos.x]
	if bid < 0:
		return {}
	for b in _buildings:
		if b["id"] == bid:
			return b
	return {}


func is_tile_occupied(gx: int, gy: int) -> bool:
	if gx < 0 or gx >= grid_cols or gy < 0 or gy >= grid_rows:
		return true  # out of bounds = occupied
	return building_grid[gy][gx] >= 0


# ========== Footprint 工具 ==========

func _get_footprint_tiles(origin: Vector2i, fp: Vector2i) -> Array:
	## 返回建筑原点 + footprint 覆盖的所有 Vector2i 格子
	var result: Array = []
	for dy in range(fp.y):
		for dx in range(fp.x):
			result.append(Vector2i(origin.x + dx, origin.y + dy))
	return result


func _can_place(data: BuildingData, faction: int, origin: Vector2i) -> bool:
	## 校验所有 footprint 格是否满足放置条件
	var tiles := _get_footprint_tiles(origin, data.footprint)
	for t in tiles:
		if t.x < 0 or t.x >= grid_cols or t.y < 0 or t.y >= grid_rows:
			return false
		# 领地检查
		if _territory_mgr:
			var owner: int = _territory_mgr.get_cell_owner(t.x, t.y)
			if owner != faction:
				return false
		# 地形兼容
		if _grid_manager and _grid_manager.has_method("get_terrain_at"):
			var terrain: int = _grid_manager.get_terrain_at(t.x, t.y)
			if not (terrain in data.terrain_compatibility):
				return false
		# 格子未被占用
		if building_grid[t.y][t.x] >= 0:
			return false

	# 金矿矿井：需要金矿资源点
	if data.needs_resource_point:
		if not _resource_mgr or not _resource_mgr.has_method("get_resource_type"):
			return false
		if _resource_mgr.get_resource_type(origin.x, origin.y) != 1:
			return false

	# 阵营上限检查
	if data.storage_level > 0:
		var warehouse_count := 0
		for b in _buildings:
			var existing_data: BuildingData = b["data"]
			if b["faction"] == faction and existing_data.storage_level > 0:
				warehouse_count += 1
		if warehouse_count >= data.max_per_faction:
			return false

	if data.max_per_faction < 99:
		var count := 0
		for b in _buildings:
			if b["faction"] == faction and b["data"].name == data.name:
				count += 1
		if count >= data.max_per_faction:
			return false

	return true


func count_buildings(faction: int, name_filter: String = "") -> int:
	var count := 0
	for b in _buildings:
		if b["faction"] != faction:
			continue
		if name_filter.is_empty() or b["data"].name == name_filter:
			count += 1
	return count

func get_all_buildings() -> Array:
	return _buildings.duplicate()


func get_upgrade_info(building_id: int) -> Dictionary:
	return _upgrade_service.get_upgrade_info(building_id)


func upgrade_building(building_id: int) -> bool:
	var ok: bool = _upgrade_service.upgrade(building_id)
	if ok:
		var building: Dictionary = _get_building_by_id(building_id)
		if not building.is_empty() and _resource_tracker and _resource_tracker.has_method("update_display"):
			_resource_tracker.update_display(int(building.get("faction", 0)))
		if not building.is_empty():
			building_upgraded.emit(int(building.get("faction", -1)), building.duplicate(), int(building.get("level", 1)))
		queue_redraw()
	return ok


# ========== 驻兵系统 ==========

func max_garrison(building: Dictionary) -> int:
	return _garrison_service.max_garrison(building)


func can_garrison(building_id: int, faction: int, unit_category: int = -1) -> bool:
	return _garrison_service.can_garrison(_buildings, building_id, faction, unit_category)


func garrison_unit(building_id: int, unit_dict: Dictionary) -> void:
	if _garrison_service.garrison_unit(_buildings, building_id, unit_dict):
		_just_garrisoned[building_id] = true
		var building: Dictionary = _get_building_by_id(building_id)
		if not building.is_empty():
			building_garrisoned.emit(int(building.get("faction", -1)), building.duplicate(), unit_dict.duplicate())
		queue_redraw()


func ungarrison_one(building_id: int) -> Dictionary:
	var unit: Dictionary = _garrison_service.ungarrison_one(_buildings, building_id)
	if not unit.is_empty():
		queue_redraw()
	return unit


func get_garrison_bonus(building_id: int) -> Dictionary:
	return _garrison_service.get_garrison_bonus(_buildings, building_id)
func _find_ungarrison_pos(building: Dictionary) -> Vector2i:
	## 在建筑周围找第一个空位用于撤出单位
	var origin: Vector2i = building["origin"]
	var fp: Vector2i = building["data"].footprint
	var dirs := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	for dy in range(fp.y):
		for dx in range(fp.x):
			for dir in dirs:
				var n: Vector2i = Vector2i(origin.x + dx, origin.y + dy) + dir
				if n.x < 0 or n.x >= grid_cols or n.y < 0 or n.y >= grid_rows:
					continue
				if building_grid[n.y][n.x] >= 0:
					continue
				return n
	return Vector2i(-1, -1)


# ========== 绘制 ==========

func _draw() -> void:
	if not _buildings.is_empty():
		_draw_effect_ranges()
		_draw_buildings()

	# 放置模式幽灵预览
	if _placement_active and _placement_data and _in_bounds(_placement_hover_pos.x, _placement_hover_pos.y):
		_draw_placement_ghost()


func _draw_buildings() -> void:
	for b in _buildings:
		var data: BuildingData = b["data"]
		var faction: int = b["faction"]
		var origin: Vector2i = b["origin"]
		var fp: Vector2i = data.footprint
		var is_selected: bool = b["id"] == _selected_id

		# 迷雾检查：所有占用格都在迷雾中 → 不绘制
		if _fog_mgr and _fog_mgr.has_method("get_fog"):
			var all_fogged := true
			var tiles := _get_footprint_tiles(origin, fp)
			for t in tiles:
				var viewer: int = _turn_manager.current_player if _turn_manager else 0
				if _fog_mgr.get_fog(viewer, t.x, t.y) <= 0.0:
					all_fogged = false
					break
			if all_fogged:
				continue

		var world_origin := _grid_to_world(origin.x, origin.y)
		var top_left := Vector2(world_origin.x - tile_size * 0.5, world_origin.y - tile_size * 0.5)
		var w := fp.x * tile_size
		var h := fp.y * tile_size

		# 选中高亮
		if is_selected:
			draw_rect(Rect2(top_left.x - 3, top_left.y - 3, w + 6, h + 6),
				SELECT_COLOR, false, 4.0)

		# 主城特殊效果：外发光
		if data.category == BuildingData.BuildingCategory.CORE:
			var glow_color: Color = GameCatalog.faction_color(faction)
			glow_color.a = 0.3
			draw_rect(Rect2(top_left.x - 4, top_left.y - 4, w + 8, h + 8), glow_color, true)
			glow_color.a = 0.2
			draw_rect(Rect2(top_left.x - 8, top_left.y - 8, w + 16, h + 16), glow_color, true)

		# 建筑底色方块
		var color: Color = GameCatalog.faction_color(faction)
		color.a = BUILDING_ALPHA
		draw_rect(Rect2(top_left.x, top_left.y, w, h), color, true)
		if _should_draw_elven_capital_texture(data, faction):
			var tex_w: float = w * ELF_CAPITAL_TEXTURE_SCALE
			var tex_h: float = h * ELF_CAPITAL_TEXTURE_SCALE
			var tex_rect := Rect2(
				top_left.x + w / 2.0 - tex_w / 2.0,
				top_left.y + h / 2.0 - tex_h / 2.0,
				tex_w,
				tex_h
			)
			draw_texture_rect(ELF_CAPITAL_TEXTURE, tex_rect, false)

		# 建筑名称文字
		var font: Font = ThemeDB.fallback_font
		var fsize: int = 13 if data.category == BuildingData.BuildingCategory.CORE else 11
		var label: String = data.name
		if int(b.get("level", 1)) > 1 and data.max_level > 1:
			label = "%s Lv%d" % [data.name, int(b.get("level", 1))]
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
		var label_pos := Vector2(
			top_left.x + w / 2.0 - text_size.x / 2.0,
			top_left.y + h / 2.0 + fsize / 3.0
		)
		# 文字阴影增加可读性
		draw_string(font, Vector2(label_pos.x + 1, label_pos.y + 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(0, 0, 0, 0.6))
		draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color.WHITE)

		# 主城特殊标记：顶部显示城堡图标 ★
		if data.category == BuildingData.BuildingCategory.CORE:
			var star_text := "★ 主城 ★"
			var star_size := font.get_string_size(star_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
			var star_pos := Vector2(
				top_left.x + w / 2.0 - star_size.x / 2.0,
				top_left.y - 6
			)
			draw_string(font, Vector2(star_pos.x + 1, star_pos.y + 1), star_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, 0.7))
			draw_string(font, star_pos, star_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.9, 0.3))

		# HP 标签（右下角小字）
		var hp_label := "HP:%d" % b["hp"]
		var hp_size := font.get_string_size(hp_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
		var hp_pos := Vector2(
			top_left.x + w - hp_size.x - 2,
			top_left.y + h - 3
		)
		draw_string(font, hp_pos, hp_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)

		# 驻兵圆点（建筑上方）
		var garrison: Array = b.get("garrison", [])
		if not garrison.is_empty():
			var dot_count: int = garrison.size()
			var max_dots := mini(dot_count, 4)
			var dot_radius := 2.5
			var dot_spacing := 8.0
			var dots_total_width := (max_dots - 1) * dot_spacing
			var dots_start_x := top_left.x + w / 2.0 - dots_total_width / 2.0
			for i in range(max_dots):
				var dot_pos := Vector2(dots_start_x + i * dot_spacing, top_left.y - 10)
				draw_circle(dot_pos, dot_radius, GameCatalog.faction_color(faction))
				draw_arc(dot_pos, dot_radius, 0, TAU, 8, Color.BLACK, 0.8)
			if dot_count > 4:
				var plus_label := "+%d" % [dot_count - 4]
				var plus_size := font.get_string_size(plus_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
				var plus_pos := Vector2(dots_start_x + 4 * dot_spacing + 2, top_left.y - 10 + 3)
				draw_string(font, plus_pos, plus_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)


func _draw_effect_ranges() -> void:
	var range_buildings: Array[Dictionary] = []
	if _hovered_id >= 0:
		var hovered: Dictionary = _get_building_by_id(_hovered_id)
		if _should_draw_effect_range(hovered):
			range_buildings.append(hovered)
	if _selected_id >= 0 and _selected_id != _hovered_id:
		var selected: Dictionary = _get_building_by_id(_selected_id)
		if _should_draw_effect_range(selected):
			range_buildings.append(selected)

	for building in range_buildings:
		_draw_effect_range_for_building(building)


func _should_draw_effect_range(building: Dictionary) -> bool:
	if building.is_empty() or not building.has("data"):
		return false
	var data: BuildingData = building["data"]
	return data.effect_radius > 0


func _draw_effect_range_for_building(building: Dictionary) -> void:
	var data: BuildingData = building["data"]
	var center: Vector2i = _get_building_center(building)
	var radius: int = data.effect_radius
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if not _in_bounds(x, y):
				continue
			var dist: int = absi(center.x - x) + absi(center.y - y)
			if dist > radius:
				continue
			var world_pos: Vector2 = _grid_to_world(x, y)
			var top_left := Vector2(world_pos.x - tile_size * 0.5, world_pos.y - tile_size * 0.5)
			var rect := Rect2(top_left, Vector2(tile_size, tile_size))
			draw_rect(rect, EFFECT_RANGE_COLOR, true)
			draw_rect(rect, EFFECT_RANGE_BORDER_COLOR, false, 1.0)


func _get_building_center(building: Dictionary) -> Vector2i:
	var data: BuildingData = building["data"]
	var origin: Vector2i = building.get("origin", Vector2i.ZERO)
	return Vector2i(origin.x + data.footprint.x / 2, origin.y + data.footprint.y / 2)


func _should_draw_elven_capital_texture(data: BuildingData, faction: int) -> bool:
	return faction == 0 and data.category == BuildingData.BuildingCategory.CORE


func _draw_placement_ghost() -> void:
	if not _placement_data:
		return
	var fp: Vector2i = _placement_data.footprint
	var world_origin := _grid_to_world(_placement_hover_pos.x, _placement_hover_pos.y)
	var top_left := Vector2(world_origin.x - tile_size * 0.5, world_origin.y - tile_size * 0.5)
	var w := fp.x * tile_size
	var h := fp.y * tile_size
	var color: Color
	if _placement_valid:
		color = Color(0.3, 1.0, 0.3, 0.4)
	else:
		color = Color(1.0, 0.3, 0.3, 0.4)
	draw_rect(Rect2(top_left.x, top_left.y, w, h), color, true)
	draw_rect(Rect2(top_left.x, top_left.y, w, h), Color.WHITE, false, 1.5)


# ========== 回合产出 ==========

func _on_round_ended(round_number: int) -> void:
	for b in _buildings:
		var data: BuildingData = b["data"]
		var prod: Dictionary = data.production

		# 金币铸造厂特殊显示
		if BuildingRules.is_mint(data):
			var garr: Array = b.get("garrison", [])
			var gcount := garr.size()
			if gcount > 0:
				var faction_name := GameCatalog.faction_name(int(b["faction"]))
				print("[建筑] %s 金币铸造厂: 驻兵 %d → 金币 +%d（消耗金矿石）" % [faction_name, gcount, gcount * 2])
				_show_production_text(b, {"gold": gcount * 2}, 0, Color(1.0, 0.84, 0.0))
			continue

		if prod.is_empty():
			continue
		var faction_name := ""
		match b["faction"]:
			0: faction_name = "精灵"
			1: faction_name = "矮人"
			2: faction_name = "兽人"
		var parts: PackedStringArray = []
		for key in prod:
			parts.append("%s +%d" % [key, prod[key]])
		print("[建筑] %s %s: %s" % [faction_name, data.name, ", ".join(parts)])

		# 驻兵加成日志
		var garrison: Array = b.get("garrison", [])
		var gcount: int = garrison.size()
		if gcount > 0:
			var garrison_bonus: Dictionary = get_garrison_bonus(b["id"])
			var bonus_parts: PackedStringArray = []
			for key in garrison_bonus:
				bonus_parts.append("%s +%d" % [key, garrison_bonus[key]])
			if not bonus_parts.is_empty():
				print("[Building] garrison bonus %s: %s" % [data.name, ", ".join(bonus_parts)])

		# 建筑上方飘浮产量文字
		_show_production_text(b, prod, gcount)


func _show_production_text(building: Dictionary, prod: Dictionary, gcount: int, custom_color: Color = Color(0.5, 1.0, 0.5)) -> void:
	## 在建筑上方创建飘浮产量文字，如 "木材 +1" "石料 +2"
	if prod.is_empty():
		return
	var data: BuildingData = building["data"]
	var origin: Vector2i = building["origin"]
	var fp: Vector2i = data.footprint
	var cx: int = origin.x + fp.x / 2
	var cy: int = origin.y + fp.y / 2
	var world_pos := _grid_to_world(cx, cy)

	var lines: PackedStringArray = []
	var bonus: Dictionary = get_garrison_bonus(building["id"])
	for key in prod:
		var total: int = int(prod[key]) + int(bonus.get(key, 0))
		var rname: String = GameCatalog.resource_name(key)
		lines.append("%s +%d" % [rname, total])
	var text := "\n".join(lines)

	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", custom_color)
	label.add_theme_font_size_override("font_size", 13)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(world_pos.x - 30, world_pos.y - 30)
	add_child(label)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(label, "position", label.position + Vector2(0, -30), 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)


# ========== 交互 ==========

func _unhandled_input(event: InputEvent) -> void:
	# 放置模式优先处理
	if _placement_active:
		_handle_placement_input(event)
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_U and _selected_id >= 0:
			var building: Dictionary = _get_building_by_id(_selected_id)
			if not building.is_empty() and _turn_manager and int(building.get("faction", -1)) == _turn_manager.current_player:
				upgrade_building(_selected_id)
			return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cursor := get_global_mouse_position()
		var gpos := _world_to_grid(cursor)
		if gpos.x < 0 or gpos.x >= grid_cols or gpos.y < 0 or gpos.y >= grid_rows:
			_clear_selection()
			return
		var building := get_building_at(gpos)
		if not building.is_empty():
			# 检查撤出驻兵：点击己方有驻兵的建筑 → 撤出一个
			var garr: Array = building.get("garrison", [])
			var building_data: BuildingData = building["data"]
			if not garr.is_empty() and building_data.upgrade_rules.is_empty() and _turn_manager and not _just_garrisoned.has(building["id"]):
				var cp: int = _turn_manager.current_player
				if building["faction"] == cp:
					var unit_dict := ungarrison_one(building["id"])
					if not unit_dict.is_empty():
						var spawn_pos := _find_ungarrison_pos(building)
						if spawn_pos.x >= 0:
							var unit_mgr = get_parent().get_node("UnitManager2D")
							if unit_mgr and unit_mgr.has_method("add_unit"):
								unit_mgr.add_unit(cp, unit_dict["data"], spawn_pos, unit_dict.get("hp", -1))
						return  # 撤出后不切换选择
			if _selected_id == building["id"]:
				_clear_selection()
			else:
				_select_building(building["id"])
		else:
			_clear_selection()

	if event is InputEventMouseMotion:
		var cursor := get_global_mouse_position()
		var gpos := _world_to_grid(cursor)
		if gpos.x < 0 or gpos.x >= grid_cols or gpos.y < 0 or gpos.y >= grid_rows:
			_set_hovered_building(-1)
			return
		var building := get_building_at(gpos)
		if not building.is_empty():
			_set_hovered_building(int(building["id"]))
			var data: BuildingData = building["data"]
			var fname := GameCatalog.faction_name(int(building["faction"]))
			var building_name: String = data.name
			if int(building.get("level", 1)) > 1 and data.max_level > 1:
				building_name = "%s Lv%d" % [data.name, int(building.get("level", 1))]
			var hover_text := "%s - %s (HP:%d/%d)" % [fname, building_name, building["hp"], data.hp_max]
			if data.effect_radius > 0:
				hover_text += " - Range:%d" % data.effect_radius
			var garr: Array = building.get("garrison", [])
			if not garr.is_empty():
				hover_text += " - Garrison:%d" % garr.size()
			building_hovered.emit(hover_text)
		else:
			_set_hovered_building(-1)


func _handle_placement_input(event: InputEvent) -> void:
	## 放置模式下处理鼠标移动（预览）+ 左键（建造）+ 右键（取消）
	if event is InputEventMouseMotion:
		var cursor := get_global_mouse_position()
		var gpos := _world_to_grid(cursor)
		_placement_hover_pos = gpos
		_placement_valid = _check_placement_valid(gpos)
		queue_redraw()
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _placement_valid:
				_do_placement(_placement_hover_pos)
			else:
				queue_redraw()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_placement()


func _select_building(bid: int) -> void:
	_selected_id = bid
	var building: Dictionary = _get_building_by_id(bid)
	if _is_recruit_building(building):
		_emit_recruit_panel(building)
	else:
		recruit_panel_closed.emit()
	queue_redraw()


func _clear_selection() -> void:
	_selected_id = -1
	recruit_panel_closed.emit()
	queue_redraw()


# ========== 放置模式 ==========


func _set_hovered_building(building_id: int) -> void:
	if _hovered_id == building_id:
		return
	_hovered_id = building_id
	queue_redraw()

func start_placement(data: BuildingData, faction: int) -> void:
	## 点击建筑卡片后进入放置模式
	_placement_active = true
	_placement_data = data
	_placement_faction = faction
	_placement_hover_pos = Vector2i(-1, -1)
	_placement_valid = false
	queue_redraw()


func cancel_placement() -> void:
	## 取消放置模式
	_placement_active = false
	_placement_data = null
	_placement_faction = -1
	_placement_hover_pos = Vector2i(-1, -1)
	_placement_valid = false
	placement_canceled.emit()
	queue_redraw()


func _check_placement_valid(pos: Vector2i) -> bool:
	## 实时校验是否可在此处建造
	if not _placement_data or not _in_bounds(pos.x, pos.y):
		return false

	var data: BuildingData = _placement_data
	var faction: int = _placement_faction

	# 资源检查
	if _resource_tracker:
		if _resource_tracker.get_resource(faction, "gold") < data.cost_gold:
			return false
		if _resource_tracker.get_resource(faction, "wood") < data.cost_wood:
			return false
		if _resource_tracker.get_resource(faction, "stone") < data.cost_stone:
			return false
		if _resource_tracker.get_resource(faction, "iron") < data.cost_iron:
			return false
		if _resource_tracker.get_resource(faction, "food") < data.cost_food:
			return false

	# AP 检查
	if _turn_manager:
		var ap: int = _turn_manager.get_ap(_turn_manager.current_player)
		if ap < 2:
			return false

	# 领土/地形/占用/上限检查
	return _can_place(data, faction, pos)


func _do_placement(pos: Vector2i) -> void:
	## 执行建造：扣资源 → 扣 AP → 放置建筑
	if not _placement_data:
		return

	var data: BuildingData = _placement_data
	var faction: int = _placement_faction

	# 扣资源
	if _resource_tracker:
		_resource_tracker.spend_resource(faction, "gold", data.cost_gold)
		_resource_tracker.spend_resource(faction, "wood", data.cost_wood)
		_resource_tracker.spend_resource(faction, "stone", data.cost_stone)
		_resource_tracker.spend_resource(faction, "iron", data.cost_iron)
		_resource_tracker.spend_resource(faction, "food", data.cost_food)

	# 扣 AP
	if _turn_manager:
		_turn_manager.spend_ap(faction, 2)

	# 放置建筑
	var placed: bool = place_building(data, faction, pos)
	if placed:
		print("[建造] 阵营 %d 在 %s 建造 %s" % [faction, str(pos), data.name])

	cancel_placement()


# ========== 坐标工具 ==========

func _grid_to_world(grid_x: int, grid_y: int) -> Vector2:
	var offset := Vector2(-grid_center.x * tile_size, -grid_center.y * tile_size)
	return Vector2(grid_x * tile_size + offset.x, grid_y * tile_size + offset.y)


func _world_to_grid(world_pos: Vector2) -> Vector2i:
	var offset := Vector2(-grid_center.x * tile_size, -grid_center.y * tile_size)
	var gx := int(roundf((world_pos.x - offset.x) / tile_size))
	var gy := int(roundf((world_pos.y - offset.y) / tile_size))
	return Vector2i(gx, gy)


func _in_bounds(gx: int, gy: int) -> bool:
	return gx >= 0 and gx < grid_cols and gy >= 0 and gy < grid_rows


func request_recruitment(building_id: int, unit_template_id: String, count: int) -> bool:
	var ok: bool = _recruitment_service.request_recruitment(building_id, unit_template_id, count)
	if ok:
		var building: Dictionary = _get_building_by_id(building_id)
		recruit_queue_changed.emit(building_id, building.get("recruit_queue", []).duplicate(true))
		_emit_recruit_panel(building)
	return ok


func get_recruit_queue(building_id: int) -> Array:
	return _recruitment_service.get_recruit_queue(building_id)


func _process_recruit_queues(player: int) -> void:
	var changed_buildings: Array = _recruitment_service.process_recruit_queues(player)
	var spawned_units: Array = _recruitment_service.consume_last_spawned_units()
	for building in changed_buildings:
		var queue: Array = building.get("recruit_queue", [])
		recruit_queue_changed.emit(building["id"], queue.duplicate(true))
		if building["id"] == _selected_id:
			_emit_recruit_panel(building)
	var unit_mgr = get_parent().get_node_or_null("UnitManager2D")
	for entry in spawned_units:
		var unit_id: int = int(entry.get("unit_id", -1))
		if unit_id < 0 or unit_mgr == null or not unit_mgr.has_method("get_unit_by_id"):
			continue
		var unit: Dictionary = unit_mgr.get_unit_by_id(unit_id)
		if unit.is_empty():
			continue
		unit_recruited.emit(player, unit.duplicate(), str(entry.get("unit_template_id", "")))


func _spawn_recruited_unit(building: Dictionary, unit_template_id: String) -> bool:
	return _recruitment_service.spawn_recruited_unit(building, unit_template_id)


func _find_empty_adjacent_pos(building: Dictionary) -> Vector2i:
	return _recruitment_service.find_empty_adjacent_pos(building)


func _emit_recruit_panel(building: Dictionary) -> void:
	var options: Array = _get_recruit_options(building)
	if options.is_empty():
		recruit_panel_closed.emit()
		return
	recruit_panel_requested.emit(
		building["id"],
		building["data"].name,
		options,
		building.get("recruit_queue", []).duplicate(true)
	)


func _get_recruit_options(building: Dictionary) -> Array:
	return _recruitment_service.get_recruit_options(building)


func _get_recruit_template_ids_for_building(building: Dictionary) -> Array:
	return _recruitment_service.get_recruit_template_ids_for_building(building)


func _get_faction_recruit_template_ids(building: Dictionary) -> Array:
	return _recruitment_service.get_faction_recruit_template_ids(building)


func _get_building_template_for_data(data: BuildingData) -> Resource:
	return _recruitment_service.get_building_template_for_data(data)


func _building_can_recruit(building: Dictionary, unit_template_id: String) -> bool:
	return _recruitment_service.building_can_recruit(building, unit_template_id)


func _get_recruit_unit_template(unit_template_id: String) -> Resource:
	return _recruitment_service.get_recruit_unit_template(unit_template_id)


func _get_unit_recruit_cost(unit_template: Resource) -> Dictionary:
	return _recruitment_service.get_unit_recruit_cost(unit_template)


func _is_recruit_building(building: Dictionary) -> bool:
	return _recruitment_service.is_recruit_building(building)


func _get_building_by_id(building_id: int) -> Dictionary:
	for building in _buildings:
		if building["id"] == building_id:
			return building
	return {}
