extends Control

@export var max_aspect: float = 0.75

@onready var aspect_ratio_container: AspectRatioContainer = $AspectRatioContainer

@onready var menu: VBoxContainer = $AspectRatioContainer/MarginContainer/Menu
@onready var walk_menu: VBoxContainer = $AspectRatioContainer/MarginContainer/WalkMenu
@onready var walk_screen: VBoxContainer = $AspectRatioContainer/MarginContainer/WalkScreen
@onready var summary: VBoxContainer = $AspectRatioContainer/MarginContainer/Summary


func _ready():
	_set_aspect()
	reset_to_menu()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var back_event = InputEventAction.new()
		back_event.action = "ui_cancel"
		back_event.pressed = true
		Input.parse_input_event(back_event)


func reset_to_menu() -> void:
	menu.visible = true
	walk_menu.visible = false
	walk_screen.visible = false
	summary.visible = false
	_resume_active_stroll()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if walk_menu.visible:
			menu.visible = true
			walk_menu.visible = false
			
			walk_menu.selected_mon = {}
			menu.update_trainer_list()


func _set_aspect():
	var vp_rect = get_viewport_rect()
	var aspect = vp_rect.size.x / vp_rect.size.y
	
	aspect = min(max_aspect, aspect)
	
	aspect_ratio_container.ratio = aspect


func _on_resized() -> void:
	if is_node_ready():
		_set_aspect()


func _resume_active_stroll() -> void:
	print("if we find onastroll.bin, switch to walk_screen")
	if not DirAccess.dir_exists_absolute(Global.trainers_path):
		DirAccess.make_dir_absolute(Global.trainers_path)
		
	var dir: DirAccess = DirAccess.open(Global.trainers_path)
	
	if !dir:
		return
	
	var trainers: Array = dir.get_directories()
	
	for trainer in trainers:
		if FileAccess.file_exists(Global.trainers_path+trainer+"/onastroll.bin"):
			print(trainer + "is strolling already!")
			menu.visible = false
			walk_menu.visible = false
			walk_screen.load_trainer(Global.trainers_path+trainer)
