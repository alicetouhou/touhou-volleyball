#https://www.reddit.com/r/godot/comments/188eo64/how_do_i_generate_mipmaps_for_a_texture/
extends Node

@onready var mesh_instance_3d: MeshInstance3D = $MeshInstance3D

var material:ShaderMaterial
var mipmap = 0

func _ready() -> void:
	var image = create_image()
	var texture = ImageTexture.create_from_image(image)
	material = mesh_instance_3d.material_override as ShaderMaterial
	material.set_shader_parameter("texture_albedo", texture)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_right"):
		mipmap = (mipmap + 1) % 3
		material.set_shader_parameter("mipmap", mipmap)


func create_image() -> Image:
	var mipmap0 = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	mipmap0.fill(Color.RED)
	var mipmap1 = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	mipmap1.fill(Color.GREEN)
	var mipmap2 = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	mipmap2.fill(Color.BLUE)
	var data = mipmap0.get_data()
	data.append_array(mipmap1.get_data())
	data.append_array(mipmap2.get_data())

	return Image.create_from_data(4, 4, true, Image.FORMAT_RGBA8, data)
