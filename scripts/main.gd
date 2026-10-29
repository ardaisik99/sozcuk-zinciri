extends Control

const CREAM = Color("fffefa")
const INK = Color("292060")
const MUTED = Color("8981a5")
const PURPLE = Color("6038ef")
const LILAC = Color("f0ebff")
const YELLOW = Color("ffca58")
const CORAL = Color("ff9664")
const GREEN = Color("53765b")
const CATEGORIES = ["Mutfak", "Doğa", "Günlük Yaşam"]
const CATEGORY_ART = ["icon_tea", "icon_leaf", "icon_book"]

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
var tile_area: HBoxContainer
var tile_panels: Array = []
var active_card: PanelContainer
var game_generation = 0
var answer_timer: Timer

func _ready() -> void:
	RenderingServer.set_default_clear_color(CREAM)
	Engine.max_fps = 30
	get_window().size_changed.connect(_adapt_scale)
	_adapt_scale()
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
	variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):900}
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
	answer_timer = Timer.new()
	answer_timer.one_shot = true
	answer_timer.wait_time = 0.24
	answer_timer.timeout.connect(func():
		if screen == "game" and not busy and WordRules.matches(entry.text,current,cursor,revealed): submit_answer())
	add_child(answer_timer)
	show_loading()
	await get_tree().process_frame
	if str(state.data.name).is_empty(): show_profile_setup()
	elif not state.data.tutorial: show_tutorial_intro()
	else: show_home()

func _adapt_scale() -> void:
	var pixels = get_window().size
	if pixels.x <= 0: return
	get_window().content_scale_size = Vector2i(432,maxi(1,roundi(432.0*pixels.y/pixels.x)))
	if OS.has_feature("web"):
		await get_tree().process_frame
		await get_tree().process_frame
		if web_input != null and is_instance_valid(scroll):
			var focused_id = str(web_input.focused())
			if web_entries.has(focused_id) and is_instance_valid(web_entries[focused_id]):
				var focused_field = web_entries[focused_id]
				scroll.ensure_control_visible(tile_area if focused_field.has_meta("tile_input") and is_instance_valid(tile_area) else focused_field)
				await get_tree().process_frame
				_position_web_input()

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
	if color == Color.WHITE or color == PURPLE:
		s.shadow_color = Color(0.24,0.12,0.57,0.10 if color == Color.WHITE else 0.24)
		s.shadow_size = 1
		s.shadow_offset = Vector2(0,3)
	return s

func track_style(color: Color) -> StyleBoxFlat:
	var s = style(color,3)
	s.content_margin_top = 0
	s.content_margin_bottom = 0
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

func reset_page(id: String, _nav: bool = false) -> void:
	if OS.has_feature("web") and web_input != null:
		web_input.close()
	web_entries.clear()
	game_generation += 1
	screen = id
	busy = false
	for tw in sparkle_tweens:
		if is_instance_valid(tw): tw.kill()
	sparkle_tweens.clear()
	for child in get_children():
		if child != party_clock and child != answer_timer:
			remove_child(child)
			child.queue_free()
	if id != "game": party_clock.stop()
	if is_instance_valid(answer_timer): answer_timer.stop()
	var bg = TextureRect.new()
	bg.texture = load("res://assets/v2/"+("splash" if id == "loading" else "background")+".webp")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
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
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	layout.add_child(scroll)
	scroll.get_v_scroll_bar().value_changed.connect(func(_v): call_deferred("_position_web_input"))
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left",24)
	margin.add_theme_constant_override("margin_right",24)
	margin.add_theme_constant_override("margin_top",24)
	margin.add_theme_constant_override("margin_bottom",24)
	scroll.add_child(margin)
	page = box_to(margin,14)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var over = Control.new()
	over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(over)
	overlay = over
	if OS.has_feature("web"):
		JavaScriptBridge.eval("document.getElementById('canvas').setAttribute('aria-label','Sözcük Zinciri — "+id+"');",true)
		web_input.setScreen(id)

func art_to(parent: Node, asset: String, dimensions: Vector2) -> TextureRect:
	return image_to(parent,"v2/"+asset,dimensions)

func center_label(parent: Node, value: String, pixels: int = 16, color: Color = INK, heavy: bool = false) -> Label:
	var l = label_to(parent,value,pixels,color,heavy)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func brand(parent: Node, height: int = 205, dark: bool = false) -> void:
	art_to(parent,"logo_dark" if dark else "logo",Vector2(260,height))

func menu_button(parent: Node, title: String, icon_name: String, action: Callable, description: String = "") -> Button:
	var button = button_to(parent,"",action,Color.WHITE,PURPLE,72 if not description.is_empty() else 62)
	button.add_theme_stylebox_override("normal",style(Color.WHITE,22,Color("ebe6fb"),1))
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right"]: margin.add_theme_constant_override("margin_"+edge,20)
	margin.add_theme_constant_override("margin_top",10)
	margin.add_theme_constant_override("margin_bottom",10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var h = row_to(margin,14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_to(h,"icon_"+icon_name,Vector2(32,32))
	var v = box_to(h,2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_to(v,title,17,INK,true)
	if not description.is_empty(): label_to(v,description,12,MUTED)
	var arrow = label_to(h,"›",26,PURPLE,true)
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return button

func show_categories() -> void:
	reset_page("categories")
	header("Kategoriler",show_home)
	gap(page,14)
	center_label(page,"Hangi dünyaya adım atalım?",24,PURPLE,true)
	center_label(page,"Kelimeler arasında küçük bir keşif.",14,MUTED)
	gap(page,12)
	menu_button(page,"Hepsi","chain",func(): filter_category = "Tümü"; show_levels(),"Tüm kelimeler · 24 bölüm")
	for i in range(CATEGORIES.size()):
		menu_button(page,CATEGORIES[i],["tea","leaf","book"][i],func(): filter_category = CATEGORIES[i]; show_levels(),str(category_done(CATEGORIES[i]))+" / 8 bölüm tamamlandı")
	gap(page,12)
	center_label(page,"Yeni bağlantılar keşfettikçe\nbölümler birer birer açılır.",14,MUTED)

func header(title: String = "", back: Callable = Callable()) -> void:
	var h = row_to(page)
	if back.is_valid():
		var b = button_to(h,"←",back,Color.WHITE,PURPLE,46)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.custom_minimum_size.x = 46
		b.add_theme_font_size_override("font_size",26)
		for state_name in ["normal","hover","pressed","focus"]:
			var back_style = b.get_theme_stylebox(state_name).duplicate()
			back_style.content_margin_left = 0
			back_style.content_margin_right = 0
			b.add_theme_stylebox_override(state_name,back_style)
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
	brand(page,280,true)
	gap(page,70)
	var p = ProgressBar.new()
	p.custom_minimum_size.y = 6
	p.show_percentage = false
	p.value = 100
	p.add_theme_stylebox_override("background",track_style(Color("593eae")))
	p.add_theme_stylebox_override("fill",track_style(Color.WHITE))
	page.add_child(p)
	center_label(page,"Kelimeler hazırlanıyor…",14,Color.WHITE)

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
	await get_tree().process_frame
	if not is_instance_valid(field) or not field.is_inside_tree(): return
	var id = str(field.get_instance_id())
	web_entries[id] = field
	web_input.add(id,field.text,field.placeholder_text,field.max_length,"tiles" if field.has_meta("tile_input") else "form")
	_position_web_input()

func _position_web_input() -> void:
	if screen == "game" and is_instance_valid(entry) and is_instance_valid(tile_area):
		entry.position = tile_area.get_global_rect().position
		entry.size = tile_area.size
	if web_input == null or size.x <= 0 or size.y <= 0: return
	for id in web_entries:
		var field = web_entries[id]
		if not is_instance_valid(field): continue
		var r = tile_area.get_global_rect() if field.has_meta("tile_input") and is_instance_valid(tile_area) else field.get_global_rect()
		web_input.position(id,r.position.x/size.x,r.position.y/size.y,r.size.x/size.x,r.size.y/size.y)

func _web_input_changed(args: Array) -> void:
	if args.size() < 3 or not web_entries.has(str(args[0])): return
	var field = web_entries[str(args[0])]
	if not is_instance_valid(field): return
	var action = str(args[2])
	if action == "focus":
		if not field.has_meta("tile_input"):
			field.add_theme_stylebox_override("normal",style(Color.WHITE,20,PURPLE,2))
		return
	if action == "blur":
		if not field.has_meta("tile_input"):
			field.add_theme_stylebox_override("normal",style(Color.WHITE,20,Color("e5ddff"),1))
		return
	if busy and field.has_meta("tile_input"): return
	field.text = str(args[1])
	field.caret_column = field.text.length()
	field.text_changed.emit(field.text)
	if action == "submit": field.text_submitted.emit(field.text)

func show_profile_setup() -> void:
	reset_page("onboarding")
	gap(page,60)
	brand(page,220)
	center_label(page,"Kelimeleri birbirine bağla,\nkendi zincirini tamamla.",17,INK,true)
	gap(page,42)
	profile_name = create_entry(page,"Kullanıcı adını yaz…",16)
	profile_name.text = str(state.data.name)
	var go = button_to(page,"Devam Et     →",_finish_profile,PURPLE,Color.WHITE,60)
	go.disabled = profile_name.text.strip_edges().length() < 2
	profile_name.text_changed.connect(func(s): go.disabled = s.strip_edges().length() < 2)
	profile_name.text_submitted.connect(func(_s): _finish_profile())
	gap(page,30)
	center_label(page,"Sadece bir isim, sonra oyuna hazırsın.",14,MUTED)
	center_label(page,"İlerlemen bu cihazda saklanır.",12,MUTED)

func _finish_profile() -> void:
	var clean = profile_name.text.strip_edges()
	if clean.length() < 2: return
	state.data.name = clean
	state.save()
	DisplayServer.virtual_keyboard_hide()
	show_tutorial_intro()

func show_tutorial_intro() -> void:
	reset_page("tutorial_intro")
	if state.data.tutorial: header("Nasıl oynanır?",show_profile)
	brand(page,150)
	center_label(page,"Bir sözcük diğerini açar.",26,PURPLE,true)
	var card = panel_to(page,Color.WHITE)
	var v = box_to(card,12)
	center_label(v,"SU  →  B A R D A Ğ I",23,PURPLE,true)
	center_label(v,"Su bardağı! İlk harf bizden.\nKutulara dokun, ARDAĞI yaz.",16,INK)
	center_label(v,"BARDAĞI   →   BARDAK",21,PURPLE,true)
	center_label(v,"Doğru sözcük köküne dönüşür.\nSonra bardak altlığıyla devam edersin.",15,MUTED)
	gap(page,8)
	label_to(page,"01    İlk kutuya dokun, kalan harfleri yaz.",15,INK,true)
	label_to(page,"02    Doğru cevapta otomatik devam et.",15,INK,true)
	label_to(page,"03    Takılırsan harf veya ipucu kullan.",15,INK,true)
	button_to(page,"Hadi Deneyelim     →",func(): start_level(1,"tutorial"))
	center_label(page,"Öğreticide bütün jokerler ücretsiz.",12,MUTED)

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
	reset_page("home")
	var h = row_to(page,9)
	var profile = button_to(h,"",show_profile,Color.TRANSPARENT,PURPLE,46)
	profile.custom_minimum_size.x = 44
	profile.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var user_art = art_to(profile,"icon_user",Vector2.ZERO)
	user_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var identity = box_to(h,1)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_to(identity,str(state.data.name),14,INK,true)
	label_to(identity,"Seviye "+str(1+int(state.data.completed.size()/4)),11,MUTED)
	var coin = panel_to(h,Color.WHITE,22)
	var coin_row = row_to(coin,5)
	art_to(coin_row,"icon_coin",Vector2(22,22))
	label_to(coin_row,str(int(state.data.coins)),15,INK,true)
	var settings = button_to(h,"",show_profile,Color.WHITE,PURPLE,46)
	settings.custom_minimum_size.x = 46
	settings.size_flags_horizontal = Control.SIZE_SHRINK_END
	var gear = art_to(settings,"icon_gear",Vector2.ZERO)
	gear.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gear.offset_left = 10
	gear.offset_right = -10
	gear.offset_top = 10
	gear.offset_bottom = -10
	gap(page,14)
	brand(page,220)
	center_label(page,"Bir kelimeyle başla, bağlantıyı keşfet.",14,MUTED)
	gap(page,12)
	var next = next_level_id()
	menu_button(page,"Tek Oyunculu","play",func(): start_level(next),"Bölüm "+str(next)+" · "+levels[next-1].category)
	menu_button(page,"Çok Oyunculu","versus",show_online)
	menu_button(page,"Parti Modu","party",show_party_setup)
	var bottom = row_to(page,14)
	for info in [["Kategoriler","folder",show_categories],["Ayarlar","gear",show_profile]]:
		var b = button_to(bottom,"",info[2],Color.WHITE,INK,96)
		var margin = MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_top",12)
		margin.add_theme_constant_override("margin_bottom",12)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(margin)
		var v = box_to(margin,5)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_to(v,"icon_"+info[1],Vector2(30,30))
		center_label(v,info[0],15,INK,true)
	center_label(page,"Her gün yeni bağlantılar kur.",12,MUTED)

func category_card(i: int) -> void:
	menu_button(page,CATEGORIES[i],["tea","leaf","book"][i],func(): filter_category = CATEGORIES[i]; show_levels())

func show_levels() -> void:
	reset_page("levels")
	header("Bölümler",show_categories)
	gap(page,8)
	center_label(page,filter_category if filter_category != "Tümü" else "Keşif Rotan",28,PURPLE,true)
	center_label(page,str(state.data.completed.size())+" / 24 bölüm tamamlandı",14,MUTED)
	for i in range(3):
		if filter_category != "Tümü" and filter_category != CATEGORIES[i]: continue
		var section = row_to(page)
		art_to(section,CATEGORY_ART[i],Vector2(34,34))
		label_to(section,CATEGORIES[i],19,INK,true)
		var grid = GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation",10)
		grid.add_theme_constant_override("v_separation",12)
		page.add_child(grid)
		for j in range(8):
			var id = i*8+j+1
			var done = id in state.data.completed
			var unlocked = j == 0 or id-1 in state.data.completed or done
			var b = button_to(grid,str(id)+(" ✓" if done else ""),func(): start_level(id),LILAC if done else Color.WHITE,PURPLE,72)
			b.custom_minimum_size.x = 80
			b.disabled = not unlocked
			b.tooltip_text = "Tekrar oyna" if done else "Önceki bölümü tamamla" if not unlocked else "Zinciri keşfet"
	center_label(page,"Her kategorinin ilk bölümü açık.\nÇözdükçe yeni bağlantılara ulaşırsın.",13,MUTED)

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
	if busy: return
	if mode == "party":
		confirm_dialog("Partiden ayrıl?","Bu partinin puanları silinecek.",func(): show_home())
	elif mode == "tutorial": show_tutorial_intro()
	else:
		save_active()
		DisplayServer.virtual_keyboard_hide()
		show_home()

func show_game(message: String = "", keep_input: bool = false) -> void:
	if keep_input and screen == "game" and is_instance_valid(entry):
		answer_timer.stop()
		for child in page.get_children():
			page.remove_child(child)
			child.queue_free()
	else:
		reset_page("game")
		entry = null
	header("Öğretici" if mode == "tutorial" else party_names[party_index % party_names.size()] if mode == "party" else "Bölüm "+str(int(current.id)),leave_game)
	var top = row_to(page)
	var cat = label_to(top,current.category,13,PURPLE,true)
	cat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if mode == "party": clock_label = label_to(top,str(party_remaining)+" sn",15,PURPLE,true)
	else: label_to(top,str(cursor)+" / "+str(current.words.size()-1)+" bağlantı",13,MUTED)
	center_label(page,"Bağlantıyı bul!",27,PURPLE,true)
	if mode == "tutorial":
		var guide = panel_to(page,Color("fff2ce"),20)
		label_to(guide,["","Su bardağı → B hazır. ARDAĞI yaz.","Bardak altlığı → A hazır. LTLIĞI yaz.","Altlık kumaşı → K hazır. UMAŞI yaz."][mini(cursor,3)],14,INK,true)
	else: center_label(page,"İlk harf bizden. Kalanı senden.",14,MUTED)
	var progress = ProgressBar.new()
	progress.max_value = current.words.size()-1
	progress.value = cursor-1
	progress.show_percentage = false
	progress.custom_minimum_size.y = 5
	progress.add_theme_stylebox_override("background",track_style(LILAC))
	progress.add_theme_stylebox_override("fill",track_style(PURPLE))
	page.add_child(progress)
	var chain = box_to(page,5)
	active_tiles.clear()
	tile_panels.clear()
	for i in range(current.words.size()):
		if i > 0:
			center_label(chain,"•",10,Color("b6a2ff"))
		var solved = i < cursor
		var active = i == cursor
		var p = panel_to(chain,Color.WHITE if solved else LILAC if active else Color("f8f5ff"),20)
		var st = p.get_theme_stylebox("panel").duplicate()
		st.content_margin_top = 10 if active else 7
		st.content_margin_bottom = 10 if active else 7
		p.add_theme_stylebox_override("panel",st)
		var b = box_to(p,5)
		if solved:
			var r = row_to(b)
			var word = label_to(r,current.words[i],22,PURPLE,true)
			word.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label_to(r,"BAŞLANGIÇ" if i == 0 else "✓",10,PURPLE,true)
			if i > 0: label_to(b,current.links[i-1],11,MUTED)
		elif active:
			active_card = p
			tile_area = row_to(b,5)
			tile_area.alignment = BoxContainer.ALIGNMENT_CENTER
			var surface = WordRules.form(current,i)
			for j in range(surface.length()):
				var tile = PanelContainer.new()
				tile.custom_minimum_size = Vector2(31 if surface.length() > 7 else 36,48)
				tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var tile_style = style(Color.WHITE,11,PURPLE if j == 0 else Color("d7caff"),2 if j == 0 else 1)
				tile_style.content_margin_left = 0
				tile_style.content_margin_right = 0
				tile_style.content_margin_top = 0
				tile_style.content_margin_bottom = 0
				tile.add_theme_stylebox_override("panel",tile_style)
				tile_area.add_child(tile)
				var l = label_to(tile,surface[j] if j in revealed else "",23,PURPLE,true)
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				active_tiles.append(l)
				tile_panels.append(tile)
			center_label(b,"Kutulara dokun · Kalan harfleri yaz",11,PURPLE)
		else:
			center_label(b,"•  •  •",16,Color("c3b6dc"),true)
	if entry == null:
		entry = create_entry(self,"Harf kutuları",40)
		entry.set_meta("tile_input",true)
		entry.modulate.a = 0.0
		entry.text_submitted.connect(func(_v): submit_answer())
		entry.text_changed.connect(update_tiles)
	var hint_key = str(cursor)
	if clues.has(hint_key):
		var bubble = panel_to(page,Color("fff2ce"),20)
		label_to(bubble,current.hints[cursor],14,INK)
	feedback = center_label(page,message if not message.is_empty() else "Doğru sözcükte otomatik devam eder.",12,GREEN if not message.is_empty() else MUTED)
	var hint_row = row_to(page,10)
	var price_letter = "Ücretsiz" if mode == "tutorial" else "15 altın" if mode == "solo" else "−10 puan"
	var price_clue = "Ücretsiz" if mode == "tutorial" else "10 altın" if mode == "solo" else "−5 puan"
	var lb = button_to(hint_row,"Harf Al · "+price_letter,reveal_letter,Color.WHITE,PURPLE,48)
	lb.add_theme_font_size_override("font_size",13)
	var cb = button_to(hint_row,"İpucu · "+price_clue,reveal_clue,Color.WHITE,PURPLE,48)
	cb.add_theme_font_size_override("font_size",13)
	cb.disabled = clues.has(hint_key)
	busy = false
	_sync_game_input()
	if mode == "party": party_clock.start()

func _sync_game_input() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if screen != "game" or not is_instance_valid(entry) or not is_instance_valid(tile_area): return
	entry.position = tile_area.get_global_rect().position
	entry.size = tile_area.size
	_position_web_input()
	update_tiles(entry.text)

func update_tiles(value: String) -> void:
	if screen != "game" or busy: return
	var surface = WordRules.form(current,cursor)
	var shown = WordRules.display(value,surface,revealed)
	for i in range(active_tiles.size()):
		active_tiles[i].text = shown[i] if i < shown.length() else ""
		active_tiles[i].add_theme_color_override("font_color",PURPLE if i in revealed else INK)
	answer_timer.stop()
	if WordRules.matches(value,current,cursor,revealed):
		answer_timer.start()
	else:
		var raw = WordRules.typed(value)
		var used = raw.length() if raw.begins_with(surface[0]) else raw.length()+1
		if not raw.is_empty() and used >= surface.length() and is_instance_valid(feedback):
			feedback.text = "Henüz olmadı. Bağlantıyı bir daha düşün."
			feedback.add_theme_color_override("font_color",Color("b46a3f"))

func submit_answer() -> void:
	if busy or screen != "game" or not is_instance_valid(entry): return
	answer_timer.stop()
	if not WordRules.matches(entry.text,current,cursor,revealed):
		feedback.text = "Bağlantıyı bir daha düşün. İlk harfi tekrar yazmana gerek yok."
		feedback.add_theme_color_override("font_color",Color("b46a3f"))
		return
	busy = true
	var generation = game_generation
	var surface = WordRules.form(current,cursor)
	var stem = str(current.words[cursor])
	for i in range(active_tiles.size()): active_tiles[i].text = surface[i]
	if state.data.motion:
		var tw = create_tween()
		sparkle_tweens.append(tw)
		for i in range(active_tiles.size()):
			active_tiles[i].pivot_offset = active_tiles[i].size/2
			tw.parallel().tween_property(active_tiles[i],"scale",Vector2(1.15,1.15),0.12).set_delay(i*0.025)
		tw.chain().tween_interval(0.12)
		for i in range(active_tiles.size()):
			if i >= stem.length():
				tw.parallel().tween_property(tile_panels[i],"modulate:a",0.0,0.16)
			else:
				var at = i
				tw.parallel().tween_property(active_tiles[i],"scale",Vector2.ONE,0.16)
				tw.parallel().tween_callback(func():
					if is_instance_valid(active_tiles[at]): active_tiles[at].text = stem[at]).set_delay(0.08)
		tw.chain().tween_interval(0.12)
		await tw.finished
	if screen != "game" or generation != game_generation: return
	_commit_answer()

func _commit_answer() -> void:
	if mode == "party": party_scores[party_index % party_names.size()] += 30
	cursor += 1
	revealed = [0]
	if cursor >= current.words.size():
		party_clock.stop()
		DisplayServer.virtual_keyboard_hide()
		if mode == "tutorial":
			state.data.tutorial = true
			state.save()
			show_win(false)
		elif mode == "party":
			party_remaining = maxi(0,90-int((Time.get_ticks_msec()-party_started)/1000))
			party_scores[party_index % party_names.size()] += int(party_remaining/3)
			finish_party_turn(true)
		else:
			var rewarded = state.complete(int(current.id))
			show_win(rewarded)
	else:
		save_active()
		entry.text = ""
		if OS.has_feature("web"): web_input.resetValue(str(entry.get_instance_id()))
		show_game(current.links[cursor-2]+" → "+current.words[cursor-1],true)

func reveal_letter() -> void:
	if busy: return
	var surface = WordRules.form(current,cursor)
	var hidden: Array = []
	for i in range(1,surface.length()):
		if not i in revealed: hidden.append(i)
	if hidden.is_empty(): return
	if mode == "solo" and not state.spend(GameState.LETTER_COST):
		feedback.text = "Harf için 15 altın gerekiyor."
		return
	if mode == "party": party_scores[party_index % party_names.size()] -= 10
	revealed.append(hidden.pick_random())
	save_active()
	show_game("Bir harf daha açıldı.",true)
	if revealed.size() == surface.length():
		entry.text = surface
		update_tiles(surface)

func reveal_clue() -> void:
	if busy or clues.has(str(cursor)): return
	if mode == "solo" and not state.spend(GameState.CLUE_COST):
		feedback.text = "İpucu için 10 altın gerekiyor."
		return
	if mode == "party": party_scores[party_index % party_names.size()] -= 5
	clues[str(cursor)] = true
	save_active()
	show_game("",true)

func show_win(rewarded: bool) -> void:
	reset_page("win")
	gap(page,16)
	var tag = label_to(page,"BAĞLANTILAR TAMAM!",13,PURPLE,true)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand(page,190)
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
	art_to(page,"icon_party",Vector2(130,130))
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
	art_to(page,"icon_party",Vector2(210,210))
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
	if mode != "party" or screen != "game" or busy: return
	party_remaining = maxi(0,90-int((Time.get_ticks_msec()-party_started)/1000))
	if is_instance_valid(clock_label): clock_label.text = str(party_remaining)+" sn"
	if party_remaining <= 0:
		party_clock.stop()
		finish_party_turn(false)

func finish_party_turn(finished: bool) -> void:
	DisplayServer.virtual_keyboard_hide()
	reset_page("party_turn_end")
	gap(page,55)
	art_to(page,"icon_party",Vector2(190,190))
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
	art_to(page,"icon_party",Vector2(200,200))
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
	art_to(page,"icon_party",Vector2(180,180))
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
	reset_page("profile")
	header("Profil & Ayarlar",show_home)
	gap(page,18)
	art_to(page,"icon_user",Vector2(66,66))
	center_label(page,str(state.data.name),28,PURPLE,true)
	center_label(page,"Her gün bir bağlantı daha.",14,MUTED)
	var p = panel_to(page,Color.WHITE)
	var h = row_to(p)
	for stat in [[str(state.data.completed.size()),"Tamamlanan bölüm"],[str(int(state.data.coins)),"Biriken altın"]]:
		var v = box_to(h,4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		center_label(v,stat[0],27,PURPLE,true)
		center_label(v,stat[1],12,MUTED)
	label_to(page,"Kullanıcı adın",15,INK,true)
	profile_name = create_entry(page,"Kullanıcı adını yaz…",16)
	profile_name.text = str(state.data.name)
	button_to(page,"Kaydet     →",func():
		if profile_name.text.strip_edges().length() < 2:
			toast("İsmin en az 2 karakter olsun.")
			return
		state.data.name = profile_name.text.strip_edges()
		state.save()
		DisplayServer.virtual_keyboard_hide()
		show_profile()
		toast("Profilin güncellendi."))
	menu_button(page,"Animasyonlar","chain",func():
		var draft = profile_name.text
		state.data.motion = not state.data.motion
		state.save()
		show_profile()
		profile_name.text = draft,
		("Açık" if state.data.motion else "Kapalı")+" · Değiştirmek için dokun")
	menu_button(page,"Nasıl oynanır?","hint",show_tutorial_intro)
	center_label(page,"Türkçe · Sürüm 2.0\nİlerlemen yalnızca bu cihazda saklanır.",12,MUTED)

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
