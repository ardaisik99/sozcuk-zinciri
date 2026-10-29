extends Control

const CREAM = Color("faf7f0")
const INK = Color("35264c")
const MUTED = Color("81758e")
const PURPLE = Color("7654bf")
const LILAC = Color("eee7f8")
const YELLOW = Color("f8d875")
const CORAL = Color("ef9277")
const GREEN = Color("53765b")
const CATEGORIES = ["Mutfak", "Doğa", "Günlük Yaşam"]
const CATEGORY_ART = ["tea", "plant", "book"]
const AVATARS = ["Mor kuş", "Çay dostu", "Filiz", "Kitap kurdu"]

var state = GameState.new()
var levels: Array = []
var screen = ""
var page: VBoxContainer
var scroll: ScrollContainer
var overlay: Control
var font: Font
var bold: Font
var current: Dictionary
var cursor = 1
var revealed: Array = [0]
var clues: Dictionary = {}
var entry: LineEdit
var feedback: Label
var active_tiles: Array = []
var mode = "solo"
var busy = false
var filter_category = "Tümü"
var profile_avatar = 0
var profile_name: LineEdit
var party_names: Array = []
var party_scores: Array = []
var party_index = 0
var party_rounds = 1
var party_queue: Array = []
var party_inputs: Array = []
var party_started = 0
var party_remaining = 90
var party_clock: Timer
var clock_label: Label
var sparkle_tweens: Array = []
var web_entries: Dictionary = {}
var web_input_callback: JavaScriptObject
var web_input: JavaScriptObject

func _ready() -> void:
	RenderingServer.set_default_clear_color(CREAM)
	Engine.max_fps = 30
	var source_font = load("res://assets/Nunito.ttf")
	source_font.fallbacks = [load("res://assets/Symbols.ttf")]
	var regular = FontVariation.new()
	regular.base_font = source_font
	regular.fallbacks = [load("res://assets/Symbols.ttf")]
	regular.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):500}
	font = regular
	var variation = FontVariation.new()
	variation.base_font = source_font
	variation.fallbacks = [load("res://assets/Symbols.ttf")]
	variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):800}
	bold = variation
	var base_theme = Theme.new()
	base_theme.default_font = font
	base_theme.default_font_size = 16
	theme = base_theme
	if OS.has_feature("web"):
		web_input = JavaScriptBridge.get_interface("wordInput")
		web_input_callback = JavaScriptBridge.create_callback(_web_input_changed)
		web_input.changed = web_input_callback
		resized.connect(func(): call_deferred("_position_web_input"))
	state.load_save()
	levels = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	party_clock = Timer.new()
	party_clock.wait_time = 1.0
	party_clock.timeout.connect(_party_tick)
	add_child(party_clock)
	show_loading()
	await get_tree().create_timer(0.35).timeout
	if str(state.data.name).is_empty(): show_profile_setup()
	elif not state.data.tutorial: show_tutorial_intro()
	else: show_home()

func style(color: Color, radius: int = 20, border: Color = Color.TRANSPARENT, width: int = 0) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(width)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

func text_label(value: String, size_px: int = 16, color: Color = INK, heavy: bool = false) -> Label:
	var l = Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size",size_px)
	l.add_theme_color_override("font_color",color)
	if heavy: l.add_theme_font_override("font",bold)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func label_to(parent: Node, value: String, size_px: int = 16, color: Color = INK, heavy: bool = false) -> Label:
	var l = text_label(value,size_px,color,heavy)
	if parent is HBoxContainer or (parent is PanelContainer and parent.get_parent() is HBoxContainer):
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
	parent.add_child(l)
	return l

func button_to(parent: Node, value: String, fn: Callable, bg: Color = PURPLE, fg: Color = Color.WHITE, height: int = 56) -> Button:
	var b = Button.new()
	b.text = value
	b.custom_minimum_size.y = height
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_override("font",bold)
	b.add_theme_font_size_override("font_size",17)
	b.add_theme_color_override("font_color",fg)
	b.add_theme_color_override("font_hover_color",fg)
	b.add_theme_color_override("font_pressed_color",fg)
	b.add_theme_color_override("font_focus_color",fg)
	b.add_theme_stylebox_override("normal",style(bg,18))
	b.add_theme_stylebox_override("hover",style(bg.lightened(0.06),18))
	b.add_theme_stylebox_override("pressed",style(bg.darkened(0.06),18))
	b.add_theme_stylebox_override("focus",style(bg,18,YELLOW,2))
	b.add_theme_stylebox_override("disabled",style(Color("e9e5ec"),18))
	b.add_theme_color_override("font_disabled_color",MUTED)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(fn)
	parent.add_child(b)
	return b

func gap(parent: Node, height: int) -> void:
	var c = Control.new()
	c.custom_minimum_size.y = height
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)

func row_to(parent: Node, separation: int = 10) -> HBoxContainer:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation",separation)
	parent.add_child(h)
	return h

func box_to(parent: Node, separation: int = 10) -> VBoxContainer:
	var b = VBoxContainer.new()
	b.add_theme_constant_override("separation",separation)
	parent.add_child(b)
	return b

func panel_to(parent: Node, color: Color = Color.WHITE, radius: int = 22) -> PanelContainer:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel",style(color,radius))
	parent.add_child(p)
	return p

func image_to(parent: Node, asset: String, dimensions: Vector2) -> TextureRect:
	var p = TextureRect.new()
	p.texture = load("res://assets/"+asset+".webp")
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p.custom_minimum_size = dimensions
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p

func reset_page(id: String, nav: bool = false) -> void:
	if OS.has_feature("web") and web_input != null:
		web_input.close()
	web_entries.clear()
	screen = id
	busy = false
	for tw in sparkle_tweens:
		if is_instance_valid(tw): tw.kill()
	sparkle_tweens.clear()
	for child in get_children():
		if child != party_clock:
			remove_child(child)
			child.queue_free()
	if id != "game": party_clock.stop()
	var bg = ColorRect.new()
	bg.color = CREAM
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var layout = VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation",0)
	add_child(layout)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	layout.add_child(scroll)
	if OS.has_feature("web"):
		scroll.get_v_scroll_bar().value_changed.connect(func(_v): _position_web_input())
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left",24)
	margin.add_theme_constant_override("margin_right",24)
	margin.add_theme_constant_override("margin_top",24)
	margin.add_theme_constant_override("margin_bottom",24)
	scroll.add_child(margin)
	page = box_to(margin,14)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if nav:
		var nav_panel = panel_to(layout,CREAM,0)
		var nav_row = row_to(nav_panel,8)
		button_to(nav_row,"Oyna",show_home,LILAC if id == "home" else CREAM,PURPLE,48)
		button_to(nav_row,"Bölümler",show_levels,LILAC if id == "levels" else CREAM,PURPLE,48)
		button_to(nav_row,"Profil",show_profile,LILAC if id == "profile" else CREAM,PURPLE,48)
	var over = Control.new()
	over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(over)
	overlay = over
	if OS.has_feature("web"):
		JavaScriptBridge.eval("document.getElementById('canvas').setAttribute('aria-label','Sözcük Zinciri — "+id+"');",true)

func header(title: String = "", back: Callable = Callable()) -> void:
	var h = row_to(page)
	if back.is_valid():
		var b = button_to(h,"‹",back,LILAC,PURPLE,46)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.custom_minimum_size.x = 46
		b.tooltip_text = "Geri dön"
	var l = label_to(h,title,20,INK,true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var coin = panel_to(h,Color("fff0bb"),16)
	label_to(coin,"●  "+str(int(state.data.coins)),16,Color("8a641c"),true)

func show_loading() -> void:
	reset_page("loading")
	gap(page,110)
	image_to(page,"mascot",Vector2(260,260))
	var t = label_to(page,"Sözcük\nZinciri",42,INK,true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var s = label_to(page,"Kelimeler birleşir, keşif başlar.",17,MUTED)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gap(page,30)
	var p = ProgressBar.new()
	p.custom_minimum_size.y = 6
	p.show_percentage = false
	p.value = 100
	p.add_theme_stylebox_override("background",style(LILAC,3))
	p.add_theme_stylebox_override("fill",style(PURPLE,3))
	page.add_child(p)

func create_entry(parent: Node, placeholder: String, maximum: int = 20) -> LineEdit:
	var e = LineEdit.new()
	e.placeholder_text = placeholder
	e.max_length = maximum
	e.custom_minimum_size.y = 58
	e.add_theme_font_size_override("font_size",20)
	e.add_theme_color_override("font_color",INK)
	e.add_theme_color_override("font_placeholder_color",MUTED)
	e.add_theme_color_override("caret_color",PURPLE)
	e.add_theme_stylebox_override("normal",style(Color.WHITE,16,Color("e2d9ed"),1))
	e.add_theme_stylebox_override("focus",style(Color.WHITE,16,PURPLE,2))
	e.virtual_keyboard_enabled = not OS.has_feature("web")
	e.virtual_keyboard_show_on_focus = true
	e.select_all_on_focus = true
	parent.add_child(e)
	if OS.has_feature("web"):
		_register_web_input(e)
	return e

func _register_web_input(field: LineEdit) -> void:
	await get_tree().process_frame
	if not is_instance_valid(field) or not field.is_inside_tree(): return
	var id = str(field.get_instance_id())
	web_entries[id] = field
	web_input.add(id,field.text,field.placeholder_text,field.max_length)
	_position_web_input()

func _position_web_input() -> void:
	if web_input == null or size.x <= 0 or size.y <= 0: return
	for id in web_entries:
		var field = web_entries[id]
		if not is_instance_valid(field): continue
		var r = field.get_global_rect()
		web_input.position(id,r.position.x/size.x,r.position.y/size.y,r.size.x/size.x,r.size.y/size.y)

func _web_input_changed(args: Array) -> void:
	if args.size() < 3 or not web_entries.has(str(args[0])): return
	var field = web_entries[str(args[0])]
	if not is_instance_valid(field): return
	field.text = str(args[1])
	field.text_changed.emit(field.text)
	if str(args[2]) == "submit":
		web_input.blur()
		field.text_submitted.emit(field.text)

func show_profile_setup() -> void:
	reset_page("onboarding")
	gap(page,12)
	label_to(page,"SÖZCÜK ZİNCİRİ",14,PURPLE,true)
	image_to(page,"mascot",Vector2(210,210))
	label_to(page,"Tanışalım mı?",34,INK,true)
	label_to(page,"Her güzel zincir bir sözcükle başlar.\nSeninkine bir de isim ekleyelim.",17,MUTED)
	gap(page,8)
	label_to(page,"Sana nasıl seslenelim?",15,INK,true)
	profile_name = create_entry(page,"Adın veya takma adın",16)
	profile_name.text = str(state.data.name)
	label_to(page,"Küçük bir yol arkadaşı seç",15,INK,true)
	avatar_picker(page)
	gap(page,8)
	var go = button_to(page,"Hadi başlayalım  →",_finish_profile)
	go.disabled = profile_name.text.strip_edges().length() < 2
	profile_name.text_changed.connect(func(s): go.disabled = s.strip_edges().length() < 2)
	profile_name.text_submitted.connect(func(_s): _finish_profile())
	label_to(page,"Hesap gerekmez. İlerlemen bu cihazda saklanır.",13,MUTED)

func avatar_picker(parent: Node) -> void:
	var h = row_to(parent,8)
	for i in range(4):
		var b = Button.new()
		b.custom_minimum_size = Vector2(76,76)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("normal",style(LILAC if i == profile_avatar else Color.WHITE,20,PURPLE if i == profile_avatar else Color("e6dfee"),2))
		b.add_theme_stylebox_override("hover",style(LILAC,20,PURPLE,2))
		b.add_theme_stylebox_override("focus",style(LILAC,20,PURPLE,2))
		b.tooltip_text = AVATARS[i]
		h.add_child(b)
		var art = image_to(b,["mascot","tea","plant","book"][i],Vector2.ZERO)
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.offset_left = 8
		art.offset_right = -8
		art.offset_top = 8
		art.offset_bottom = -8
		b.pressed.connect(func():
			profile_avatar = i
			for j in range(h.get_child_count()):
				h.get_child(j).add_theme_stylebox_override("normal",style(LILAC if j == i else Color.WHITE,20,PURPLE if j == i else Color("e6dfee"),2)))

func _finish_profile() -> void:
	var clean = profile_name.text.strip_edges()
	if clean.length() < 2: return
	state.data.name = clean
	state.data.avatar = profile_avatar
	state.save()
	DisplayServer.virtual_keyboard_hide()
	show_tutorial_intro()

func show_tutorial_intro() -> void:
	reset_page("tutorial_intro")
	gap(page,16)
	label_to(page,"MİNİK BİR ISINMA",13,PURPLE,true)
	label_to(page,"Bir sözcük,\nbir sonrakinin ipucu.",32,INK,true)
	image_to(page,"tea",Vector2(150,140))
	var card = panel_to(page,Color.WHITE)
	var b = box_to(card,10)
	label_to(b,"ÇAY   →   K A _ _ _",25,PURPLE,true)
	label_to(b,"Çay kaşığı! Cevabı ek almadan yaz: KAŞIK.",17)
	label_to(b,"Sonra “kaşık oyunu” ve “oyun havası”… Her iki komşu sözcük anlamlı bir tamlama oluşturur.",15,MUTED)
	var steps = box_to(page,14)
	label_to(steps,"01   İlk harf ve kutu sayısı sana yol gösterir.",15)
	label_to(steps,"02   Cevabı telefonunun klavyesiyle yaz.",15)
	label_to(steps,"03   Takılırsan harf veya anlam ipucu al.",15)
	button_to(page,"Deneyerek öğren  →",func(): start_level(1,"tutorial"))
	label_to(page,"Bu denemede jokerler ücretsiz. Rahatça keşfet!",13,MUTED)

func next_level_id() -> int:
	for lev in levels:
		if not lev.id in state.data.completed: return int(lev.id)
	return 1

func category_done(category: String) -> int:
	var n = 0
	for l in levels:
		if l.category == category and l.id in state.data.completed: n += 1
	return n

func show_home() -> void:
	reset_page("home",true)
	var h = row_to(page)
	var mark = label_to(h,"sözcük\nzinciri",22,PURPLE,true)
	mark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var coins = panel_to(h,Color("fff0bb"),16)
	label_to(coins,"●  "+str(int(state.data.coins)),16,Color("8a641c"),true)
	var avatar = button_to(h,str(state.data.name).substr(0,1).to_upper(),show_profile,LILAC,PURPLE,46)
	avatar.size_flags_horizontal = Control.SIZE_SHRINK_END
	avatar.custom_minimum_size.x = 46
	gap(page,4)
	label_to(page,"Merhaba, "+str(state.data.name)+"!",16,MUTED)
	label_to(page,"Bugün ne keşfedelim?",28,INK,true)
	var hero = panel_to(page,LILAC,26)
	var vb = box_to(hero,8)
	var hero_row = row_to(vb,0)
	var copy = box_to(hero_row,7)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_to(copy,"BİR KELİMEYLE BAŞLA",11,PURPLE,true)
	label_to(copy,"Bağlantıyı bul.\nZinciri tamamla.",24,INK,true)
	label_to(copy,"Küçük bir mola,\ntaptaze bir zihin.",14,MUTED)
	image_to(hero_row,"mascot",Vector2(142,153))
	var next = next_level_id()
	var resume_text = "Kaldığın yerden" if state.data.active.has(str(next)) else "Maceraya başla"
	button_to(vb,resume_text+"   →",func(): start_level(next))
	var foot = label_to(vb,"Bölüm "+str(next)+"  ·  "+levels[next-1].category+"  ·  +25 altın",12,PURPLE)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var section = row_to(page)
	var title = label_to(section,"Keşif rotan",20,INK,true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var all_btn = button_to(section,"Tümünü gör",show_levels,CREAM,PURPLE,34)
	all_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	all_btn.add_theme_font_size_override("font_size",13)
	for i in range(3): category_card(i)
	label_to(page,"Birlikte daha eğlenceli",20,INK,true)
	var modes = row_to(page,10)
	var party = panel_to(modes,Color("fff0c4"),20)
	party.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pb = box_to(party,4)
	label_to(pb,"Yan yana",12,Color("9a742f"),true)
	button_to(pb,"Parti modu →",show_party_setup,Color("fff0c4"),INK,42)
	var online = panel_to(modes,Color("f2e8e2"),20)
	online.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ob = box_to(online,4)
	label_to(ob,"Çok yakında",12,Color("a16f5e"),true)
	button_to(ob,"1'e 1 yarış →",show_online,Color("f2e8e2"),INK,42)

func category_card(i: int) -> void:
	var p = panel_to(page,[Color("fff0db"),Color("e9efdf"),Color("ece6f6")][i],20)
	var h = row_to(p,12)
	image_to(h,CATEGORY_ART[i],Vector2(56,60))
	var v = box_to(h,2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_to(v,CATEGORIES[i],18,INK,true)
	label_to(v,str(category_done(CATEGORIES[i]))+" / 8 bölüm tamamlandı",12,MUTED)
	var b = button_to(h,"→",func(): filter_category = CATEGORIES[i]; show_levels(),Color.TRANSPARENT,PURPLE,44)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END

func show_levels() -> void:
	reset_page("levels",true)
	header("Keşif rotan")
	label_to(page,"Her zincir yeni bir keşif.",25,INK,true)
	label_to(page,str(state.data.completed.size())+" / 24 bölüm tamamlandı",14,MUTED)
	var filters = row_to(page,5)
	for cat in ["Tümü","Mutfak","Doğa","Günlük Yaşam"]:
		var b = button_to(filters,cat,func(): filter_category = cat; show_levels(),PURPLE if filter_category == cat else LILAC,Color.WHITE if filter_category == cat else PURPLE,42)
		b.add_theme_font_size_override("font_size",12)
		for s in ["normal","hover","pressed"]:
			var st = b.get_theme_stylebox(s).duplicate()
			st.content_margin_left = 9
			st.content_margin_right = 9
			b.add_theme_stylebox_override(s,st)
	for i in range(3):
		if filter_category != "Tümü" and filter_category != CATEGORIES[i]: continue
		var section = row_to(page)
		image_to(section,CATEGORY_ART[i],Vector2(48,48))
		label_to(section,CATEGORIES[i],21,INK,true)
		var grid = GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation",10)
		grid.add_theme_constant_override("v_separation",10)
		page.add_child(grid)
		for j in range(8):
			var id = i*8+j+1
			var done = id in state.data.completed
			var unlocked = j == 0 or id-1 in state.data.completed or done
			var caption = str(id)+(" ✓" if done else "")
			var b = button_to(grid,caption,func(): start_level(id),Color("e3eddc") if done else Color.WHITE, GREEN if done else PURPLE,72)
			b.custom_minimum_size.x = 80
			b.disabled = not unlocked
			b.tooltip_text = "Tamamlandı · tekrar oyna" if done else "Önceki bölümü tamamla" if not unlocked else "Zinciri keşfet"
	label_to(page,"Her kategorinin ilk bölümü açık. İlerledikçe yenileri açılır.",13,MUTED)

func start_level(id: int, selected_mode: String = "solo") -> void:
	mode = selected_mode
	current = levels[id-1].duplicate(true)
	cursor = 1
	revealed = [0]
	clues = {}
	if mode == "solo" and state.data.active.has(str(id)):
		var saved = state.data.active[str(id)]
		cursor = clampi(int(saved.get("cursor",1)),1,current.words.size()-1)
		revealed = saved.get("revealed",[0])
		clues = saved.get("clues",{})
	show_game()
	if mode == "party":
		party_remaining = 90
		party_started = Time.get_ticks_msec()
		party_clock.start()

func save_active() -> void:
	if mode != "solo": return
	state.data.active[str(int(current.id))] = {"cursor":cursor,"revealed":revealed,"clues":clues}
	state.save()

func leave_game() -> void:
	if mode == "party":
		confirm_dialog("Partiden ayrıl?","Bu partinin puanları silinecek.",func(): show_home())
	elif mode == "tutorial": show_tutorial_intro()
	else:
		save_active()
		DisplayServer.virtual_keyboard_hide()
		show_home()

func show_game(message: String = "") -> void:
	reset_page("game")
	header("Isınma turu" if mode == "tutorial" else party_names[party_index % party_names.size()] if mode == "party" else "Bölüm "+str(int(current.id)),leave_game)
	var top = row_to(page)
	var cat = label_to(top,current.category.to_upper(),12,PURPLE,true)
	cat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if mode == "party": clock_label = label_to(top,str(party_remaining)+" sn",15,PURPLE,true)
	else: label_to(top,str(cursor)+" / "+str(current.words.size()-1)+" bağlantı",13,MUTED)
	label_to(page,"Sıradaki sözcüğü bul.",28,INK,true)
	label_to(page,"Komşu sözcükler bir tamlama oluşturur.",14,MUTED)
	if mode == "tutorial":
		var guide = panel_to(page,Color("fff0c4"),18)
		label_to(guide,["","ÇAY + ? → Çay kaşığı. Cevabın KAŞIK!","KAŞIK + ? → Kaşık oyunu. Şimdi OYUN yaz.","OYUN + ? → Oyun havası. Son sözcük HAVA."][mini(cursor,3)],14,INK)
	var progress = ProgressBar.new()
	progress.max_value = current.words.size()-1
	progress.value = cursor-1
	progress.show_percentage = false
	progress.custom_minimum_size.y = 5
	progress.add_theme_stylebox_override("background",style(LILAC,3))
	progress.add_theme_stylebox_override("fill",style(PURPLE,3))
	page.add_child(progress)
	var chain = box_to(page,5)
	active_tiles.clear()
	for i in range(current.words.size()):
		if i > 0:
			var dot = label_to(chain,"↕",13,Color("c9bbdf"))
			dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var solved = i < cursor
		var active = i == cursor
		var p = panel_to(chain,LILAC if active else Color.WHITE if solved else Color("f1edf3"),18)
		var b = box_to(p,4)
		if solved:
			var r = row_to(b)
			var word = label_to(r,current.words[i],23,INK,true)
			word.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label_to(r,"BAŞLANGIÇ" if i == 0 else "✓",11,PURPLE,true)
			if i > 0: label_to(b,current.links[i-1],12,MUTED)
		elif active:
			var r = row_to(b,6)
			r.alignment = BoxContainer.ALIGNMENT_CENTER
			var word: String = current.words[i]
			for j in range(word.length()):
				var tile = PanelContainer.new()
				tile.custom_minimum_size = Vector2(34 if word.length() > 7 else 39,46)
				tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var st = style(Color.WHITE,9,PURPLE if j == 0 else Color("d8c9ee"),1)
				st.content_margin_left = 0
				st.content_margin_right = 0
				st.content_margin_top = 2
				st.content_margin_bottom = 2
				tile.add_theme_stylebox_override("panel",st)
				r.add_child(tile)
				var l = label_to(tile,word[j] if j in revealed else "",23,PURPLE,true)
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				active_tiles.append(l)
			var desc = label_to(b,str(word.length())+" harf  ·  İlk harf hazır, gerisi sende",11,PURPLE)
			desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			var l = label_to(b,"•  •  •",17,Color("b4a8c1"),true)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entry = create_entry(page,"Cevabını yaz…",current.words[cursor].length()+3)
	entry.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	entry.text_submitted.connect(func(_v): submit_answer())
	entry.text_changed.connect(update_tiles)
	var hint_key = str(cursor)
	if clues.has(hint_key):
		var bubble = panel_to(page,Color("fff0c4"),18)
		label_to(bubble,"Minik bir ipucu: "+current.hints[cursor],14,INK)
	feedback = label_to(page,message if not message.is_empty() else "Sözcükleri ek almadan, yalın hâliyle yaz.",13,GREEN if not message.is_empty() else MUTED)
	var hint_row = row_to(page,8)
	var price_letter = "Ücretsiz" if mode == "tutorial" else "15 altın" if mode == "solo" else "−10 puan"
	var price_clue = "Ücretsiz" if mode == "tutorial" else "10 altın" if mode == "solo" else "−5 puan"
	var lb = button_to(hint_row,"Harf al · "+price_letter,reveal_letter,Color("fff0c4"),Color("806122"),48)
	lb.add_theme_font_size_override("font_size",13)
	var cb = button_to(hint_row,"İpucu · "+price_clue,reveal_clue,LILAC,PURPLE,48)
	cb.add_theme_font_size_override("font_size",13)
	cb.disabled = clues.has(hint_key)
	button_to(page,"Kontrol et   →",submit_answer)
	if mode == "party": party_clock.start()

func update_tiles(value: String) -> void:
	var normalized = GameState.upper_tr(value)
	var word: String = current.words[cursor]
	for i in range(active_tiles.size()):
		active_tiles[i].text = word[i] if i in revealed else normalized[i] if i < normalized.length() else ""
		active_tiles[i].modulate = Color.WHITE if i in revealed else Color("9c88bb")

func submit_answer() -> void:
	if busy or not is_instance_valid(entry): return
	var guess = GameState.upper_tr(entry.text)
	if guess.is_empty():
		feedback.text = "Önce bir sözcük yazalım."
		return
	if guess != current.words[cursor]:
		feedback.text = "Bir daha deneyelim. Önceki sözcükle bağlantısını düşün."
		feedback.add_theme_color_override("font_color",Color("b35e50"))
		if state.data.motion:
			var tw = create_tween()
			tw.tween_property(entry,"modulate",Color("f3b6a7"),0.12)
			tw.tween_property(entry,"modulate",Color.WHITE,0.18)
		return
	busy = true
	DisplayServer.virtual_keyboard_hide()
	if mode == "party": party_scores[party_index % party_names.size()] += 30
	cursor += 1
	revealed = [0]
	if cursor >= current.words.size():
		party_clock.stop()
		if mode == "tutorial":
			state.data.tutorial = true
			state.save()
			show_win(false)
		elif mode == "party":
			party_scores[party_index % party_names.size()] += int(party_remaining/3)
			finish_party_turn(true)
		else:
			var rewarded = state.complete(int(current.id))
			show_win(rewarded)
	else:
		save_active()
		show_game("Harika bağlantı! "+current.links[cursor-2]+".")

func reveal_letter() -> void:
	if busy: return
	var word: String = current.words[cursor]
	var hidden: Array = []
	for i in range(1,word.length()):
		if not i in revealed: hidden.append(i)
	if hidden.is_empty():
		feedback.text = "Bütün harfler açık. Sözcüğü yazıp kontrol et."
		return
	if mode == "solo" and not state.spend(GameState.LETTER_COST):
		feedback.text = "Harf için 15 altın gerekiyor. Denemek her zaman ücretsiz."
		return
	if mode == "party": party_scores[party_index % party_names.size()] -= 10
	revealed.append(hidden.pick_random())
	save_active()
	show_game("Bir harf daha seninle!")

func reveal_clue() -> void:
	if busy or clues.has(str(cursor)): return
	if mode == "solo" and not state.spend(GameState.CLUE_COST):
		feedback.text = "İpucu için 10 altın gerekiyor. Bir tahmin daha yapabilirsin."
		return
	if mode == "party": party_scores[party_index % party_names.size()] -= 5
	clues[str(cursor)] = true
	save_active()
	show_game()

func show_win(rewarded: bool) -> void:
	reset_page("win")
	gap(page,16)
	var tag = label_to(page,"BAĞLANTILAR TAMAM!",13,PURPLE,true)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	image_to(page,"mascot",Vector2(210,210))
	var title = label_to(page,"İşte bu, zincir tamam!",29,INK,true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub = label_to(page,"Artık hazırsın. Kendi keşif rotanı seç!" if mode == "tutorial" else "Bir sözcükten kocaman bir keşfe.",16,MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var summary = panel_to(page,LILAC)
	var v = box_to(summary,8)
	for phrase in current.links:
		var l = label_to(v,"✓  "+phrase,17,PURPLE,true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if mode != "tutorial":
		var reward = panel_to(page,Color("fff0c4"),18)
		var l = label_to(reward,"+25 altın  ·  Çok iyi iş!" if rewarded else "Bu zinciri daha önce tamamladın.",18,Color("8a641c"),true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gap(page,4)
	if mode == "tutorial": button_to(page,"Keşfe başla   →",show_home)
	else:
		var id = int(current.id)
		if id < levels.size(): button_to(page,"Sıradaki zincir   →",func(): start_level(id+1))
		button_to(page,"Keşif rotana dön",show_levels,LILAC,PURPLE)
	confetti()

func confetti() -> void:
	if not state.data.motion: return
	for i in range(22):
		var piece = ColorRect.new()
		piece.color = [PURPLE,YELLOW,CORAL,Color("b9cfaa")][i%4]
		piece.size = Vector2(6,11)
		piece.position = Vector2(randf_range(10,size.x-10),-25)
		piece.rotation = randf_range(-2,2)
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(piece)
		var tw = create_tween().set_parallel(true)
		tw.tween_property(piece,"position:y",size.y+30,randf_range(1.5,2.8)).set_delay(randf_range(0,0.4))
		tw.tween_property(piece,"rotation",randf_range(-7,7),2.5)
		tw.chain().tween_callback(piece.queue_free)
		sparkle_tweens.append(tw)

func show_party_setup() -> void:
	reset_page("party_setup")
	header("Parti modu",show_home)
	image_to(page,"party",Vector2(130,130))
	label_to(page,"Telefonu sırayla paylaş.",29,INK,true)
	label_to(page,"2–4 kişi, bolca kelime. Her oyuncuya 90 saniye ve farklı bir zincir. En çok puanı toplayan kazanır.",16,MUTED)
	label_to(page,"Oyuncular",17,INK,true)
	party_inputs.clear()
	for i in range(4):
		var e = create_entry(page,"Oyuncu "+str(i+1)+(" · isteğe bağlı" if i > 1 else ""),16)
		if i < party_names.size(): e.text = party_names[i]
		elif i == 0: e.text = str(state.data.name)
		party_inputs.append(e)
	var r = row_to(page)
	label_to(r,"Kaç tur?",16,INK,true)
	button_to(r,"1 tur",func(): party_rounds = 1; toast("1 tur seçildi"),LILAC,PURPLE,44)
	button_to(r,"2 tur",func(): party_rounds = 2; toast("2 tur seçildi"),LILAC,PURPLE,44)
	label_to(page,"Doğru sözcük +30 · Harf −10 · İpucu −5\nBitirince kalan her 3 saniye +1 puan.",13,MUTED)
	button_to(page,"Partiyi başlat   →",begin_party,YELLOW,INK)

func begin_party() -> void:
	party_names.clear()
	for e in party_inputs:
		if not e.text.strip_edges().is_empty(): party_names.append(e.text.strip_edges())
	if party_names.size() < 2:
		toast("En az iki oyuncunun adını yaz.")
		return
	var unique: Array = []
	for n in party_names:
		var upper = GameState.upper_tr(n)
		if upper in unique:
			toast("Oyuncular için farklı isimler kullan.")
			return
		unique.append(upper)
	party_scores = []
	for n in party_names: party_scores.append(0)
	party_queue.clear()
	for lev in levels:
		if lev.words.size() == 4: party_queue.append(int(lev.id))
	party_queue.shuffle()
	party_index = 0
	DisplayServer.virtual_keyboard_hide()
	show_party_handoff()

func show_party_handoff() -> void:
	reset_page("party_handoff")
	header("Tur "+str(int(party_index/party_names.size())+1)+" / "+str(party_rounds),func(): confirm_dialog("Partiden ayrıl?","Parti puanları kaydedilmez.",show_home))
	gap(page,60)
	image_to(page,"party",Vector2(210,210))
	var l = label_to(page,"Sıra sende,\n"+party_names[party_index % party_names.size()]+"!",33,INK,true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_to(page,"Telefonu bu oyuncuya ver. Hazır olduğunda 90 saniyelik süre başlayacak.",17,MUTED)
	gap(page,20)
	button_to(page,"Hazırım!   →",party_countdown,YELLOW,INK)

func party_countdown() -> void:
	reset_page("countdown")
	gap(page,210)
	var l = label_to(page,"3",100,PURPLE,true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for n in [3,2,1]:
		l.text = str(n)
		await get_tree().create_timer(0.75).timeout
		if screen != "countdown": return
	start_level(party_queue[party_index],"party")

func _party_tick() -> void:
	if mode != "party" or screen != "game": return
	party_remaining = maxi(0,90-int((Time.get_ticks_msec()-party_started)/1000))
	if is_instance_valid(clock_label): clock_label.text = str(party_remaining)+" sn"
	if party_remaining <= 0:
		party_clock.stop()
		finish_party_turn(false)

func finish_party_turn(finished: bool) -> void:
	DisplayServer.virtual_keyboard_hide()
	reset_page("party_turn_end")
	gap(page,55)
	image_to(page,"party",Vector2(190,190))
	label_to(page,"Zincir tamam!" if finished else "Süre doldu!",32,INK,true)
	var who = party_index % party_names.size()
	label_to(page,party_names[who]+" · "+str(party_scores[who])+" toplam puan",22,PURPLE,true)
	var p = panel_to(page,LILAC)
	var v = box_to(p,7)
	for phrase in current.links: label_to(v,phrase,17,INK)
	party_index += 1
	button_to(page,"Sonuçları gör" if party_index >= party_names.size()*party_rounds else "Sıradaki oyuncu   →",show_party_results if party_index >= party_names.size()*party_rounds else show_party_handoff)

func show_party_results() -> void:
	reset_page("party_results")
	image_to(page,"party",Vector2(200,200))
	var highest = party_scores.max()
	var winners: Array = []
	for i in range(party_names.size()):
		if party_scores[i] == highest: winners.append(party_names[i])
	label_to(page,"Dostluk kazandı!" if winners.size() > 1 else winners[0]+" kazandı!",30,INK,true)
	label_to(page,"Birlikte keşfetmek çok daha güzel.",16,MUTED)
	var results: Array = []
	for i in range(party_names.size()): results.append({"name":party_names[i],"score":party_scores[i]})
	results.sort_custom(func(a,b): return a.score > b.score)
	for r in results:
		var p = panel_to(page,LILAC)
		label_to(p,r.name+"   ·   "+str(r.score)+" puan",20,INK,true)
	button_to(page,"Bir parti daha",show_party_setup,YELLOW,INK)
	button_to(page,"Ana menüye dön",show_home,LILAC,PURPLE)
	confetti()

func show_online() -> void:
	reset_page("online")
	header("1'e 1 yarış",show_home)
	gap(page,24)
	image_to(page,"party",Vector2(180,180))
	label_to(page,"Aynı anda,\naynı heyecan.",34,INK,true)
	var note = panel_to(page,Color("fff0c4"))
	label_to(note,"Çok yakında · Çevrim içi bağlantı henüz açık değil.",16,Color("8a641c"),true)
	label_to(page,"Oda koduyla arkadaşınla eşleş, 3–2–1 sayımıyla başla ve rakibinin puanını canlı takip et.",17,MUTED)
	var p = panel_to(page,LILAC)
	var v = box_to(p,12)
	label_to(v,"Birlikte yarışmaya hazırlanıyoruz",19,INK,true)
	label_to(v,"•  Oda kurma ve kodla katılma\n•  Aynı zincir, eş zamanlı başlangıç\n•  Canlı skor ve kısa mesajlar",15,MUTED)
	button_to(page,"Şimdilik yan yana oynayalım",show_party_setup)
	button_to(page,"Keşfe dön",show_home,LILAC,PURPLE)

func show_profile() -> void:
	reset_page("profile",true)
	header("Senin köşen")
	profile_avatar = int(state.data.avatar)
	image_to(page,["mascot","tea","plant","book"][profile_avatar],Vector2(130,130))
	label_to(page,str(state.data.name),30,INK,true)
	label_to(page,"Her gün bir bağlantı daha.",16,MUTED)
	var p = panel_to(page,LILAC)
	var h = row_to(p)
	var a = box_to(h)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_to(a,str(state.data.completed.size()),30,PURPLE,true)
	label_to(a,"Tamamlanan bölüm",12,MUTED)
	var b = box_to(h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_to(b,str(int(state.data.coins)),30,PURPLE,true)
	label_to(b,"Biriken altın",12,MUTED)
	label_to(page,"Profilini düzenle",19,INK,true)
	profile_name = create_entry(page,"Adın",16)
	profile_name.text = str(state.data.name)
	avatar_picker(page)
	button_to(page,"Değişiklikleri kaydet",func():
		if profile_name.text.strip_edges().length() < 2:
			toast("İsmin en az 2 karakter olsun.")
			return
		state.data.name = profile_name.text.strip_edges()
		state.data.avatar = profile_avatar
		state.save()
		DisplayServer.virtual_keyboard_hide()
		show_profile()
		toast("Profilin güncellendi."))
	var motion = CheckButton.new()
	motion.text = "Kutlama animasyonları"
	motion.custom_minimum_size.y = 48
	motion.button_pressed = bool(state.data.motion)
	motion.add_theme_color_override("font_color",INK)
	motion.toggled.connect(func(on): state.data.motion = on; state.save())
	page.add_child(motion)
	button_to(page,"Nasıl oynanır?",show_tutorial_intro,LILAC,PURPLE,48)
	label_to(page,"Türkçe · Godot 4.7.2 · Sürüm 1.0\nİlerlemen yalnızca bu tarayıcıda / cihazda saklanır.",12,MUTED)

func toast(message: String) -> void:
	var panel = panel_to(overlay,PURPLE,18)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_top = -130
	panel.offset_bottom = -65
	var l = label_to(panel,message,15,Color.WHITE,true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	await get_tree().create_timer(2.5).timeout
	if is_instance_valid(panel): panel.queue_free()

func confirm_dialog(title: String, description: String, fn: Callable) -> void:
	var shade = ColorRect.new()
	shade.color = Color(0.13,0.08,0.19,0.38)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var card = panel_to(center,CREAM,24)
	card.custom_minimum_size.x = 344
	var b = box_to(card,16)
	label_to(b,title,24,INK,true)
	label_to(b,description,15,MUTED)
	button_to(b,"Devam et",func(): shade.queue_free(),LILAC,PURPLE)
	button_to(b,"Ayrıl",func(): shade.queue_free(); fn.call())
