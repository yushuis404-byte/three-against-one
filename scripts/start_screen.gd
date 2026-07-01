extends Node2D

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer
@onready var btn_start: TextureButton = $Buttons/StartButton
@onready var btn_multiplayer: TextureButton = $Buttons/MultiplayerButton
@onready var btn_quit: TextureButton = $Buttons/QuitButton
@onready var buttons: VBoxContainer = $Buttons
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer
var _multiplayer_panel: Control = null

const BUTTON_GROUP_SCALE := 0.48
const BUTTON_GROUP_Y := 580.0


func _ready() -> void:
	video_player.set_anchors_preset(Control.PRESET_TOP_LEFT)
	video_player.position = Vector2.ZERO
	video_player.size = get_viewport_rect().size
	video_player.stream = load("res://assets/ui/开始界面.ogv")
	video_player.autoplay = true
	video_player.loop = true
	video_player.play()

	btn_start.pressed.connect(_on_start_pressed)
	btn_multiplayer.pressed.connect(_on_multiplayer_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)

	buttons.scale = Vector2(BUTTON_GROUP_SCALE, BUTTON_GROUP_SCALE)
	_center_buttons.call_deferred()


func _center_buttons() -> void:
	var scaled_width := buttons.size.x * buttons.scale.x
	buttons.position = Vector2(
		(1920.0 - scaled_width) / 2.0,
		BUTTON_GROUP_Y
	)


func _on_start_pressed() -> void:
	GameSession.start_singleplayer()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_multiplayer_pressed() -> void:
	if _multiplayer_panel == null:
		_multiplayer_panel = MultiplayerConnectionPanel.new()
		add_child(_multiplayer_panel)
	_multiplayer_panel.show()


func _on_quit_pressed() -> void:
	get_tree().quit()
