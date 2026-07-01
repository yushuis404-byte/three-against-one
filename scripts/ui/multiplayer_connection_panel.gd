class_name MultiplayerConnectionPanel
extends Control

var _panel: Panel = null
var _title_label: Label = null
var _host_button: Button = null
var _join_button: Button = null
var _ip_input: LineEdit = null
var _port_input: LineEdit = null
var _lan_label: Label = null
var _status_label: Label = null
var _back_button: Button = null
var _bg: ColorRect = null
var _is_host := false
var _join_state := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 150
	_build_ui()
	hide()


func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.name = "Shade"
	_bg.color = Color(0.0, 0.0, 0.0, 0.62)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	_panel = Panel.new()
	_panel.name = "Panel"
	_panel.position = Vector2(710.0, 280.0)
	_panel.size = Vector2(500.0, 460.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.065, 0.085, 0.98)
	style.border_color = Color(0.42, 0.76, 1.0, 0.62)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "联机对战"
	_title_label.position = Vector2(0.0, 16.0)
	_title_label.size = Vector2(500.0, 36.0)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
	_panel.add_child(_title_label)

	_host_button = Button.new()
	_host_button.name = "HostButton"
	_host_button.text = "创建主机"
	_host_button.position = Vector2(60.0, 80.0)
	_host_button.size = Vector2(180.0, 42.0)
	_host_button.focus_mode = Control.FOCUS_NONE
	_host_button.pressed.connect(_on_host_pressed)
	_panel.add_child(_host_button)

	_join_button = Button.new()
	_join_button.name = "JoinButton"
	_join_button.text = "加入游戏"
	_join_button.position = Vector2(260.0, 80.0)
	_join_button.size = Vector2(180.0, 42.0)
	_join_button.focus_mode = Control.FOCUS_NONE
	_join_button.pressed.connect(_on_join_pressed)
	_panel.add_child(_join_button)

	var ip_label := Label.new()
	ip_label.name = "IPLabel"
	ip_label.text = "IP 地址:"
	ip_label.position = Vector2(40.0, 150.0)
	ip_label.size = Vector2(70.0, 28.0)
	ip_label.add_theme_font_size_override("font_size", 14)
	ip_label.add_theme_color_override("font_color", Color(0.76, 0.84, 0.92))
	_panel.add_child(ip_label)

	_ip_input = LineEdit.new()
	_ip_input.name = "IPInput"
	_ip_input.text = "127.0.0.1"
	_ip_input.placeholder_text = "192.168.1.xxx"
	_ip_input.position = Vector2(114.0, 146.0)
	_ip_input.size = Vector2(346.0, 32.0)
	_ip_input.focus_mode = Control.FOCUS_CLICK
	_panel.add_child(_ip_input)

	var port_label := Label.new()
	port_label.name = "PortLabel"
	port_label.text = "端口:"
	port_label.position = Vector2(40.0, 200.0)
	port_label.size = Vector2(70.0, 28.0)
	port_label.add_theme_font_size_override("font_size", 14)
	port_label.add_theme_color_override("font_color", Color(0.76, 0.84, 0.92))
	_panel.add_child(port_label)

	_port_input = LineEdit.new()
	_port_input.name = "PortInput"
	_port_input.text = "24531"
	_port_input.placeholder_text = "Port"
	_port_input.position = Vector2(114.0, 196.0)
	_port_input.size = Vector2(120.0, 32.0)
	_port_input.focus_mode = Control.FOCUS_CLICK
	_panel.add_child(_port_input)

	_lan_label = Label.new()
	_lan_label.name = "LANLabel"
	_lan_label.position = Vector2(20.0, 250.0)
	_lan_label.size = Vector2(460.0, 40.0)
	_lan_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lan_label.add_theme_font_size_override("font_size", 12)
	_lan_label.add_theme_color_override("font_color", Color(0.62, 0.86, 1.0, 0.95))
	_lan_label.visible = false
	_panel.add_child(_lan_label)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.position = Vector2(20.0, 295.0)
	_status_label.size = Vector2(460.0, 28.0)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color(0.9, 0.82, 0.42))
	_status_label.visible = false
	_panel.add_child(_status_label)

	_back_button = Button.new()
	_back_button.name = "BackButton"
	_back_button.text = "返回"
	_back_button.position = Vector2(198.0, 400.0)
	_back_button.size = Vector2(104.0, 36.0)
	_back_button.focus_mode = Control.FOCUS_NONE
	_back_button.pressed.connect(_on_back_pressed)
	_panel.add_child(_back_button)


func _on_host_pressed() -> void:
	var port := _get_port()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, 3)
	if err != OK:
		_show_error("鍒涘缓鎴块棿澶辫触: %s" % str(err))
		return
	multiplayer.multiplayer_peer = peer
	GameSession.start_multiplayer()
	_is_host = true
	_set_form_enabled(false)
	_show_lan_addresses(port)
	_status_label.text = "宸插垱寤烘埧闂达紝姝ｅ湪杩涘叆娓告垙..."
	_status_label.visible = true
	await get_tree().create_timer(0.8).timeout
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_join_pressed() -> void:
	var address := _ip_input.text.strip_edges()
	var port := _get_port()
	if address.is_empty():
		address = "127.0.0.1"

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		_show_error("杩炴帴澶辫触: %s" % str(err))
		return
	multiplayer.multiplayer_peer = peer
	GameSession.start_multiplayer()
	_set_form_enabled(false)
	_status_label.text = "姝ｅ湪杩炴帴 %s:%d ..." % [address, port]
	_status_label.visible = true

	_join_state = 0
	var conn_cb := func(): _join_state = 1
	var fail_cb := func(): _join_state = -1
	multiplayer.connected_to_server.connect(conn_cb, CONNECT_ONE_SHOT)
	multiplayer.connection_failed.connect(fail_cb, CONNECT_ONE_SHOT)

	var timer := 0.0
	while timer < 3.0 and _join_state == 0:
		await get_tree().process_frame
		timer += get_process_delta_time()

	match _join_state:
		1:
			_status_label.text = "宸茶繛鎺ワ紝姝ｅ湪杩涘叆娓告垙..."
			await get_tree().create_timer(0.5).timeout
			get_tree().change_scene_to_file("res://scenes/main.tscn")
		-1, 0:
			_show_error("连接失败或超时")
			multiplayer.multiplayer_peer = null
			GameSession.clear()
			_set_form_enabled(true)


func _on_back_pressed() -> void:
	if multiplayer.multiplayer_peer != null and not _is_host:
		multiplayer.multiplayer_peer = null
	multiplayer.multiplayer_peer = null
	GameSession.clear()
	hide()


func _show_lan_addresses(port: int) -> void:
	var addresses := PackedStringArray()
	for address in IP.get_local_addresses():
		var value := str(address)
		if value.begins_with("127."):
			continue
		if value == "0.0.0.0":
			continue
		if not value.contains("."):
			continue
		addresses.append(value)
	var text := "unknown"
	if not addresses.is_empty():
		text = ", ".join(addresses)
	_lan_label.text = "鏈満 IP: %s | 绔彛: %d" % [text, port]
	_lan_label.visible = true


func _get_port() -> int:
	var value := _port_input.text.strip_edges()
	if value.is_empty() or not value.is_valid_int():
		return 24531
	return clampi(int(value), 1, 65535)


func _set_form_enabled(enabled: bool) -> void:
	_host_button.disabled = not enabled
	_join_button.disabled = not enabled
	_ip_input.editable = enabled
	_port_input.editable = enabled


func _show_error(text: String) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
	_status_label.visible = true

