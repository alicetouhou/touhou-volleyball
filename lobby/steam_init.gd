extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_process(false)
	var init_result = Steam.steamInit(480)
	
	Steam.steam_shutdown.connect(steam_shutdown)

	print("Steam init result: ", init_result)

	if not init_result:
		return

	set_process(true)

	print("Steam initialized")
	print("Steam ID: ", Steam.getSteamID())
	print("App ID: ", Steam.getAppID())
	print("Overlay enabled: ", Steam.isOverlayEnabled())

func steam_shutdown() -> void:
	set_process(false)
	Steam.steamShutdown()
	print("Steam shutting down!")
	get_tree().quit()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Steam.steamShutdown()
		get_tree().quit()

func _process(_delta: float) -> void:
	Steam.run_callbacks()
