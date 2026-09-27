extends HBoxContainer

var players: Array[PlayerPeer] = []

## https://www.reddit.com/r/godot/comments/13u9w0j/comment/ldb4q0w
static func load_asset(path : String) -> Resource:
	if OS.has_feature("export"):
		# Check if file is .remap
		if not path.ends_with(".remap"):
			return load(path)

		# Open the file
		var __config_file = ConfigFile.new()
		__config_file.load(path)

		# Load the remapped file
		var __remapped_file_path = __config_file.get_value("remap", "path")
		__config_file = null
		return load(__remapped_file_path)
	else:
		return load(path)

var selected: CharacterResource

func unpress_others(character: CharacterResource) -> void:
	selected = character
	var selected_id = (selected.resource_path.split("/") as Array).back()
	if $"/root/Lobby".connected:
		$"/root/Lobby".set_player_character.rpc(selected_id)
	for child in get_children():
		child.radio_unpressed()

func players_updated(players_: Array[PlayerPeer]) -> void:
	players = players_
	var character_selections = {}
	for player in players:
		var selections = character_selections.get(player.character, {"colors": [], "numbers": []})
		selections["numbers"].push_back(player.number)
		selections["colors"].push_back(player.color)
		character_selections[player.character] = selections

	for child in get_children():
		var pucks = character_selections.get(child.name + ".tres", {"colors": [], "numbers": []})
		child.set_pucks(pucks["colors"], pucks["numbers"])

func handle_input(player: PlayerPeer, event: InputEvent):
	if event.is_action_pressed("ui_right"):
		pass
	if event.is_action_pressed("ui_left"):
		pass

func _input(event: InputEvent) -> void:
	for player in players:
		if event.device == player.input_device:
			handle_input(player, event)

func _ready() -> void:
	var first = true
	for file in DirAccess.open("res://resources/characters").get_files():
		var character_card := preload("res://lobby/character_selection/character.tscn").instantiate()
		character_card.name = file.split(".")[0]
		character_card.character = load_asset("res://resources/characters/%s" % file)
		if first:
			selected = character_card.character
			character_card.set_pucks([Color.RED], [1])
			character_card.hovered()
			character_card.button_pressed = true
			first = false
		character_card.pressed.connect(unpress_others)
		add_child(character_card)
		
