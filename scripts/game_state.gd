extends Node
## Local profile, separate progress for each mode, and an earn-only economy.
## Every mutation is saved. Public getters return copies of puzzle records.

signal changed

const HINT_COST: int = 15
const REVIEW_DAYS: Array[int] = [1, 3, 7, 14, 30]
const MAX_COINS: int = 1000000
const SHOP: Array[Dictionary] = [
	{"id": "coral", "name": "Coral ink", "description": "A warm red accent for your edition.", "cost": 120, "type": "accent"},
	{"id": "violet", "name": "Violet ink", "description": "A vivid purple accent for your edition.", "cost": 180, "type": "accent"},
	{"id": "amber", "name": "Amber ink", "description": "A golden accent for your edition.", "cost": 240, "type": "accent"},
]
const CHALLENGES: Array[Dictionary] = [
	{"id": "journey_10", "title": "First chapter", "description": "Complete 10 journey puzzles.", "metric": "solved", "goal": 10, "reward": 50},
	{"id": "journey_50", "title": "Page turner", "description": "Complete 50 journey puzzles.", "metric": "solved", "goal": 50, "reward": 100},
	{"id": "journey_100", "title": "A hundred discoveries", "description": "Complete 100 journey puzzles.", "metric": "solved", "goal": 100, "reward": 150},
	{"id": "learn_10", "title": "Word collector", "description": "Discover 10 different words.", "metric": "learned", "goal": 10, "reward": 35},
	{"id": "learn_50", "title": "Living lexicon", "description": "Discover 50 different words.", "metric": "learned", "goal": 50, "reward": 75},
	{"id": "recall_10", "title": "Make it stick", "description": "Review 10 different words from your collection.", "metric": "reviewed", "goal": 10, "reward": 50},
	{"id": "daily_7", "title": "Seven editions", "description": "Complete 7 daily puzzles, at your own pace.", "metric": "daily", "goal": 7, "reward": 100},
]

var profile: Dictionary = {}
var save_path: String = "user://folio_profile.json"
var last_save_error: String = ""
var recovered_backup: bool = false


func _ready() -> void:
	load_profile()


func _catalog() -> Node:
	return get_node("/root/Catalog")


func _defaults() -> Dictionary:
	return {
		"version": 1, "coins": 120, "completed": {}, "daily_completed": {},
		"puzzles": {}, "learned": {}, "claimed_challenges": {}, "cosmetics": ["paper", "midnight", "cobalt"],
		"settings": {"theme": "paper", "accent": "cobalt", "sound": true, "reduced_motion": false},
		"stats": {"words_found": 0, "bonus_found": 0, "reviews": 0, "sprint_best": 0},
	}


func today() -> String:
	return Time.get_date_string_from_system(true)


func next_level() -> int:
	var total: int = _catalog().total_levels()
	for id: int in range(1, total + 1):
		if not profile.completed.has(str(id)):
			return id
	return maxi(total, 1)


func is_unlocked(id: int) -> bool:
	return id >= 1 and id <= _catalog().total_levels() and id <= next_level()


func puzzle_key(mode: String, id: int, day: String = "") -> String:
	if mode == "daily":
		return "daily:" + (today() if day.is_empty() else day)
	if mode == "campaign":
		return "campaign:%d" % id
	return "mode:%s:%d" % [mode.validate_filename(), id]


func begin_puzzle(mode: String, id: int, day: String = "") -> Dictionary:
	if day.is_empty():
		day = today()
	if mode == "daily":
		if not _valid_day(day):
			return {}
		id = _catalog().daily_id(day)
	if _catalog().level(id).is_empty() or (mode == "campaign" and not is_unlocked(id)):
		return {}
	var key: String = puzzle_key(mode, id, day)
	if not profile.puzzles.has(key):
		profile.puzzles[key] = {
			"key": key, "mode": mode, "level_id": id, "day": day if mode == "daily" else "",
			"found": [], "bonus": [], "hints": {}, "completed": false,
		}
		_persist()
	elif mode not in ["campaign", "daily"] and bool(profile.puzzles[key].completed):
		reset_practice(key)
	return puzzle_progress(key)


func puzzle_progress(key: String) -> Dictionary:
	return profile.puzzles.get(key, {}).duplicate(true)


func reset_practice(key: String) -> bool:
	if not profile.puzzles.has(key) or str(profile.puzzles[key].mode) in ["campaign", "daily"]:
		return false
	var progress: Dictionary = profile.puzzles[key]
	progress.found = []
	progress.bonus = []
	progress.hints = {}
	progress.completed = false
	_persist()
	return true


func record_word(key: String, word: String) -> Dictionary:
	word = word.strip_edges().to_upper()
	var result: Dictionary = {"status": "invalid", "word": word, "meaning": "", "completed": false, "reward": 0}
	if not profile.puzzles.has(key):
		return result
	var progress: Dictionary = profile.puzzles[key]
	var puzzle: Dictionary = _catalog().level(int(progress.level_id))
	result.completed = bool(progress.completed)
	if progress.found.has(word) or progress.bonus.has(word):
		result.status = "duplicate"
		return result
	if puzzle.get("words", []).has(word):
		progress.found.append(word)
		profile.stats.words_found = int(profile.stats.words_found) + 1
		result.status = "found"
	elif _catalog().valid_bonus(word, str(puzzle.get("letters", ""))):
		progress.bonus.append(word)
		profile.stats.bonus_found = int(profile.stats.bonus_found) + 1
		result.status = "bonus"
		# Bonus recognition is deliberately non-currency. Replaying a rack cannot farm coins.
	else:
		return result
	_learn_word(word)
	result.meaning = _catalog().meaning(word)
	result.reward = _complete_if_ready(progress, puzzle)
	result.completed = bool(progress.completed)
	_persist()
	return result


func complete_puzzle(key: String) -> int:
	if not profile.puzzles.has(key):
		return 0
	var progress: Dictionary = profile.puzzles[key]
	var reward: int = _complete_if_ready(progress, _catalog().level(int(progress.level_id)))
	_persist()
	return reward


func _complete_if_ready(progress: Dictionary, puzzle: Dictionary) -> int:
	if bool(progress.completed) or puzzle.is_empty():
		return 0
	for word: String in puzzle.words:
		if not progress.found.has(word):
			return 0
	progress.completed = true
	var reward: int = 0
	if progress.mode == "campaign":
		var id: String = str(int(progress.level_id))
		if not profile.completed.has(id) and is_unlocked(int(progress.level_id)):
			profile.completed[id] = true
			reward = 20 + 5 * int(puzzle.difficulty)
	elif progress.mode == "daily" and progress.day == today():
		if not profile.daily_completed.has(str(progress.day)):
			profile.daily_completed[str(progress.day)] = true
			reward = 40
	profile.coins = mini(MAX_COINS, int(profile.coins) + reward)
	return reward


func purchase_hint(key: String) -> Dictionary:
	var result: Dictionary = {"ok": false, "reason": "No puzzle is open.", "word": "", "revealed": 0, "prefix": ""}
	if not profile.puzzles.has(key):
		return result
	var progress: Dictionary = profile.puzzles[key]
	var puzzle: Dictionary = _catalog().level(int(progress.level_id))
	if bool(progress.completed):
		result.reason = "This puzzle is already complete."
		return result
	if int(profile.coins) < HINT_COST:
		result.reason = "You need 15 coins. Earn coins by completing a journey or daily puzzle."
		return result
	for word: String in puzzle.get("words", []):
		var revealed: int = int(progress.hints.get(word, 0))
		if not progress.found.has(word) and revealed < word.length():
			revealed += 1
			progress.hints[word] = revealed
			profile.coins = int(profile.coins) - HINT_COST
			result = {"ok": true, "reason": "", "word": word, "revealed": revealed, "prefix": word.left(revealed)}
			_persist()
			return result
	result.reason = "All remaining letters are revealed. Trace the words to finish."
	return result


func _learn_word(word: String) -> bool:
	if profile.learned.has(word):
		return false
	# Let players try active recall in their first session; their first review
	# schedules the next visit for tomorrow, then 3, 7, 14 and 30 days.
	profile.learned[word] = {"stage": 0, "due": int(Time.get_unix_time_from_system()), "reviews": 0}
	return true


func learn_word(word: String) -> bool:
	word = word.strip_edges().to_upper()
	if not _catalog().valid_bonus(word, word):
		return false
	var added: bool = _learn_word(word)
	if added:
		_persist()
	return added


func due_words(limit: int = 20) -> Array[String]:
	var result: Array[String] = []
	var now: int = int(Time.get_unix_time_from_system())
	for word: String in profile.learned:
		if int(profile.learned[word].due) <= now:
			result.append(word)
	result.sort_custom(func(a: String, b: String) -> bool: return int(profile.learned[a].due) < int(profile.learned[b].due) if int(profile.learned[a].due) != int(profile.learned[b].due) else a < b)
	if limit > 0 and result.size() > limit:
		result.resize(limit)
	return result


func review_word(word: String, remembered: bool) -> bool:
	word = word.strip_edges().to_upper()
	if not profile.learned.has(word):
		return false
	var card: Dictionary = profile.learned[word]
	# First successful recall schedules 1 day; subsequent successes use 3, 7, 14, 30.
	var stage: int = mini(int(card.stage), REVIEW_DAYS.size() - 1) if remembered else 0
	card.due = int(Time.get_unix_time_from_system()) + REVIEW_DAYS[stage] * 86400
	card.stage = mini(stage + 1, REVIEW_DAYS.size() - 1) if remembered else 0
	card.reviews = int(card.reviews) + 1
	profile.stats.reviews = int(profile.stats.reviews) + 1
	_persist()
	return true


func daily_streak() -> int:
	var day_number: int = int(floor(Time.get_unix_time_from_system() / 86400.0))
	if not profile.daily_completed.has(today()):
		day_number -= 1
	var streak: int = 0
	while streak < 100000:
		var day: String = Time.get_date_string_from_unix_time(day_number * 86400)
		if not profile.daily_completed.has(day):
			break
		streak += 1
		day_number -= 1
	return streak


func shop_items() -> Array[Dictionary]:
	return SHOP.duplicate(true)


func challenges() -> Array[Dictionary]:
	var reviewed: int = 0
	for card: Dictionary in profile.learned.values():
		if int(card.reviews) > 0:
			reviewed += 1
	var metrics: Dictionary = {"solved": profile.completed.size(), "learned": profile.learned.size(), "reviewed": reviewed, "daily": profile.daily_completed.size()}
	var result: Array[Dictionary] = []
	for challenge: Dictionary in CHALLENGES:
		var entry: Dictionary = challenge.duplicate()
		entry.progress = mini(int(metrics[entry.metric]), int(entry.goal))
		entry.claimed = profile.claimed_challenges.has(entry.id)
		result.append(entry)
	return result


func claim_challenge(id: String) -> bool:
	if profile.claimed_challenges.has(id):
		return false
	for challenge: Dictionary in challenges():
		if challenge.id == id and int(challenge.progress) >= int(challenge.goal):
			profile.claimed_challenges[id] = true
			profile.coins = mini(MAX_COINS, int(profile.coins) + int(challenge.reward))
			_persist()
			return true
	return false


func purchase_cosmetic(id: String) -> bool:
	if profile.cosmetics.has(id):
		return false
	for item: Dictionary in SHOP:
		if item.id == id and int(profile.coins) >= int(item.cost):
			profile.coins = int(profile.coins) - int(item.cost)
			profile.cosmetics.append(id)
			_persist()
			return true
	return false


func set_setting(key: String, value: Variant) -> bool:
	if key in ["sound", "reduced_motion"]:
		if not value is bool:
			return false
	elif key == "theme":
		if not value is String or value not in ["paper", "midnight"]:
			return false
	elif key == "accent":
		if not value is String or value not in ["cobalt", "coral", "violet", "amber"] or not profile.cosmetics.has(value):
			return false
	else:
		return false
	profile.settings[key] = value
	_persist()
	return true


func _persist() -> void:
	save_profile()
	changed.emit()


func save_profile() -> bool:
	last_save_error = ""
	var pending: String = save_path + ".tmp"
	var file := FileAccess.open(pending, FileAccess.WRITE)
	if file == null:
		last_save_error = "Could not write your progress on this device."
		return false
	file.store_string(JSON.stringify(profile))
	file.flush()
	file.close()
	# Retain the previous valid snapshot; never replace it with a corrupt primary.
	if not _read_save(save_path).is_empty():
		var backup_error: Error = DirAccess.copy_absolute(save_path, save_path + ".bak")
		if backup_error != OK:
			last_save_error = "Could not back up progress on this device."
			return false
	var rename_error: Error = DirAccess.rename_absolute(pending, save_path)
	if rename_error != OK:
		last_save_error = "Could not finish saving your progress on this device."
		return false
	return true


func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 16000000:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return {}
	return parser.data


func load_profile() -> void:
	var raw: Dictionary = _read_save(save_path)
	recovered_backup = false
	if raw.is_empty():
		raw = _read_save(save_path + ".bak")
		recovered_backup = not raw.is_empty()
	profile = _sanitize(raw)
	changed.emit()


func _number(value: Variant, fallback: int, low: int, high: int) -> int:
	if not (value is int or value is float) or not is_finite(float(value)):
		return fallback
	return clampi(int(value), low, high)


func _valid_day(day: String) -> bool:
	if day.length() != 10 or day[4] != "-" or day[7] != "-":
		return false
	if not day.substr(0, 4).is_valid_int() or not day.substr(5, 2).is_valid_int() or not day.substr(8, 2).is_valid_int():
		return false
	var year: int = int(day.substr(0, 4))
	var month: int = int(day.substr(5, 2))
	var date: int = int(day.substr(8, 2))
	if year < 1970 or year > 9999 or month < 1 or month > 12:
		return false
	var month_days: Array[int] = [31, 29 if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	return date >= 1 and date <= month_days[month - 1]


func _sanitize(raw: Dictionary) -> Dictionary:
	var clean: Dictionary = _defaults()
	clean.coins = _number(raw.get("coins"), 120, 0, MAX_COINS)
	if raw.get("completed") is Dictionary:
		for id: Variant in raw.completed:
			if str(id).is_valid_int() and int(id) >= 1 and int(id) <= _catalog().total_levels() and raw.completed[id] is bool and raw.completed[id]:
				clean.completed[str(int(id))] = true
	if raw.get("daily_completed") is Dictionary:
		for day: Variant in raw.daily_completed:
			if day is String and _valid_day(day) and raw.daily_completed[day] is bool and raw.daily_completed[day]:
				clean.daily_completed[day] = true
	if raw.get("cosmetics") is Array:
		for item: Variant in raw.cosmetics:
			if item is String and item in ["coral", "violet", "amber"] and not clean.cosmetics.has(item):
				clean.cosmetics.append(item)
	if raw.get("claimed_challenges") is Dictionary:
		for challenge: Dictionary in CHALLENGES:
			if raw.claimed_challenges.get(challenge.id) is bool and raw.claimed_challenges[challenge.id]:
				clean.claimed_challenges[challenge.id] = true
	if raw.get("settings") is Dictionary:
		var settings: Dictionary = raw.settings
		for key: String in ["sound", "reduced_motion"]:
			if settings.get(key) is bool:
				clean.settings[key] = settings[key]
		if settings.get("theme") in ["paper", "midnight"]:
			clean.settings.theme = settings.theme
		if settings.get("accent") in ["cobalt", "coral", "violet", "amber"] and clean.cosmetics.has(settings.get("accent")):
			clean.settings.accent = settings.accent
	if raw.get("stats") is Dictionary:
		for key: String in clean.stats:
			clean.stats[key] = _number(raw.stats.get(key), 0, 0, 10000 if key == "sprint_best" else 100000000)
	if raw.get("learned") is Dictionary:
		for word: Variant in raw.learned:
			if not word is String or not _catalog().valid_bonus(word, word) or not raw.learned[word] is Dictionary:
				continue
			var card: Dictionary = raw.learned[word]
			clean.learned[word.to_upper()] = {"stage": _number(card.get("stage"), 0, 0, 4), "due": _number(card.get("due"), int(Time.get_unix_time_from_system()), 0, 253402300799), "reviews": _number(card.get("reviews"), 0, 0, 100000000)}
	if raw.get("puzzles") is Dictionary:
		for key: Variant in raw.puzzles:
			if not key is String or not raw.puzzles[key] is Dictionary:
				continue
			var source: Dictionary = raw.puzzles[key]
			var id: int = _number(source.get("level_id"), 0, 1, _catalog().total_levels())
			var puzzle: Dictionary = _catalog().level(id)
			var mode: String = str(source.get("mode", ""))
			var day: String = str(source.get("day", ""))
			if puzzle.is_empty() or mode.is_empty() or mode.length() > 32 or (mode == "daily" and (not _valid_day(day) or id != _catalog().daily_id(day))) or key != puzzle_key(mode, id, day):
				continue
			var progress: Dictionary = {"key": key, "mode": mode, "level_id": id, "day": day if mode == "daily" else "", "found": [], "bonus": [], "hints": {}, "completed": false}
			if source.get("found") is Array:
				for word: Variant in source.found:
					if word is String and puzzle.words.has(word) and not progress.found.has(word):
						progress.found.append(word)
			if source.get("bonus") is Array:
				for word: Variant in source.bonus:
					if word is String and _catalog().valid_bonus(word, str(puzzle.letters)) and not puzzle.words.has(word) and not progress.bonus.has(word):
						progress.bonus.append(word)
			if source.get("hints") is Dictionary:
				for word: Variant in source.hints:
					if word is String and puzzle.words.has(word):
						progress.hints[word] = _number(source.hints[word], 0, 0, word.length())
			progress.completed = progress.found.size() == puzzle.words.size()
			clean.puzzles[key] = progress
	return clean
