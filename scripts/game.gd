extends Node2D
## Neon Pulse - prototip. Tüm oyun mantığı ve çizim burada.
## Fizik sabit adımda (_physics_process) ve deterministiktir; tools/gen_level_01.py
## aynı sabitlerle seviyenin geçilebilirliğini doğrular, ikisini birlikte güncelle.

const T := 64.0
const GROUND_Y := 560.0
const GRAVITY := 4200.0
const JUMP_V := -1100.0
const PLAYER_SIZE := 56.0
const CAMERA_LEAD := 300.0
const CAMERA_Y := 360.0
const SPIKE_W_RATIO := 0.55
const SPIKE_H_RATIO := 0.60
const LAND_TOLERANCE := 12.0
const SPIN_DEG_PER_SEC := 486.0
const DEATH_DELAY := 0.4
const END_MARGIN := 400.0
const FINISH_OFFSET := 150.0
const LEVEL_PATH := "res://levels/level_01.json"

const COL_BG_TOP := Color("0b0720")
const COL_BG_BOTTOM := Color("2a0f4d")
const COL_GRID := Color(0.55, 0.3, 1.0, 0.12)
const COL_GROUND := Color("120a2b")
const COL_NEON := Color("00f0ff")
const COL_BLOCK := Color("1b1450")
const COL_BLOCK_EDGE := Color("ff2bd6")
const COL_SPIKE := Color("ff3860")
const COL_PLAYER := Color("39ff88")

enum State { PLAYING, DEAD, WON }

var level_name := ""
var speed := 520.0
var rows: Array[String] = []
var row_count := 0
var level_w := 0
var level_end_x := 0.0
var solid_tiles: Array[Rect2] = []   # '#'
var spike_tiles: Array[Rect2] = []   # '^' (görünür kare)
var spike_hitboxes: Array[Rect2] = []

var state := State.PLAYING
var px := 0.0          # oyuncunun merkez x'i
var py := GROUND_Y     # oyuncunun alt kenarı
var vy := 0.0
var rot := 0.0
var on_ground := true
var held := false
var jump_queued := false
var attempts := 1
var state_time := 0.0
var particles: Array[Dictionary] = []

var camera: Camera2D
var hud: Control


func _ready() -> void:
	camera = $Camera
	_load_level()
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_draw_hud)
	layer.add_child(hud)
	_reset_run()


func _load_level() -> void:
	var data = null
	var file := FileAccess.open(LEVEL_PATH, FileAccess.READ)
	if file:
		data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Seviye okunamadı: " + LEVEL_PATH)
		data = {"name": "?", "speed": 520, "rows": ["."]}
	level_name = str(data.get("name", ""))
	speed = float(data.get("speed", 520))
	rows.clear()
	for line in data.get("rows", []):
		rows.append(str(line))
	row_count = rows.size()
	level_w = 0
	for line in rows:
		level_w = maxi(level_w, line.length())
	level_end_x = level_w * T + END_MARGIN
	solid_tiles.clear()
	spike_tiles.clear()
	spike_hitboxes.clear()
	for r in row_count:
		for c in rows[r].length():
			var ch := rows[r][c]
			# Tile (c,r) dünya konumu: x=c*T, y=GROUND_Y-(satır_sayısı-r)*T
			var rect := Rect2(c * T, GROUND_Y - (row_count - r) * T, T, T)
			if ch == "#":
				solid_tiles.append(rect)
			elif ch == "^":
				spike_tiles.append(rect)
				var sw := T * SPIKE_W_RATIO
				var sh := T * SPIKE_H_RATIO
				spike_hitboxes.append(Rect2(rect.position.x + (T - sw) * 0.5, rect.end.y - sh, sw, sh))


func _reset_run() -> void:
	state = State.PLAYING
	state_time = 0.0
	px = 0.0
	py = GROUND_Y
	vy = 0.0
	rot = 0.0
	on_ground = true
	jump_queued = held
	particles.clear()
	_update_camera()
	queue_redraw()


func _input(event: InputEvent) -> void:
	# Dokunma, emulate_mouse_from_touch ile fare olayına çevrilir; yalnızca onu dinliyoruz.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_set_held(event.pressed)
	elif event is InputEventKey and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_UP, KEY_W]:
			_set_held(event.pressed)


func _set_held(pressed: bool) -> void:
	held = pressed
	if pressed:
		jump_queued = true
		if state == State.WON and state_time > 0.8:
			attempts = 1
			_reset_run()


func _physics_process(delta: float) -> void:
	state_time += delta
	match state:
		State.PLAYING:
			_step_player(delta)
		State.DEAD:
			_step_particles(delta)
			if state_time >= DEATH_DELAY:
				attempts += 1
				_reset_run()
	_update_camera()
	queue_redraw()
	hud.queue_redraw()


func _step_player(dt: float) -> void:
	px += speed * dt
	var prev_bottom := py
	if on_ground and (held or jump_queued):
		vy = JUMP_V
		on_ground = false
	jump_queued = false
	if not on_ground:
		vy += GRAVITY * dt
		py += vy * dt
		rot += deg_to_rad(SPIN_DEG_PER_SEC) * dt

	var box := Rect2(px - PLAYER_SIZE * 0.5, py - PLAYER_SIZE, PLAYER_SIZE, PLAYER_SIZE)
	var land_y := INF
	for tile in solid_tiles:
		if not box.intersects(tile):
			continue
		if vy >= 0.0 and prev_bottom <= tile.position.y + LAND_TOLERANCE:
			land_y = minf(land_y, tile.position.y)
		else:
			_die()
			return
	for hit in spike_hitboxes:
		if box.intersects(hit):
			_die()
			return

	if not on_ground:
		if land_y < INF and vy >= 0.0:
			py = land_y
			_land()
		elif py >= GROUND_Y:
			py = GROUND_Y
			_land()
	elif not _has_support():
		on_ground = false  # bloğun kenarından düştü

	if px >= level_end_x:
		state = State.WON
		state_time = 0.0
		held = false


func _land() -> void:
	vy = 0.0
	on_ground = true
	rot = roundf(rot / (PI * 0.5)) * (PI * 0.5)


func _has_support() -> bool:
	if py >= GROUND_Y - 0.001:
		return true
	var l := px - PLAYER_SIZE * 0.5
	var r := px + PLAYER_SIZE * 0.5
	for tile in solid_tiles:
		if absf(py - tile.position.y) < 0.01 and r > tile.position.x and l < tile.end.x:
			return true
	return false


func _die() -> void:
	state = State.DEAD
	state_time = 0.0
	var origin := Vector2(px, py - PLAYER_SIZE * 0.5)
	for i in 28:
		var ang := randf() * TAU
		var spd := randf_range(150.0, 650.0)
		particles.append({
			"pos": origin,
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"size": randf_range(4.0, 12.0),
		})


func _step_particles(dt: float) -> void:
	for p in particles:
		p["vel"].y += GRAVITY * 0.4 * dt
		p["pos"] += p["vel"] * dt


func _update_camera() -> void:
	camera.position = Vector2(px + CAMERA_LEAD, CAMERA_Y)


# ---------------------------------------------------------------- çizim

func _draw() -> void:
	var view := get_viewport_rect().size
	var left := camera.position.x - view.x * 0.5
	var right := camera.position.x + view.x * 0.5
	var top := CAMERA_Y - view.y * 0.5
	var bottom := CAMERA_Y + view.y * 0.5
	_draw_background(left, right, top, bottom)

	# Zemin
	draw_rect(Rect2(left, GROUND_Y, right - left, bottom - GROUND_Y), COL_GROUND)
	draw_line(Vector2(left, GROUND_Y), Vector2(right, GROUND_Y), COL_NEON, 3.0)

	for tile in solid_tiles:
		if tile.end.x < left or tile.position.x > right:
			continue
		draw_rect(tile, COL_BLOCK)
		draw_rect(tile.grow(-2.0), COL_BLOCK_EDGE, false, 3.0)
	for tile in spike_tiles:
		if tile.end.x < left or tile.position.x > right:
			continue
		var pts := PackedVector2Array([
			Vector2(tile.position.x + 4.0, tile.end.y),
			Vector2(tile.position.x + T * 0.5, tile.position.y + 6.0),
			Vector2(tile.end.x - 4.0, tile.end.y),
		])
		draw_colored_polygon(pts, COL_SPIKE.darkened(0.55))
		pts.append(pts[0])
		draw_polyline(pts, COL_SPIKE, 3.0)

	# Bitiş çizgisi
	var fx := level_w * T + FINISH_OFFSET
	for i in 20:
		var col := Color.WHITE if i % 2 == 0 else Color.BLACK
		draw_rect(Rect2(fx, GROUND_Y - (i + 1) * 32.0, 16.0, 32.0), col)
		draw_rect(Rect2(fx + 16.0, GROUND_Y - (i + 1) * 32.0, 16.0, 32.0), Color.BLACK if i % 2 == 0 else Color.WHITE)

	# Oyuncu / parçacıklar
	if state == State.DEAD:
		for p in particles:
			var s: float = p["size"]
			draw_rect(Rect2(p["pos"] - Vector2(s, s) * 0.5, Vector2(s, s)), COL_PLAYER)
	else:
		_draw_player()


func _draw_background(left: float, right: float, top: float, bottom: float) -> void:
	var steps := 8
	var h := (bottom - top) / steps
	for i in steps:
		var col := COL_BG_TOP.lerp(COL_BG_BOTTOM, float(i) / (steps - 1))
		draw_rect(Rect2(left, top + i * h, right - left, h + 1.0), col)
	# Yavaş kayan ızgara (paralaks)
	var cell := 128.0
	var offset := camera.position.x * 0.5
	var x := left - fposmod(left - offset, cell)
	while x < right:
		draw_line(Vector2(x, top), Vector2(x, bottom), COL_GRID, 2.0)
		x += cell
	var y := GROUND_Y
	while y > top:
		draw_line(Vector2(left, y), Vector2(right, y), COL_GRID, 2.0)
		y -= cell


func _draw_player() -> void:
	var center := Vector2(px, py - PLAYER_SIZE * 0.5)
	draw_set_transform(center, rot, Vector2.ONE)
	var half := PLAYER_SIZE * 0.5
	draw_rect(Rect2(-half, -half, PLAYER_SIZE, PLAYER_SIZE), COL_PLAYER.darkened(0.6))
	draw_rect(Rect2(-half, -half, PLAYER_SIZE, PLAYER_SIZE), COL_PLAYER, false, 4.0)
	draw_rect(Rect2(-half * 0.45, -half * 0.45, half * 0.9, half * 0.9), COL_PLAYER, false, 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_hud() -> void:
	var size := hud.size
	var font := ThemeDB.fallback_font
	var progress := clampf(px / level_end_x, 0.0, 1.0)
	if state == State.WON:
		progress = 1.0
	var bar_w := minf(size.x * 0.5, 560.0)
	var bar := Rect2((size.x - bar_w) * 0.5, 24.0, bar_w, 14.0)
	hud.draw_rect(bar, Color(0, 0, 0, 0.5))
	hud.draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), COL_NEON)
	hud.draw_rect(bar, COL_NEON, false, 2.0)
	hud.draw_string(font, Vector2(bar.end.x + 12.0, 38.0), "%d%%" % int(progress * 100.0),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	hud.draw_string(font, Vector2(20.0, 38.0), "Deneme %d" % attempts,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	if state == State.WON:
		hud.draw_string(font, Vector2(0.0, size.y * 0.42), "SEVİYE TAMAM",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 72, COL_PLAYER)
		hud.draw_string(font, Vector2(0.0, size.y * 0.42 + 50.0), "Tekrar oynamak için dokun",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color.WHITE)
