extends GridContainer
class_name GSLinearControl

var client: GSClient
var device: GSDevice
var feature: GSFeature

@onready var _index: Label = %Index
@onready var _duration: SpinBox = %Duration
@onready var _position: HSlider = $Position
@onready var _open_dialog: FileDialog = %OpenDialog


func _ready() -> void:
	_index.text = str(feature.feature_index)


func _on_position_value_changed(value: float) -> void:
	value = clampf(value / 100.0, 0.0, 1.0)
	await client.send_feature(feature, value, int(_duration.value))


func _on_play_pattern_pressed() -> void:
	_open_dialog.popup_centered()


func _on_stop_pattern_pressed() -> void:
	var patterns: GSPatterns = GSClient.ext(GSPatterns.NAME)
	var active := patterns.get_active_by_feature(feature)
	if active:
		active.stop()


func _on_pause_pattern_pressed() -> void:
	var patterns: GSPatterns = GSClient.ext(GSPatterns.NAME)
	var active := patterns.get_active_by_feature(feature)
	if active:
		active.pause()


func _on_resume_pattern_pressed() -> void:
	var patterns: GSPatterns = GSClient.ext(GSPatterns.NAME)
	var active := patterns.get_active_by_feature(feature)
	if active:
		active.resume()


func _on_open_dialog_file_selected(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		OS.alert("Unable to open pattern: %s" % FileAccess.get_open_error())
		return
	var json = file.get_as_text()
	var pattern: GSPattern = GSClient.ext_call(GSPatterns.NAME, "deserialize_pattern", [ json ])
	if not pattern:
		OS.alert("Unable to parse pattern file: %s" % path)
		return
	var patterns: GSPatterns = GSClient.ext(GSPatterns.NAME)
	patterns.add(pattern)
	patterns.play(pattern, feature)
