@tool
extends EditorPlugin

const CLIENT_SCRIPT_PATH: String = "res://addons/gspot/gsclient.gd"


func _enter_tree() -> void:
	add_autoload_singleton("GSClient", CLIENT_SCRIPT_PATH)
	if ProjectSettings.has_setting(GSConstants.PROJECT_SETTING_CLIENT_NAME):
		ProjectSettings.set_as_basic(GSConstants.PROJECT_SETTING_CLIENT_NAME, true)
	if ProjectSettings.has_setting(GSConstants.PROJECT_SETTING_CLIENT_VERSION):
		ProjectSettings.set_as_basic(GSConstants.PROJECT_SETTING_CLIENT_VERSION, true)
	if ProjectSettings.has_setting(GSConstants.PROJECT_SETTINGS_MESSAGE_RATE):
		ProjectSettings.set_as_basic(GSConstants.PROJECT_SETTINGS_MESSAGE_RATE, true)
	if ProjectSettings.has_setting(GSConstants.PROJECT_SETTING_ENABLE_RAW_COMMANDS):
		ProjectSettings.set_as_basic(GSConstants.PROJECT_SETTING_ENABLE_RAW_COMMANDS, false)
	if ProjectSettings.has_setting(GSConstants.PROJECT_SETTING_PROTOCOL_MODE):
		ProjectSettings.set_as_basic(GSConstants.PROJECT_SETTING_PROTOCOL_MODE, true)


func _exit_tree() -> void:
	remove_autoload_singleton("GSClient")


func _enable_plugin() -> void:
	ProjectSettings.set_setting(GSConstants.PROJECT_SETTING_CLIENT_NAME, GSConstants.CLIENT_NAME)
	ProjectSettings.set_setting(GSConstants.PROJECT_SETTING_CLIENT_VERSION, GSConstants.CLIENT_VERSION)
	ProjectSettings.set_setting(GSConstants.PROJECT_SETTINGS_MESSAGE_RATE, GSConstants.MESSAGE_RATE)
	ProjectSettings.add_property_info({
		"name": GSConstants.PROJECT_SETTINGS_MESSAGE_RATE,
		"type": TYPE_FLOAT
	})
	ProjectSettings.set_setting(GSConstants.PROJECT_SETTING_ENABLE_RAW_COMMANDS, false)
	ProjectSettings.add_property_info({
		"name": GSConstants.PROJECT_SETTING_ENABLE_RAW_COMMANDS,
		"type": TYPE_BOOL
	})
	ProjectSettings.set_setting(GSConstants.PROJECT_SETTING_PROTOCOL_MODE, 0)
	ProjectSettings.add_property_info({
		"name": GSConstants.PROJECT_SETTING_PROTOCOL_MODE,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Auto,Spec v4,Spec v3"
	})


func _disable_plugin() -> void:
	ProjectSettings.set_setting(GSConstants.PROJECT_SETTING_CLIENT_NAME, null)
	ProjectSettings.set_setting(GSConstants.PROJECT_SETTING_CLIENT_VERSION, null)
	ProjectSettings.set_setting(GSConstants.PROJECT_SETTINGS_MESSAGE_RATE, null)
	ProjectSettings.set_setting(GSConstants.PROJECT_SETTING_ENABLE_RAW_COMMANDS, null)
	ProjectSettings.set_setting(GSConstants.PROJECT_SETTING_PROTOCOL_MODE, null)
