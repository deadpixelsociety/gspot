# gspot

![gspot logo](logo.png) 

A Godot 4 Plugin for interacting with intimate haptic devices via the [buttplug.io](https://buttplug.io/) interface.

**This plugin provides a buttplug.io standard compatibile client implementation. To interact with devices a server is also required. See [Intiface Central](https://intiface.com/central/).**

Review the [protocol specification](https://buttplug-spec.docs.buttplug.io/docs/spec) for an idea of how to interact with this plugin and proper device flow.

A [client control panel](addons/gspot/ui/gscontrol_panel.tscn) is provided for testing devices and getting familiar with the client.

## Quick Example
```gdscript
# Connect to the device server.
GSClient.start("localhost", 12345)
# Wait for connection.
await GSClient.client_connection_changed
# Request the device list from the server.
GSClient.request_device_list()
# Wait for devices to arrive.
await GSClient.client_device_list_received
# Grab the first device.
var device = GSClient.get_device(0)
# Send a vibration command to the device.
device.vibrate()
```
## Log Levels
Log levels let you control the verbosity of messages sent through the ```client_message``` signal. There are four different levels from most verbose to least: 
* ```VERBOSE``` - All messages are emitted.
* ```DEBUG``` - Debug level messages include things like connection state and message contents, but exclude client state messages.
* ```WARN``` - Warning level messages include unexpected issues that can be recovered from or ignored.
* ```ERROR``` - Error level messages include unexpected issues that cannot be recovered from. These are also emitted through ```client_error```.

### Usage
```gdscript
GSClient.set_log_level(GSClient.LogLevel.DEBUG)
GSClient.logv("Verbose log message.")
GSClient.logd("Debug log message.")
GSClient.logw("Warn log message.")
GSClient.loge("Error log message.")
```

## Project Settings
Project settings are now available to configure how the GSClient identifies itself to buttplug.io servers, and if raw device commands are available.
* ```gspot/client/client_name``` - The client name. Defaults to GSClient.
* ```gspot/client/client_version``` - The client version. Currently defaults to 2.1.
* ```gspot/client/message_rate``` - The default device command rate which dictates how fast commands should be sent to a device. Currently defaults to 0.2 seconds.
* ```gspot/client/enable_raw_commands``` - Determines if the raw command methods on GSClient are available or not. Defaults to false. Hidden by advanced settings.

You can set these values in the Project Settings UI under the Gspot category. If you do not see them, try disabling and re-enabling the plugin.

These values are also accessible via the GSClient.
```gdscript
GSClient.get_client_name() # GSClient
GSClient.get_client_version() # 2.0
GSClient.get_client_string() # GSClient v2.0
GSDevice.get_message_rate()
GSClient.is_raw_command_enabled() # false
```

## Extensions
Extensions to GSClient can now be created and placed in the extensions subdirectory to be loaded. The first official extension is for Patterns.

### Patterns
The patterns extension lets you define a pattern via a sequence of float values or by using a Godot Curve. You can then play this pattern against any available device feature including looping, intensity control, pausing, resuming and stopping an active pattern.

A [simple pattern editor](https://github.com/deadpixelsociety/gspot/blob/main/ui/pattern_editor/pattern_editor.tscn) is included in the developer control panel to create sequences. 

Example pattern usage:
```gdscript
var device: GSDevice = GSClient.get_device_by_name("Lovense Calor")
var feature: GSFeature = device.get_feature_by_actuator_type(GSActuatorTypes.VIBRATE)

var patterns: GSPatterns = GSClient.ext(GSPatterns.NAME)

var sequence: PackedFloat32Array = [ 0.0, 0.1, 0.2, 0.3, 1.0, 0.5, 0.7, 0.3, 0.0 ]
# Creates a sequence pattern that plays over 10 seconds.
patterns.create_sequence_pattern("My Pattern", 10.0, sequence)

# Plays the previously added pattern with looping enabled and at half intensity.
var active_pattern: GSActivePattern = patterns.play("My Pattern", feature, true, 0.5)
...
# Stops the looping pattern.
active_pattern.stop()
```

# Games Made Using gspot!
* [Mousegun](https://shinlalala.itch.io/mousegun) by [Shinlalala](https://shinlalala.itch.io/) - Mousegun is a retro FPS in which you take control of the titular character in an action filled adventure.

# Attribution
The gspot icon was created by [Kokota](https://thenounproject.com/kokota.icon/) and distributed under the [Creative Commons Attribution License (CC BY 3.0)](https://creativecommons.org/licenses/by/3.0/)
