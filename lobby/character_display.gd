extends HBoxContainer


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
	if $"/root/Lobby".connected:
		$"/root/Lobby".set_player_character.rpc((selected.resource_path.split("/") as Array).back())
	for child in get_children():
		child.radio_unpressed()

func _ready() -> void:
	var first = true
	for file in DirAccess.open("res://resources/characters").get_files():
		var character_card := preload("res://lobby/character.tscn").instantiate()
		character_card.character = load_asset("res://resources/characters/%s" % file)
		if first:
			selected = character_card.character
			character_card.hovered()
			character_card.button_pressed = true
			first = false
		character_card.pressed.connect(unpress_others)
		add_child(character_card)
		
