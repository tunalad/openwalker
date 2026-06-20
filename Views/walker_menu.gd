extends VBoxContainer


@onready var catch_minigame: VBoxContainer = $"../CatchMinigame"


func _on_btn_radar_pressed() -> void:
	print("catching mons minigame")
	print("do grass minigame (maybe not? xd)")
	print("do catch minigame")
	print("mons that we can find on this route: ")
	
	catch_minigame.display_data()


func _on_btn_dowsing_pressed() -> void:
	print("finding items minigame")
	print("items that we can find on this route: ")
	for item in Global.route_data["items"]:
		print(item)


func _on_btn_found_pressed() -> void:
	print("list what we found and caught so far")
