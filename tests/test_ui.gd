extends SceneTree
## Headless integration smoke test of the real scene, controls, and game APIs.
## Run: godot --headless --path . --script tests/test_ui.gd

var failures: Array[String] = []
var checks: int = 0
var app: Control
var game: Node
var catalog: Node
var disposable_path: String
var original_path: String
var original_profile: Dictionary


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: " + description)


func _run() -> void:
	await process_frame
	game = root.get_node("Game")
	catalog = root.get_node("Catalog")
	original_path = game.save_path
	original_profile = game.profile.duplicate(true)
	disposable_path = "user://folio_ui_test_%d.json" % Time.get_ticks_usec()
	game.save_path = disposable_path
	game.load_profile()
	game.set_setting("reduced_motion", true)
	game.set_setting("sound", false)
	var main_script: GDScript = load("res://scripts/main.gd")
	app = main_script.new()
	app.size = Vector2(720, 1280)
	root.add_child(app)
	app.set_process(false)
	await process_frame
	_check(app.current_screen == "home", "Main scene opens to the home screen")
	_check(is_instance_valid(app.nav), "Home navigation is present")
	_check(_labels(app.stage).contains("folio."), "Home renders the Folio wordmark")
	await _test_wheel_input()
	await _test_journey()
	await _test_navigation_and_learning()
	await _test_modes()
	await _test_preferences()
	app.free()
	game.profile = original_profile
	game.save_path = original_path
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(disposable_path + suffix):
			DirAccess.remove_absolute(disposable_path + suffix)
	await process_frame
	if failures.is_empty():
		print("PASS: %d UI integration checks." % checks)
		quit(0)
	else:
		printerr("FAILED: %d of %d UI integration checks." % [failures.size(), checks])
		quit(1)


func _labels(node: Node) -> String:
	var text: String = ""
	if node is Label or node is Button:
		text += str(node.text) + "\n"
	for child: Node in node.get_children():
		text += _labels(child)
	return text


func _type_word(word: String) -> void:
	for letter: String in word:
		var key := InputEventKey.new()
		key.pressed = true
		key.unicode = letter.unicode_at(0)
		key.keycode = letter.unicode_at(0)
		app._unhandled_key_input(key)
	var submit := InputEventKey.new()
	submit.pressed = true
	submit.keycode = KEY_ENTER
	app._unhandled_key_input(submit)


func _mouse_button(wheel_control: Control, at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.pressed = pressed
	wheel_control._gui_input(event)


func _mouse_motion(wheel_control: Control, at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	wheel_control._gui_input(event)


func _test_wheel_input() -> void:
	var wheel_script: GDScript = load("res://scripts/letter_wheel.gd")
	var touch_wheel: Control = wheel_script.new()
	touch_wheel.size = Vector2(640, 345)
	touch_wheel.setup("CATS", app.theme.default_font, app.colors)
	root.add_child(touch_wheel)
	await process_frame
	# Headless rendering does not populate hit targets through _draw().
	touch_wheel._layout_points()
	var submissions: Array[String] = []
	touch_wheel.word_submitted.connect(func(word: String): submissions.append(word))
	_mouse_button(touch_wheel, touch_wheel.points[0], true)
	_mouse_motion(touch_wheel, touch_wheel.points[1])
	_mouse_motion(touch_wheel, touch_wheel.points[2])
	_check(touch_wheel.current_word() == "CAT", "Press and drag connects the letter tiles in pointer order")
	_mouse_motion(touch_wheel, touch_wheel.points[0])
	_check(touch_wheel.current_word() == "CAT", "Dragging onto an already used tile cannot duplicate its letter")
	_mouse_button(touch_wheel, touch_wheel.points[0], false)
	_check(submissions == ["CAT"], "Releasing a swipe emits its assembled word exactly once")
	_check(catalog.valid_bonus(submissions[0], "CATS"), "Swipe submission is formable and recognized by the offline dictionary")
	_check(touch_wheel.selected.is_empty(), "Swipe submission clears the current selection")
	for index: int in [0, 1, 2]:
		_mouse_button(touch_wheel, touch_wheel.points[index], true)
		_mouse_button(touch_wheel, touch_wheel.points[index], false)
	_check(touch_wheel.current_word() == "CAT", "Independent taps build and preserve a word selection")
	_check(submissions.size() == 1, "Tapping letters waits for Submit rather than submitting each tap")
	_mouse_button(touch_wheel, touch_wheel.points[0], true)
	_mouse_button(touch_wheel, touch_wheel.points[0], false)
	_check(touch_wheel.current_word() == "CAT", "Tapping an already selected tile cannot reuse its letter")
	var original_letters: Array[String] = touch_wheel.letters.duplicate()
	original_letters.sort()
	_mouse_button(touch_wheel, touch_wheel.size / 2.0, true)
	_mouse_button(touch_wheel, touch_wheel.size / 2.0, false)
	var shuffled_letters: Array[String] = touch_wheel.letters.duplicate()
	shuffled_letters.sort()
	_check(shuffled_letters == original_letters, "Center shuffle preserves the complete letter multiset")
	_check(touch_wheel.selected.is_empty() and submissions.size() == 1, "Center shuffle clears the selection without submitting a word")
	touch_wheel.free()


func _test_journey() -> void:
	app._start_puzzle("campaign", 1)
	await process_frame
	_check(app.current_screen == "puzzle" and app.current_mode == "campaign", "Journey starts a campaign puzzle")
	_check(is_instance_valid(app.wheel), "Puzzle creates the interactive letter wheel")
	_check(app.progress.found.is_empty(), "New journey puzzle has no found words")
	app._submit_word("ZZZZZZZZZZ")
	_check(app.progress.found.is_empty(), "Invalid UI submission does not change progress")
	_check(str(app.feedback.text).contains("Try another"), "Invalid answer provides visible feedback")
	var words: Array = app.puzzle.words.duplicate()
	_type_word(str(words[0]))
	await process_frame
	_check(app.progress.found.has(words[0]), "Keyboard letter input and Enter submit a valid word")
	var count: int = app.progress.found.size()
	app._submit_word(str(words[0]))
	_check(app.progress.found.size() == count, "Duplicate UI submission does not count twice")
	app._show_definition(str(words[0]))
	await process_frame
	_check(is_instance_valid(app.overlay), "Found-word definition opens a modal")
	_check(_labels(app.overlay).contains(catalog.meaning(str(words[0]))), "Definition modal renders the offline dictionary meaning")
	app._close_modal()
	var before: int = int(game.profile.coins)
	app._use_hint()
	_check(int(game.profile.coins) == before - 15, "Hint button charges the configured cost")
	_check(not app.progress.hints.is_empty(), "Hint button refreshes visible progress")
	var earned_coins: int = int(game.profile.coins)
	var existing_hints: Dictionary = app.progress.hints.duplicate()
	game.profile.coins = 0
	app._use_hint()
	_check(int(game.profile.coins) == 0 and app.progress.hints == existing_hints, "Zero-coin hint attempt spends nothing and reveals nothing")
	_check(is_instance_valid(app.toast_panel) and _labels(app.toast_panel).contains("You need 15"), "Zero-coin hint clearly reports insufficient currency")
	game.profile.coins = earned_coins
	app._free_clue()
	await process_frame
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await process_frame
	_check(not is_instance_valid(app.overlay) and app.current_screen == "puzzle", "Android Back dismisses a clue modal while remaining in the puzzle")
	for index: int in range(1, words.size()):
		app._submit_word(str(words[index]))
		await process_frame
	_check(game.next_level() == 2, "Completing the visible puzzle unlocks level 2")
	_check(is_instance_valid(app.overlay), "Puzzle completion opens the completion panel")
	_check(_labels(app.overlay).contains("Beautifully put."), "Completion panel has its success message")
	app._show_home()
	await process_frame
	_check(app.current_screen == "home", "Player can return home after completion")


func _test_navigation_and_learning() -> void:
	app._show_journey()
	await process_frame
	_check(app.current_screen == "journey", "Journey browser opens")
	_check(_labels(app.stage).contains("PAGES 0001"), "Journey browser shows the first page range")
	app.journey_page = 103
	app._show_journey()
	await process_frame
	_check(_labels(app.stage).contains("5200"), "Journey browser can reach the final campaign page")
	app.journey_page = 0
	app._show_journal()
	await process_frame
	_check(app.current_screen == "journal", "Vocabulary collection opens")
	_check(not game.due_words().is_empty(), "First-session words are ready for recall")
	app._start_review()
	await process_frame
	_check(not str(app.recall_word).is_empty() and is_instance_valid(app.overlay), "Recall shows a due word's meaning")
	_check(_labels(app.overlay).contains("Turn over the word"), "Recall initially conceals its answer")
	app._reveal_review()
	await process_frame
	_check(_labels(app.overlay).contains(str(app.recall_word).capitalize()), "Recall answer can be revealed")
	app._close_modal()
	var original_tea_meaning: String = catalog.meaning("TEA")
	game.learn_word("TEA")
	game.profile.learned.TEA.due = 0
	app._start_review()
	await process_frame
	_check(app.recall_word == "TEA", "Recall selects the explicitly due TEA card")
	var tea_pattern := RegEx.new()
	tea_pattern.compile("(?i)\\btea\\b")
	_check(tea_pattern.search(_labels(app.overlay)) == null, "Recall clue conceals the answer TEA embedded in its definition")
	_check(catalog.meaning("TEA") == original_tea_meaning, "Concealing a recall answer preserves the original dictionary definition")
	app._reveal_review()
	await process_frame
	_check(_labels(app.overlay).contains(original_tea_meaning), "Revealed recall card restores the full unmasked dictionary meaning")
	app._close_modal()
	app._show_studio()
	await process_frame
	_check(app.current_screen == "studio", "Studio screen opens")
	_check(_labels(app.stage).contains("MILESTONES"), "Studio renders progress challenges")
	_check(_labels(app.stage).contains("Coral ink"), "Studio renders the earn-only shop")
	_check(_labels(app.stage).contains("Cobalt ink"), "Studio offers the original free cobalt ink after a cosmetic change")


func _test_modes() -> void:
	var campaign_count: int = game.profile.completed.size()
	app._start_puzzle("daily", catalog.daily_id())
	await process_frame
	_check(str(app.progress.key) == "daily:" + game.today(), "Daily UI uses the current UTC puzzle key")
	_check(int(app.puzzle.id) == int(app.progress.level_id), "Daily displayed rack matches the saved daily puzzle")
	app._show_home()
	app._show_mode_picker("cozy")
	await process_frame
	_check(_labels(app.overlay).contains("Gentle") and _labels(app.overlay).contains("Intense"), "Mode picker exposes all difficulty choices")
	for difficulty: int in range(1, 6):
		var selected: int = app._pick_level(difficulty)
		_check(int(catalog.level(selected).difficulty) == difficulty, "Difficulty picker returns the requested level band")
	app._start_puzzle("cozy", 10)
	await process_frame
	_check(app.current_mode == "cozy" and not app.sprint_active, "Cozy mode starts without a countdown")
	app._free_clue()
	await process_frame
	_check(is_instance_valid(app.overlay) and _labels(app.overlay).contains("FREE CLUE"), "Cozy free-definition clue is available")
	app._close_modal()
	app._start_puzzle("clue", 10)
	await process_frame
	var target: String = app._next_word()
	_check(_labels(app.stage).contains(app._clue_meaning(target)), "Clue mode renders its current definition without exposing the answer")
	if app.puzzle.words.size() > 1:
		app._submit_word(str(app.puzzle.words[1]))
		_check(app.progress.found.is_empty(), "Clue mode accepts the word matching the current definition first")
	app._submit_word(target)
	await process_frame
	_check(app.progress.found.has(target), "Clue mode accepts its current answer")
	app._show_home()
	app.sprint_active = true
	app.sprint_paused = false
	app.sprint_remaining = 90.0
	app.sprint_score = 0
	app._start_puzzle("sprint", 10)
	await process_frame
	app._process(2.0)
	_check(is_equal_approx(app.sprint_remaining, 88.0), "Sprint countdown advances during play")
	app._pause_sprint()
	app._process(10.0)
	_check(is_equal_approx(app.sprint_remaining, 88.0), "Sprint countdown freezes while paused")
	app._close_modal()
	app.sprint_paused = false
	app._submit_word(str(app.puzzle.words[0]))
	await process_frame
	_check(app.sprint_score == 1, "Sprint counts a valid discovered word")
	app._end_sprint()
	await process_frame
	_check(not app.sprint_active, "Ending a sprint stops its timer")
	_check(int(game.profile.stats.sprint_best) == 1, "Sprint completion stores the personal best")
	var saved_balance: int = int(game.profile.coins)
	var saved_hints: Dictionary = app.progress.hints.duplicate()
	app._use_hint()
	_check(int(game.profile.coins) == saved_balance and app.progress.hints == saved_hints, "A completed Sprint cannot spend coins on another hint")
	app._dismiss_modal()
	await process_frame
	_check(app.current_screen == "home" and not is_instance_valid(app.overlay), "Dismissing Sprint results returns to the home screen")
	app._use_hint()
	_check(int(game.profile.coins) == saved_balance, "Dismissed Sprint results cannot spend coins on stale puzzle hints")
	game.load_profile()
	_check(int(game.profile.stats.sprint_best) == 1, "Sprint personal best survives a profile reload")
	_check(game.profile.completed.size() == campaign_count, "Daily and practice UI do not unlock campaign progress")
	app._show_home()


func _test_preferences() -> void:
	app._show_settings()
	await process_frame
	_check(is_instance_valid(app.overlay), "Preferences open")
	_check(_labels(app.overlay).contains("Reduced motion"), "Preferences expose reduced-motion controls")
	game.set_setting("theme", "midnight")
	app._set_colors()
	app._refresh_screen()
	await process_frame
	_check(app.colors.paper.get_luminance() < 0.1, "Midnight mode applies a dark background")
	game.profile.coins = 1000
	for accent: String in ["coral", "violet", "amber"]:
		game.purchase_cosmetic(accent)
	var midnight_swatches: Array[Color] = []
	for theme_name: String in ["paper", "midnight"]:
		game.set_setting("theme", theme_name)
		for accent: String in ["cobalt", "coral", "violet", "amber"]:
			game.set_setting("accent", accent)
			app._set_colors()
			var foreground: Color = app.colors.on_accent
			var background: Color = app.colors.accent
			_check(_contrast(foreground, background) >= 4.5, "%s %s primary text meets 4.5:1 contrast" % [theme_name, accent])
			var primary: Button = app._button("Test primary", func(): pass, true)
			_check(primary.get_theme_color("font_color") == foreground, "%s %s primary button uses the accessible foreground" % [theme_name, accent])
			primary.free()
			if theme_name == "midnight":
				_check(not midnight_swatches.has(background), "Midnight %s ink has its own distinct accent color" % accent)
				midnight_swatches.append(background)
	app._refresh_screen()
	await process_frame
	app._show_help()
	await process_frame
	_check(_labels(app.overlay).contains("Make a connection."), "How-to-play guide renders")
	app._show_about()
	await process_frame
	_check(_labels(app.overlay).contains("WordNet"), "About panel includes dictionary attribution")


func _contrast(a: Color, b: Color) -> float:
	var first: float = a.srgb_to_linear().get_luminance()
	var second: float = b.srgb_to_linear().get_luminance()
	return (maxf(first, second) + 0.05) / (minf(first, second) + 0.05)
