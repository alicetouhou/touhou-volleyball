@tool
extends VBoxContainer


@export var character: CharacterResource :
	set(value):
		character = value

func update_character() -> void:
	$TextureRect.texture = character.texture
	$Label.text = character.name

func hovered() -> void:
	create_tween().tween_property($TextureRect, "offset_transform_position", Vector2(0, -50), 0.1)

func unhovered() -> void:
	create_tween().tween_property($TextureRect, "offset_transform_position", Vector2(0, 0), 0.1)

func _ready() -> void:
	update_character()
