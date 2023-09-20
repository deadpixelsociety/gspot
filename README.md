# gspot

![gspot logo](logo.png) 

A Godot 4 Plugin for interacting with intimate haptic devices via the [buttplug.io](https://buttplug.io/) interface.

**This plugin provides a buttplug.io standard compatibile client implementation. To interact with devices a server is also required. See [Intiface Central](https://intiface.com/central/).**

Review the [protocol specification](https://buttplug-spec.docs.buttplug.io/docs/spec) for an idea of how to interact with this plugin and proper device flow.

A [client control panel](addons/gspot/ui/gscontrol_panel.tscn) is provided for testing devices and getting familiar with the client.

## Quick Example
```gdscript
# Get the client from the scene tree.
var client = $GSClient
# Connect to the device server.
client.start("localhost", 12345)
# Wait for connection.
await client.client_connection_changed
# Request the device list from the server.
client.request_device_list()
# Wait for devices to arrive.
await client.client_device_list_received
# Grab the first device.
var device = client.get_device(0)
# Grab the first feature. We'll assume it's a vibrate function or something fun.
# You will want something more robust.
var feature = device.features[0]
# Send the feature to the server, triggering it's action at max (1.0) power for 5 seconds.
client.send_feature(feature, 1.0, 5.0)
```

# Attribution
The gspot icon was created by [Kokota](https://thenounproject.com/kokota.icon/) and distributed under the [Creative Commons Attribution License (CC BY 3.0)](https://creativecommons.org/licenses/by/3.0/)
