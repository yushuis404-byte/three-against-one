extends PanelContainer
## Temporary read-only civilization route debug display.

@export var rule_service_path: NodePath = NodePath("../../GameBoard/CivilizationRuleService")

var _rule_service: Node = null
var _label: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_style()
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color(0.92, 0.9, 0.84))
	add_child(_label)

	_rule_service = get_node_or_null(rule_service_path)
	if _rule_service != null and _rule_service.has_signal("route_changed"):
		_rule_service.route_changed.connect(func(_player: int): refresh())
	refresh()


func refresh() -> void:
	if _label == null:
		return
	if _rule_service == null:
		_label.text = "文明路线\n规则服务未找到"
		return

	var lines: Array[String] = ["文明路线状态"]
	for player in [0, 1, 2]:
		lines.append(_format_player_line(player))
	_label.text = "\n".join(lines)


func _format_player_line(player: int) -> String:
	var summary: Dictionary = _rule_service.call("get_state_summary", player)
	if summary.is_empty():
		return "%s：未找到路线状态" % GameCatalog.faction_name(player)

	var axis: Dictionary = summary.get("axis_values", {})
	var lords: Array = summary.get("lord_ids", [])
	var buildings: Array = summary.get("unlocked_buildings", [])
	var modifiers: Dictionary = summary.get("passive_modifiers", {})
	return "%s｜%s｜领主：%s｜解锁：%s｜加成：%s" % [
		GameCatalog.faction_name(player),
		_route_name(axis),
		_format_lords(lords),
		_format_unlocks(buildings),
		_format_modifiers(modifiers),
	]


func _format_modifiers(modifiers: Dictionary) -> String:
	if modifiers.is_empty():
		return "无"
	var parts: Array[String] = []
	for key in modifiers.keys():
		parts.append("%s+%s" % [_modifier_name(str(key)), str(modifiers[key])])
	return "，".join(parts)


func _route_name(axis: Dictionary) -> String:
	var information: int = int(axis.get("information", 0))
	var space: int = int(axis.get("space", 0))
	var war: int = int(axis.get("war", 0))
	if information >= space and information >= war:
		return "情报路线"
	if space >= information and space >= war:
		return "筑城路线"
	return "战争路线"


func _format_lords(values: Array) -> String:
	if values.is_empty():
		return "无"
	var parts: Array[String] = []
	for value in values:
		parts.append(_lord_name(str(value)))
	return "，".join(parts)


func _format_unlocks(buildings: Array) -> String:
	if buildings.is_empty():
		return "无"
	var named: Array[String] = []
	for building_id in buildings:
		named.append(_building_name(str(building_id)))
	return "建筑 " + "，".join(named)


func _lord_name(lord_id: String) -> String:
	match lord_id:
		"lord.elf.wind_seer":
			return "风语先知"
		"lord.dwarf.stone_warden":
			return "石誓守望者"
		"lord.orc.blood_chief":
			return "血牙酋长"
	return lord_id


func _building_name(building_id: String) -> String:
	match building_id:
		"building.wind_ancient_tree":
			return "风语古树"
		"building.stone_wall":
			return "石墙"
		"building.watch_tower":
			return "哨塔"
		"building.blood_fang_den":
			return "血牙巢穴"
	return building_id


func _modifier_name(key: String) -> String:
	match key:
		"unit_vision_bonus":
			return "单位视野"
		"scout_move_bonus":
			return "斥候移动"
		"building_hp_bonus":
			return "建筑生命"
		"repair_efficiency_bonus":
			return "修复效率"
		"kill_gold_reward":
			return "击杀金币"
		"melee_atk_bonus":
			return "近战攻击"
	return key


func _setup_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.055, 0.78)
	style.border_color = Color(0.45, 0.42, 0.35, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)
