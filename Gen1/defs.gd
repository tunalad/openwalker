class_name Gen1Defs

const SAVE_BASE     = 0x2598
const TID           = 0x2605
const CHK_START     = 0x2598
const CHK_OFS       = 0x3523
const CURRENT_BOX   = 0x284C
const STARTER       = 0x29C3

const YLW_FRIENDSHIP = 0x271C
const YLW_MOOD       = 0x271D

const BOX_ABS   = 0x30C0
const BOX_SIZE  = 0x0600
const BOX_CAP   = 20
const BOX_HEAD  = 22
const BOX_POKE  = 33

static func BOX_OT()   -> int:  return BOX_HEAD + BOX_POKE * BOX_CAP
static func BOX_NICK() -> int:  return BOX_OT() + 11 * BOX_CAP

const PC_BANK     = [0x4000, 0x6000]

const NAME_TABLE_BR = 0x1C21E
const CONV_TABLE_BR = 0x41024
const NAME_TABLE_Y  = 0xE8000
const CONV_TABLE_Y  = 0x0410B1
const BASE_STATS    = 0x383DE

const TERM    = 0x50
const SPACE_1 = 0x4E
const SPACE_2 = 0x4F
