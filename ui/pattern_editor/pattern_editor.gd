extends Control
class_name PatternEditor

var _recording: bool = false
var _time: float = 0.0

@onready var _record: Button = %Record
@onready var _reset: Button = %Reset
@onready var _elapsed_time: Label = %ElapsedTime
@onready var _pattern_canvas: PatternCanvas = %PatternCanvas
@onready var _pattern_name: TextEdit = %PatternName
@onready var _save: Button = %Save
@onready var _exit: Button = %Exit
@onready var _save_dialog: FileDialog = $SaveDialog


func _process(delta: float) -> void:
	if _recording:
		_time += delta
		_update_time()


func _configure_controls() -> void:
	if _recording:
		_record.text = "Stop [1]"
		_pattern_canvas.recording = true
		_reset.disabled = true
		_save.disabled = true
		_exit.disabled = true
	else:
		_record.text = "Record [1]"
		_pattern_canvas.recording = false
		_reset.disabled = false
		_save.disabled = false
		_exit.disabled = false


func _update_time() -> void:
	var seconds = floor(_time)
	var remainder = clampf(fmod(_time, 1.0) * 100.0, 0.0, 99.99)
	_elapsed_time.text = "Time: %02.f:%02.f" % [ seconds, remainder ]


func _on_record_pressed() -> void:
	_recording = not _recording
	_configure_controls()


func _on_reset_pressed() -> void:
	_recording = false
	_pattern_canvas.recording = false
	_pattern_canvas.reset()
	_time = 0.0
	_configure_controls()
	_update_time()


func _on_save_pressed() -> void:
	var pattern_name := _pattern_name.text
	if not pattern_name or pattern_name.is_empty():
		OS.alert("Enter a pattern name before saving.")
		return
	_save_dialog.popup_centered()


func _on_exit_pressed() -> void:
	if get_parent() is Window:
		get_parent().close_requested.emit()
	else:
		get_tree().quit()


func _on_save_dialog_file_selected(path: String) -> void:
	var pattern_name := _pattern_name.text
	var pattern := GSSequencePattern.new()
	pattern.pattern_name = pattern_name
	pattern.sequence = _pattern_canvas.get_samples()
	pattern.duration = _time
	var json = GSPatterns.serialize_pattern(pattern)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		OS.alert("Unable to save pattern: %s" % FileAccess.get_open_error())
		return
	file.store_string(json)
