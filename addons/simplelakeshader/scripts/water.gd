@tool
extends MeshInstance3D
			
@export_category("Normals")
@export var texture_normal: NoiseTexture2D = preload("res://addons/simplelakeshader/assets/noise/normal.res"):
	set(value):
		texture_normal = value
		set_values()
@export var first_normal_speed = Vector2(-0.01, 0.03):
	set(value):
		first_normal_speed = value
		set_values()
@export var second_normal_speed = Vector2(0.025, -0.02):
	set(value):
		second_normal_speed = value
		set_values()
@export_range(-2.0, 2.0, 0.1) var first_normal_strength = 0.3:
	set(value):
		first_normal_strength = value
		set_values()
@export_range(-2.0, 2.0, 0.1) var second_normal_strength = 0.4:
	set(value):
		second_normal_strength = value
		set_values()

@export_category("Colors")
@export var deep_color: Color = Color(0.02, 0.15, 0.3):
	set(value):
		deep_color = value
		set_values()
@export var shallow_color: Color = Color(0.2, 0.5, 0.6):
	set(value):
		shallow_color = value
		set_values()
			
@export_category("Foam")
@export_range(0.0, 2.0, 0.01) var foam_distance = 0.03:
	set(value):
		foam_distance = value
		set_values()
@export_range(0.0, 1.0, 0.01) var foam_cutoff = 0.6:
	set(value):
		foam_cutoff = value
		set_values()
@export var foam_color: Color = Color(1.0, 1.0, 1.0):
	set(value):
		foam_color = value
		set_values()


@export_category("Misc")
@export var water_size = Vector2(2.0, 2.0):
	set(value):
		water_size = value
		set_values()
@export_range(0.0, 0.1, 0.01) var refraction_strength: float = 0.075:
	set(value):
		refraction_strength = value
		set_values()
@export_range(0.0, 1.0, 0.1) var roughness: float = 0.2:
	set(value):
		roughness = value
		set_values()
@export_range(0.0, 1.0, 0.1) var metallic: float = 0.2:
	set(value):
		metallic = value
		set_values()
@export_range(0.0, 1.0, 0.1) var specular: float = 0.3:
	set(value):
		specular = value
		set_values()
@export_range(0.0, 10.0, 0.1) var depth_distance: float = 2.0:
	set(value):
		depth_distance = value
		set_values()
@export_range(1.0, 32.0, 0.1) var beers_law: float = 16.0:
	set(value):
		beers_law = value
		set_values()
@export_range(0.0, 1.0, 0.01) var fresnel_strength: float = 0.25:
	set(value):
		fresnel_strength = value
		set_values()

var material: ShaderMaterial

func _ready() -> void:
	material = get_active_material(0)
	set_values()

func set_values() -> void:
	if not material:
		return
		
	mesh.size = water_size
	material.set_shader_parameter("texture_normal", texture_normal)
	material.set_shader_parameter("first_normal_speed", first_normal_speed)
	material.set_shader_parameter("second_normal_speed", second_normal_speed)
	material.set_shader_parameter("first_normal_strength", first_normal_strength)
	material.set_shader_parameter("second_normal_strength", second_normal_strength)
	
	material.set_shader_parameter("deep_color", deep_color)
	material.set_shader_parameter("shallow_color", shallow_color)
	
	material.set_shader_parameter("foam_distance", foam_distance)
	material.set_shader_parameter("foam_cutoff", foam_cutoff)
	material.set_shader_parameter("foam_color", foam_color)
	material.set_shader_parameter("refraction_strength", refraction_strength)
	material.set_shader_parameter("roughness", roughness)
	material.set_shader_parameter("metallic", metallic)
	material.set_shader_parameter("specular", specular)
	material.set_shader_parameter("depth_distance", depth_distance)
	material.set_shader_parameter("beers_law", beers_law)
	material.set_shader_parameter("fresnel_strength", fresnel_strength)
