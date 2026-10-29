class_name GameState
extends RefCounted

const SAVE_PATH = "user://progress.json"
const INITIAL_COINS = 100
const REWARD = 25
const LETTER_COST = 15
const CLUE_COST = 10
var data: Dictionary = {"version":1,"name":"","avatar":0,"tutorial":false,"coins":INITIAL_COINS,"completed":[],"active":{},"sound":true,"motion":true}

func load_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if parsed is Dictionary and parsed.get("version",0) == 1:
			for key in data:
				if parsed.has(key):
					data[key] = parsed[key]
			data.coins = maxi(0,int(data.coins))
			if not data.completed is Array: data.completed = []
			if not data.active is Dictionary: data.active = {}

func save() -> bool:
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify(data))
	return true

static func upper_tr(value: String) -> String:
	return value.strip_edges().replace("i","İ").replace("ı","I").to_upper()

func spend(amount: int) -> bool:
	if int(data.coins) < amount: return false
	data.coins -= amount
	save()
	return true

func complete(id: int) -> bool:
	data.active.erase(str(id))
	if id in data.completed:
		save()
		return false
	data.completed.append(id)
	data.coins += REWARD
	save()
	return true
