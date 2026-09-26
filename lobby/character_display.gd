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

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for file in DirAccess.open("res://resources/characters").get_files():
		var character_card := preload("res://lobby/character.tscn").instantiate()
		character_card.character = load_asset("res://resources/characters/%s" % file)
		add_child(character_card)
