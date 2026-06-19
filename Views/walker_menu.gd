extends VBoxContainer



func _on_btn_radar_pressed() -> void:
	print("catching mons minigame")
	print("mons that we can find on this route: ")
	for mon in Global.route_data["mons"]:
		print(mon)

func _on_btn_dowsing_pressed() -> void:
	print("finding items minigame")
	print("items that we can find on this route: ")
	for item in Global.route_data["items"]:
		print(item)


func _on_btn_found_pressed() -> void:
	print("list what we found and caught so far")
