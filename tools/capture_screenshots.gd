extends SceneTree
## Mağaza ekran görüntülerini üretir (xvfb altında, gerçek render ile).
## Kullanım: xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-method gl_compatibility \
##   --rendering-driver opengl3 --script tools/capture_screenshots.gd   (OUT_DIR ortam değişkeni: çıktı klasörü)
var g
var step := 0
var wait := 0

# Her sahne: [dosya adı, dil, hazırlayan fonksiyon]
func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	g = load("res://scenes/game.tscn").instantiate()
	root.add_child(g)


func _col_of(level: int, ch: String) -> int:
	g._load_level(level)
	for c in g.level_w:
		for r in g.row_count:
			if g.rows[r][c] == ch:
				return maxi(c, 13)
	return 12


func _freeze_at(level: int, px: float, py: float, rot: float) -> void:
	g._load_level(level)
	g._reset_run()
	g.px = px
	g.py = py
	g.on_ground = py >= g.GROUND_Y
	g.rot = rot
	g.banner_t = 0.0
	g.set_physics_process(false)
	g._update_camera()
	g.queue_redraw()
	g.hud.queue_redraw()


func _scene(i: int) -> String:
	g.set_physics_process(false)
	match i:
		0:  # Ana ekran, 5. seviyede kalmış
			g.lang = "en"; g.save_data["best"]["5"] = 62; g.save_data["total_attempts"] = 20; g.save_data["level"] = 5
			g._enter_menu(); g.set_physics_process(false)
			return "01-main-menu"
		1:  # Seviye 1 oyun içi, küp dikenin üstünde
			g.lang = "en"; g.state = g.State.PLAYING
			_freeze_at(1, 12.0 * 64.0 - 20.0, g.GROUND_Y - 120.0, -0.5)
			g.state = g.State.PLAYING
			return "02-gameplay-level-1"
		2:  # Tavan dikenleri
			g.lang = "en"
			var lv := 4
			var c := 12
			for cand in range(4, 12):   # tavan dikeni içeren ilk seviyeyi bul
				c = _col_of(cand, "v")
				if c != 12 or g.rows[0].length() <= 12:
					lv = cand
					break
			_freeze_at(lv, c * 64.0 - 330.0, g.GROUND_Y, 0.0)
			g.state = g.State.PLAYING
			return "03-ceiling-spikes"
		3:  # Yeni yetenek duyurusu (seviye 6)
			g.lang = "en"
			_freeze_at(6, 40.0, g.GROUND_Y, 0.0)
			g.state = g.State.PLAYING
			g.banner_t = 2.0
			return "04-new-ability-level-6"
		4:  # Yüksek bloklar, 8. seviye, havada
			g.lang = "en"
			var c2 := _col_of(8, "#")
			_freeze_at(8, c2 * 64.0 - 220.0, g.GROUND_Y - 150.0, 0.7)
			g.state = g.State.PLAYING
			return "05-gameplay-level-8"
		5:  # Seviye tamamlandı
			g.lang = "en"
			_freeze_at(2, 0.0, g.GROUND_Y, 0.0)
			g.px = g.level_w * 64.0 + 230.0
			g.state = g.State.WON
			g._update_camera()
			return "06-level-complete"
		6:  # Türkçe ana ekran
			g.lang = "tr"; g.save_data["level"] = 8; g.save_data["best"]["8"] = 37
			g._enter_menu(); g.set_physics_process(false)
			return "07-main-menu-turkish"
	return ""


var current := ""

func _process(_d: float) -> bool:
	wait += 1
	if wait == 3:
		current = _scene(step)
		if current == "":
			quit()
			return false
	elif wait == 3 + 1:
		g.queue_redraw()
		g.hud.queue_redraw()
	elif wait == 8:
		var dir := OS.get_environment("OUT_DIR")
		root.get_texture().get_image().save_png("%s/%s.png" % [dir, current])
		step += 1
		wait = 0
	return false
