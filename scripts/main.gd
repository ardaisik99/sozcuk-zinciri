extends Control

const CREAM = Color("fdfdff")
const INK = Color("172967")
const MUTED = Color("7781a5")
const PURPLE = Color("7845e8")
const LILAC = Color("eef0fd")
const YELLOW = Color("ffd25f")
const CORAL = Color("ff9035")
const GREEN = Color("148f7c")
const TEAL = Color("1cb4b7")
const BLUE = Color("4054ac")
const CATEGORIES = ["Mutfak", "Doğa", "Günlük Yaşam"]
const CATEGORY_ART = ["icon_tea", "icon_leaf", "icon_book"]

var state = GameState.new()
var levels: Array = []
var level_by_id: Dictionary = {}
var screen = ""
var page: VBoxContainer
var page_root: VBoxContainer
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
	# A positive max_fps sleeps inside Godot's WebAssembly callback. On the
	# browser main thread nanosleep busy-waits, monopolising input and a CPU core.
	# Let browser RAF schedule frames and redraw only when the UI changes.
	Engine.max_fps = 0 if OS.has_feature("web") else 30
	OS.low_processor_usage_mode = true
	OS.low_processor_usage_mode_sleep_usec = 0 if OS.has_feature("web") else 33000
	get_viewport().disable_3d = true
	# The small web template omits physics entirely; native editor builds
	# still disable their installed physics singletons while this UI runs.
	for server_name in ["PhysicsServer2D","PhysicsServer3D"]:
		if Engine.has_singleton(server_name): Engine.get_singleton(server_name).call("set_active",false)
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
	if not get_tree().has_meta("test_mode"): state.load_save()
	levels = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	for level in levels:
		level.id = int(level.id)
		level.order = int(level.order)
		level_by_id[level.id] = level
	levels.sort_custom(func(a,b): return int(a.order) < int(b.order))
	party_clock = Timer.new()
	party_clock.wait_time = 1.0
	party_clock.timeout.connect(_party_tick)
	add_child(party_clock)
	answer_timer = Timer.new()
	answer_timer.one_shot = true
	answer_timer.wait_time = 0.18
	answer_timer.timeout.connect(func():
		if screen == "game" and not busy and WordRules.matches(entry.text,current,cursor,revealed): submit_answer())
	add_child(answer_timer)
	show_loading()
	await get_tree().process_frame
	if str(state.data.name).is_empty(): show_profile_setup()
	elif not state.data.tutorial: show_tutorial_intro()
	else: show_home()
	var refund = int(state.data.get("hint_refund_pending",0))
	if refund > 0:
		toast("Jokerlerin için "+str(refund)+" altın geri yüklendi.")
		state.data.hint_refund_pending = 0
		state.save()

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
		s.shadow_color = Color(0.10,0.16,0.39,0.15 if color == Color.WHITE else 0.20)
		s.shadow_size = 2
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
	for item in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: b.add_theme_color_override(item,fg)
	var skin = "teal" if bg == TEAL else "purple" if bg == PURPLE else "orange" if bg == CORAL else "gold" if bg == YELLOW else ""
	if not skin.is_empty():
		for variant in ["normal","hover","pressed","focus"]:
			var texture_style = StyleBoxTexture.new()
			texture_style.texture = load("res://assets/v4/button_"+skin+".webp")
			for side in [SIDE_LEFT,SIDE_RIGHT]: texture_style.set_texture_margin(side,30)
			for side in [SIDE_TOP,SIDE_BOTTOM]: texture_style.set_texture_margin(side,26)
			texture_style.content_margin_left = 16
			texture_style.content_margin_right = 16
			texture_style.content_margin_top = 12
			texture_style.content_margin_bottom = 14
			texture_style.modulate_color = Color("ededff") if variant == "pressed" else Color.WHITE
			b.add_theme_stylebox_override(variant,texture_style)
	else:
		b.add_theme_stylebox_override("normal",style(bg,16))
		b.add_theme_stylebox_override("hover",style(bg.lightened(0.05),16))
		b.add_theme_stylebox_override("pressed",style(bg.darkened(0.05),16))
		b.add_theme_stylebox_override("focus",style(bg,16,Color("b0bafa"),2))
	b.add_theme_stylebox_override("disabled",style(Color("e3e6f1"),16))
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
	bg.texture = load("res://assets/v4/landscape.webp")
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
	margin.add_theme_constant_override("margin_left",20)
	margin.add_theme_constant_override("margin_right",20)
	margin.add_theme_constant_override("margin_top",20)
	margin.add_theme_constant_override("margin_bottom",24)
	scroll.add_child(margin)
	page = box_to(margin,14)
	page_root = page
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

func brand(parent: Node, height: int = 180, _dark: bool = false) -> void:
	var title = center_label(parent,"Sözcük\nZinciri",53,Color.WHITE,true)
	title.custom_minimum_size.y = height
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("line_spacing",-12)
	title.add_theme_color_override("font_shadow_color",Color(0.13,0.17,0.39,0.35))
	title.add_theme_constant_override("shadow_offset_y",3)
	title.add_theme_constant_override("shadow_offset_x",0)

func sheet_to(parent: Node, separation: int = 14) -> VBoxContainer:
	var p = panel_to(parent,Color.WHITE,24)
	var st = p.get_theme_stylebox("panel").duplicate()
	st.content_margin_top = 22
	st.content_margin_bottom = 22
	p.add_theme_stylebox_override("panel",st)
	return box_to(p,separation)

func currency_to(parent: Node) -> void:
	var chip = panel_to(parent,Color.WHITE,12)
	var st = chip.get_theme_stylebox("panel").duplicate()
	st.content_margin_left = 9
	st.content_margin_right = 12
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	chip.add_theme_stylebox_override("panel",st)
	var h = row_to(chip,5)
	image_to(h,"v4/gem",Vector2(30,30))
	var amount = label_to(h,str(int(state.data.coins)),16,INK,true)
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func color_menu(parent: Node, title: String, icon_name: String, action: Callable, color: Color) -> void:
	var b = button_to(parent,"",action,color,Color.WHITE,76)
	var m = MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right"]: m.add_theme_constant_override("margin_"+edge,24)
	m.add_theme_constant_override("margin_top",10)
	m.add_theme_constant_override("margin_bottom",14)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(m)
	var h = row_to(m,16)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image_to(h,"v4/"+icon_name,Vector2(38,38))
	var title_label = label_to(h,title,23,Color.WHITE,true)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var arrow = label_to(h,"›",32,Color.WHITE)
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

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
	header("Bölümler",show_home)
	center_label(page,"Keşif rotanı seç",23,INK,true)
	var colors = [Color("d6eee5"),Color("d6e7fc"),Color("fce0d7"),Color("e3dafa")]
	for i in range(4):
		var category = CATEGORIES[i] if i < 3 else "Tümü"
		var count = category_done(category) if i < 3 else state.data.completed.size()
		var total = 8 if i < 3 else 24
		var b = button_to(page,"",func(): filter_category = category; show_levels(),colors[i],INK,100)
		var m = MarginContainer.new()
		m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for edge in ["left","right"]: m.add_theme_constant_override("margin_"+edge,18)
		m.add_theme_constant_override("margin_top",14)
		m.add_theme_constant_override("margin_bottom",14)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(m)
		var h = row_to(m,12)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var v = box_to(h,7)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label_to(v,category if i < 3 else "Tüm Bölümler",21,INK,true)
		var r = row_to(v,14)
		label_to(r,str(count)+" / "+str(total),14,BLUE,true)
		var progress = ProgressBar.new()
		progress.max_value = total
		progress.value = count
		progress.show_percentage = false
		progress.custom_minimum_size = Vector2(100,10)
		progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		progress.add_theme_stylebox_override("background",track_style(Color("bbc3d9")))
		progress.add_theme_stylebox_override("fill",track_style(TEAL))
		r.add_child(progress)
		var arrow = label_to(h,"›",35,INK)
		arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_label(page,"Kolay bağlantılardan zor zincirlere.",13,MUTED)

func header(title: String = "", back: Callable = Callable()) -> void:
	var h = row_to(page_root,10)
	if back.is_valid():
		var b = button_to(h,"‹",back,BLUE,Color.WHITE,42)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.custom_minimum_size.x = 42
		b.add_theme_font_size_override("font_size",32)
		for variant in ["normal","hover","pressed","focus"]:
			var st = b.get_theme_stylebox(variant).duplicate()
			st.content_margin_left = 0
			st.content_margin_right = 0
			st.content_margin_top = 0
			st.content_margin_bottom = 0
			b.add_theme_stylebox_override(variant,st)
		b.tooltip_text = "Geri dön"
	var l = label_to(h,title,19,Color.WHITE,true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	currency_to(h)
	if screen != "game": page = sheet_to(page_root)

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
		call_deferred("_reveal_web_focus",field)
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

func _reveal_web_focus(field: LineEdit) -> void:
	await get_tree().process_frame
	if not is_instance_valid(field) or not is_instance_valid(scroll): return
	scroll.ensure_control_visible(tile_area if field.has_meta("tile_input") and is_instance_valid(tile_area) else field)
	await get_tree().process_frame
	_position_web_input()

func show_profile_setup() -> void:
	reset_page("onboarding")
	gap(page,30)
	brand(page,180)
	page = sheet_to(page_root,16)
	center_label(page,"Birlikte başlayalım",25,INK,true)
	center_label(page,"Kelimeleri birbirine bağla,\nkendi zincirini tamamla.",16,MUTED)
	profile_name = create_entry(page,"Kullanıcı adını yaz…",16)
	profile_name.text = str(state.data.name)
	var go = button_to(page,"Devam Et     ›",_finish_profile,TEAL,Color.WHITE,60)
	go.disabled = profile_name.text.strip_edges().length() < 2
	profile_name.text_changed.connect(func(value): go.disabled = value.strip_edges().length() < 2)
	profile_name.text_submitted.connect(func(_value): _finish_profile())
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
	header("Nasıl oynanır?",show_profile if state.data.tutorial else Callable())
	center_label(page,"Bir sözcük diğerini açar.",25,INK,true)
	var card = panel_to(page,LILAC)
	var v = box_to(card,12)
	center_label(v,"SU  →  B A R D A Ğ I",22,BLUE,true)
	center_label(v,"Su bardağı! İlk harf bizden.\nKutulara dokun, ARDAĞI yaz.",16,INK)
	center_label(v,"BARDAĞI   →   BARDAK",21,PURPLE,true)
	center_label(v,"Doğru sözcük köküne dönüşür.\nSonra bardak altlığıyla devam edersin.",15,MUTED)
	label_to(page,"01    Kutulara dokun, kalan harfleri yaz.",15,INK,true)
	label_to(page,"02    Doğru cevapta otomatik devam et.",15,INK,true)
	label_to(page,"03    Takılırsan harf veya ipucu kullan.",15,INK,true)
	button_to(page,"Hadi Deneyelim     ›",func(): start_level(1,"tutorial"),TEAL)
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
	var h = row_to(page,8)
	var identity = button_to(h,str(state.data.name),show_profile,BLUE,Color.WHITE,36)
	identity.add_theme_font_size_override("font_size",14)
	identity.clip_text = true
	identity.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	currency_to(h)
	gap(page,12)
	brand(page,162)
	gap(page,12)
	var next = next_level_id()
	color_menu(page,"Tek Kişilik","user",func(): start_level(next),TEAL)
	color_menu(page,"Parti Modu","party",show_party_setup,PURPLE)
	color_menu(page,"1’e 1 Yarışma","versus",show_online,CORAL)
	gap(page,18)
	var bottom = row_to(page,12)
	button_to(bottom,"Bölümler",show_categories,BLUE,Color.WHITE,48)
	var settings = button_to(bottom,"Ayarlar",show_profile,BLUE,Color.WHITE,48)
	settings.icon = load("res://assets/v4/gear.webp")
	settings.expand_icon = true
	settings.add_theme_constant_override("icon_max_width",22)
	center_label(page,"Bir sözcükle başla, bağlantıyı keşfet.",13,Color.WHITE)

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
		var category_levels: Array = levels.filter(func(level): return level.category == CATEGORIES[i])
		for j in range(category_levels.size()):
			var level = category_levels[j]
			var id = int(level.id)
			var done = id in state.data.completed
			var unlocked = j == 0 or category_levels[j-1].id in state.data.completed or done
			var b = button_to(grid,str(int(level.order))+(" ✓" if done else ""),func(): start_level(id),Color("d6eee5") if done else LILAC,BLUE,64)
			b.custom_minimum_size.x = 65
			b.disabled = not unlocked
			b.tooltip_text = "Tekrar oyna" if done else "Önceki bölümü tamamla" if not unlocked else str(level.difficulty)
	center_label(page,"Her kategorinin ilk bölümü açık.\nÇözdükçe yeni bağlantılara ulaşırsın.",13,MUTED)

func start_level(id: int, selected_mode: String = "solo") -> void:
	mode = selected_mode
	current = level_by_id[id].duplicate(true)
	cursor = 1
	revealed = [0]
	clues = {}
	if mode == "solo" and state.data.active.has(str(id)):
		var saved = state.data.active[str(id)]
		cursor = clampi(int(saved.get("cursor",1)),1,current.words.size()-1)
		revealed = saved.get("revealed",[0]).map(func(at): return int(at))
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
		for child in page_root.get_children():
			page_root.remove_child(child)
			child.queue_free()
		page = page_root
	else:
		reset_page("game")
		entry = null
	header("Öğretici" if mode == "tutorial" else party_names[party_index % party_names.size()] if mode == "party" else current.category,leave_game)
	var top = row_to(page_root)
	var cat = label_to(top,"Seviye "+str(int(current.order))+" · "+current.difficulty,13,Color.WHITE,true)
	cat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if mode == "party": clock_label = label_to(top,str(party_remaining)+" sn",14,Color.WHITE,true)
	else: label_to(top,str(cursor)+" / "+str(current.words.size()-1)+" bağlantı",13,Color.WHITE)
	var progress_shell = panel_to(page_root,Color("f1f2fc"),24)
	var steps = row_to(progress_shell,8)
	steps.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in range(current.words.size()):
		if i > 0:
			var line = ColorRect.new()
			line.color = TEAL if i < cursor else Color("bac3df")
			line.custom_minimum_size = Vector2(22,3)
			line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			steps.add_child(line)
		var dot = panel_to(steps,TEAL if i < cursor else Color("a6afd1"),12)
		dot.custom_minimum_size = Vector2(17,17)
		var st = dot.get_theme_stylebox("panel").duplicate()
		for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]: st.set_content_margin(side,0)
		dot.add_theme_stylebox_override("panel",st)
	page = sheet_to(page_root,14)
	var chain = row_to(page,6)
	for i in range(current.words.size()):
		var col = box_to(chain,5)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.size_flags_stretch_ratio = 1
		var caption = center_label(col,str(i+1)+". Kelime",11,PURPLE if i == cursor else MUTED,true)
		caption.autowrap_mode = TextServer.AUTOWRAP_OFF
		var p = panel_to(col,Color("d7eee7") if i < cursor else LILAC,14)
		var st = p.get_theme_stylebox("panel").duplicate()
		st.content_margin_left = 3
		st.content_margin_right = 3
		st.content_margin_top = 12
		st.content_margin_bottom = 12
		if i == cursor:
			st.bg_color = Color.WHITE
			st.border_color = PURPLE
			st.set_border_width_all(2)
		p.add_theme_stylebox_override("panel",st)
		var shown = str(current.words[i]) if i < cursor else WordRules.form(current,i)[0]+" _ _" if i == cursor else "— —"
		var word = center_label(p,shown,13,BLUE,true)
		word.autowrap_mode = TextServer.AUTOWRAP_OFF
		word.clip_text = true
		word.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var prompt = panel_to(page,LILAC,16)
	center_label(prompt,str(cursor+1)+". kelimeyi tahmin et",17,BLUE,true)
	center_label(page,str(current.words[cursor-1])+"  →  ?",22,INK,true)
	active_card = panel_to(page,Color("f7f7ff"),18)
	var active = box_to(active_card,7)
	active_tiles.clear()
	tile_panels.clear()
	tile_area = row_to(active,4)
	tile_area.alignment = BoxContainer.ALIGNMENT_CENTER
	var surface = WordRules.form(current,cursor)
	for j in range(surface.length()):
		var tile = PanelContainer.new()
		tile.custom_minimum_size = Vector2(24 if surface.length() > 8 else 29,46)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tile_style = style(Color.WHITE,10,PURPLE if j == 0 else Color("d4dbef"),2 if j == 0 else 1)
		for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]: tile_style.set_content_margin(side,0)
		tile.add_theme_stylebox_override("panel",tile_style)
		tile_area.add_child(tile)
		var letter = label_to(tile,surface[j] if j in revealed else "",22,BLUE,true)
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		active_tiles.append(letter)
		tile_panels.append(tile)
	center_label(active,"Kutulara dokun · Kalan harfleri yaz",11,MUTED)
	if entry == null:
		entry = create_entry(self,"Harf kutuları",40)
		entry.set_meta("tile_input",true)
		entry.modulate.a = 0.0
		entry.text_submitted.connect(func(_value): submit_answer())
		entry.text_changed.connect(update_tiles)
	var hint_key = str(cursor)
	if mode == "tutorial":
		center_label(page,["","Su bardağı → B hazır. ARDAĞI yaz.","Bardak altlığı → A hazır. LTLIĞI yaz.","Altlık kumaşı → K hazır. UMAŞI yaz."][mini(cursor,3)],13,BLUE,true)
	if clues.has(hint_key):
		var bubble = panel_to(page,Color("fff0c5"),16)
		label_to(bubble,current.hints[cursor],14,INK)
	feedback = center_label(page,message if not message.is_empty() else "İlk harf bizden. Kalanı senden.",12,GREEN if not message.is_empty() else MUTED)
	var hint_row = row_to(page,10)
	var price_letter = "Ücretsiz" if mode == "tutorial" else "15 altın" if mode == "solo" else "−10 puan"
	var price_clue = "Ücretsiz" if mode == "tutorial" else "10 altın" if mode == "solo" else "−5 puan"
	var cb = button_to(hint_row,"İpucu Ver\n"+price_clue,reveal_clue,YELLOW,INK,64)
	cb.add_theme_font_size_override("font_size",15)
	cb.disabled = clues.has(hint_key)
	var lb = button_to(hint_row,"Harf Al\n"+price_letter,reveal_letter,PURPLE,Color.WHITE,64)
	lb.add_theme_font_size_override("font_size",15)
	busy = false
	if OS.has_feature("web"):
		web_input.setWord(int(current.id),cursor,str(current.words[cursor-1]),WordRules.form(current,cursor)[0],WordRules.form(current,cursor).length())
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
	var resolved = WordRules.resolve(value,current,cursor,revealed)
	var shown: String = resolved.letters
	for i in range(active_tiles.size()):
		active_tiles[i].text = shown[i] if i < shown.length() else ""
		active_tiles[i].add_theme_color_override("font_color",PURPLE if i in revealed else INK)
	answer_timer.stop()
	if resolved.accepted:
		feedback.text = "Doğru bağlantı!"
		feedback.add_theme_color_override("font_color",GREEN)
		answer_timer.start()
	elif resolved.reason == "overflow":
		feedback.text = "Fazla harf var. Son harfi silip tekrar dene."
		feedback.add_theme_color_override("font_color",Color("b46a3f"))
	elif resolved.reason == "phrase":
		feedback.text = "Yalnızca sıradaki sözcüğü yaz."
	else:
		var raw = WordRules.typed(value)
		var used = raw.length() if raw.begins_with(surface[0]) else raw.length()+1
		if not raw.is_empty() and used >= surface.length() and is_instance_valid(feedback):
			feedback.text = "Henüz olmadı. Bağlantıyı bir daha düşün."
			feedback.add_theme_color_override("font_color",Color("b46a3f"))

func submit_answer() -> void:
	if busy or screen != "game" or not is_instance_valid(entry): return
	if mode == "party" and Time.get_ticks_msec()-party_started >= 90000:
		party_clock.stop()
		finish_party_turn(false)
		return
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
			tw.parallel().tween_property(active_tiles[i],"scale",Vector2(1.1,1.1),0.09).set_delay(i*0.012)
		tw.chain().tween_interval(0.06)
		for i in range(active_tiles.size()):
			if i >= stem.length():
				tw.parallel().tween_property(tile_panels[i],"modulate:a",0.0,0.12)
			else:
				var at = i
				tw.parallel().tween_property(active_tiles[i],"scale",Vector2.ONE,0.12)
				tw.parallel().tween_callback(func():
					if is_instance_valid(active_tiles[at]): active_tiles[at].text = stem[at]).set_delay(0.045)
		tw.chain().tween_interval(0.05)
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
	var before = WordRules.resolve(entry.text,current,cursor,revealed)
	var hidden: Array = []
	for i in range(1,surface.length()):
		if not i in revealed: hidden.append(i)
	if hidden.is_empty(): return
	if mode == "solo" and not state.spend(GameState.LETTER_COST):
		feedback.text = "Harf için 15 altın gerekiyor."
		return
	if mode == "party": party_scores[party_index % party_names.size()] -= 10
	revealed.append(hidden.pick_random())
	# Keep entered letters in their cells when a joker locks another cell.
	var remainder = ""
	for i in range(surface.length()):
		if not i in revealed: remainder += str(before.letters)[i]
	entry.text = remainder.rstrip(" ")
	if OS.has_feature("web"): web_input.setValue(str(entry.get_instance_id()),entry.text)
	save_active()
	show_game("Bir harf daha açıldı.",true)
	update_tiles(entry.text)

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
	gap(page,68)
	page = sheet_to(page_root,18)
	center_label(page,"Seviye Tamamlandı!",27,BLUE,true)
	var stars = row_to(page,4)
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in range(3): image_to(stars,"v4/star",Vector2(80,92 if i == 1 else 78))
	var category = panel_to(page,LILAC,17)
	var category_box = box_to(category,3)
	center_label(category_box,"Öğretici" if mode == "tutorial" else current.category,20,BLUE,true)
	center_label(category_box,"Artık oyuna hazırsın!" if mode == "tutorial" else "Seviye "+str(int(current.order)),14,MUTED)
	if mode != "tutorial":
		var reward = panel_to(page,LILAC,17)
		var h = row_to(reward,7)
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		if rewarded: image_to(h,"v4/gem",Vector2(36,36))
		var amount = label_to(h,"+"+str(GameState.REWARD) if rewarded else "Daha önce tamamlandı",27 if rewarded else 15,BLUE,true)
		amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_label(page,"  ·  ".join(current.links),13,MUTED)
	if mode == "tutorial": button_to(page,"Oyuna Başla     ›",show_home,TEAL,Color.WHITE,60)
	else:
		var number = int(current.order)
		if number < levels.size(): button_to(page,"Sonraki Seviye     ›",func(): start_level(int(levels[number].id)),TEAL,Color.WHITE,60)
		else: button_to(page,"Bölümlere Dön",show_levels,TEAL,Color.WHITE,60)
	button_to(page,"Ana Menü",show_home,Color("e4e8f8"),INK,54)
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
	art_to(page,"icon_party",Vector2(70,70))
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
	gap(page,8)
	art_to(page,"icon_party",Vector2(90,90))
	var l = label_to(page,"Sıra sende,\n"+party_names[party_index % party_names.size()]+"!",33,INK,true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_to(page,"Telefonu bu oyuncuya ver. Hazır olduğunda 90 saniyelik süre başlayacak.",17,MUTED)
	gap(page,20)
	button_to(page,"Hazırım!   →",party_countdown,YELLOW,INK)

func party_countdown() -> void:
	reset_page("countdown")
	gap(page,210)
	var l = label_to(page,"3",100,Color.WHITE,true)
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
	header("Parti Modu")
	art_to(page,"icon_party",Vector2(72,72))
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
	header("Parti Sonuçları",show_home)
	image_to(page,"v4/star",Vector2(76,76))
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
	header("1’e 1 Yarışma",show_home)
	var players = row_to(page,12)
	for i in range(2):
		var p = panel_to(players,Color("d6e7fc") if i == 0 else Color("ffe0e7"),18)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b = box_to(p,8)
		center_label(b,"Sen" if i == 0 else "Rakip",17,BLUE,true)
		center_label(b,"—",42,INK,true)
	var note = panel_to(page,LILAC,20)
	var v = box_to(note,14)
	center_label(v,"Çok yakında",27,BLUE,true)
	center_label(v,"Oda koduyla eşleş, aynı zincirde yarış.",16,MUTED)
	center_label(v,"Çevrim içi bağlantı henüz açık değil.",14,INK,true)
	label_to(page,"•  Oda kurma ve kodla katılma\n•  Eş zamanlı başlangıç ve canlı skor\n•  Oyun içi kısa mesajlar",15,MUTED)
	button_to(page,"Şimdilik Parti Oynayalım",show_party_setup,TEAL,Color.WHITE,60)
	button_to(page,"Ana Menü",show_home,LILAC,INK)

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
	center_label(page,"Türkçe · Sürüm 5.0\nİlerlemen yalnızca bu cihazda saklanır.",12,MUTED)

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
