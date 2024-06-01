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
# Grab the first feature. We'll assume it's a vibrate function or something fun.
# You will want something more robust.
var feature = device.features[0]
# Send the feature to the server, triggering it's action at max (1.0) power for 5 seconds.
GSClient.send_feature(feature, 1.0, 5.0)
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
```

## Project Settings
Project settings are now available to configure how the GSClient identifies itself to buttplug.io servers, and if raw device commands are available.
* ```gspot/client/client_name``` - The client name. Defaults to GSClient.
* ```gspot/client/client_version``` - The client version. Currently defaults to 2.0.
* ```gspot/client/enable_raw_commands``` - Determines if the raw command methods on GSClient are available or not. Defaults to false. Hidden by advanced settings.

You can set these values in the Project Settings UI under the Gspot category. If you do not see them, try disabling and re-enabling the plugin.

These values are also accessible via the GSClient.
```gdscript
GSClient.get_client_name() # GSClient
GSClient.get_client_version() # 2.0
GSClient.get_client_string() # GSClient v2.0
GSClient.is_raw_command_enabled() # false
```

# Apps Made Using gspot!
* [vibecheck](https://deadpixelsociety.itch.io/vibecheck) - An app that adds Twitch integration to your toys.
* [godohmygod](https://github.com/deadpixelsociety/godohmygod) - An editor plugin for Godot that adds toy support while coding.

# Games Made Using gspot!
* [Mousegun](https://shinlalala.itch.io/mousegun) by [Shinlalala](https://shinlalala.itch.io/) - Mousegun is a retro FPS in which you take control of the titular character in an action filled adventure.

# Attribution
The gspot icon was created by [Kokota](https://thenounproject.com/kokota.icon/) and distributed under the [Creative Commons Attribution License (CC BY 3.0)](https://creativecommons.org/licenses/by/3.0/)
