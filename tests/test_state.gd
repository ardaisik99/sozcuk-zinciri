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
	# The reported FINCANI case: visible cells and acceptance must agree.
	var coffee = levels[1]
	assert(WordRules.resolve("incani",coffee,1,[0,6]).letters == "FİNCANI")
	assert(WordRules.matches("incani",coffee,1,[0,6]))
	assert(WordRules.matches("İNCANX",coffee,1,[0,6]))
	assert(WordRules.matches("",coffee,1,[0,1,2,3,4,5,6]))
	assert(WordRules.matches("fincani",coffee,1))
	assert(WordRules.matches("fincanı",coffee,1))
	assert(WordRules.matches("FI\u0307NCANI",coffee,1))
	assert(not WordRules.matches("FİNCANIP",coffee,1))
	var checked = 0
	for level in levels:
		for index in range(1,level.words.size()):
			var surface: String = level.forms[index]
			for bits in range(1 << (surface.length()-1)):
				var mask: Array = [0]
				var missing = ""
				for i in range(1,surface.length()):
					if bits & (1 << (i-1)): mask.append(i)
					else: missing += surface[i]
				for value in [surface,surface.substr(1),missing,level.words[index],surface+"X","", "YANLIŞ"]:
					var resolved = WordRules.resolve(value,level,index,mask)
					assert(WordRules.matches(value,level,index,mask) == resolved.accepted)
					assert((resolved.letters == surface) == resolved.accepted)
				assert(WordRules.matches(missing,level,index,mask))
				checked += 1
	var legacy = {"version":1,"content_version":2,"name":"Oyuncu","coins":5,"completed":[1],"active":{"2":{"cursor":1,"revealed":[0,1,2,3,4,5,6],"clues":{"1":true}}}}
	var restored = MemoryState.new()
	assert(restored.restore(legacy))
	assert(restored.data.coins == 105)
	var round_trip = MemoryState.new()
	assert(not round_trip.restore(JSON.parse_string(JSON.stringify(restored.data))))
	assert(1 in round_trip.data.completed)
	assert(typeof(round_trip.data.completed[0]) == TYPE_INT)
	assert(6 in round_trip.data.active["2"].revealed)
	assert(restored.data.completed == [1])
	assert(not restored.restore(restored.data.duplicate(true)))
	assert(restored.data.coins == 105)
	var orders: Array = []
	for level in levels:
		orders.append(int(level.order))
		assert(level.difficulty == ("Kolay" if level.order <= 8 else "Orta" if level.order <= 16 else "Zor"))
	orders.sort()
	assert(orders == range(1,25))
	print("PASS: "+str(checked)+" hint masks, full/rest/blank-only input, I variants, visible/accepted invariant, refund-once and difficulty ordering.")
	print("PASS: Turkish casing, insufficient balance, 24 valid chains.")
	quit()
