extends TextureButton

var mon_nickname: String

@onready var label: Label = $MarginContainer/Label


func _ready() -> void:
	label.text = mon_nickname
