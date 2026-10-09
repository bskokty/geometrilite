extends Node2D
## Neon Pulse - prototip. Tüm oyun mantığı ve çizim burada.
## Fizik sabit adımda (_physics_process) ve deterministiktir; tools/gen_levels.py
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
const LEVEL_PATH_FMT := "res://levels/level_%02d.json"
const SAVE_PATH := "user://save.json"
const BANNER_TIME := 3.0
const LANGS := ["en", "tr", "de", "es", "fr", "pt", "it", "ru"]
const STR := {
	"en": {
		"attempt": "Attempt %d", "level": "LEVEL %d / %d", "best": "Best %d%%",
		"complete": "LEVEL COMPLETE", "all_done": "ALL LEVELS COMPLETE",
		"tap_next": "Tap to continue", "tap_again": "Tap to play again",
		"new_ability": "NEW ABILITY", "air_n": "Air jump ×%d", "air_inf": "Unlimited air jumps",
		"air_hint": "Tap again while airborne",
	},
	"tr": {
		"attempt": "Deneme %d", "level": "SEVİYE %d / %d", "best": "En iyi %%%d",
		"complete": "SEVİYE TAMAMLANDI", "all_done": "TÜM SEVİYELER TAMAMLANDI",
		"tap_next": "Devam etmek için dokun", "tap_again": "Tekrar oynamak için dokun",
		"new_ability": "YENİ YETENEK", "air_n": "Havada zıplama ×%d", "air_inf": "Sınırsız havada zıplama",
		"air_hint": "Havadayken tekrar dokun",
	},
	"de": {
		"attempt": "Versuch %d", "level": "LEVEL %d / %d", "best": "Bestwert %d%%",
		"complete": "LEVEL GESCHAFFT", "all_done": "ALLE LEVEL GESCHAFFT",
		"tap_next": "Zum Fortfahren tippen", "tap_again": "Zum Neustart tippen",
		"new_ability": "NEUE FÄHIGKEIT", "air_n": "Luftsprung ×%d", "air_inf": "Unbegrenzte Luftsprünge",
		"air_hint": "In der Luft erneut tippen",
	},
	"es": {
		"attempt": "Intento %d", "level": "NIVEL %d / %d", "best": "Mejor %d%%",
		"complete": "NIVEL COMPLETADO", "all_done": "TODOS LOS NIVELES COMPLETADOS",
		"tap_next": "Toca para continuar", "tap_again": "Toca para jugar de nuevo",
		"new_ability": "NUEVA HABILIDAD", "air_n": "Salto aéreo ×%d", "air_inf": "Saltos aéreos ilimitados",
		"air_hint": "Toca de nuevo en el aire",
	},
	"fr": {
		"attempt": "Essai %d", "level": "NIVEAU %d / %d", "best": "Meilleur %d%%",
		"complete": "NIVEAU TERMINÉ", "all_done": "TOUS LES NIVEAUX TERMINÉS",
		"tap_next": "Touchez pour continuer", "tap_again": "Touchez pour rejouer",
		"new_ability": "NOUVELLE CAPACITÉ", "air_n": "Saut aérien ×%d", "air_inf": "Sauts aériens illimités",
		"air_hint": "Touchez à nouveau en l'air",
	},
	"pt": {
		"attempt": "Tentativa %d", "level": "NÍVEL %d / %d", "best": "Melhor %d%%",
		"complete": "NÍVEL CONCLUÍDO", "all_done": "TODOS OS NÍVEIS CONCLUÍDOS",
		"tap_next": "Toque para continuar", "tap_again": "Toque para jogar novamente",
		"new_ability": "NOVA HABILIDADE", "air_n": "Salto aéreo ×%d", "air_inf": "Saltos aéreos ilimitados",
		"air_hint": "Toque novamente no ar",
	},
	"it": {
		"attempt": "Tentativo %d", "level": "LIVELLO %d / %d", "best": "Migliore %d%%",
		"complete": "LIVELLO COMPLETATO", "all_done": "TUTTI I LIVELLI COMPLETATI",
		"tap_next": "Tocca per continuare", "tap_again": "Tocca per rigiocare",
		"new_ability": "NUOVA ABILITÀ", "air_n": "Salto in aria ×%d", "air_inf": "Salti in aria illimitati",
		"air_hint": "Tocca di nuovo in aria",
	},
	"ru": {
		"attempt": "Попытка %d", "level": "УРОВЕНЬ %d / %d", "best": "Рекорд %d%%",
		"complete": "УРОВЕНЬ ПРОЙДЕН", "all_done": "ВСЕ УРОВНИ ПРОЙДЕНЫ",
		"tap_next": "Нажмите, чтобы продолжить", "tap_again": "Нажмите, чтобы сыграть снова",
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

enum State { PLAYING, DEAD, WON }

var level_index := 1
var level_count := 1
var save_data := {"unlocked": 1, "best": {}, "total_attempts": 0}
var best_pct := 0
var lang := "en"
var level_meta: Array = []          # her seviye için {"name", "air"}
var air_jumps_cfg := 0              # seviyenin havada zıplama hakkı (0 yok, -1 sınırsız)
var air_left := 0
var has_ceiling := false
var ceil_y := 0.0
var banner_t := 0.0
var new_ability := false
var level_name := ""
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
var particles: Array = []

var camera: Camera2D
var hud: Control


func _ready() -> void:
	camera = $Camera
	while FileAccess.file_exists(LEVEL_PATH_FMT % (level_count + 1)):
		level_count += 1
	for i in range(1, level_count + 1):
		level_meta.append(_read_level_meta(i))
	_load_save()
	lang = str(save_data.get("lang", ""))
	if not LANGS.has(lang):
		var loc := OS.get_locale_language()
		lang = loc if LANGS.has(loc) else "en"
	level_index = clampi(int(save_data["unlocked"]), 1, level_count)
	_load_level(level_index)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_draw_hud)
	layer.add_child(hud)
	_reset_run()


func _read_level_meta(index: int) -> Dictionary:
	var file := FileAccess.open(LEVEL_PATH_FMT % index, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text()) if file else null
	if typeof(data) != TYPE_DICTIONARY:
		return {"name": "?", "air": 0}
	return {"name": str(data.get("name", "")), "air": int(data.get("air_jumps", 0))}


func _t(key: String) -> String:
	return STR[lang].get(key, STR["en"].get(key, key))


func _load_level(index: int) -> void:
	level_index = index
	attempts = 1
	banner_t = BANNER_TIME
	best_pct = int(save_data["best"].get(str(index), 0))
	var data = null
	var file := FileAccess.open(LEVEL_PATH_FMT % index, FileAccess.READ)
	if file:
		data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Seviye okunamadı: " + (LEVEL_PATH_FMT % index))
		data = {"name": "?", "speed": 520, "rows": ["."]}
	level_name = str(data.get("name", ""))
	speed = float(data.get("speed", 520))
	air_jumps_cfg = int(data.get("air_jumps", 0))
	var prev_air := int(level_meta[index - 2]["air"]) if index >= 2 and level_meta.size() >= index - 1 else 0
	new_ability = air_jumps_cfg != 0 and air_jumps_cfg != prev_air
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
	ceil_spike_tiles.clear()
	ceil_spike_hitboxes.clear()
	has_ceiling = air_jumps_cfg != 0
	ceil_y = GROUND_Y - row_count * T
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
			elif ch == "v":
				has_ceiling = true
				ceil_spike_tiles.append(rect)
				var cw := T * SPIKE_W_RATIO
				var cht := T * SPIKE_H_RATIO
				ceil_spike_hitboxes.append(Rect2(rect.position.x + (T - cw) * 0.5, rect.position.y, cw, cht))


func _reset_run() -> void:
	state = State.PLAYING
	state_time = 0.0
	px = 0.0
	py = GROUND_Y
	vy = 0.0
	rot = 0.0
	on_ground = true
	air_left = air_jumps_cfg
	jump_queued = held
	particles.clear()
	_update_camera()
	queue_redraw()


func _input(event: InputEvent) -> void:
	# Dokunma, emulate_mouse_from_touch ile fare olayına çevrilir; yalnızca onu dinliyoruz.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _lang_button_rect().has_point(event.position):
			_cycle_language()
			return
		_set_held(event.pressed)
	elif event is InputEventKey and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_UP, KEY_W]:
			_set_held(event.pressed)


func _lang_button_rect() -> Rect2:
	return Rect2(hud.size.x - 92.0, 16.0, 76.0, 34.0)


func _cycle_language() -> void:
	lang = LANGS[(LANGS.find(lang) + 1) % LANGS.size()]
	save_data["lang"] = lang
	_write_save()
	hud.queue_redraw()


func _set_held(pressed: bool) -> void:
	held = pressed
	if pressed:
		jump_queued = true
		if state == State.WON and state_time > 0.8:
			var next := level_index + 1
			_load_level(next if next <= level_count else 1)
			_reset_run()


func _physics_process(delta: float) -> void:
	state_time += delta
	match state:
		State.PLAYING:
			banner_t = maxf(0.0, banner_t - delta)
			_step_player(delta)
			_step_particles(delta)
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
		save_data["unlocked"] = maxi(int(save_data["unlocked"]), mini(level_index + 1, level_count))
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

	# Sol üst: seviye, deneme, en iyi sonuç
	hud.draw_string(font, Vector2(20.0, 32.0), _t("level") % [level_index, level_count],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, COL_NEON)
	hud.draw_string(font, Vector2(20.0, 58.0), _t("attempt") % attempts,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	hud.draw_string(font, Vector2(20.0, 80.0), _t("best") % best_pct,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.6))
	if air_jumps_cfg != 0:
		hud.draw_string(font, Vector2(20.0, 104.0), _air_label(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COL_BLOCK_EDGE)

	# Sağ üst: dil düğmesi
	var btn := _lang_button_rect()
	hud.draw_rect(btn, Color(0, 0, 0, 0.45))
	hud.draw_rect(btn, COL_NEON, false, 2.0)
	hud.draw_string(font, Vector2(btn.position.x, btn.position.y + 24.0), lang.to_upper(),
		HORIZONTAL_ALIGNMENT_CENTER, btn.size.x, 18, COL_NEON)

	# Seviye tanıtım afişi
	if banner_t > 0.0 and state != State.WON:
		var a := clampf(banner_t / 0.6, 0.0, 1.0)
		var y := size.y * 0.30
		hud.draw_string(font, Vector2(0.0, y), _t("level") % [level_index, level_count],
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(1, 1, 1, 0.7 * a))
		hud.draw_string(font, Vector2(0.0, y + 52.0), str(level_name).to_upper(),
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 56, Color(COL_NEON, a))
		if new_ability:
			hud.draw_string(font, Vector2(0.0, y + 100.0), "%s: %s" % [_t("new_ability"), _air_label()],
				HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color(COL_BLOCK_EDGE, a))
			hud.draw_string(font, Vector2(0.0, y + 130.0), _t("air_hint"),
				HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color(1, 1, 1, 0.8 * a))

	if state == State.WON:
		var all_done := level_index >= level_count
		hud.draw_string(font, Vector2(0.0, size.y * 0.40), _t("all_done") if all_done else _t("complete"),
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 56, COL_PLAYER)
		hud.draw_string(font, Vector2(0.0, size.y * 0.40 + 44.0), _t("attempt") % attempts,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(1, 1, 1, 0.75))
		hud.draw_string(font, Vector2(0.0, size.y * 0.40 + 84.0), _t("tap_again") if all_done else _t("tap_next"),
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color.WHITE)


func _air_label() -> String:
	return _t("air_inf") if air_jumps_cfg < 0 else _t("air_n") % air_jumps_cfg


# ---------------------------------------------------------------- kayıt

func _load_save() -> void:
	# İlerleme cihazda (user://) saklanır; web sürümünde tarayıcı deposuna yazılır.
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	save_data["unlocked"] = clampi(int(data.get("unlocked", 1)), 1, level_count)
	save_data["lang"] = str(data.get("lang", ""))
	save_data["total_attempts"] = int(data.get("total_attempts", 0))
	var best = data.get("best", {})
	if typeof(best) == TYPE_DICTIONARY:
		save_data["best"] = best


func _write_save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
