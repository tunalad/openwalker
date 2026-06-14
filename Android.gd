extends Node

var background_plugin
var notify
var uri_permission
var is_android: bool


func _ready():
	is_android = OS.get_name() == "Android"
	if is_android:
		background_plugin = Engine.get_singleton("BackgroundKeepAlive")
		notify = Engine.get_singleton("AndroidNotify")
		uri_permission = Engine.get_singleton("UriPermissionPlugin")

		#if notify and not notify.isPermissionGranted():
		#	notify.requestPermission()
		#	await get_tree().create_timer(0.5).timeout
		if background_plugin and not background_plugin.isPermissionGranted():
			background_plugin.requestPermission()
