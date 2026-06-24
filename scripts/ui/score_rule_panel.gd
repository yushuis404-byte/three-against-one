class_name ScoreRulePanel
extends Control

const PANEL_COLOR := Color(0.035, 0.04, 0.045, 0.92)
const BORDER_COLOR := Color(0.42, 0.58, 0.82, 0.62)
const ROW_A := Color(0.09, 0.11, 0.13, 0.82)
const ROW_B := Color(0.06, 0.075, 0.09, 0.82)
const CLOSE_RECT := Rect2(0, 0, 72, 26)

const RESOURCE_RULES := [
	{"key": "gold", "name": "\u91d1\u5e01", "rate": "1 = 4\u5206", "cap": 160},
	{"key": "gold_ore", "name": "\u91d1\u77ff\u77f3", "rate": "1 = 1\u5206", "cap": 80},
	{"key": "magic_dust", "name": "\u9b54\u5c18", "rate": "1 = 2\u5206", "cap": 80},
	{"key": "dragon_blood", "name": "\u9f99\u8840", "rate": "1 = 8\u5206", "cap": 96},
	{"key": "ancient_wood", "name": "\u53e4\u6728", "rate": "2 = 1\u5206", "cap": 60},
	{"key": "iron", "name": "\u94c1\u77ff", "rate": "3 = 1\u5206", "cap": 60},
	{"key": "wood", "name": "\u6728\u6750", "rate": "5 = 1\u5206", "cap": 40},
	{"key": "stone", "name": "\u77f3\u6599", "rate": "5 = 1\u5206", "cap": 40},
	{"key": "food", "name": "\u98df\u7269", "rate": "5 = 1\u5206", "cap": 40},
]
const BUILDING_RULES := [
	["\u4e3b\u57ce", "100"],
	["\u57fa\u7840\u7ecf\u6d4e\u5efa\u7b51", "8"],
	["\u4ed3\u5e93 Lv1 / Lv2 / Lv3", "10 / 20 / 35"],
	["\u62db\u52df\u8425", "10"],
	["\u5175\u8425", "15"],
	["\u4fa6\u5bdf / \u524d\u54e8", "12"],
	["\u94c1\u77ff\u4e95", "16"],
	["\u91d1\u77ff\u4e95 / \u94f8\u5e01\u5382", "22 / 28"],
	["\u7a00\u6709\u8d44\u6e90\u5efa\u7b51", "24"],
	["\u9886\u4e3b\u7279\u8272\u5efa\u7b51", "30"],
	["\u9f99\u65cf\u5efa\u7b51", "40"],
	["\u5347\u7ea7\u989d\u5916", "\u6bcf\u7ea7 +6"],
]
const UNIT_RULES := [
	["\u5de5\u4eba", "4"],
	["\u65a5\u5019", "8"],
	["\u5b88\u536b / \u57fa\u7840\u6218\u6597\u5355\u4f4d", "10"],
	["\u57fa\u7840\u8089\u76fe", "12"],
	["\u91cd\u88c5\u8089\u76fe", "18"],
	["\u9ad8\u7ea7\u5355\u4f4d", "18"],
	["\u9f99\u88d4\u5355\u4f4d", "28"],
	["\u5c60\u9f99\u72c2\u6218\u58eb", "32"],
	["\u53e4\u9f99", "100"],
	["\u59cb\u7956\u9f99\u795d\u798f\u5355\u4f4d", "140"],
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _draw() -> void:
	_draw_panel()
	_draw_resource_table()
	_draw_building_table()
	_draw_unit_table()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var close_rect := Rect2(size.x - 86.0, 5.0, CLOSE_RECT.size.x, CLOSE_RECT.size.y)
	if close_rect.has_point(mb.position):
		visible = false
		accept_event()


func _draw_panel() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PANEL_COLOR, true)
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, 1.0)
	draw_rect(Rect2(size.x - 86.0, 5.0, CLOSE_RECT.size.x, CLOSE_RECT.size.y), Color(0.18, 0.08, 0.08, 0.85), true)
	draw_rect(Rect2(size.x - 86.0, 5.0, CLOSE_RECT.size.x, CLOSE_RECT.size.y), Color(1.0, 0.55, 0.48, 0.72), false, 1.0)
	_draw_text(Vector2(size.x - 73.0, 23.0), "\u5173\u95ed", 13, Color(1.0, 0.84, 0.80))
	_draw_text(Vector2(18.0, 30.0), "\u7ed3\u7b97\u8ba1\u5206\u89c4\u5219", 20, Color(0.96, 0.98, 1.0))
	_draw_text(Vector2(18.0, 58.0), "\u603b\u5206 = \u4e3b\u57ce + \u5efa\u7b51 + \u5355\u4f4d + \u79d1\u6280 + \u8d44\u6e90\u3002\u5355\u4f4d\u6309\u5f53\u524d\u751f\u547d\u6bd4\u4f8b\u6298\u7b97\u3002", 12, Color(0.68, 0.76, 0.86))


func _draw_resource_table() -> void:
	var x := 24.0
	var y := 92.0
	var row_h := 34.0
	var widths := [150.0, 160.0, 110.0]
	_draw_row(Vector2(x, y), widths, ["\u8d44\u6e90", "\u8ba1\u5206", "\u5355\u9879\u4e0a\u9650"], Color(0.15, 0.22, 0.31, 0.94), true)
	y += row_h
	for i in range(RESOURCE_RULES.size()):
		var rule: Dictionary = RESOURCE_RULES[i]
		var color := ROW_A if i % 2 == 0 else ROW_B
		_draw_row(Vector2(x, y), widths, [
			str(rule["name"]),
			str(rule["rate"]),
			"%d\u5206" % int(rule["cap"]),
		], color, false)
		y += row_h


func _draw_building_table() -> void:
	var x := 24.0
	var y := 432.0
	var row_h := 28.0
	var widths := [250.0, 150.0]
	_draw_row(Vector2(x, y), widths, ["\u5efa\u7b51", "\u5206\u6570"], Color(0.15, 0.22, 0.31, 0.94), true)
	y += row_h
	for i in range(BUILDING_RULES.size()):
		var row: Array = BUILDING_RULES[i]
		var color := ROW_A if i % 2 == 0 else ROW_B
		_draw_row(Vector2(x, y), widths, row, color, false)
		y += row_h
	_draw_text(Vector2(x, y + 20.0), "\u5efa\u7b51\u603b\u5206\u4e0a\u9650\uff1a220", 12, Color(0.82, 0.88, 0.96))


func _draw_unit_table() -> void:
	var x := 470.0
	var y := 92.0
	var row_h := 30.0
	var widths := [260.0, 110.0]
	_draw_row(Vector2(x, y), widths, ["\u5355\u4f4d", "\u6ee1\u8840\u5206"], Color(0.15, 0.22, 0.31, 0.94), true)
	y += row_h
	for i in range(UNIT_RULES.size()):
		var row: Array = UNIT_RULES[i]
		var color := ROW_A if i % 2 == 0 else ROW_B
		_draw_row(Vector2(x, y), widths, row, color, false)
		y += row_h
	_draw_text(Vector2(x, y + 20.0), "\u666e\u901a\u5355\u4f4d\u4e0a\u9650\uff1a160\uff1b\u53e4\u9f99\u7c7b\u4e0d\u8fdb\u666e\u901a\u4e0a\u9650", 12, Color(0.82, 0.88, 0.96))


func _draw_row(pos: Vector2, widths: Array, values: Array, bg: Color, is_header: bool) -> void:
	var row_w: float = 0.0
	for w in widths:
		row_w += float(w)
	draw_rect(Rect2(pos, Vector2(row_w, 30.0)), bg, true)
	draw_rect(Rect2(pos, Vector2(row_w, 30.0)), Color(1, 1, 1, 0.12), false, 1.0)
	var x := pos.x
	for i in range(values.size()):
		_draw_text(Vector2(x + 10.0, pos.y + 21.0), str(values[i]), 13 if is_header else 12, Color(0.94, 0.97, 1.0))
		x += float(widths[i])


func _draw_text(pos: Vector2, text: String, font_size: int, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
