extends Control
## Tap letters then submit, or swipe and release. Each tile is used once.
signal word_submitted(word: String)
signal selection_changed(word: String)
signal shuffle_requested
var letters: Array[String] = []
var selected: Array[int] = []
var ink := Color("182238")
var paper := Color("f6f7fc")
var accent := Color("345ded")
var muted := Color("d9deec")
var on_accent := Color.WHITE
var face: Font
var points: Array[Vector2] = []
var dragging := false
var moved := false
var press_position := Vector2.ZERO
var pointer := Vector2.ZERO
var radius := 44.0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
func setup(rack: String, font: Font, colors: Dictionary) -> void:
	letters.assign(rack.split(""))
	face = font
	ink = colors.ink
	paper = colors.paper
	accent = colors.accent
	muted = colors.line
	on_accent = colors.on_accent
	clear_selection()
func current_word() -> String:
	var word := ""
	for index in selected:
		word += letters[index]
	return word
func clear_selection() -> void:
	selected.clear()
	dragging = false
	selection_changed.emit("")
	queue_redraw()
func shuffle() -> void:
	letters.shuffle()
	clear_selection()
func _layout_points() -> void:
	points.clear()
	var center := size / 2.0
	var orbit := minf(size.x * 0.33, size.y * 0.37)
	radius = minf(46.0, orbit * 0.32) if letters.size() > 6 else 49.0
	for i in letters.size():
		var angle := -PI / 2 + TAU * float(i) / maxf(letters.size(), 1)
		points.append(center + Vector2(cos(angle), sin(angle)) * orbit)
func _hit(position: Vector2) -> int:
	for i in points.size():
		if position.distance_to(points[i]) <= radius + 10:
			return i
	return -1
func _choose(index: int) -> void:
	if index < 0:
		return
	if selected.size() > 1 and selected[selected.size() - 2] == index:
		selected.pop_back()
	elif not selected.has(index):
		selected.append(index)
	selection_changed.emit(current_word())
	queue_redraw()
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			press_position = event.position
			pointer = event.position
			if event.position.distance_to(size / 2) < 33:
				shuffle_requested.emit()
				shuffle()
				accept_event()
				return
			dragging = true
			moved = false
			_choose(_hit(event.position))
		else:
			if dragging and moved and not selected.is_empty():
				word_submitted.emit(current_word())
				clear_selection()
			dragging = false
			queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		pointer = event.position
		if press_position.distance_to(pointer) > 12:
			moved = true
			_choose(_hit(pointer))
		queue_redraw()
		accept_event()
func _draw() -> void:
	if letters.is_empty() or face == null:
		return
	_layout_points()
	var center := size / 2
	draw_arc(center, minf(size.x * 0.33, size.y * 0.37), 0, TAU, 90, muted, 1.5, true)
	for i in range(1, selected.size()):
		draw_line(points[selected[i-1]], points[selected[i]], Color(accent, 0.24), 16, true)
	if dragging and moved and not selected.is_empty():
		draw_line(points[selected.back()], pointer, Color(accent, 0.18), 12, true)
	for i in letters.size():
		var active := selected.has(i)
		draw_circle(points[i], radius, accent if active else paper)
		draw_arc(points[i], radius, 0, TAU, 48, accent if active else muted, 2, true)
		var text_size := face.get_string_size(letters[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 48)
		draw_string(face, points[i] + Vector2(-text_size.x / 2, 17), letters[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 48, on_accent if active else ink)
	var c := center
	draw_polyline(PackedVector2Array([c+Vector2(-15,-9),c+Vector2(-6,-9),c+Vector2(7,9),c+Vector2(17,9)]), ink, 2.5, true)
	draw_polyline(PackedVector2Array([c+Vector2(-15,9),c+Vector2(-6,9),c+Vector2(7,-9),c+Vector2(17,-9)]), ink, 2.5, true)
	draw_polyline(PackedVector2Array([c+Vector2(11,-15),c+Vector2(18,-9),c+Vector2(11,-3)]), ink, 2.5, true)
	draw_polyline(PackedVector2Array([c+Vector2(11,3),c+Vector2(18,9),c+Vector2(11,15)]), ink, 2.5, true)
