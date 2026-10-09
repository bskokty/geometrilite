extends Node2D
## Neon Pulse - prototip. Tüm oyun mantığı ve çizim burada.
## Fizik sabit adımda (_physics_process) ve deterministiktir; tools/gen_segments.py
## aynı sabitlerle engel parçalarının geçilebilirliğini doğrular, ikisini birlikte güncelle.
##
## Seviyeler sonsuzdur: her seviye numarası, levels/segments.json içindeki doğrulanmış
## engel parçalarından numaraya bağlı tohumla kurulur (aynı numara her zaman aynı seviye).

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
const WIN_DELAY := 1.4
const BANNER_TIME := 2.4
const RESET_CONFIRM_TIME := 3.0
const MAX_EXTRA_SEGMENTS := 24      # profil seviyelerinden sonra seviye başına uzama sınırı
const SEGMENTS_PATH := "res://levels/segments.json"
const SAVE_PATH := "user://save.json"
const LANGS := ["en", "tr", "de", "es", "fr", "pt", "it", "ru"]
const STR := {
	"en": {
		"level": "LEVEL %d", "best": "Best %d%%", "complete": "LEVEL COMPLETE",
		"start": "START", "continue": "CONTINUE", "reset": "RESET GAME",
		"reset_confirm": "TAP AGAIN TO ERASE PROGRESS", "left_off": "WHERE YOU LEFT OFF", "new_game": "NEW GAME",
		"new_ability": "NEW ABILITY", "air_n": "Air jump ×%d", "air_inf": "Unlimited air jumps",
		"air_hint": "Tap again while airborne",
	},
	"tr": {
		"level": "SEVİYE %d", "best": "En iyi %%%d", "complete": "SEVİYE TAMAMLANDI",
		"start": "BAŞLA", "continue": "DEVAM ET", "reset": "OYUNU SIFIRLA",
		"reset_confirm": "SİLMEK İÇİN TEKRAR DOKUN", "left_off": "KALDIĞIN YER", "new_game": "YENİ OYUN",
		"new_ability": "YENİ YETENEK", "air_n": "Havada zıplama ×%d", "air_inf": "Sınırsız havada zıplama",
		"air_hint": "Havadayken tekrar dokun",
	},
	"de": {
		"level": "LEVEL %d", "best": "Bestwert %d%%", "complete": "LEVEL GESCHAFFT",
		"start": "START", "continue": "WEITER", "reset": "SPIEL ZURÜCKSETZEN",
		"reset_confirm": "ZUM LÖSCHEN ERNEUT TIPPEN", "left_off": "DEIN LETZTER STAND", "new_game": "NEUES SPIEL",
		"new_ability": "NEUE FÄHIGKEIT", "air_n": "Luftsprung ×%d", "air_inf": "Unbegrenzte Luftsprünge",
		"air_hint": "In der Luft erneut tippen",
	},
	"es": {
		"level": "NIVEL %d", "best": "Mejor %d%%", "complete": "NIVEL COMPLETADO",
		"start": "JUGAR", "continue": "CONTINUAR", "reset": "REINICIAR JUEGO",
		"reset_confirm": "TOCA DE NUEVO PARA BORRAR", "left_off": "DONDE LO DEJASTE", "new_game": "NUEVA PARTIDA",
		"new_ability": "NUEVA HABILIDAD", "air_n": "Salto aéreo ×%d", "air_inf": "Saltos aéreos ilimitados",
		"air_hint": "Toca de nuevo en el aire",
	},
	"fr": {
		"level": "NIVEAU %d", "best": "Meilleur %d%%", "complete": "NIVEAU TERMINÉ",
		"start": "JOUER", "continue": "CONTINUER", "reset": "RÉINITIALISER",
		"reset_confirm": "TOUCHEZ À NOUVEAU POUR EFFACER", "left_off": "OÙ VOUS EN ÉTIEZ", "new_game": "NOUVELLE PARTIE",
		"new_ability": "NOUVELLE CAPACITÉ", "air_n": "Saut aérien ×%d", "air_inf": "Sauts aériens illimités",
		"air_hint": "Touchez à nouveau en l'air",
	},
	"pt": {
		"level": "NÍVEL %d", "best": "Melhor %d%%", "complete": "NÍVEL CONCLUÍDO",
		"start": "JOGAR", "continue": "CONTINUAR", "reset": "REINICIAR JOGO",
		"reset_confirm": "TOQUE NOVAMENTE PARA APAGAR", "left_off": "ONDE VOCÊ PAROU", "new_game": "NOVO JOGO",
		"new_ability": "NOVA HABILIDADE", "air_n": "Salto aéreo ×%d", "air_inf": "Saltos aéreos ilimitados",
		"air_hint": "Toque novamente no ar",
	},
	"it": {
		"level": "LIVELLO %d", "best": "Migliore %d%%", "complete": "LIVELLO COMPLETATO",
		"start": "GIOCA", "continue": "CONTINUA", "reset": "RIPRISTINA GIOCO",
		"reset_confirm": "TOCCA ANCORA PER CANCELLARE", "left_off": "DOVE ERI RIMASTO", "new_game": "NUOVA PARTITA",
		"new_ability": "NUOVA ABILITÀ", "air_n": "Salto in aria ×%d", "air_inf": "Salti in aria illimitati",
		"air_hint": "Tocca di nuovo in aria",
	},
	"ru": {
		"level": "УРОВЕНЬ %d", "best": "Рекорд %d%%", "complete": "УРОВЕНЬ ПРОЙДЕН",
		"start": "ИГРАТЬ", "continue": "ПРОДОЛЖИТЬ", "reset": "СБРОСИТЬ ИГРУ",
		"reset_confirm": "НАЖМИТЕ ЕЩЁ РАЗ, ЧТОБЫ СТЕРЕТЬ", "left_off": "ГДЕ ВЫ ОСТАНОВИЛИСЬ", "new_game": "НОВАЯ ИГРА",
		"new_ability": "НОВАЯ СПОСОБНОСТЬ", "air_n": "Прыжок в воздухе ×%d", "air_inf": "Неограниченные прыжки в воздухе",
		"air_hint": "Нажмите ещё раз в воздухе",
	},
}

const COL_BG_TOP := Color("0b0720")
const COL_BG_BOTTOM := Color("2a0f4d")
const COL_GRID := Color(0.55, 0.3, 1.0, 0.12)
const COL_GROUND := Color("120a2b")
const COL_NEON := Color("00f0ff")
const COL_BLOCK := Color("1b1450")
const COL_BLOCK_EDGE := Color("ff2bd6")
const COL_SPIKE := Color("ff3860")
const COL_PLAYER := Color("39ff88")
const COL_CEIL := Color(0.03, 0.01, 0.09, 0.94)

enum State { MENU, PLAYING, DEAD, WON }

var seg_data: Dictionary = {}
var profile_levels := 1
var save_data := {"level": 1, "best": {}, "total_attempts": 0, "lang": ""}
var lang := "en"
var level_index := 1
var best_pct := 0
var air_jumps_cfg := 0              # seviyenin havada zıplama hakkı (0 yok, -1 sınırsız)
var air_left := 0
var new_ability := false
var has_ceiling := false
var ceil_y := 0.0
var banner_t := 0.0
var reset_armed_t := 0.0
var speed := 520.0
var rows: Array[String] = []
var row_count := 0
var level_w := 0
var level_end_x := 0.0
var solid_tiles: Array[Rect2] = []   # '#'
var spike_tiles: Array[Rect2] = []   # '^' (görünür kare)
var spike_hitboxes: Array[Rect2] = []
var ceil_spike_tiles: Array[Rect2] = []     # 'v' (aşağı bakan tavan dikeni)
var ceil_spike_hitboxes: Array[Rect2] = []

var state := State.MENU
var px := 0.0          # oyuncunun merkez x'i
var py := GROUND_Y     # oyuncunun alt kenarı
var vy := 0.0
var rot := 0.0
var on_ground := true
var held := false
var jump_queued := false
var state_time := 0.0
var particles: Array = []

var camera: Camera2D
var hud: Control


func _ready() -> void:
	camera = $Camera
	_load_segments()
	_load_save()
	lang = str(save_data.get("lang", ""))
	if not LANGS.has(lang):
		var loc := OS.get_locale_language()
		lang = loc if LANGS.has(loc) else "en"
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_draw_hud)
	layer.add_child(hud)
	_enter_menu()


func _t(key: String) -> String:
	return STR[lang].get(key, STR["en"].get(key, key))


# ---------------------------------------------------------------- seviye kurucu

func _load_segments() -> void:
	var file := FileAccess.open(SEGMENTS_PATH, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text()) if file else null
	if typeof(data) != TYPE_DICTIONARY or not data.has("levels"):
		push_error("Seviye verisi okunamadı: " + SEGMENTS_PATH)
		data = {"start_empty": 12, "levels": [{"speed": 420, "air": 0, "ceil": false, "gaps": [8, 10],
			"weights": [1, 0, 0], "count": 0, "tall": 0, "fixed": [[["^"], 9]], "pools": {}}]}
	seg_data = data
	profile_levels = (data["levels"] as Array).size()


func _profile(n: int) -> Dictionary:
	return seg_data["levels"][mini(n, profile_levels) - 1]


func _build_level(n: int) -> Array[String]:
	## Seviye n'in satırlarını (üstten alta) kurar. Aynı n her zaman aynı sonucu verir.
	var prof := _profile(n)
	var parts: Array = []   # [segment (satırlar), boşluk]
	if prof.has("fixed"):
		for e in prof["fixed"]:
			parts.append([e[0], int(e[1])])
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = n * 7919 + 13
		var pools: Dictionary = prof["pools"]
		var count := int(prof["count"]) + clampi(n - profile_levels, 0, MAX_EXTRA_SEGMENTS)
		var picks: Array = []
		var prev = null
		for i in count:
			var tier := _pick_tier(rng, prof["weights"])
			var pool: Array = pools.get(["easy", "medium", "hard"][tier], [])
			if pool.is_empty():
				continue
			var seg = pool[rng.randi() % pool.size()]
			if seg != prev:
				picks.append(seg)
				prev = seg
		var tall: Array = pools.get("tall", [])
		var tall_n := int(prof["tall"])
		if tall_n > 0 and not tall.is_empty():
			var step := maxi(1, picks.size() / (tall_n + 1))
			for k in range(1, tall_n + 1):
				picks.insert(mini(k * step + k - 1, picks.size()), tall[rng.randi() % tall.size()])
		var gaps: Array = prof["gaps"]
		for seg in picks:
			parts.append([seg, rng.randi_range(int(gaps[0]), int(gaps[1]))])
	return _assemble(parts, int(seg_data.get("start_empty", 12)))


func _pick_tier(rng: RandomNumberGenerator, weights: Array) -> int:
	var total := 0
	for w in weights:
		total += int(w)
	var r := rng.randi() % maxi(total, 1)
	for i in weights.size():
		r -= int(weights[i])
		if r < 0:
			return i
	return 0


func _assemble(parts: Array, start_empty: int) -> Array[String]:
	const ROWS := 6
	var grid: Array = []
	for r in ROWS:
		grid.append("")
	_add_columns(grid, ["." .repeat(start_empty)], ROWS)
	for p in parts:
		_add_columns(grid, p[0], ROWS)
		_add_columns(grid, ["." .repeat(int(p[1]))], ROWS)
	var out: Array[String] = []
	for line in grid:
		out.append(line)
	return out


func _add_columns(grid: Array, cols: Array, row_total: int) -> void:
	var w := 0
	for s in cols:
		w = maxi(w, str(s).length())
	var offset := row_total - cols.size()   # kısa parçalar alta hizalanır
	for r in row_total:
		var line := "." .repeat(w)
		if r >= offset:
			line = str(cols[r - offset]).rpad(w, ".")
		grid[r] += line


func _load_level(n: int) -> void:
	level_index = n
	best_pct = int(save_data["best"].get(str(n), 0))
	var prof := _profile(n)
	speed = float(prof["speed"])
	air_jumps_cfg = int(prof["air"])
	var prev_air := int(_profile(n - 1)["air"]) if n > 1 else 0
	new_ability = air_jumps_cfg != 0 and air_jumps_cfg != prev_air
	rows = _build_level(n)
	row_count = rows.size()
	level_w = 0
	for line in rows:
		level_w = maxi(level_w, line.length())
	level_end_x = level_w * T + END_MARGIN
	solid_tiles.clear()
	spike_tiles.clear()
	spike_hitboxes.clear()
	ceil_spike_tiles.clear()
	ceil_spike_hitboxes.clear()
	has_ceiling = air_jumps_cfg != 0
	ceil_y = GROUND_Y - row_count * T
	var sw := T * SPIKE_W_RATIO
	var sh := T * SPIKE_H_RATIO
	for r in row_count:
		for c in rows[r].length():
			var ch := rows[r][c]
			# Tile (c,r) dünya konumu: x=c*T, y=GROUND_Y-(satır_sayısı-r)*T
			var rect := Rect2(c * T, GROUND_Y - (row_count - r) * T, T, T)
			if ch == "#":
				solid_tiles.append(rect)
			elif ch == "^":
				spike_tiles.append(rect)
				spike_hitboxes.append(Rect2(rect.position.x + (T - sw) * 0.5, rect.end.y - sh, sw, sh))
			elif ch == "v":
				has_ceiling = true
				ceil_spike_tiles.append(rect)
				ceil_spike_hitboxes.append(Rect2(rect.position.x + (T - sw) * 0.5, rect.position.y, sw, sh))


# ---------------------------------------------------------------- durum geçişleri

func _reset_run(new_state: State = State.PLAYING) -> void:
	state = new_state
	state_time = 0.0
	px = 0.0
	py = GROUND_Y
	vy = 0.0
	rot = 0.0
	on_ground = true
	air_left = air_jumps_cfg
	jump_queued = false
	particles.clear()
	_update_camera()
	queue_redraw()


func _enter_menu() -> void:
	_load_level(maxi(1, int(save_data["level"])))
	_reset_run(State.MENU)
	reset_armed_t = 0.0
	held = false


func _start_game() -> void:
	_reset_run()
	banner_t = BANNER_TIME if new_ability else 0.0


func _next_level() -> void:
	_load_level(level_index + 1)
	_reset_run()
	banner_t = BANNER_TIME if new_ability else 0.0


func _reset_progress() -> void:
	var keep_lang := lang
	save_data = {"level": 1, "best": {}, "total_attempts": 0, "lang": keep_lang}
	_write_save()
	_enter_menu()


# ---------------------------------------------------------------- girdi

func _start_rect() -> Rect2:
	var s := hud.size
	return Rect2(s.x * 0.5 - 170.0, s.y * 0.55, 340.0, 64.0)


func _reset_rect() -> Rect2:
	var r := _start_rect()
	return Rect2(r.position.x, r.end.y + 20.0, r.size.x, 46.0)


func _lang_rect() -> Rect2:
	return Rect2(hud.size.x - 92.0, 16.0, 76.0, 34.0)


func _menu_rect() -> Rect2:
	return Rect2(hud.size.x - 64.0, 14.0, 48.0, 40.0)


func _input(event: InputEvent) -> void:
	# Dokunma, emulate_mouse_from_touch ile fare olayına çevrilir; yalnızca onu dinliyoruz.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if state == State.MENU:
				_menu_press(event.position)
				return
			if _menu_rect().has_point(event.position):
				_enter_menu()
				return
		if state != State.MENU:
			_set_held(event.pressed)
	elif event is InputEventKey and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_UP, KEY_W, KEY_ENTER]:
			if state == State.MENU:
				if event.pressed:
					_start_game()
				return
			_set_held(event.pressed)
		elif event.pressed and event.keycode == KEY_ESCAPE and state != State.MENU:
			_enter_menu()


func _menu_press(pos: Vector2) -> void:
	if _start_rect().has_point(pos):
		_start_game()
	elif _reset_rect().has_point(pos):
		if reset_armed_t > 0.0:
			_reset_progress()
		else:
			reset_armed_t = RESET_CONFIRM_TIME
	elif _lang_rect().has_point(pos):
		lang = LANGS[(LANGS.find(lang) + 1) % LANGS.size()]
		save_data["lang"] = lang
		_write_save()
		reset_armed_t = 0.0
	else:
		reset_armed_t = 0.0


func _set_held(pressed: bool) -> void:
	held = pressed
	if pressed:
		jump_queued = true
		if state == State.WON and state_time > 0.4:
			_next_level()


# ---------------------------------------------------------------- fizik

func _physics_process(delta: float) -> void:
	state_time += delta
	match state:
		State.MENU:
			reset_armed_t = maxf(0.0, reset_armed_t - delta)
		State.PLAYING:
			banner_t = maxf(0.0, banner_t - delta)
			_step_player(delta)
			_step_particles(delta)
		State.DEAD:
			_step_particles(delta)
			if state_time >= DEATH_DELAY:
				_reset_run()
				jump_queued = held
		State.WON:
			if state_time >= WIN_DELAY:
				_next_level()
	_update_camera()
	queue_redraw()
	hud.queue_redraw()


func _step_player(dt: float) -> void:
	px += speed * dt
	var prev_bottom := py
	if on_ground and (held or jump_queued):
		vy = JUMP_V
		on_ground = false
	elif not on_ground and jump_queued and air_left != 0:
		# Havada yeni dokunuş = ek zıplama (seviyenin hakkı kadar; -1 sınırsız). Basılı tutmak havada zıplatmaz.
		vy = JUMP_V
		if air_left > 0:
			air_left -= 1
		_spawn_air_ring()
	jump_queued = false
	if not on_ground:
		vy += GRAVITY * dt
		py += vy * dt
		rot += deg_to_rad(SPIN_DEG_PER_SEC) * dt
		if has_ceiling and py - PLAYER_SIZE < ceil_y:
			py = ceil_y + PLAYER_SIZE
			vy = maxf(vy, 0.0)

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
	for hit in ceil_spike_hitboxes:
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
		air_left = air_jumps_cfg

	if px >= level_end_x:
		state = State.WON
		state_time = 0.0
		held = false
		best_pct = 100
		save_data["best"][str(level_index)] = 100
		save_data["level"] = level_index + 1
		_write_save()


func _land() -> void:
	vy = 0.0
	on_ground = true
	air_left = air_jumps_cfg
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
	var pct := int(clampf(px / level_end_x, 0.0, 1.0) * 100.0)
	save_data["total_attempts"] = int(save_data["total_attempts"]) + 1
	if pct > best_pct:
		best_pct = pct
		save_data["best"][str(level_index)] = pct
	_write_save()
	var origin := Vector2(px, py - PLAYER_SIZE * 0.5)
	for i in 28:
		var ang := randf() * TAU
		var spd := randf_range(150.0, 650.0)
		particles.append({
			"pos": origin,
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"size": randf_range(4.0, 12.0),
		})


func _spawn_air_ring() -> void:
	# Havada zıplama geri bildirimi: oyuncunun altından saçılan kısa parçacıklar.
	var origin := Vector2(px, py)
	for i in 8:
		var ang := PI * 0.15 + randf() * PI * 0.7
		particles.append({
			"pos": origin,
			"vel": Vector2(cos(ang) * -1.0, sin(ang)) * randf_range(120.0, 320.0),
			"size": randf_range(3.0, 7.0),
			"ttl": 0.3,
		})


func _step_particles(dt: float) -> void:
	for p in particles:
		p["vel"].y += GRAVITY * 0.4 * dt
		p["pos"] += p["vel"] * dt
		if p.has("ttl"):
			p["ttl"] -= dt
	particles = particles.filter(func(p): return not p.has("ttl") or p["ttl"] > 0.0)


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
		_draw_spike(PackedVector2Array([
			Vector2(tile.position.x + 4.0, tile.end.y),
			Vector2(tile.position.x + T * 0.5, tile.position.y + 6.0),
			Vector2(tile.end.x - 4.0, tile.end.y),
		]))
	for tile in ceil_spike_tiles:
		if tile.end.x < left or tile.position.x > right:
			continue
		var cx := tile.position.x + T * 0.5
		draw_line(Vector2(cx, ceil_y), Vector2(cx, tile.position.y), Color(COL_BLOCK_EDGE, 0.45), 2.0)
		_draw_spike(PackedVector2Array([
			Vector2(tile.position.x + 4.0, tile.position.y),
			Vector2(tile.end.x - 4.0, tile.position.y),
			Vector2(tile.position.x + T * 0.5, tile.end.y - 6.0),
		]))
	if has_ceiling:
		draw_rect(Rect2(left, top, right - left, ceil_y - top), COL_CEIL)
		draw_line(Vector2(left, ceil_y), Vector2(right, ceil_y), COL_BLOCK_EDGE, 3.0)

	# Bitiş çizgisi
	var fx := level_w * T + FINISH_OFFSET
	for i in 20:
		var col := Color.WHITE if i % 2 == 0 else Color.BLACK
		draw_rect(Rect2(fx, GROUND_Y - (i + 1) * 32.0, 16.0, 32.0), col)
		draw_rect(Rect2(fx + 16.0, GROUND_Y - (i + 1) * 32.0, 16.0, 32.0), Color.BLACK if i % 2 == 0 else Color.WHITE)

	# Oyuncu / parçacıklar
	for p in particles:
		var s: float = p["size"]
		draw_rect(Rect2(p["pos"] - Vector2(s, s) * 0.5, Vector2(s, s)), COL_PLAYER)
	if state != State.DEAD:
		_draw_player()


func _draw_spike(pts: PackedVector2Array) -> void:
	draw_colored_polygon(pts, COL_SPIKE.darkened(0.55))
	pts.append(pts[0])
	draw_polyline(pts, COL_SPIKE, 3.0)


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
	if state == State.MENU:
		_draw_menu()
	else:
		_draw_play_hud()


func _draw_play_hud() -> void:
	# Oyun içinde yalnızca üç bilgi: seviye numarası, ilerleme çubuğu, yüzde.
	var size := hud.size
	var font := ThemeDB.fallback_font
	var progress := 1.0 if state == State.WON else clampf(px / level_end_x, 0.0, 1.0)
	var bar_w := minf(size.x * 0.5, 560.0)
	var bar := Rect2((size.x - bar_w) * 0.5, 24.0, bar_w, 14.0)
	hud.draw_rect(bar, Color(0, 0, 0, 0.5))
	hud.draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), COL_NEON)
	hud.draw_rect(bar, COL_NEON, false, 2.0)
	hud.draw_string(font, Vector2(bar.end.x + 12.0, 38.0), "%d%%" % int(progress * 100.0),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	hud.draw_string(font, Vector2(20.0, 38.0), _t("level") % level_index,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, COL_NEON)

	# Ana ekrana dönüş düğmesi (üç çizgi)
	var mb := _menu_rect()
	for i in 3:
		hud.draw_rect(Rect2(mb.position.x + 10.0, mb.position.y + 10.0 + i * 8.0, 28.0, 3.0), Color(1, 1, 1, 0.55))

	# Yeni yetenek duyurusu (yalnızca yetenek açılan seviyenin başında, kısa süre)
	if banner_t > 0.0 and new_ability and state == State.PLAYING:
		var a := clampf(banner_t / 0.6, 0.0, 1.0)
		var y := size.y * 0.32
		hud.draw_string(font, Vector2(0.0, y), "%s: %s" % [_t("new_ability"), _air_label()],
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, Color(COL_BLOCK_EDGE, a))
		hud.draw_string(font, Vector2(0.0, y + 32.0), _t("air_hint"),
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color(1, 1, 1, 0.8 * a))

	if state == State.WON:
		hud.draw_string(font, Vector2(0.0, size.y * 0.42), _t("complete"),
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 56, COL_PLAYER)


func _draw_menu() -> void:
	var size := hud.size
	var font := ThemeDB.fallback_font
	# Başlık
	var fs := 64
	var w1 := font.get_string_size("NEON ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w2 := font.get_string_size("PULSE", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x0 := (size.x - w1 - w2) * 0.5
	var ty := size.y * 0.20
	hud.draw_string(font, Vector2(x0, ty), "NEON ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COL_NEON)
	hud.draw_string(font, Vector2(x0 + w1, ty), "PULSE", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COL_BLOCK_EDGE)

	# Kaldığın seviye
	var fresh := level_index == 1 and int(save_data["total_attempts"]) == 0 and best_pct == 0
	hud.draw_string(font, Vector2(0.0, size.y * 0.33), _t("new_game") if fresh else _t("left_off"),
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color(1, 1, 1, 0.65))
	hud.draw_string(font, Vector2(0.0, size.y * 0.33 + 76.0), _t("level") % level_index,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 72, Color.WHITE)
	if best_pct > 0:
		hud.draw_string(font, Vector2(0.0, size.y * 0.33 + 112.0), _t("best") % best_pct,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, COL_NEON)

	# Düğmeler
	var sr := _start_rect()
	hud.draw_rect(sr, Color(COL_NEON, 0.18))
	hud.draw_rect(sr, COL_NEON, false, 3.0)
	hud.draw_string(font, Vector2(sr.position.x, sr.position.y + 43.0), _t("start") if fresh else _t("continue"),
		HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 30, COL_NEON)
	var rr := _reset_rect()
	var armed := reset_armed_t > 0.0
	var rc := COL_SPIKE if armed else Color(1, 1, 1, 0.45)
	if armed:
		hud.draw_rect(rr, Color(COL_SPIKE, 0.2))
	hud.draw_rect(rr, rc, false, 2.0)
	hud.draw_string(font, Vector2(rr.position.x, rr.position.y + 30.0), _t("reset_confirm") if armed else _t("reset"),
		HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 16, rc)

	# Dil düğmesi
	var lb := _lang_rect()
	hud.draw_rect(lb, Color(0, 0, 0, 0.45))
	hud.draw_rect(lb, COL_NEON, false, 2.0)
	hud.draw_string(font, Vector2(lb.position.x, lb.position.y + 24.0), lang.to_upper(),
		HORIZONTAL_ALIGNMENT_CENTER, lb.size.x, 18, COL_NEON)


func _air_label() -> String:
	return _t("air_inf") if air_jumps_cfg < 0 else _t("air_n") % air_jumps_cfg


# ---------------------------------------------------------------- kayıt

func _load_save() -> void:
	# İlerleme yalnızca cihazda (user://) saklanır; hesap veya sunucu yoktur.
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	save_data["level"] = maxi(1, int(data.get("level", data.get("unlocked", 1))))
	save_data["lang"] = str(data.get("lang", ""))
	save_data["total_attempts"] = int(data.get("total_attempts", 0))
	var best = data.get("best", {})
	if typeof(best) == TYPE_DICTIONARY:
		save_data["best"] = best


func _write_save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
