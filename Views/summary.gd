extends VBoxContainer

@onready var label: Label = $Label
@onready var btn_home: Button = $BtnHome

@onready var main: Control = $"../../.."


func show_summary(trainer_path: String, steps: int, watts: int) -> void:
	self.visible = true
	
	var mon = Global.trainer_data["mon"]
	
	Gen1Helpers.write_json(trainer_path + "/trainer.json", Global.trainer_data)
	var result := Gen1Walker.return_pokemon(Global.rom, Global.sav, trainer_path)
	
	if result.has("error"):
		printerr(result["error"])
		label.text = result["error"]
		return
	
	DirAccess.remove_absolute(trainer_path+"/route.json")
	
	var route_name: String = "%s Summary:" % [ Global.route_data["name"] ]
	
	var session_steps: String = "Walked %d steps" % [ steps ]
	var session_watts: String = "Collected %dW" % [ watts ]
	
	var total_steps: String = "Total steps made: %d" % [ Global.trainer_data["steps"] ]
	var total_watts: String = "Total watts collected: %d" % [ Global.trainer_data["total_watts"] ]
	
	var xp_earned: String = "%s's EXP: %d/%d" % [ mon["nickname"], result["exp"], result["max_exp"] ]
	var placed_at: String = "%s is placed in %s, slot %d" % [ mon["nickname"], result["box_name"], result["slot"] ]
	
	var happiness: String = ""
	var ylw_mood: String = ""
	
	if Global.trainer_data["mon"].has(["happiness"]):
		happiness = "happiness: %d" % [ Global.trainer_data["mon"]["happiness"] ]
	
	if  Gen1Helpers._is_yellow(Global.rom) and Global.trainer_data["mon"]["species"] == 84:
		if Global.trainer_data.has("ylw_happiness"):
			happiness = "ylw_happiness: %d/255" % [ Global.trainer_data["ylw_happiness"] ]
		if Global.trainer_data.has("ylw_mood"):
			ylw_mood = "\nylw_mood: %d/255" % [ Global.trainer_data["ylw_mood"] ]
	
	label.text = "%s\n\n%s\n%s\n\n%s\n%s\n\n%s\n%s\n%s%s" % [
		route_name,
		session_steps, session_watts, 
		total_steps, total_watts, 
		xp_earned, placed_at,
		happiness, ylw_mood
		]


func _on_btn_home_pressed() -> void:
	Global.clear_trainer_session()
	main.reset_to_menu()
