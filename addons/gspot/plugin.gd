@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_autoload_singleton("GSClient", "gsclient.gd")
	if ProjectSettings.has_setting(GSConstants.PROJECT_SETTING_CLIENT_NAME):
		ProjectSettings.set_as_basic(GSConstants.PROJECT_SETTING_CLIENT_NAME, true)
	if ProjectSettings.has_setting(GSConstants.PROJECT_SETTING_CLIENT_VERSION):
		ProjectSettings.set_as_basic(GSConstants.PROJECT_SETTING_CLIENT_VERSION, true)
	if ProjectSettings.has_setting(GSConstants.PROJECT_SETTING_ENABLE_RAW_COMMANDS):
		ProjectSettings.set_as_basic(GSConstants.PROJECT_SETTING_ENABLE_RAW_COMMANDS, false)


func _exit_tree() -> void:
	remove_autoload_singleton("GSClient")


func _enable_plugin() -> void:
	ProjectSettings.set_setting(GSConstants.PROJECT_SETTING_CLIENT_NAME, GSConstants.CLIENT_NAME)
	ProjectSettings.set_setting(GSConstants.PROJECT_SETTING_CLIENT_VERSION, GSConstants.CLIENT_VERSION)
	ProjectSettings.set_setting(GSConstants.PROJECT_SETTING_ENABLE_RAW_COMMANDS, false)
	ProjectSettings.add_property_info({
		"name": GSConstants.PROJECT_SETTING_ENABLE_RAW_COMMANDS,
		"type": TYPE_BOOL
	})


func _disable_plugin() -> void:
	ProjectSettings.set_setting(GSConstants.PROJECT_SETTING_CLIENT_NAME, null)
	ProjectSettings.set_setting(GSConstants.PROJECT_SETTING_CLIENT_VERSION, null)
	ProjectSettings.set_setting(GSConstants.PROJECT_SETTING_ENABLE_RAW_COMMANDS, null)
