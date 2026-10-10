extends Node
## Offline, deterministic puzzle and dictionary catalogue.

var _levels: Array[Dictionary] = []
var _by_id: Dictionary = {}
var _lexicon: Dictionary = {}
var _rack_cache: Dictionary = {}
var load_error: String = ""
var levels: Array[Dictionary]:
	get:
		return _levels.duplicate(true)
var lexicon: Dictionary:
	get:
		return _lexicon.duplicate(true)


func _ready() -> void:
	load_catalog()


func load_catalog() -> void:
	_levels.clear()
	_by_id.clear()
	_rack_cache.clear()
	load_error = ""
	var lexicon_data: Variant = _read_json("res://data/lexicon.json")
	var level_data: Variant = _read_json("res://data/levels.json")
	if not lexicon_data is Dictionary or not level_data is Array:
		load_error = "The offline puzzle library could not be loaded."
		push_error(load_error)
		return
	_lexicon = lexicon_data
	for entry: Variant in level_data:
		if not entry is Dictionary:
			continue
		var id: int = int(entry.get("id", 0))
		if id < 1 or _by_id.has(id):
			continue
		var puzzle: Dictionary = entry.duplicate(true)
		_by_id[id] = puzzle
		_levels.append(puzzle)
	_levels.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.id) < int(b.id))


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return null
	return parser.data


func total_levels() -> int:
	return _levels.size()


func level(id: int) -> Dictionary:
	return _by_id.get(id, {}).duplicate(true)


func daily_id(day: String = "") -> int:
	if _levels.is_empty():
		return 0
	if day.is_empty():
		day = Time.get_date_string_from_system(true)
	# A bounded integer hash gives the same daily on every supported platform.
	var value: int = 17
	for index: int in day.length():
		value = (value * 31 + day.unicode_at(index)) % 2147483647
	return int(_levels[value % _levels.size()].id)


func meaning(word: String) -> String:
	var entry: Variant = _lexicon.get(word.strip_edges().to_upper(), {})
	if entry is Dictionary:
		return str(entry.get("meaning", "Meaning not available in this edition."))
	return "Meaning not available in this edition."


func word_formable(word: String, letters: String) -> bool:
	word = word.strip_edges().to_upper()
	letters = letters.to_upper()
	if word.is_empty():
		return false
	var remaining: Dictionary = {}
	for letter: String in letters:
		remaining[letter] = int(remaining.get(letter, 0)) + 1
	for letter: String in word:
		if int(remaining.get(letter, 0)) <= 0:
			return false
		remaining[letter] = int(remaining[letter]) - 1
	return true


func valid_bonus(word: String, letters: String) -> bool:
	word = word.strip_edges().to_upper()
	return word.length() >= 3 and _lexicon.has(word) and word_formable(word, letters)


func words_for_letters(letters: String) -> Array[String]:
	var chars: Array = letters.to_upper().split("")
	chars.sort()
	var signature: String = "".join(chars)
	if _rack_cache.has(signature):
		var cached: Array[String] = []
		cached.assign(_rack_cache[signature])
		return cached
	var matches: Array[String] = []
	for word: String in _lexicon:
		if word.length() >= 3 and word.length() <= letters.length() and word_formable(word, letters):
			matches.append(word)
	matches.sort_custom(func(a: String, b: String) -> bool: return a.length() < b.length() if a.length() != b.length() else a < b)
	_rack_cache[signature] = matches.duplicate()
	return matches
