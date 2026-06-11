extends Camera2D
## 2.5D 伪正交俯视摄像机控制器
## 星露谷物语风格：固定视角 + 空格拖拽平移 + 滚轮缩放

const PAN_BUTTON := KEY_SPACE
const ZOOM_SPEED := 0.08
const ZOOM_MIN := Vector2(0.5, 0.5)
const ZOOM_MAX := Vector2(2.5, 2.5)
const ZOOM_DEFAULT := Vector2(1.0, 1.0)
const PAN_SPEED := 1.0
const SMOOTH_SPEED := 12.0

# 地图边界（世界坐标）
const TILE_SIZE := 32.0
const GRID_COLS := 100
const GRID_ROWS := 56
const GRID_EXTENT_X := GRID_COLS / 2.0 * TILE_SIZE  # 1600
const GRID_EXTENT_Y := GRID_ROWS / 2.0 * TILE_SIZE  # 896
const MARGIN := 200.0
const BOUNDS_MIN := Vector2(-GRID_EXTENT_X - MARGIN, -GRID_EXTENT_Y - MARGIN)
const BOUNDS_MAX := Vector2(GRID_EXTENT_X + MARGIN, GRID_EXTENT_Y + MARGIN)

var _panning := false
var _target_zoom := ZOOM_DEFAULT
var _target_position := Vector2.ZERO


func _ready() -> void:
	zoom = ZOOM_DEFAULT
	_target_zoom = ZOOM_DEFAULT
	_target_position = position
	print("[Camera] 2.5D 固定视角摄像机就绪")


func _process(delta: float) -> void:
	zoom = zoom.lerp(_target_zoom, SMOOTH_SPEED * delta)
	_clamp_position()

	var dist := position.distance_to(_target_position)
	if dist < 1.0:
		position = _target_position
	else:
		position = position.lerp(_target_position, SMOOTH_SPEED * delta)

	if zoom.distance_to(_target_zoom) < 0.005:
		zoom = _target_zoom


func _input(event: InputEvent) -> void:
	# Space key
	if event is InputEventKey and event.keycode == KEY_SPACE:
		if event.pressed and not event.echo:
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_panning = true
		elif not event.pressed:
			_panning = false

	# Left mouse button: start/stop panning while Space is held
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if Input.is_key_pressed(PAN_BUTTON):
				_panning = true
		else:
			_panning = false

	# Mouse motion: pan when Space + LMB held
	if event is InputEventMouseMotion and _panning:
		if Input.is_key_pressed(PAN_BUTTON) and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_target_position -= event.relative / zoom * PAN_SPEED

	# Scroll zoom
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = (_target_zoom + Vector2(ZOOM_SPEED, ZOOM_SPEED)).clamp(ZOOM_MIN, ZOOM_MAX)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = (_target_zoom - Vector2(ZOOM_SPEED, ZOOM_SPEED)).clamp(ZOOM_MIN, ZOOM_MAX)


func _clamp_position() -> void:
	var viewport_size := get_viewport_rect().size
	var view_half := viewport_size / 2.0 / _target_zoom
	var bounds_size := BOUNDS_MAX - BOUNDS_MIN

	if view_half.x * 2.0 >= bounds_size.x:
		_target_position.x = (BOUNDS_MIN.x + BOUNDS_MAX.x) / 2.0
	else:
		_target_position.x = clampf(_target_position.x,
			BOUNDS_MIN.x + view_half.x, BOUNDS_MAX.x - view_half.x)

	if view_half.y * 2.0 >= bounds_size.y:
		_target_position.y = (BOUNDS_MIN.y + BOUNDS_MAX.y) / 2.0
	else:
		_target_position.y = clampf(_target_position.y,
			BOUNDS_MIN.y + view_half.y, BOUNDS_MAX.y - view_half.y)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_SPACE:
		if not event.pressed:
			_panning = false
