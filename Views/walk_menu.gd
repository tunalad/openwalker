extends VBoxContainer

@onready var trainer_bar: MarginContainer = $TrainerBar

# box nodes
@onready var box_selector: OptionButton = $Boxes/BoxesList
@onready var mon_grid: GridContainer = $Boxes/InBox

#mon info nodes
@onready var mon_image: TextureRect = $MonInfo/VBoxContainer/HBoxContainer/MonImage
@onready var l_nickname: Label = $MonInfo/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/L_Nickname
@onready var l_gender: Label = $MonInfo/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/L_Gender
@onready var l_level: Label = $MonInfo/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/L_Level
@onready var l_species: Label = $MonInfo/VBoxContainer/HBoxContainer/VBoxContainer/L_Species
@onready var l_item: Label = $MonInfo/VBoxContainer/HBoxContainer/VBoxContainer/L_Item
@onready var l_ribbons: Label = $MonInfo/VBoxContainer/HBoxContainer/VBoxContainer/L_Ribbons
@onready var exp_bar: TextureProgressBar = $MonInfo/VBoxContainer/ExpBar

@onready var routes_list: OptionButton = $VBoxContainer/RoutesList
@onready var l_route_text: Label = $VBoxContainer/L_RouteText

@onready var btn_stroll: Button = $BtnStroll

@onready var walk_screen: VBoxContainer = $"../WalkScreen"

const BTN_MON = preload("res://Components/btn_box_cell.tscn")

var boxes_data: Array[Dictionary]

var box: Dictionary
var selected_mon: Dictionary = {}
var trainer_folder: String
var routes_found: Array

func display_data():
	trainer_bar.update_bar(
		Global.trainer_data["name"], 
		int(Global.trainer_data["tid"]), 
		Global.game_version_color(Global.trainer_data["game"]))
	
	trainer_folder = "%s-%05d" % [Global.trainer_data["name"], Global.trainer_data["tid"]]
	
	fill_box()
	fill_mon_grid(0)
	fill_routes()
	update_mon_info()


func update_mon_info():
	var mon_to_display = selected_mon
	
	l_nickname.text = mon_to_display.get("nickname", "")
	l_level.text = "Lv. %s" % [ mon_to_display.get("level", "") ]
	
	var species_id = mon_to_display.get("species", -1)
	l_species.text = Gen1Helpers.species_name(Global.rom, species_id) if species_id != -1 else ""
	
	exp_bar.min_value = mon_to_display.get("min_exp", 0)
	exp_bar.max_value = mon_to_display.get("max_exp", 1)
	exp_bar.value = mon_to_display.get("exp", 0)
	
	if "gender" in mon_to_display:
		l_gender.text = mon_to_display["gender"]
		l_gender.visible = true
	else:
		l_gender.visible = false
	
	if "holding" in mon_to_display:
		l_item.text = mon_to_display["holding"]
		l_item.visible = true
	else:
		l_item.visible = false
	
	if "ribbons" in mon_to_display:
		l_ribbons.text = mon_to_display["ribbons"]
		l_ribbons.visible = true
	else:
		l_ribbons.visible = false
	pass
	
	if selected_mon.is_empty():
		btn_stroll.disabled = true
	else:
		btn_stroll.disabled = false


func fill_box():
	box_selector.clear()
	for b in boxes_data:
		#box_selector.add_item(box["name"])
		box_selector.add_item("%s (%d)" % [b["name"], b["mons"].filter(func(m): return m!= null).size()])
		#for mon in box["mons"]:
		#	if mon:
		#		print(mon)


func load_trainer(folder: String) -> void:
	Global.trainer_data = Gen1Walker.trainer_status(folder)
	
	Global.rom = Gen1Helpers.load_bin(Global.trainer_data["rom_path"])
	Global.sav = Gen1Helpers.load_bin(Global.trainer_data["sav_path"])
	
	boxes_data = Gen1Walker.list_pokemon(Global.sav, Global.rom)
	self.visible = true
	display_data()


func fill_mon_grid(index: int):
	box = boxes_data[index]
	
	if len(boxes_data) == 12:
		mon_grid.columns = 4
	else:
		mon_grid.columns = 6
	
	for child in mon_grid.get_children():
		child.free()
	
	for mon in box["mons"]:
		var cell_btn = BTN_MON.instantiate()
		
		if mon:
			cell_btn.mon_nickname = str(mon["nickname"])
		
		#cell_btn.pressed.connect(_on_btn_mon_pressed.bind(str(mon)))
		cell_btn.pressed.connect(_on_btn_mon_pressed.bind(mon))
		mon_grid.add_child(cell_btn)


func fill_routes() -> void:
	routes_list.clear()
	routes_found.clear()
	
	var dir: DirAccess = DirAccess.open(Global.routes_path)
	
	if !dir:
		return
	
	var routes: Array = dir.get_files()
	
	for route in routes:
		var json_as_dict = Gen1Helpers.read_json(Global.routes_path + route)
		if json_as_dict:
			routes_found.append(json_as_dict)
	
	routes_found.sort_custom(func(a, b): return a.get("position", 0) < b.get("position", 0))
	
	for route_dict in routes_found:
		routes_list.add_item(route_dict["name"])
	
	routes_list.selected = 0
	_on_routes_list_item_selected(routes_list.selected)


# -----------------------------------------------------------------------------


func _on_boxes_list_item_selected(index: int) -> void:
	fill_mon_grid(index)


func _on_btn_mon_pressed(data):
	selected_mon = data if data else {}
	update_mon_info()


func _on_btn_stroll_pressed() -> void:
	var box_num = boxes_data.find_custom(func(b): return b.get("name") == box["name"])
	var mon_slot = box["mons"].find(selected_mon)
	
	var result := Gen1Walker.export_pokemon(Global.rom, Global.sav, Global.trainers_path+trainer_folder, box_num+1, mon_slot)
	if result.has("error"):
		printerr(result["error"])
		return
	Global.sav = result["sav"]
	
	var route_file = FileAccess.open(Global.trainers_path+trainer_folder+"/route.json", FileAccess.WRITE)
	if route_file:
		route_file.store_string(JSON.stringify(Global.route_data))
		route_file.close()
	
	walk_screen.load_trainer(Global.trainers_path+trainer_folder)
	self.visible = false
	print("switch to walker scren")


func _on_routes_list_item_selected(index: int) -> void:
	l_route_text.text = routes_found[index]["description"]
	Global.route_data = routes_found[index]
