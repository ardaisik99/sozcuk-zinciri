extends SceneTree

class MemoryState extends GameState:
	func save() -> bool:
		return true

func _initialize() -> void:
	assert(GameState.upper_tr("kaşık") == "KAŞIK")
	assert(GameState.upper_tr("  incir  ") == "İNCİR")
	assert(GameState.upper_tr("ışık") == "IŞIK")
	var state = MemoryState.new()
	assert(state.data.coins == 100)
	# Avoid touching a real user's save: test economy in memory.
	state.data.coins = 10
	assert(not state.spend(15))
	assert(state.data.coins == 10)
	state.data.coins = 100
	assert(state.spend(15))
	assert(state.data.coins == 85)
	assert(state.complete(1))
	assert(state.data.coins == 110)
	state.data.active["1"] = {"cursor":2}
	assert(not state.complete(1))
	assert(state.data.coins == 110)
	assert(not state.data.active.has("1"))
	var levels = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	assert(levels.size() == 24)
	var ids: Array = []
	for level in levels:
		assert(not level.id in ids)
		ids.append(level.id)
		assert(level.words.size() in [4,5])
		assert(level.links.size() == level.words.size()-1)
		assert(level.hints.size() == level.words.size())
		assert(level.forms.size() == level.words.size())
		for index in range(1,level.words.size()):
			assert(WordRules.matches(level.forms[index],level,index))
			assert(WordRules.matches(level.forms[index].substr(1),level,index))
			assert(WordRules.matches(level.words[index],level,index))
			assert(WordRules.matches(level.links[index-1],level,index))
		for word in level.words:
			assert(word == GameState.upper_tr(word))
			assert(word.length() >= 2 and word.length() <= 8)
	var box = {"words":["BİR","KUTU"],"forms":["BİR","KUTU"],"links":["Bir kutu"]}
	assert(WordRules.matches("utu",box,1))
	assert(not WordRules.matches("kutuş",box,1))
	assert(not WordRules.matches("deniz bardağı",levels[0],1))
	assert(WordRules.display("ardağı","BARDAĞI",[0]) == "BARDAĞI")
	print("PASS: Turkish casing, insufficient balance, 24 valid chains.")
	quit()
