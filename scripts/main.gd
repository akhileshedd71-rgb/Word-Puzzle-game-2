extends Control

const Wheel = preload("res://scripts/letter_wheel.gd")
const Mark = preload("res://scripts/mark.gd")
const SANS = preload("res://assets/fonts/DMSans.ttf")
const SERIF = preload("res://assets/fonts/Editorial.tres")
const DIFFICULTY = ["", "Gentle", "Easy", "Thoughtful", "Tricky", "Intense"]
const CHAPTERS = ["First light", "Open windows", "Side streets", "Hidden patterns", "Wider horizons", "Between the lines", "The long way home", "After hours"]
var colors: Dictionary
var page: VBoxContainer
var stage: Control
var nav: HBoxContainer
var overlay: Control
var toast_panel: Control
var current_screen = "home"
var current_mode = "campaign"
var current_level = 1
var puzzle: Dictionary = {}
var progress: Dictionary = {}
var wheel: Control
var entry: Label
var feedback: Label
var coin_label: Label
var timer_label: Label
var sprint_remaining = 90.0
var sprint_score = 0
var sprint_active = false
var sprint_paused = false
var practice_difficulty = 2
var journey_page = 0
var journal_filter = ""
var recall_word = ""
var sound_player: AudioStreamPlayer
var last_word = ""

func _ready() -> void:
	_set_colors()
	var ui_theme = Theme.new()
	ui_theme.default_font = SANS
	ui_theme.default_font_size = 24
	theme = ui_theme
	sound_player = AudioStreamPlayer.new()
	add_child(sound_player)
	_make_chime()
	get_tree().auto_accept_quit = false
	if not Catalog.load_error.is_empty():
		_screen("error",false)
		page.add_child(_label("The pages are missing.",48,colors.ink,true))
		page.add_child(_label(Catalog.load_error + " Please reinstall this build.",26,colors.muted))
	else:
		_show_home()
		if Game.recovered_backup:
			_toast("Your previous saved progress was recovered.")
	Game.changed.connect(func():
		if not Game.last_save_error.is_empty():
			_toast(Game.last_save_error)
	)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and sprint_active:
		sprint_paused = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and sprint_active and sprint_paused:
		call_deferred("_pause_sprint")
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_instance_valid(overlay):
			_dismiss_modal()
		elif current_screen == "puzzle":
			_leave_puzzle()
		else:
			_show_home()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		Game.save_profile()
		get_tree().quit()

func _set_colors() -> void:
	var night = Game.profile.settings.theme == "midnight"
	var accents = {"cobalt":"345ded", "coral":"c34d40", "violet":"7950c7", "amber":"986012"}
	var night_accents = {"cobalt":"8aa6ff", "coral":"ffa18e", "violet":"c5a1ff", "amber":"efc573"}
	colors = {"paper":Color("111a2c") if night else Color("f6f7fc"), "ink":Color("f3f5fd") if night else Color("182238"), "muted":Color("a1aecb") if night else Color("66728b"), "line":Color("34415a") if night else Color("d9deec"), "accent":Color(night_accents.get(Game.profile.settings.accent,"8aa6ff")) if night else Color(accents.get(Game.profile.settings.accent,"345ded")), "tint":Color("233657") if night else Color("e8edff"), "card":Color("1a263d") if night else Color.WHITE, "coral":Color("ffa18e") if night else Color("bc493a"), "success":Color("91d4ca") if night else Color("17796d"), "on_accent":Color("111a2c") if night else Color.WHITE}
	RenderingServer.set_default_clear_color(colors.paper)

func _screen(name_: String, with_nav: bool = true) -> void:
	current_screen = name_
	if is_instance_valid(stage):
		remove_child(stage)
		stage.queue_free()
	stage = Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(stage)
	var background = ColorRect.new()
	background.color = colors.paper
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(background)
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_bottom = -120 if with_nav else -16
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_theme_stylebox_override("panel", _style(colors.paper, 0))
	stage.add_child(scroll)
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 38)
	margin.add_theme_constant_override("margin_right", 38)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	scroll.add_child(margin)
	page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 18)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(page)
	if with_nav:
		_navigation(name_)
	if not Game.profile.settings.reduced_motion:
		page.modulate.a = 0.0
		create_tween().tween_property(page, "modulate:a", 1.0, 0.18)
	overlay = null

func _style(bg: Color, radius: int = 10, border: Color = Color.TRANSPARENT, width: int = 0) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = bg
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.border_color = border
	box.set_border_width_all(width)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	return box

func _label(text_: String, font_size: int = 24, color: Color = Color.TRANSPARENT, serif: bool = false) -> Label:
	var label = Label.new()
	label.text = text_
	label.add_theme_font_override("font", SERIF if serif else SANS)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colors.ink if color == Color.TRANSPARENT else color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _eyebrow(text_: String, parent: Node = null) -> Label:
	var label = _label(text_.to_upper(), 19, colors.muted)
	(parent if parent != null else page).add_child(label)
	return label

func _button(text_: String, action: Callable, primary: bool = false, height: int = 78) -> Button:
	var button = Button.new()
	button.text = text_
	button.custom_minimum_size.y = height
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 25)
	for setting in ["font_color","font_hover_color","font_pressed_color"]:
		button.add_theme_color_override(setting, colors.on_accent if primary else colors.ink)
	button.add_theme_color_override("font_disabled_color", colors.muted)
	button.add_theme_stylebox_override("normal", _style(colors.accent if primary else colors.card, 8, colors.line, 0 if primary else 1))
	button.add_theme_stylebox_override("hover", _style(colors.accent.lightened(0.1) if primary else colors.tint, 8, colors.accent, 1))
	button.add_theme_stylebox_override("pressed", _style(colors.accent.darkened(0.12) if primary else colors.line, 8))
	button.add_theme_stylebox_override("disabled", _style(colors.paper, 8, colors.line, 1))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, 8, colors.coral, 3))
	button.pressed.connect(action)
	return button

func _row(parent: Node = null, gap: int = 14) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", gap)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(parent if parent != null else page).add_child(row)
	return row

func _column(parent: Node, gap: int = 10) -> VBoxContainer:
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", gap)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	return box

func _rule(parent: Node = null) -> void:
	var rule = ColorRect.new()
	rule.color = colors.line
	rule.custom_minimum_size.y = 1
	(parent if parent != null else page).add_child(rule)

func _space(height: int, parent: Node = null) -> void:
	var spacer = Control.new()
	spacer.custom_minimum_size.y = height
	(parent if parent != null else page).add_child(spacer)

func _mark(kind: String, color: Color, parent: Node, side: int = 62) -> Control:
	var mark = Mark.new()
	mark.kind = kind
	mark.color = color
	mark.fill = colors.paper
	mark.custom_minimum_size = Vector2(side, side)
	parent.add_child(mark)
	return mark

func _header(title_: String = "", back: bool = false) -> void:
	var row = _row()
	if back:
		var b = _button("‹", _leave_puzzle if current_screen == "puzzle" else _show_home, false, 66)
		b.custom_minimum_size.x = 66
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.add_theme_font_size_override("font_size", 40)
		row.add_child(b)
		var title = _label(title_.to_upper(), 19, colors.muted)
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(title)
	else:
		row.add_child(_label("folio.", 62, colors.ink, true))
	_mark("coin",colors.accent,row,36)
	coin_label = _label("%d" % int(Game.profile.coins), 23)
	coin_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	coin_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(coin_label)
	if not back:
		var settings = _button("", _show_settings, false, 62)
		settings.custom_minimum_size.x = 62
		settings.size_flags_horizontal = Control.SIZE_SHRINK_END
		row.add_child(settings)
		var icon = _mark("tune", colors.ink, settings, 44)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rule()

func _navigation(active: String) -> void:
	var base = PanelContainer.new()
	base.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	base.offset_top = -116
	base.add_theme_stylebox_override("panel", _style(colors.paper, 0, colors.line, 1))
	stage.add_child(base)
	nav = HBoxContainer.new()
	base.add_child(nav)
	var entries = [["Play", "home", "spark", _show_home], ["Journey", "journey", "grid", _show_journey], ["Words", "journal", "book", _show_journal], ["Studio", "studio", "sun", _show_studio]]
	for item in entries:
		var b = Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("normal", _style(Color.TRANSPARENT, 0))
		b.add_theme_stylebox_override("hover", _style(colors.tint, 8))
		b.add_theme_stylebox_override("pressed", _style(colors.line, 8))
		b.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, 6, colors.accent, 2))
		b.pressed.connect(item[3])
		nav.add_child(b)
		var v = VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.add_theme_constant_override("separation", 2)
		b.add_child(v)
		var tint = colors.accent if active == item[1] else colors.muted
		var icon = _mark(item[2], tint, v, 40)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var text_ = _label(item[0], 20, tint)
		text_.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(text_)

func _show_home() -> void:
	sprint_active = false
	_screen("home")
	_header()
	var issue = _row()
	issue.add_child(_label("A LITTLE WORDPLAY, EVERY DAY.", 18, colors.muted))
	var date_ = _label(_date_label(), 18, colors.muted)
	date_.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	issue.add_child(date_)
	page.add_child(_label("Find your next\naha moment.", 60, colors.ink, true))
	var feature = PanelContainer.new()
	feature.add_theme_stylebox_override("panel", _style(Color("345ded"), 14))
	page.add_child(feature)
	var content = _column(feature, 14)
	var level_id = Game.next_level()
	var top = _row(content)
	top.add_child(_label("THE LONG & LOVELY JOURNEY", 18, Color("dce5ff")))
	top.add_child(_label("%04d / 5200" % level_id, 18, Color("dce5ff")))
	var hero = _row(content, 20)
	var hero_text = _column(hero, 6)
	hero_text.add_child(_label(CHAPTERS[mini((level_id-1)/650,7)] + ".", 44, Color.WHITE, true))
	hero_text.add_child(_label("One small puzzle.\nA whole new perspective.", 23, Color("e2e9ff")))
	var art = Control.new()
	art.custom_minimum_size = Vector2(156, 144)
	hero.add_child(art)
	for i in 3:
		var tile = PanelContainer.new()
		tile.position = Vector2(12+i*41, 23+abs(i-1)*22)
		tile.size = Vector2(59, 65)
		tile.rotation = (i-1)*0.1
		var tile_style = _style(Color.WHITE if i != 1 else Color("ffa18e"),4)
		tile_style.set_content_margin_all(0)
		tile.add_theme_stylebox_override("panel",tile_style)
		art.add_child(tile)
		var l = _label(["A","H","A"][i], 34, Color("182238"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tile.add_child(l)
	var play = _button("Continue journey     →", func(): _start_puzzle("campaign",level_id), false, 74)
	play.add_theme_stylebox_override("normal",_style(Color.WHITE,7))
	play.add_theme_color_override("font_color",Color("182238"))
	content.add_child(play)
	_space(3)
	var daily_row = _row()
	_mark("spark", colors.coral, daily_row, 68)
	var daily_text = _column(daily_row, 3)
	daily_text.add_child(_label("THE DAILY EDITION", 18, colors.coral))
	daily_text.add_child(_label("A fresh page awaits.", 33, colors.ink, true))
	var done = Game.profile.daily_completed.has(Game.today())
	daily_text.add_child(_label("Completed today. Lovely work." if done else "Same letters for everyone. A little daily ritual.", 20, colors.muted))
	var daily_button = _button("Done" if done else "→",func(): _start_puzzle("daily",Catalog.daily_id()),false,82)
	daily_button.custom_minimum_size.x = 82
	daily_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	daily_row.add_child(daily_button)
	_rule()
	var mode_heading = _row()
	mode_heading.add_child(_label("FIND YOUR OWN PACE",18,colors.muted))
	var info = _button("How to play",_show_help,false,44)
	info.add_theme_font_size_override("font_size",18)
	info.size_flags_horizontal = Control.SIZE_SHRINK_END
	mode_heading.add_child(info)
	var modes = _row(null,12)
	_mode_card(modes,"Cozy","No rush.","moon","cozy",colors.accent)
	_mode_card(modes,"Clue","Read between.","book","clue",colors.coral)
	_mode_card(modes,"Sprint","90 seconds.","bolt","sprint",colors.accent)
	_rule()
	var review = _row()
	var rv = _column(review,4)
	rv.add_child(_label("LET THE GOOD WORDS STAY",18,colors.muted))
	var count = Game.due_words(9999).size()
	rv.add_child(_label("Your word collection.",31,colors.ink,true))
	rv.add_child(_label("%d collected · %d ready to revisit" % [Game.profile.learned.size(),count],21,colors.muted))
	var visit = _button("Open  →",_show_journal,false,72)
	visit.size_flags_horizontal = Control.SIZE_SHRINK_END
	review.add_child(visit)

func _mode_card(parent: Node, title_: String, subtitle: String, icon: String, mode: String, color: Color) -> void:
	var button = _button("",func(): _show_mode_picker(mode),false,159)
	parent.add_child(button)
	var box = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left=18
	box.offset_top=12
	box.add_theme_constant_override("separation",2)
	button.add_child(box)
	var mark = _mark(icon,color,box,46)
	mark.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	box.add_child(_label(title_,29,colors.ink,true))
	box.add_child(_label(subtitle,18,colors.muted))

func _date_label() -> String:
	var now = Time.get_datetime_dict_from_system(true)
	var months = ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"]
	return "%s %02d" % [months[int(now.month)-1],int(now.day)]

func _show_mode_picker(mode: String) -> void:
	var body = _modal("Find your pace.", "%s mode" % mode.capitalize())
	var descriptions = {"cozy":"A quiet place to find words. No timer, no lives, no hurry.","clue":"Let a definition lead the way. Solve the word behind each meaning.","sprint":"Find as many words as you can in 90 seconds. The clock pauses when you step away."}
	body.add_child(_label(descriptions[mode],25,colors.muted))
	_eyebrow("CHOOSE YOUR DIFFICULTY",body)
	for d in 5:
		var difficulty = d+1
		body.add_child(_button("%s     %s" % [DIFFICULTY[difficulty], "·".repeat(difficulty)],func():
			practice_difficulty=difficulty
			if mode=="sprint":
				sprint_remaining=90.0
				sprint_score=0
				sprint_active=true
				sprint_paused=false
			_start_puzzle(mode,_pick_level(difficulty))
		,false,65))

func _pick_level(difficulty: int) -> int:
	var candidates: Array[int] = []
	for l in Catalog.levels:
		if int(l.difficulty)==difficulty:
			candidates.append(int(l.id))
	return candidates.pick_random() if not candidates.is_empty() else 1

func _start_puzzle(mode: String, id: int) -> void:
	current_mode=mode
	current_level=id
	progress=Game.begin_puzzle(mode,id)
	if progress.is_empty():
		_show_home()
		_toast("Finish your current page to unlock this one.")
		return
	puzzle=Catalog.level(int(progress.level_id))
	if mode=="sprint":
		Game.reset_practice(progress.key)
		progress=Game.puzzle_progress(progress.key)
	last_word=""
	_render_puzzle()
	if bool(progress.get("completed",false)):
		_show_complete(0)

func _render_puzzle(message: String = "") -> void:
	_screen("puzzle",false)
	_header("The daily edition" if current_mode=="daily" else ("The campaign" if current_mode=="campaign" else current_mode+" mode"),true)
	var title_row = _row()
	var title = CHAPTERS[mini((current_level-1)/650,7)] + "." if current_mode=="campaign" else {"daily":"Today's little ritual.","cozy":"Take your time.","clue":"Between the lines.","sprint":"Quick thinking."}.get(current_mode,"Wordplay.")
	title_row.add_child(_label(title,45,colors.ink,true))
	if current_mode=="sprint":
		timer_label=_label("%02d:%02d" % [int(sprint_remaining)/60,int(sprint_remaining)%60],34,colors.coral)
		timer_label.size_flags_horizontal=Control.SIZE_SHRINK_END
		title_row.add_child(timer_label)
	var caption = "%s  ·  %s" % ["LEVEL %04d" % current_level if current_mode=="campaign" else (str(progress.day)+" · UTC" if current_mode=="daily" else "%d LETTERS" % str(puzzle.letters).length()),DIFFICULTY[int(puzzle.difficulty)].to_upper()]
	_eyebrow(caption)
	var track = _row()
	track.add_child(_label("%d / %d WORDS" % [progress.found.size(),puzzle.words.size()],19,colors.muted))
	var bonus = _label("%d BONUS" % progress.bonus.size(),19,colors.muted)
	bonus.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	track.add_child(bonus)
	var meter = ProgressBar.new()
	meter.custom_minimum_size.y=5
	meter.max_value=puzzle.words.size()
	meter.value=progress.found.size()
	meter.show_percentage=false
	var track_style = _style(colors.line,2)
	track_style.set_content_margin_all(0)
	var fill_style = _style(colors.accent,2)
	fill_style.set_content_margin_all(0)
	meter.add_theme_stylebox_override("background",track_style)
	meter.add_theme_stylebox_override("fill",fill_style)
	page.add_child(meter)
	if current_mode=="clue":
		var next = _next_word()
		var clue_panel = PanelContainer.new()
		clue_panel.add_theme_stylebox_override("panel",_style(colors.tint,8))
		page.add_child(clue_panel)
		var clue_box = _column(clue_panel,8)
		_eyebrow("THE CLUE · %d LETTERS" % next.length(),clue_box)
		clue_box.add_child(_label(_clue_meaning(next),28,colors.ink,true))
		_word_tiles(next,clue_box)
	else:
		var targets = GridContainer.new()
		targets.columns=2
		targets.add_theme_constant_override("h_separation",18)
		targets.add_theme_constant_override("v_separation",12)
		page.add_child(targets)
		for word in puzzle.words:
			_word_tiles(word,targets)
	feedback=_label(message if not message.is_empty() else ("Tap letters, then submit. Or swipe a word." if current_level<=3 and current_mode=="campaign" else "Every word is a small discovery."),21,colors.success if not message.is_empty() else colors.muted)
	feedback.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	feedback.custom_minimum_size.y=50
	page.add_child(feedback)
	entry=_label("· · ·",36,colors.accent)
	entry.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	entry.custom_minimum_size.y=54
	page.add_child(entry)
	wheel=Wheel.new()
	wheel.custom_minimum_size=Vector2(0,345)
	wheel.setup(puzzle.letters,SANS,colors)
	wheel.word_submitted.connect(_submit_word)
	wheel.selection_changed.connect(func(word):
		if is_instance_valid(entry):
			entry.text=word if not word.is_empty() else "· · ·"
	)
	page.add_child(wheel)
	var actions = _row()
	actions.add_child(_button("Clear",func(): wheel.clear_selection(),false,74))
	actions.add_child(_button("Submit",func(): _submit_word(wheel.current_word()),true,74))
	var assists = _row()
	assists.add_child(_button("Hint  ·  15 coins",_use_hint,false,68))
	assists.add_child(_button("A little clue",_free_clue,false,68))
	var footer = _row()
	var help = _button("How to play",_show_help,false,50)
	help.add_theme_font_size_override("font_size",18)
	footer.add_child(help)
	if current_mode=="sprint":
		var pause = _button("Pause",_pause_sprint,false,50)
		pause.add_theme_font_size_override("font_size",18)
		footer.add_child(pause)
	else:
		footer.add_child(_label("Progress saves as you play.",18,colors.muted))

func _word_tiles(word: String, parent: Node) -> void:
	var solved = progress.found.has(word)
	var hint_count = int(progress.hints.get(word,0))
	var button = Button.new()
	button.custom_minimum_size=Vector2(0,62)
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal",_style(colors.tint if solved else colors.card,5,colors.line,1))
	button.add_theme_stylebox_override("hover",_style(colors.tint,5,colors.accent,1))
	button.add_theme_stylebox_override("pressed",_style(colors.line,5))
	button.add_theme_stylebox_override("focus",_style(Color.TRANSPARENT,5,colors.accent,2))
	button.add_theme_font_size_override("font_size",27 if word.length()<=6 else 22)
	button.add_theme_color_override("font_color",colors.accent if solved else colors.ink)
	button.add_theme_color_override("font_hover_color",colors.ink)
	var display = ""
	for i in word.length():
		display += (word[i] if solved or i<hint_count else "_") + (" " if i<word.length()-1 else "")
	button.text=display
	button.pressed.connect(func():
		if solved:
			_show_definition(word)
		else:
			var body = _modal("A little nudge.","%d letters" % word.length())
			body.add_child(_label(_clue_meaning(word),29,colors.ink,true))
	)
	parent.add_child(button)

func _next_word() -> String:
	for word in puzzle.words:
		if not progress.found.has(word):
			return word
	return puzzle.words[0]

func _clue_meaning(word: String) -> String:
	# A dictionary meaning may contain its own headword. Conceal it in recall/clues.
	var pattern = RegEx.new()
	pattern.compile("(?i)\\b" + word + "\\b")
	return pattern.sub(Catalog.meaning(word),"…",true)

func _submit_word(word: String) -> void:
	if word.is_empty() or (current_mode=="sprint" and (sprint_paused or not sprint_active)):
		return
	word=word.to_upper()
	if current_mode=="clue" and puzzle.words.has(word) and word!=_next_word() and not progress.found.has(word):
		feedback.text="A good word. Try the word for this clue first."
		wheel.clear_selection()
		return
	var result = Game.record_word(progress.key,word)
	if result.status=="invalid":
		feedback.text="Not in this word collection. Try another arrangement."
		feedback.add_theme_color_override("font_color",colors.coral)
		wheel.clear_selection()
		return
	if result.status=="duplicate":
		feedback.text="Already found. There are more words in there."
		wheel.clear_selection()
		return
	if current_mode=="sprint":
		sprint_score+=1
	last_word=word
	_chime()
	progress=Game.puzzle_progress(progress.key)
	_render_puzzle("%s · %s" % [word,"A lovely bonus find!" if result.status=="bonus" else "Added to your word collection."])
	if result.completed:
		if current_mode=="sprint":
			_start_puzzle("sprint",_pick_level(practice_difficulty))
		else:
			_show_complete(int(result.reward))

func _use_hint() -> void:
	if current_mode=="sprint" and not sprint_active:
		return
	var result = Game.purchase_hint(progress.key)
	if not result.ok:
		_toast(str(result.reason))
		return
	progress=Game.puzzle_progress(progress.key)
	_render_puzzle("A letter revealed. Follow the thread.")

func _free_clue() -> void:
	var word = _next_word()
	var body = _modal("A little nudge.","FREE CLUE · %d LETTERS" % word.length())
	body.add_child(_label(_clue_meaning(word),29,colors.ink,true))
	body.add_child(_label("Use the letters on the wheel to find this word.",22,colors.muted))

func _show_complete(reward: int) -> void:
	var body = _modal("Beautifully put.","THE DAILY EDITION" if current_mode=="daily" else "PAGE COMPLETE")
	var top = _row(body)
	_mark("spark",colors.accent,top,80)
	top.add_child(_label("%d words found.\nA little wiser than before." % progress.found.size(),28,colors.ink,true))
	if reward>0:
		body.add_child(_label("+%d coins   ·   Yours to keep." % reward,23,colors.accent))
	else:
		body.add_child(_label("A page worth revisiting. Words stay in your notebook.",22,colors.muted))
	_rule(body)
	var word = last_word if not last_word.is_empty() else str(puzzle.words.back())
	_eyebrow("ONE TO REMEMBER",body)
	body.add_child(_label(word.capitalize(),40,colors.ink,true))
	body.add_child(_label(Catalog.meaning(word),25,colors.muted))
	if current_mode=="campaign" and current_level<Catalog.total_levels():
		body.add_child(_button("Turn the page   →",func(): _start_puzzle("campaign",current_level+1),true))
	elif current_mode=="daily":
		body.add_child(_button("Copy spoiler-free result",_share_daily,true))
		body.add_child(_label("The next edition arrives at 00:00 UTC. Your journey is always open." if str(progress.day)==Game.today() else "You finished the %s edition. Today's puzzle is waiting on Play; past editions do not award new daily coins." % str(progress.day),21,colors.muted))
	else:
		body.add_child(_button("Another little puzzle   →",func(): _start_puzzle(current_mode,_pick_level(practice_difficulty)),true))
	body.add_child(_button("Back to the studio",_show_home))

func _share_daily() -> void:
	var share = "Folio · %s UTC\n%s\n%d words · %d bonus finds\nA little wordplay, every day." % [str(progress.day),"▰ ".repeat(progress.found.size()),progress.found.size(),progress.bonus.size()]
	DisplayServer.clipboard_set(share)
	_toast("Result copied. Share a little wordplay.")

func _process(delta: float) -> void:
	if sprint_active and not sprint_paused and current_screen=="puzzle" and not is_instance_valid(overlay):
		sprint_remaining=maxf(0.0,sprint_remaining-delta)
		if is_instance_valid(timer_label):
			timer_label.text="%02d:%02d" % [int(ceil(sprint_remaining))/60,int(ceil(sprint_remaining))%60]
		if sprint_remaining<=0:
			_end_sprint()

func _pause_sprint() -> void:
	if not sprint_active:
		return
	sprint_paused=true
	var body = _modal("Take a breath.","SPRINT PAUSED")
	body.add_child(_label("Your time is safe. Pick up whenever you're ready.",26,colors.muted))
	body.add_child(_button("Keep going   →",func():
		_close_modal()
		sprint_paused=false
	,true))
	body.add_child(_button("Finish this sprint",_end_sprint))

func _end_sprint() -> void:
	sprint_active=false
	sprint_paused=false
	var best = maxi(int(Game.profile.stats.get("sprint_best",0)),sprint_score)
	Game.profile.stats["sprint_best"]=best
	Game.save_profile()
	var body = _modal("And, exhale.","SPRINT COMPLETE")
	body.add_child(_label(str(sprint_score),84,colors.accent,true))
	body.add_child(_label("words found · personal best %d" % best,25,colors.muted))
	body.add_child(_label("A quick burst of wordplay. Every discovery is in your notebook.",27,colors.ink,true))
	body.add_child(_button("Another sprint",func(): _show_mode_picker("sprint"),true))
	body.add_child(_button("Back to the studio",_show_home))

func _leave_puzzle() -> void:
	if sprint_active:
		_pause_sprint()
	else:
		_show_home()

func _show_journey() -> void:
	_screen("journey")
	_header()
	_eyebrow("5,200 SMALL DISCOVERIES")
	page.add_child(_label("The long &\nlovely journey.",59,colors.ink,true))
	page.add_child(_label("A steady climb, with room to breathe. Each page brings a different set of letters.",25,colors.muted))
	var stats = _row()
	stats.add_child(_label("%d" % Game.profile.completed.size(),46,colors.accent,true))
	stats.add_child(_label("pages complete\n%d words collected" % Game.profile.learned.size(),22,colors.muted))
	_rule()
	var range_start = journey_page*50+1
	var range_end = mini(range_start+49,Catalog.total_levels())
	_eyebrow("PAGES %04d — %04d" % [range_start,range_end])
	var grid = GridContainer.new()
	grid.columns=5
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	page.add_child(grid)
	for id in range(range_start,range_end+1):
		var done = Game.profile.completed.has(str(id))
		var button = _button(str(id),func(): _start_puzzle("campaign",id),id==Game.next_level(),74)
		button.add_theme_font_size_override("font_size",22)
		button.disabled=not Game.is_unlocked(id)
		if done:
			button.add_theme_stylebox_override("normal",_style(colors.tint,8,colors.accent,1))
		grid.add_child(button)
	var paging = _row()
	var prev = _button("← Previous",func():
		journey_page=maxi(0,journey_page-1)
		_show_journey()
	)
	prev.disabled=journey_page==0
	paging.add_child(prev)
	var next = _button("Next →",func():
		journey_page+=1
		_show_journey()
	)
	next.disabled=range_end==Catalog.total_levels()
	paging.add_child(next)
	page.add_child(_button("Go to my next page",func():
		journey_page=(Game.next_level()-1)/50
		_show_journey()
	))

func _show_journal() -> void:
	_screen("journal")
	_header()
	_eyebrow("NOT JUST FOUND. REMEMBERED.")
	page.add_child(_label("A collection\nof good words.",58,colors.ink,true))
	var due = Game.due_words(9999)
	page.add_child(_label("%d words collected · %d ready to revisit" % [Game.profile.learned.size(),due.size()],24,colors.muted))
	page.add_child(_label("See a meaning. Recall the word. Return to it a little later. Small steps make words feel familiar.",25,colors.muted))
	var review_button = _button("Revisit %d words   →" % due.size(),_start_review,true)
	review_button.disabled=due.is_empty()
	page.add_child(review_button)
	var search = LineEdit.new()
	search.placeholder_text="Find a word in your collection…"
	search.text=journal_filter
	search.custom_minimum_size.y=70
	search.add_theme_stylebox_override("normal",_style(colors.card,8,colors.line,1))
	search.add_theme_stylebox_override("focus",_style(colors.card,8,colors.accent,2))
	search.add_theme_color_override("font_color",colors.ink)
	search.add_theme_color_override("font_placeholder_color",colors.muted)
	search.add_theme_font_size_override("font_size",24)
	search.text_submitted.connect(func(value):
		journal_filter=value.to_upper()
		_show_journal()
	)
	page.add_child(search)
	_rule()
	if Game.profile.learned.is_empty():
		_mark("book",colors.accent,page,88)
		page.add_child(_label("Your first word is waiting.",34,colors.ink,true))
		page.add_child(_label("Every word you discover gets a home here, along with its meaning. Start a page to begin your collection.",25,colors.muted))
		page.add_child(_button("Find my first words",func(): _start_puzzle("campaign",Game.next_level())))
	else:
		var words = Game.profile.learned.keys()
		words.sort()
		var shown = 0
		for word in words:
			if not journal_filter.is_empty() and not str(word).contains(journal_filter):
				continue
			if shown>=60:
				page.add_child(_label("Showing 60 words. Search to find more.",21,colors.muted))
				break
			var row = _row()
			var v = _column(row,5)
			v.add_child(_label(str(word).capitalize(),33,colors.ink,true))
			v.add_child(_label(Catalog.meaning(word),22,colors.muted))
			var b = _button("→",func(): _show_definition(word),false,66)
			b.custom_minimum_size.x=64
			b.size_flags_horizontal=Control.SIZE_SHRINK_END
			row.add_child(b)
			_rule()
			shown+=1
		if shown==0:
			page.add_child(_label("No matching words yet. Try another search.",25,colors.muted))

func _start_review() -> void:
	var due = Game.due_words(1)
	if due.is_empty():
		_show_journal()
		_toast("All caught up. Let those words settle in.")
		return
	recall_word=due[0]
	var body = _modal("Does this ring a bell?","WORD RECALL")
	body.add_child(_label(_clue_meaning(recall_word),34,colors.ink,true))
	body.add_child(_label("%d letters. Try to bring the word to mind before turning it over." % recall_word.length(),23,colors.muted))
	body.add_child(_button("Turn over the word",_reveal_review,true))

func _reveal_review() -> void:
	var body = _modal(recall_word.capitalize(),"THE WORD WAS")
	body.add_child(_label(Catalog.meaning(recall_word),27,colors.muted))
	body.add_child(_label("How did that feel? This guides when the word comes back.",24))
	body.add_child(_button("I remembered",func():
		Game.review_word(recall_word,true)
		_start_review()
	,true))
	body.add_child(_button("Let's meet again",func():
		Game.review_word(recall_word,false)
		_start_review()
	))

func _show_definition(word: String) -> void:
	var body = _modal(word.capitalize(),"A WORD WORTH KEEPING")
	var definition = Catalog.lexicon.get(word,{})
	_eyebrow(str(definition.get("pos","word")),body)
	body.add_child(_label(Catalog.meaning(word),30,colors.ink,true))
	if Game.profile.learned.has(word):
		var record = Game.profile.learned[word]
		body.add_child(_label("Collected · revisited %d times" % int(record.get("reviews",0)),22,colors.muted))
	body.add_child(_label("Definitions adapted from Princeton WordNet. A word can have more than one meaning.",19,colors.muted))

func _show_studio() -> void:
	_screen("studio")
	_header()
	_eyebrow("MAKE YOURSELF AT HOME")
	page.add_child(_label("Your little\nword studio.",59,colors.ink,true))
	page.add_child(_label("Small milestones. A fresh coat of ink.\nMake this space your own.",25,colors.muted))
	_eyebrow("MILESTONES")
	for challenge in Game.challenges():
		var row = _row()
		var v = _column(row,4)
		v.add_child(_label(challenge.title,29,colors.ink,true))
		v.add_child(_label("%s · %d / %d" % [challenge.description,mini(int(challenge.progress),int(challenge.goal)),int(challenge.goal)],20,colors.muted))
		var b = _button("Claim %d" % int(challenge.reward) if not challenge.claimed else "Collected",func():
			if Game.claim_challenge(challenge.id):
				_chime()
				_show_studio()
		,false,66)
		b.add_theme_font_size_override("font_size",20)
		b.size_flags_horizontal=Control.SIZE_SHRINK_END
		b.disabled=bool(challenge.claimed) or int(challenge.progress)<int(challenge.goal)
		row.add_child(b)
		_rule()
	_space(8)
	_eyebrow("THE INK SHOP · EARNED COINS ONLY")
	page.add_child(_label("A change of tone.",38,colors.ink,true))
	page.add_child(_label("A placeholder for a future shop. For now, everything here uses coins you earn by playing.",23,colors.muted))
	for item in [{"id":"cobalt","name":"Cobalt ink","cost":0}] + Game.shop_items():
		var id = str(item.id)
		if id in ["paper","midnight"]:
			continue
		var selected = Game.profile.settings.accent==id
		var owned = Game.profile.cosmetics.has(id)
		var row = _row()
		var swatches = {"cobalt":Color("345ded"),"coral":Color("c34d40"),"violet":Color("7950c7"),"amber":Color("986012")}
		_mark("spark",swatches.get(id,colors.accent),row,60)
		row.add_child(_label(str(item.get("name",id.capitalize())),28,colors.ink,true))
		var price = int(item.get("price",item.get("cost",0)))
		var b = _button("Selected" if selected else ("Use ink" if owned else "%d coins" % price),func():
			if Game.profile.cosmetics.has(id) or Game.purchase_cosmetic(id):
				Game.set_setting("accent",id)
				_set_colors()
				_show_studio()
			else:
				_toast("A few more pages will get you there.")
		,false,66)
		b.disabled=selected
		b.size_flags_horizontal=Control.SIZE_SHRINK_END
		row.add_child(b)
		_rule()
	page.add_child(_button("Reading preferences",_show_settings))

func _show_settings() -> void:
	var body = _modal("Make room for you.","READING PREFERENCES")
	body.add_child(_label("Choose your paper",26,colors.ink,true))
	var row = _row(body)
	for theme_name in ["paper","midnight"]:
		row.add_child(_button(theme_name.capitalize(),func():
			Game.set_setting("theme",theme_name)
			_set_colors()
			_refresh_screen()
			_show_settings()
		,Game.profile.settings.theme==theme_name,65))
	body.add_child(_button("Sound: " + ("on" if Game.profile.settings.sound else "off"),func():
		Game.set_setting("sound",not Game.profile.settings.sound)
		_show_settings()
	,false,65))
	body.add_child(_button("Reduced motion: " + ("on" if Game.profile.settings.reduced_motion else "off"),func():
		Game.set_setting("reduced_motion",not Game.profile.settings.reduced_motion)
		_show_settings()
	,false,65))
	body.add_child(_label("All progress is saved on this device. No account, ads, purchases, or internet connection needed.",22,colors.muted))
	body.add_child(_button("How to play",_show_help,false,64))
	body.add_child(_button("About Folio",_show_about,false,64))

func _refresh_screen() -> void:
	match current_screen:
		"puzzle": _render_puzzle()
		"journey": _show_journey()
		"journal": _show_journal()
		"studio": _show_studio()
		_: _show_home()

func _show_help() -> void:
	var body = _modal("Follow the letters.","A SMALL FIELD GUIDE")
	var hints = [["01","Make a connection.","Swipe through letters to make a word, then lift your finger. Or tap letters one by one and press Submit."],["02","Fill in the page.","Find every hidden target to finish. A letter tile can be used once per word. Other valid words count as bonus finds."],["03","Keep a good word.","Tap any completed word for its meaning. Your discoveries collect in Words, where spaced recall helps you revisit them."],["04","A nudge is always nearby.","Tap a blank word for a free definition clue. A hint reveals a letter for 15 earned coins. Tap the center of the wheel to shuffle."]]
	for item in hints:
		var row = _row(body)
		var number = _label(item[0],27,colors.accent,true)
		number.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
		row.add_child(number)
		var v = _column(row,5)
		v.add_child(_label(item[1],29,colors.ink,true))
		v.add_child(_label(item[2],23,colors.muted))
	body.add_child(_label("Desktop: type letters, Enter to submit, Backspace to undo. Escape goes back.",20,colors.muted))

func _show_about() -> void:
	var body = _modal("folio.","A LITTLE WORDPLAY, EVERY DAY")
	body.add_child(_label("An offline word studio made with Godot. 5,200 distinct campaign letter banks, a daily edition, and room to play your own way.",26,colors.ink,true))
	body.add_child(_label("Definitions: Princeton WordNet 3.0. Frequency guidance: wordfreq. Type: Fraunces & DM Sans, SIL Open Font License. WordNet © 2006 Princeton University. Full attribution and license notices are available below.",22,colors.muted))
	body.add_child(_button("Licenses & credits",_show_licenses,false,64))
	body.add_child(_label("v0.1 · Playtest edition\nEnglish vocabulary · Daily reset 00:00 UTC\nGenerated campaign; editorial tuning continues.",21,colors.muted))

func _modal(title_: String, kicker: String = "") -> VBoxContainer:
	_close_modal()
	overlay=Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(overlay)
	var shade = ColorRect.new()
	shade.color=Color(0.025,0.055,0.13,0.52)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_left=26
	center.offset_right=-26
	center.offset_top=36
	center.offset_bottom=-36
	overlay.add_child(center)
	var panel = PanelContainer.new()
	panel.custom_minimum_size.x=640
	panel.add_theme_stylebox_override("panel",_style(colors.paper,14))
	center.add_child(panel)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(600,0)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var body = VBoxContainer.new()
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",18)
	scroll.add_child(body)
	var top = _row(body)
	top.add_child(_label(kicker.to_upper(),18,colors.accent))
	var close = _button("×",_dismiss_modal,false,52)
	close.custom_minimum_size.x=54
	close.size_flags_horizontal=Control.SIZE_SHRINK_END
	close.add_theme_font_size_override("font_size",30)
	top.add_child(close)
	body.add_child(_label(title_,49,colors.ink,true))
	body.resized.connect(func():
		if is_instance_valid(scroll):
			scroll.custom_minimum_size.y=minf(body.size.y,size.y-140)
	)
	return body

func _dismiss_modal() -> void:
	_close_modal()
	if current_mode=="sprint" and current_screen=="puzzle" and not sprint_active:
		_show_home()
	elif sprint_active:
		sprint_paused=false

func _close_modal() -> void:
	if is_instance_valid(overlay):
		overlay.get_parent().remove_child(overlay)
		overlay.queue_free()
	overlay=null

func _toast(text_: String) -> void:
	if is_instance_valid(toast_panel):
		toast_panel.queue_free()
	toast_panel=PanelContainer.new()
	toast_panel.add_theme_stylebox_override("panel",_style(colors.ink,8))
	toast_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	toast_panel.offset_left=36
	toast_panel.offset_right=-36
	toast_panel.offset_top=-185
	toast_panel.offset_bottom=-120
	add_child(toast_panel)
	var text_label = _label(text_,22,colors.paper)
	text_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast_panel.add_child(text_label)
	var this_toast = toast_panel
	get_tree().create_timer(3.0).timeout.connect(func():
		if is_instance_valid(this_toast):
			this_toast.queue_free()
	)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode==KEY_ESCAPE:
		if is_instance_valid(overlay):
			_dismiss_modal()
		elif current_screen=="puzzle":
			_leave_puzzle()
		else:
			_show_home()
		get_viewport().set_input_as_handled()
		return
	if current_screen!="puzzle" or is_instance_valid(overlay) or not is_instance_valid(wheel):
		return
	if event.keycode==KEY_ENTER or event.keycode==KEY_KP_ENTER:
		_submit_word(wheel.current_word())
	elif event.keycode==KEY_BACKSPACE:
		if not wheel.selected.is_empty():
			wheel.selected.pop_back()
			wheel.selection_changed.emit(wheel.current_word())
			wheel.queue_redraw()
	elif event.unicode>=65 and event.unicode<=122:
		var character = String.chr(event.unicode).to_upper()
		for i in wheel.letters.size():
			if wheel.letters[i]==character and not wheel.selected.has(i):
				wheel._choose(i)
				break
	get_viewport().set_input_as_handled()

func _make_chime() -> void:
	var stream = AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=22050
	stream.stereo=false
	var bytes = PackedByteArray()
	bytes.resize(6615*2)
	for i in 6615:
		var t = float(i)/22050
		var envelope = exp(-t*17)*minf(t*180,1.0)
		var wave = (sin(TAU*660*t)+sin(TAU*990*t)*0.35)*envelope*0.13
		bytes.encode_s16(i*2,int(wave*32767))
	stream.data=bytes
	sound_player.stream=stream

func _chime() -> void:
	if Game.profile.settings.sound:
		sound_player.play()

func _show_licenses() -> void:
	var body = _modal("Made with good things.","LICENSES & CREDITS")
	body.add_child(_label("Game code: MIT. Content compilation and authored additions: CC BY-SA 4.0. WordNet text retains its Princeton license. Fonts: SIL Open Font License.",23,colors.muted))
	var notices = [["WordNet · Princeton University","res://data/licenses/WORDNET-LICENSE.txt"],["Content attribution & modifications","res://data/licenses/README.md"],["wordfreq & source credits","res://data/licenses/WORDFREQ-NOTICES.md"],["Creative Commons BY-SA 4.0","res://data/licenses/CC-BY-SA-4.0.txt"],["Fraunces · Undercase Type","res://assets/fonts/Fraunces-LICENSE.txt"],["DM Sans · Colophon Foundry","res://assets/fonts/DMSans-LICENSE.txt"],["Godot Engine · MIT","res://assets/GODOT-LICENSE.txt"]]
	for notice in notices:
		body.add_child(_button(notice[0],func(): _show_notice(notice[0],notice[1]),false,62))

func _show_notice(title_: String, path: String) -> void:
	var body = _modal(title_,"OPEN SOURCE NOTICES")
	body.add_child(_label(FileAccess.get_file_as_string(path),20,colors.muted))
