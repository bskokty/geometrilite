extends Node
## Reklam katmanı: Android'de AdMob (Google Mobile Ads SDK) ve AB onay penceresi (UMP).
## Android dışındaki platformlarda (web önizleme, masaüstü, editör) reklamları simüle eder;
## böylece oyun akışı her yerde aynı kalır ve gerçek reklam kimliği gerekmez.
##
## Kural: Onay (UMP) tamamlanmadan reklam istenmez. Reklam kimlikleri config/ads.json'dan okunur;
## depodaki değerler Google'ın TEST kimlikleridir, yayın derlemesinde CI gerçek kimliklerle değiştirir.

const CONFIG_PATH := "res://config/ads.json"
const SINGLETON := "PoingGodotAdMob"
const RETRY_MS := 30000
const MIN_INTERSTITIAL_GAP_MS := 120000
const SIM_SECONDS := 2.0

var rewarded_unit := "ca-app-pub-3940256099942544/5224354917"
var interstitial_unit := "ca-app-pub-3940256099942544/1033173712"
var is_real := false                  # gerçek AdMob eklentisi var mı (Android derlemesi)
var consent_ready := false            # onay akışı bitti mi
var can_request_ads := false
var privacy_options_required := false
var rewarded_ready := false
var interstitial_ready := false
var busy := false                     # tam ekran reklam gösteriliyor

# Simülasyon (gerçek olmayan platformlar)
var sim_active := false
var sim_t := 0.0
var _sim_on_reward := Callable()
var _sim_on_closed := Callable()

var _rewarded = null
var _interstitial = null
var _last_interstitial_ms := -MIN_INTERSTITIAL_GAP_MS
var _retry_rewarded_at := 0
var _retry_interstitial_at := 0


func _ready() -> void:
	_load_config()
	is_real = OS.get_name() == "Android" and Engine.has_singleton(SINGLETON)
	if is_real:
		_start_consent()
	else:
		# Önizleme/masaüstü: reklamlar hazır sayılır ve simüle edilir.
		consent_ready = true
		can_request_ads = true
		rewarded_ready = true
		interstitial_ready = true


func _load_config() -> void:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if not file:
		return
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	rewarded_unit = str(data.get("rewarded", rewarded_unit))
	interstitial_unit = str(data.get("interstitial", interstitial_unit))


func _process(delta: float) -> void:
	if sim_active:
		sim_t -= delta
		if sim_t <= 0.0:
			sim_active = false
			busy = false
			if _sim_on_reward.is_valid():
				_sim_on_reward.call()
			if _sim_on_closed.is_valid():
				_sim_on_closed.call()
			_sim_on_reward = Callable()
			_sim_on_closed = Callable()
	elif is_real and can_request_ads and not busy:
		var now := Time.get_ticks_msec()
		if not rewarded_ready and _rewarded == null and now >= _retry_rewarded_at:
			_retry_rewarded_at = now + RETRY_MS
			_load_rewarded()
		if not interstitial_ready and _interstitial == null and now >= _retry_interstitial_at:
			_retry_interstitial_at = now + RETRY_MS
			_load_interstitial()


# ---------------------------------------------------------------- onay (UMP) ve başlatma

func _start_consent() -> void:
	var params := ConsentRequestParameters.new()
	UserMessagingPlatform.consent_information.update(params,
		func() -> void: _on_consent_info_updated(),
		func(_err) -> void: _finish_consent())


func _on_consent_info_updated() -> void:
	var info := UserMessagingPlatform.consent_information
	if info.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED \
			and info.get_is_consent_form_available():
		UserMessagingPlatform.load_consent_form(
			func(form) -> void: form.show(func(_err) -> void: _finish_consent()),
			func(_err) -> void: _finish_consent())
	else:
		_finish_consent()


func _finish_consent() -> void:
	var info := UserMessagingPlatform.consent_information
	var status := info.get_consent_status()
	can_request_ads = status == ConsentInformation.ConsentStatus.NOT_REQUIRED \
		or status == ConsentInformation.ConsentStatus.OBTAINED
	privacy_options_required = info.get_privacy_options_requirement_status() \
		== ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED
	consent_ready = true
	if not can_request_ads:
		return
	# 13+ hedef kitle: reklam içerik düzeyini "Teen" ile sınırla.
	var config := RequestConfiguration.new()
	config.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_T
	MobileAds.set_request_configuration(config)
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status) -> void:
		_load_rewarded()
		_load_interstitial()
	MobileAds.initialize(listener)


func show_privacy_options() -> void:
	## AB kullanıcıları için "Gizlilik seçenekleri" (onayı değiştirme) formu.
	if is_real and privacy_options_required:
		UserMessagingPlatform.show_privacy_options_form(func(_err) -> void: pass)


# ---------------------------------------------------------------- yükleme

func _load_rewarded() -> void:
	if _rewarded:
		_rewarded.destroy()
		_rewarded = null
	rewarded_ready = false
	var cb := RewardedAdLoadCallback.new()
	cb.on_ad_failed_to_load = func(_err) -> void:
		rewarded_ready = false
	cb.on_ad_loaded = func(ad) -> void:
		_rewarded = ad
		rewarded_ready = true
	RewardedAdLoader.new().load(rewarded_unit, AdRequest.new(), cb)


func _load_interstitial() -> void:
	if _interstitial:
		_interstitial.destroy()
		_interstitial = null
	interstitial_ready = false
	var cb := InterstitialAdLoadCallback.new()
	cb.on_ad_failed_to_load = func(_err) -> void:
		interstitial_ready = false
	cb.on_ad_loaded = func(ad) -> void:
		_interstitial = ad
		interstitial_ready = true
	InterstitialAdLoader.new().load(interstitial_unit, AdRequest.new(), cb)


# ---------------------------------------------------------------- gösterme

func can_show_rewarded() -> bool:
	return can_request_ads and rewarded_ready and not busy


func show_rewarded(on_reward: Callable, on_closed: Callable) -> void:
	## on_reward: kullanıcı ödülü kazandı. on_closed: reklam kapandı (ödül kazanılsın ya da kazanılmasın).
	if not can_show_rewarded():
		on_closed.call()
		return
	busy = true
	if not is_real:
		sim_active = true
		sim_t = SIM_SECONDS
		_sim_on_reward = on_reward
		_sim_on_closed = on_closed
		return
	var ad = _rewarded
	_rewarded = null
	rewarded_ready = false
	var earned := [false]
	var finish := func() -> void:
		busy = false
		ad.destroy()
		if earned[0]:
			on_reward.call()
		on_closed.call()
		_retry_rewarded_at = 0
	var fsc := FullScreenContentCallback.new()
	fsc.on_ad_dismissed_full_screen_content = func() -> void: finish.call()
	fsc.on_ad_failed_to_show_full_screen_content = func(_err) -> void: finish.call()
	ad.full_screen_content_callback = fsc
	var listener := OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(_item) -> void: earned[0] = true
	ad.show(listener)


func can_show_interstitial() -> bool:
	return can_request_ads and interstitial_ready and not busy \
		and Time.get_ticks_msec() - _last_interstitial_ms >= MIN_INTERSTITIAL_GAP_MS


func show_interstitial(on_closed: Callable) -> void:
	if not can_show_interstitial():
		on_closed.call()
		return
	busy = true
	_last_interstitial_ms = Time.get_ticks_msec()
	if not is_real:
		sim_active = true
		sim_t = SIM_SECONDS
		_sim_on_reward = Callable()
		_sim_on_closed = on_closed
		return
	var ad = _interstitial
	_interstitial = null
	interstitial_ready = false
	var finish := func() -> void:
		busy = false
		ad.destroy()
		on_closed.call()
		_retry_interstitial_at = 0
	var fsc := FullScreenContentCallback.new()
	fsc.on_ad_dismissed_full_screen_content = func() -> void: finish.call()
	fsc.on_ad_failed_to_show_full_screen_content = func(_err) -> void: finish.call()
	ad.full_screen_content_callback = fsc
	ad.show()
