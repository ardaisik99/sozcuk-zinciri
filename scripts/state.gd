class_name GameState
extends RefCounted

const SAVE_PATH = "user://progress.json"
const INITIAL_COINS = 100
const REWARD = 25
const LETTER_COST = 15
const CLUE_COST = 10
var data: Dictionary = {"version":1,"content_version":2,"input_rules_version":3,"hint_refund_pending":0,"name":"","tutorial":false,"coins":INITIAL_COINS,"completed":[],"active":{},"sound":true,"motion":true}

func load_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if parsed is Dictionary and restore(parsed): save()

func restore(parsed: Dictionary) -> bool:
	if int(parsed.get("version",0)) != 1: return false
	for key in data:
		if parsed.has(key): data[key] = parsed[key].duplicate(true) if parsed[key] is Array or parsed[key] is Dictionary else parsed[key]
	data.coins = maxi(0,int(data.coins))
	if not data.completed is Array: data.completed = []
	if not data.active is Dictionary: data.active = {}
	# JSON numbers are floats. Array.has() distinguishes int from float,
	# which otherwise breaks completed badges, unlocks and the next level.
	var completed_ids: Array = []
	for id in data.completed:
		if int(id) > 0 and not int(id) in completed_ids: completed_ids.append(int(id))
	data.completed = completed_ids
	for round_data in data.active.values():
		if round_data is Dictionary and round_data.get("revealed",[]) is Array:
			round_data.revealed = round_data.get("revealed",[0]).map(func(at): return int(at))
	if int(parsed.get("content_version",1)) < 2: data.active = {}
	data.content_version = 2
	var migrated = int(parsed.get("input_rules_version",0)) < 3
	if migrated:
		# Refund known joker expenditure in unfinished v2 rounds once. Keep
		# their revealed cells and all completed-level identities intact.
		var refund = 0
		for round_data in data.active.values():
			if not round_data is Dictionary: continue
			var unique: Array = []
			for at in round_data.get("revealed",[0]):
				if int(at) > 0 and not int(at) in unique: unique.append(int(at))
			refund += unique.size()*LETTER_COST
			if round_data.get("clues",{}) is Dictionary: refund += round_data.get("clues",{}).size()*CLUE_COST
		data.coins += refund
		data.hint_refund_pending = int(data.get("hint_refund_pending",0))+refund
	data.input_rules_version = 3
	return migrated

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
