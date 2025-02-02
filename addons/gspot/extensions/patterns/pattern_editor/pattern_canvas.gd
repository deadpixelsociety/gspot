extends Control
class_name PatternCanvas


const SAMPLE_RATE := 1.0 / 30.0
const SAMPLE_RENDER_COUNT := 50
const VISUAL_SPACING := 20.0


var recording: bool = false

var _samples: PackedFloat32Array = PackedFloat32Array()
var _line_points: PackedVector2Array = PackedVector2Array()
var _sr: float = 0.0
var _sample_pos: Vector2 = Vector2.ZERO
var _last_sample_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	reset()


func _process(delta: float) -> void:
	if recording:
		_sr += delta
		if _sr >= SAMPLE_RATE:
			_sr -= SAMPLE_RATE
			_sample_pos.x = size.x * 0.5
			_sample_pos.y = _get_clamped_local_mouse().y
			_add_sample(_sample_pos)
			_last_sample_pos = _sample_pos
	queue_redraw()


func _draw() -> void:
	var color = Color.from_string("#de2a85", Color.PINK)
	var pos = Vector2(size.x * 0.5, _get_clamped_local_mouse().y)
	for i in _line_points.size():
		if i + 1 < _line_points.size():
			var a = _line_points[i]
			var b = _line_points[i + 1]
			draw_line(a, b, color, 4.0, true)
	if recording:
		if _line_points.size() > 0:
			draw_line(_line_points[-1], pos, color, 4.0, true)
		draw_circle(pos, 16.0, color)


func get_samples() -> PackedFloat32Array:
	return _samples


func reset() -> void:
	_samples.clear()
	_line_points.clear()
	_sample_pos = Vector2.ZERO
	_last_sample_pos = Vector2.ZERO
	_sr = 0.0


func _get_clamped_local_mouse() -> Vector2:
	var mouse_pos = get_local_mouse_position()
	mouse_pos.x = clampf(mouse_pos.x, 0.0, size.x)
	mouse_pos.y = clampf(mouse_pos.y, 0.0, size.y)
	return mouse_pos


func _add_sample(sample_pos: Vector2) -> void:
	var sample = 1.0 - (sample_pos.y / size.y)
	_samples.append(sample)
	var mouse_pos = _get_clamped_local_mouse()
	_line_points.append(Vector2(size.x * 0.5, mouse_pos.y))
	if _line_points.size() > SAMPLE_RENDER_COUNT:
		_line_points.remove_at(0)
	for i in _line_points.size():
		var point := _line_points[i]
		point.x -= VISUAL_SPACING
		_line_points[i] = point
