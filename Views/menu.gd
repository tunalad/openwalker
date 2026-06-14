extends VBoxContainer

var rom_path: String
var sav_path: String

@onready var btn_select_rom: Button = $SelectRomSav/BtnSelectRom
@onready var btn_select_sav: Button = $SelectRomSav/BtnSelectSav
@onready var btn_load: Button = $SelectRomSav/BtnLoad

@onready var trainer_list: VBoxContainer = $ScrollContainer/TrainerList

@onready var fd_rom: FileDialog = $FD_Rom
@onready var fd_sav: FileDialog = $FD_Sav

@onready var walk_menu: VBoxContainer = $"../WalkMenu"

const BTN_TRAINER = preload("res://Components/btn_trainer.tscn")


func _ready() -> void:
	update_trainer_list()
	btn_load.disabled = true



func update_trainer_list() -> void:
	if not DirAccess.dir_exists_absolute(Global.trainers_path):
		DirAccess.make_dir_absolute(Global.trainers_path)
		
	var dir: DirAccess = DirAccess.open(Global.trainers_path)
	
	if !dir:
		return
	
	var trainers: Array = dir.get_directories()
	
	for child in trainer_list.get_children():
		child.free()
	
	for trainer in trainers:
		var trainer_data := Gen1Walker.trainer_status(Global.trainers_path+trainer)
		var btn: TextureButton = BTN_TRAINER.instantiate()
		
		btn.trainer_name = trainer_data["name"]
		btn.trainer_id = trainer_data["tid"]
		btn.game_version = trainer_data["game"]
		btn.watts = trainer_data["watts_left"]
		btn.rom_path = trainer_data["rom_path"]
		btn.sav_path = trainer_data["sav_path"]
		
		btn.pressed.connect(_on_btn_trainer_pressed.bind(trainer_data))
		trainer_list.add_child(btn)


func check_load() -> void:
	if rom_path and sav_path:
		btn_load.disabled = false
	else:
		btn_load.disabled = true


# -----------------------------------------------------------------------------


func _on_btn_select_rom_pressed() -> void:
	fd_rom.visible = true


func _on_btn_select_sav_pressed() -> void:
	fd_sav.visible = true


func _on_btn_load_pressed() -> void:
	var sav: PackedByteArray = Gen1Helpers.load_bin(sav_path)
	var info: Dictionary = Gen1Helpers.trainer_info(sav)
	var safe_name: String = info["name"].replace(" ", "_")
	var trainer_folder: String = Global.trainers_path + "%s-%05d" % [safe_name, info["id"]]
	
	Gen1Walker.init_trainer(trainer_folder, rom_path, sav_path)
	walk_menu.load_trainer(trainer_folder)
	self.visible = false


func _on_btn_trainer_pressed(data: Dictionary) -> void:
	var trainer_folder: String = Global.trainers_path + "%s-%05d" % [data["name"], data["tid"]]
	walk_menu.load_trainer(trainer_folder)
	self.visible = false


func _on_fd_rom_file_selected(path: String) -> void:
	rom_path = path
	btn_select_rom.text = path
	fd_rom.current_dir = path.get_base_dir()
	fd_sav.current_dir = path.get_base_dir()
	if Android.uri_permission:
		Android.uri_permission.takePersistablePermission(path)
	check_load()


func _on_fd_sav_file_selected(path: String) -> void:
	sav_path = path
	btn_select_sav.text = path
	fd_rom.current_dir = path.get_base_dir()
	fd_sav.current_dir = path.get_base_dir()
	if Android.uri_permission:
		Android.uri_permission.takePersistablePermission(path)
	check_load()
