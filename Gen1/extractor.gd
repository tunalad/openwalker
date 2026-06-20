class_name Gen1Extractor

static func compute_dvs() -> int:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var atk = rng.randi() % 16
	var defn = rng.randi() % 16
	var spd = rng.randi() % 16
	var spc = rng.randi() % 16
	return (atk << 12) | (defn << 8) | (spd << 4) | spc


static func _stat_calc(base: int, dv: int, level: int, is_hp: bool = false) -> int:
	var part: int = ((2 * base + dv) * level) / 100.0 as int
	if is_hp:
		return part + level + 10
	return part + 5


static func pkmn_from_catch(rom: PackedByteArray, species_internal_1: int, level: int,
		ot_id: int, _ot_str: PackedByteArray, _nick_str: PackedByteArray, moves: Array = []) -> PackedByteArray:
	species_internal_1 = int(species_internal_1)
	level = int(level)
	ot_id = int(ot_id)

	var nat_dex: int = rom[0x41024 + species_internal_1 - 1]
	var bs_off: int = Gen1Defs.BASE_STATS + (nat_dex - 1) * 28
	var hp_base: int = rom[bs_off + 1]
	var atk_base: int = rom[bs_off + 2]
	var def_base: int = rom[bs_off + 3]
	var spd_base: int = rom[bs_off + 4]
	var spc_base: int = rom[bs_off + 5]
	var type1: int = rom[bs_off + 6]
	var type2: int = rom[bs_off + 7]
	var catch_rate: int = rom[bs_off + 8]
	var growth: int = rom[bs_off + 19]

	var dvs: int = compute_dvs()
	var dv_atk: int = (dvs >> 12) & 0xF
	var dv_def: int = (dvs >> 8) & 0xF
	var dv_spd: int = (dvs >> 4) & 0xF
	var dv_spc: int = dvs & 0xF
	var dv_hp: int = ((dv_atk & 1) << 3) | ((dv_def & 1) << 2) | ((dv_spd & 1) << 1) | (dv_spc & 1)

	var max_hp: int = _stat_calc(hp_base, dv_hp, level, true)
	var _atk: int = _stat_calc(atk_base, dv_atk, level)
	var _def: int = _stat_calc(def_base, dv_def, level)
	var _spd: int = _stat_calc(spd_base, dv_spd, level)
	var _spc: int = _stat_calc(spc_base, dv_spc, level)

	var exp_val: int = Gen1Helpers.exp_for(growth, level)

	var move_ids: Array[int] = []
	if moves.size() > 0:
		for m in moves:
			move_ids.append(Gen1Helpers.move_id(rom, str(m)) if Gen1Helpers.move_id(rom, str(m)) >= 0 else 0)
	else:
		move_ids = [150, 0, 0, 0]
	while move_ids.size() < 4:
		move_ids.append(0)
	var pps: Array[int] = []
	for m in move_ids.slice(0, 4):
		pps.append(Gen1Helpers.move_pp(rom, m))

	var pk1: PackedByteArray = PackedByteArray()
	pk1.resize(33)
	pk1[0] = species_internal_1
	pk1[1] = (max_hp >> 8) & 0xFF
	pk1[2] = max_hp & 0xFF
	pk1[3] = level
	pk1[4] = 0
	pk1[5] = type1
	pk1[6] = type2
	pk1[7] = catch_rate
	pk1[8] = move_ids[0]
	pk1[9] = move_ids[1]
	pk1[10] = move_ids[2]
	pk1[11] = move_ids[3]
	pk1[12] = (ot_id >> 8) & 0xFF
	pk1[13] = ot_id & 0xFF
	pk1[14] = (exp_val >> 16) & 0xFF
	pk1[15] = (exp_val >> 8) & 0xFF
	pk1[16] = exp_val & 0xFF
	for i in range(17, 27):
		pk1[i] = 0
	pk1[27] = (dvs >> 8) & 0xFF
	pk1[28] = dvs & 0xFF
	pk1[29] = pps[0]
	pk1[30] = pps[1]
	pk1[31] = pps[2]
	pk1[32] = pps[3]

	return pk1
