extends Node2D
const GameStageRulesScript = preload("res://scripts/rules/game_stage_rules.gd")
const StageEventServiceScript = preload("res://scripts/services/stage_event_service.gd")
const AchievementServiceScript = preload("res://scripts/services/achievement_service.gd")
const AchievementTreePanelScript = preload("res://scripts/ui/achievement_tree_panel.gd")
const TechnologyServiceScript = preload("res://scripts/services/technology_service.gd")
const TechnologyTreePanelScript = preload("res://scripts/ui/technology_tree_panel.gd")
const VictoryServiceScript = preload("res://scripts/services/victory_service.gd")
const ScoreRulePanelScript = preload("res://scripts/ui/score_rule_panel.gd")
const CivilizationRoutePanelScript = preload("res://scripts/ui/civilization_route_panel.gd")
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
var achievement_service: AchievementService = null
var achievement_tree_panel: Control = null
var achievement_tree_button: Button = null
var technology_service: Node = null
var technology_tree_panel: Control = null
var technology_tree_button: Button = null
var victory_service: Node = null
var game_over_label: Label = null
var score_rule_panel: Control = null
var score_rule_button: Button = null
var civilization_route_panel: Control = null
var civilization_route_button: Button = null
var creative_mode_button: Button = null
var wall_blueprint_button: Button = null
var wall_blueprint_status_label: Label = null
var zoom_status_label: Label = null
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
	_init_zoom_status_label()
	_init_stage_event_service()

	# 单位系统初始化
	unit_manager.set_turn_manager(turn_manager)
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
	_init_creative_mode_button()
	_init_achievement_service()
	_init_technology_service()
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

	# 所有信号就绪后启动第一回合
	turn_manager.start_game()


func _hide_civilization_debug_panel() -> void:
	var panel: CanvasItem = $UI.get_node_or_null("CivilizationDebugPanel") as CanvasItem
	if panel != null:
		panel.visible = false


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
	if text.is_empty():
		debug_label.text = ""
	else:
		debug_label.text = text


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
	resource_tracker.update_display(player)
	_update_wall_blueprint_ui(player, "")
	# 海克斯商队触发检查
	if _goblin_market_round == turn_manager.round_number:
		if neutral_unit_manager.should_caravan_visit(player):
			var mult: float = neutral_unit_manager.get_price_multiplier(player)
			goblin_market_ui.show_market(player, mult)
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
	debug_label.text = _format_ap_debug_text(player)
	_update_ap_status_label(player)
	_update_wall_blueprint_ui(player, "")
	resource_tracker.update_display(player)
	building_ui.refresh(player)
	_refresh_unit_skill_bar()


func _init_resource_labels() -> void:
	## 将 UI 面板中的 Label 引用传给 resource_tracker
	var panel: Panel = resource_panel
	if not panel:
		return
	var hbox: HBoxContainer = panel.get_node("HBox") as HBoxContainer
	var key_map := {"Gold": "gold", "Wood": "wood", "Stone": "stone", "Food": "food", "Iron": "iron", "MagicDust": "magic_dust", "AncientWood": "ancient_wood", "GoldOre": "gold_ore", "Mithril": "mithril", "Steel": "steel"}
	for node_name in key_map:
		var label: Label = hbox.get_node_or_null("Label" + node_name) as Label
		if label == null:
			label = Label.new()
			label.name = "Label" + node_name
			label.add_theme_font_size_override("font_size", 13)
			hbox.add_child(label)
		resource_tracker.set_resource_label(str(key_map[node_name]), label)
	resource_tracker.set_faction_label(panel.get_node("HBox/FactionLabel") as Label)


func _on_resources_updated(_player: int) -> void:
	var cp: int = turn_manager.current_player
	resource_tracker.update_display(cp)


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
	achievement_tree_button = Button.new()
	achievement_tree_button.name = "AchievementTreeButton"
	achievement_tree_button.text = "\u6210\u5c31\u6811"
	achievement_tree_button.position = Vector2(16.0, 176.0)
	achievement_tree_button.size = Vector2(96.0, 30.0)
	achievement_tree_button.focus_mode = Control.FOCUS_NONE
	achievement_tree_button.z_index = 90
	achievement_tree_button.pressed.connect(_on_achievement_tree_button_pressed)
	$UI.add_child(achievement_tree_button)


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
	technology_tree_button = Button.new()
	technology_tree_button.name = "TechnologyTreeButton"
	technology_tree_button.text = "\u79d1\u6280\u6811"
	technology_tree_button.position = Vector2(118.0, 176.0)
	technology_tree_button.size = Vector2(96.0, 30.0)
	technology_tree_button.focus_mode = Control.FOCUS_NONE
	technology_tree_button.z_index = 90
	technology_tree_button.pressed.connect(_on_technology_tree_button_pressed)
	$UI.add_child(technology_tree_button)


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
	score_rule_button.position = Vector2(220.0, 176.0)
	score_rule_button.size = Vector2(76.0, 30.0)
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
	civilization_route_button.position = Vector2(302.0, 176.0)
	civilization_route_button.size = Vector2(76.0, 30.0)
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
	debug_label.text = "第 %d 阶段开始：哥布林商队出现" % stage
	print("[阶段事件] 哥布林商队出现：阶段 %d，回合 %d" % [stage, round_number])


func _init_stage_label() -> void:
	stage_label = Label.new()
	stage_label.name = "StageLabel"
	stage_label.position = Vector2(760, 48)
	stage_label.size = Vector2(400, 28)
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_label.add_theme_font_size_override("font_size", 16)
	stage_label.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0))
	stage_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	stage_label.add_theme_constant_override("shadow_offset_x", 1)
	stage_label.add_theme_constant_override("shadow_offset_y", 1)
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
	stage_label.text = "第 %d / %d 阶段 · 阶段回合 %d / %d" % [
		stage,
		GameStageRulesScript.TOTAL_STAGES,
		round_in_stage,
		GameStageRulesScript.ROUNDS_PER_STAGE,
	]


func _init_ap_status_label() -> void:
	ap_status_label = Label.new()
	ap_status_label.name = "APStatusLabel"
	ap_status_label.position = Vector2(16, 138)
	ap_status_label.size = Vector2(220, 34)
	ap_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ap_status_label.add_theme_font_size_override("font_size", 18)
	ap_status_label.add_theme_color_override("font_color", Color.WHITE)
	ap_status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	ap_status_label.add_theme_constant_override("shadow_offset_x", 1)
	ap_status_label.add_theme_constant_override("shadow_offset_y", 1)
	$UI.add_child(ap_status_label)
	_update_ap_status_label(turn_manager.current_player)


func _update_ap_status_label(player: int) -> void:
	if not ap_status_label:
		return
	var color: Color = GameCatalog.faction_color(player)
	ap_status_label.add_theme_color_override("font_color", color)
	if _creative_mode_enabled:
		ap_status_label.text = "%s AP: ∞" % GameCatalog.faction_name(player)
		return
	ap_status_label.text = "%s AP: %d / %d" % [
		GameCatalog.faction_name(player),
		turn_manager.get_ap(player),
		turn_manager.AP_MAX,
	]


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


func _input(event: InputEvent) -> void:
	# Enter 或 Tab 都可结束回合（Tab 在编辑器内嵌模式可能被截获）
	if event is InputEventKey and event.pressed and not event.echo:
		if wall_blueprint_manager != null and wall_blueprint_manager.has_method("is_wall_mode_active"):
			if bool(wall_blueprint_manager.call("is_wall_mode_active")) and event.keycode == KEY_ENTER:
				return
		if event.keycode == KEY_ENTER or event.keycode == KEY_TAB:
			_on_end_turn()


func _on_end_turn() -> void:
	if current_state != GameState.PLAYING:
		return
	if unit_manager.is_in_combat():
		return
	if neutral_unit_manager.is_in_combat():
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
