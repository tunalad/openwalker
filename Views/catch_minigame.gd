extends VBoxContainer

@onready var walker_menu: VBoxContainer = $"../WalkerMenu"


@onready var l_catch_name: Label = $MinigameStats/MonLeft/L_Name
@onready var l_catch_hp: Label = $MinigameStats/MonLeft/L_HP

@onready var l_us_name: Label = $MinigameStats/MonRight/L_Name
@onready var l_us_hp: Label = $MinigameStats/MonRight/L_HP


var wild_mon: Dictionary


func display_data():
	get_wild_mon()
	
	var dex_to_int = Gen1Helpers.build_dex_to_internal(Global.rom)
	var idx = Gen1Helpers.internal_idx(Global.rom, wild_mon["species"], dex_to_int)
	
	l_catch_name.text = Gen1Helpers.species_name(Global.rom, idx)
	l_us_name.text = Global.trainer_data["mon"]["nickname"]
	
	self.visible = true
	walker_menu.visible = false

func get_wild_mon():
	var wild_mons: Array = Global.route_data["mons"]
	wild_mon = wild_mons.pick_random()


func _on_btn_back_pressed() -> void:
	self.visible = false
	walker_menu.visible = true
