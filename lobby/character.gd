@tool
extends Control


signal pressed(character: CharacterResource)

var mouse_down := false
var button_pressed := false
var just_pressed := false

@export var character: CharacterResource

func radio_unpressed() -> void:
	if just_pressed:
		just_pressed = false
		return
	button_pressed = false
	create_tween().tween_property($TextureRect, "offset_transform_position", Vector2(0, 0), 0.1)

func update_character() -> void:
	$TextureRect.texture = character.texture
	$Label.text = character.name

func hovered() -> void:
	if button_pressed:
		return
	create_tween().tween_property($TextureRect, "offset_transform_position", Vector2(0, -50), 0.1)

func unhovered() -> void:
	if not button_pressed:
		create_tween().tween_property($TextureRect, "offset_transform_position", Vector2(0, 0), 0.1)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not button_pressed:
		if not mouse_down and event.is_pressed():
			mouse_down = true
			create_tween().tween_property($TextureRect, "offset_transform_position", Vector2(0, -45), 0.05)
		elif pressed and not event.is_pressed():
			mouse_down = false
			if Rect2(global_position, size).has_point(event.global_position):
				create_tween().tween_property($TextureRect, "offset_transform_position", Vector2(0, -50), 0.05)
				button_pressed = true
				if button_pressed:
					just_pressed = true
					pressed.emit(character)

func _ready() -> void:
	update_character()
