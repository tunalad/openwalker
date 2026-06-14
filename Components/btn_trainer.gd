extends TextureButton

@export var trainer_name: String
@export var trainer_id: int
@export_enum("BLUE", "GREEN", "RED", "YELLOW") var game_version: String
@export var watts: int = 0

@export var rom_path: String
@export var sav_path: String

@onready var l_game_ver_name: RichTextLabel = $MarginContainer/VBoxContainer/GameVerColor/L_GameVerName
@onready var game_ver_color: ColorRect = $MarginContainer/VBoxContainer/GameVerColor
@onready var l_t_name_id: Label = $MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/L_TNameID
@onready var l_watts: Label = $MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/L_Watts


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	game_ver_color.color = Global.game_version_color(game_version.to_upper())
	l_game_ver_name.text = "  [color=black][b]Ver. %s[/b]" % [ Global.game_version_label(game_version) ]
	l_t_name_id.text = "TRAINER: %s\nIDNo. %05d" % [trainer_name, trainer_id]
	l_watts.text = "WATT: %d" % [ watts ]
