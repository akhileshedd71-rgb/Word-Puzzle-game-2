extends SceneTree
## Run: godot --headless --path . --script tests/test_systems.gd
## Uses a disposable save path, never the player's profile.

const GameStateScript = preload("res://scripts/game_state.gd")
var failures: Array[String] = []
var checks: int = 0
var catalog: Node
var game: Node
var test_save: String


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: " + description)


func _run() -> void:
	await process_frame
	catalog = root.get_node("Catalog")
	test_save = "user://folio_system_test_%d.json" % Time.get_ticks_usec()
	game = GameStateScript.new()
	game.save_path = test_save
	root.add_child(game)
	_test_catalog()
	if catalog.total_levels() > 0:
		_test_progress_and_rewards()
		_test_daily_and_modes()
		_test_hints_and_shop()
		_test_recall_and_challenges()
		_test_persistence()
	game.free()
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(test_save + suffix):
			DirAccess.remove_absolute(test_save + suffix)
	if failures.is_empty():
		print("PASS: %d system and content checks." % checks)
		quit(0)
	else:
		printerr("FAILED: %d of %d checks." % [failures.size(), checks])
		quit(1)


func _test_catalog() -> void:
	_check(catalog.total_levels() >= 5200, "At least 5,200 campaign levels are bundled")
	_check(catalog.load_error.is_empty(), "Offline content loads without errors")
	_check(catalog.word_formable("LETTER", "RETTEL"), "Duplicate letters can be used up to their available count")
	_check(not catalog.word_formable("LETTER", "LETR"), "Duplicate letters cannot be reused beyond their count")
	_check(not catalog.word_formable("", "ABC"), "Empty input is not a word")
	_check(catalog.word_formable("cat", "ACT"), "Word formability normalizes case")
	var signatures: Dictionary = {}
	for id: int in range(1, catalog.total_levels() + 1):
		var puzzle: Dictionary = catalog.level(id)
		_check(not puzzle.is_empty() and int(puzzle.id) == id, "Sequential content id %d" % id)
		if puzzle.is_empty():
			continue
		_check(int(puzzle.difficulty) in [1, 2, 3, 4, 5], "Difficulty in range for %d" % id)
		_check(puzzle.words.size() > 0, "Level %d has targets" % id)
		var unique: Dictionary = {}
		var sorted_words: Array = puzzle.words.duplicate()
		sorted_words.sort()
		var chars: Array = str(puzzle.letters).split("")
		chars.sort()
		var signature: String = "".join(chars) + ":" + ",".join(sorted_words)
		_check(not signatures.has(signature), "Level %d has a distinct rack and target combination" % id)
		signatures[signature] = true
		for word: String in puzzle.words:
			_check(not unique.has(word), "Level %d has no duplicate target %s" % [id, word])
			unique[word] = true
			_check(catalog.word_formable(word, str(puzzle.letters)), "%s is formable in level %d" % [word, id])
			_check(catalog.valid_bonus(word, str(puzzle.letters)), "%s has an offline lexicon entry" % word)
			_check(not catalog.meaning(word).begins_with("Meaning not available"), "%s has a definition" % word)
	for day: String in ["2026-10-10", "2030-02-28", "not-a-date", "", "日常", "-9999999999999999999999999"]:
		var id: int = catalog.daily_id(day)
		_check(id >= 1 and id <= catalog.total_levels(), "Daily id bounded for arbitrary input")
		_check(id == catalog.daily_id(day), "Daily selection is deterministic")
	var first: Dictionary = catalog.level(1)
	first.words.clear()
	_check(not catalog.level(1).words.is_empty(), "Returned catalog levels cannot mutate the source")
	var catalog_snapshot: Array[Dictionary] = catalog.levels
	catalog_snapshot.clear()
	_check(catalog.levels.size() == catalog.total_levels(), "Public level snapshots cannot mutate the catalogue")
	var lexicon_snapshot: Dictionary = catalog.lexicon
	var known_word: String = str(catalog.level(1).words[0])
	lexicon_snapshot.erase(known_word)
	_check(catalog.lexicon.has(known_word), "Public lexicon snapshots cannot mutate definitions")
	var rack: String = str(catalog.level(1).letters)
	var matches: Array[String] = catalog.words_for_letters(rack)
	_check(not matches.is_empty(), "Rack search finds dictionary words")
	for word: String in matches:
		_check(catalog.word_formable(word, rack), "Rack search returns formable words only")


func _solve(key: String, id: int) -> int:
	var earned: int = 0
	for word: String in catalog.level(id).words:
		var result: Dictionary = game.record_word(key, word)
		earned += int(result.reward)
	return earned


func _test_progress_and_rewards() -> void:
	_check(int(game.profile.coins) == 120, "New profiles begin with 120 ink")
	_check(game.next_level() == 1, "New profiles begin at journey level 1")
	_check(game.begin_puzzle("campaign", 2).is_empty(), "Campaign levels unlock sequentially")
	var progress: Dictionary = game.begin_puzzle("campaign", 1)
	var key: String = str(progress.key)
	_check(game.record_word(key, "NOTAWORD").status == "invalid", "Invalid answers rejected")
	var before: int = int(game.profile.coins)
	var earned: int = _solve(key, 1)
	_check(earned == 20 + 5 * int(catalog.level(1).difficulty), "Campaign completion awards the documented ink")
	_check(int(game.profile.coins) == before + earned, "Reward updates wallet")
	_check(game.next_level() == 2, "Completion unlocks exactly the next campaign level")
	_check(game.complete_puzzle(key) == 0, "Completion rewards are idempotent")
	_check(_solve(key, 1) == 0, "Replaying solved words earns no repeat reward")
	_check(game.puzzle_progress(key).completed, "Completion is persisted in puzzle progress")
	var word: String = str(catalog.level(1).words[0])
	_check(game.profile.learned.has(word), "Solved words enter the learning collection")
	_check(game.due_words(0).has(word), "Newly learned words are immediately available for first-session active recall")
	var copy: Dictionary = game.puzzle_progress(key)
	copy.found.clear()
	_check(not game.puzzle_progress(key).found.is_empty(), "Returned progress is independent of stored progress")


func _test_daily_and_modes() -> void:
	var campaign_before: int = game.profile.completed.size()
	var progress: Dictionary = game.begin_puzzle("daily", 1)
	_check(int(progress.level_id) == catalog.daily_id(), "Daily always uses the shared date-selected puzzle")
	_check(_solve(str(progress.key), int(progress.level_id)) == 40, "Today's daily awards 40 ink once")
	_check(game.profile.completed.size() == campaign_before, "Daily completion cannot unlock campaign progress")
	_check(_solve(str(progress.key), int(progress.level_id)) == 0, "Daily cannot be replayed for currency")
	_check(game.daily_streak() == 1, "Today's completion starts a daily streak")
	var archive: Dictionary = game.begin_puzzle("daily", 1, "2000-01-01")
	_check(_solve(str(archive.key), int(archive.level_id)) == 0, "Archived daily cannot award today's currency")
	_check(game.begin_puzzle("daily", 1, "2026-02-30").is_empty(), "Impossible calendar dates are rejected")
	for mode: String in ["cozy", "clue", "sprint"]:
		var practice: Dictionary = game.begin_puzzle(mode, 10)
		_check(_solve(str(practice.key), 10) == 0, "Practice mode %s does not farm currency" % mode)
		var replay: Dictionary = game.begin_puzzle(mode, 10)
		_check(replay.found.is_empty() and not replay.completed, "Completed practice mode %s can be replayed" % mode)
		game.record_word(str(replay.key), str(catalog.level(10).words[0]))
		_check(game.reset_practice(str(replay.key)) and game.puzzle_progress(str(replay.key)).found.is_empty(), "Practice can explicitly restart a partial run")
	_check(not game.reset_practice("campaign:1"), "Practice reset cannot reset campaign rewards")
	_check(not game.reset_practice(str(progress.key)), "Practice reset cannot reset daily rewards")
	_check(game.profile.completed.size() == campaign_before, "Other modes do not unlock the journey")


func _test_hints_and_shop() -> void:
	var progress: Dictionary = game.begin_puzzle("campaign", 2)
	var key: String = str(progress.key)
	game.profile.coins = 15
	var hint: Dictionary = game.purchase_hint(key)
	_check(hint.ok and int(hint.revealed) == 1, "Hint reveals exactly one initial letter")
	_check(int(game.profile.coins) == 0, "Hint spends exactly 15 ink")
	_check(game.puzzle_progress(key).hints.get(hint.word) == 1, "Hint is stored per word")
	_check(not game.purchase_hint(key).ok and int(game.profile.coins) == 0, "Insufficient funds cannot buy hints or go negative")
	_check(not game.purchase_cosmetic("coral"), "Insufficient funds cannot buy cosmetics")
	_check(not game.purchase_cosmetic("made-up-item"), "Unknown shop IDs are rejected")
	_check(not game.set_setting("accent", "coral"), "Unowned cosmetics cannot be equipped")
	game.profile.coins = 120
	_check(game.purchase_cosmetic("coral"), "Earned ink can buy a cosmetic")
	_check(int(game.profile.coins) == 0 and game.profile.cosmetics.has("coral"), "Cosmetic purchase debits the exact price and grants ownership")
	_check(not game.purchase_cosmetic("coral"), "Owned cosmetic cannot be purchased twice")
	_check(game.set_setting("accent", "coral"), "Purchased cosmetic can be equipped")
	_check(game.set_setting("theme", "midnight"), "Dark mode is available without a purchase")
	_check(not game.set_setting("sound", "false"), "Settings reject malformed types")
	_check(not game.set_setting("coins", 9999), "Only supported settings can be changed")


func _test_recall_and_challenges() -> void:
	var word: String = str(catalog.level(1).words[0])
	game.profile.learned[word].stage = 0
	game.profile.learned[word].due = 0
	_check(game.due_words().has(word), "Due review cards appear in the review queue")
	for days: int in [1, 3, 7, 14, 30, 30]:
		var now: int = int(Time.get_unix_time_from_system())
		_check(game.review_word(word, true), "Known word can be reviewed")
		_check(absi(int(game.profile.learned[word].due) - now - days * 86400) <= 2, "Successful recall schedules %d days" % days)
	_check(game.review_word(word, false), "Again review is accepted")
	_check(int(game.profile.learned[word].stage) == 0, "Again resets the recall stage")
	_check(not game.review_word("MISSINGWORD", true), "Unknown cards cannot be reviewed")
	_check(not game.claim_challenge("journey_100"), "Unfinished challenge cannot be claimed")
	for id: int in range(1, 11):
		var progress: Dictionary = game.begin_puzzle("campaign", id)
		_solve(str(progress.key), id)
	var before: int = int(game.profile.coins)
	_check(game.claim_challenge("journey_10"), "Completed challenge can be claimed")
	_check(int(game.profile.coins) == before + 50, "Challenge grants its advertised currency")
	_check(not game.claim_challenge("journey_10"), "Challenge can only be claimed once")
	_check(not game.claim_challenge("fake"), "Unknown challenge is rejected")


func _test_persistence() -> void:
	game.profile.stats.sprint_best = 42
	_check(game.save_profile(), "Profile save succeeds")
	var expected: Dictionary = game.profile.duplicate(true)
	game.load_profile()
	_check(game.profile == expected, "Progress, rewards, preferences and recall survive a round trip")
	_check(int(game.profile.stats.sprint_best) == 42, "Sprint personal best survives reload")
	# A second save establishes a matching backup, then simulate an interrupted/corrupt write.
	_check(game.save_profile(), "Backup save succeeds")
	var file := FileAccess.open(test_save, FileAccess.WRITE)
	file.store_string("{ interrupted write")
	file.close()
	game.load_profile()
	_check(game.recovered_backup, "Corrupt primary profile recovers from its previous valid snapshot")
	_check(game.profile == expected, "Recovered backup preserves the complete profile")
	_check(game.save_profile(), "Recovered profile can be saved again")
	file = FileAccess.open(test_save, FileAccess.WRITE)
	file.store_string(JSON.stringify({"coins": -999, "completed": {"999999": true, "bad": true}, "puzzles": {"bad": 12}, "learned": {"BAD": 10}, "cosmetics": [12, "fake"], "settings": {"theme": "bad", "sound": 3}, "stats": {"reviews": "bad", "sprint_best": 999999}}))
	file.close()
	game.load_profile()
	_check(int(game.profile.coins) == 0, "Malformed profiles cannot create negative currency")
	_check(game.profile.completed.is_empty() and game.profile.puzzles.is_empty(), "Malformed puzzle records are discarded")
	_check(game.profile.learned.is_empty(), "Malformed review cards are discarded")
	_check(game.profile.settings.theme == "paper" and game.profile.settings.sound, "Malformed settings fall back to safe defaults")
	_check(game.profile.cosmetics == ["paper", "midnight", "cobalt"], "Malformed cosmetic ownership is discarded")
	_check(int(game.profile.stats.sprint_best) == 10000, "Sprint personal best is bounded when loading a modified save")
