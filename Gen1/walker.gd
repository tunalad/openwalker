class_name Gen1Walker

static func _versions_match(a: String, b: String) -> bool:
	if a == b:
		return true
	if a != "Yellow" and b != "Yellow":
		return true
	return false


static func _check_mismatch(folder: String, trainer: Dictionary, ver: String) -> bool:
	var json_path: String = folder.path_join("trainer.json")
	if not FileAccess.file_exists(json_path):
		return false
	var old: Dictionary = Gen1Helpers.read_json(json_path)
	return old.get("name") != trainer["name"] or old.get("tid") != trainer["id"] or not _versions_match(old.get("game", ""), ver)


static func _trainer_dict(rom: PackedByteArray, sav: PackedByteArray, rom_path: String = "", sav_path: String = "") -> Dictionary:
	var trainer: Dictionary = Gen1Helpers.trainer_info(sav)
	var ver: String = Gen1Helpers.game_version(rom, sav)
	var data: Dictionary = {
		"name": trainer["name"],
		"tid": trainer["id"],
		"game": ver,
		"rom_path": rom_path,
		"sav_path": sav_path,
		"steps": 0,
		"total_watts": 0,
		"watts_left": 0,
		"last_access": 0,
	}
	if ver.to_lower() == "yellow":
		data["ylw_happiness"] = sav[Gen1Defs.YLW_FRIENDSHIP]
		data["ylw_mood"] = sav[Gen1Defs.YLW_MOOD]
	return data


static func init_trainer(folder: String, rom_path: String, sav_path: String) -> Dictionary:
	var rom: PackedByteArray = Gen1Helpers.load_bin(rom_path)
	var sav: PackedByteArray = Gen1Helpers.load_bin(sav_path)
	if rom.is_empty() or sav.is_empty():
		return {"error": "Failed to load ROM or save file"}
	if not Gen1Helpers.check_match(rom, sav):
		return {"error": "ROM and save don't match — one is Yellow, the other isn't"}
	var json_path: String = folder.path_join("trainer.json")
	if FileAccess.file_exists(json_path):
		return {"error": "Trainer already exists"}
	DirAccess.make_dir_recursive_absolute(folder)
	var data: Dictionary = _trainer_dict(rom, sav, rom_path, sav_path)
	Gen1Helpers.write_json(json_path, data)
	return {}


static func list_pokemon(sav: PackedByteArray, rom: PackedByteArray) -> Array[Dictionary]:
	var boxes: Array[Dictionary] = []
	for box_num in range(1, 13):
		var name: String = "Box " + str(box_num)
		var mons: Array = []
		mons.resize(Gen1Defs.BOX_CAP)
		var b: int = Gen1Helpers.base(sav, box_num)
		if b >= 0 and b < sav.size() and sav[b] != 0 and sav[b] <= Gen1Defs.BOX_CAP:
			for slot in range(Gen1Defs.BOX_CAP):
				var species_byte: int = sav[b + 1 + slot]
				if species_byte == 0 or species_byte == 0xFF:
					continue
				var raw: Dictionary = Gen1Helpers.box_raw(sav, box_num, slot)
				if raw.is_empty():
					continue
				var pk1_33: PackedByteArray = raw["pk1"] as PackedByteArray
				var nick_raw: PackedByteArray = raw["nick"] as PackedByteArray
				var nick: String = Gen1Helpers.decode_str(nick_raw, 0)
				
				var exp_val: int = (pk1_33[14] << 16) | (pk1_33[15] << 8) | pk1_33[16]
				var dex: int = Gen1Helpers.dex_num(rom, pk1_33[0])
				var growth: int = Gen1Helpers.growth_rate(rom, dex)
				var min_exp: int = Gen1Helpers.exp_for(growth, pk1_33[3])
				var max_exp: int = Gen1Helpers.exp_for(growth, pk1_33[3] + 1) - 1
				
				
				mons[slot] = {
					"species": pk1_33[0],
					"species_name": Gen1Helpers.species_name(rom, pk1_33[0]),
					"nickname": nick,
					"level": pk1_33[3],
					"exp": exp_val,
					"min_exp": min_exp,
					"max_exp": max_exp,
				}
		boxes.append({"name": name, "mons": mons})
	return boxes


static func export_pokemon(rom: PackedByteArray, sav: PackedByteArray,
		folder: String, box_num: int, slot: int) -> Dictionary:
	var raw: Dictionary = Gen1Helpers.box_raw(sav, box_num, slot)
	if raw.is_empty():
		return {"error": "Slot is empty"}

	var pk1_33: PackedByteArray = raw["pk1"] as PackedByteArray
	var ot_raw: PackedByteArray = raw["ot"] as PackedByteArray
	var nick_raw: PackedByteArray = raw["nick"] as PackedByteArray
	var species: int = pk1_33[0]
	var mon_lv: int = pk1_33[3]
	var dex: int = Gen1Helpers.dex_num(rom, species)
	var sname: String = Gen1Helpers.species_name(rom, species)
	var nick: String = Gen1Helpers.decode_str(nick_raw, 0)
	var ver: String = Gen1Helpers.game_version(rom, sav)
	var trainer: Dictionary = Gen1Helpers.trainer_info(sav)

	if _check_mismatch(folder, trainer, ver):
		return {"error": "Trainer mismatch"}

	var exp_val: int = (pk1_33[14] << 16) | (pk1_33[15] << 8) | pk1_33[16]
	var bin_data: PackedByteArray = PackedByteArray()
	bin_data.append_array(pk1_33)
	bin_data.append_array(ot_raw)
	bin_data.append_array(nick_raw)

	var growth: int = Gen1Helpers.growth_rate(rom, dex)
	var max_exp: int = Gen1Helpers.exp_for(growth, mon_lv + 1) - 1

	var out: Dictionary = {
		"species": species,
		"species_name": sname,
		"nickname": nick,
		"level": mon_lv,
		"exp": exp_val,
		"max_exp": max_exp,
		"game": ver,
		"box_name": "Box " + str(box_num)
	}
	if ver.to_lower() == "yellow":
		out["ylw_happiness"] = sav[Gen1Defs.YLW_FRIENDSHIP]
		out["ylw_mood"] = sav[Gen1Defs.YLW_MOOD]

	DirAccess.make_dir_recursive_absolute(folder)
	Gen1Helpers.save_bin(folder.path_join("onastroll.bin"), bin_data)

	var json_path: String = folder.path_join("trainer.json")
	var data: Dictionary
	if FileAccess.file_exists(json_path):
		data = Gen1Helpers.read_json(json_path)
	else:
		data = {
			"name": trainer["name"],
			"tid": trainer["id"],
			"game": ver,
			"steps": 0,
			"total_watts": 0,
			"watts_left": 0,
			"last_access": 0,
		}

	data["mon"] = {
		"species": species,
		"species_name": sname,
		"nickname": nick,
		"level": mon_lv,
		"exp": exp_val,
		"max_exp": max_exp,
	}
	if ver.to_lower() == "yellow":
		data["ylw_happiness"] = out["ylw_happiness"]
		data["ylw_mood"] = out["ylw_mood"]
	data["last_access"] = int(Time.get_unix_time_from_system())

	Gen1Helpers.write_json(json_path, data)
	Gen1Helpers.remove_box(sav, box_num, slot)
	Gen1Helpers.fix_checksum(sav)
	var sav_path: String = data.get("sav_path", "")
	if not sav_path.is_empty():
		Gen1Helpers.save_bin(sav_path, sav)
	out["sav"] = sav
	return out


static func return_pokemon(rom: PackedByteArray, sav: PackedByteArray, folder: String) -> Dictionary:
	var bin_path: String = folder.path_join("onastroll.bin")
	var json_path: String = folder.path_join("trainer.json")
	if not FileAccess.file_exists(bin_path):
		return {"error": "No stroll data found"}
	if not FileAccess.file_exists(json_path):
		return {"error": "No trainer data found"}

	var data: Dictionary = Gen1Helpers.read_json(json_path)
	var trainer: Dictionary = Gen1Helpers.trainer_info(sav)
	var ver: String = Gen1Helpers.game_version(rom, sav)
	if _check_mismatch(folder, trainer, ver):
		return {"error": "Trainer mismatch"}

	var stroll_result: Dictionary = {}
	if data.has("mon") and FileAccess.file_exists(bin_path):
		var mon: Dictionary = data["mon"] as Dictionary
		var bin_data: PackedByteArray = Gen1Helpers.load_bin(bin_path)
		if bin_data.size() >= 55:
			var new_exp: int = mini(mon["exp"] as int, mon["max_exp"] as int)
			bin_data[14] = (new_exp >> 16) & 0xFF
			bin_data[15] = (new_exp >> 8) & 0xFF
			bin_data[16] = new_exp & 0xFF

			var pk1_33: PackedByteArray = bin_data.slice(0, 33)
			var ot_11: PackedByteArray = bin_data.slice(33, 44)
			var nick_11: PackedByteArray = bin_data.slice(44, 55)

			var target: Dictionary = Gen1Helpers.find_first_empty(sav)
			if not target.is_empty():
				Gen1Helpers.write_box(sav, target["box"], target["slot"], pk1_33, ot_11, nick_11)
				var returned_label: String = Gen1Helpers.decode_str(nick_11, 0)
				if returned_label.is_empty():
					returned_label = Gen1Helpers.species_name(rom, pk1_33[0])
				stroll_result = {
					"label": returned_label,
					"box": target["box"],
					"box_name": "Box " + str(target["box"]),
					"slot": target["slot"],
					"exp": new_exp,
					"max_exp": mon["max_exp"] as int,
				}
				DirAccess.remove_absolute(bin_path)
		data.erase("mon")

	var caught: Array = data.get("caught", [])
	data.erase("caught")
	if caught.size() > 0:
		var dex_map: Dictionary = Gen1Helpers.build_dex_to_internal(rom)
		var ot_enc: PackedByteArray = Gen1Helpers.encode_str(data["name"] as String)
		var nick_cache: Dictionary = {}
		for entry in caught:
			var ndex: int = int(entry["species"])
			var sid: int = Gen1Helpers.internal_idx(rom, ndex, dex_map)
			if sid < 0:
				continue
			var lv: int = int(entry["level"])
			var nick: String = entry.get("nickname", "")
			var nick_key: String = nick + "|" + str(sid)
			var nick_enc: PackedByteArray
			if nick_cache.has(nick_key):
				nick_enc = nick_cache[nick_key] as PackedByteArray
			else:
				nick_enc = Gen1Helpers.encode_str(nick if not nick.is_empty() else Gen1Helpers.species_name(rom, sid))
				nick_cache[nick_key] = nick_enc
			var moves: Array = entry.get("moves", [])
			var pk1: PackedByteArray = Gen1Extractor.pkmn_from_catch(rom, sid, lv, data["tid"] as int, ot_enc, nick_enc, moves)
			var target: Dictionary = Gen1Helpers.find_first_empty(sav)
			if not target.is_empty():
				Gen1Helpers.write_box(sav, target["box"], target["slot"], pk1, ot_enc, nick_enc)

	var found: Array = data.get("found", [])
	data.erase("found")
	for entry in found:
		Gen1Helpers.give_item(rom, sav, entry["name"] as String)

	if data.has("ylw_happiness"):
		sav[Gen1Defs.YLW_FRIENDSHIP] = data["ylw_happiness"] as int
		sav[Gen1Defs.YLW_MOOD] = data["ylw_mood"] as int
	Gen1Helpers.fix_checksum(sav)
	var sav_path: String = data.get("sav_path", "")
	if not sav_path.is_empty():
		Gen1Helpers.save_bin(sav_path, sav)

	data["last_access"] = int(Time.get_unix_time_from_system())
	Gen1Helpers.write_json(json_path, data)

	stroll_result["sav"] = sav
	return stroll_result


static func trainer_status(folder: String) -> Dictionary:
	var json_path: String = folder.path_join("trainer.json")
	if not FileAccess.file_exists(json_path):
		return {"error": "No trainer data found"}
	var data: Dictionary = Gen1Helpers.read_json(json_path)
	var out: Dictionary = {
		"name": data.get("name", "?"),
		"tid": data.get("tid", 0),
		"game": data.get("game", "?"),
		"steps": data.get("steps", 0),
		"total_watts": data.get("total_watts", 0),
		"watts_left": data.get("watts_left", 0),
	}
	out["rom_path"] = data.get("rom_path", "")
	out["sav_path"] = data.get("sav_path", "")
	if data.has("ylw_happiness"):
		out["ylw_happiness"] = data["ylw_happiness"]
		out["ylw_mood"] = data["ylw_mood"]
	if data.has("mon"):
		out["mon"] = data["mon"]
	return out


static func catch_pokemon(folder: String, mon_data: Dictionary) -> Dictionary:
	if not mon_data.has("species") or not mon_data.has("level"):
		return {"error": "mon_data must be a dict with 'species' and 'level'"}
	var json_path: String = folder.path_join("trainer.json")
	if not FileAccess.file_exists(json_path):
		return {"error": "No trainer data found"}
	var data: Dictionary = Gen1Helpers.read_json(json_path)
	if not data.has("caught"):
		data["caught"] = []
	data["caught"].append(mon_data)
	Gen1Helpers.write_json(json_path, data)
	return {"ok": true, "caught": data["caught"].size()}


static func list_items_json(rom: PackedByteArray) -> Array:
	return Gen1Helpers.list_items(rom)


static func list_pc(rom: PackedByteArray, sav: PackedByteArray) -> Array[Dictionary]:
	var items: Array[Dictionary] = Gen1Helpers.read_pc_items(sav)
	var name_map: Dictionary = {}
	for entry in Gen1Helpers.list_items(rom):
		name_map[entry["id"] as int] = entry["name"] as String
	var out: Array[Dictionary] = []
	for it in items:
		out.append({"id": it["id"], "name": name_map.get(it["id"] as int, "?"), "qty": it["qty"]})
	return out


static func give_item_to_pc(rom: PackedByteArray, sav: PackedByteArray, name: String, qty: int = 1) -> Dictionary:
	Gen1Helpers.give_item(rom, sav, name, qty)
	Gen1Helpers.fix_checksum(sav)
	return {"sav": sav}
