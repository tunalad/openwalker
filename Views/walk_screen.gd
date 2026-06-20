extends VBoxContainer

@onready var trainer_bar: MarginContainer = $TrainerBar

@onready var l_steps: Label = $Pedometer/Info/L_Steps
@onready var l_route: Label = $Pedometer/L_Route
@onready var l_mon: Label = $Pedometer/L_Mon

@onready var l_watts: Label = $WalkerMenu/L_Watts

@onready var btn_step: Button = get_node("Pedometer/BtnStep++")

@onready var summary_screen: VBoxContainer = $"../Summary"


var steps: int = 0
var watts_collected: int = 0
var trainer_folder: String
var _last_synced_steps: int = 0
var _step_timer: Timer


func load_trainer(folder: String) -> void:
	Global.trainer_data = Gen1Walker.trainer_status(folder)
	trainer_folder = "%s-%05d" % [Global.trainer_data["name"], Global.trainer_data["tid"]]
	
	Global.rom = Gen1Helpers.load_bin(Global.trainer_data.get("rom_path", ""))
	Global.sav = Gen1Helpers.load_bin(Global.trainer_data.get("sav_path", ""))
	
	Global.route_data = Gen1Helpers.read_json(Global.trainers_path + trainer_folder + "/route.json")
	
	display_data()
	
	_setup_step_counter()


func display_data() -> void:
	trainer_bar.update_bar(
		Global.trainer_data["name"], 
		int(Global.trainer_data["tid"]), 
		Global.game_version_color(Global.trainer_data["game"]))
	
	l_steps.text = str(steps)
	l_watts.text = str(Global.trainer_data["watts_left"] + watts_collected)
	l_mon.text = Global.trainer_data["mon"]["nickname"]
	l_route.text = Global.route_data.get("name", "")
	
	self.visible = true


func _setup_step_counter() -> void:
	if _step_timer:
		return
	if not Android.background_plugin:
		btn_step.show()
		return
	
	if Android.background_plugin.isRunning():
		steps = Android.background_plugin.getSteps()
		watts_collected = steps / 20
		_last_synced_steps = steps
	else:
		Android.background_plugin.start("OpenWalker", "Running in the background.")
		steps = 0
		watts_collected = 0
		_last_synced_steps = 0
	
	l_steps.text = str(steps)
	l_watts.text = str(Global.trainer_data["watts_left"] + watts_collected)
	btn_step.hide()
	
	_step_timer = Timer.new()
	_step_timer.wait_time = 1.0
	_step_timer.timeout.connect(_on_step_timer)
	add_child(_step_timer)
	_step_timer.start()


func _on_step_timer() -> void:
	var count = Android.background_plugin.getSteps()
	var delta = count - _last_synced_steps
	_last_synced_steps = count
	for _i in range(delta):
		add_step()


func add_step() -> void:
	steps += 1
	
	# adding watts
	if steps > 0 and steps % 20 == 0:
		watts_collected += 1
		l_watts.text = str(Global.trainer_data["watts_left"] + watts_collected)
	
	# add happiness
	if steps > 0 and steps % 128 == 0:
		# if ylw
		if Gen1Helpers._is_yellow(Global.rom) and Global.trainer_data["mon"]["species"] == 84:
			if Global.trainer_data.has("ylw_happiness"):
				Global.trainer_data["ylw_happiness"] += 1
			if Global.trainer_data.has("ylw_mood"):
				Global.trainer_data["ylw_mood"] += 1
		
		# gen2 & later (yet to implement)
		if Global.trainer_data["mon"].has("happiness"):
			Global.trainer_data["mon"]["happiness"] += 1
	
	l_steps.text = str(steps)


func add_xp(amt: int) -> void:
	Global.trainer_data["mon"]["exp"] += amt


func _on_btn_return_pressed() -> void:
	if _step_timer:
		_step_timer.stop()
		remove_child(_step_timer)
		_step_timer = null
	
	if Android.background_plugin:
		Android.background_plugin.stop()
	
	var total = Android.background_plugin.getSteps() if Android.background_plugin else steps
	Global.trainer_data["steps"] += total
	add_xp(total)
	
	Global.trainer_data["watts_left"] += watts_collected
	Global.trainer_data["total_watts"] += watts_collected
	
	summary_screen.show_summary(
		Global.trainers_path + trainer_folder, 
		total, 
		watts_collected)
	
	self.visible = false


func _on_btn_step_pressed() -> void:
	add_step()
