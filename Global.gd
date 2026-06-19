extends Node

var trainers_path: String = "user://trainers/"
var trainer_data: Dictionary

var routes_path: String = "res://Routes/"
var route_data: Dictionary

var rom: PackedByteArray
var sav: PackedByteArray


func game_version_label(gamever: String) -> String:
	match (gamever.to_upper()):
		"RGB": 
			return "Blue/Green"
		"YELLOW": 
			return "Yellow"
		_: 
			return "???"


func game_version_color(version: String):
	match(version.to_upper()):
		"YELLOW":
			return "YELLOW"
		"RGB":
			return "BLUE"
		_: 
			return "GRAY"


func clear_trainer_session():
	trainer_data = {}
	route_data = {}
	
	rom = []
	sav = []
