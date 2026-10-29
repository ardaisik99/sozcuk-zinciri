extends SceneTree

class MemoryState extends GameState:
	var writes = 0
	func save() -> bool:
		writes += 1
		return true

func _initialize() -> void:
	call_deferred("run")

func answer(game: Control, word: String) -> void:
	game.entry.text = word
	game.submit_answer()

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.5).timeout
	var memory = MemoryState.new()
	memory.data.name = "Deneme"
	game.state = memory
	game.show_tutorial_intro()
	game.start_level(1,"tutorial")
	game.reveal_letter()
	game.reveal_clue()
	assert(memory.data.coins == 100)
	answer(game,"kaşık")
	answer(game,"oyun")
	answer(game,"hava")
	assert(game.screen == "win")
	assert(memory.data.tutorial)
	assert(memory.data.completed.is_empty())
	game.show_home()
	game.start_level(1)
	answer(game,"YANLIŞ")
	assert(game.cursor == 1)
	assert(memory.data.coins == 100)
	game.reveal_letter()
	assert(memory.data.coins == 85)
	assert(game.revealed.size() == 2)
	game.reveal_clue()
	game.reveal_clue()
	assert(memory.data.coins == 75)
	game.leave_game()
	game.start_level(1)
	assert(game.revealed.size() == 2)
	assert(game.clues.has("1"))
	answer(game,"KAŞIK")
	answer(game,"OYUN")
	answer(game,"HAVA")
	assert(memory.data.coins == 100)
	assert(1 in memory.data.completed)
	game.start_level(1)
	answer(game,"KAŞIK")
	answer(game,"OYUN")
	answer(game,"HAVA")
	assert(memory.data.coins == 100)
	game.start_level(24)
	for word in ["lamba","ışık","hız","sınır"]: answer(game,word)
	assert(game.screen == "win")
	assert(memory.data.coins == 125)
	game.show_levels()
	game.show_profile()
	game.show_online()
	game.show_party_setup()
	game.party_inputs[1].text = "Arkadaş"
	game.begin_party()
	assert(game.screen == "party_handoff")
	assert(game.party_names.size() == 2)
	game.start_level(game.party_queue[0],"party")
	game.reveal_letter()
	game.reveal_clue()
	var words = game.current.words.duplicate()
	for i in range(1,words.size()): answer(game,words[i])
	assert(game.screen == "party_turn_end")
	assert(game.party_scores[0] == 105)
	assert(memory.data.coins == 125)
	game.start_level(game.party_queue[1],"party")
	game.party_started = Time.get_ticks_msec()-91000
	game._party_tick()
	assert(game.screen == "party_turn_end")
	game.show_party_results()
	assert(game.screen == "party_results")
	print("PASS: tutorial, wrong answer, paid/repeated clues, resume, reward once, 5-word chain, menus, party scoring and timeout.")
	game.queue_free()
	await process_frame
	quit()
