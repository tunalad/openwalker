extends MarginContainer

@onready var trainer_ver_color: ColorRect = $TrainerVerColor
@onready var l_name: Label = $TrainerData/VBoxContainer/L_Name
@onready var l_tid: Label = $TrainerData/VBoxContainer/L_TID

func update_bar(trainer_name: String, tid: int, color: String) -> void:
	l_name.text =  "Name: %s" % [ trainer_name ]
	l_tid.text =   "IDNo. %05d" % [ tid ]
	trainer_ver_color.color = color
