extends PanelContainer
class_name PatternPanel

var feature: GSFeature = null

@onready var _open_dialog: FileDialog = %OpenDialog


func _ready() -> void:
	if get_parent():
		feature = get_parent().get("feature")


func _on_play_pattern_pressed() -> void:
	_open_dialog.popup_centered()


func _on_stop_pattern_pressed() -> void:
	var patterns: GSPatterns = GSClient.ext(GSPatterns.NAME)
	var active := patterns.get_active_pattern_by_feature(feature)
	if active:
		active.stop()


func _on_pause_pattern_pressed() -> void:
	var patterns: GSPatterns = GSClient.ext(GSPatterns.NAME)
	var active := patterns.get_active_pattern_by_feature(feature)
	if active:
		active.pause()


func _on_resume_pattern_pressed() -> void:
	var patterns: GSPatterns = GSClient.ext(GSPatterns.NAME)
	var active := patterns.get_active_pattern_by_feature(feature)
	if active:
		active.resume()


func _on_open_dialog_file_selected(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		OS.alert("Unable to open pattern: %s" % FileAccess.get_open_error())
		return
	var json = file.get_as_text()
	var pattern: GSPattern = GSPatterns.deserialize_pattern(json)
	if not pattern:
		OS.alert("Unable to parse pattern file: %s" % path)
		return
	var patterns: GSPatterns = GSClient.ext(GSPatterns.NAME)
	patterns.add_pattern(pattern)
	patterns.play(pattern.pattern_name, feature)
