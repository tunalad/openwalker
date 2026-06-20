class_name Gen1Helpers

static func decode_str(data: PackedByteArray, off: int, max_len: int = 11) -> String:
	var out: PackedStringArray = PackedStringArray()
	for i in range(max_len):
		if off + i >= data.size():
			break
		var b: int = data[off + i]
		if b == Gen1Defs.TERM:
			break
		if b >= 0x80 and b <= 0x99:
			out.append(char(65 + (b - 0x80)))
		elif b >= 0xF6 and b <= 0xFF:
			out.append(char(48 + (b - 0xF6)))
		elif b == Gen1Defs.SPACE_1 or b == Gen1Defs.SPACE_2:
			out.append(" ")
		else:
			break
	return "".join(out)


static func exp_for(growth: int, level: int) -> int:
	if level <= 1:
		return 0
	match growth:
		0:
			return level * level * level
		3:
			return int(1.2 * level * level * level - 15 * level * level + 100 * level - 140)
		4:
			return int(0.8 * level * level * level)
		5:
			return int(1.25 * level * level * level)
		_:
			return 0


static func _is_yellow(rom: PackedByteArray) -> bool:
	var title: PackedByteArray = rom.slice(0x134, 0x144)
	var s: String = title.get_string_from_ascii()
	return "YELLOW" in s


static func check_match(rom: PackedByteArray, sav: PackedByteArray) -> bool:
	var save_yellow: bool = sav[Gen1Defs.STARTER] == 0x54 or sav[Gen1Defs.YLW_FRIENDSHIP] != 0
	var rom_yellow: bool = _is_yellow(rom)
	return save_yellow == rom_yellow


static func fix_checksum(sav: PackedByteArray) -> void:
	var s: int = 0
	for i in range(Gen1Defs.CHK_START, Gen1Defs.CHK_OFS):
		s += sav[i]
	sav[Gen1Defs.CHK_OFS] = (~s) & 0xFF


static func base(sav: PackedByteArray, box_num: int) -> int:
	var curr: int = (sav[Gen1Defs.CURRENT_BOX] & 0x7F) + 1
	if box_num == curr:
		return Gen1Defs.BOX_ABS
	if box_num >= 1 and box_num <= 6:
		return Gen1Defs.PC_BANK[0] + (box_num - 1) * Gen1Defs.BOX_SIZE
	if box_num >= 7 and box_num <= 12:
		return Gen1Defs.PC_BANK[1] + (box_num - 7) * Gen1Defs.BOX_SIZE
	return -1


static func find_empty(sav: PackedByteArray, box_num: int) -> int:
	var b: int = base(sav, box_num)
	if b < 0:
		return -1
	for slot in range(Gen1Defs.BOX_CAP):
		var v: int = sav[b + 1 + slot]
		if v == 0 or v == 0xFF:
			return slot
	return -1


static func box_raw(sav: PackedByteArray, box_num: int, slot: int) -> Dictionary:
	var b: int = base(sav, box_num)
	if b < 0:
		return {}
	var sp: int = sav[b + 1 + slot]
	if sp == 0 or sp == 0xFF:
		return {}
	var body: int = b + Gen1Defs.BOX_HEAD + slot * Gen1Defs.BOX_POKE
	var pk1: PackedByteArray = sav.slice(body, body + Gen1Defs.BOX_POKE)
	if pk1[0] == 0 or pk1[0] == 0xFF or pk1[0] > 190:
		return {}
	var ot_off: int = b + Gen1Defs.BOX_OT() + slot * 11
	var nick_off: int = b + Gen1Defs.BOX_NICK() + slot * 11
	return {
		"pk1": pk1,
		"ot":  sav.slice(ot_off, ot_off + 11),
		"nick": sav.slice(nick_off, nick_off + 11),
	}


static func remove_box(sav: PackedByteArray, box_num: int, slot: int) -> void:
	var b: int = base(sav, box_num)
	if b < 0:
		return
	var box_count: int = sav[b]
	if slot >= box_count or slot < 0:
		return
	for src in range(slot + 1, box_count):
		var dst: int = src - 1
		var src_poke: int = b + Gen1Defs.BOX_HEAD + src * Gen1Defs.BOX_POKE
		var dst_poke: int = b + Gen1Defs.BOX_HEAD + dst * Gen1Defs.BOX_POKE
		for i in range(Gen1Defs.BOX_POKE):
			sav[dst_poke + i] = sav[src_poke + i]
		var src_ot: int = b + Gen1Defs.BOX_OT() + src * 11
		var dst_ot: int = b + Gen1Defs.BOX_OT() + dst * 11
		for i in range(11):
			sav[dst_ot + i] = sav[src_ot + i]
		var src_nick: int = b + Gen1Defs.BOX_NICK() + src * 11
		var dst_nick: int = b + Gen1Defs.BOX_NICK() + dst * 11
		for i in range(11):
			sav[dst_nick + i] = sav[src_nick + i]
		sav[b + 1 + dst] = sav[b + 1 + src]
	var last: int = box_count - 1
	var body: int = b + Gen1Defs.BOX_HEAD + last * Gen1Defs.BOX_POKE
	for i in range(Gen1Defs.BOX_POKE):
		sav[body + i] = 0
	var ot_off: int = b + Gen1Defs.BOX_OT() + last * 11
	for i in range(11):
		sav[ot_off + i] = 0x50
	var nick_off: int = b + Gen1Defs.BOX_NICK() + last * 11
	for i in range(11):
		sav[nick_off + i] = 0x50
	sav[b + 1 + last] = 0xFF
	sav[b] = box_count - 1


static func write_box(sav: PackedByteArray, box_num: int, slot: int,
		pk1_33: PackedByteArray, ot_11: PackedByteArray, nick_11: PackedByteArray) -> void:
	var b: int = base(sav, box_num)
	if b < 0:
		return
	var body: int = b + Gen1Defs.BOX_HEAD + slot * Gen1Defs.BOX_POKE
	for i in range(Gen1Defs.BOX_POKE):
		sav[body + i] = pk1_33[i]
	var ot_offset: int = b + Gen1Defs.BOX_OT() + slot * 11
	for i in range(11):
		sav[ot_offset + i] = ot_11[i]
	var nick_offset: int = b + Gen1Defs.BOX_NICK() + slot * 11
	for i in range(11):
		sav[nick_offset + i] = nick_11[i]
	sav[b + 1 + slot] = pk1_33[0]
	var box_count: int = sav[b]
	if slot >= box_count:
		sav[b] = slot + 1
		box_count = slot + 1
	for i in range(box_count, Gen1Defs.BOX_CAP):
		sav[b + 1 + i] = 0xFF


static func trainer_info(sav: PackedByteArray) -> Dictionary:
	return {
		"name": decode_str(sav, Gen1Defs.SAVE_BASE, 8),
		"id": (sav[Gen1Defs.TID] << 8) | sav[Gen1Defs.TID + 1],
	}


static func game_version(rom: PackedByteArray, sav: PackedByteArray) -> String:
	if sav[Gen1Defs.STARTER] == 0x54 or sav[Gen1Defs.YLW_FRIENDSHIP] != 0:
		return "Yellow"
	if _is_yellow(rom):
		return "Yellow"
	return "RGB"


static func species_name(rom: PackedByteArray, idx: int) -> String:
	var off: int = Gen1Defs.NAME_TABLE_Y if _is_yellow(rom) else Gen1Defs.NAME_TABLE_BR
	return decode_str(rom, off + (idx - 1) * 10, 10)


static func dex_num(rom: PackedByteArray, idx: int) -> int:
	var off: int = Gen1Defs.CONV_TABLE_Y if _is_yellow(rom) else Gen1Defs.CONV_TABLE_BR
	return rom[off + idx - 1]


static func growth_rate(rom: PackedByteArray, national_dex: int) -> int:
	return rom[Gen1Defs.BASE_STATS + (national_dex - 1) * 28 + 19]


static func load_bin(path: String) -> PackedByteArray:
	if Engine.has_singleton("UriPermissionPlugin"):
		var bytes = Engine.get_singleton("UriPermissionPlugin").readUri(path)
		if bytes:
			return bytes as PackedByteArray

	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var data: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	return data

static func save_bin(path: String, data: PackedByteArray) -> void:
	if Engine.has_singleton("UriPermissionPlugin") and path.begins_with("content://"):
		Engine.get_singleton("UriPermissionPlugin").writeUri(path, data)
		return

	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_buffer(data)
	f.close()

static func write_json(path: String, data: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()


static func read_json(path: String):
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text: String = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	return parsed if parsed != null else {}


static func _encode_char(c: String) -> int:
	var code: int = c.unicode_at(0)
	if code >= 65 and code <= 90:
		return 0x80 + (code - 65)
	if code >= 97 and code <= 122:
		return 0xA0 + (code - 97)
	if code >= 48 and code <= 57:
		return 0xF6 + (code - 48)
	match c:
		" ":  return 0x7F
		"'":  return 0xE0
		"-":  return 0xE3
		"?":  return 0xE6
		"!":  return 0xE7
		".":  return 0xE8
		"(":  return 0x9A
		")":  return 0x9B
		":":  return 0x9C
	return 0x7F


static func encode_str(s: String, max_len: int = 11) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(max_len)
	for i in range(min(s.length(), max_len)):
		out[i] = _encode_char(s[i])
	for i in range(s.length(), max_len):
		out[i] = Gen1Defs.TERM
	return out


const TYPE_NAMES: Dictionary = {
	0x00: "Normal",   0x01: "Fighting", 0x02: "Flying",
	0x03: "Poison",   0x04: "Ground",   0x05: "Rock",
	0x07: "Bug",      0x08: "Ghost",
	0x14: "Fire",     0x15: "Water",    0x16: "Grass",
	0x17: "Electric", 0x18: "Psychic",  0x19: "Ice",
	0x1A: "Dragon",
}


static func move_id(rom: PackedByteArray, name: String) -> int:
	var target: String = name.to_upper()
	var tbl: int = Gen1Defs.MOVE_NAME_TABLE_Y if _is_yellow(rom) else Gen1Defs.MOVE_NAME_TABLE_BR
	var off: int = tbl
	for mid in range(1, 166):
		var n: String = decode_str(rom, off, 99)
		if n.to_upper() == target:
			return mid
		var skip: int = 0
		while skip < 13 and off + skip < rom.size() and rom[off + skip] != Gen1Defs.TERM:
			skip += 1
		off += skip + 1
	return -1


static func move_pp(rom: PackedByteArray, id: int) -> int:
	return rom[Gen1Defs.MOVE_DATA_TABLE + (id - 1) * 6 + 5]


static func build_dex_to_internal(rom: PackedByteArray) -> Dictionary:
	var off: int = Gen1Defs.CONV_TABLE_Y if _is_yellow(rom) else Gen1Defs.CONV_TABLE_BR
	var m: Dictionary = {}
	for i in range(190):
		m[rom[off + i]] = i + 1
	return m


static func internal_idx(rom: PackedByteArray, national_dex: int, dex_to_internal: Dictionary = {}) -> int:
	if dex_to_internal.is_empty():
		dex_to_internal = build_dex_to_internal(rom)
	return dex_to_internal.get(national_dex, -1)


static func find_first_empty(sav: PackedByteArray) -> Dictionary:
	for box_num in range(1, 13):
		var slot: int = find_empty(sav, box_num)
		if slot >= 0:
			return {"box": box_num, "slot": slot}
	return {}


static func _tm_name(id: int) -> String:
	if id >= 193 and id <= 204:
		return "TM" + str(id - 192).pad_zeros(2)
	if id >= 205 and id <= 209:
		return "HM" + str(id - 204).pad_zeros(2)
	return ""


static func list_items(rom: PackedByteArray) -> Array[Dictionary]:
	var off: int = Gen1Defs.ITEM_NAME_TABLE_Y if _is_yellow(rom) else Gen1Defs.ITEM_NAME_TABLE_BR
	var items: Array[Dictionary] = []
	for id in range(1, Gen1Defs.NUM_ITEMS + 1):
		var name: String = decode_str(rom, off, Gen1Defs.ITEM_NAME_LENGTH)
		items.append({"id": id, "name": name})
		while off < rom.size() and rom[off] != Gen1Defs.TERM:
			off += 1
		if off < rom.size():
			off += 1
	for id in range(193, 210):
		var tn: String = _tm_name(id)
		if not tn.is_empty():
			items.append({"id": id, "name": tn})
	return items


static func item_id(rom: PackedByteArray, name: String) -> int:
	var target: String = name.to_upper()

	for id in range(193, 210):
		var tn: String = _tm_name(id)
		if not tn.is_empty() and tn.to_upper() == target:
			return id

	var off: int = Gen1Defs.ITEM_NAME_TABLE_Y if _is_yellow(rom) else Gen1Defs.ITEM_NAME_TABLE_BR
	for id in range(1, Gen1Defs.NUM_ITEMS + 1):
		var item_name: String = decode_str(rom, off, Gen1Defs.ITEM_NAME_LENGTH)
		if item_name.to_upper() == target:
			return id
		while off < rom.size() and rom[off] != Gen1Defs.TERM:
			off += 1
		if off < rom.size():
			off += 1
	return -1


static func read_pc_items(sav: PackedByteArray) -> Array[Dictionary]:
	var count: int = sav[Gen1Defs.PC_ITEMS]
	if count >= 0xFF or count > Gen1Defs.PC_ITEM_CAPACITY:
		return []
	var items: Array[Dictionary] = []
	var addr: int = Gen1Defs.PC_ITEMS + 1
	for i in range(count):
		var idx: int = addr + i * 2
		items.append({"id": sav[idx], "qty": sav[idx + 1]})
	return items


static func write_pc_items(sav: PackedByteArray, items: Array) -> void:
	var count: int = mini(items.size(), Gen1Defs.PC_ITEM_CAPACITY)
	sav[Gen1Defs.PC_ITEMS] = count
	var addr: int = Gen1Defs.PC_ITEMS + 1
	for i in range(count):
		var idx: int = addr + i * 2
		sav[idx] = items[i]["id"] as int
		sav[idx + 1] = items[i]["qty"] as int
	var term: int = addr + count * 2
	sav[term] = 0xFF
	var zero_start: int = term + 1
	var slot_end: int = addr + Gen1Defs.PC_ITEM_CAPACITY * 2 + 1
	for i in range(zero_start, slot_end):
		sav[i] = 0


static func give_item(rom: PackedByteArray, sav: PackedByteArray, name: String, qty: int = 1) -> void:
	var iid: int = item_id(rom, name)
	if iid < 0:
		return
	var items: Array[Dictionary] = read_pc_items(sav)
	for it in items:
		if it["id"] as int != iid or qty == 0:
			continue
		var room: int = 99 - (it["qty"] as int)
		if room <= 0:
			continue
		var add: int = mini(room, qty)
		it["qty"] = (it["qty"] as int) + add
		qty -= add
	while qty > 0 and items.size() < Gen1Defs.PC_ITEM_CAPACITY:
		var add: int = mini(99, qty)
		items.append({"id": iid, "qty": add})
		qty -= add
	write_pc_items(sav, items)
