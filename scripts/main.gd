extends Node2D
const GameStageRulesScript = preload("res://scripts/rules/game_stage_rules.gd")
const StageEventServiceScript = preload("res://scripts/services/stage_event_service.gd")
const AchievementServiceScript = preload("res://scripts/services/achievement_service.gd")
const AchievementTreePanelScript = preload("res://scripts/ui/achievement_tree_panel.gd")
const TechnologyServiceScript = preload("res://scripts/services/technology_service.gd")
const TechnologyTreePanelScript = preload("res://scripts/ui/technology_tree_panel.gd")
const GoblinHexServiceScript = preload("res://scripts/services/goblin_hex_service.gd")
const GoblinHexPanelScript = preload("res://scripts/ui/goblin_hex_panel.gd")
const VictoryServiceScript = preload("res://scripts/services/victory_service.gd")
const ScoreRulePanelScript = preload("res://scripts/ui/score_rule_panel.gd")
const CivilizationRoutePanelScript = preload("res://scripts/ui/civilization_route_panel.gd")
const VisibilityServiceScript = preload("res://scripts/services/visibility_service.gd")
const GameStateSerializerScript = preload("res://scripts/services/game_state_serializer.gd")
const NetworkGameServiceScript = preload("res://scripts/services/network_game_service.gd")
## 主场景控制器 — 2.5D 三人竞技棋

@onready var camera: Camera2D = $GameCamera
@onready var grid_manager: Node2D = $GameBoard/GridManager2D
@onready var resource_manager: Node2D = $GameBoard/ResourceManager2D
@onready var debug_label: Label = $UI/DebugLabel
@onready var turn_manager: Node = $GameBoard/TurnManager2D
@onready var unit_manager: Node2D = $GameBoard/UnitManager2D
@onready var building_manager: Node2D = $GameBoard/BuildingManager2D
@onready var wall_blueprint_manager: Node2D = $GameBoard/WallBlueprintManager2D
@onready var turn_label: Label = $UI/TurnLabel
@onready var resource_tracker: Node = $GameBoard/ResourceTracker
@onready var gathering_manager: Node2D = $GameBoard/GatheringManager2D
@onready var resource_panel: Panel = $UI/ResourcePanel
@onready var building_ui: Control = $UI/BuildingUI
@onready var recruit_ui: Control = $UI/RecruitUI
@onready var neutral_unit_manager: Node2D = $GameBoard/NeutralUnitManager2D
@onready var goblin_market_ui: Control = $UI/GoblinMarketUI
@onready var civilization_rules: Node = $GameBoard/CivilizationRuleService

enum GameState { LOADING, PLAYING, TURN_RESOLVE, GAME_OVER }
var current_state: GameState = GameState.LOADING
var stage_label: Label = null
var stage_event_service: StageEventService = null
var _goblin_market_round := -1
var action_preview_panel: Control = null
var unit_skill_bar: Control = null
var ap_status_label: Label = null
var _resource_progress_bars: Dictionary = {}
var achievement_service: AchievementService = null
var achievement_tree_panel: Control = null
var achievement_tree_button: Button = null
var technology_service: Node = null
var technology_tree_panel: Control = null
var technology_tree_button: Button = null
var goblin_hex_service: Node = null
var goblin_hex_panel: Control = null
var victory_service: Node = null
var game_over_label: Label = null
var score_rule_panel: Control = null
var score_rule_button: Button = null
var score_label: Label = null
var civilization_route_panel: Control = null
var civilization_route_button: Button = null
var creative_mode_button: Button = null
var wall_blueprint_button: Button = null
var wall_blueprint_status_label: Label = null
var zoom_status_label: Label = null
var visibility_service: VisibilityService = null
var game_state_serializer: GameStateSerializer = null
var network_game_service: NetworkGameService = null
var network_status_label: Label = null
var network_ready_label: Label = null
var network_host_button: Button = null
var network_join_button: Button = null
var network_ready_button: Button = null
var network_address_input: LineEdit = null
var network_port_input: LineEdit = null
var hover_info_card: TextureRect = null
var hover_info_label: Label = null
var _last_hover_info_text := ""
var _creative_mode_enabled := false
var _selected_unit_skill_view: Dictionary = {}
var _wall_preview_valid: bool = false
var _wall_preview_cells: int = 0
var _wall_preview_stone_cost: int = 0


func _ready() -> void:
	print("[Main] 项目启动 - Three Against One (2.5D)")
	_setup_game()


func _process(_delta: float) -> void:
	_update_zoom_status_label()
	_sync_hover_info_card()


func _setup_game() -> void:
	$UI.visible = true
	_hide_civilization_debug_panel()
	current_state = GameState.PLAYING
	_init_stage_label()
	_init_game_over_label()
	var tile_count: int = grid_manager.get_rendered_count()
	debug_label.text = "Three Against One v0.1 | 2.5D 开放世界 | %d 格\n空格+鼠标左键拖拽 平移 | 滚轮 缩放 | Enter/Tab 结束回合" % tile_count
	resource_manager.resource_hovered.connect(_on_resource_hovered)

	# 初始视野：揭示三阵营出生点周围
	var fog_mgr = $GameBoard/FogOfWar2D
	fog_mgr.reveal_area_immediate(0, 35, 12, 3)  # 精灵（覆盖主城 2×2）
	fog_mgr.reveal_area_immediate(1, 35, 42, 3)  # 矮人
	fog_mgr.reveal_area_immediate(2, 62, 34, 3)  # 兽人
	fog_mgr.queue_redraw()
	print("[Main] 2.5D 游戏就绪")

	# 领土系统初始化
	var territory_mgr = $GameBoard/TerritoryManager2D
	territory_mgr.add_town_hall(0, Vector2i(35, 13))  # 精灵
	territory_mgr.add_town_hall(1, Vector2i(35, 43))  # 矮人
	territory_mgr.add_town_hall(2, Vector2i(62, 35))  # 兽人
	territory_mgr.recalc_territory(0)
	territory_mgr.recalc_territory(1)
	territory_mgr.recalc_territory(2)

	# 联通信號：迷雾动画完成后重算领土
	fog_mgr.fog_updated.connect(_on_fog_updated)
	# 建筑系统初始化
	fog_mgr.set_turn_manager(turn_manager)
	resource_manager.set_turn_manager(turn_manager)
	building_manager.set_turn_manager(turn_manager)
	building_manager.building_hovered.connect(_on_resource_hovered)
	building_manager.set_resource_tracker(resource_tracker)
	if wall_blueprint_manager.has_method("set_turn_manager"):
		wall_blueprint_manager.set_turn_manager(turn_manager)
	if wall_blueprint_manager.has_method("set_building_manager"):
		wall_blueprint_manager.set_building_manager(building_manager)
	if wall_blueprint_manager.has_method("set_resource_tracker"):
		wall_blueprint_manager.set_resource_tracker(resource_tracker)
	if wall_blueprint_manager.has_signal("wall_hovered"):
		wall_blueprint_manager.wall_hovered.connect(_on_resource_hovered)
	if wall_blueprint_manager.has_signal("wall_mode_changed"):
		wall_blueprint_manager.wall_mode_changed.connect(_on_wall_mode_changed)
	if wall_blueprint_manager.has_signal("wall_preview_changed"):
		wall_blueprint_manager.wall_preview_changed.connect(_on_wall_preview_changed)
	if building_manager.has_method("set_civilization_rules"):
		building_manager.set_civilization_rules(civilization_rules)
	building_manager.recruit_panel_requested.connect(_on_recruit_panel_requested)
	building_manager.recruit_panel_closed.connect(_on_recruit_panel_closed)
	building_manager.recruit_queue_changed.connect(_on_recruit_queue_changed)
	_place_initial_buildings()
	building_manager.reveal_all_town_hall_vision()

	# 回合系统初始化
	turn_manager.round_started.connect(_on_round_started)
	turn_manager.player_turn_started.connect(_on_player_turn_started)
	turn_manager.round_ended.connect(_on_round_ended)
	turn_manager.ap_changed.connect(_on_ap_changed)
	_init_ap_status_label()
	_init_score_label()
	_init_zoom_status_label()
	_init_stage_event_service()

	# 单位系统初始化
	unit_manager.set_turn_manager(turn_manager)
	if unit_manager.has_signal("unit_hovered"):
		unit_manager.unit_hovered.connect(_on_resource_hovered)
	if unit_manager.has_method("set_civilization_rules"):
		unit_manager.set_civilization_rules(civilization_rules)
	unit_manager.place_initial_units()

	# 中立生物系统初始化
	neutral_unit_manager.set_turn_manager(turn_manager)
	neutral_unit_manager.place_initial_neutral_units()
	neutral_unit_manager.neutral_combat_started.connect(_on_neutral_combat_started)
	neutral_unit_manager.neutral_combat_ended.connect(_on_neutral_combat_ended)
	# 资源追踪系统初始化
	resource_tracker.set_turn_manager(turn_manager)
	resource_tracker.set_building_manager(building_manager)
	if resource_tracker.has_method("set_civilization_rules"):
		resource_tracker.set_civilization_rules(civilization_rules)
	resource_tracker.resources_updated.connect(_on_resources_updated)
	_init_resource_labels()
	_restyle_top_bar()
	_init_hover_info_card()
	_init_creative_mode_button()
	_init_achievement_service()
	_init_technology_service()
	_init_goblin_hex_service()
	_init_victory_service()

	# 建造面板初始化
	building_ui.set_turn_manager(turn_manager)
	building_ui.set_building_manager(building_manager)
	building_ui.set_resource_tracker(resource_tracker)
	if building_ui.has_method("set_civilization_rules"):
		building_ui.set_civilization_rules(civilization_rules)
	building_ui.building_selected.connect(_on_building_selected)
	building_ui.refresh(turn_manager.current_player)

	recruit_ui.recruit_requested.connect(_on_recruit_requested)

	# 哥布林商队面板初始化
	goblin_market_ui.set_resource_tracker(resource_tracker)
	goblin_market_ui.set_neutral_manager(neutral_unit_manager)
	goblin_market_ui.hide()
	_init_goblin_hex_panel()
	unit_manager.hidden_trader_discovered.connect(_on_hidden_trader_discovered)

		# 单位信息面板初始化
	_init_unit_info_panel()
	_init_unit_skill_bar()
	_init_action_preview_panel()
	_init_achievement_tree_panel()
	_init_achievement_tree_button()
	_init_technology_tree_panel()
	_init_technology_tree_button()
	_init_score_rule_panel()
	_init_score_rule_button()
	_init_civilization_route_panel()
	_init_civilization_route_button()
	_init_wall_blueprint_ui()
	_init_network_services()
	_init_network_ui()

	# 所有信号就绪后启动第一回合
	turn_manager.start_game()


func _hide_civilization_debug_panel() -> void:
	var panel: CanvasItem = $UI.get_node_or_null("CivilizationDebugPanel") as CanvasItem
	if panel != null:
		panel.visible = false



func _restyle_top_bar() -> void:
	# Reposition to full-width unified top bar (Civ 6 style)
	resource_panel.offset_left = 0.0
	resource_panel.offset_top = 0.0
	resource_panel.offset_right = 1920.0
	resource_panel.offset_bottom = 48.0

	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.08, 0.09, 0.12, 0.95)
	bar_style.border_color = Color(0.30, 0.35, 0.42, 0.65)
	bar_style.border_width_bottom = 2
	resource_panel.add_theme_stylebox_override("panel", bar_style)

	var hbox: HBoxContainer = resource_panel.get_node("HBox") as HBoxContainer
	if hbox:
		hbox.add_theme_constant_override("separation", 24)
		# Separator between faction label and resources
		var sep := VSeparator.new()
		sep.name = "TopBarSep"
		hbox.add_child(sep)
		hbox.move_child(sep, 1)

		# Extra spacing between gold and wood
		var gold_vbox: VBoxContainer = hbox.get_node_or_null("ResGold") as VBoxContainer
		if gold_vbox:
			gold_vbox.add_theme_constant_override("separation", 30)

		var spacer := Control.new()
		spacer.name = "TopBarSpacer"
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(spacer)

		turn_label.reparent(hbox)
		turn_label.add_theme_font_size_override("font_size", 14)
		turn_label.visible = false


func _init_hover_info_card() -> void:
	debug_label.visible = false
	hover_info_card = TextureRect.new()
	hover_info_card.name = "HoverInfoCard"
	hover_info_card.texture = load("res://assets/小信息.png")
	hover_info_card.position = Vector2((1920.0 - 180.0) * 0.5, 58.0)
	hover_info_card.size = Vector2(180.0, 52.0)
	hover_info_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hover_info_card.stretch_mode = TextureRect.STRETCH_SCALE
	hover_info_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_info_card.z_index = 120
	hover_info_card.visible = false
	$UI.add_child(hover_info_card)

	hover_info_label = Label.new()
	hover_info_label.name = "HoverInfoLabel"
	hover_info_label.position = Vector2(16.0, 8.0)
	hover_info_label.size = Vector2(144.0, 26.0)
	hover_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hover_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hover_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hover_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_info_label.add_theme_font_size_override("font_size", 12)
	hover_info_label.add_theme_color_override("font_color", Color(0.28, 0.16, 0.06, 1.0))
	hover_info_label.add_theme_color_override("font_shadow_color", Color(1.0, 0.92, 0.72, 0.45))
	hover_info_label.add_theme_constant_override("shadow_offset_x", 1)
	hover_info_label.add_theme_constant_override("shadow_offset_y", 1)
	hover_info_card.add_child(hover_info_label)
	_sync_hover_info_card(true)


func _sync_hover_info_card(force: bool = false) -> void:
	if hover_info_card == null or hover_info_label == null or debug_label == null:
		return
	var text: String = debug_label.text.strip_edges()
	if not force and text == _last_hover_info_text:
		return
	_last_hover_info_text = text
	hover_info_label.text = text
	hover_info_card.visible = not text.is_empty()


func _on_building_selected(data: BuildingData) -> void:
	building_manager.start_placement(data, turn_manager.current_player)


func _on_recruit_panel_requested(building_id: int, building_name: String, options: Array, queue: Array) -> void:
	recruit_ui.show_panel(building_id, building_name, options, queue)


func _on_recruit_panel_closed() -> void:
	recruit_ui.hide_panel()


func _on_recruit_queue_changed(building_id: int, queue: Array) -> void:
	recruit_ui.update_queue(building_id, queue)


func _on_recruit_requested(building_id: int, unit_template_id: String, count: int) -> void:
	building_manager.request_recruitment(building_id, unit_template_id, count)


func _on_fog_updated(player: int) -> void:
	var territory_mgr = $GameBoard/TerritoryManager2D
	territory_mgr.recalc_territory(player)
	resource_manager.queue_redraw()
	building_manager.queue_redraw()
	unit_manager.queue_redraw()
	neutral_unit_manager.queue_redraw()


func _on_resource_hovered(text: String) -> void:
	debug_label.text = text
	_sync_hover_info_card(true)


# 三阵营出生点坐标（领土系统 seed）
const FACTION_SPAWNS := [
	{ "player": 0, "th_pos": Vector2i(35, 13), "th_origin": Vector2i(34, 11) },
	{ "player": 1, "th_pos": Vector2i(35, 43), "th_origin": Vector2i(34, 41) },
	{ "player": 2, "th_pos": Vector2i(62, 35), "th_origin": Vector2i(61, 33) },
]


func _place_initial_buildings() -> void:
	## 每阵营：1 座主城（2×2）+ 1 座特色资源建筑
	## 精灵→伐木场，矮人→采石场，兽人→农场
	var faction_buildings := {
		0: BuildingData.infra_lumber_camp(),
		1: BuildingData.infra_quarry(),
		2: BuildingData.infra_farm(),
	}
	for s in FACTION_SPAWNS:
		var p: int = s["player"]
		var origin: Vector2i = s["th_origin"]

		# 主城
		var th_placed: bool = building_manager.place_building(BuildingData.town_hall(), p, origin)
		print("[建筑] 阵营 %d 主城放置: %s at %s" % [p, str(th_placed), str(origin)])

		# 特色资源建筑：在主城旁尝试偏移位置放置
		var infra: BuildingData = faction_buildings[p]
		var offsets := [
			Vector2i(-1, 0), Vector2i(2, 0),
			Vector2i(0, -1),
			Vector2i(-1, 1), Vector2i(2, 1),
			Vector2i(-1, -1), Vector2i(2, -1),
		]
		var infra_placed: bool = false
		for off in offsets:
			var cand := Vector2i(origin.x + off.x, origin.y + off.y)
			if building_manager.place_building(infra, p, cand):
				infra_placed = true
				print("[建筑] 阵营 %d %s 放置: true at %s" % [p, infra.name, str(cand)])
				break
		if not infra_placed:
			print("[建筑] 阵营 %d %s 放置失败!" % [p, infra.name])


func _on_round_started(round: int) -> void:
	var p: int = turn_manager.current_player
	turn_label.text = "第 %d 回合 · %s" % [round, GameCatalog.faction_name(p)]
	turn_label.label_settings = _make_label_settings(GameCatalog.faction_color(p))
	_update_stage_label(round)


func _on_player_turn_started(player: int) -> void:
	turn_label.text = "第 %d 回合 · %s" % [turn_manager.round_number, GameCatalog.faction_name(player)]
	turn_label.label_settings = _make_label_settings(GameCatalog.faction_color(player))
	debug_label.text = _format_ap_debug_text(player)
	_update_ap_status_label(player)
	_update_score_label(player)
	resource_tracker.update_display(player)
	_update_progress_bars(player)
	_update_wall_blueprint_ui(player, "")
	# 海克斯商队触发检查
	if _goblin_market_round == turn_manager.round_number:
		if goblin_hex_service != null and goblin_hex_panel != null:
			if bool(goblin_hex_service.call("can_player_choose", player, turn_manager.round_number)):
				goblin_hex_panel.call("show_hex", player, turn_manager.round_number)
	building_ui.refresh(player)
	_selected_unit_skill_view = {}
	_refresh_unit_skill_bar()


func _on_round_ended(round: int) -> void:
	var fog_mgr: Node = $GameBoard/FogOfWar2D
	if fog_mgr != null and fog_mgr.has_method("tick_magic_fog_round"):
		fog_mgr.call("tick_magic_fog_round")
	turn_label.text = "第 %d 回合结束" % round
	debug_label.text = "结算中..."


func _on_ap_changed(player: int, ap: int) -> void:
	var display_player: int = _get_display_player()
	debug_label.text = _format_ap_debug_text(display_player)
	_update_ap_status_label(display_player)
	_update_wall_blueprint_ui(display_player, "")
	resource_tracker.update_display(display_player)
	building_ui.refresh(display_player)
	_refresh_unit_skill_bar()


func _init_resource_labels() -> void:
	## 将 UI 面板中的 Label 引用传给 resource_tracker
	var panel: Panel = resource_panel
	if not panel:
		return
	var hbox: HBoxContainer = panel.get_node("HBox") as HBoxContainer
	var key_map := {"Gold": "gold", "Wood": "wood", "Stone": "stone", "Food": "food", "Iron": "iron", "MagicDust": "magic_dust", "AncientWood": "ancient_wood", "GoldOre": "gold_ore", "Mithril": "mithril", "Steel": "steel", "DragonBlood": "dragon_blood", "DragonCrystal": "dragon_crystal"}
	for node_name in key_map:
		var rkey: String = str(key_map[node_name])
		# Remove pre-existing label from scene file so we can recreate with icon
		var old_label: Label = hbox.get_node_or_null("Label" + node_name) as Label
		if old_label:
			old_label.get_parent().remove_child(old_label)
			old_label.queue_free()
		var label: Label = null
		var res_icon_map := {
			"gold": "res://assets/icon_gold.png",
			"wood": "res://assets/icon_wood.png",
			"stone": "res://assets/icon_stone.png",
			"food": "res://assets/icon_food.png",
			"iron": "res://assets/icon_iron.png",
			"magic_dust": "res://assets/icon_magic_dust.png",
			"ancient_wood": "res://assets/icon_ancient_wood.png",
			"mithril": "res://assets/icon_mithril.png",
			"steel": "res://assets/icon_steel.png",
			"dragon_blood": "res://assets/icon_dragon_blood.png",
			"dragon_crystal": "res://assets/icon_dragon_crystal.png",
		}
		if res_icon_map.has(rkey):
				# VBox with icon+name on top, progress bar below
				var vbox := VBoxContainer.new()
				vbox.name = "Res" + node_name
				vbox.add_theme_constant_override("separation", 1)
				var top_row := HBoxContainer.new()
				top_row.add_theme_constant_override("separation", 4)
				var icon := TextureRect.new()
				icon.texture = load(res_icon_map[rkey])
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.custom_minimum_size = Vector2(26, 26)
				icon.size = Vector2(26, 26)
				icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				if rkey == "food":
					icon.scale = Vector2(1.2, 1.2)
				top_row.add_child(icon)
				label = Label.new()
				label.name = "Label" + node_name
				label.add_theme_font_size_override("font_size", 15)
				label.offset_top = -2
				top_row.add_child(label)
				vbox.add_child(top_row)
				if rkey != "gold":
					var progress := ProgressBar.new()
					progress.name = "Progress" + node_name
					progress.custom_minimum_size = Vector2(72, 8)
					progress.show_percentage = false
					var bar_bg := StyleBoxFlat.new()
					bar_bg.bg_color = Color(0.22, 0.22, 0.25, 0.85)
					bar_bg.set_corner_radius_all(2)
					progress.add_theme_stylebox_override("background", bar_bg)
					var bar_fill := StyleBoxFlat.new()
					var progress_colors := {
						"wood": Color(0.65, 0.88, 0.52, 1.0),
						"stone": Color(0.75, 0.73, 0.68, 1.0),
						"food": Color(1.0, 0.72, 0.38, 1.0),
						"iron": Color(0.70, 0.80, 0.90, 1.0),
						"magic_dust": Color(0.82, 0.60, 0.98, 1.0),
						"ancient_wood": Color(0.60, 0.45, 0.75, 1.0),
						"mithril": Color(0.65, 0.85, 0.90, 1.0),
						"steel": Color(0.70, 0.72, 0.78, 1.0),
						"dragon_blood": Color(0.90, 0.25, 0.20, 1.0),
						"dragon_crystal": Color(0.85, 0.35, 0.85, 1.0),
					}
					bar_fill.bg_color = progress_colors.get(rkey, Color(0.7, 0.7, 0.7, 1.0))
					bar_fill.set_corner_radius_all(2)
					progress.add_theme_stylebox_override("fill", bar_fill)
					vbox.add_child(progress)
					_resource_progress_bars[rkey] = progress
				hbox.add_child(vbox)
		else:
			label = Label.new()
			label.name = "Label" + node_name
			label.add_theme_font_size_override("font_size", 15)
			hbox.add_child(label)
		# Frostpunk-style: color-coded resource text
		var res_colors := {
			"gold": Color(0.95, 0.78, 0.20),
			"wood": Color(0.55, 0.78, 0.42),
			"stone": Color(0.72, 0.70, 0.65),
			"food": Color(0.92, 0.62, 0.28),
			"iron": Color(0.68, 0.75, 0.82),
			"magic_dust": Color(0.72, 0.50, 0.88),
			"ancient_wood": Color(0.62, 0.48, 0.78),
			"mithril": Color(0.55, 0.85, 0.92),
			"steel": Color(0.68, 0.70, 0.78),
			"dragon_blood": Color(0.95, 0.30, 0.25),
			"dragon_crystal": Color(0.88, 0.40, 0.88),
		}
		label.add_theme_color_override("font_color", res_colors.get(rkey, Color.WHITE))
		resource_tracker.set_resource_label(rkey, label)
	resource_tracker.set_faction_label(panel.get_node("HBox/FactionLabel") as Label)

	# hide labels not in top bar visible set
	var visible_keys := ["gold", "wood", "stone", "food", "iron", "magic_dust", "ancient_wood", "mithril", "steel", "dragon_blood", "dragon_crystal"]
	var all_extra := ["AncientWood", "GoldOre", "Mithril", "Steel"]
	for node_name in all_extra:
		var lbl: Label = hbox.get_node_or_null("Label" + node_name) as Label
		if lbl:
			lbl.visible = false


func _update_progress_bars(player: int) -> void:
	for rkey in _resource_progress_bars:
		var cur: int = resource_tracker.get_resource(player, rkey)
		var cap: int = resource_tracker.get_resource_cap(player, rkey)
		var bar: ProgressBar = _resource_progress_bars[rkey]
		bar.max_value = float(maxi(cap, 1))
		bar.value = float(clampi(cur, 0, cap))

func _on_resources_updated(_player: int) -> void:
	var cp: int = _get_display_player()
	resource_tracker.update_display(cp)
	_update_progress_bars(cp)


func _get_display_player() -> int:
	if turn_manager == null:
		return 0
	if turn_manager.get("view_player") != null:
		return int(turn_manager.get("view_player"))
	return int(turn_manager.current_player)


func _init_creative_mode_button() -> void:
	creative_mode_button = Button.new()
	creative_mode_button.name = "CreativeModeButton"
	creative_mode_button.toggle_mode = true
	creative_mode_button.position = Vector2(16.0, 54.0)
	creative_mode_button.size = Vector2(132.0, 30.0)
	creative_mode_button.focus_mode = Control.FOCUS_NONE
	creative_mode_button.z_index = 95
	creative_mode_button.tooltip_text = "开启后资源与 AP 不会被消耗"
	creative_mode_button.toggled.connect(_on_creative_mode_toggled)
	$UI.add_child(creative_mode_button)
	_update_creative_mode_button()


func _on_creative_mode_toggled(enabled: bool) -> void:
	_creative_mode_enabled = enabled
	if turn_manager != null and turn_manager.has_method("set_creative_mode_enabled"):
		turn_manager.call("set_creative_mode_enabled", enabled)
	if resource_tracker != null and resource_tracker.has_method("set_creative_mode_enabled"):
		resource_tracker.call("set_creative_mode_enabled", enabled)
	_update_creative_mode_button()
	var cp: int = turn_manager.current_player
	_update_ap_status_label(cp)
	resource_tracker.update_display(cp)
	building_ui.refresh(cp)
	debug_label.text = "创造模式已开启：资源与 AP 不消耗" if enabled else _format_ap_debug_text(cp)


func _update_creative_mode_button() -> void:
	if creative_mode_button == null:
		return
	creative_mode_button.text = "创造模式: 开" if _creative_mode_enabled else "创造模式: 关"
	creative_mode_button.modulate = Color(0.72, 1.0, 0.72, 1.0) if _creative_mode_enabled else Color.WHITE


func _format_ap_debug_text(player: int) -> String:
	if _creative_mode_enabled:
		return "%s (AP: ∞)" % GameCatalog.faction_name(player)
	return "%s (AP: %d)" % [GameCatalog.faction_name(player), turn_manager.get_ap(player)]


func _init_achievement_service() -> void:
	achievement_service = AchievementServiceScript.new()
	achievement_service.name = "AchievementService"
	$GameBoard.add_child(achievement_service)
	achievement_service.setup(resource_tracker, building_manager, unit_manager, neutral_unit_manager)
	achievement_service.achievement_completed.connect(_on_achievement_completed)


func _init_technology_service() -> void:
	technology_service = TechnologyServiceScript.new()
	technology_service.name = "TechnologyService"
	$GameBoard.add_child(technology_service)
	technology_service.setup(achievement_service, civilization_rules)
	if building_manager != null and building_manager.has_method("set_technology_service"):
		building_manager.set_technology_service(technology_service)
	if resource_tracker != null and resource_tracker.has_method("set_technology_service"):
		resource_tracker.set_technology_service(technology_service)


func _init_goblin_hex_service() -> void:
	goblin_hex_service = GoblinHexServiceScript.new()
	goblin_hex_service.name = "GoblinHexService"
	$GameBoard.add_child(goblin_hex_service)
	if goblin_hex_service.has_method("setup"):
		goblin_hex_service.call("setup", resource_tracker, turn_manager, technology_service)
	if goblin_hex_service.has_signal("card_selected"):
		goblin_hex_service.card_selected.connect(_on_goblin_hex_card_selected)


func _init_goblin_hex_panel() -> void:
	goblin_hex_panel = GoblinHexPanelScript.new()
	goblin_hex_panel.name = "GoblinHexPanel"
	$UI.add_child(goblin_hex_panel)
	goblin_hex_panel.setup(goblin_hex_service)
	goblin_hex_panel.hide()


func _init_victory_service() -> void:
	victory_service = VictoryServiceScript.new()
	victory_service.name = "VictoryService"
	$GameBoard.add_child(victory_service)
	victory_service.setup(turn_manager, building_manager, unit_manager, resource_tracker, technology_service)
	victory_service.conquest_victory_declared.connect(_on_conquest_victory_declared)
	victory_service.final_scoring_started.connect(_on_final_scoring_started)


func _on_conquest_victory_declared(winner: int, _reason: String) -> void:
	current_state = GameState.GAME_OVER
	var text := "\u5f81\u670d\u80dc\u5229\uff1a%s" % GameCatalog.faction_name(winner)
	debug_label.text = text
	turn_label.text = text
	_show_game_over_text(text)


func _on_final_scoring_started(scores: Array, winner: int) -> void:
	current_state = GameState.GAME_OVER
	var lines: PackedStringArray = []
	lines.append("\u9636\u6bb5\u7ed3\u7b97\uff1a%s \u80dc\u51fa" % GameCatalog.faction_name(winner))
	for item in scores:
		var entry: Dictionary = item
		lines.append("%s: %d" % [GameCatalog.faction_name(int(entry.get("player", -1))), int(entry.get("score", 0))])
	var text := "\n".join(lines)
	debug_label.text = lines[0]
	turn_label.text = lines[0]
	_show_game_over_text(text)


func _on_achievement_completed(player: int, _achievement_id: String, title: String) -> void:
	if player == turn_manager.current_player:
		debug_label.text = "成就达成：%s｜科技点 %d" % [title, achievement_service.get_tech_points(player)]


func _init_achievement_tree_panel() -> void:
	achievement_tree_panel = AchievementTreePanelScript.new()
	achievement_tree_panel.name = "AchievementTreePanel"
	achievement_tree_panel.position = Vector2(48.0, 64.0)
	achievement_tree_panel.size = Vector2(1824.0, 936.0)
	achievement_tree_panel.visible = false
	achievement_tree_panel.z_index = 100
	$UI.add_child(achievement_tree_panel)
	achievement_tree_panel.setup(achievement_service, turn_manager)


func _init_achievement_tree_button() -> void:
	var acontainer := VBoxContainer.new()
	acontainer.name = "AchievementTreeContainer"
	acontainer.position = Vector2(16.0, 168.0)
	acontainer.z_index = 90
	achievement_tree_button = Button.new()
	achievement_tree_button.name = "AchievementTreeButton"
	achievement_tree_button.icon = load("res://assets/icon_achievement.png")
	achievement_tree_button.expand_icon = true
	achievement_tree_button.custom_minimum_size = Vector2(56.0, 56.0)
	achievement_tree_button.size = Vector2(56.0, 56.0)
	var abg := StyleBoxFlat.new()
	abg.bg_color = Color(0.08, 0.08, 0.10, 0.85)
	abg.set_corner_radius_all(28)
	achievement_tree_button.add_theme_stylebox_override("normal", abg)
	var ahover := StyleBoxFlat.new()
	ahover.bg_color = Color(0.15, 0.15, 0.18, 0.9)
	ahover.set_corner_radius_all(28)
	achievement_tree_button.add_theme_stylebox_override("hover", ahover)
	var apressed := StyleBoxFlat.new()
	apressed.bg_color = Color(0.35, 0.30, 0.22, 0.95)
	apressed.set_corner_radius_all(28)
	apressed.border_width_bottom = 2
	apressed.border_color = Color(0.82, 0.72, 0.38, 0.6)
	achievement_tree_button.add_theme_stylebox_override("pressed", apressed)
	achievement_tree_button.focus_mode = Control.FOCUS_NONE
	achievement_tree_button.pressed.connect(_on_achievement_tree_button_pressed)
	acontainer.add_child(achievement_tree_button)
	var alabel := Label.new()
	alabel.name = "AchievementTreeLabel"
	alabel.text = "\u6210\u5c31\u6811"
	alabel.add_theme_font_size_override("font_size", 13)
	alabel.add_theme_color_override("font_color", Color(0.82, 0.78, 0.65))
	alabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	acontainer.add_child(alabel)
	$UI.add_child(acontainer)


func _on_achievement_tree_button_pressed() -> void:
	if achievement_tree_panel == null:
		return
	if technology_tree_panel != null:
		technology_tree_panel.visible = false
	if score_rule_panel != null:
		score_rule_panel.visible = false
	if civilization_route_panel != null:
		civilization_route_panel.visible = false
	achievement_tree_panel.visible = true
	achievement_tree_panel.queue_redraw()


func _init_technology_tree_panel() -> void:
	technology_tree_panel = TechnologyTreePanelScript.new()
	technology_tree_panel.name = "TechnologyTreePanel"
	technology_tree_panel.position = Vector2(48.0, 64.0)
	technology_tree_panel.size = Vector2(1824.0, 936.0)
	technology_tree_panel.visible = false
	technology_tree_panel.z_index = 101
	$UI.add_child(technology_tree_panel)
	technology_tree_panel.setup(technology_service, achievement_service, turn_manager)


func _init_technology_tree_button() -> void:
	var tcontainer := VBoxContainer.new()
	tcontainer.name = "TechnologyTreeContainer"
	tcontainer.position = Vector2(92.0, 168.0)
	tcontainer.z_index = 90
	technology_tree_button = Button.new()
	technology_tree_button.name = "TechnologyTreeButton"
	technology_tree_button.icon = load("res://assets/icon_technology.png")
	technology_tree_button.expand_icon = true
	technology_tree_button.custom_minimum_size = Vector2(56.0, 56.0)
	technology_tree_button.size = Vector2(56.0, 56.0)
	var tbg := StyleBoxFlat.new()
	tbg.bg_color = Color(0.08, 0.08, 0.10, 0.85)
	tbg.set_corner_radius_all(28)
	technology_tree_button.add_theme_stylebox_override("normal", tbg)
	var thover := StyleBoxFlat.new()
	thover.bg_color = Color(0.15, 0.15, 0.18, 0.9)
	thover.set_corner_radius_all(28)
	technology_tree_button.add_theme_stylebox_override("hover", thover)
	var tpressed := StyleBoxFlat.new()
	tpressed.bg_color = Color(0.35, 0.30, 0.22, 0.95)
	tpressed.set_corner_radius_all(28)
	tpressed.border_width_bottom = 2
	tpressed.border_color = Color(0.82, 0.72, 0.38, 0.6)
	technology_tree_button.add_theme_stylebox_override("pressed", tpressed)
	technology_tree_button.focus_mode = Control.FOCUS_NONE
	technology_tree_button.pressed.connect(_on_technology_tree_button_pressed)
	tcontainer.add_child(technology_tree_button)
	var tlabel := Label.new()
	tlabel.name = "TechnologyTreeLabel"
	tlabel.text = "\u79d1\u6280\u6811"
	tlabel.add_theme_font_size_override("font_size", 13)
	tlabel.add_theme_color_override("font_color", Color(0.82, 0.78, 0.65))
	tlabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tcontainer.add_child(tlabel)
	$UI.add_child(tcontainer)


func _on_technology_tree_button_pressed() -> void:
	if technology_tree_panel == null:
		return
	if achievement_tree_panel != null:
		achievement_tree_panel.visible = false
	if score_rule_panel != null:
		score_rule_panel.visible = false
	if civilization_route_panel != null:
		civilization_route_panel.visible = false
	technology_tree_panel.visible = true
	technology_tree_panel.queue_redraw()


func _init_score_rule_panel() -> void:
	score_rule_panel = ScoreRulePanelScript.new()
	score_rule_panel.name = "ScoreRulePanel"
	score_rule_panel.position = Vector2(360.0, 120.0)
	score_rule_panel.size = Vector2(900.0, 760.0)
	score_rule_panel.visible = false
	score_rule_panel.z_index = 102
	$UI.add_child(score_rule_panel)


func _init_score_rule_button() -> void:
	score_rule_button = Button.new()
	score_rule_button.name = "ScoreRuleButton"
	score_rule_button.text = "\u8ba1\u5206"
	score_rule_button.position = Vector2(16.0, 256.0)
	score_rule_button.size = Vector2(56.0, 30.0)
	score_rule_button.focus_mode = Control.FOCUS_NONE
	score_rule_button.z_index = 90
	score_rule_button.pressed.connect(_on_score_rule_button_pressed)
	$UI.add_child(score_rule_button)


func _on_score_rule_button_pressed() -> void:
	if score_rule_panel == null:
		return
	if achievement_tree_panel != null:
		achievement_tree_panel.visible = false
	if technology_tree_panel != null:
		technology_tree_panel.visible = false
	if civilization_route_panel != null:
		civilization_route_panel.visible = false
	score_rule_panel.visible = true
	score_rule_panel.queue_redraw()


func _init_civilization_route_panel() -> void:
	civilization_route_panel = CivilizationRoutePanelScript.new()
	civilization_route_panel.name = "CivilizationRoutePanel"
	civilization_route_panel.position = Vector2(320.0, 110.0)
	civilization_route_panel.size = Vector2(1040.0, 760.0)
	civilization_route_panel.visible = false
	civilization_route_panel.z_index = 103
	$UI.add_child(civilization_route_panel)
	civilization_route_panel.setup(civilization_rules, turn_manager)


func _init_civilization_route_button() -> void:
	civilization_route_button = Button.new()
	civilization_route_button.name = "CivilizationRouteButton"
	civilization_route_button.text = "\u8def\u7ebf"
	civilization_route_button.position = Vector2(16.0, 291.0)
	civilization_route_button.size = Vector2(56.0, 30.0)
	civilization_route_button.focus_mode = Control.FOCUS_NONE
	civilization_route_button.z_index = 90
	civilization_route_button.pressed.connect(_on_civilization_route_button_pressed)
	$UI.add_child(civilization_route_button)


func _on_civilization_route_button_pressed() -> void:
	if civilization_route_panel == null:
		return
	if achievement_tree_panel != null:
		achievement_tree_panel.visible = false
	if technology_tree_panel != null:
		technology_tree_panel.visible = false
	if score_rule_panel != null:
		score_rule_panel.visible = false
	civilization_route_panel.visible = true
	civilization_route_panel.queue_redraw()


func _init_wall_blueprint_ui() -> void:
	wall_blueprint_button = Button.new()
	wall_blueprint_button.name = "WallBlueprintButton"
	wall_blueprint_button.text = "\u57ce\u5899"
	wall_blueprint_button.toggle_mode = true
	wall_blueprint_button.position = Vector2(384.0, 176.0)
	wall_blueprint_button.size = Vector2(76.0, 30.0)
	wall_blueprint_button.focus_mode = Control.FOCUS_NONE
	wall_blueprint_button.z_index = 90
	wall_blueprint_button.tooltip_text = "\u77ee\u4eba\u56de\u5408\uff1a\u8fde\u63a5\u4e24\u5ea7\u5efa\u7b51\u89c4\u5212\u57ce\u5899"
	wall_blueprint_button.pressed.connect(_on_wall_blueprint_button_pressed)
	$UI.add_child(wall_blueprint_button)

	wall_blueprint_status_label = Label.new()
	wall_blueprint_status_label.name = "WallBlueprintStatusLabel"
	wall_blueprint_status_label.position = Vector2(16.0, 214.0)
	wall_blueprint_status_label.size = Vector2(520.0, 48.0)
	wall_blueprint_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wall_blueprint_status_label.z_index = 90
	wall_blueprint_status_label.add_theme_font_size_override("font_size", 13)
	wall_blueprint_status_label.add_theme_color_override("font_color", Color(0.62, 0.86, 1.0, 0.95))
	wall_blueprint_status_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	wall_blueprint_status_label.add_theme_constant_override("shadow_offset_x", 1)
	wall_blueprint_status_label.add_theme_constant_override("shadow_offset_y", 1)
	$UI.add_child(wall_blueprint_status_label)
	_update_wall_blueprint_ui(turn_manager.current_player, "")


func _on_wall_blueprint_button_pressed() -> void:
	if wall_blueprint_manager == null:
		return
	if turn_manager.current_player != 1:
		debug_label.text = "\u53ea\u6709\u77ee\u4eba\u56de\u5408\u53ef\u4ee5\u89c4\u5212\u57ce\u5899"
		return
	if wall_blueprint_manager.has_method("is_wall_mode_active") and bool(wall_blueprint_manager.call("is_wall_mode_active")):
		wall_blueprint_manager.call("cancel_wall_blueprint")
	else:
		wall_blueprint_manager.call("start_wall_anchor_selection")


func _on_wall_mode_changed(active: bool, message: String) -> void:
	_update_wall_blueprint_ui(turn_manager.current_player, message)
	if wall_blueprint_button != null:
		wall_blueprint_button.button_pressed = active
	_refresh_unit_skill_bar()


func _on_wall_preview_changed(message: String, valid: bool, cells: int, stone_cost: int) -> void:
	_wall_preview_valid = valid
	_wall_preview_cells = cells
	_wall_preview_stone_cost = stone_cost
	var state_text: String = "\u672a\u5b8c\u6210"
	if valid:
		state_text = "\u53ef\u786e\u8ba4"
	var full_message: String = message
	if cells > 0:
		full_message = "\u57ce\u5899\u84dd\u56fe %d\u683c | \u77f3\u6599 %d | %s" % [cells, stone_cost, state_text]
	_update_wall_blueprint_ui(turn_manager.current_player, full_message)
	_refresh_unit_skill_bar()


func _update_wall_blueprint_ui(player: int, message: String) -> void:
	if wall_blueprint_button != null:
		var is_dwarf := player == 1
		wall_blueprint_button.disabled = not is_dwarf
		wall_blueprint_button.visible = false
		wall_blueprint_button.modulate = Color(0.72, 0.86, 1.0, 1.0) if is_dwarf else Color(0.45, 0.45, 0.45, 0.72)
	if wall_blueprint_status_label == null:
		return
	if player != 1:
		wall_blueprint_status_label.text = ""
		return
	if message.is_empty():
		wall_blueprint_status_label.text = "\u57ce\u5899\uff1a\u4f7f\u7528\u53f3\u4e0b\u89d2\u6280\u80fd\u6309\u94ae\u8fdb\u5165\u84dd\u56fe\u6a21\u5f0f"
	else:
		wall_blueprint_status_label.text = message


func _init_stage_event_service() -> void:
	stage_event_service = StageEventServiceScript.new()
	stage_event_service.name = "StageEventService"
	$GameBoard.add_child(stage_event_service)
	stage_event_service.stage_started.connect(_on_stage_started)
	stage_event_service.goblin_market_started.connect(_on_goblin_market_started)
	stage_event_service.set_turn_manager(turn_manager)


func _on_stage_started(stage: int, round_number: int) -> void:
	debug_label.text = "第 %d 阶段开始" % stage
	print("[阶段] 第 %d 阶段开始，回合 %d" % [stage, round_number])


func _on_goblin_market_started(stage: int, round_number: int) -> void:
	_goblin_market_round = round_number
	var rarity := ""
	if goblin_hex_service != null:
		rarity = str(goblin_hex_service.call("prepare_round", round_number))
	debug_label.text = "第 %d 阶段：哥布林海克斯出现（%s）" % [stage, rarity]
	print("[阶段事件] 哥布林海克斯出现：阶段 %d，回合 %d，品质 %s" % [stage, round_number, rarity])


func _on_goblin_hex_card_selected(player: int, round_number: int, card: Dictionary) -> void:
	var card_name: String = str(card.get("name", ""))
	var rarity_name: String = str(card.get("rarity_name", ""))
	debug_label.text = "%s 选择了%s海克斯：%s" % [GameCatalog.faction_name(player), rarity_name, card_name]
	print("[哥布林海克斯] 回合 %d 阵营 %d 选择 %s %s" % [round_number, player, rarity_name, card_name])


func _init_stage_label() -> void:
	stage_label = Label.new()
	stage_label.name = "StageLabel"
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_label.add_theme_font_size_override("font_size", 14)
	stage_label.add_theme_color_override("font_color", Color.WHITE)
	stage_label.position = Vector2(1700, 12)
	stage_label.size = Vector2(200, 24)
	$UI.add_child(stage_label)
	_update_stage_label(maxi(turn_manager.round_number, 1))


func _init_game_over_label() -> void:
	game_over_label = Label.new()
	game_over_label.name = "GameOverLabel"
	game_over_label.position = Vector2(700, 390)
	game_over_label.size = Vector2(520, 180)
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.visible = false
	game_over_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_over_label.add_theme_font_size_override("font_size", 28)
	game_over_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.58))
	game_over_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	game_over_label.add_theme_constant_override("shadow_offset_x", 2)
	game_over_label.add_theme_constant_override("shadow_offset_y", 2)
	$UI.add_child(game_over_label)


func _show_game_over_text(text: String) -> void:
	if game_over_label == null:
		return
	game_over_label.text = text
	game_over_label.visible = true


func _update_stage_label(round_number: int) -> void:
	if not stage_label:
		return
	var stage: int = GameStageRulesScript.get_stage_for_round(round_number)
	var round_in_stage: int = GameStageRulesScript.get_round_in_stage(round_number)
	stage_label.text = "第%d阶段 第%d/%d回合" % [
		stage,
		round_in_stage,
		GameStageRulesScript.ROUNDS_PER_STAGE,
	]


func _init_ap_status_label() -> void:
	ap_status_label = Label.new()
	ap_status_label.name = "APStatusLabel"
	ap_status_label.position = Vector2(1470, 12)
	ap_status_label.size = Vector2(100, 24)
	ap_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ap_status_label.add_theme_font_size_override("font_size", 14)
	ap_status_label.add_theme_color_override("font_color", Color.WHITE)
	ap_status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	ap_status_label.add_theme_constant_override("shadow_offset_x", 1)
	ap_status_label.add_theme_constant_override("shadow_offset_y", 1)
	$UI.add_child(ap_status_label)
	_update_ap_status_label(turn_manager.current_player)


func _update_ap_status_label(player: int) -> void:
	if not ap_status_label:
		return
	# white text for top bar
	if _creative_mode_enabled:
		ap_status_label.text = "AP:∞"
		return
	ap_status_label.text = "AP:%d/%d" % [turn_manager.get_ap(player), turn_manager.AP_MAX]


func _init_score_label() -> void:
	score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.position = Vector2(1580, 12)
	score_label.size = Vector2(110, 24)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_label.add_theme_font_size_override("font_size", 14)
	score_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.58))
	score_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	score_label.add_theme_constant_override("shadow_offset_x", 1)
	score_label.add_theme_constant_override("shadow_offset_y", 1)
	$UI.add_child(score_label)
	_update_score_label(turn_manager.current_player)


func _update_score_label(player: int) -> void:
	if not score_label or not victory_service:
		return
	var scores: Array = victory_service.calculate_scores()
	if player >= 0 and player < scores.size():
		var entry: Dictionary = scores[player]
		score_label.text = "计分: %d" % int(entry.get("score", 0))


func _init_zoom_status_label() -> void:
	zoom_status_label = Label.new()
	zoom_status_label.name = "ZoomStatusLabel"
	zoom_status_label.position = Vector2(16.0, 92.0)
	zoom_status_label.size = Vector2(160.0, 28.0)
	zoom_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zoom_status_label.z_index = 95
	zoom_status_label.add_theme_font_size_override("font_size", 16)
	zoom_status_label.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0))
	zoom_status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	zoom_status_label.add_theme_constant_override("shadow_offset_x", 1)
	zoom_status_label.add_theme_constant_override("shadow_offset_y", 1)
	$UI.add_child(zoom_status_label)
	_update_zoom_status_label()


func _update_zoom_status_label() -> void:
	if zoom_status_label == null or camera == null:
		return
	var zoom_percent := int(roundf(camera.zoom.x * 100.0))
	zoom_status_label.text = "Zoom: %d%%" % zoom_percent


func _make_label_settings(color: Color) -> LabelSettings:
	var s := LabelSettings.new()
	s.font_size = 22
	s.font_color = color
	s.outline_size = 2
	s.outline_color = Color(0, 0, 0, 0.6)
	return s


func _init_unit_info_panel() -> void:
	var panel_script := preload("res://scripts/unit_info_panel.gd")
	var panel := Control.new()
	panel.name = "UnitInfoPanel"
	panel.script = panel_script
	$UI.add_child(panel)

	unit_manager.unit_selected.connect(panel.show_unit)
	unit_manager.selection_cleared.connect(panel.hide_panel)
	unit_manager.unit_selected.connect(_on_unit_selected_for_skill_bar)
	unit_manager.selection_cleared.connect(_on_unit_selection_cleared_for_skill_bar)
	if panel.has_signal("form_warband_requested"):
		panel.form_warband_requested.connect(unit_manager.request_form_warband)
	if panel.has_signal("confirm_warband_requested"):
		panel.confirm_warband_requested.connect(unit_manager.confirm_warband_selection)
	if panel.has_signal("cancel_warband_requested"):
		panel.cancel_warband_requested.connect(unit_manager.cancel_warband_selection)
	if panel.has_signal("disband_warband_requested"):
		panel.disband_warband_requested.connect(unit_manager.disband_warband)

	# 中立单位选择信号
	neutral_unit_manager.neutral_selected.connect(panel.show_unit)
	neutral_unit_manager.neutral_selected.connect(_on_neutral_selected_for_skill_bar)
	neutral_unit_manager.selection_cleared.connect(panel.hide_panel)
	unit_manager.selection_cleared.connect(neutral_unit_manager.clear_selection)


func _init_unit_skill_bar() -> void:
	var panel_script: Script = preload("res://scripts/ui/unit_skill_bar.gd")
	unit_skill_bar = Control.new()
	unit_skill_bar.name = "UnitSkillBar"
	unit_skill_bar.script = panel_script
	$UI.add_child(unit_skill_bar)
	if unit_skill_bar.has_signal("skill_requested"):
		unit_skill_bar.skill_requested.connect(_on_unit_skill_requested)
	_refresh_unit_skill_bar()


func _on_unit_selected_for_skill_bar(unit: Dictionary) -> void:
	_selected_unit_skill_view = unit
	_refresh_unit_skill_bar()


func _on_unit_selection_cleared_for_skill_bar() -> void:
	_selected_unit_skill_view = {}
	_refresh_unit_skill_bar()


func _on_neutral_selected_for_skill_bar(_unit: Dictionary) -> void:
	_selected_unit_skill_view = {}
	_refresh_unit_skill_bar()


func _refresh_unit_skill_bar() -> void:
	if unit_skill_bar == null:
		return
	var skills: Array = []
	if not _selected_unit_skill_view.is_empty():
		if unit_manager != null and unit_manager.has_method("get_selected_unit_view"):
			var refreshed_view: Dictionary = unit_manager.call("get_selected_unit_view")
			if not refreshed_view.is_empty():
				_selected_unit_skill_view = refreshed_view
		var unit_skills: Array = _selected_unit_skill_view.get("skills", [])
		for skill_variant in unit_skills:
			skills.append(skill_variant)
	var wall_skills: Array = _get_wall_skill_actions()
	for wall_skill in wall_skills:
		skills.append(wall_skill)
	if unit_skill_bar.has_method("show_skills"):
		unit_skill_bar.call("show_skills", skills)


func _get_wall_skill_actions() -> Array:
	var result: Array = []
	if wall_blueprint_manager == null or turn_manager == null:
		return result
	if int(turn_manager.current_player) != 1:
		return result
	var active: bool = false
	if wall_blueprint_manager.has_method("is_wall_mode_active"):
		active = bool(wall_blueprint_manager.call("is_wall_mode_active"))
	if active:
		var confirm_status: String = "选择两个建筑"
		var confirm_reason: String = "连接两座矮人建筑后才能确认城墙蓝图。"
		if _wall_preview_valid:
			confirm_status = "石料 %d" % _wall_preview_stone_cost
			confirm_reason = "确认 %d 格城墙，消耗 %d 石料。" % [_wall_preview_cells, _wall_preview_stone_cost]
		result.append({
			"id": "wall_confirm",
			"unit_id": -1,
			"label": "确认城墙",
			"enabled": _wall_preview_valid,
			"active": true,
			"cooldown": 0,
			"status": confirm_status,
			"reason": confirm_reason,
		})
		result.append({
			"id": "wall_cancel",
			"unit_id": -1,
			"label": "取消城墙",
			"enabled": true,
			"active": true,
			"cooldown": 0,
			"status": "蓝图中",
			"reason": "取消当前城墙蓝图。",
		})
	else:
		result.append({
			"id": "wall_start",
			"unit_id": -1,
			"label": "城墙蓝图",
			"enabled": true,
			"active": false,
			"cooldown": 0,
			"status": "可用",
			"reason": "选择两座矮人建筑规划城墙。",
		})
	return result


func _on_unit_skill_requested(action_id: String, unit_id: int) -> void:
	match action_id:
		"wall_start":
			if wall_blueprint_manager != null and wall_blueprint_manager.has_method("start_wall_anchor_selection"):
				wall_blueprint_manager.call("start_wall_anchor_selection")
		"wall_confirm":
			if wall_blueprint_manager != null and wall_blueprint_manager.has_method("confirm_wall_blueprint"):
				wall_blueprint_manager.call("confirm_wall_blueprint")
		"wall_cancel":
			if wall_blueprint_manager != null and wall_blueprint_manager.has_method("cancel_wall_blueprint"):
				wall_blueprint_manager.call("cancel_wall_blueprint")
		_:
			if unit_manager != null and unit_manager.has_method("request_unit_skill"):
				unit_manager.call("request_unit_skill", action_id, unit_id)
	_refresh_unit_skill_bar()


func _init_action_preview_panel() -> void:
	var panel_script := preload("res://scripts/ui/action_preview_panel.gd")
	action_preview_panel = Control.new()
	action_preview_panel.name = "ActionPreviewPanel"
	action_preview_panel.script = panel_script
	$UI.add_child(action_preview_panel)
	unit_manager.action_preview_changed.connect(action_preview_panel.show_preview)


func _init_network_services() -> void:
	visibility_service = VisibilityServiceScript.new()
	visibility_service.name = "VisibilityService"
	$GameBoard.add_child(visibility_service)
	visibility_service.setup($GameBoard/FogOfWar2D)

	game_state_serializer = GameStateSerializerScript.new()
	game_state_serializer.name = "GameStateSerializer"
	$GameBoard.add_child(game_state_serializer)
	game_state_serializer.setup(
		turn_manager,
		unit_manager,
		building_manager,
		resource_manager,
		resource_tracker,
		visibility_service
	)

	network_game_service = NetworkGameServiceScript.new()
	network_game_service.name = "NetworkGameService"
	$GameBoard.add_child(network_game_service)
	network_game_service.setup(turn_manager, game_state_serializer)
	network_game_service.set_unit_manager(unit_manager)
	network_game_service.set_building_manager(building_manager)
	if network_game_service.has_method("set_gathering_manager"):
		network_game_service.set_gathering_manager(gathering_manager)
	if technology_service != null and network_game_service.has_method("set_technology_service"):
		network_game_service.set_technology_service(technology_service)
	if wall_blueprint_manager != null and network_game_service.has_method("set_wall_blueprint_manager"):
		network_game_service.set_wall_blueprint_manager(wall_blueprint_manager)
	if unit_manager.has_method("set_network_game_service"):
		unit_manager.set_network_game_service(network_game_service)
	if building_manager.has_method("set_network_game_service"):
		building_manager.set_network_game_service(network_game_service)
	if gathering_manager.has_method("set_network_game_service"):
		gathering_manager.set_network_game_service(network_game_service)
	if technology_service != null and technology_service.has_method("set_network_game_service"):
		technology_service.set_network_game_service(network_game_service)
	if wall_blueprint_manager != null and wall_blueprint_manager.has_method("set_network_game_service"):
		wall_blueprint_manager.set_network_game_service(network_game_service)
	network_game_service.network_status_changed.connect(_on_network_status_changed)
	network_game_service.local_faction_changed.connect(_on_network_local_faction_changed)
	network_game_service.remote_snapshot_received.connect(_on_network_snapshot_received)
	if turn_manager.has_signal("player_ready_changed"):
		turn_manager.player_ready_changed.connect(_on_player_ready_changed)
	if turn_manager.has_signal("round_action_started"):
		turn_manager.round_action_started.connect(_on_sync_round_action_started)
	if network_game_service != null:
		if GameSession.is_multiplayer_launch:
			network_game_service.adopt_existing_peer()
		else:
			if multiplayer.multiplayer_peer != null:
				multiplayer.multiplayer_peer.close()
			multiplayer.multiplayer_peer = null
			if turn_manager.has_method("set_synchronous_mode_enabled"):
				turn_manager.call("set_synchronous_mode_enabled", false)


func _init_network_ui() -> void:
	network_host_button = Button.new()
	network_host_button.name = "NetworkHostButton"
	network_host_button.text = "LAN Host"
	network_host_button.position = Vector2(468.0, 176.0)
	network_host_button.size = Vector2(96.0, 30.0)
	network_host_button.focus_mode = Control.FOCUS_NONE
	network_host_button.z_index = 90
	network_host_button.pressed.connect(_on_network_host_pressed)
	$UI.add_child(network_host_button)

	network_join_button = Button.new()
	network_join_button.name = "NetworkJoinButton"
	network_join_button.text = "LAN Join"
	network_join_button.position = Vector2(570.0, 176.0)
	network_join_button.size = Vector2(96.0, 30.0)
	network_join_button.focus_mode = Control.FOCUS_NONE
	network_join_button.z_index = 90
	network_join_button.pressed.connect(_on_network_join_pressed)
	$UI.add_child(network_join_button)

	network_address_input = LineEdit.new()
	network_address_input.name = "NetworkAddressInput"
	network_address_input.text = "127.0.0.1"
	network_address_input.placeholder_text = "Host IP"
	network_address_input.position = Vector2(672.0, 176.0)
	network_address_input.size = Vector2(142.0, 30.0)
	network_address_input.focus_mode = Control.FOCUS_CLICK
	network_address_input.z_index = 90
	$UI.add_child(network_address_input)

	network_port_input = LineEdit.new()
	network_port_input.name = "NetworkPortInput"
	network_port_input.text = "24531"
	network_port_input.placeholder_text = "Port"
	network_port_input.position = Vector2(820.0, 176.0)
	network_port_input.size = Vector2(68.0, 30.0)
	network_port_input.focus_mode = Control.FOCUS_CLICK
	network_port_input.z_index = 90
	$UI.add_child(network_port_input)

	network_ready_button = Button.new()
	network_ready_button.name = "NetworkReadyButton"
	network_ready_button.text = "End Round"
	network_ready_button.position = Vector2(894.0, 176.0)
	network_ready_button.size = Vector2(112.0, 30.0)
	network_ready_button.focus_mode = Control.FOCUS_NONE
	network_ready_button.z_index = 90
	network_ready_button.pressed.connect(_on_network_ready_pressed)
	$UI.add_child(network_ready_button)

	network_status_label = Label.new()
	network_status_label.name = "NetworkStatusLabel"
	network_status_label.position = Vector2(468.0, 214.0)
	network_status_label.size = Vector2(520.0, 24.0)
	network_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	network_status_label.z_index = 90
	network_status_label.add_theme_font_size_override("font_size", 13)
	network_status_label.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0, 0.96))
	network_status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	network_status_label.add_theme_constant_override("shadow_offset_x", 1)
	network_status_label.add_theme_constant_override("shadow_offset_y", 1)
	$UI.add_child(network_status_label)

	network_ready_label = Label.new()
	network_ready_label.name = "NetworkReadyLabel"
	network_ready_label.position = Vector2(468.0, 238.0)
	network_ready_label.size = Vector2(520.0, 24.0)
	network_ready_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	network_ready_label.z_index = 90
	network_ready_label.add_theme_font_size_override("font_size", 13)
	network_ready_label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.78, 0.96))
	network_ready_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	network_ready_label.add_theme_constant_override("shadow_offset_x", 1)
	network_ready_label.add_theme_constant_override("shadow_offset_y", 1)
	$UI.add_child(network_ready_label)
	_update_network_ready_label()




	if network_game_service != null and network_game_service.is_network_game():
		if network_host_button != null:
			network_host_button.visible = false
		if network_join_button != null:
			network_join_button.visible = false
		if network_address_input != null:
			network_address_input.visible = false
		if network_port_input != null:
			network_port_input.visible = false

func _on_network_host_pressed() -> void:
	if network_game_service != null:
		var port := _get_network_port()
		if network_game_service.host_game(port):
			_show_host_lan_addresses(port)


func _on_network_join_pressed() -> void:
	if network_game_service != null:
		var address := _get_network_address()
		var port := _get_network_port()
		network_game_service.join_game(address, port)


func _on_network_ready_pressed() -> void:
	_on_end_turn()


func _on_network_status_changed(text: String) -> void:
	if network_status_label != null:
		network_status_label.text = text
	debug_label.text = text
	_update_network_ready_label()


func _get_network_address() -> String:
	if network_address_input == null:
		return "127.0.0.1"
	var value := network_address_input.text.strip_edges()
	if value.is_empty():
		return "127.0.0.1"
	return value


func _get_network_port() -> int:
	if network_port_input == null:
		return 24531
	var value := network_port_input.text.strip_edges()
	if value.is_empty() or not value.is_valid_int():
		return 24531
	return clampi(int(value), 1, 65535)


func _show_host_lan_addresses(port: int) -> void:
	if network_game_service == null or not network_game_service.has_method("get_lan_addresses"):
		return
	var addresses: PackedStringArray = network_game_service.call("get_lan_addresses")
	var address_text := "unknown"
	if not addresses.is_empty():
		address_text = ", ".join(addresses)
	var text := "Host IP: %s | Port: %d" % [address_text, port]
	if network_status_label != null:
		network_status_label.text = text
	debug_label.text = text


func _on_network_local_faction_changed(player: int) -> void:
	if turn_manager.has_method("set_view_player"):
		turn_manager.call("set_view_player", player)
	resource_tracker.update_display(player)
	_update_progress_bars(player)
	building_ui.refresh(player)
	_update_ap_status_label(player)
	_update_wall_blueprint_ui(player, "")
	_update_network_ready_label()


func _on_network_snapshot_received(snapshot: Dictionary) -> void:
	var player: int = int(snapshot.get("player", turn_manager.current_player))
	if turn_manager.has_method("set_view_player"):
		turn_manager.call("set_view_player", player)
	resource_tracker.update_display(player)
	_update_progress_bars(player)
	building_ui.refresh(player)
	_update_ap_status_label(player)
	_update_wall_blueprint_ui(player, "")
	grid_manager.queue_redraw()
	resource_manager.queue_redraw()
	building_manager.queue_redraw()
	unit_manager.queue_redraw()
	$GameBoard/FogOfWar2D.queue_redraw()
	_update_network_ready_label()
	if network_status_label != null:
		network_status_label.text = "LAN snapshot round %d" % int(snapshot.get("round", 0))


func _on_player_ready_changed(_player: int, _ready: bool) -> void:
	_update_network_ready_label()


func _on_sync_round_action_started(_round: int) -> void:
	_update_network_ready_label()


func _update_network_ready_label() -> void:
	if network_ready_label == null:
		return
	var ready: Array = []
	if turn_manager != null and turn_manager.has_method("get_ready_players"):
		ready = turn_manager.call("get_ready_players")
	var parts: PackedStringArray = []
	for p in range(3):
		var state := "OK" if p < ready.size() and bool(ready[p]) else "--"
		parts.append("%s:%s" % [GameCatalog.faction_name(p), state])
	network_ready_label.text = "Round %d | %s" % [turn_manager.round_number, "  ".join(parts)]


func _input(event: InputEvent) -> void:
	# Enter 或 Tab 都可结束回合（Tab 在编辑器内嵌模式可能被截获）
	if event is InputEventKey and event.pressed and not event.echo:
		var focus_owner := get_viewport().gui_get_focus_owner()
		if focus_owner is LineEdit:
			return
		if wall_blueprint_manager != null and wall_blueprint_manager.has_method("is_wall_mode_active"):
			if bool(wall_blueprint_manager.call("is_wall_mode_active")) and event.keycode == KEY_ENTER:
				return
		if event.keycode == KEY_ENTER or event.keycode == KEY_TAB:
			_on_end_turn()
		elif event.keycode == KEY_1:
			if current_state == GameState.PLAYING and building_ui != null:
				building_ui.toggle_panel()
		elif event.keycode == KEY_ESCAPE:
			if building_ui != null and building_ui.visible:
				building_ui.hide_panel()


func _on_end_turn() -> void:
	if current_state != GameState.PLAYING:
		return
	if unit_manager.is_in_combat():
		return
	if neutral_unit_manager.is_in_combat():
		return
	if network_game_service != null and network_game_service.is_network_game():
		network_game_service.request_end_round()
		return
	turn_manager.end_player_turn(turn_manager.current_player)



func _on_hidden_trader_discovered(faction: int) -> void:
	var mult: float = neutral_unit_manager.get_price_multiplier(faction)
	goblin_market_ui.show_market(faction, mult)

func _on_neutral_combat_started() -> void:
	debug_label.text = "战斗中..."


func _on_neutral_combat_ended() -> void:
	var cp: int = turn_manager.current_player
	debug_label.text = _format_ap_debug_text(cp)
