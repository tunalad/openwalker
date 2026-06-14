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


static func species_name(rom: PackedByteArray, internal_idx: int) -> String:
	var off: int = Gen1Defs.NAME_TABLE_Y if _is_yellow(rom) else Gen1Defs.NAME_TABLE_BR
	return decode_str(rom, off + (internal_idx - 1) * 10, 10)


static func dex_num(rom: PackedByteArray, internal_idx: int) -> int:
	var off: int = Gen1Defs.CONV_TABLE_Y if _is_yellow(rom) else Gen1Defs.CONV_TABLE_BR
	return rom[off + internal_idx - 1]


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
